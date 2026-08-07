#!/usr/bin/env python3
"""Build palette-stable looping GIFs from promo_capture PNG frames."""

from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image


def build_one(source: Path, destination: Path) -> None:
    paths = sorted(source.glob("frame_*.png"))
    if len(paths) != 36:
        raise SystemExit(f"{source}: expected 36 frames, found {len(paths)}")
    rgb = [Image.open(path).convert("RGB") for path in paths]

    # One palette for the whole animation avoids color shimmer between frames.
    sample = Image.new("RGB", (rgb[0].width, rgb[0].height * len(rgb)))
    for index, frame in enumerate(rgb):
        sample.paste(frame, (0, index * frame.height))
    palette = sample.quantize(colors=255, method=Image.Quantize.MEDIANCUT)
    frames = [
        frame.quantize(palette=palette, dither=Image.Dither.NONE)
        for frame in rgb
    ]
    destination.parent.mkdir(parents=True, exist_ok=True)
    frames[0].save(
        destination,
        save_all=True,
        append_images=frames[1:],
        duration=50,
        loop=0,
        # Keep the authored frame cadence intact. Some platforms interpret
        # optimized merged-frame delays differently when looping GIFs.
        optimize=False,
        disposal=1,
    )
    with Image.open(destination) as built:
        total_ms = 0
        unique = set()
        for index in range(built.n_frames):
            built.seek(index)
            total_ms += built.info.get("duration", 0)
            unique.add(built.convert("RGB").tobytes())
        if built.size != (480, 432) or not 8 <= built.n_frames <= 36:
            raise SystemExit(f"{destination}: invalid dimensions/frame count")
        if total_ms != 1800 or len(unique) < 8 or built.info.get("loop") != 0:
            raise SystemExit(f"{destination}: invalid timing, motion, or loop")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("frames", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    folders = sorted(path for path in args.frames.iterdir() if path.is_dir())
    if len(folders) != 15:
        raise SystemExit(f"expected 15 move folders, found {len(folders)}")
    for folder in folders:
        destination = args.output / f"{folder.name}.gif"
        build_one(folder, destination)
        print(f"built {destination}")


if __name__ == "__main__":
    main()
