"""Deterministic local tone edit on a raw painting (director step; generalises maquettes/chainbound_gaoler/tone_tabard.py).

Usage: python3 tone_region.py SRC OUT CONFIG.json
CONFIG is a list of regions applied in order; each region:
  {"name": str, "box": [x0, y0, x1, y1],            raw-pixel box the edit may touch
   "seed": [x, y] | null,                           flood-fill (8-way) from here through matching pixels; null = whole box
   "min_lum": 0..1, "max_lum": 0..1,                Rec.601 luminance window of pixels that may change
   "min_chroma": 0..1, "hue_deg": [lo, hi] | null,  RGB max-min chroma floor and optional hue window
   "exclude_green": true,                           never touch key-green background
   "lab_scale": [L, a, b]}                          CIE Lab multipliers (prototype/match_palette.py conversion)
Prints the changed pixel count per region.
"""
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
from match_palette import to_lab, from_lab  # noqa: E402


def region_mask(rgb: np.ndarray, region: dict) -> np.ndarray:
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    lum = (0.299 * r + 0.587 * g + 0.114 * b) / 255.0
    chroma = (rgb.max(-1) - rgb.min(-1)) / 255.0
    candidate = np.zeros(lum.shape, bool)
    x0, y0, x1, y1 = region["box"]
    candidate[y0:y1, x0:x1] = True
    candidate &= (lum >= region.get("min_lum", 0.0)) & (lum <= region.get("max_lum", 1.0))
    candidate &= chroma >= region.get("min_chroma", 0.0)
    if region.get("hue_deg"):
        hue = np.degrees(np.arctan2(np.sqrt(3) * (g - b), 2 * r - g - b)) % 360
        lo, hi = region["hue_deg"]
        candidate &= (hue >= lo) & (hue <= hi)
    if region.get("exclude_green", True):
        candidate &= ~((g > 200) & (r < 80) & (b < 80))
    if region.get("seed") is None:
        return candidate
    sx, sy = region["seed"]
    mask = np.zeros_like(candidate)
    mask[sy, sx] = candidate[sy, sx]
    if not mask.any():
        raise ValueError(f"{region['name']}: seed {region['seed']} is not a matching pixel")
    while True:
        grown = mask.copy()
        for dy in (-1, 0, 1):
            for dx in (-1, 0, 1):
                grown |= np.roll(np.roll(mask, dy, 0), dx, 1)
        grown &= candidate
        if (grown == mask).all():
            return mask
        mask = grown


def tone(src: Path, out: Path, regions: list) -> None:
    pixels = np.asarray(Image.open(src).convert("RGBA")).astype(float)
    for region in regions:
        rgb = pixels[..., :3]
        mask = region_mask(rgb, region)
        lab = to_lab(rgb[mask]) * np.array(region["lab_scale"])
        rgb[mask] = np.clip(np.rint(from_lab(lab)), 0, 255)
        pixels[..., :3] = rgb
        print(f"{region['name']}: {int(mask.sum())} pixels toned")
    Image.fromarray(pixels.astype(np.uint8)).save(out)


if __name__ == "__main__":
    tone(Path(sys.argv[1]), Path(sys.argv[2]), json.loads(Path(sys.argv[3]).read_text()))
