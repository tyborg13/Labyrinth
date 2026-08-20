#!/usr/bin/env python3
"""Split the approved ImageGen combat-mechanic atlas into game-ready icons."""

from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image


ICON_NAMES = (
    "corruption",
    "radiance",
    "surface_bramble",
    "surface_poison",
    "surface_ice",
    "surface_snowdrift",
    "surface_electrified",
    "combust",
    "free_move",
)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("atlas", type=Path)
    parser.add_argument("output_dir", type=Path)
    args = parser.parse_args()

    atlas = Image.open(args.atlas).convert("RGBA")
    if atlas.width != atlas.height or atlas.width % 3 != 0:
        raise SystemExit(f"Expected a square 3x3 atlas, got {atlas.size}")
    cell_size = atlas.width // 3
    args.output_dir.mkdir(parents=True, exist_ok=True)
    for index, icon_name in enumerate(ICON_NAMES):
        column = index % 3
        row = index // 3
        icon = atlas.crop((
            column * cell_size,
            row * cell_size,
            (column + 1) * cell_size,
            (row + 1) * cell_size,
        ))
        icon = icon.resize((64, 64), Image.Resampling.LANCZOS)
        icon.save(args.output_dir / f"{icon_name}.png", optimize=True)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
