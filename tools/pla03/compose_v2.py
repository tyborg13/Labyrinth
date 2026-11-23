#!/usr/bin/env python3
"""Compose the v2 playability mock faces (owner token rules, 2026-11-20).

Same real captures as v1 (mocks/old_captures), same blank parchment, fonts,
icons and target chip (compose_faces.py). v2 faces are token rows drawn the
way card_widget.gd draws summary rows:
  - icon token: the 64 px icon in an icon_size box, its value label at
    _summary_token_layout's position (bottom right, overlapping), Text font at
    label_size = max(16, round(icon_size * 0.62)), ink #2a170c, outline #f8f1dd;
  - words (target/trigger/condition/sequence) are value labels in that same
    style, like the old faces' "you on", "Only Target on", "from center";
  - surface-condition icons sit 3 local px from their words, as
    card_widget's SurfaceCondition group does;
  - area patterns are AoePatternView: 16x10 iso tiles at
    clamp(icon_size / 30, 0.52, 1), hit #d95f4a/#7b2f25, origin #e9dcc6/#5a493b;
  - rows are centred, 5 local apart; tokens one row gap apart (6/5/4 by size,
    -1 at 3+ rows, -1 at 4+); the icon size is the largest of card_widget's
    candidates (46..20) whose rows fit the panel, wrapping a row at item
    boundaries past the comfortable width (164 local) instead of shrinking.
"""

from __future__ import annotations

import json
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import compose_faces as v1  # noqa: E402
from PIL import Image, ImageDraw  # noqa: E402

OUT = "/private/tmp/labyrinth_codex/playability/mocks_v2"
v1.CHIP_MAX_WIDTH = 164.0  # v2: the chip keeps the comfortable width like every row
V1_NEW = "/private/tmp/labyrinth_codex/playability/mocks/new_faces"
SS = v1.SS
TEXT = v1.TEXT

VALUE_INK = (0x2A, 0x17, 0x0C, 255)      # card_widget.DAMAGE_NEUTRAL_COLOR
OUTLINE = (0xF8, 0xF1, 0xDD, 255)        # _token_outline_color(false)
OUTLINE_SIZE = 3.0                       # label outline_size (local px)
OUTLINE_RADIUS = 0.8                     # stroke radius matched to the engine capture (calibrate_v2.py)
HIT_FILL, HIT_BORDER = (0xD9, 0x5F, 0x4A, 255), (0x7B, 0x2F, 0x25, 255)
ORIGIN_FILL, ORIGIN_BORDER = (0xE9, 0xDC, 0xC6, 255), (0x5A, 0x49, 0x3B, 255)
ICON_CANDIDATES = [46.0, 44.0, 42.0, 40.0, 38.0, 36.0, 34.0, 32.0, 30.0, 28.0, 26.0, 24.0, 22.0, 20.0]
COMFORT_WIDTH = 164.0     # _summary_parchment_width() 176 - 2 * SUMMARY_COMFORT_INSET 6
HARD_WIDTH = 172.0        # 176 - 2 * screen inset (2 px at hover scale)
ROW_SEPARATION = 5.0      # _summary_icon_box separation
VERTICAL_PADDING = 10.0   # SUMMARY_VERTICAL_PADDING
COND_GAP = 3.0            # SurfaceCondition group separation

ICON_NAMES = {
    "Ranged": "ranged", "Melee": "melee", "Burst": "burst", "Push": "push", "Pull": "pull",
    "Expose": "expose", "Rubble": "surface_rubble", "Fire": "surface_fire", "Ice": "surface_ice",
    "Electrified": "surface_electrified", "Light": "illuminate", "Draw": "draw", "Move": "move",
    "Stoneskin": "stoneskin", "Immobilize": "immobilize", "Range": "range", "Exhaust": "exhaust",
    "Stagger": "stagger", "Follow-up": "follow_up",
}
PATTERNS = {
    # Patterns the old faces already draw (ActionIcons rows for these cards).
    "neighbors": ([(0, -1), (-1, 0), (1, 0), (0, 1)], True),       # Dust Devil, Shatter, Cyclone Seal
    "cross": ([(0, 0), (1, 0), (-1, 0), (0, 1), (0, -1)], False),  # Squall, Tectonic Maul
}

# v2 token lines (mock_faces_v2.md), "{pat:id}" marks where the face draws its
# pattern diagram. Burst areas draw none: Burst has one shape (director: 3x3).
V2: dict[str, dict | None] = {
    "dust_devil": {"chip": {"icon": None, "labels": ["Tile"], "range": 3},
                   "line": "If the tile is [Rubble]: [Burst]5 / [Push]2 away from the tile · [Expose]4 {pat:neighbors}"},
    "magma_vent": {"chip": {"icon": None, "labels": ["Tile"], "range": 3},
                   "line": "[Ranged]4, or [Burst]7 if the tile is [Rubble] / leave [Fire]"},
    "discharge": {"chip": {"icon": "surface_electrified", "labels": ["Electrified tile", "Electrified"], "range": 4},
                  "line": "[Burst]5 on the tile and every [Electrified] tile connected to it"},
    "beacon": {"chip": {"icon": None, "labels": ["Tile"], "range": 4},
               "line": "[Light]2 · [Draw]1"},
    "worldroot_stride": {"chip": None,
                         "line": "[Move]3 / [Stoneskin]6, or 9 if you arrive on [Rubble] / leave [Rubble] under you"},
    "palm_strike": None,
    "frost_heave": {"chip": None,
                    "line": "[Ranged]3 · [Range]3 · [Immobilize] / Target on [Ice]: [Burst]6 · the Ice becomes [Rubble]"},
    "shatter": {"chip": None,
                "line": "[Ranged]5 · [Range]3 / Target on [Ice]: [Burst]5"},
    "cyclone_seal": {"chip": {"icon": None, "labels": ["Tile"], "range": 3},
                     "line": "[Exhaust] / [Pull]3 toward the tile, from up to 3 tiles away / then [Ranged]9 {pat:neighbors}"},
    "squall_shot": {"chip": {"icon": None, "labels": ["Tile"], "range": 3},
                    "line": "[Ranged]2 {pat:cross} / [Push]1 away from the tile; an enemy on the tile: away from you"},
    # The engine leaves Rubble on the target and its 4 neighbours today; the
    # old face draws that cross, so v2 keeps it beside "leave [Rubble]".
    "tectonic_maul": {"chip": None,
                      "line": "[Move]1 / [Melee]11, or 15 if the target is already on [Rubble] / [Stagger]3 · leave [Rubble] {pat:cross}"},
    "sidestep_slash": None,
}

TOKEN_RE = re.compile(r"\[([A-Za-z-]+)\](\+?\d+)?(,?)|\{pat:(\w+)\}")


# ------------------------------------------------------------------ parsing
def parse_row(row: str) -> list[dict]:
    """Items: tok(icon,value) | word(text) | cicon(icon) | pat(id). Each item
    carries 'gap_before' kind: 'space' | 'cond' | 'row' and 'glue' (no break)."""
    items: list[dict] = []
    for chunk_index, chunk in enumerate(row.split(" · ")):
        pos = 0
        chunk_items: list[dict] = []
        for m in TOKEN_RE.finditer(chunk):
            for word in chunk[pos:m.start()].split():
                chunk_items.append({"kind": "word", "text": word})
            pos = m.end()
            if m.group(4):
                chunk_items.append({"kind": "pat", "id": m.group(4)})
                continue
            icon = ICON_NAMES[m.group(1)]
            value = (m.group(2) or "") + m.group(3)
            chunk_items.append({"kind": "tok", "icon": icon, "value": value, "bare": not m.group(2)})
        for word in chunk[pos:].split():
            chunk_items.append({"kind": "word", "text": word})
        # A bare icon among words is a condition/ground icon (SurfaceCondition
        # style); a lone ":" glues to it.
        for index, item in enumerate(chunk_items):
            if item["kind"] == "tok" and item["bare"] and any(i["kind"] == "word" for i in chunk_items):
                item["kind"] = "cicon"
        merged: list[dict] = []
        for item in chunk_items:
            if item["kind"] == "word" and item["text"].startswith(":") and merged and merged[-1]["kind"] == "cicon":
                item["kind"] = "word"
                item["gap"] = "cond"
                item["glue"] = True
            merged.append(item)
        for index, item in enumerate(merged):
            item["chunk"] = chunk_index
            if "gap" in item:
                pass
            elif index == 0:
                item["gap"] = "row"
            else:
                prev = merged[index - 1]
                if item["kind"] == "word" and prev["kind"] == "word":
                    item["gap"] = "space"
                elif item["kind"] == "cicon" and prev["kind"] == "word":
                    item["gap"] = "cond"
                    item["glue"] = True  # keep "on [Ice]" together
                else:
                    item["gap"] = "row"
                    # keep "or [Burst]7", "then [Ranged]9" together; a break
                    # may follow "...:" or "...,".
                    if item["kind"] == "tok" and prev["kind"] == "word" and not prev["text"].endswith((",", ";", ":")):
                        item["glue"] = True
            if item["kind"] == "pat":
                item["glue"] = True
        items.extend(merged)
    return items


# ------------------------------------------------------------------ metrics
def font_metrics(label: float) -> tuple[float, float, float]:
    ascent = round(TEXT.ascent * label)
    descent = round(TEXT.descent * label)
    return ascent, descent, ascent + descent


def row_gap(icon: float, rows: int) -> float:
    gap = 4 if icon <= 22 else 5 if icon <= 26 else 6
    if rows >= 3:
        gap -= 1
    if rows >= 4:
        gap -= 1
    return float(max(1, gap))


def pattern_scale(icon: float) -> float:
    return min(1.0, max(0.52, icon / 30.0))


def pattern_size(pid: str, icon: float) -> tuple[float, float]:
    offsets, origin = PATTERNS[pid]
    s = pattern_scale(icon)
    pts = list(offsets) + ([(0, 0)] if origin and (0, 0) not in offsets else [])
    tw, th = 16.0 * s, 10.0 * s
    xs = [(x - y) * tw / 2 for x, y in pts]
    ys = [(x + y) * th / 2 for x, y in pts]
    bw = max(xs) - min(xs) + tw
    bh = max(ys) - min(ys) + th
    return max(34.0 * s, bw + 10.0 * s), max(24.0 * s, bh + 10.0 * s)


def measure(item: dict, icon: float, label: float) -> tuple[float, float]:
    ascent, descent, height = font_metrics(label)
    if item["kind"] == "word":
        return TEXT.width(item["text"], label), height
    if item["kind"] == "cicon":
        return icon, icon
    if item["kind"] == "pat":
        return pattern_size(item["id"], icon)
    # icon token (_summary_token_layout)
    if not item["value"]:
        return icon, icon
    vw = TEXT.width(item["value"], label) + 2.0
    vh = height + 2.0
    overlap = max(5.0, vw * 0.36)
    vx = max(icon * 0.56, icon - overlap)
    vy = max(0.0, icon - vh * 0.76)
    item["_value_rect"] = (vx, vy, vw, vh)
    return max(icon, vx + vw), max(icon, vy + vh)


def gap_width(kind: str, gap: float, label: float) -> float:
    if kind == "space":
        return TEXT.width(" ", label)
    if kind == "cond":
        return COND_GAP
    return gap


def _ends_clause(unit: list[dict]) -> bool:
    last = unit[-1]
    text = last.get("text") if last["kind"] == "word" else last.get("value", "")
    return bool(text) and text.endswith((",", ";", ":"))


def wrap_row(items: list[dict], icon: float, label: float, gap: float, limit: float, mode: str = "words") -> list[list[dict]] | None:
    """One authored row -> lines (None if it cannot fit in this mode).
    mode "chunks": break only between the row's tokens (" · ");
    mode "words": also inside a phrase, never inside a glued unit (condition
    icon with its words, "or [Burst]7", a pattern with its token).
    Breaks are chosen to use the fewest lines, then to prefer token
    boundaries and clause ends (",", ";", ":") and to avoid ragged lines."""
    units: list[list[dict]] = []
    for item in items:
        if units and item.get("glue"):
            units[-1].append(item)
        else:
            units.append([item])
    n = len(units)

    def width(i: int, j: int) -> float:
        w = 0.0
        first = True
        for unit in units[i:j]:
            for item in unit:
                if not first:
                    w += gap_width(item["gap"], gap, label)
                first = False
                w += measure(item, icon, label)[0]
        return w

    def chunk_end(j: int) -> bool:  # a break before units[j] falls between tokens
        return j < n and units[j][0]["chunk"] != units[j - 1][-1]["chunk"]

    allowed = [j for j in range(1, n) if mode == "words" or chunk_end(j)]
    inf = float("inf")
    best: list[tuple[float, int]] = [(inf, -1)] * (n + 1)
    best[0] = (0.0, -1)
    for j in list(allowed) + [n]:
        for i in [0] + allowed:
            if i >= j or best[i][0] == inf:
                continue
            w = width(i, j)
            if w > limit and j - i > 1:
                continue
            if w > limit:
                cost = 1000.0  # a single unit wider than the line
            else:
                cost = 10.0
                if j < n:
                    cost += ((limit - w) / limit) ** 2
                    cost -= 0.6 if chunk_end(j) else (0.4 if _ends_clause(units[j - 1]) else 0.0)
                if w < 0.22 * limit and (j < n or i > 0):
                    cost += 1.0
            if best[i][0] + cost < best[j][0]:
                best[j] = (best[i][0] + cost, i)
    if best[n][0] == inf:
        return None
    cuts = []
    j = n
    while j > 0:
        i = best[j][1]
        cuts.append((i, j))
        j = i
    lines = [[item for unit in units[i:j] for item in unit] for i, j in reversed(cuts)]
    if any(width(i, j) > limit for i, j in cuts):
        return None
    return lines


def line_width(line: list[dict], icon: float, label: float, gap: float) -> float:
    w = 0.0
    for index, item in enumerate(line):
        if index > 0:
            w += gap_width(item["gap"], gap, label)
        w += measure(item, icon, label)[0]
    return w


# Un-lent card geometry (local units): art 115 tall, details panel 140, rows
# box 183..323. card_widget picks the icon size against details + the art it
# may lend (art down to ART_MIN_HEIGHT 76) and then lends what it needs.
DETAILS_HEIGHT = 140.0
ART_HEIGHT = 115.0
ART_MIN_HEIGHT = 76.0
MAX_RELIEF = ART_HEIGHT - ART_MIN_HEIGHT


ROWS_TOP = 183.0          # un-lent rows box top (details top 180 + margin 3)
PROFILE_PATH = os.path.join(OUT, "parchment_profile.json")
_profile_cache: dict = {}


def allowed_half_width(y0: float, y1: float) -> float:
    """Half the line width allowed over local rows y0..y1: the comfortable
    width (164) where the parchment is full, narrowed by exactly as much as the
    measured light parchment narrows (torn lower edge, bottom corners)."""
    if not _profile_cache:
        raw = {int(k): v for k, v in json.load(open(PROFILE_PATH)).items()}
        for y in raw:
            window = sorted(raw[y + d] for d in range(-6, 7) if (y + d) in raw)
            _profile_cache[y] = window[len(window) // 2]
    ys = [y for y in range(int(y0), int(y1) + 1) if y in _profile_cache]
    if not ys:
        return COMFORT_WIDTH / 2.0
    return min(min(COMFORT_WIDTH / 2.0, _profile_cache[y] + 3.0) for y in ys)


def _chip_width(chip: dict | None) -> float:
    return v1.chip_layout(chip, 1.0)[2] if chip else 0.0


def _candidate(rows: list[list[dict]], chip_h: float, icon: float, wrap: str, limit: float = COMFORT_WIDTH,
               rows_chip: dict | None = None) -> dict:
    label = max(16.0, float(round(icon * 0.62)))
    gap = row_gap(icon, len(rows) + (1 if chip_h else 0))
    lines: list[list[dict]] = []
    for row in rows:
        wrapped = wrap_row(row, icon, label, gap, limit, wrap) if wrap else [row]
        if wrapped is None:
            return {"icon": icon, "total": float("inf"), "widest": float("inf"), "ok": False}
        lines.extend(wrapped)
    heights = [max(measure(i, icon, label)[1] for i in line) for line in lines]
    total = sum(heights) + ROW_SEPARATION * (len(lines) - 1) + (chip_h + ROW_SEPARATION if chip_h else 0.0)
    widths = [line_width(line, icon, label, gap) for line in lines]
    cand = {"icon": icon, "label": label, "gap": gap, "lines": lines, "heights": heights, "widths": widths,
            "total": total, "rows": len(rows), "wrapped": len(lines) - len(rows), "widest": max(widths),
            "chip_h": chip_h, "limit": limit, "chip_w": _chip_width(rows_chip)}
    # Art lend: what the height needs, then more (up to the art minimum) if a
    # line would otherwise reach the narrowing parchment.
    need = max(0.0, total + VERTICAL_PADDING - DETAILS_HEIGHT)
    cand["ok"] = False
    lend = need
    while lend <= MAX_RELIEF + 1e-6:
        if _profile_ok(cand, ROWS_TOP - lend):
            cand["ok"] = cand["widest"] <= COMFORT_WIDTH
            cand["lend"] = round(lend, 1)
            break
        lend += 0.5
    return cand


def _profile_ok(cand: dict, top: float) -> bool:
    y = top + (cand["chip_h"] + ROW_SEPARATION if cand["chip_h"] else 0.0)
    if cand["chip_h"] and cand["chip_w"] / 2.0 > allowed_half_width(top, top + cand["chip_h"]):
        return False
    for h, w in zip(cand["heights"], cand["widths"]):
        if w / 2.0 > allowed_half_width(y, y + h):
            return False
        y += h + ROW_SEPARATION
    return True


def layout(spec: dict) -> dict:
    """Largest icon size whose authored rows fit unwrapped; failing that,
    split rows only between tokens; failing that, break phrases with the
    fewest lines. Every line must clear the parchment edge where it sits; the
    art lends height (to ART_MIN_HEIGHT) before icons shrink, as card_widget does."""
    rows = [parse_row(r) for r in spec["line"].split(" / ")]
    chip_h = v1.CHIP_HEIGHT if spec.get("chip") else 0.0
    limits = [COMFORT_WIDTH, 156.0, 148.0, 140.0, 132.0]
    chosen = None
    for wrap in ("", "chunks"):
        for icon in ICON_CANDIDATES:
            for limit in limits:
                cand = _candidate(rows, chip_h, icon, wrap, limit, spec.get("chip"))
                if cand["ok"]:
                    chosen = cand
                    break
            if chosen:
                break
        if chosen:
            break
    if chosen is None:
        fitting = []
        for icon in ICON_CANDIDATES:
            for limit in limits:
                cand = _candidate(rows, chip_h, icon, "words", limit, spec.get("chip"))
                if cand["ok"]:
                    fitting.append(cand)
                    break
        if fitting:
            chosen = min(fitting, key=lambda c: (len(c["lines"]), -c["icon"]))
            chosen["phrase_broken"] = True
    if chosen is None:
        chosen = _candidate(rows, chip_h, ICON_CANDIDATES[-1], "words", COMFORT_WIDTH, spec.get("chip"))
        chosen["fits"] = False
        chosen["lend"] = MAX_RELIEF
        return chosen
    chosen["fits"] = True
    return chosen


# ------------------------------------------------------------------ drawing
def draw_label(layers, x: float, baseline: float, text: str, size: float, k: float) -> None:
    outline_layer, ink_layer = layers
    stroke = max(1, int(round(OUTLINE_RADIUS * k)))
    font = TEXT.pil(size)
    od = ImageDraw.Draw(outline_layer)
    idr = ImageDraw.Draw(ink_layer)
    cx = x
    for ch in text:
        if ch != " ":
            od.text((round(cx), round(baseline)), ch, font=font, fill=OUTLINE, anchor="ls",
                    stroke_width=stroke, stroke_fill=OUTLINE)
            idr.text((round(cx), round(baseline)), ch, font=font, fill=VALUE_INK, anchor="ls")
        cx += TEXT.advance(ch) * size


def draw_icon(layer: Image.Image, name: str, x: float, y: float, box: float) -> None:
    src = v1.Image.open(os.path.join(v1.ICONS, name + ".png")).convert("RGBA")
    size = max(1, int(round(box)))
    img = src.resize((size, size), Image.LANCZOS)
    layer.alpha_composite(img, (int(round(x)), int(round(y))))


def draw_pattern(layer: Image.Image, pid: str, x: float, y: float, w: float, h: float, icon: float, k: float) -> None:
    offsets, origin = PATTERNS[pid]
    s = pattern_scale(icon)
    pts = list(offsets)
    if origin and (0, 0) not in pts:
        pts.append((0, 0))
    tw, th = 16.0 * s * k, 10.0 * s * k
    centers = [((px - py) * tw / 2, (px + py) * th / 2) for px, py in pts]
    min_x = min(c[0] for c in centers) - tw / 2
    max_x = max(c[0] for c in centers) + tw / 2
    min_y = min(c[1] for c in centers) - th / 2
    max_y = max(c[1] for c in centers) + th / 2
    shift_x = x + w / 2 - (min_x + max_x) / 2
    shift_y = y + h / 2 - (min_y + max_y) / 2
    d = ImageDraw.Draw(layer)
    order = sorted(zip(pts, centers), key=lambda pc: (pc[0][1], pc[0][0]))
    for (px, py), (cx, cy) in order:
        is_origin = origin and (px, py) == (0, 0) and (0, 0) not in offsets
        fill, border = (ORIGIN_FILL, ORIGIN_BORDER) if is_origin else (HIT_FILL, HIT_BORDER)
        cx += shift_x
        cy += shift_y
        poly = [(cx, cy - th / 2), (cx + tw / 2, cy), (cx, cy + th / 2), (cx - tw / 2, cy)]
        d.polygon(poly, fill=fill)
        d.line(poly + [poly[0]], fill=border, width=max(1, int(round(1.0 * k))), joint="curve")


def render_rows(layer: Image.Image, lay: dict, k: float, center_x: float, top: float) -> None:
    icon, label, gap = lay["icon"], lay["label"], lay["gap"]
    ascent, descent, fh = font_metrics(label)
    outline_layer = Image.new("RGBA", layer.size, (0, 0, 0, 0))
    ink_layer = Image.new("RGBA", layer.size, (0, 0, 0, 0))
    graphics = Image.new("RGBA", layer.size, (0, 0, 0, 0))
    y = top
    for line, h, w in zip(lay["lines"], lay["heights"], lay["widths"]):
        x = center_x - w * k / 2.0
        for index, item in enumerate(line):
            if index > 0:
                x += gap_width(item["gap"], gap, label) * k
            iw, ih = measure(item, icon, label)
            iy = y + (h - ih) * k / 2.0
            if item["kind"] == "word":
                baseline = y + ((h - fh) / 2.0 + ascent) * k
                draw_label((outline_layer, ink_layer), x, baseline, item["text"], label * k, k)
            elif item["kind"] == "cicon":
                draw_icon(graphics, item["icon"], x, iy, icon * k)
            elif item["kind"] == "pat":
                draw_pattern(graphics, item["id"], x, iy, iw * k, ih * k, icon, k)
            else:
                draw_icon(graphics, item["icon"], x, iy, icon * k)
                if item["value"]:
                    vx, vy, vw, vh = item["_value_rect"]
                    baseline = iy + (vy + (vh - fh) / 2.0 + ascent) * k
                    draw_label((outline_layer, ink_layer), x + vx * k, baseline, item["value"], label * k, k)
            x += iw * k
        y += (h + ROW_SEPARATION) * k
    # Godot draws the icon, then the label's outline, then its glyphs.
    layer.alpha_composite(graphics)
    layer.alpha_composite(outline_layer)
    layer.alpha_composite(ink_layer)


V2_CAPTURES = os.path.join(OUT, "v2_captures")


def plan_lends() -> dict:
    """Art lend per v2 card (input to mock_faces_v2_probe.gd)."""
    return {card_id: layout(spec)["lend"] for card_id, spec in V2.items() if spec is not None}


def compose(card_id: str, mode: str, manifest: dict, v2_manifest: dict):
    info = manifest[card_id][mode]
    box = v1.crop_box(info)
    old = Image.open(os.path.join(v1.CAPTURES, "%s_%s.png" % (mode, card_id))).convert("RGBA").crop(box)
    spec = V2[card_id]
    if spec is None:
        return old, old.copy(), {"control": True}
    lay = layout(spec)
    captured = v2_manifest[card_id]
    assert abs(float(captured["lend"]) - lay["lend"]) < 0.05, (card_id, captured["lend"], lay["lend"])
    vinfo = captured[mode]
    assert v1.crop_box(vinfo) == box
    blank = Image.open(os.path.join(V2_CAPTURES, "%s_%s_blank.png" % (mode, card_id))).convert("RGBA").crop(box)
    scale = vinfo["scale"][0]
    k = scale * SS
    oy = vinfo["origin"][1]
    rows_top_local = (vinfo["rows_rect"][1] - oy) / scale
    details_bottom_local = (vinfo["details_rect"][3] - oy) / scale
    layer = Image.new("RGBA", (blank.width * SS, blank.height * SS), (0, 0, 0, 0))
    center_x = (vinfo["origin"][0] - box[0]) * SS + 125.0 * k
    y = (vinfo["rows_rect"][1] - box[1]) * SS
    meta = {"control": False, "icon_size": lay["icon"], "label_size": lay["label"], "rows": lay["rows"],
            "lines": len(lay["lines"]), "wrapped_extra_lines": lay["wrapped"], "phrase_broken": lay.get("phrase_broken", False),
            "widest_local": round(lay["widest"], 1), "height_local": round(lay["total"], 1),
            "art_lend_local": lay["lend"], "rows_bottom_local": round(rows_top_local + lay["total"], 1),
            "panel_bottom_local": round(details_bottom_local, 1), "fits": lay["fits"],
            "line_items": [" ".join(i.get("text") or ("[%s]%s" % (i.get("icon") or i.get("id"), i.get("value", ""))) for i in line)
                           for line in lay["lines"]]}
    if spec.get("chip"):
        meta["chip"] = v1.draw_chip(layer, spec["chip"], scale, center_x, y)
        y += (v1.CHIP_HEIGHT + ROW_SEPARATION) * k
    render_rows(layer, lay, k, center_x, y)
    small = layer.convert("RGBa").resize((blank.width, blank.height), Image.LANCZOS).convert("RGBA")
    new = blank.copy()
    new.alpha_composite(small)
    return old, new, meta


# ------------------------------------------------------------------ sheets
def pair_image(card_id: str, old: Image.Image, new: Image.Image, meta: dict) -> Image.Image:
    gap, pad, head, foot = 16, 14, 34, 30
    sheet = Image.new("RGB", (pad * 2 + old.width + gap + new.width, head + old.height + foot), v1.BG)
    d = ImageDraw.Draw(sheet)
    d.text((pad, 8), v1.NAMES[card_id], font=v1.label_font(20), fill=v1.CREAM)
    sheet.paste(old, (pad, head), old)
    sheet.paste(new, (pad + old.width + gap, head), new)
    d.text((pad + 4, head + old.height + 6), "OLD  (today, real capture)", font=v1.label_font(13), fill=v1.MUTED)
    if meta.get("control"):
        note, colour = "NEW v2 = old (simple card, rows stay)", v1.MUTED
    else:
        note = "NEW v2  icons %d, %d row%s" % (meta["icon_size"], meta["lines"], "" if meta["lines"] == 1 else "s")
        colour = v1.MUTED if meta["fits"] else v1.WARN
        if not meta["fits"]:
            note += "  DOES NOT FIT"
    d.text((pad + old.width + gap + 4, head + old.height + 6), note, font=v1.label_font(13), fill=colour)
    return sheet


def triple_image(card_id: str, old: Image.Image, first: Image.Image, second: Image.Image, meta: dict) -> Image.Image:
    gap, pad, head, foot = 12, 10, 32, 26
    w = pad * 2 + old.width + first.width + second.width + gap * 2
    sheet = Image.new("RGB", (w, head + old.height + foot), v1.BG)
    d = ImageDraw.Draw(sheet)
    d.text((pad, 7), v1.NAMES[card_id], font=v1.label_font(19), fill=v1.CREAM)
    x = pad
    for image, tag in ((old, "OLD"), (first, "v1"), (second, "v2")):
        sheet.paste(image, (x, head), image)
        colour = v1.MUTED
        if tag == "v2" and not meta.get("control") and not meta.get("fits", True):
            tag, colour = "v2  DOES NOT FIT", v1.WARN
        d.text((x + 4, head + old.height + 5), tag, font=v1.label_font(13), fill=colour)
        x += image.width + gap
    return sheet


def main() -> int:
    if len(sys.argv) > 1 and sys.argv[1] == "plan":
        os.makedirs(OUT, exist_ok=True)
        with open(os.path.join(OUT, "lends.json"), "w") as handle:
            json.dump(plan_lends(), handle, indent=1)
        print(os.path.join(OUT, "lends.json"))
        return 0
    manifest = json.load(open(os.path.join(v1.CAPTURES, "manifest.json")))
    v2_manifest = json.load(open(os.path.join(V2_CAPTURES, "manifest.json")))
    for sub in ("pairs_hover", "old_faces", "new_faces"):
        os.makedirs(os.path.join(OUT, sub), exist_ok=True)
    report: dict = {}
    triples = []
    hand_new = []
    for index, card_id in enumerate(v1.ORDER, start=1):
        old, new, meta = compose(card_id, "hover", manifest, v2_manifest)
        old.save(os.path.join(OUT, "old_faces", "%02d_%s_hover.png" % (index, card_id)))
        new.save(os.path.join(OUT, "new_faces", "%02d_%s_hover.png" % (index, card_id)))
        pair = pair_image(card_id, old, new, meta)
        pair_path = os.path.join(OUT, "pairs_hover", "%02d_%s_old_vs_v2_hover.png" % (index, card_id))
        pair.save(pair_path)
        first = Image.open(os.path.join(V1_NEW, "%02d_%s_hover.png" % (index, card_id))).convert("RGBA")
        triples.append(triple_image(card_id, old, first, new, meta))
        hold, hnew, hmeta = compose(card_id, "hand", manifest, v2_manifest)
        hold.save(os.path.join(OUT, "old_faces", "%02d_%s_hand.png" % (index, card_id)))
        hnew.save(os.path.join(OUT, "new_faces", "%02d_%s_hand.png" % (index, card_id)))
        hand_new.append((card_id, hnew, hmeta))
        report[card_id] = {"hover": meta, "hand": hmeta, "pair": pair_path}
    cols = 2
    cw = max(t.width for t in triples)
    ch = max(t.height for t in triples)
    title_h = 56
    sheet = Image.new("RGB", (cols * cw, title_h + ((len(triples) + cols - 1) // cols) * ch), v1.BG)
    d = ImageDraw.Draw(sheet)
    d.text((16, 12), "Mock faces OLD | v1 | v2, hover-enlarged size (1920x1080, 100% UI scale, real renderer + PIL composite)",
           font=v1.label_font(22), fill=v1.CREAM)
    for i, triple in enumerate(triples):
        sheet.paste(triple, ((i % cols) * cw, title_h + (i // cols) * ch))
    sheet.save(os.path.join(OUT, "contact_sheet_old_v1_v2_hover.png"))
    hcols = 6
    hw = max(im.width for _, im, _ in hand_new) + 16
    hh = max(im.height for _, im, _ in hand_new) + 40
    hs = Image.new("RGB", (hcols * hw + 16, 56 + 2 * hh), v1.BG)
    d = ImageDraw.Draw(hs)
    d.text((16, 12), "v2 faces at normal hand size (208 px wide, 1:1)", font=v1.label_font(22), fill=v1.CREAM)
    for i, (card_id, im, meta) in enumerate(hand_new):
        x = 16 + (i % hcols) * hw
        y = 56 + (i // hcols) * hh
        hs.paste(im, (x, y), im)
        tag = v1.NAMES[card_id] + ("  (control)" if meta.get("control") else "")
        d.text((x + 4, y + im.height + 6), tag, font=v1.label_font(14), fill=v1.MUTED)
    hs.save(os.path.join(OUT, "v2_faces_hand_size_sheet.png"))
    with open(os.path.join(OUT, "compose_v2_report.json"), "w") as handle:
        json.dump(report, handle, indent=2, default=str)
    for card_id in v1.ORDER:
        meta = report[card_id]["hover"]
        if meta.get("control"):
            print("%-17s control" % card_id)
            continue
        print("%-17s icon=%d label=%d rows=%d lines=%d widest=%.1f bottom=%.1f/%.1f lend=%.1f broken=%s fits=%s" % (
            card_id, meta["icon_size"], meta["label_size"], meta["rows"], meta["lines"], meta["widest_local"],
            meta["rows_bottom_local"], meta["panel_bottom_local"], meta["art_lend_local"], meta["phrase_broken"], meta["fits"]))
        for text in meta["line_items"]:
            print("      | " + text)
    return 0


if __name__ == "__main__":
    sys.exit(main())
