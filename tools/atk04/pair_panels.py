#!/usr/bin/env python3
"""atk-04 proof helper: crop the PASS forecast panel from a before and an after
1920x1080 capture and place them side by side at 2x (inspection only).

  python3 tools/atk04/pair_panels.py <before.png> <after.png> <out.png>
"""
import sys
from PIL import Image, ImageDraw

BOX = (1540, 600, 1920, 960)  # PASS button and the panel above it


def panel(path: str) -> Image.Image:
    crop = Image.open(path).convert("RGB").crop(BOX)
    return crop.resize((crop.width * 2, crop.height * 2), Image.NEAREST)


def main() -> None:
    before, after = panel(sys.argv[1]), panel(sys.argv[2])
    sheet = Image.new("RGB", (before.width + after.width + 24, before.height + 40), (16, 12, 10))
    sheet.paste(before, (0, 40))
    sheet.paste(after, (before.width + 24, 40))
    draw = ImageDraw.Draw(sheet)
    draw.text((8, 12), "BEFORE (base)", fill=(240, 230, 210))
    draw.text((before.width + 32, 12), "AFTER (atk-04)", fill=(240, 230, 210))
    sheet.save(sys.argv[3])


if __name__ == "__main__":
    main()
