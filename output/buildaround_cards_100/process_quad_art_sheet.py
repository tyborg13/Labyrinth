from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image

from process_card_art import DEFAULT_MASK, process


ROOT = Path(__file__).resolve().parent


def split_and_process(source: Path, ids: list[str], out_dir: Path, mask: Path = DEFAULT_MASK) -> None:
    if not 1 <= len(ids) <= 4:
        raise SystemExit("--ids must include 1 to 4 comma-separated ids")
    image = Image.open(source).convert("RGBA")
    half_w = image.width // 2
    half_h = image.height // 2
    gutter = max(4, round(min(image.width, image.height) * 0.006))
    boxes = [
        (0, 0, half_w - gutter, half_h - gutter),
        (half_w + gutter, 0, image.width, half_h - gutter),
        (0, half_h + gutter, half_w - gutter, image.height),
        (half_w + gutter, half_h + gutter, image.width, image.height),
    ]
    tmp_dir = ROOT / "tmp_quad_crops"
    tmp_dir.mkdir(parents=True, exist_ok=True)
    for card_id, box in zip(ids, boxes):
        crop_path = tmp_dir / f"{card_id}_crop.png"
        image.crop(box).save(crop_path)
        process(crop_path, out_dir / f"{card_id}.png", mask)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", required=True, type=Path)
    parser.add_argument("--ids", required=True)
    parser.add_argument("--out-dir", default=ROOT / "assets" / "art" / "cards", type=Path)
    parser.add_argument("--mask", default=DEFAULT_MASK, type=Path)
    args = parser.parse_args()
    split_and_process(args.source, [part.strip() for part in args.ids.split(",") if part.strip()], args.out_dir, args.mask)
    print(args.out_dir)


if __name__ == "__main__":
    main()
