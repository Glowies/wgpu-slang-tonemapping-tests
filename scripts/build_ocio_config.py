#!/usr/bin/env python3
"""
Build an OCIO config from a built-in ACES config, replacing its view transforms
with OpenDRT LUTs.

LUT files must be named <input>_to_<output>_<look>.spi3d, e.g.
acescct_to_rec2100-pq_OpenDRT-aery.spi3d. .exr LUT images with the same naming
are converted to .spi3d first (see exr_to_spi3d.py). Each LUT becomes a view transform
"<look> - <output>" and a view "<look>" on the displays for its output.

All views of the base config are removed except "Un-tone-mapped" and "Raw".
Displays without a LUT are removed; their display colorspaces stay, so they
can still be used for file output.

Usage:
    python build_ocio_config.py <lut_dir> <out_dir> [--base ocio://cg-config-v4.0.0_aces-v2.0_ocio-v2.5]
"""

import argparse
import re
import shutil
import sys
import tempfile
from pathlib import Path

import PyOpenColorIO as ocio

from exr_to_spi3d import convert_exr_to_spi3d

LUT_PATTERN = re.compile(r"^(?P<input>[^_]+)_to_(?P<output>[^_]+)_(?P<look>.+)\.spi3d$")

KEPT_VIEWS = ["Un-tone-mapped", "Raw"]
DISPLAY_XYZ = "CIE XYZ-D65 - Display-referred"
VIEW_FAMILY = "OpenDRT"

# Blender-specific role -> role it is filled from when the base config lacks it.
# Blender picks the colorspace of newly loaded images and sequencer strips from
# these; without them it tags even linear EXRs as sRGB.
BLENDER_ROLES = {
    "default_float": ocio.ROLE_SCENE_LINEAR,
    "default_byte": ocio.ROLE_TEXTURE_PAINT,
    "default_sequencer": ocio.ROLE_TEXTURE_PAINT,
}

# Input slug -> base config colorspace the LUT expects as input.
INPUTS = {
    "acescct": "ACEScct",
}

# Output slug -> (displays the views go on, colorspace of the LUT's output).
# OpenDRT has no piecewise sRGB EOTF: its sRGB and Display P3 presets are pure
# 2.2 power. The LUT output is decoded with that, then re-encoded by each
# display, so e.g. "sRGB - Display" shows the same light as "Gamma 2.2".
OUTPUTS = {
    "srgb-display": (
        ["sRGB - Display", "Gamma 2.2 Rec.709 - Display"],
        "Gamma 2.2 Rec.709 - Display",
    ),
    "display-p3": (
        ["Display P3 - Display"],
        "Gamma 2.2 Display P3 - Display",
    ),
    "rec2100-pq": (
        ["Rec.2100-PQ - Display"],
        "Rec.2100-PQ - Display",
    ),
}

D65 = (0.3127, 0.3290)
P3_PRIMARIES = ((0.680, 0.320), (0.265, 0.690), (0.150, 0.060))


def inv3(m):
    a, b, c, d, e, f, g, h, i = m
    det = a * (e * i - f * h) - b * (d * i - f * g) + c * (d * h - e * g)
    return [(e * i - f * h) / det, (c * h - b * i) / det, (b * f - c * e) / det,
            (f * g - d * i) / det, (a * i - c * g) / det, (c * d - a * f) / det,
            (d * h - e * g) / det, (b * g - a * h) / det, (a * e - b * d) / det]


def rgb_to_xyz(primaries):
    """RGB -> CIE XYZ matrix (row-major 3x3) for the given primaries, D65 white."""
    xyz = lambda x, y: (x / y, 1.0, (1 - x - y) / y)
    cols = [xyz(*p) for p in primaries]
    p = [cols[c][r] for r in range(3) for c in range(3)]
    s = inv3(p)
    w = xyz(*D65)
    k = [sum(s[3 * r + c] * w[c] for c in range(3)) for r in range(3)]
    return [p[3 * r + c] * k[c] for r in range(3) for c in range(3)]


def matrix_transform(m):
    return ocio.MatrixTransform([*m[0:3], 0, *m[3:6], 0, *m[6:9], 0, 0, 0, 0, 1])


def make_g22_p3_display():
    """Display P3 primaries with a pure 2.2 power, as output by OpenDRT."""
    exponent = ocio.ExponentTransform([2.2, 2.2, 2.2, 1.0], ocio.NEGATIVE_MIRROR,
                                      direction=ocio.TRANSFORM_DIR_INVERSE)
    cs = ocio.ColorSpace(ocio.REFERENCE_SPACE_DISPLAY, "Gamma 2.2 Display P3 - Display")
    cs.addAlias("g22_p3d65_display")
    cs.setInteropID("g22_p3d65_display")
    cs.setFamily("Display")
    cs.setDescription("Convert CIE XYZ (D65 white) to Gamma 2.2, P3-D65, mirror neg. values")
    cs.setEncoding("sdr-video")
    cs.setBitDepth(ocio.BIT_DEPTH_F32)
    cs.addCategory("file-io")
    cs.setTransform(
        ocio.GroupTransform([matrix_transform(inv3(rgb_to_xyz(P3_PRIMARIES))), exponent]),
        ocio.COLORSPACE_DIR_FROM_REFERENCE,
    )
    return cs


ADDED_COLORSPACES = {
    "Gamma 2.2 Display P3 - Display": make_g22_p3_display,
}


def collect_luts(lut_dir, convert_dir):
    """All .spi3d LUTs in lut_dir, plus its .exr LUTs converted into convert_dir.

    A converted .exr replaces a .spi3d of the same name, as the .exr is the source.
    """
    luts = {p.name: p for p in lut_dir.glob("*.spi3d")}
    exr_files = sorted(lut_dir.glob("*.exr"))
    if exr_files:
        convert_exr_to_spi3d(lut_dir, convert_dir)
        for exr in exr_files:
            spi3d = convert_dir / exr.with_suffix(".spi3d").name
            if not spi3d.is_file():
                sys.exit(f"Error: failed to convert '{exr}' to .spi3d")
            luts[spi3d.name] = spi3d
    return [luts[name] for name in sorted(luts)]


def parse_luts(lut_dir, paths):
    luts = []
    for path in paths:
        m = LUT_PATTERN.match(path.name)
        if m is None:
            sys.exit(f"Error: '{path.name}' is not named <input>_to_<output>_<look>.spi3d")
        if m["input"] not in INPUTS:
            sys.exit(f"Error: unknown input '{m['input']}' in {path.name}. Known: {', '.join(INPUTS)}")
        if m["output"] not in OUTPUTS:
            sys.exit(f"Error: unknown output '{m['output']}' in {path.name}. Known: {', '.join(OUTPUTS)}")
        luts.append((path, m["input"], m["output"], m["look"]))
    if not luts:
        sys.exit(f"Error: no .spi3d or .exr LUTs in '{lut_dir}'")
    return luts


def view_order(look):
    # "standard" first so it becomes each display's default view.
    return (not look.endswith("-standard"), look)


def build_config(base, luts, name):
    cfg = ocio.Config.CreateFromFile(base)
    scene_ref = cfg.getColorSpace(ocio.ROLE_INTERCHANGE_SCENE)
    if scene_ref is None:
        sys.exit(f"Error: base config '{base}' has no '{ocio.ROLE_INTERCHANGE_SCENE}' role")
    for required in [DISPLAY_XYZ, *INPUTS.values()]:
        if cfg.getColorSpace(required) is None:
            sys.exit(f"Error: base config '{base}' has no '{required}'")

    # Remember the kept views before removing anything: (name, shared, colorspace, rule).
    kept = {}
    for display in cfg.getDisplays():
        for view in cfg.getViews(ocio.VIEW_SHARED, display):
            if view in KEPT_VIEWS:
                kept.setdefault(view, (view, True, None, None))
        for view in cfg.getViews(ocio.VIEW_DISPLAY_DEFINED, display):
            if view in KEPT_VIEWS:
                kept.setdefault(view, (view, False, cfg.getDisplayViewColorSpaceName(display, view),
                                       cfg.getDisplayViewRule(display, view)))
    missing = [v for v in KEPT_VIEWS if v not in kept]
    if missing:
        sys.exit(f"Error: base config '{base}' has no view(s) {missing}")
    untonemapped_rule = cfg.getDisplayViewRule("", "Un-tone-mapped")

    # Clear all displays, shared views and virtual display views.
    displays = list(cfg.getDisplays())
    for display in displays:
        for view in list(cfg.getViews(ocio.VIEW_SHARED, display)) + \
                list(cfg.getViews(ocio.VIEW_DISPLAY_DEFINED, display)):
            cfg.removeDisplayView(display, view)
    for view in list(cfg.getSharedViews()):
        if view not in KEPT_VIEWS:
            cfg.removeSharedView(view)
    for kind in (ocio.VIEW_SHARED, ocio.VIEW_DISPLAY_DEFINED):
        for view in list(cfg.getVirtualDisplayViews(kind)):
            if view not in KEPT_VIEWS:
                cfg.removeVirtualDisplayView(view)

    # Keep only the default view transform; the base ACES ones are unused now.
    default_vt = cfg.getViewTransform(cfg.getDefaultViewTransformName())
    cfg.clearViewTransforms()
    cfg.addViewTransform(default_vt)

    for cs_name, make in ADDED_COLORSPACES.items():
        if cfg.getColorSpace(cs_name) is None and any(OUTPUTS[o][1] == cs_name for _, _, o, _ in luts):
            cfg.addColorSpace(make())

    # One view transform per LUT, one view per (display, look).
    views = {}
    for path, input_slug, output_slug, look in luts:
        out_displays, lut_encoding = OUTPUTS[output_slug]
        vt_name = f"{look} - {output_slug}"
        vt = ocio.ViewTransform(ocio.REFERENCE_SPACE_SCENE, vt_name, family=VIEW_FAMILY,
                                description=f"{look} LUT ({path.name})")
        vt.setTransform(ocio.GroupTransform([
            ocio.ColorSpaceTransform(scene_ref.getName(), INPUTS[input_slug]),
            ocio.FileTransform(path.name, interpolation=ocio.INTERP_TETRAHEDRAL),
            # Display-referred to display-referred: no view transform is inserted.
            ocio.ColorSpaceTransform(lut_encoding, DISPLAY_XYZ),
        ]), ocio.VIEWTRANSFORM_DIR_FROM_REFERENCE)
        cfg.addViewTransform(vt)
        for display in out_displays:
            views.setdefault(display, []).append((look, vt_name))

    # Rebuild the displays that have LUTs, in the base config's order.
    out_displays = [d for d in displays if d in views]
    unknown = set(views) - set(out_displays)
    if unknown:
        sys.exit(f"Error: base config '{base}' has no display(s) {sorted(unknown)}")
    for display in out_displays:
        for look, vt_name in sorted(views[display], key=lambda v: view_order(v[0])):
            cfg.addDisplayView(display, look, viewTransform=vt_name,
                               displayColorSpaceName=display, ruleName=untonemapped_rule)
        for view in KEPT_VIEWS:
            _, shared, colorspace, rule = kept[view]
            if shared:
                cfg.addDisplaySharedView(display, view)
            else:
                cfg.addDisplayView(display, view, viewTransform="",
                                   displayColorSpaceName=colorspace, ruleName=rule)

    looks = sorted({look for _, _, _, look in luts}, key=view_order)
    cfg.setActiveDisplays(", ".join(out_displays))
    cfg.setActiveViews(", ".join(looks + KEPT_VIEWS))

    # Drop viewing rules that no remaining view uses.
    used_rules = {cfg.getDisplayViewRule(d, v) for d in out_displays
                  for kind in (ocio.VIEW_SHARED, ocio.VIEW_DISPLAY_DEFINED)
                  for v in cfg.getViews(kind, d)}
    rules = cfg.getViewingRules()
    for i in reversed(range(rules.getNumEntries())):
        if rules.getName(i) not in used_rules:
            rules.removeRule(i)
    cfg.setViewingRules(rules)

    for role, source in BLENDER_ROLES.items():
        if not cfg.hasRole(role):
            colorspace = cfg.getColorSpace(source)
            if colorspace is None:
                sys.exit(f"Error: base config '{base}' has no '{source}' role to fill '{role}' from")
            cfg.setRole(role, colorspace.getName())

    cfg.setName(name or f"{cfg.getName()}_opendrt")
    cfg.setDescription(
        f"{cfg.getDescription().rstrip()}\n\n"
        f"Views replaced with OpenDRT LUTs by build_ocio_config.py (base: {base}).\n"
    )
    cfg.setSearchPath("luts")
    return cfg


def main():
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument("lut_dir", type=Path, help="Directory with <input>_to_<output>_<look>.spi3d or .exr LUTs")
    parser.add_argument("out_dir", type=Path, help="Output directory; config.ocio and luts/ go in <out_dir>/<config name>/")
    parser.add_argument("--base", default="ocio://cg-config-v4.0.0_aces-v2.0_ocio-v2.5",
                        help="Base config file or ocio:// URI (default: %(default)s)")
    parser.add_argument("--name", help="Config name (default: <base name>_opendrt)")
    args = parser.parse_args()

    if not args.lut_dir.is_dir():
        sys.exit(f"Error: '{args.lut_dir}' is not a directory")

    convert_dir = tempfile.TemporaryDirectory(prefix="exr_to_spi3d_")
    luts = parse_luts(args.lut_dir, collect_luts(args.lut_dir, Path(convert_dir.name)))
    cfg = build_config(args.base, luts, args.name)

    name = cfg.getName()
    if name in ("", ".", "..") or Path(name).name != name:
        sys.exit(f"Error: config name '{name}' can't be used as a folder name")
    config_dir = args.out_dir / name
    if config_dir.exists():
        # Only clear folders this script wrote, so a wrong path can't wipe anything else.
        if not config_dir.is_dir() or (any(config_dir.iterdir()) and not (config_dir / "config.ocio").is_file()):
            sys.exit(f"Error: '{config_dir}' exists and doesn't look like a generated config "
                     "(no config.ocio). Remove it or pick another --name.")
        shutil.rmtree(config_dir)
    lut_out = config_dir / "luts"
    lut_out.mkdir(parents=True, exist_ok=True)
    for path, *_ in luts:
        shutil.copy2(path, lut_out / path.name)

    cfg.setWorkingDir(str(config_dir.resolve()))
    cfg.validate()
    out_path = config_dir / "config.ocio"
    out_path.write_text(cfg.serialize())
    print(f"Wrote {out_path} ({len(luts)} LUTs, displays: {', '.join(cfg.getActiveDisplays())})")


if __name__ == "__main__":
    main()
