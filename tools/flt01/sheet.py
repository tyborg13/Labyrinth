#!/usr/bin/env python3
"""Validate the native frame pairs and arrange the exact, unscaled crops."""
import argparse
import json
from pathlib import Path

ROWS = (
    ("stone_plate", "Stone Plate"),
    ("brace", "Brace"),
    ("glass_mending", "Glass Mending"),
    ("draw_two", "Daybreak Draw 2"),
    ("card_play", "Daybreak Card Play"),
    ("illusion", "Mirror Charm"),
    ("block_loss", "Enemy hit absorbed by Block"),
    ("stoneskin_loss", "Enemy hit absorbed by Stoneskin"),
    ("stagger", "Throwing Net Stagger"),
    ("strength_buff", "Whetstone next-attack buff"),
    ("defiance", "Defiance"),
)
PHASES = ("peak", "settle")
VARIANTS = ("before", "after")
CROP = (640, 480)
FULL = (1920, 1080)
CAPTURE_FILES = {"crop": CROP, "full": FULL}
MARGIN = 16
LABEL_HEIGHT = 28


def write_contract(path):
    images = []
    for key, _ in ROWS:
        for phase in PHASES:
            for suffix, (width, height) in CAPTURE_FILES.items():
                images.append({
                    "pattern": f"{key}_{phase}_{suffix}.png",
                    "width": width,
                    "height": height,
                    "regions": [{"rect": [width // 4, height // 4, width // 2, height // 2],
                                 "min_luma_range": 8, "min_luma_stdev": 2}],
                })
    path.write_text(json.dumps({"min_images": len(images), "required_images": images}, indent=2) + "\n")


def compose(directory):
    from PIL import Image, ImageDraw, ImageFont

    width, height = CROP
    full_width = len(PHASES) * len(VARIANTS) * (width + MARGIN) + MARGIN
    row_height = height + LABEL_HEIGHT + MARGIN
    sheet = Image.new("RGB", (full_width, MARGIN + LABEL_HEIGHT + len(ROWS) * row_height), "#160f0d")
    ink = ImageDraw.Draw(sheet)
    font = ImageFont.load_default(size=16)
    for phase_index, phase in enumerate(PHASES):
        for variant_index, variant in enumerate(VARIANTS):
            column = phase_index * len(VARIANTS) + variant_index
            x = MARGIN + column * (width + MARGIN)
            ink.text((x, MARGIN), f"{variant.title()} | {phase.title()}", font=font, fill="#f8f0da")
    for row, (key, label) in enumerate(ROWS):
        y = MARGIN + LABEL_HEIGHT + row * row_height
        ink.text((MARGIN, y), label, font=font, fill="#f8f0da")
        for phase_index, phase in enumerate(PHASES):
            for variant_index, variant in enumerate(VARIANTS):
                column = phase_index * len(VARIANTS) + variant_index
                x = MARGIN + column * (width + MARGIN)
                stem = directory / variant / f"{key}_{phase}"
                for suffix, expected in CAPTURE_FILES.items():
                    path = stem.with_name(f"{stem.name}_{suffix}.png")
                    with Image.open(path) as image:
                        if image.size != expected:
                            raise ValueError(f"{path} is {image.size}, expected {expected}")
                        if suffix == "crop":
                            sheet.paste(image.convert("RGB"), (x, y + LABEL_HEIGHT))
    path = directory / "comparison.png"
    sheet.save(path)
    print(path)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("path", type=Path)
    parser.add_argument("--contract", action="store_true", help="write the visual probe runner contract")
    arguments = parser.parse_args()
    (write_contract if arguments.contract else compose)(arguments.path)
