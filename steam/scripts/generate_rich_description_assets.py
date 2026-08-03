#!/usr/bin/env python3
"""Derive current-build replacements for the live Steam description images."""

from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageOps


ROOT = Path(__file__).resolve().parents[2]
SCREENSHOTS = ROOT / "steam" / "assets" / "screenshots"
OUTPUT = ROOT / "steam" / "assets" / "rich-description"
TARGET_SIZE = (1560, 878)
MAPPINGS = {
    "01-lantern-shot.png": "03-lantern-shot.png",
    "02-cleaver-hook.png": "07-cleaver-hook.png",
    "03-character-loadout.png": "02-character-loadout.png",
    "04-route-map.png": "05-route-map.png",
}


def main() -> None:
    OUTPUT.mkdir(parents=True, exist_ok=True)
    for output_name, screenshot_name in MAPPINGS.items():
        source = SCREENSHOTS / screenshot_name
        if not source.is_file():
            raise FileNotFoundError(f"Capture the Steam screenshots first; missing {source}")
        with Image.open(source) as image:
            replacement = ImageOps.fit(
                image.convert("RGB"),
                TARGET_SIZE,
                method=Image.Resampling.LANCZOS,
                centering=(0.5, 0.5),
            )
            replacement.save(OUTPUT / output_name, optimize=True)
            print((OUTPUT / output_name).relative_to(ROOT))


if __name__ == "__main__":
    main()
