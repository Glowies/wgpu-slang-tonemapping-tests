# To get Blender to recognize and display HDR view transforms
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
