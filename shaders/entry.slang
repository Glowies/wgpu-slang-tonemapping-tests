import "modules/opendrt.slang";

struct Textures {
  Texture2D<float4> inputTexture;
  WTexture2D<float4> outputTexture;
}

ParameterBlock<Textures> textures;
ParameterBlock<OpenDrtUniforms> uniforms;

[shader("compute")]
[numthreads(8, 8, 1)]
void main(uint3 global_invocation_id: SV_DispatchThreadID) {
  uint2 pixel_coords = global_invocation_id.xy;
  uint width, height;
  textures.inputTexture.GetDimensions(width, height);

  if (pixel_coords.x >= width || pixel_coords.y >= height) {
    return;
  }

  // assume input pixels are in AP0 color space
  float4 input_color = textures.inputTexture[pixel_coords];
  float3 output_color = opendrt_transform(input_color.rgb, uniforms);

  float4 output_color_with_alpha = float4(output_color, input_color.a);
  textures.outputTexture.Store(pixel_coords, output_color_with_alpha);
}
