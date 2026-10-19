"""Director-authored crucible ownership masks for the Slag Mortar (rr-22 feedback 2).

The crucible owns every opaque pixel inside its polygon: the iron rim and pot body, the molten slag and the leather
straps where they lie on the pot. It also owns the rim's own dark outline where the pot meets the background: opaque
pixels within 2 px of the polygon and within 2 px of transparent background that are dark (max channel < 70) or
grey (saturation < 0.30). That never reaches the head's or the shoulder's outline where they overlap the pot. Head, shoulder and harness skin outside the polygon belong to their own pieces.
Coordinates are on the 255 px processed paintings (spec/art_identity/jobs/slag_mortar/mq9_<view>).
"""
from pathlib import Path
import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[4]
POLYGONS = {
    "front": [(133, 37), (148, 32), (163, 32), (185, 39), (200, 47), (212, 57), (216, 66), (216, 76), (212, 84),
              (206, 95), (200, 104), (196, 110), (190, 101), (182, 97), (165, 97), (152, 94), (147, 87), (140, 86),
              (130, 82), (124, 78), (123, 64), (125, 52), (128, 44)],
    "rear": [(37, 58), (42, 48), (50, 38), (62, 31), (75, 27), (95, 23), (115, 22), (125, 25), (130, 35), (131, 45),
             (130, 55), (131, 70), (130, 85), (125, 95), (121, 104), (115, 108), (100, 112), (85, 112), (70, 110),
             (60, 105), (55, 98), (52, 90), (48, 82), (42, 75), (38, 68)],
}


def mask(view: str) -> Image.Image:
    art = Image.open(ROOT / f"spec/art_identity/jobs/slag_mortar/mq9_{view}/processed.png").convert("RGBA")
    poly = Image.new("L", art.size, 0)
    ImageDraw.Draw(poly).polygon(POLYGONS[view], fill=255, outline=255)
    rgba = np.asarray(art).astype(int)
    opaque = rgba[..., 3] > 0
    inside = (np.asarray(poly) > 0) & opaque
    hi = rgba[..., :3].max(axis=2)
    lo = rgba[..., :3].min(axis=2)
    rim_like = (hi < 70) | ((hi - lo) / np.maximum(hi, 1) < 0.30)
    outline = opaque & _grow(~opaque, 2) & _grow(inside, 2) & rim_like
    return Image.fromarray(((inside | outline) * 255).astype(np.uint8))


def _grow(mask: np.ndarray, steps: int) -> np.ndarray:
    for _ in range(steps):
        grown = mask.copy()
        grown[1:] |= mask[:-1]
        grown[:-1] |= mask[1:]
        grown[:, 1:] |= mask[:, :-1]
        grown[:, :-1] |= mask[:, 1:]
        mask = grown
    return mask


if __name__ == "__main__":
    for view in POLYGONS:
        out = Path(__file__).with_name(f"crucible_mask_{view}.png")
        mask(view).save(out)
        print(out)
