#!/usr/bin/env python3
"""Assemble owner-rendered v5 PNG sequences into 1x and 1/3-speed motion proof.

Uses Pillow, already required by the supplied director mockup. Source PNGs remain
unchanged; GIFs are supplemental motion previews, not the native pixel evidence.
"""
import argparse
from pathlib import Path
from PIL import Image

FPS = 30
NATIVE_SIZE = (1920, 1080)
SEQUENCES = {"opening_1x": (13, 1), "opening_third_speed": (37, 3)}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input-dir", type=Path, default=Path(__file__).resolve().parents[2] / "output/dlg-01-v5/native")
    args = parser.parse_args()
    for prefix, (count, speed_divisor) in SEQUENCES.items():
        files = [args.input_dir / f"{prefix}_{index:02d}.png" for index in range(count)]
        missing = [str(path) for path in files if not path.is_file()]
        if missing:
            parser.error("Missing owner-rendered frame(s): " + ", ".join(missing))
        with Image.open(files[-1]) as image:
            palette = image.convert("RGB").quantize(colors=256, dither=Image.Dither.NONE)
        frames = []
        for path in files:
            with Image.open(path) as image:
                if image.size != NATIVE_SIZE:
                    parser.error(f"Expected native {NATIVE_SIZE}: {path} is {image.size}")
                frames.append(image.convert("RGB").quantize(palette=palette, dither=Image.Dither.NONE))
        # GIF uses centiseconds: 30/40/30ms retains 30fps instead of silently
        # truncating every 33ms frame to 30ms. Match the final hold at 1/3 speed.
        durations = [(round((index + 1) * 100 / FPS) - round(index * 100 / FPS)) * 10 for index in range(count)]
        durations[-1] *= speed_divisor
        output = args.input_dir / f"{prefix}.gif"
        frames[0].save(output, save_all=True, append_images=frames[1:], duration=durations, loop=0, optimize=False)
        print(output)


if __name__ == "__main__":
    main()
