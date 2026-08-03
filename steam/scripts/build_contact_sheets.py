#!/usr/bin/env python3
"""Build compact visual-QA sheets for the Steam delivery bundle."""

from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[2]
ASSETS = ROOT / "steam" / "assets"
QA = ROOT / "steam" / "qa"
BACKGROUND = (10, 8, 14)
PANEL = (23, 18, 30)
TEXT = (239, 225, 190)
MUTED = (170, 151, 122)


def _font(size: int) -> ImageFont.FreeTypeFont | ImageFont.ImageFont:
    font_path = ROOT / "fonts" / "LabyrinthCrumble-Display.ttf"
    if font_path.exists():
        return ImageFont.truetype(str(font_path), size)
    return ImageFont.load_default()


def _fit(image: Image.Image, width: int, height: int) -> Image.Image:
    preview = image.copy()
    preview.thumbnail((width, height), Image.Resampling.LANCZOS)
    canvas = Image.new("RGB", (width, height), PANEL)
    x = (width - preview.width) // 2
    y = (height - preview.height) // 2
    if preview.mode == "RGBA":
        canvas.paste(preview, (x, y), preview)
    else:
        canvas.paste(preview.convert("RGB"), (x, y))
    return canvas


def _sheet(
    title: str,
    entries: list[tuple[str, Path]],
    output: Path,
    *,
    columns: int,
    preview_size: tuple[int, int],
) -> None:
    label_height = 74
    gap = 20
    margin = 28
    title_height = 90
    rows = (len(entries) + columns - 1) // columns
    cell_width, cell_height = preview_size
    width = margin * 2 + columns * cell_width + (columns - 1) * gap
    height = title_height + margin + rows * (cell_height + label_height) + (rows - 1) * gap + margin
    sheet = Image.new("RGB", (width, height), BACKGROUND)
    draw = ImageDraw.Draw(sheet)
    draw.text((margin, 24), title, font=_font(38), fill=TEXT)

    for index, (label, path) in enumerate(entries):
        row, column = divmod(index, columns)
        x = margin + column * (cell_width + gap)
        y = title_height + row * (cell_height + label_height + gap)
        image = Image.open(path)
        sheet.paste(_fit(image, cell_width, cell_height), (x, y))
        draw.rectangle((x, y + cell_height, x + cell_width, y + cell_height + label_height), fill=PANEL)
        draw.text((x + 14, y + cell_height + 10), label, font=_font(22), fill=TEXT)
        draw.text(
            (x + 14, y + cell_height + 40),
            f"{image.width} x {image.height}",
            font=_font(16),
            fill=MUTED,
        )

    output.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(output, quality=94, subsampling=0)
    print(output.relative_to(ROOT))


def main() -> None:
    store_entries = [
        ("Store header capsule", ASSETS / "store" / "header_capsule.jpg"),
        ("Store small capsule", ASSETS / "store" / "small_capsule.jpg"),
        ("Store main capsule", ASSETS / "store" / "main_capsule.jpg"),
        ("Store vertical capsule", ASSETS / "store" / "vertical_capsule.jpg"),
        ("Store page background", ASSETS / "store" / "page_background.jpg"),
        ("Library capsule", ASSETS / "library" / "library_capsule.jpg"),
        ("Library header", ASSETS / "library" / "library_header.jpg"),
        ("Library hero", ASSETS / "library" / "library_hero.jpg"),
        ("Transparent library logo", ASSETS / "library" / "library_logo.png"),
        ("Shortcut icon", ASSETS / "client" / "shortcut_icon.png"),
        ("App icon", ASSETS / "client" / "app_icon.jpg"),
        ("Trailer poster", ASSETS / "trailer" / "poster.jpg"),
        ("Description: Lantern Shot", ASSETS / "rich-description" / "01-lantern-shot.png"),
        ("Description: Cleaver Hook", ASSETS / "rich-description" / "02-cleaver-hook.png"),
        ("Description: Character", ASSETS / "rich-description" / "03-character-loadout.png"),
        ("Description: Map", ASSETS / "rich-description" / "04-route-map.png"),
    ]
    screenshot_entries = [
        (path.stem.replace("-", " ").title(), path)
        for path in sorted((ASSETS / "screenshots").glob("*.png"))
    ]
    _sheet(
        "Escape the Umbra — Steam asset refresh",
        store_entries,
        QA / "store-assets-contact-sheet.jpg",
        columns=3,
        preview_size=(640, 360),
    )
    _sheet(
        "Escape the Umbra — ordered Steam screenshots",
        screenshot_entries,
        QA / "screenshots-contact-sheet.jpg",
        columns=2,
        preview_size=(960, 540),
    )
    comparison_entries = [
        ("Previous — Lantern Shot", ROOT / "steam" / "source_art" / "rich-description" / "01-lantern-shot-reference.png"),
        ("Current — Lantern Shot", ASSETS / "rich-description" / "01-lantern-shot.png"),
        ("Previous — Cleaver Hook", ROOT / "steam" / "source_art" / "rich-description" / "02-cleaver-hook-reference.png"),
        ("Current — Cleaver Hook", ASSETS / "rich-description" / "02-cleaver-hook.png"),
        ("Previous — Character", ROOT / "steam" / "source_art" / "rich-description" / "03-character-loadout-reference.png"),
        ("Current — Character", ASSETS / "rich-description" / "03-character-loadout.png"),
        ("Previous — Map", ROOT / "steam" / "source_art" / "rich-description" / "04-route-map-reference.png"),
        ("Current — Map", ASSETS / "rich-description" / "04-route-map.png"),
    ]
    _sheet(
        "Steam rich-description images — previous / current",
        comparison_entries,
        QA / "rich-description-comparison.jpg",
        columns=2,
        preview_size=(780, 439),
    )


if __name__ == "__main__":
    main()
