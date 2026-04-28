use clap::Parser;
use flume::bounded;
use image::{ImageBuffer, Rgba};
use std::path::PathBuf;
use wgpu::util::DeviceExt;

mod slang_macros;

#[derive(Clone, Debug, clap::ValueEnum, Default)]
pub enum OpenDrtLook {
    #[default]
    Standard,
    Arriba,
    Sylvan,
    Colorful,
    Aery,
    Dystopic,
    Umbra,
    All,
}

impl OpenDrtLook {
    fn to_u32(&self) -> u32 {
        match self {
            OpenDrtLook::Standard => 0,
            OpenDrtLook::Arriba => 1,
            OpenDrtLook::Sylvan => 2,
            OpenDrtLook::Colorful => 3,
            OpenDrtLook::Aery => 4,
            OpenDrtLook::Dystopic => 5,
            OpenDrtLook::Umbra => 6,
            OpenDrtLook::All => 999,
        }
    }

    fn all_presets() -> Vec<OpenDrtLook> {
        vec![
            OpenDrtLook::Standard,
            OpenDrtLook::Arriba,
            OpenDrtLook::Sylvan,
            OpenDrtLook::Colorful,
            OpenDrtLook::Aery,
            OpenDrtLook::Dystopic,
            OpenDrtLook::Umbra,
        ]
    }

    fn preset_name(&self) -> &'static str {
        match self {
            OpenDrtLook::Standard => "standard",
            OpenDrtLook::Arriba => "arriba",
            OpenDrtLook::Sylvan => "sylvan",
            OpenDrtLook::Colorful => "colorful",
            OpenDrtLook::Aery => "aery",
            OpenDrtLook::Dystopic => "dystopic",
            OpenDrtLook::Umbra => "umbra",
            OpenDrtLook::All => "all",
        }
    }
}

#[derive(Parser, Debug)]
#[command(name = "wgpu-slang-tonemappers")]
#[command(about = "Process EXR images with OpenDRT compute shader", long_about = None)]
pub struct Args {
    pub input: PathBuf,
    pub output: PathBuf,
    pub look: Option<OpenDrtLook>,
}

// Define the uniform buffer struct that matches your shader
#[repr(C)]
#[derive(Copy, Clone, bytemuck::Pod, bytemuck::Zeroable)]
struct ShaderUniforms {
    in_gamut: u32,
    in_oetf: u32,
    display_encoding_preset: u32,
    look_preset: u32,
    display_peak_luminance: f32,
    _padding: [u32; 3],
}

pub async fn run(args: Args) -> anyhow::Result<()> {
    // Determine which looks to process
    let looks_to_process = if matches!(args.look, Some(OpenDrtLook::All)) {
        OpenDrtLook::all_presets()
    } else {
        vec![args.look.unwrap_or_default()]
    };
    let is_processing_multiple = looks_to_process.len() > 1;

    let instance = wgpu::Instance::new(&Default::default());
    let adapter = instance.request_adapter(&Default::default()).await.unwrap();
    let (device, queue) = adapter.request_device(&Default::default()).await.unwrap();

    let shader = device.create_shader_module(wgpu_include_slang_shader!("entry"));

    let pipeline = device.create_compute_pipeline(&wgpu::ComputePipelineDescriptor {
        label: Some("OpenDRT Compute Pipeline"),
        layout: None,
        module: &shader,
        entry_point: None,
        compilation_options: Default::default(),
        cache: Default::default(),
    });

    // READ EXR FILE
    println!("Reading EXR file: {:?}", args.input);
    let img = image::open(&args.input)?.into_rgba32f();

    let texture_size = wgpu::Extent3d {
        width: img.width(),
        height: img.height(),
        depth_or_array_layers: 1,
    };
    println!("Image dimensions: {:?}", texture_size);

    // Convert image data to f32 array for GPU
    let input_data: Vec<f32> = img.as_raw().to_vec();

    // CREATE TEXTURES
    let texture_format = wgpu::TextureFormat::Rgba32Float;

    let input_texture = device.create_texture(&wgpu::TextureDescriptor {
        label: Some("input_texture"),
        size: texture_size,
        mip_level_count: 1,
        sample_count: 1,
        dimension: wgpu::TextureDimension::D2,
        format: texture_format,
        usage: wgpu::TextureUsages::TEXTURE_BINDING | wgpu::TextureUsages::COPY_DST,
        view_formats: &[],
    });

    let output_texture = device.create_texture(&wgpu::TextureDescriptor {
        label: Some("output_texture"),
        size: texture_size,
        mip_level_count: 1,
        sample_count: 1,
        dimension: wgpu::TextureDimension::D2,
        format: texture_format,
        usage: wgpu::TextureUsages::STORAGE_BINDING | wgpu::TextureUsages::COPY_SRC,
        view_formats: &[],
    });

    // Write input data to input texture
    let texel_copy_buffer_layout = wgpu::TexelCopyBufferLayout {
        offset: 0,
        bytes_per_row: Some(16 * texture_size.width),
        rows_per_image: Some(texture_size.height),
    };
    queue.write_texture(
        wgpu::TexelCopyTextureInfo {
            texture: &input_texture,
            mip_level: 0,
            origin: wgpu::Origin3d::ZERO,
            aspect: wgpu::TextureAspect::All,
        },
        bytemuck::cast_slice(&input_data),
        texel_copy_buffer_layout,
        texture_size,
    );

    // Create a temp buffer for reading back results
    let temp_buffer = device.create_buffer(&wgpu::BufferDescriptor {
        label: Some("temp"),
        size: (texture_size.width * texture_size.height * 16) as u64,
        usage: wgpu::BufferUsages::COPY_DST | wgpu::BufferUsages::MAP_READ,
        mapped_at_creation: false,
    });

    // CREATE TEXTURE VIEWS
    let input_texture_view = input_texture.create_view(&wgpu::TextureViewDescriptor::default());
    let output_texture_view = output_texture.create_view(&wgpu::TextureViewDescriptor::default());

    // CREATE BIND GROUP FOR THE COMPUTE SHADER
    let uniform_buffer = device.create_buffer_init(&wgpu::util::BufferInitDescriptor {
        label: Some("Shader Uniforms"),
        contents: bytemuck::cast_slice(&[ShaderUniforms {
            in_gamut: 1,
            in_oetf: 3,
            display_encoding_preset: 1,
            look_preset: 0,
            display_peak_luminance: 100.0,
            _padding: [0; 3],
        }]),
        usage: wgpu::BufferUsages::UNIFORM | wgpu::BufferUsages::COPY_DST,
    });

    let texture_bind_group = device.create_bind_group(&wgpu::BindGroupDescriptor {
        label: None,
        layout: &pipeline.get_bind_group_layout(0),
        entries: &[
            wgpu::BindGroupEntry {
                binding: 0,
                resource: wgpu::BindingResource::TextureView(&input_texture_view),
            },
            wgpu::BindGroupEntry {
                binding: 1,
                resource: wgpu::BindingResource::TextureView(&output_texture_view),
            },
        ],
    });

    let uniform_bind_group = device.create_bind_group(&wgpu::BindGroupDescriptor {
        label: None,
        layout: &pipeline.get_bind_group_layout(1),
        entries: &[wgpu::BindGroupEntry {
            binding: 0,
            resource: uniform_buffer.as_entire_binding(),
        }],
    });

    // Process each look preset
    for look in looks_to_process {
        process_look(
            look,
            &device,
            &queue,
            &pipeline,
            &uniform_buffer,
            &texture_bind_group,
            &uniform_bind_group,
            texture_size,
            texel_copy_buffer_layout,
            &output_texture,
            &temp_buffer,
            &args.output,
            is_processing_multiple,
        )
        .await?;
    }

    println!("Successfully processed image!");

    Ok(())
}

async fn process_look(
    look: OpenDrtLook,
    device: &wgpu::Device,
    queue: &wgpu::Queue,
    pipeline: &wgpu::ComputePipeline,
    uniform_buffer: &wgpu::Buffer,
    texture_bind_group: &wgpu::BindGroup,
    uniform_bind_group: &wgpu::BindGroup,
    texture_size: wgpu::Extent3d,
    texel_copy_buffer_layout: wgpu::TexelCopyBufferLayout,
    output_texture: &wgpu::Texture,
    temp_buffer: &wgpu::Buffer,
    output_path_base: &PathBuf,
    is_with_look_in_name: bool,
) -> anyhow::Result<()> {
    // Update uniform buffer with the current look preset
    let uniforms = ShaderUniforms {
        in_gamut: 1,
        in_oetf: 3,
        display_encoding_preset: 1,
        look_preset: look.to_u32(),
        display_peak_luminance: 100.0,
        _padding: [0; 3],
    };
    queue.write_buffer(&uniform_buffer, 0, bytemuck::cast_slice(&[uniforms]));

    // ENQUEUE THE COMPUTE SHADER AND TEXTURE COPY
    let mut encoder = device.create_command_encoder(&Default::default());

    {
        // We specified 8x8 threads per workgroup in the shader, so we need to compute how many
        // workgroups we need to dispatch.
        let num_workgroups_x = texture_size.width.div_ceil(8);
        let num_workgroups_y = texture_size.height.div_ceil(8);

        let mut pass = encoder.begin_compute_pass(&Default::default());
        pass.set_pipeline(&pipeline);
        pass.set_bind_group(0, texture_bind_group, &[]);
        pass.set_bind_group(1, uniform_bind_group, &[]);
        pass.dispatch_workgroups(num_workgroups_x, num_workgroups_y, 1);
    }

    encoder.copy_texture_to_buffer(
        wgpu::TexelCopyTextureInfo {
            texture: &output_texture,
            mip_level: 0,
            origin: wgpu::Origin3d::ZERO,
            aspect: wgpu::TextureAspect::All,
        },
        wgpu::TexelCopyBufferInfo {
            buffer: &temp_buffer,
            layout: texel_copy_buffer_layout,
        },
        texture_size,
    );

    queue.submit([encoder.finish()]);

    // GET INFO BACK FROM GPU
    let output_data = {
        // The mapping process is async, so we'll need to create a channel to get
        // the success flag for our mapping
        let (tx, rx) = bounded(1);

        // We send the success or failure of our mapping via a callback
        temp_buffer.map_async(wgpu::MapMode::Read, .., move |result| {
            tx.send(result).unwrap()
        });

        // The callback we submitted to map async will only get called after the
        // device is polled or the queue submitted
        device.poll(wgpu::PollType::wait_indefinitely())?;

        // We check if the mapping was successful here
        rx.recv_async().await??;

        // We then get the bytes that were stored in the buffer
        let buffer_view = temp_buffer.get_mapped_range(..);
        let data: Vec<f32> = bytemuck::cast_slice(&buffer_view).to_vec();

        data
    };
    // We need to unmap the buffer to be able to use it again
    temp_buffer.unmap();

    // Generate output path with look preset name if processing multiple looks
    let output_path = if is_with_look_in_name {
        let mut path = output_path_base.clone();
        let stem = path.file_stem().unwrap().to_string_lossy().to_string();
        let extension = path.extension().unwrap().to_string_lossy().to_string();
        path.set_file_name(format!("{}_{}.{}", stem, look.preset_name(), extension));
        path
    } else {
        output_path_base.clone()
    };

    // Write output EXR file
    println!("Writing output to: {:?}", output_path);
    let output_image: ImageBuffer<Rgba<f32>, Vec<f32>> =
        ImageBuffer::from_raw(texture_size.width, texture_size.height, output_data)
            .expect("Failed to create output image buffer");

    output_image.save(&output_path)?;

    Ok(())
}
