#!/usr/bin/env python3
"""
Convert EXR files to SPI3D LUT files using OCIO's ociolutimage tool.
"""

import subprocess
import sys
from pathlib import Path


def convert_exr_to_spi3d(
    directory, output_directory=None, cube_size=48, max_width=9000
):
    """
    Convert all EXR files in a directory to SPI3D format.

    Args:
        directory: Path to directory containing EXR files
        output_directory: Path to output directory (creates if doesn't exist). If None, saves to input directory.
        cube_size: Cube size for the LUT (default: 48)
        max_width: Maximum width for the LUT (default: 9000)
    """
    directory = Path(directory)

    if not directory.exists():
        print(f"Error: Directory '{directory}' does not exist")
        sys.exit(1)

    if not directory.is_dir():
        print(f"Error: '{directory}' is not a directory")
        sys.exit(1)

    # Handle output directory
    if output_directory:
        output_dir = Path(output_directory)
        output_dir.mkdir(parents=True, exist_ok=True)
        print(f"Output directory: {output_dir.resolve()}\n")
    else:
        output_dir = directory

    # Find all EXR files
    exr_files = sorted(directory.glob("*.exr"))

    if not exr_files:
        print(f"No EXR files found in '{directory}'")
        return

    print(f"Found {len(exr_files)} EXR file(s) to convert\n")

    for i, exr_file in enumerate(exr_files, 1):
        output_file = output_dir / exr_file.with_suffix(".spi3d").name

        command = [
            "ociolutimage",
            "--extract",
            "--input",
            str(exr_file),
            "--output",
            str(output_file),
            "--cubesize",
            str(cube_size),
            "--maxwidth",
            str(max_width),
        ]

        print(
            f"[{i}/{len(exr_files)}] Converting: {exr_file.name} -> {output_file.name}"
        )

        try:
            result = subprocess.run(command, capture_output=True, text=True)

            if result.returncode == 0:
                print(f"        ✓ Successfully converted\n")
            else:
                print(f"        ✗ Error: {result.stderr}\n")

        except FileNotFoundError:
            print(f"        ✗ Error: 'ociolutimage' command not found.")
            print("        Make sure OCIO is installed and in your PATH.\n")
            sys.exit(1)
        except Exception as e:
            print(f"        ✗ Error: {e}\n")


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Convert EXR files to SPI3D LUT files")
        print(
            "\nUsage: python exr_to_spi3d.py <directory> [output_directory] [cube_size] [max_width]"
        )
        print("\nExamples:")
        print("  python exr_to_spi3d.py ./exr_files")
        print("  python exr_to_spi3d.py ./exr_files ./output_luts")
        print("  python exr_to_spi3d.py ./exr_files ./output_luts 64 10000")
        sys.exit(1)

    directory = sys.argv[1]
    output_directory = (
        sys.argv[2] if len(sys.argv) > 2 and not sys.argv[2].isdigit() else None
    )

    # Adjust indices for cube_size and max_width based on whether output_directory was provided
    cube_size_idx = 3 if output_directory else 2
    max_width_idx = 4 if output_directory else 3

    cube_size = int(sys.argv[cube_size_idx]) if len(sys.argv) > cube_size_idx else 48
    max_width = int(sys.argv[max_width_idx]) if len(sys.argv) > max_width_idx else 9000

    convert_exr_to_spi3d(directory, output_directory, cube_size, max_width)
