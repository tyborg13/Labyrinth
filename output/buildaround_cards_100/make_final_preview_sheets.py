from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

from render_buildaround_gallery import CARDS


ROOT = Path(__file__).resolve().parent
PREVIEW_DIR = ROOT / "card_widget_previews"
OUT_PREFIX = "buildaround_card_sheet"
FONT_TITLE = "/System/Library/Fonts/Supplemental/Georgia Bold.ttf"
FONT_BOLD = "/System/Library/Fonts/Supplemental/Arial Bold.ttf"
FONT_REGULAR = "/System/Library/Fonts/Supplemental/Arial.ttf"


def font(path: str, size: int) -> ImageFont.FreeTypeFont:
    try:
        return ImageFont.truetype(path, size)
    except OSError:
        return ImageFont.load_default()


def sheet_background(size: tuple[int, int]) -> Image.Image:
    w, h = size
    image = Image.new("RGB", size, "#1e1917")
    draw = ImageDraw.Draw(image)
    for y in range(h):
        t = y / max(1, h - 1)
        r = int(29 * (1 - t) + 55 * t)
        g = int(24 * (1 - t) + 42 * t)
        b = int(22 * (1 - t) + 34 * t)
        draw.line((0, y, w, y), fill=(r, g, b))
    return image


def main() -> None:
    cols = 4
    rows = 5
    per_sheet = cols * rows
    card_w, card_h = 294, 396
    gap_x, gap_y = 28, 40
    margin = 36
    header_h = 88
    footer_h = 32
    sheet_w = margin * 2 + cols * card_w + (cols - 1) * gap_x
    sheet_h = header_h + rows * card_h + (rows - 1) * gap_y + footer_h
    for sheet_index in range(0, len(CARDS), per_sheet):
        sheet_no = sheet_index // per_sheet + 1
        subset = CARDS[sheet_index:sheet_index + per_sheet]
        sheet = sheet_background((sheet_w, sheet_h))
        draw = ImageDraw.Draw(sheet)
        draw.text((margin, 24), "Escape the Umbra - 100 Text Build-Around Staged Cards",
                  font=font(FONT_TITLE, 25), fill="#f2dec0")
        draw.text((margin, 56), f"Sheet {sheet_no} of 5 | Cards {sheet_index + 1:03d}-{sheet_index + len(subset):03d}",
                  font=font(FONT_REGULAR, 16), fill="#cdb894")
        for local_index, card in enumerate(subset):
            number = sheet_index + local_index + 1
            preview_path = PREVIEW_DIR / f"{card['id']}_card.png"
            preview = Image.open(preview_path).convert("RGB")
            row = local_index // cols
            col = local_index % cols
            x = margin + col * (card_w + gap_x)
            y = header_h + row * (card_h + gap_y)
            sheet.paste(preview, (x, y))
            badge = f"{number:03d}"
            draw.rounded_rectangle((x + 8, y + 8, x + 56, y + 31), radius=7, fill="#20170f", outline="#d1b06b", width=1)
            draw.text((x + 18, y + 12), badge, font=font(FONT_BOLD, 12), fill="#f6e2b8")
        sheet.save(ROOT / f"{OUT_PREFIX}_{sheet_no:02d}.png", optimize=True)
        print(ROOT / f"{OUT_PREFIX}_{sheet_no:02d}.png")


if __name__ == "__main__":
    main()
