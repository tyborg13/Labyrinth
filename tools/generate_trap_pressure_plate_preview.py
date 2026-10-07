#!/usr/bin/env python3
"""Build the review sheet for the elemental pressure-plate concepts."""

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[1]
TRAP_DIR = ROOT / "assets/art/traps"
FLOOR_DIR = ROOT / "assets/placeholders/tiles"
OUTPUT = ROOT / "output/visual_proofs/elemental_pressure_plates_perspective_fit_on_actual_tiles.png"

ELEMENTS = (
    ("FIRE", "fire", 1),
    ("ICE", "ice", 2),
    ("LIGHTNING", "lightning", 3),
    ("AIR", "air", 4),
    ("EARTH", "earth", 5),
)

SCALE = 3
MARGIN = 34
GAP = 26
HEADER_HEIGHT = 80
ROW_LABEL_HEIGHT = 30
ELEMENT_LABEL_HEIGHT = 40
BACKGROUND = (13, 15, 22, 255)
PANEL = (25, 28, 38, 255)
TEXT = (230, 232, 238, 255)
MUTED_TEXT = (149, 157, 174, 255)


def _font() -> ImageFont.ImageFont:
    return ImageFont.load_default(size=16)


def _checkerboard(size: tuple[int, int], cell_size: int = 12) -> Image.Image:
    image = Image.new("RGBA", size, (36, 40, 51, 255))
    draw = ImageDraw.Draw(image)
    alternate = (49, 54, 67, 255)
    for y in range(0, size[1], cell_size):
        for x in range(0, size[0], cell_size):
            if (x // cell_size + y // cell_size) % 2:
                draw.rectangle(
                    (x, y, min(x + cell_size - 1, size[0] - 1), min(y + cell_size - 1, size[1] - 1)),
                    fill=alternate,
                )
    return image


def _scaled(image: Image.Image, size: tuple[int, int]) -> Image.Image:
    return image.resize(size, Image.Resampling.NEAREST)


def _centered_text(
    draw: ImageDraw.ImageDraw,
    center_x: int,
    y: int,
    text: str,
    fill: tuple[int, int, int, int],
) -> None:
    font = _font()
    box = draw.textbbox((0, 0), text, font=font)
    draw.text((center_x - (box[2] - box[0]) // 2, y), text, font=font, fill=fill)


def build_sheet() -> Image.Image:
    with Image.open(TRAP_DIR / f"trap_{ELEMENTS[0][1]}.png") as reference:
        tile_size = reference.size
    preview_size = (tile_size[0] * SCALE, tile_size[1] * SCALE)
    columns = len(ELEMENTS)
    width = MARGIN * 2 + columns * preview_size[0] + (columns - 1) * GAP
    height = (
        HEADER_HEIGHT
        + ROW_LABEL_HEIGHT
        + preview_size[1]
        + ELEMENT_LABEL_HEIGHT
        + ROW_LABEL_HEIGHT
        + preview_size[1]
        + MARGIN
    )
    sheet = Image.new("RGBA", (width, height), BACKGROUND)
    draw = ImageDraw.Draw(sheet)
    draw.text((MARGIN, 22), "ELEMENTAL PRESSURE PLATES", font=_font(), fill=TEXT)
    draw.text(
        (MARGIN, 46),
        f"{tile_size[0]} x {tile_size[1]} current transparent plate canvases, shown at {SCALE}x",
        font=_font(),
        fill=MUTED_TEXT,
    )

    actual_y = HEADER_HEIGHT + ROW_LABEL_HEIGHT
    cutout_y = actual_y + preview_size[1] + ELEMENT_LABEL_HEIGHT + ROW_LABEL_HEIGHT
    draw.text((MARGIN, HEADER_HEIGHT), "ON CURRENT GAME FLOOR VARIANTS", font=_font(), fill=MUTED_TEXT)
    draw.text(
        (MARGIN, actual_y + preview_size[1] + ELEMENT_LABEL_HEIGHT),
        "THE EXACT DROP-IN PNGS (CHECKERBOARD = TRANSPARENT)",
        font=_font(),
        fill=MUTED_TEXT,
    )

    for index, (label, element, floor_variant) in enumerate(ELEMENTS):
        x = MARGIN + index * (preview_size[0] + GAP)
        trap_path = TRAP_DIR / f"trap_{element}.png"
        floor_path = FLOOR_DIR / f"base_floor_tile_{floor_variant:02d}.png"
        trap = Image.open(trap_path).convert("RGBA")
        floor = Image.open(floor_path).convert("RGBA")
        if trap.size != tile_size:
            raise ValueError(f"Expected matching plate canvases: {trap_path}={trap.size}, reference={tile_size}")
        # Legacy, unused floor variants can still have their native canvas.
        floor = floor.resize(tile_size, Image.Resampling.NEAREST)

        composite = floor.copy()
        composite.alpha_composite(trap)
        actual_panel = Image.new("RGBA", preview_size, PANEL)
        actual_panel.alpha_composite(_scaled(composite, preview_size))
        sheet.alpha_composite(actual_panel, (x, actual_y))

        checker = _checkerboard(preview_size)
        checker.alpha_composite(_scaled(trap, preview_size))
        sheet.alpha_composite(checker, (x, cutout_y))
        _centered_text(draw, x + preview_size[0] // 2, actual_y + preview_size[1] + 12, label, TEXT)

    return sheet


def main() -> None:
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    sheet = build_sheet()
    sheet.save(OUTPUT)
    print(OUTPUT)


if __name__ == "__main__":
    main()
