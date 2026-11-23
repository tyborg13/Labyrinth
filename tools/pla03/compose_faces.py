#!/usr/bin/env python3
"""Compose the playability mock faces (2026-11-20) onto real card captures.

Inputs: old_captures/ from mock_faces_probe.gd (hand_<id>.png, hover_<id>.png,
their *_blank.png twins with the icon rows hidden, manifest.json).
New face = the blank capture (the card's own parchment and emblem, as the
engine drew it) + a target chip + one sentence with inline icons, laid out in
the card's local units and drawn at the card's on-screen scale.

Type: fonts/LabyrinthCrumble-Text.ttf at the Rite rules size (16 local, ink
#503d2c, centred, wrap width 162 local, line pitch 18 local), laid out with
unhinted advances as Godot does (checked against the captured Rite text),
supersampled 4x. Chip: LabyrinthCrumble-UI at 14 local in the title ink
#39271b on a plate in the nameplate's colours (dark border, tan rim, light fill).
"""

from __future__ import annotations

import json
import os
import sys

from fontTools.ttLib import TTFont
from PIL import Image, ImageDraw, ImageFilter, ImageFont

RELEASE = "/Users/borgerding/workspace/Labyrinth.worktrees/release"
ROOT = "/private/tmp/labyrinth_codex/playability/mocks"
CAPTURES = os.path.join(ROOT, "old_captures")
ICONS = os.path.join(RELEASE, "assets/art/icons")
TEXT_FONT = os.path.join(RELEASE, "fonts/LabyrinthCrumble-Text.ttf")
UI_FONT = os.path.join(RELEASE, "fonts/LabyrinthCrumble-UI.ttf")

SS = 4  # supersampling factor
NBSP = " "

# Local card units (the widget is 250x352 and is scaled on screen).
TEXT_SIZE = 16.0          # card_widget._rules_text_font_size() at base width
LINE_PITCH = 18.0         # round(16 * (850 + 250) / 1000), as Godot lays it out
TEXT_WIDTH = 162.0        # card_widget._rules_text_width()
INK = (0x50, 0x3D, 0x2C, 255)          # card_widget.RULES_TEXT_COLOR
TITLE_INK = (0x39, 0x27, 0x1B, 255)    # card title ink
ICON_CAP_RATIO = 1.25     # inline icon visible height / cap height
CHIP_TEXT_SIZE = 14.0     # UiTypography.SIZE_CAPTION
CHIP_HEIGHT = 24.0
CHIP_PAD = 6.0
CHIP_ICON = 17.0
CHIP_RANGE_ICON = 15.0
CHIP_RADIUS = 6.0
CHIP_MAX_WIDTH = 186.0    # text width plus the comfort inset either side
CHIP_BORDER = (57, 36, 21, 255)        # nameplate border (sampled)
CHIP_RIM = (175, 131, 86, 255)         # nameplate inner shading (sampled)
CHIP_FILL = (211, 182, 147, 255)       # nameplate light fill (sampled)
TOP_PAD = 3.0
CHIP_GAP = 6.0
CROP_MARGIN = (12.0, 20.0, 12.0, 8.0)  # left, top, right, bottom (local)

ORDER = [
    "dust_devil", "magma_vent", "discharge", "beacon", "worldroot_stride", "palm_strike",
    "frost_heave", "shatter", "cyclone_seal", "squall_shot", "tectonic_maul", "sidestep_slash",
]

# Chip: list of label variants (first that fits CHIP_MAX_WIDTH wins).
SPEC: dict[str, dict | None] = {
    "dust_devil": {
        "chip": {"icon": "surface_rubble", "labels": ["Rubble"], "range": 3},
        "text": "{burst}Burst it: Push~{push}2 and Expose~{expose}4.",
    },
    "magma_vent": {
        "chip": {"icon": "surface_rubble", "labels": ["Rubble"], "range": 3},
        "text": "Burst it for~{burst}7. It becomes~{surface_fire}Fire.",
    },
    "discharge": {
        "chip": {"icon": "surface_electrified", "labels": ["Electrified"], "range": 4},
        "text": "Burst its whole network for~{burst}5 Lightning damage.",
    },
    "beacon": {
        "chip": {"icon": None, "labels": ["Tile"], "range": 4},
        "text": "Create Light~{illuminate}2 there. Draw~{draw}1.",
    },
    "worldroot_stride": {
        "chip": None,
        "text": "Move~{move}3 and leave {surface_rubble}Rubble where you arrive. "
                "Gain~{stoneskin}6 Stoneskin, or 9 if Rubble was already there.",
    },
    "palm_strike": None,  # control: icon rows stay
    "frost_heave": {
        "chip": {"icon": "surface_ice", "labels": ["Ice under an enemy", "Ice under enemy"], "range": 3},
        "text": "Burst the Ice for~{burst}6. The enemy on it is {immobilize}Immobilized.",
    },
    "shatter": {
        "chip": {"icon": None, "labels": ["Enemy"], "range": 3},
        "text": "Deal 5 Ice damage. If it stands on {surface_ice}Ice, Burst the Ice for~{burst}5.",
    },
    "cyclone_seal": {
        "chip": {"icon": None, "labels": ["Tile"], "range": 3},
        "text": "{exhaust}Exhaust. Pull enemies within 3 tiles up to~{pull}3 toward it, then deal 9 to them.",
    },
    "squall_shot": {
        "chip": {"icon": None, "labels": ["Tile"], "range": 3},
        "text": "Deal 2 in a cross and Push~{push}1 away from the center.",
    },
    "tectonic_maul": {
        "chip": None,
        "text": "Strike for~{melee}11 and leave {surface_rubble}Rubble under the target. "
                "Target on Rubble: 15 and Stagger~{stagger}3.",
    },
    "sidestep_slash": None,  # control: icon rows stay
}

NAMES = {
    "dust_devil": "Dust Devil", "magma_vent": "Magma Vent", "discharge": "Discharge", "beacon": "Beacon",
    "worldroot_stride": "Worldroot Stride", "palm_strike": "Palm Strike", "frost_heave": "Frost Heave",
    "shatter": "Shatter", "cyclone_seal": "Cyclone Seal", "squall_shot": "Squall",
    "tectonic_maul": "Tectonic Maul", "sidestep_slash": "Sidestep Slash",
}


class Face:
    """Unhinted advance layout for one font (Godot draws card text this way)."""

    def __init__(self, path: str):
        self.path = path
        tt = TTFont(path)
        self.cmap = tt.getBestCmap()
        self.hmtx = tt["hmtx"]
        self.upm = tt["head"].unitsPerEm
        self.ascent = tt["hhea"].ascent / self.upm
        self.descent = -tt["hhea"].descent / self.upm
        self.cap = tt["OS/2"].sCapHeight / self.upm
        self._pil: dict[int, ImageFont.FreeTypeFont] = {}

    def pil(self, px: float) -> ImageFont.FreeTypeFont:
        key = int(round(px))
        if key not in self._pil:
            self._pil[key] = ImageFont.truetype(self.path, key)
        return self._pil[key]

    def advance(self, ch: str) -> float:
        if ch == NBSP:
            ch = " "
        return self.hmtx[self.cmap[ord(ch)]][0] / self.upm

    def width(self, text: str, size: float) -> float:
        return sum(self.advance(c) for c in text) * size

    def draw(self, draw: ImageDraw.ImageDraw, x: float, baseline: float, text: str, size: float, fill) -> float:
        font = self.pil(size)
        for ch in text:
            if ch not in (" ", NBSP):
                draw.text((round(x), round(baseline)), ch, font=font, fill=fill, anchor="ls")
            x += self.advance(ch) * size
        return x


TEXT = Face(TEXT_FONT)
UI = Face(UI_FONT)
_icon_cache: dict[str, Image.Image] = {}


def icon(name: str) -> Image.Image:
    if name not in _icon_cache:
        im = Image.open(os.path.join(ICONS, name + ".png")).convert("RGBA")
        bbox = im.getchannel("A").point(lambda a: 255 if a > 24 else 0).getbbox()
        _icon_cache[name] = im.crop(bbox) if bbox else im
    return _icon_cache[name]


def icon_at_height(name: str, height: float) -> Image.Image:
    src = icon(name)
    h = max(1, int(round(height)))
    w = max(1, int(round(src.width * h / src.height)))
    return src.resize((w, h), Image.LANCZOS)


# ---------------------------------------------------------------- sentence
def parse_word(word: str) -> list[tuple[str, str]]:
    """'{push}2' -> [('icon','push'), ('text','2')]; '~' is a no-break space."""
    parts: list[tuple[str, str]] = []
    i = 0
    buf = ""
    while i < len(word):
        if word[i] == "{":
            j = word.index("}", i)
            if buf:
                parts.append(("text", buf))
                buf = ""
            parts.append(("icon", word[i + 1:j]))
            i = j + 1
        else:
            buf += NBSP if word[i] == "~" else word[i]
            i += 1
    if buf:
        parts.append(("text", buf))
    return parts


def word_metrics(parts, size: float, icon_h: float):
    """Width of a word in px and its pieces with x offsets."""
    x = 0.0
    pieces = []
    for kind, value in parts:
        if kind == "icon":
            if pieces and pieces[-1][0] == "text" and not pieces[-1][1].endswith(NBSP):
                x += 0.06 * size
            img = icon_at_height(value, icon_h)
            pieces.append(("icon", value, x, img))
            x += img.width + 0.07 * size
        else:
            pieces.append(("text", value, x, None))
            x += TEXT.width(value, size)
    return x, pieces


def layout_sentence(markup: str, size: float, width: float, icon_h: float):
    words = markup.split(" ")
    # Keep the last two words together, as card_widget does for Rite text.
    if len(words) >= 2:
        words = words[:-2] + [words[-2] + "~" + words[-1]]
    space = TEXT.width(" ", size)
    lines: list[list] = [[]]
    line_w = 0.0
    for word in words:
        w, pieces = word_metrics(parse_word(word), size, icon_h)
        add = w if not lines[-1] else space + w
        if lines[-1] and line_w + add > width + 0.01:
            lines.append([])
            line_w = 0.0
            add = w
        lines[-1].append((w, pieces))
        line_w += add
    return lines, space


def draw_sentence(layer: Image.Image, markup: str, scale: float, center_x: float, top: float) -> dict:
    """Draw on a supersampled layer; coords are in layer px. Returns metrics."""
    k = scale * SS
    size = TEXT_SIZE * k
    width = TEXT_WIDTH * k
    pitch = LINE_PITCH * k
    cap = TEXT.cap * size
    icon_h = cap * ICON_CAP_RATIO
    lines, space = layout_sentence(markup, size, width, icon_h)
    draw = ImageDraw.Draw(layer)
    ascent_px = round(TEXT.ascent * TEXT_SIZE) * k  # Godot rounds metrics at the label size
    widest = 0.0
    for index, line in enumerate(lines):
        line_w = sum(w for w, _ in line) + space * (len(line) - 1)
        widest = max(widest, line_w)
        x = center_x - line_w / 2.0
        baseline = top + index * pitch + ascent_px
        for w, pieces in line:
            for kind, value, dx, img in pieces:
                if kind == "text":
                    TEXT.draw(draw, x + dx, baseline, value, size, INK)
                else:
                    y = baseline - cap / 2.0 - img.height / 2.0
                    layer.alpha_composite(img, (int(round(x + dx)), int(round(y))))
            x += w + space
    line_text = [" ".join("".join(p[1] if p[0] == "text" else "[%s]" % p[1] for p in pieces)
                          for _, pieces in line).replace(NBSP, " ") for line in lines]
    return {"lines": len(lines), "height": len(lines) * pitch, "widest": widest / k, "line_text": line_text}


# ---------------------------------------------------------------- chip
def chip_layout(chip: dict, k: float):
    size = CHIP_TEXT_SIZE * k
    pad = CHIP_PAD * k
    for label in chip["labels"]:
        items = []
        x = pad
        if chip.get("icon"):
            img = icon_at_height(chip["icon"], CHIP_ICON * k)
            items.append(("icon", img, x))
            x += img.width + 3.0 * k
        items.append(("text", label, x))
        x += UI.width(label, size) + 7.0 * k
        rimg = icon_at_height("range", CHIP_RANGE_ICON * k)
        items.append(("icon", rimg, x))
        x += rimg.width + 2.0 * k
        number = str(chip["range"])
        items.append(("text", number, x))
        x += UI.width(number, size) + pad
        if x / k <= CHIP_MAX_WIDTH or label == chip["labels"][-1]:
            return label, items, x
    raise AssertionError


def draw_chip(layer: Image.Image, chip: dict, scale: float, center_x: float, top: float) -> dict:
    k = scale * SS
    label, items, width = chip_layout(chip, k)
    height = CHIP_HEIGHT * k
    left = center_x - width / 2.0
    box = [left, top, left + width, top + height]
    radius = CHIP_RADIUS * k
    # Plate in the nameplate's colours: dark border, tan rim fading to fill.
    plate = Image.new("RGBA", layer.size, (0, 0, 0, 0))
    pd = ImageDraw.Draw(plate)
    pd.rounded_rectangle(box, radius=radius, fill=CHIP_BORDER)
    b = 1.3 * k
    pd.rounded_rectangle([box[0] + b, box[1] + b, box[2] - b, box[3] - b], radius=radius - b, fill=CHIP_RIM)
    inner = Image.new("RGBA", layer.size, (0, 0, 0, 0))
    idraw = ImageDraw.Draw(inner)
    r = b + 2.2 * k
    idraw.rounded_rectangle([box[0] + r, box[1] + r, box[2] - r, box[3] - r], radius=max(1, radius - r), fill=CHIP_FILL)
    inner = inner.filter(ImageFilter.GaussianBlur(1.1 * k))
    mask = Image.new("L", layer.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle([box[0] + b, box[1] + b, box[2] - b, box[3] - b], radius=radius - b, fill=255)
    clipped = Image.new("RGBA", layer.size, (0, 0, 0, 0))
    clipped.paste(inner, (0, 0), mask)
    plate.alpha_composite(clipped)
    layer.alpha_composite(plate)
    draw = ImageDraw.Draw(layer)
    size = CHIP_TEXT_SIZE * k
    mid = top + height / 2.0
    baseline = mid + UI.cap * size / 2.0
    for kind, value, x in items:
        if kind == "icon":
            layer.alpha_composite(value, (int(round(left + x)), int(round(mid - value.height / 2.0))))
        else:
            UI.draw(draw, left + x, baseline, value, size, TITLE_INK)
    return {"label": label, "width_local": width / k}


# ---------------------------------------------------------------- compose
def crop_box(info: dict) -> tuple[int, int, int, int]:
    s = info["scale"][0]
    ox, oy = info["origin"]
    cx, cy = info["corner"]
    ml, mt, mr, mb = CROP_MARGIN
    return (int(round(ox - ml * s)), int(round(oy - mt * s)), int(round(cx + mr * s)), int(round(cy + mb * s)))


def compose(card_id: str, mode: str, manifest: dict) -> tuple[Image.Image, Image.Image, dict]:
    info = manifest[card_id][mode]
    box = crop_box(info)
    old = Image.open(os.path.join(CAPTURES, "%s_%s.png" % (mode, card_id))).convert("RGBA").crop(box)
    spec = SPEC[card_id]
    if spec is None:
        return old, old.copy(), {"control": True}
    blank = Image.open(os.path.join(CAPTURES, "%s_%s_blank.png" % (mode, card_id))).convert("RGBA").crop(box)
    scale = info["scale"][0]
    k = scale * SS
    layer = Image.new("RGBA", (blank.width * SS, blank.height * SS), (0, 0, 0, 0))
    # Card-local frame inside the crop.
    ox = (info["origin"][0] - box[0]) * SS
    rows_top = (info["rows_rect"][1] - box[1]) * SS
    rows_bottom = (info["rows_rect"][3] - box[1]) * SS
    center_x = ox + 125.0 * k
    y = rows_top + TOP_PAD * k
    meta: dict = {"control": False}
    if spec.get("chip"):
        meta["chip"] = draw_chip(layer, spec["chip"], scale, center_x, y)
        y += (CHIP_HEIGHT + CHIP_GAP) * k
    else:
        y += 2.0 * k
    text_meta = draw_sentence(layer, spec["text"], scale, center_x, y)
    meta.update(text_meta)
    meta["text_bottom_local"] = (y + text_meta["height"]) / k
    meta["panel_bottom_local"] = rows_bottom / k
    meta["overflow"] = (y + text_meta["height"]) > rows_bottom
    small = layer.convert("RGBa").resize((blank.width, blank.height), Image.LANCZOS).convert("RGBA")
    new = blank.copy()
    new.alpha_composite(small)
    return old, new, meta


def label_font(px: int) -> ImageFont.FreeTypeFont:
    return ImageFont.truetype(UI_FONT, px)


BG = (23, 17, 13)
CREAM = (236, 220, 186)
MUTED = (178, 160, 128)
WARN = (232, 128, 96)


def pair_image(card_id: str, old: Image.Image, new: Image.Image, meta: dict) -> Image.Image:
    gap, pad, head, foot = 16, 14, 34, 30
    w = pad * 2 + old.width + gap + new.width
    h = head + old.height + foot
    sheet = Image.new("RGB", (w, h), BG)
    d = ImageDraw.Draw(sheet)
    d.text((pad, 8), NAMES[card_id], font=label_font(20), fill=CREAM)
    sheet.paste(old, (pad, head), old)
    sheet.paste(new, (pad + old.width + gap, head), new)
    d.text((pad + 4, head + old.height + 6), "OLD  (today, real capture)", font=label_font(13), fill=MUTED)
    if meta.get("control"):
        note, colour = "NEW  = old (simple card, rows stay)", MUTED
    else:
        lines = meta["lines"]
        note = "NEW  (mock) %d line%s" % (lines, "" if lines == 1 else "s")
        colour = MUTED
        if lines > 3:
            note += " (over the 3-line budget)"
            colour = WARN
    d.text((pad + old.width + gap + 4, head + old.height + 6), note, font=label_font(13), fill=colour)
    return sheet


def main() -> int:
    manifest = json.load(open(os.path.join(CAPTURES, "manifest.json")))
    out_pairs = os.path.join(ROOT, "pairs_hover")
    out_old = os.path.join(ROOT, "old_faces")
    out_new = os.path.join(ROOT, "new_faces")
    for path in (out_pairs, out_old, out_new):
        os.makedirs(path, exist_ok=True)
    report: dict = {}
    pairs = []
    hand_new = []
    for index, card_id in enumerate(ORDER, start=1):
        old, new, meta = compose(card_id, "hover", manifest)
        old.save(os.path.join(out_old, "%02d_%s_hover.png" % (index, card_id)))
        new.save(os.path.join(out_new, "%02d_%s_hover.png" % (index, card_id)))
        pair = pair_image(card_id, old, new, meta)
        pair_path = os.path.join(out_pairs, "%02d_%s_old_vs_new_hover.png" % (index, card_id))
        pair.save(pair_path)
        pairs.append(pair)
        hold, hnew, hmeta = compose(card_id, "hand", manifest)
        hold.save(os.path.join(out_old, "%02d_%s_hand.png" % (index, card_id)))
        hnew.save(os.path.join(out_new, "%02d_%s_hand.png" % (index, card_id)))
        hand_new.append((card_id, hnew, hmeta))
        report[card_id] = {"hover": meta, "hand": hmeta, "pair": pair_path}
    # Contact sheet: 12 pairs, 3 per row, 1:1.
    cols = 3
    cw = max(p.width for p in pairs)
    ch = max(p.height for p in pairs)
    title_h = 56
    sheet = Image.new("RGB", (cols * cw, title_h + ((len(pairs) + cols - 1) // cols) * ch), BG)
    d = ImageDraw.Draw(sheet)
    d.text((16, 12), "Mock faces, old | new, hover-enlarged size (1920x1080, 100% UI scale, real renderer + PIL composite)",
           font=label_font(22), fill=CREAM)
    for i, pair in enumerate(pairs):
        sheet.paste(pair, ((i % cols) * cw, title_h + (i // cols) * ch))
    sheet.save(os.path.join(ROOT, "contact_sheet_old_vs_new_hover.png"))
    # Hand-size sheet: the 12 new faces at 1:1.
    hcols = 6
    hw = max(im.width for _, im, _ in hand_new) + 16
    hh = max(im.height for _, im, _ in hand_new) + 40
    hs = Image.new("RGB", (hcols * hw + 16, 56 + 2 * hh), BG)
    d = ImageDraw.Draw(hs)
    d.text((16, 12), "New faces at normal hand size (208 px wide, 1:1)", font=label_font(22), fill=CREAM)
    for i, (card_id, im, meta) in enumerate(hand_new):
        x = 16 + (i % hcols) * hw
        y = 56 + (i // hcols) * hh
        hs.paste(im, (x, y), im)
        tag = NAMES[card_id] + ("  (control)" if meta.get("control") else "")
        d.text((x + 4, y + im.height + 6), tag, font=label_font(14), fill=MUTED)
    hs.save(os.path.join(ROOT, "new_faces_hand_size_sheet.png"))
    with open(os.path.join(ROOT, "compose_report.json"), "w") as handle:
        json.dump(report, handle, indent=2, default=str)
    for card_id in ORDER:
        meta = report[card_id]["hover"]
        if meta.get("control"):
            print("%-17s control" % card_id)
            continue
        print("%-17s lines=%d widest=%.1f/%.0f bottom=%.1f/%.1f overflow=%s chip=%s" % (
            card_id, meta["lines"], meta["widest"], TEXT_WIDTH, meta["text_bottom_local"],
            meta["panel_bottom_local"], meta["overflow"], meta.get("chip")))
    return 0


if __name__ == "__main__":
    sys.exit(main())
