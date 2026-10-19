# How-To: Generate OCIO Config from the LUTs

## Generate your view transform LUTs
```sh
pixi run start --release -- refs/input/identity48.exr output/luts/acescct_to_display-p3_OpenDRT.exr -l all -d displayp3
pixi run start --release -- refs/input/identity48.exr output/luts/acescct_to_srgb-display_OpenDRT.exr -l all -d srgb
pixi run start --release -- refs/input/identity48.exr output/luts/acescct_to_rec2100-pq_OpenDRT.exr -l all -d rec2100pq -p 1000
```

## Add LUTs as View Transforms to an OCIO config
```sh
pixi run build-ocio-config output/luts output/ --name opendrt-custom 
```

# To get Blender to recognize and display HDR view transforms
These are a few things that were needed for Blender to recognize and use the HDR View Transforms correctly.
If you use an ACES OCIO config as your base, these should already be true.

- Each HDR display space should have `encoding: hdr-video`
  - This makes sure the display is categorized as HDR under the Displays menu in Blender
- The view transforms need be actually marked as ViewTransforms, not just plain ColorSpaces
  - Wrong:
  ```
displays:
  Rec2100 PQ:
    - !<View> {name: OpenDRT-aery, colorspace: OpenDRT-aery - Rec2100 PQ}

...

colorspaces:
- !<ColorSpace>
  name: OpenDRT-aery - Rec2100 PQ
  family: Image Formation
  encoding: hdr-video
  from_reference: !<GroupTransform>
    children:
      - !<ColorSpaceTransform> {src: reference, dst: ACEScct}
      - !<FileTransform> {src: acescct_to_rec2100-pq_OpenDRT-aery.spi3d, interpolation: tetrahedral}

  ```

  - Right:
  ```
displays:    
  Rec2100 PQ:
    - !<View> {name: OpenDRT-aery, view_transform: OpenDRT-aery - Rec2100 PQ, display_colorspace: Rec2100 PQ}

...

view_transforms:
  - !<ViewTransform>
    name: OpenDRT-aery - Rec2100 PQ
    family: OpenDRT
    from_scene_reference: !<GroupTransform>
      children:
        - !<ColorSpaceTransform> {src: Filmlight - E-Gamut2 - Linear, dst: ACEScct}
        - !<FileTransform> {src: acescct_to_rec2100-pq_OpenDRT-aery.spi3d, interpolation: tetrahedral}
        - !<GroupTransform>
          direction: inverse
          children:
            - !<BuiltinTransform> {style: DISPLAY - CIE-XYZ-D65_to_REC.2100-PQ}
  ```
