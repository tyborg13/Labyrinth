#!/usr/bin/env python3
"""Build the readable Labyrinth Crumble optical font family.

The family is a deterministic, project-owned derivative of the OFL-licensed
Bitter variable font.  Three optical cuts share one sturdy slab-serif skeleton:

* Display Black: hero titles and banners, with bold exterior edge wear.
* UI ExtraBold: headings, buttons, card names, and short action labels.
* Text Semibold: rules, dialogue, tooltips, logs, stats, and captions.

Glyphs are rasterized at a high design resolution, receive stepped chips only
from the exterior silhouette, and are traced back into TrueType outlines.  A
chip is accepted only when it preserves both filled-component and counter
counts, so distress cannot cut a stem apart or punch through a counter.

Requires fontTools and Pillow.  Generated binaries must not be hand-edited.
"""

from __future__ import annotations

import argparse
import base64
import json
import random
import tempfile
from collections import defaultdict, deque
from dataclasses import asdict, dataclass
from pathlib import Path
from typing import Iterable, Sequence

from fontTools.fontBuilder import FontBuilder
from fontTools.pens.ttGlyphPen import TTGlyphPen
from fontTools.ttLib import TTFont
from fontTools.varLib.instancer import instantiateVariableFont
from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[1]
FONT_DIR = ROOT / "fonts"
SOURCE_FONT_PATH = FONT_DIR / "source" / "Bitter[wght].ttf"
SOURCE_LICENSE_PATH = FONT_DIR / "source" / "Bitter-OFL.txt"
PREVIEW_NAME = "LabyrinthCrumble-preview.png"
MANIFEST_NAME = "LabyrinthCrumble-family.json"

FAMILY_NAME = "Labyrinth Crumble"
VERSION = "Version 2.0"
UNITS_PER_EM = 1000
RASTER_EM = 256
FIXED_FONT_TIMESTAMP = 3_850_070_400  # 2026-01-01 in the TrueType epoch.
COPYRIGHT = (
    "Copyright 2026 Labyrinth project contributors. "
    "Derived from Bitter, Copyright 2011 The Bitter Project Authors. "
    "Licensed under the SIL Open Font License, Version 1.1."
)

ASCII = "".join(chr(codepoint) for codepoint in range(32, 127))
PROJECT_SYMBOLS = "·→∞±–—◆↻←›•×−…“”‘’"
SUPPORTED_CHARS = ASCII + PROJECT_SYMBOLS


@dataclass(frozen=True)
class FontCut:
    key: str
    style_name: str
    filename_stem: str
    weight: int
    chip_min: int
    chip_max: int
    chip_width: tuple[int, int]
    chip_depth: tuple[int, int]
    chip_probability: float
    seed: int


CUTS = (
    FontCut(
        key="display",
        style_name="Display Black",
        filename_stem="LabyrinthCrumble-Display",
        weight=900,
        chip_min=3,
        chip_max=5,
        chip_width=(12, 24),
        chip_depth=(7, 12),
        chip_probability=1.0,
        seed=0xD15A,
    ),
    FontCut(
        key="ui",
        style_name="UI ExtraBold",
        filename_stem="LabyrinthCrumble-UI",
        weight=800,
        chip_min=2,
        chip_max=4,
        chip_width=(10, 18),
        chip_depth=(6, 10),
        chip_probability=1.0,
        seed=0x51B0,
    ),
    FontCut(
        key="text",
        style_name="Text Semibold",
        filename_stem="LabyrinthCrumble-Text",
        weight=600,
        chip_min=1,
        chip_max=2,
        chip_width=(7, 13),
        chip_depth=(4, 7),
        chip_probability=0.9,
        seed=0x7E47,
    ),
)


def _safe_glyph_name(char: str) -> str:
    if char == " ":
        return "space"
    if char.isascii() and char.isalpha():
        return char
    if char.isascii() and char.isdigit():
        return f"digit{char}"
    return f"uni{ord(char):04X}"


def _boolean_mask(image: Image.Image, threshold: int = 120) -> list[list[bool]]:
    gray = image.convert("L")
    width, height = gray.size
    pixels = gray.load()
    return [[bool(pixels[x, y] >= threshold) for x in range(width)] for y in range(height)]


def _neighbors4(x: int, y: int) -> Iterable[tuple[int, int]]:
    yield x - 1, y
    yield x + 1, y
    yield x, y - 1
    yield x, y + 1


def _filled_component_count(mask: Sequence[Sequence[bool]]) -> int:
    height = len(mask)
    width = len(mask[0]) if height else 0
    seen: set[tuple[int, int]] = set()
    count = 0
    for y in range(height):
        for x in range(width):
            if not mask[y][x] or (x, y) in seen:
                continue
            count += 1
            queue = deque([(x, y)])
            seen.add((x, y))
            while queue:
                current_x, current_y = queue.popleft()
                for neighbor_x, neighbor_y in _neighbors4(current_x, current_y):
                    if (
                        0 <= neighbor_x < width
                        and 0 <= neighbor_y < height
                        and mask[neighbor_y][neighbor_x]
                        and (neighbor_x, neighbor_y) not in seen
                    ):
                        seen.add((neighbor_x, neighbor_y))
                        queue.append((neighbor_x, neighbor_y))
    return count


def _exterior_empty(mask: Sequence[Sequence[bool]]) -> set[tuple[int, int]]:
    height = len(mask)
    width = len(mask[0]) if height else 0
    exterior: set[tuple[int, int]] = set()
    queue: deque[tuple[int, int]] = deque()
    for x in range(width):
        for y in (0, height - 1):
            if not mask[y][x] and (x, y) not in exterior:
                exterior.add((x, y))
                queue.append((x, y))
    for y in range(height):
        for x in (0, width - 1):
            if not mask[y][x] and (x, y) not in exterior:
                exterior.add((x, y))
                queue.append((x, y))
    while queue:
        current_x, current_y = queue.popleft()
        for neighbor_x, neighbor_y in _neighbors4(current_x, current_y):
            if (
                0 <= neighbor_x < width
                and 0 <= neighbor_y < height
                and not mask[neighbor_y][neighbor_x]
                and (neighbor_x, neighbor_y) not in exterior
            ):
                exterior.add((neighbor_x, neighbor_y))
                queue.append((neighbor_x, neighbor_y))
    return exterior


def _counter_count(mask: Sequence[Sequence[bool]]) -> int:
    height = len(mask)
    width = len(mask[0]) if height else 0
    exterior = _exterior_empty(mask)
    seen = set(exterior)
    counters = 0
    for y in range(height):
        for x in range(width):
            if mask[y][x] or (x, y) in seen:
                continue
            counters += 1
            queue = deque([(x, y)])
            seen.add((x, y))
            while queue:
                current_x, current_y = queue.popleft()
                for neighbor_x, neighbor_y in _neighbors4(current_x, current_y):
                    if (
                        0 <= neighbor_x < width
                        and 0 <= neighbor_y < height
                        and not mask[neighbor_y][neighbor_x]
                        and (neighbor_x, neighbor_y) not in seen
                    ):
                        seen.add((neighbor_x, neighbor_y))
                        queue.append((neighbor_x, neighbor_y))
    return counters


def _structure_signature(mask: Sequence[Sequence[bool]]) -> tuple[int, int]:
    return _filled_component_count(mask), _counter_count(mask)


def _copy_mask(mask: Sequence[Sequence[bool]]) -> list[list[bool]]:
    return [list(row) for row in mask]


def _glyph_seed(char: str, cut: FontCut) -> int:
    return cut.seed + sum((index + 1) * ord(value) * 9173 for index, value in enumerate(char))


def _requested_chip_count(char: str, cut: FontCut, rng: random.Random) -> int:
    if not char.isalnum() or rng.random() > cut.chip_probability:
        return 0
    return rng.randint(cut.chip_min, cut.chip_max)


def _exterior_edge_candidates(
    mask: Sequence[Sequence[bool]],
) -> list[tuple[int, int, int, int]]:
    exterior = _exterior_empty(mask)
    height = len(mask)
    width = len(mask[0]) if height else 0
    candidates: list[tuple[int, int, int, int]] = []
    for y in range(height):
        for x in range(width):
            if not mask[y][x]:
                continue
            for outside_dx, outside_dy in ((-1, 0), (1, 0), (0, -1), (0, 1)):
                outside = (x + outside_dx, y + outside_dy)
                if outside in exterior:
                    candidates.append((x, y, -outside_dx, -outside_dy))
    return candidates


def _inward_run(
    mask: Sequence[Sequence[bool]], x: int, y: int, inward_dx: int, inward_dy: int
) -> int:
    height = len(mask)
    width = len(mask[0]) if height else 0
    run = 0
    while 0 <= x < width and 0 <= y < height and mask[y][x]:
        run += 1
        x += inward_dx
        y += inward_dy
    return run


def _apply_wedge_chip(
    mask: list[list[bool]],
    x: int,
    y: int,
    inward_dx: int,
    inward_dy: int,
    width: int,
    depth: int,
) -> int:
    tangent_dx, tangent_dy = -inward_dy, inward_dx
    removed = 0
    for step in range(depth):
        center_x = x + inward_dx * step
        center_y = y + inward_dy * step
        radius = max(0, round((width - 1) * (depth - step) / max(1, depth) / 2.0))
        for tangent_step in range(-radius, radius + 1):
            pixel_x = center_x + tangent_dx * tangent_step
            pixel_y = center_y + tangent_dy * tangent_step
            if (
                0 <= pixel_y < len(mask)
                and 0 <= pixel_x < len(mask[0])
                and mask[pixel_y][pixel_x]
            ):
                mask[pixel_y][pixel_x] = False
                removed += 1
    return removed


def chip_exterior_mask(
    mask: Sequence[Sequence[bool]], char: str, cut: FontCut
) -> tuple[list[list[bool]], int, int]:
    """Return a safely chipped copy plus accepted chip/pixel counts."""

    result = _copy_mask(mask)
    baseline_signature = _structure_signature(result)
    rng = random.Random(_glyph_seed(char, cut))
    requested = _requested_chip_count(char, cut, rng)
    accepted = 0
    removed_pixels = 0
    attempts = 0
    while accepted < requested and attempts < max(24, requested * 40):
        attempts += 1
        candidates = _exterior_edge_candidates(result)
        if not candidates:
            break
        x, y, inward_dx, inward_dy = rng.choice(candidates)
        depth = rng.randint(*cut.chip_depth)
        width = rng.randint(*cut.chip_width)
        if _inward_run(result, x, y, inward_dx, inward_dy) < depth * 2 + 2:
            continue
        trial = _copy_mask(result)
        removed = _apply_wedge_chip(trial, x, y, inward_dx, inward_dy, width, depth)
        if removed < max(2, depth):
            continue
        if _structure_signature(trial) != baseline_signature:
            continue
        result = trial
        accepted += 1
        removed_pixels += removed
    return result, accepted, removed_pixels


def _special_symbol_image(char: str) -> tuple[Image.Image, float, float, float]:
    if char != "↻":
        raise ValueError(f"No procedural symbol recipe for {char!r}")
    size = RASTER_EM
    padding = 28
    image = Image.new("L", (size + padding * 2, size + padding * 2), 0)
    draw = ImageDraw.Draw(image)
    stroke = 22
    box = (padding + 28, padding + 28, padding + size - 28, padding + size - 28)
    draw.arc(box, start=42, end=330, fill=255, width=stroke)
    draw.polygon(
        (
            (padding + size - 12, padding + 74),
            (padding + size - 88, padding + 38),
            (padding + size - 62, padding + 116),
        ),
        fill=255,
    )
    origin_x = padding
    baseline_y = padding + round(size * 0.82)
    advance = size
    return image, origin_x, baseline_y, advance


def _render_char(font: ImageFont.FreeTypeFont, char: str) -> tuple[Image.Image, float, float, float]:
    if char == "↻":
        return _special_symbol_image(char)
    bbox = font.getbbox(char, anchor="ls")
    left, top, right, bottom = bbox
    padding = 18
    width = max(1, right - left + padding * 2)
    height = max(1, bottom - top + padding * 2)
    origin_x = padding - left
    baseline_y = padding - top
    image = Image.new("L", (width, height), 0)
    ImageDraw.Draw(image).text((origin_x, baseline_y), char, font=font, fill=255, anchor="ls")
    return image, origin_x, baseline_y, float(font.getlength(char))


def _boundary_edges(mask: Sequence[Sequence[bool]]) -> set[tuple[tuple[int, int], tuple[int, int]]]:
    height = len(mask)
    width = len(mask[0]) if height else 0
    edges: set[tuple[tuple[int, int], tuple[int, int]]] = set()
    for y in range(height):
        for x in range(width):
            if not mask[y][x]:
                continue
            if y == 0 or not mask[y - 1][x]:
                edges.add(((x, y), (x + 1, y)))
            if x == width - 1 or not mask[y][x + 1]:
                edges.add(((x + 1, y), (x + 1, y + 1)))
            if y == height - 1 or not mask[y + 1][x]:
                edges.add(((x + 1, y + 1), (x, y + 1)))
            if x == 0 or not mask[y][x - 1]:
                edges.add(((x, y + 1), (x, y)))
    return edges


def _edge_direction(edge: tuple[tuple[int, int], tuple[int, int]]) -> tuple[int, int]:
    (start_x, start_y), (end_x, end_y) = edge
    return end_x - start_x, end_y - start_y


def _turn_priority(
    current: tuple[tuple[int, int], tuple[int, int]],
    candidate: tuple[tuple[int, int], tuple[int, int]],
) -> int:
    directions = ((1, 0), (0, 1), (-1, 0), (0, -1))
    current_index = directions.index(_edge_direction(current))
    next_index = directions.index(_edge_direction(candidate))
    turn = (next_index - current_index) % 4
    return {1: 0, 0: 1, 3: 2, 2: 3}[turn]


def _trace_contours(mask: Sequence[Sequence[bool]]) -> list[list[tuple[int, int]]]:
    remaining = _boundary_edges(mask)
    by_start: dict[tuple[int, int], set[tuple[tuple[int, int], tuple[int, int]]]] = defaultdict(set)
    for edge in remaining:
        by_start[edge[0]].add(edge)
    contours: list[list[tuple[int, int]]] = []
    while remaining:
        first = min(remaining)
        remaining.remove(first)
        by_start[first[0]].discard(first)
        contour = [first[0], first[1]]
        current = first
        while contour[-1] != contour[0]:
            candidates = [edge for edge in by_start.get(contour[-1], set()) if edge in remaining]
            if not candidates:
                raise RuntimeError(f"Open raster contour at {contour[-1]}")
            next_edge = min(candidates, key=lambda edge: _turn_priority(current, edge))
            remaining.remove(next_edge)
            by_start[next_edge[0]].discard(next_edge)
            contour.append(next_edge[1])
            current = next_edge
        contours.append(_simplify_contour(contour[:-1]))
    return [contour for contour in contours if len(contour) >= 3]


def _simplify_contour(contour: Sequence[tuple[int, int]]) -> list[tuple[int, int]]:
    if len(contour) < 3:
        return list(contour)
    simplified: list[tuple[int, int]] = []
    for index, point in enumerate(contour):
        previous = contour[index - 1]
        following = contour[(index + 1) % len(contour)]
        if (previous[0] == point[0] == following[0]) or (previous[1] == point[1] == following[1]):
            continue
        simplified.append(point)
    return simplified


def _mask_to_glyph(
    mask: Sequence[Sequence[bool]], origin_x: float, baseline_y: float
) -> tuple[object, int, int]:
    scale = UNITS_PER_EM / RASTER_EM
    contours = _trace_contours(mask)
    pen = TTGlyphPen(None)
    x_values: list[int] = []
    for contour in contours:
        points = [
            (round((x - origin_x) * scale), round((baseline_y - y) * scale))
            for x, y in contour
        ]
        if len(points) < 3:
            continue
        pen.moveTo(points[0])
        for point in points[1:]:
            pen.lineTo(point)
        pen.closePath()
        x_values.extend(point[0] for point in points)
    if not x_values:
        raise RuntimeError("Rendered glyph has no traced contours")
    return pen.glyph(), min(x_values), max(x_values)


def _notdef_glyph() -> object:
    pen = TTGlyphPen(None)
    pen.moveTo((80, -80))
    pen.lineTo((620, -80))
    pen.lineTo((620, 820))
    pen.lineTo((80, 820))
    pen.closePath()
    pen.moveTo((150, 0))
    pen.lineTo((150, 740))
    pen.lineTo((550, 740))
    pen.lineTo((550, 0))
    pen.closePath()
    return pen.glyph()


def _static_source_font(cut: FontCut, destination: Path) -> None:
    source = TTFont(SOURCE_FONT_PATH, recalcTimestamp=False)
    instance = instantiateVariableFont(source, {"wght": cut.weight}, inplace=False, optimize=True)
    instance.recalcTimestamp = False
    instance["head"].created = FIXED_FONT_TIMESTAMP
    instance["head"].modified = FIXED_FONT_TIMESTAMP
    instance.save(destination, reorderTables=False)


def _build_cut(cut: FontCut, source_path: Path, output_dir: Path) -> dict[str, object]:
    font = ImageFont.truetype(str(source_path), RASTER_EM)
    glyph_order = [".notdef", "space"]
    glyphs = {".notdef": _notdef_glyph(), "space": TTGlyphPen(None).glyph()}
    metrics: dict[str, tuple[int, int]] = {
        ".notdef": (700, 80),
        "space": (round(font.getlength(" ") * UNITS_PER_EM / RASTER_EM), 0),
    }
    cmap = {ord(" "): "space"}
    total_chips = 0
    total_removed_pixels = 0
    glyph_stats: dict[str, dict[str, int]] = {}
    for char in SUPPORTED_CHARS:
        if char == " ":
            continue
        name = _safe_glyph_name(char)
        image, origin_x, baseline_y, source_advance = _render_char(font, char)
        original_mask = _boolean_mask(image)
        chipped_mask, chips, removed_pixels = chip_exterior_mask(original_mask, char, cut)
        glyph, x_min, x_max = _mask_to_glyph(chipped_mask, origin_x, baseline_y)
        advance = max(round(source_advance * UNITS_PER_EM / RASTER_EM), x_max + 24)
        glyph_order.append(name)
        glyphs[name] = glyph
        metrics[name] = (advance, x_min)
        cmap[ord(char)] = name
        total_chips += chips
        total_removed_pixels += removed_pixels
        glyph_stats[char] = {
            "chips": chips,
            "removed_pixels": removed_pixels,
            "components": _filled_component_count(chipped_mask),
            "counters": _counter_count(chipped_mask),
        }

    builder = FontBuilder(UNITS_PER_EM, isTTF=True)
    builder.setupGlyphOrder(glyph_order)
    builder.setupCharacterMap(cmap)
    builder.setupGlyf(glyphs)
    builder.setupHorizontalMetrics(metrics)
    builder.setupHorizontalHeader(ascent=850, descent=-250, lineGap=80)
    builder.setupOS2(
        sTypoAscender=850,
        sTypoDescender=-250,
        sTypoLineGap=80,
        usWinAscent=900,
        usWinDescent=260,
        usWeightClass=cut.weight,
        usWidthClass=5,
        achVendID="LBRN",
        sxHeight=520,
        sCapHeight=720,
    )
    full_name = f"{FAMILY_NAME} {cut.style_name}"
    builder.setupNameTable(
        {
            "familyName": FAMILY_NAME,
            "styleName": cut.style_name,
            "uniqueFontIdentifier": f"{full_name} {VERSION}",
            "fullName": full_name,
            "psName": cut.filename_stem,
            "version": VERSION,
            "copyright": COPYRIGHT,
            "licenseDescription": "SIL Open Font License, Version 1.1",
            "licenseInfoURL": "https://openfontlicense.org",
        }
    )
    builder.setupPost(keepGlyphNames=True)
    builder.setupMaxp()
    builder.setupHead(created=FIXED_FONT_TIMESTAMP, modified=FIXED_FONT_TIMESTAMP)
    ttf_path = output_dir / f"{cut.filename_stem}.ttf"
    builder.save(ttf_path)
    _write_tres(ttf_path, output_dir / f"{cut.filename_stem}.tres", cut)
    return {
        "key": cut.key,
        "style_name": cut.style_name,
        "weight": cut.weight,
        "ttf": ttf_path.name,
        "tres": f"{cut.filename_stem}.tres",
        "total_chips": total_chips,
        "total_removed_pixels": total_removed_pixels,
        "glyphs": glyph_stats,
    }


def _write_tres(ttf_path: Path, tres_path: Path, cut: FontCut) -> None:
    encoded = base64.b64encode(ttf_path.read_bytes()).decode("ascii")
    tres_path.write_text(
        "\n".join(
            (
                '[gd_resource type="FontFile" format=4]',
                "",
                "[resource]",
                f'data = PackedByteArray("{encoded}")',
                f'font_name = "{FAMILY_NAME}"',
                f'style_name = "{cut.style_name}"',
                "subpixel_positioning = 0",
                "msdf_pixel_range = 12",
                "msdf_size = 128",
                "",
            )
        ),
        encoding="utf-8",
    )


def _draw_button(
    draw: ImageDraw.ImageDraw,
    rect: tuple[int, int, int, int],
    label: str,
    font: ImageFont.FreeTypeFont,
) -> None:
    draw.rounded_rectangle(rect, radius=5, fill="#111319", outline="#9b713c", width=2)
    left, top, right, bottom = draw.textbbox((0, 0), label, font=font)
    x = (rect[0] + rect[2] - (right - left)) // 2
    y = (rect[1] + rect[3] - (bottom - top)) // 2 - top
    draw.text((x, y), label, font=font, fill="#f1dfba")


def _render_preview(output_dir: Path) -> None:
    display_path = output_dir / "LabyrinthCrumble-Display.ttf"
    ui_path = output_dir / "LabyrinthCrumble-UI.ttf"
    text_path = output_dir / "LabyrinthCrumble-Text.ttf"
    display_112 = ImageFont.truetype(str(display_path), 112)
    display_48 = ImageFont.truetype(str(display_path), 48)
    ui_34 = ImageFont.truetype(str(ui_path), 34)
    ui_25 = ImageFont.truetype(str(ui_path), 25)
    text_22 = ImageFont.truetype(str(text_path), 22)
    text_18 = ImageFont.truetype(str(text_path), 18)
    text_16 = ImageFont.truetype(str(text_path), 16)

    image = Image.new("RGB", (1920, 1080), "#0b0e13")
    draw = ImageDraw.Draw(image)
    draw.rectangle((24, 24, 1896, 1056), outline="#654a2d", width=2)
    draw.text((54, 44), "DISPLAY BLACK · 58–114 PX", font=text_18, fill="#c59653")
    draw.line((365, 62, 1860, 62), fill="#75532f", width=2)
    draw.text((54, 84), "ESCAPE THE UMBRA", font=display_112, fill="#f0dfbd", stroke_width=1, stroke_fill="#4c281d")
    draw.text((60, 235), "THE LABYRINTH ANSWERS", font=display_48, fill="#ead5aa")
    draw.text((1060, 235), "CHOOSE A REWARD", font=display_48, fill="#e7c786")

    draw.line((54, 318, 1866, 318), fill="#75532f", width=2)
    draw.text((54, 337), "UI EXTRABOLD · 21–38 PX", font=text_18, fill="#c59653")
    _draw_button(draw, (54, 385, 360, 463), "Continue Run", ui_34)
    _draw_button(draw, (386, 385, 674, 463), "New Game", ui_34)
    _draw_button(draw, (700, 385, 970, 463), "Settings", ui_34)
    draw.rounded_rectangle((1010, 378, 1858, 472), radius=6, fill="#111319", outline="#8a6539", width=2)
    draw.text((1040, 404), "Rallying Breath    Firebrand Volley", font=ui_34, fill="#ead8b7")

    draw.line((54, 520, 1866, 520), fill="#75532f", width=2)
    draw.text((54, 539), "TEXT SEMIBOLD · 14–18 PX", font=text_18, fill="#c59653")
    draw.rounded_rectangle((54, 584, 720, 790), radius=5, fill="#111319", outline="#8a6539", width=2)
    draw.text((84, 614), "Deal 8 damage. Move 2 tiles.", font=text_22, fill="#f0dfbd")
    draw.text((84, 656), "Hidden enemies cannot be targeted.", font=text_22, fill="#f0dfbd")
    draw.line((84, 708, 680, 708), fill="#75532f", width=1)
    draw.text((84, 735), "HP 18 / 24   EMBERS 74   TIME 6", font=ui_25, fill="#e6c98f")

    draw.text((780, 584), "ABCDEFGHIJKLMNOPQRSTUVWXYZ", font=ui_25, fill="#ead8b7")
    draw.text((780, 630), "abcdefghijklmnopqrstuvwxyz", font=text_22, fill="#ead8b7")
    draw.text((780, 676), "0123456789   . , : ; ! ? / + − %", font=text_22, fill="#ead8b7")
    draw.text((780, 728), "→  ←  ↻  ±  ×  ∞  ·  •  ◆", font=text_22, fill="#e6c98f")

    draw.line((54, 836, 1866, 836), fill="#75532f", width=2)
    draw.text((54, 856), "CRUMBLE: DISPLAY  /  UI  /  TEXT", font=text_18, fill="#c59653")
    draw.text((60, 892), "A  M  R", font=display_48, fill="#f0dfbd")
    draw.text((520, 904), "A  M  R", font=ui_34, fill="#f0dfbd")
    draw.text((900, 916), "A  M  R", font=text_22, fill="#f0dfbd")
    draw.text((1260, 904), "Crisp structure. Exterior wear.", font=text_22, fill="#b9aa91")
    draw.text((1260, 944), "No broken stems or counters.", font=text_16, fill="#8f877a")
    image.save(output_dir / PREVIEW_NAME)


def _generated_names() -> list[str]:
    names = [PREVIEW_NAME, MANIFEST_NAME]
    for cut in CUTS:
        names.extend((f"{cut.filename_stem}.ttf", f"{cut.filename_stem}.tres"))
    return names


def build_family(output_dir: Path) -> None:
    if not SOURCE_FONT_PATH.is_file() or not SOURCE_LICENSE_PATH.is_file():
        raise FileNotFoundError("The vendored Bitter source font and OFL license are required")
    output_dir.mkdir(parents=True, exist_ok=True)
    cut_results: list[dict[str, object]] = []
    with tempfile.TemporaryDirectory(prefix="labyrinth-font-source-") as temp_dir_name:
        temp_dir = Path(temp_dir_name)
        for cut in CUTS:
            source_path = temp_dir / f"source-{cut.key}.ttf"
            _static_source_font(cut, source_path)
            cut_results.append(_build_cut(cut, source_path, output_dir))
    _render_preview(output_dir)
    manifest = {
        "family": FAMILY_NAME,
        "version": VERSION,
        "source": "Bitter[wght].ttf",
        "source_license": "SIL Open Font License 1.1",
        "source_reserved_name": "Bitter Pro",
        "policy": {
            "chips": "exterior silhouette only",
            "interior_cracks": False,
            "preserve_component_count": True,
            "preserve_counter_count": True,
        },
        "cuts": cut_results,
    }
    (output_dir / MANIFEST_NAME).write_text(json.dumps(manifest, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    for name in _generated_names():
        print(f"Wrote {(output_dir / name).relative_to(ROOT) if output_dir.is_relative_to(ROOT) else output_dir / name}")


def check_generated() -> None:
    with tempfile.TemporaryDirectory(prefix="labyrinth-font-check-") as temp_dir_name:
        temp_dir = Path(temp_dir_name)
        build_family(temp_dir)
        stale = [
            name
            for name in _generated_names()
            if not (FONT_DIR / name).is_file() or (FONT_DIR / name).read_bytes() != (temp_dir / name).read_bytes()
        ]
    if stale:
        raise SystemExit("Generated font assets are stale: " + ", ".join(stale))
    print("Labyrinth Crumble generated assets are current")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="rebuild in a temporary directory and compare tracked outputs")
    args = parser.parse_args()
    if args.check:
        check_generated()
    else:
        build_family(FONT_DIR)


if __name__ == "__main__":
    main()
