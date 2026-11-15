#!/usr/bin/env python3
"""atk-06 proof pair (not a test): crop the same board region from two native
captures, scale 2x, and put them side by side. Each capture's JSON sidecar
(tools/atk06/capture.gd) gives the screen polygon of the marked tile, which is
outlined in a thin neutral proof colour so the reader can find it; the game
frames themselves are untouched.

  python3 tools/atk06/pair.py <before.png> <after.png> <out.png> [--pad 220]
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path

from PIL import Image, ImageDraw

PROOF_INK = (235, 235, 235)


def marks(png: Path) -> list[list[tuple[float, float]]]:
    sidecar = png.with_suffix(".json")
    if not sidecar.exists():
        return []
    data = json.loads(sidecar.read_text())
    return [[(float(x), float(y)) for x, y in points] for points in data.get("marks", {}).values()]


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("before")
    parser.add_argument("after")
    parser.add_argument("out")
    parser.add_argument("--pad", type=int, default=150)
    args = parser.parse_args()
    shots = [Path(args.before), Path(args.after)]
    polygons = marks(shots[0]) or marks(shots[1])
    points = [p for polygon in polygons for p in polygon]
    if points:
        left, top = min(x for x, _ in points) - args.pad, min(y for _, y in points) - args.pad
        right, bottom = max(x for x, _ in points) + args.pad, max(y for _, y in points) + args.pad
    else:
        left, top, right, bottom = 480, 180, 1440, 900
    box = (int(max(0, left)), int(max(0, top)), int(min(1920, right)), int(min(1080, bottom)))
    tiles = []
    for shot in shots:
        image = Image.open(shot).convert("RGB")
        draw = ImageDraw.Draw(image)
        for polygon in marks(shot) or polygons:
            # Outside the tile, so the board's own red outline stays visible.
            cx = sum(x for x, _ in polygon[:4]) / 4.0
            cy = sum(y for _, y in polygon[:4]) / 4.0
            ring = [(cx + (x - cx) * 1.35, cy + (y - cy) * 1.35) for x, y in polygon[:4]]
            draw.line(ring + [ring[0]], fill=PROOF_INK, width=2)
        crop = image.crop(box)
        tiles.append(crop.resize((crop.width * 2, crop.height * 2), Image.LANCZOS))
    gap = 16
    pair = Image.new("RGB", (tiles[0].width * 2 + gap, tiles[0].height), (12, 10, 8))
    pair.paste(tiles[0], (0, 0))
    pair.paste(tiles[1], (tiles[0].width + gap, 0))
    pair.save(args.out)
    print(args.out, box)


if __name__ == "__main__":
    main()
