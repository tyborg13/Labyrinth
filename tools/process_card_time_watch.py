#!/usr/bin/env python3
"""Key the painted pocket-watch body for the card time-cost badge.

The source painting was generated on flat chroma green. Alpha comes from how
far each pixel's green exceeds its red/blue, edge colours are un-mixed from the
green so no fringe survives, and the watch is cropped and downscaled with
premultiplied alpha. The dial centre and radius are written next to the
texture so the code-drawn hands and number land exactly on the painted dial.

    python3 tools/process_card_time_watch.py spec/assets/card_time_watch/watch_source.png
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets" / "art" / "ui" / "card_time_watch.png"
META = ROOT / "assets" / "art" / "ui" / "card_time_watch.json"
TARGET_HEIGHT = 176
# Green excess of pure background vs. the warmest brass in the painting.
BACKGROUND_EXCESS = 255.0
SUBJECT_EXCESS = -24.0


def key(rgb: np.ndarray) -> tuple[np.ndarray, np.ndarray]:
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    excess = g - np.maximum(r, b)
    alpha = np.clip((BACKGROUND_EXCESS - excess) / (BACKGROUND_EXCESS - SUBJECT_EXCESS), 0.0, 1.0)
    alpha[alpha < 0.04] = 0.0
    green = np.array([0.0, 255.0, 0.0])
    safe = np.maximum(alpha, 1e-4)[..., None]
    colour = (rgb - (1.0 - alpha[..., None]) * green) / safe
    colour = np.clip(colour, 0.0, 255.0)
    # Any residual spill: green may never exceed the brighter of red and blue.
    colour[..., 1] = np.minimum(colour[..., 1], np.maximum(colour[..., 0], colour[..., 2]) * 1.02)
    return colour, alpha


def dial_geometry(alpha: np.ndarray) -> tuple[float, float, float]:
    # The case is a circle below the crown and bow: its widest row gives the
    # radius, and the bottom of the case sits one radius below the centre.
    solid = alpha > 0.5
    rows = np.where(solid.any(axis=1))[0]
    widths = solid.sum(axis=1)
    widest = int(np.argmax(widths))
    xs = np.where(solid[widest])[0]
    radius = (xs.max() - xs.min() + 1) * 0.5
    centre_x = (xs.max() + xs.min()) * 0.5
    centre_y = rows.max() - radius
    return float(centre_x), float(centre_y), float(radius)


def main(source: Path) -> None:
    rgb = np.asarray(Image.open(source).convert("RGB"), dtype=np.float64)
    colour, alpha = key(rgb)
    ys, xs = np.where(alpha > 0.02)
    pad = 6
    x0, x1 = max(0, xs.min() - pad), min(rgb.shape[1], xs.max() + pad + 1)
    y0, y1 = max(0, ys.min() - pad), min(rgb.shape[0], ys.max() + pad + 1)
    colour, alpha = colour[y0:y1, x0:x1], alpha[y0:y1, x0:x1]
    cx, cy, radius = dial_geometry(alpha)
    scale = TARGET_HEIGHT / alpha.shape[0]
    size = (max(1, round(alpha.shape[1] * scale)), TARGET_HEIGHT)
    premultiplied = np.dstack([colour * alpha[..., None], alpha * 255.0]).astype(np.float32)
    channels = [Image.fromarray(premultiplied[..., i]).resize(size, Image.LANCZOS) for i in range(4)]
    small = np.dstack([np.asarray(c) for c in channels])
    out_alpha = np.clip(small[..., 3], 0.0, 255.0)
    out_rgb = np.where(out_alpha[..., None] > 0.5, small[..., :3] * 255.0 / np.maximum(out_alpha[..., None], 1e-3), 0.0)
    out = np.dstack([np.clip(out_rgb, 0, 255), out_alpha]).astype(np.uint8)
    OUT.parent.mkdir(parents=True, exist_ok=True)
    Image.fromarray(out).save(OUT, optimize=True)
    meta = {
        "source": str(source.relative_to(ROOT)) if source.is_absolute() else str(source),
        "size": list(size),
        "dial_center": [round(cx * scale, 2), round(cy * scale, 2)],
        "case_radius": round(radius * scale, 2),
    }
    META.write_text(json.dumps(meta, indent=2) + "\n")
    print(json.dumps(meta))


if __name__ == "__main__":
    if len(sys.argv) != 2:
        raise SystemExit(__doc__)
    main(Path(sys.argv[1]).resolve())
