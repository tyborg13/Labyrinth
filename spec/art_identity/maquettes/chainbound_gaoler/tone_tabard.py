"""Director tone edit (2026-10-13): the gaoler's tabard becomes oxblood so the rust hook stays the one hot accent.

Usage: python3 tone_tabard.py <raw front v2 1024 px> <out raw>
Only pixels inside BOX whose colour is warm and saturated change; the bone sigil, coat and outline are untouched.
"""
import sys
from pathlib import Path

import numpy as np
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "prototype"))
from match_palette import to_lab, from_lab  # noqa: E402

BOX = (395, 500, 515, 750)          # raw-pixel x0, y0, x1, y1 of the tabard below the belt
MIN_CHROMA = 0.12                   # max(rgb) - min(rgb), 0..1
HUE_DEG = (0.0, 40.0)               # warm reds/oranges only
LAB_SCALE = (0.60, 0.70, 0.50)      # L, a, b multipliers: darker, slightly less red, much less yellow -> oxblood


def tone(src: Path, out: Path) -> None:
    image = Image.open(src).convert("RGBA")
    pixels = np.asarray(image).astype(float)
    rgb = pixels[..., :3]
    high, low = rgb.max(-1), rgb.min(-1)
    chroma = (high - low) / 255.0
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    hue = np.degrees(np.arctan2(np.sqrt(3) * (g - b), 2 * r - g - b)) % 360
    box = np.zeros(chroma.shape, bool)
    x0, y0, x1, y1 = BOX
    box[y0:y1, x0:x1] = True
    mask = box & (chroma > MIN_CHROMA) & (hue >= HUE_DEG[0]) & (hue <= HUE_DEG[1])
    lab = to_lab(rgb[mask])
    lab = lab * np.array(LAB_SCALE)
    rgb[mask] = np.clip(np.rint(from_lab(lab)), 0, 255)
    pixels[..., :3] = rgb
    Image.fromarray(pixels.astype(np.uint8)).save(out)
    print(f"tabard pixels toned: {int(mask.sum())}")


if __name__ == "__main__":
    tone(Path(sys.argv[1]), Path(sys.argv[2]))
