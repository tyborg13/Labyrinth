#!/usr/bin/env python3
"""Generate the complete Steam image set from current Escape the Umbra art.

The title-bearing images deliberately mirror the accepted Steam compositions,
but render the two-row title with the same font, colors, offsets, outlines, and
subtle stone texture used by the current main menu.
"""

from __future__ import annotations

import math
import random
from pathlib import Path

from PIL import Image, ImageDraw, ImageEnhance, ImageFont, ImageOps


REPO_ROOT = Path(__file__).resolve().parents[2]
STEAM_ROOT = REPO_ROOT / "steam"
OUTPUT_ROOT = STEAM_ROOT / "assets"
SOURCE_ROOT = STEAM_ROOT / "source_art"

KEY_ART = REPO_ROOT / "assets" / "art" / "ui" / "main_menu_umbra_dragon.png"
FONT_PATH = REPO_ROOT / "fonts" / "LabyrinthCrumble-Display.ttf"
LIBRARY_HERO_REFERENCE = SOURCE_ROOT / "library_hero_reference.jpg"
PAGE_BACKGROUND_REFERENCE = SOURCE_ROOT / "page_background_reference.jpg"
SHORTCUT_ICON_REFERENCE = SOURCE_ROOT / "shortcut_icon_reference.png"
APP_ICON_REFERENCE = SOURCE_ROOT / "app_icon_reference.jpg"

SCALE = 4
BASE_FONT_SIZE = 238
LINE_SPACING = -8
ROW_OFFSET_FACTOR = 0.72
WORD_GAP_FACTOR = 0.10

FACE_STOPS = (
    (0.00, (255, 247, 207)),
    (0.26, (255, 224, 142)),
    (0.56, (221, 133, 62)),
    (0.80, (133, 49, 31)),
    (1.00, (45, 11, 36)),
)


def _ensure_inputs() -> None:
    for path in (
        KEY_ART,
        FONT_PATH,
        LIBRARY_HERO_REFERENCE,
        PAGE_BACKGROUND_REFERENCE,
        SHORTCUT_ICON_REFERENCE,
        APP_ICON_REFERENCE,
    ):
        if not path.is_file():
            raise FileNotFoundError(path)


def _interpolate_color(position: float) -> tuple[int, int, int]:
    for index in range(len(FACE_STOPS) - 1):
        left_position, left_color = FACE_STOPS[index]
        right_position, right_color = FACE_STOPS[index + 1]
        if position <= right_position:
            span = max(right_position - left_position, 0.0001)
            amount = max(0.0, min(1.0, (position - left_position) / span))
            return tuple(
                round(left_color[channel] + (right_color[channel] - left_color[channel]) * amount)
                for channel in range(3)
            )
    return FACE_STOPS[-1][1]


def _title_operations() -> tuple[list[tuple[str, ImageFont.FreeTypeFont, float, float]], tuple[int, int]]:
    base_size = BASE_FONT_SIZE * SCALE
    fonts = (
        ImageFont.truetype(str(FONT_PATH), base_size),
        ImageFont.truetype(str(FONT_PATH), round(base_size * 0.52)),
        ImageFont.truetype(str(FONT_PATH), base_size),
    )
    texts = ("ESCAPE", "THE", "UMBRA")
    scratch = Image.new("L", (1, 1))
    draw = ImageDraw.Draw(scratch)
    bounds = [draw.textbbox((0, 0), text, font=font) for text, font in zip(texts, fonts)]
    widths = [right - left for left, _top, right, _bottom in bounds]
    heights = [bottom - top for _left, top, _right, bottom in bounds]
    # Godot's layout uses Font.get_height(), not the visible glyph bounds, for
    # the second-row baseline. Pillow's ascent + descent is the matching metric.
    row_zero_height = sum(fonts[0].getmetrics())
    row_one_y = row_zero_height + LINE_SPACING * SCALE
    row_one_x = BASE_FONT_SIZE * ROW_OFFSET_FACTOR * SCALE
    gap = BASE_FONT_SIZE * WORD_GAP_FACTOR * SCALE

    top_lefts = (
        (0.0, 0.0),
        (row_one_x, row_one_y),
        (row_one_x + widths[1] + gap, row_one_y),
    )
    operations = []
    for text, font, bound, top_left in zip(texts, fonts, bounds, top_lefts):
        left, top, _right, _bottom = bound
        operations.append((text, font, top_left[0] - left, top_left[1] - top))
    width = math.ceil(max(widths[0], row_one_x + widths[1] + gap + widths[2]))
    height = math.ceil(row_one_y + max(heights[1], heights[2]))
    return operations, (width, height)


def _draw_title_layer(
    image: Image.Image,
    operations: list[tuple[str, ImageFont.FreeTypeFont, float, float]],
    *,
    fill: str | int,
    stroke_fill: str | int,
    stroke_width: int,
    offset: tuple[int, int] = (0, 0),
) -> None:
    draw = ImageDraw.Draw(image)
    for text, font, x, y in operations:
        draw.text(
            (round(x + offset[0]), round(y + offset[1])),
            text,
            font=font,
            fill=fill,
            stroke_fill=stroke_fill,
            stroke_width=stroke_width,
        )


def render_title_logo() -> Image.Image:
    operations, title_size = _title_operations()
    padding = 20 * SCALE
    shifted_operations = [
        (text, font, x + padding, y + padding)
        for text, font, x, y in operations
    ]
    canvas_size = (title_size[0] + padding * 2, title_size[1] + padding * 2)
    logo = Image.new("RGBA", canvas_size, (0, 0, 0, 0))

    _draw_title_layer(
        logo,
        shifted_operations,
        fill="#5b2d74",
        stroke_fill="#0b040f",
        stroke_width=9 * SCALE,
        offset=(8 * SCALE, 7 * SCALE),
    )
    _draw_title_layer(
        logo,
        shifted_operations,
        fill="#c0522f",
        stroke_fill="#170508",
        stroke_width=6 * SCALE,
        offset=(3 * SCALE, 2 * SCALE),
    )
    _draw_title_layer(
        logo,
        shifted_operations,
        fill="#ffd98d",
        stroke_fill="#210725",
        stroke_width=5 * SCALE,
    )

    face_mask = Image.new("L", canvas_size, 0)
    _draw_title_layer(
        face_mask,
        shifted_operations,
        fill=255,
        stroke_fill=0,
        stroke_width=0,
    )
    gradient = Image.new("RGBA", canvas_size)
    gradient_draw = ImageDraw.Draw(gradient)
    top = padding
    bottom = max(top + 1, padding + title_size[1])
    randomizer = random.Random(0x554D4252)
    for y in range(canvas_size[1]):
        position = max(0.0, min(1.0, (y - top) / (bottom - top)))
        red, green, blue = _interpolate_color(position)
        grain = randomizer.uniform(-0.035, 0.035)
        gradient_draw.line(
            (0, y, canvas_size[0], y),
            fill=(
                round(max(0, min(255, red * (1.0 + grain)))),
                round(max(0, min(255, green * (1.0 + grain)))),
                round(max(0, min(255, blue * (1.0 + grain)))),
                255,
            ),
        )
    gradient.putalpha(face_mask)
    logo.alpha_composite(gradient)

    bounds = logo.getchannel("A").getbbox()
    if bounds is None:
        raise RuntimeError("The current title font rendered no visible pixels")
    return logo.crop(bounds)


def _fit_logo(logo: Image.Image, width: int, height: int | None = None) -> Image.Image:
    maximum_height = height if height is not None else 100000
    scale = min(width / logo.width, maximum_height / logo.height)
    return logo.resize(
        (max(1, round(logo.width * scale)), max(1, round(logo.height * scale))),
        Image.Resampling.LANCZOS,
    )


def _cover(source: Image.Image, size: tuple[int, int], centering: tuple[float, float] = (0.5, 0.5)) -> Image.Image:
    return ImageOps.fit(source.convert("RGB"), size, method=Image.Resampling.LANCZOS, centering=centering)


def _darken_for_logo(image: Image.Image, strength: float = 0.28) -> Image.Image:
    width, height = image.size
    veil = Image.new("RGBA", image.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(veil)
    for x in range(width):
        amount = max(0.0, 1.0 - x / max(width * 0.72, 1.0))
        alpha = round(255 * strength * amount * amount)
        draw.line((x, 0, x, height), fill=(5, 2, 10, alpha))
    return Image.alpha_composite(image.convert("RGBA"), veil).convert("RGB")


def _save_title_composite(
    key_art: Image.Image,
    logo: Image.Image,
    output: Path,
    size: tuple[int, int],
    *,
    logo_width_fraction: float,
    logo_height_fraction: float,
    x_fraction: float,
    y_fraction: float | None = None,
    bottom_fraction: float | None = None,
    centering: tuple[float, float] = (0.5, 0.5),
) -> None:
    background = _darken_for_logo(_cover(key_art, size, centering))
    placed_logo = _fit_logo(
        logo,
        round(size[0] * logo_width_fraction),
        round(size[1] * logo_height_fraction),
    )
    x = round(size[0] * x_fraction)
    if bottom_fraction is not None:
        y = size[1] - placed_logo.height - round(size[1] * bottom_fraction)
    else:
        y = round(size[1] * (y_fraction or 0.0))
    background.paste(placed_logo, (x, y), placed_logo)
    output.parent.mkdir(parents=True, exist_ok=True)
    background.save(output, quality=95, subsampling=0, optimize=True)


def _save_library_logo(logo: Image.Image) -> None:
    output = Image.new("RGBA", (1280, 720), (0, 0, 0, 0))
    fitted = _fit_logo(logo, 1120, 430)
    output.alpha_composite(
        fitted,
        ((output.width - fitted.width) // 2, (output.height - fitted.height) // 2),
    )
    destination = OUTPUT_ROOT / "library" / "library_logo.png"
    destination.parent.mkdir(parents=True, exist_ok=True)
    output.save(destination, optimize=True)


def _save_reference_assets() -> None:
    page_background = Image.open(PAGE_BACKGROUND_REFERENCE).convert("RGB")
    page_background = _cover(page_background, (1438, 810))
    page_background = ImageEnhance.Contrast(page_background).enhance(1.01)
    page_background.save(
        OUTPUT_ROOT / "store" / "page_background.jpg",
        quality=95,
        subsampling=0,
        optimize=True,
    )

    library_hero = Image.open(LIBRARY_HERO_REFERENCE).convert("RGB")
    library_hero = _cover(library_hero, (3840, 1240))
    library_hero.save(
        OUTPUT_ROOT / "library" / "library_hero.jpg",
        quality=95,
        subsampling=0,
        optimize=True,
    )


def _save_client_icons() -> None:
    shortcut_icon = Image.open(SHORTCUT_ICON_REFERENCE).convert("RGBA")
    shortcut_icon = ImageOps.fit(shortcut_icon, (512, 512), method=Image.Resampling.LANCZOS)
    shortcut_icon.save(OUTPUT_ROOT / "client" / "shortcut_icon.png", optimize=True)
    app_icon = Image.open(APP_ICON_REFERENCE).convert("RGB")
    app_icon = ImageOps.fit(app_icon, (184, 184), method=Image.Resampling.LANCZOS)
    app_icon.save(
        OUTPUT_ROOT / "client" / "app_icon.jpg",
        quality=95,
        subsampling=0,
        optimize=True,
    )


def main() -> None:
    _ensure_inputs()
    for directory in (
        OUTPUT_ROOT / "store",
        OUTPUT_ROOT / "library",
        OUTPUT_ROOT / "client",
    ):
        directory.mkdir(parents=True, exist_ok=True)

    key_art = Image.open(KEY_ART).convert("RGB")
    logo = render_title_logo()

    composites = (
        ("store/header_capsule.jpg", (920, 430), 0.54, 0.48, 0.025, 0.035, None, (0.5, 0.5)),
        ("store/small_capsule.jpg", (462, 174), 0.55, 0.72, 0.025, 0.035, None, (0.5, 0.5)),
        ("store/main_capsule.jpg", (1232, 706), 0.55, 0.40, 0.025, 0.045, None, (0.5, 0.5)),
        ("store/vertical_capsule.jpg", (748, 896), 0.86, 0.27, 0.045, None, 0.035, (0.5, 0.5)),
        ("library/library_capsule.jpg", (600, 900), 0.88, 0.24, 0.045, None, 0.035, (0.5, 0.5)),
        ("library/library_header.jpg", (920, 430), 0.54, 0.48, 0.025, 0.035, None, (0.5, 0.5)),
    )
    for relative, size, width, height, x, y, bottom, centering in composites:
        _save_title_composite(
            key_art,
            logo,
            OUTPUT_ROOT / relative,
            size,
            logo_width_fraction=width,
            logo_height_fraction=height,
            x_fraction=x,
            y_fraction=y,
            bottom_fraction=bottom,
            centering=centering,
        )

    _save_library_logo(logo)
    _save_reference_assets()
    _save_client_icons()
    print(f"Generated 11 current-build Steam image assets in {OUTPUT_ROOT}")


if __name__ == "__main__":
    main()
