#!/usr/bin/env python3
"""Convert white-on-black painted brush strokes into tintable alpha textures.

The turn-order rail tints each stroke in-engine (ivory, teal, crimson), so the
shipped textures are pure white with the painting carried entirely in alpha.
Source paintings were generated as white paint on solid black; luminance
becomes alpha after a gentle levels pass that keeps dry-brush bristle detail.

    python3 tools/process_turn_order_brushes.py <source_dir>
"""
from __future__ import annotations

import sys
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets" / "art" / "ui" / "turn_order_ink"
NAMES = ("brush_a", "brush_b", "brush_c", "brush_d", "brush_hero")
TARGET_WIDTH = 512
PADDING = 0.04
BLACK_POINT = 18.0
WHITE_POINT = 225.0


def process(source: Path, destination: Path) -> None:
    image = Image.open(source).convert("L")
    luma = np.asarray(image, dtype=np.float64)
    alpha = np.clip((luma - BLACK_POINT) / (WHITE_POINT - BLACK_POINT), 0.0, 1.0)
    alpha = alpha ** 0.9
    mask = alpha > 0.03
    ys, xs = np.where(mask)
    if xs.size == 0:
        raise SystemExit(f"{source}: no paint found")
    x0, x1, y0, y1 = xs.min(), xs.max(), ys.min(), ys.max()
    pad_x = int((x1 - x0) * PADDING)
    pad_y = int((y1 - y0) * PADDING)
    x0 = max(0, x0 - pad_x)
    y0 = max(0, y0 - pad_y)
    x1 = min(alpha.shape[1] - 1, x1 + pad_x)
    y1 = min(alpha.shape[0] - 1, y1 + pad_y)
    crop = alpha[y0:y1 + 1, x0:x1 + 1]
    rgba = np.zeros(crop.shape + (4,), dtype=np.uint8)
    rgba[..., 0:3] = 255
    rgba[..., 3] = (crop * 255.0).astype(np.uint8)
    out = Image.fromarray(rgba)
    height = max(1, round(out.height * TARGET_WIDTH / out.width))
    out = out.resize((TARGET_WIDTH, height), Image.LANCZOS)
    destination.parent.mkdir(parents=True, exist_ok=True)
    out.save(destination, optimize=True)
    print(f"{destination.name}: {out.width}x{out.height}")


def main() -> int:
    if len(sys.argv) != 2:
        print(__doc__)
        return 2
    source_dir = Path(sys.argv[1])
    for name in NAMES:
        process(source_dir / f"{name}.png", OUT / f"{name}.png")
    return 0


if __name__ == "__main__":
    sys.exit(main())
