#!/usr/bin/env python3
"""Render the trailer's finite text cards from the exact game font."""

from pathlib import Path

from PIL import Image, ImageChops, ImageColor, ImageDraw, ImageFilter, ImageFont


TRAILER_DIR = Path(__file__).resolve().parents[1]
FONT_PATH = TRAILER_DIR.parents[1] / "fonts" / "LabyrinthCrumble-Regular.ttf"
OUTPUT_DIR = TRAILER_DIR / "public" / "title-cards"
SCALE = 4

CARDS = (
    ("this-prison", "THIS PRISON", 112, "#fff0c8", 0.035),
    ("has-no-exit", "HAS NO EXIT", 112, "#f19a3e", 0.035),
    ("plan-your-descent", "PLAN YOUR DESCENT", 76, "#fff0c8", 0.028),
    ("read-the-room", "READ THE ROOM", 76, "#fff0c8", 0.028),
    ("use-the-labyrinth", "USE THE LABYRINTH", 76, "#fff0c8", 0.028),
    ("build-the-perfect-turn", "BUILD THE PERFECT TURN", 76, "#fff0c8", 0.028),
    ("bring-light-into-the-umbra", "BRING LIGHT INTO THE UMBRA", 76, "#fff0c8", 0.028),
    ("grow-stronger", "GROW STRONGER", 76, "#fff0c8", 0.028),
    (
        "shadow-dragon-waits-below",
        "THE SHADOW DRAGON WAITS BELOW",
        76,
        "#fff0c8",
        0.028,
    ),
    ("escape", "ESCAPE", 160, "#fff0c8", 0.02),
    ("the-umbra", "THE UMBRA", 160, "#b689ff", 0.02),
    ("wishlist-now-on", "WISHLIST NOW ON", 64, "#e4c36a", 0.03),
)


def render_card(slug: str, text: str, size: int, color: str, tracking_em: float) -> None:
    font = ImageFont.truetype(str(FONT_PATH), size * SCALE)
    stroke_width = max(SCALE, round(size * 0.009 * SCALE))
    tracking = size * tracking_em * SCALE
    working = Image.new("RGBA", (8192, 1024), (0, 0, 0, 0))
    draw = ImageDraw.Draw(working)
    cursor_x = 96.0
    baseline_y = 80.0

    for character in text:
        draw.text(
            (round(cursor_x), round(baseline_y)),
            character,
            font=font,
            fill=color,
            stroke_width=stroke_width,
            stroke_fill="#21140d",
        )
        cursor_x += draw.textlength(character, font=font) + tracking

    bounds = working.getchannel("A").getbbox()
    if bounds is None:
        raise RuntimeError(f"No pixels rendered for {slug}")

    padding = 8 * SCALE
    left = max(0, bounds[0] - padding)
    top = max(0, bounds[1] - padding)
    right = min(working.width, bounds[2] + padding)
    bottom = min(working.height, bounds[3] + padding)
    cropped = working.crop((left, top, right, bottom))
    output_size = (
        max(1, round(cropped.width / SCALE)),
        max(1, round(cropped.height / SCALE)),
    )
    final = cropped.resize(output_size, Image.Resampling.LANCZOS)
    final.save(OUTPUT_DIR / f"{slug}.png", optimize=True)

    # Close only the small erosion cuts in the Crumble face. Layering these pixels
    # over the original art creates a clean, filled arrival while preserving the
    # large counters in letters such as A, D, O, P, and R. Remotion then drops
    # this fill layer away in bands to reveal the game-native crumbled silhouette.
    fill_rgb = ImageColor.getrgb(color)
    fill_mask = Image.new("L", final.size)
    fill_mask.putdata(
        [
            255
            if alpha > 24
            and max(abs(red - fill_rgb[0]), abs(green - fill_rgb[1]), abs(blue - fill_rgb[2])) < 52
            else 0
            for red, green, blue, alpha in final.getdata()
        ]
    )
    closing_size = 9 if size <= 80 else 11
    filled_alpha = fill_mask.filter(ImageFilter.MaxFilter(closing_size)).filter(
        ImageFilter.MinFilter(closing_size)
    )
    fill_alpha = ImageChops.subtract(filled_alpha, fill_mask)
    fill_layer = Image.new("RGBA", final.size, (*fill_rgb, 0))
    fill_layer.putalpha(fill_alpha)
    fill_layer.save(OUTPUT_DIR / f"{slug}-fill.png", optimize=True)


def main() -> None:
    if not FONT_PATH.is_file():
        raise FileNotFoundError(FONT_PATH)
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    for card in CARDS:
        render_card(*card)
    print(
        f"Rendered {len(CARDS)} title cards and crumble-fill layers to {OUTPUT_DIR}"
    )


if __name__ == "__main__":
    main()
