#!/usr/bin/env python3
"""Compose the round-5 playability mock faces (2026-11-20). Round 5 = round 4
plus: every game term with an icon reads icon, word, then number
("[Push] Push 2", "[Rubble] Rubble"); damage stays icon + number; "On
[ground]:" is the one condition form; diagrams sit under the sentence.

Round 4: v1's format
(target chip + one centred sentence in the game's rules-text font and ink)
with the owner's fixes.

- Sentence: LabyrinthCrumble-Text at the Rite rules size (16 local), ink
  #503d2c, centred, wrap width 162 local, pitch 18, as v1 (calibrated against
  the engine's own Rite text, mocks/calibration_rite_text_engine_vs_mock.png).
- Each effect's icon sits inline right before its number (v1 rule); a
  keyword with no number (Immobilize, Exhaust) has its icon before the word.
- Area shapes are the game's pattern diagram (AoePatternView geometry and
  colours, as v2), under the sentence or inline beside the words it shapes.
- Line breaks: fewest lines, then sentence and clause ends, then words that
  start a phrase; a keyword never leaves its icon and number.
- Nothing nears the parchment edge: every line, the chip and each diagram is
  checked against the measured parchment width at its height (v2/v3 rule);
  the art lends height (to its 76 minimum) before the wrap narrows.
- Palm Strike and Sidestep Slash keep their old face.
"""

from __future__ import annotations

import json
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import compose_faces as v1  # noqa: E402
import compose_v2 as c2  # noqa: E402  (pattern colours, parchment profile)
from PIL import Image, ImageDraw  # noqa: E402

OUT = "/private/tmp/labyrinth_codex/playability/mocks_v5"
CAPTURES = os.path.join(OUT, "v5_captures")
V1_NEW = "/private/tmp/labyrinth_codex/playability/mocks_v4/new_faces"  # the previous round (v4) for the sheet
SS = v1.SS
TEXT = v1.TEXT
NBSP = v1.NBSP

ROWS_TOP = 183.0
LINE_PITCH = v1.LINE_PITCH
K_REF = 16.0  # line-break reference resolution (px per local unit)
DETAILS_HEIGHT = 140.0
VERTICAL_PADDING = 10.0
MAX_RELIEF = 39.0
WIDTHS = [162.0, 154.0, 146.0, 138.0]
DIAGRAM_GAP = 5.0
UNDER_SCALE = 0.9    # under-sentence diagrams: the old faces' scale at icon 27-28
UNDER_SCALES = [0.9, 0.8, 0.7, 0.6]
ORDER_GAP = 5.0      # between side-by-side diagrams and their order arrow
INLINE_SCALE = 0.6   # inline diagrams: about one and a half text lines tall

PATTERNS = {
    "neighbors": ([(0, -1), (-1, 0), (1, 0), (0, 1)], True),       # old Dust Devil / Cyclone Seal 9 / Shatter
    "cross": ([(0, 0), (1, 0), (-1, 0), (0, 1), (0, -1)], False),  # old Squall / Tectonic Maul
    # old Cyclone Seal pull area: @pattern(hollow_diamond:3:origin)
    "diamond3": ([(x, y) for x in range(-3, 4) for y in range(-3, 4) if 1 <= abs(x) + abs(y) <= 3], True),
}

# "{icon}" = inline icon, "~" = no-break space, "{pat:id}" = inline diagram.
SPECS: dict[str, dict | None] = {
    # {icon}Word~#N = the term's icon, its word, its number (number in the
    # simple cards' number style); {ranged}#N / {melee}#N = damage token.
    "dust_devil": {"chip": {"icon": None, "labels": ["Tile"], "range": 3},
                   "text": "{push}Push~#2 every enemy next to the tile, away from it. "
                           "On~{surface_rubble}Rubble: {burst}Burst~#5 first.",
                   "under": ["neighbors"]},
    "magma_vent": {"chip": {"icon": None, "labels": ["Tile"], "range": 3},
                   "text": "{ranged}#4. On~{surface_rubble}Rubble: {burst}Burst~#7 instead, leaving {surface_fire}Fire."},
    "discharge": {"chip": {"icon": "surface_electrified", "labels": ["Electrified"], "range": 4},
                  "text": "{burst}Burst~#5 this tile and every {surface_electrified}Electrified tile connected to it."},
    "beacon": {"chip": {"icon": None, "labels": ["Tile"], "range": 4},
               "text": "Create {illuminate}Light~#2 and {draw}Draw~#1."},
    "worldroot_stride": {"chip": None,
                         "text": "{move}Move~#3 and gain {stoneskin}Stoneskin~#6. Leave {surface_rubble}Rubble under you."},
    "palm_strike": None,
    "frost_heave": {"chip": {"icon": None, "labels": ["Enemy"], "range": 3},
                    "text": "{ranged}#3 and {immobilize}Immobilize. On~{surface_ice}Ice: {burst}Burst~#6 the {surface_ice}Ice instead."},
    "shatter": {"chip": {"icon": None, "labels": ["Enemy"], "range": 3},
                "text": "{ranged}#5. On~{surface_ice}Ice: {burst}Burst~#5 the {surface_ice}Ice."},
    "cyclone_seal": {"chip": {"icon": None, "labels": ["Tile"], "range": 3},
                     "text": "{exhaust}Exhaust. {pull}Pull~#3 enemies in the area toward the tile, then {ranged}#9 on the marked tiles.",
                     "under": ["diamond3", "neighbors"]},
    "squall_shot": {"chip": {"icon": None, "labels": ["Tile"], "range": 3},
                    "text": "{ranged}#2 and {push}Push~#1 each enemy hit.",
                    "under": ["cross"]},
    "tectonic_maul": {"chip": None,
                      "text": "{melee}#11 and {stagger}Stagger~#3. On~{surface_rubble}Rubble: {melee}#15 instead. "
                              "Leave {surface_rubble}Rubble {pat:cross}"},
    "sidestep_slash": None,
}

# A line never ends on a word that opens a phrase ("the", "on", "every"...).
FUNCTION_WORDS = {"the", "a", "an", "on", "to", "of", "in", "every", "each", "is", "was", "if", "and", "then", "toward",
                  "from", "next", "under", "this", "which", "already", "stands", "burst", "deal", "push", "pull",
                  "strike", "create", "gain", "draw", "move", "leave", "expose", "stagger", "it"}
PHRASE_STARTERS = {"and", "then", "If", "which", "toward", "instead.", "each", "every", "on", "in", "under"}


# ------------------------------------------------------------------ patterns
def pattern_size(pid: str, s: float) -> tuple[float, float]:
    offsets, origin = PATTERNS[pid]
    pts = list(offsets) + ([(0, 0)] if origin and (0, 0) not in offsets else [])
    tw, th = 16.0 * s, 10.0 * s
    xs = [(x - y) * tw / 2 for x, y in pts]
    ys = [(x + y) * th / 2 for x, y in pts]
    return max(34.0 * s, max(xs) - min(xs) + tw + 10.0 * s), max(24.0 * s, max(ys) - min(ys) + th + 10.0 * s)


def draw_pattern(layer: Image.Image, pid: str, x: float, y: float, w: float, h: float, s: float, k: float) -> None:
    saved = c2.PATTERNS.get(pid)
    c2.PATTERNS[pid] = PATTERNS[pid]
    # c2.draw_pattern scales tiles by clamp(icon / 30): pass the icon size that gives scale s.
    c2.draw_pattern(layer, pid, x, y, w, h, s * 30.0, k) if s >= 0.52 else None
    if saved is None:
        del c2.PATTERNS[pid]
    else:
        c2.PATTERNS[pid] = saved


# ------------------------------------------------------------------ sentence
def parse(markup: str) -> list[dict]:
    """Words (split on spaces); each word = parts of text / icon / pattern."""
    words = []
    for raw in markup.split(" "):
        if raw.startswith("{pat:"):
            words.append({"pattern": raw[5:-1], "raw": raw})
            continue
        words.append({"parts": _num_parts(v1.parse_word(raw)), "raw": raw})
    return words


def _num_parts(parts: list[tuple[str, str]]) -> list[tuple[str, str]]:
    """Split '#12' markers out of text parts into ('num', '12')."""
    out: list[tuple[str, str]] = []
    for kind, value in parts:
        if kind != "text" or "#" not in value:
            out.append((kind, value))
            continue
        for chunk in re.split(r"(#[+\d]+)", value):
            if not chunk:
                continue
            out.append(("num", chunk[1:]) if chunk.startswith("#") else ("text", chunk))
    return out


def word_metrics(parts, size: float, icon_h: float):
    """v1.word_metrics plus number parts (same font, measured like text)."""
    x = 0.0
    pieces = []
    for kind, value in parts:
        if kind == "icon":
            if pieces and pieces[-1][0] in ("text", "num") and not pieces[-1][1].endswith(NBSP):
                x += 0.06 * size
            img = v1.icon_at_height(value, icon_h)
            pieces.append(("icon", value, x, img))
            x += img.width + 0.07 * size
        else:
            pieces.append((kind, value, x, None))
            x += TEXT.width(value, size)
    return x, pieces


def word_box(word: dict, size: float, icon_h: float, k: float):
    if "pattern" in word:
        w, h = pattern_size(word["pattern"], INLINE_SCALE)
        return w * k, h * k, None
    width, pieces = word_metrics(word["parts"], size, icon_h)
    return width, LINE_PITCH * k, pieces


PHRASE_PENALTY = [12.0]  # > one line: an extra line beats a broken phrase (relaxed to 4 when that cannot fit)


def break_cost(prev: dict, nxt: dict) -> float:
    text = prev["raw"]
    if text.endswith("."):
        return -1.0
    if text.endswith((",", ":")):
        return -0.6
    if text.lower() in FUNCTION_WORDS and not (text.lower() == "enemy" and nxt["raw"] in PHRASE_STARTERS):
        return PHRASE_PENALTY[0]
    if nxt["raw"] in PHRASE_STARTERS:
        return -0.3
    if "pattern" in nxt:
        return 3.0  # a diagram stays beside the words it shapes
    return 0.0


def wrap(words: list[dict], size: float, icon_h: float, width: float, k: float):
    boxes = [word_box(w, size, icon_h, k) for w in words]
    space = TEXT.width(" ", size)
    n = len(words)

    def line_w(i: int, j: int) -> float:
        return sum(b[0] for b in boxes[i:j]) + space * (j - i - 1)

    inf = float("inf")
    best = [(inf, -1)] * (n + 1)
    best[0] = (0.0, -1)
    for j in range(1, n + 1):
        for i in range(j):
            if best[i][0] == inf:
                continue
            w = line_w(i, j)
            if w > width and j - i > 1:
                continue
            cost = 10.0 + (1000.0 if w > width else 0.0)
            if j < n:
                cost += ((width - w) / width) ** 2 + break_cost(words[j - 1], words[j])
            if best[i][0] + cost < best[j][0]:
                best[j] = (best[i][0] + cost, i)
    cuts = []
    j = n
    while j > 0:
        i = best[j][1]
        cuts.append((i, j))
        j = i
    cuts.reverse()
    lines = []
    for i, j in cuts:
        h = max(b[1] for b in boxes[i:j])
        lines.append({"words": list(range(i, j)), "width": line_w(i, j), "height": max(h + (2.0 * k if h > LINE_PITCH * k else 0.0), LINE_PITCH * k)})
    return lines, boxes, space


def sentence_layout(spec: dict, width: float, k: float):
    words = parse(spec["text"])
    # Keep the last two words together, as card_widget does for Rite text.
    if len(words) >= 2 and "pattern" not in words[-1] and "pattern" not in words[-2]:
        last = words.pop()
        joined = words[-1]["raw"] + "~" + last["raw"]
        words[-1] = {"parts": _num_parts(v1.parse_word(joined)), "raw": joined}
    # Break lines at one reference resolution so every size shows the same
    # lines (rounded icon pixels must not move a break), then measure at k.
    ref_size = v1.TEXT_SIZE * K_REF
    ref_lines, _, _ = wrap(words, ref_size, TEXT.cap * ref_size * v1.ICON_CAP_RATIO, width * K_REF, K_REF)
    size = v1.TEXT_SIZE * k
    icon_h = TEXT.cap * size * v1.ICON_CAP_RATIO
    boxes = [word_box(w, size, icon_h, k) for w in words]
    space = TEXT.width(" ", size)
    lines = []
    for ref in ref_lines:
        idx = ref["words"]
        w = sum(boxes[i][0] for i in idx) + space * (len(idx) - 1)
        h = max(boxes[i][1] for i in idx)
        lines.append({"words": idx, "width": w, "height": max(h + (2.0 * k if h > LINE_PITCH * k else 0.0), LINE_PITCH * k)})
    return words, lines, boxes, space, size, icon_h


# ------------------------------------------------------------------ layout
def plan(spec: dict) -> dict:
    PHRASE_PENALTY[0] = 12.0
    result = _plan_any(spec)
    if not result["fits"]:
        PHRASE_PENALTY[0] = 4.0
        relaxed = _plan_any(spec)
        if relaxed["fits"]:
            relaxed["phrase_breaks_needed"] = True
            return relaxed
        PHRASE_PENALTY[0] = 12.0
    return result


def _plan_any(spec: dict) -> dict:
    result = _plan_one(spec)
    if not result["fits"] and spec.get("alt"):
        alt = dict(spec)
        alt.update(spec["alt"])
        alt.pop("under", None)
        alt.pop("alt", None)
        alt_result = _plan_one(alt)
        alt_result["spec"] = alt
        alt_result["diagram_inline_fallback"] = True
        alt_result["primary_lines"] = result["lines"]
        alt_result["primary_total"] = result["total"]
        return alt_result
    result["spec"] = spec
    return result


def _plan_one(spec: dict) -> dict:
    """Widest wrap and smallest art lend whose chip, lines and diagrams all
    clear the parchment edge (local units, k = 1)."""
    chip_h = v1.CHIP_HEIGHT + v1.CHIP_GAP if spec.get("chip") else 2.0
    chip_w = v1.chip_layout(spec["chip"], 1.0)[2] if spec.get("chip") else 0.0
    under = spec.get("under")
    for width, scale in [(w, us) for w in WIDTHS for us in (UNDER_SCALES if under else [0.0])]:
        size_u = under_size(under, scale) if under else (0.0, 0.0)
        words, lines, boxes, space, size, icon_h = sentence_layout(spec, width, 1.0)
        text_h = sum(l["height"] for l in lines)
        total = v1.TOP_PAD + chip_h + text_h + ((DIAGRAM_GAP + size_u[1]) if under else 0.0)
        need = max(0.0, total + VERTICAL_PADDING - DETAILS_HEIGHT)
        lend = need
        while lend <= MAX_RELIEF + 1e-6:
            top = ROWS_TOP - lend
            ok = True
            y = top + v1.TOP_PAD
            if spec.get("chip") and chip_w / 2 > c2.allowed_half_width(y, y + v1.CHIP_HEIGHT):
                ok = False
            y += chip_h
            for line in lines:
                if line["width"] / 2 > c2.allowed_half_width(y, y + line["height"]):
                    ok = False
                y += line["height"]
            if under and ok:
                y += DIAGRAM_GAP
                if size_u[0] / 2 > c2.allowed_half_width(y, y + size_u[1]):
                    ok = False
            if ok:
                return {"width": width, "lend": round(lend, 1), "lines": len(lines), "total": round(total, 1), "under_scale": scale,
                        "line_text": [" ".join(words[i]["raw"] for i in l["words"]).replace("~", " ") for l in lines],
                        "fits": True}
            lend += 0.5
    # Nothing clears the edge: show the full-width face at the maximum art
    # lend, flagged, so the overflow is visible.
    words, lines, boxes, space, size, icon_h = sentence_layout(spec, WIDTHS[0], 1.0)
    text_h = sum(l["height"] for l in lines)
    size_u = under_size(under, UNDER_SCALES[-1]) if under else (0.0, 0.0)
    total = v1.TOP_PAD + chip_h + text_h + ((DIAGRAM_GAP + size_u[1]) if under else 0.0)
    return {"width": WIDTHS[0], "lend": MAX_RELIEF, "under_scale": UNDER_SCALES[-1], "lines": len(lines), "total": round(total, 1), "fits": False,
            "line_text": [" ".join(words[i]["raw"] for i in l["words"]).replace("~", " ") for l in lines]}


def under_size(pids: list[str], scale: float) -> tuple[float, float]:
    sizes = [pattern_size(pid, scale) for pid in pids]
    arrow = TEXT.width("\u2192", v1.TEXT_SIZE) + 2 * ORDER_GAP
    return sum(w for w, _ in sizes) + arrow * (len(sizes) - 1), max(h for _, h in sizes)


def render(layer: Image.Image, spec: dict, pl: dict, k: float, center_x: float, top: float) -> None:
    y = top + v1.TOP_PAD * k
    if spec.get("chip"):
        v1.draw_chip(layer, spec["chip"], k / SS, center_x, y)
        y += (v1.CHIP_HEIGHT + v1.CHIP_GAP) * k
    else:
        y += 2.0 * k
    words, lines, boxes, space, size, icon_h = sentence_layout(spec, pl["width"], k)
    outline_layer = Image.new("RGBA", layer.size, (0, 0, 0, 0))
    number_layer = Image.new("RGBA", layer.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)
    cap = TEXT.cap * size
    ascent = round(TEXT.ascent * v1.TEXT_SIZE) * k
    for line in lines:
        x = center_x - line["width"] / 2.0
        baseline = y + (line["height"] - LINE_PITCH * k) / 2.0 + ascent
        mid = baseline - cap / 2.0
        for index in line["words"]:
            word = words[index]
            w, h, pieces = boxes[index]
            if "pattern" in word:
                draw_pattern(layer, word["pattern"], x, y + (line["height"] - h) / 2.0, w, h, INLINE_SCALE, k)
            else:
                for kind, value, dx, img in pieces:
                    if kind == "num":
                        # The simple cards' number style: dark value ink, light outline.
                        c2.draw_label((outline_layer, number_layer), x + dx, baseline, value, size, k)
                    elif kind == "text":
                        TEXT.draw(draw, x + dx, baseline, value, size, v1.INK)
                    else:
                        layer.alpha_composite(img, (int(round(x + dx)), int(round(mid - img.height / 2.0))))
            x += w + space
        y += line["height"]
    layer.alpha_composite(outline_layer)
    layer.alpha_composite(number_layer)
    if spec.get("under"):
        scale = pl["under_scale"]
        w, h = under_size(spec["under"], scale)
        y += DIAGRAM_GAP * k
        x = center_x - w * k / 2.0
        for index, pid in enumerate(spec["under"]):
            pw, ph = pattern_size(pid, scale)
            if index > 0:
                # Order mark between diagrams: the sentence's order, no words.
                ax = x + ORDER_GAP * k
                TEXT.draw(draw, ax, y + (h * k) / 2.0 + TEXT.cap * size / 2.0, "\u2192", size, v1.INK)
                x = ax + TEXT.width("\u2192", size) + ORDER_GAP * k
            draw_pattern(layer, pid, x, y + (h - ph) * k / 2.0, pw * k, ph * k, scale, k)
            x += pw * k


def compose(card_id: str, mode: str, old_manifest: dict, manifest: dict):
    info = old_manifest[card_id][mode]
    box = v1.crop_box(info)
    old = Image.open(os.path.join(v1.CAPTURES, "%s_%s.png" % (mode, card_id))).convert("RGBA").crop(box)
    spec = SPECS[card_id]
    if spec is None:
        return old, old.copy(), {"control": True}
    pl = plan(spec)
    spec = pl.pop("spec")
    captured = manifest[card_id]
    assert abs(float(captured["lend"]) - pl["lend"]) < 0.05, (card_id, captured["lend"], pl["lend"])
    vinfo = captured[mode]
    assert v1.crop_box(vinfo) == box
    blank = Image.open(os.path.join(CAPTURES, "%s_%s_blank.png" % (mode, card_id))).convert("RGBA").crop(box)
    k = vinfo["scale"][0] * SS
    layer = Image.new("RGBA", (blank.width * SS, blank.height * SS), (0, 0, 0, 0))
    center_x = (vinfo["origin"][0] - box[0]) * SS + 125.0 * k
    top = (vinfo["rows_rect"][1] - box[1]) * SS
    render(layer, spec, pl, k, center_x, top)
    small = layer.convert("RGBa").resize(blank.size, Image.LANCZOS).convert("RGBA")
    new = blank.copy()
    new.alpha_composite(small)
    meta = dict(pl)
    meta["control"] = False
    return old, new, meta


# ------------------------------------------------------------------ sheets
def triple_image(card_id: str, old: Image.Image, first: Image.Image, second: Image.Image, meta: dict) -> Image.Image:
    gap, pad, head, foot = 12, 10, 32, 26
    sheet = Image.new("RGB", (pad * 2 + old.width + first.width + second.width + gap * 2, head + old.height + foot), v1.BG)
    d = ImageDraw.Draw(sheet)
    d.text((pad, 7), v1.NAMES[card_id], font=v1.label_font(19), fill=v1.CREAM)
    x = pad
    for image, tag in ((old, "OLD"), (first, "v4"), (second, "v5")):
        sheet.paste(image, (x, head), image)
        colour = v1.MUTED
        if tag == "v5":
            if meta.get("control"):
                tag = "v5 = old (simple card)"
            else:
                tag = "v5  %d line%s" % (meta["lines"], "" if meta["lines"] == 1 else "s")
                if meta["lines"] > 4:
                    tag += "  OVER 4"
                    colour = v1.WARN
                if not meta["fits"]:
                    tag += "  TOUCHES EDGE"
                    colour = v1.WARN
        d.text((x + 4, head + old.height + 5), tag, font=v1.label_font(13), fill=colour)
        x += image.width + gap
    return sheet


def main() -> int:
    if len(sys.argv) > 1 and sys.argv[1] == "plan":
        os.makedirs(OUT, exist_ok=True)
        lends = {cid: plan(spec)["lend"] for cid, spec in SPECS.items() if spec is not None}
        with open(os.path.join(OUT, "lends.json"), "w") as handle:
            json.dump(lends, handle, indent=1)
        for cid, spec in SPECS.items():
            if spec is not None:
                pl = plan(spec)
                pl.pop("spec")
                print("%-17s width=%.0f lend=%.1f lines=%d fits=%s %s" % (cid, pl["width"], pl["lend"], pl["lines"], pl["fits"], pl["line_text"]))
        return 0
    old_manifest = json.load(open(os.path.join(v1.CAPTURES, "manifest.json")))
    manifest = json.load(open(os.path.join(CAPTURES, "manifest.json")))
    for sub in ("old_faces", "new_faces", "pairs_hover"):
        os.makedirs(os.path.join(OUT, sub), exist_ok=True)
    report = {}
    triples = []
    hand = []
    for index, card_id in enumerate(v1.ORDER, start=1):
        old, new, meta = compose(card_id, "hover", old_manifest, manifest)
        old.save(os.path.join(OUT, "old_faces", "%02d_%s_hover.png" % (index, card_id)))
        new.save(os.path.join(OUT, "new_faces", "%02d_%s_hover.png" % (index, card_id)))
        first = Image.open(os.path.join(V1_NEW, "%02d_%s_hover.png" % (index, card_id))).convert("RGBA")
        triple = triple_image(card_id, old, first, new, meta)
        triple.save(os.path.join(OUT, "pairs_hover", "%02d_%s_old_v4_v5_hover.png" % (index, card_id)))
        triples.append(triple)
        hold, hnew, hmeta = compose(card_id, "hand", old_manifest, manifest)
        hnew.save(os.path.join(OUT, "new_faces", "%02d_%s_hand.png" % (index, card_id)))
        hand.append((card_id, hnew, hmeta))
        report[card_id] = meta
    cols = 2
    cw = max(t.width for t in triples)
    ch = max(t.height for t in triples)
    sheet = Image.new("RGB", (cols * cw, 56 + ((len(triples) + 1) // cols) * ch), v1.BG)
    d = ImageDraw.Draw(sheet)
    d.text((16, 12), "Mock faces OLD | v4 | v5, hover-enlarged size (1920x1080, 100% UI scale, real renderer + PIL composite)",
           font=v1.label_font(22), fill=v1.CREAM)
    for i, t in enumerate(triples):
        sheet.paste(t, ((i % cols) * cw, 56 + (i // cols) * ch))
    sheet.save(os.path.join(OUT, "contact_sheet_old_v4_v5_hover.png"))
    hcols = 6
    hw = max(im.width for _, im, _ in hand) + 16
    hh = max(im.height for _, im, _ in hand) + 48
    hs = Image.new("RGB", (hcols * hw + 16, 56 + 2 * hh), v1.BG)
    d = ImageDraw.Draw(hs)
    d.text((16, 12), "v5 faces at normal hand size (208 px wide, 1:1)", font=v1.label_font(22), fill=v1.CREAM)
    for i, (card_id, im, meta) in enumerate(hand):
        x = 16 + (i % hcols) * hw
        y = 56 + (i // hcols) * hh
        hs.paste(im, (x, y), im)
        d.text((x + 4, y + im.height + 6), v1.NAMES[card_id] + ("  (old face)" if meta.get("control") else ""),
               font=v1.label_font(14), fill=v1.MUTED)
        if not meta.get("control") and (meta["lines"] > 4 or not meta["fits"]):
            flag = "%d lines (over 4)" % meta["lines"] if meta["lines"] > 4 else ""
            if not meta["fits"]:
                flag += ("; " if flag else "") + "touches edge"
            d.text((x + 4, y + im.height + 24), flag, font=v1.label_font(12), fill=v1.WARN)
    hs.save(os.path.join(OUT, "v5_faces_hand_size_sheet.png"))
    with open(os.path.join(OUT, "compose_v5_report.json"), "w") as handle:
        json.dump(report, handle, indent=2)
    for card_id in v1.ORDER:
        meta = report[card_id]
        if meta.get("control"):
            print("%-17s old face" % card_id)
        else:
            print("%-17s lines=%d width=%.0f lend=%.1f fits=%s" % (card_id, meta["lines"], meta["width"], meta["lend"], meta["fits"]))
            for t in meta["line_text"]:
                print("      | " + t)
    return 0


if __name__ == "__main__":
    sys.exit(main())
