#!/usr/bin/env python3
"""Derive VP4 production textures from the approved, unchanged source paintings.

Run `python3 tools/process_visual_pass_4_assets.py`. Green edges are un-mixed
before premultiplied-alpha resampling; monochrome pools use the rail's levels.
Ring geometry is measured on the final alpha mask (0.5 threshold, pixel centres).
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path

import numpy as np
from PIL import Image

from process_card_time_watch import key
from process_turn_order_brushes import BLACK_POINT, WHITE_POINT

ROOT = Path(__file__).resolve().parents[1]
SOURCES = ROOT / "spec/assets/visual_pass_4/sources"
OUT = ROOT / "assets/art/ui/visual_pass_4"


def resize_keyed(colour: np.ndarray, alpha: np.ndarray, size: tuple[int, int]) -> Image.Image:
    premultiplied = np.dstack((colour * alpha[..., None], alpha * 255.0)).astype(np.float32)
    small = np.dstack([
        np.asarray(Image.fromarray(premultiplied[..., i]).resize(size, Image.Resampling.LANCZOS))
        for i in range(4)
    ])
    out_alpha = np.clip(small[..., 3], 0.0, 255.0)
    out_rgb = small[..., :3] * 255.0 / np.maximum(out_alpha[..., None], 1e-3)
    out_rgb[out_alpha <= 0.5] = 0.0
    out_rgb = np.clip(out_rgb, 0.0, 255.0)
    out_rgb[..., 1] = np.minimum(out_rgb[..., 1], np.maximum(out_rgb[..., 0], out_rgb[..., 2]) * 1.02)
    return Image.fromarray(np.dstack((out_rgb, out_alpha)).astype(np.uint8))


def ring_geometry(alpha: np.ndarray) -> dict:
    solid = alpha > 127
    ys, xs = np.where(solid)
    centre = np.array([(xs.min() + xs.max() + 1) / 2, (ys.min() + ys.max() + 1) / 2])
    # Sample rays so both radii describe the band rather than isolated edge flecks.
    angles = np.linspace(0, 2 * np.pi, 720, endpoint=False)
    radii = np.arange(0, min(alpha.shape) / 2, 0.25)
    points = centre + np.stack((np.cos(angles), np.sin(angles)), axis=1)[:, None, :] * radii[None, :, None]
    pixels = points.astype(int)
    hits = solid[pixels[..., 1], pixels[..., 0]]
    if not hits.any(axis=1).all():
        raise ValueError("Ring alpha mask must have a continuous band around its opening")
    inner = radii[np.argmax(hits, axis=1)]
    outer = radii[hits.shape[1] - 1 - np.argmax(hits[:, ::-1], axis=1)] + 0.25
    return {
        "center": [round(float(v), 2) for v in centre],
        "outer_radius": round(float(np.median(outer)), 2),
        "inner_radius": round(float(np.median(inner)), 2),
        "alpha_threshold": 127,
    }


def process_keyed(name: str, target: int, square: bool = False, *, target_width: bool = False) -> Image.Image:
    rgb = np.asarray(Image.open(SOURCES / name).convert("RGB"), dtype=np.float64)
    colour, alpha = key(rgb)
    ys, xs = np.where(alpha > 0.02)
    if xs.size == 0:
        raise ValueError(f"{name}: no painting found")
    x0, x1 = max(0, xs.min() - 6), min(alpha.shape[1], xs.max() + 7)
    y0, y1 = max(0, ys.min() - 6), min(alpha.shape[0], ys.max() + 7)
    colour, alpha = colour[y0:y1, x0:x1], alpha[y0:y1, x0:x1]
    if square:
        side = max(alpha.shape)
        padding = ((int((side - alpha.shape[0]) // 2), int((side - alpha.shape[0] + 1) // 2)),
                   (int((side - alpha.shape[1]) // 2), int((side - alpha.shape[1] + 1) // 2)))
        colour = np.pad(colour, (*padding, (0, 0)))
        alpha = np.pad(alpha, padding)
    size = ((target, max(1, round(alpha.shape[0] * target / alpha.shape[1]))) if target_width
            else (max(1, round(alpha.shape[1] * target / alpha.shape[0])), target))
    output = resize_keyed(colour, alpha, size)
    output.save(OUT / name, optimize=True)
    return output


def process_pool(name: str) -> None:
    luma = np.asarray(Image.open(SOURCES / name).convert("L"), dtype=np.float64)
    alpha = np.clip((luma - BLACK_POINT) / (WHITE_POINT - BLACK_POINT), 0.0, 1.0) ** 0.9
    ys, xs = np.where(alpha > 0.03)
    if xs.size == 0:
        raise ValueError(f"{name}: no painting found")
    pad_x, pad_y = round((xs.max() - xs.min()) * 0.04), round((ys.max() - ys.min()) * 0.04)
    crop = alpha[max(0, ys.min() - pad_y):min(alpha.shape[0], ys.max() + pad_y + 1),
                 max(0, xs.min() - pad_x):min(alpha.shape[1], xs.max() + pad_x + 1)]
    size = (768, max(1, round(crop.shape[0] * 768 / crop.shape[1])))
    mask = Image.fromarray((crop * 255).astype(np.uint8)).resize(size, Image.Resampling.LANCZOS)
    output = Image.new("RGBA", size, (255, 255, 255, 0))
    output.putalpha(mask)
    output.save(OUT / name, optimize=True)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--signage-only", action="store_true", help="Process only the Scavenger banner and shelf label")
    args = parser.parse_args()
    OUT.mkdir(parents=True, exist_ok=True)
    for name, width in (("shop_banner.png", 1100), ("shelf_label.png", 360)):
        process_keyed(name, width, target_width=True)
    if args.signage_only:
        print("VP4 SIGNAGE: processed shop_banner (1100px wide), shelf_label (360px wide)")
        return
    ring = process_keyed("medallion_ring.png", 256, square=True)
    metadata = {"source": "spec/assets/visual_pass_4/sources/medallion_ring.png",
                "size": list(ring.size), **ring_geometry(np.asarray(ring)[..., 3])}
    (OUT / "medallion_ring.json").write_text(json.dumps(metadata, indent=2) + "\n")
    process_keyed("price_tag.png", 256)
    for name in ("ink_pool_a.png", "ink_pool_b.png"):
        process_pool(name)
    print("VP4 ASSETS: processed medallion_ring, ink_pool_a, ink_pool_b, price_tag, shop_banner, shelf_label")
    print(json.dumps(metadata))


if __name__ == "__main__":
    main()
