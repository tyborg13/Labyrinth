from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image, ImageEnhance


ROOT = Path(__file__).resolve().parent
REPO = ROOT.parents[1]
DEFAULT_MASK = REPO / "assets" / "art" / "cards" / "quick_stab.png"


def cover_resize(image: Image.Image, size: tuple[int, int]) -> Image.Image:
    target_w, target_h = size
    source_w, source_h = image.size
    scale = max(target_w / source_w, target_h / source_h)
    resized = image.resize((round(source_w * scale), round(source_h * scale)), Image.Resampling.LANCZOS)
    left = (resized.width - target_w) // 2
    top = (resized.height - target_h) // 2
    return resized.crop((left, top, left + target_w, top + target_h))


def process(source: Path, out: Path, mask_path: Path = DEFAULT_MASK) -> None:
    source_image = Image.open(source).convert("RGBA")
    mask_source = Image.open(mask_path).convert("RGBA").resize((256, 144), Image.Resampling.LANCZOS)
    alpha = mask_source.getchannel("A")
    art = cover_resize(source_image, (256, 144)).convert("RGBA")
    art = ImageEnhance.Color(art).enhance(0.92)
    art = ImageEnhance.Contrast(art).enhance(1.08)
    art.putalpha(alpha)
    out.parent.mkdir(parents=True, exist_ok=True)
    art.save(out, optimize=True)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", required=True, type=Path)
    parser.add_argument("--out", required=True, type=Path)
    parser.add_argument("--mask", default=DEFAULT_MASK, type=Path)
    args = parser.parse_args()
    process(args.source, args.out, args.mask)
    print(args.out)


if __name__ == "__main__":
    main()
