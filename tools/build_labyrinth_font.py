#!/usr/bin/env python3
"""Build the Labyrinth Crumble pixel font assets.

The font is generated from small bitmap glyph plans and emitted as a TrueType
outline font so Godot can scale it like the previous third-party font while
keeping hard pixel edges. Requires fontTools and Pillow.
"""

from __future__ import annotations

import base64
import random
from pathlib import Path
from typing import Dict, List, Sequence, Tuple

from fontTools.fontBuilder import FontBuilder
from fontTools.pens.ttGlyphPen import TTGlyphPen
from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[1]
FONT_DIR = ROOT / "fonts"
TTF_PATH = FONT_DIR / "LabyrinthCrumble-Regular.ttf"
TRES_PATH = FONT_DIR / "LabyrinthCrumble-Regular.tres"
PREVIEW_PATH = FONT_DIR / "LabyrinthCrumble-preview.png"

FAMILY_NAME = "Labyrinth Crumble"
STYLE_NAME = "Regular"
FULL_NAME = f"{FAMILY_NAME} {STYLE_NAME}"
VERSION = "Version 0.1"

UNITS_PER_EM = 1000
CELL = 18
SCALE = 7
BASE_WIDTH = 5
BASE_HEIGHT = 7
SUB_WIDTH = BASE_WIDTH * SCALE
SUB_HEIGHT = BASE_HEIGHT * SCALE
LEFT_BEARING = CELL * 2
RIGHT_BEARING = CELL * 2
ADVANCE_WIDTH = (SUB_WIDTH + 2) * CELL
ASCENT = 920
DESCENT = -180
SPACE_ADVANCE = CELL * 18


BASE_PATTERNS: Dict[str, Sequence[str]] = {
    "A": (
        ".111.",
        "1...1",
        "1...1",
        "11111",
        "1...1",
        "1...1",
        "1...1",
    ),
    "B": (
        "1111.",
        "1...1",
        "1...1",
        "1111.",
        "1...1",
        "1...1",
        "1111.",
    ),
    "C": (
        ".1111",
        "1....",
        "1....",
        "1....",
        "1....",
        "1....",
        ".1111",
    ),
    "D": (
        "1111.",
        "1...1",
        "1...1",
        "1...1",
        "1...1",
        "1...1",
        "1111.",
    ),
    "E": (
        "11111",
        "1....",
        "1....",
        "1111.",
        "1....",
        "1....",
        "11111",
    ),
    "F": (
        "11111",
        "1....",
        "1....",
        "1111.",
        "1....",
        "1....",
        "1....",
    ),
    "G": (
        ".1111",
        "1....",
        "1....",
        "1.111",
        "1...1",
        "1...1",
        ".1111",
    ),
    "H": (
        "1...1",
        "1...1",
        "1...1",
        "11111",
        "1...1",
        "1...1",
        "1...1",
    ),
    "I": (
        "11111",
        "..1..",
        "..1..",
        "..1..",
        "..1..",
        "..1..",
        "11111",
    ),
    "J": (
        "11111",
        "...1.",
        "...1.",
        "...1.",
        "...1.",
        "1..1.",
        ".11..",
    ),
    "K": (
        "1...1",
        "1..1.",
        "1.1..",
        "11...",
        "1.1..",
        "1..1.",
        "1...1",
    ),
    "L": (
        "1....",
        "1....",
        "1....",
        "1....",
        "1....",
        "1....",
        "11111",
    ),
    "M": (
        "1...1",
        "11.11",
        "1.1.1",
        "1.1.1",
        "1...1",
        "1...1",
        "1...1",
    ),
    "N": (
        "1...1",
        "11..1",
        "11..1",
        "1.1.1",
        "1..11",
        "1..11",
        "1...1",
    ),
    "O": (
        ".111.",
        "1...1",
        "1...1",
        "1...1",
        "1...1",
        "1...1",
        ".111.",
    ),
    "P": (
        "1111.",
        "1...1",
        "1...1",
        "1111.",
        "1....",
        "1....",
        "1....",
    ),
    "Q": (
        ".111.",
        "1...1",
        "1...1",
        "1...1",
        "1.1.1",
        "1..1.",
        ".11.1",
    ),
    "R": (
        "1111.",
        "1...1",
        "1...1",
        "1111.",
        "1.1..",
        "1..1.",
        "1...1",
    ),
    "S": (
        ".1111",
        "1....",
        "1....",
        ".111.",
        "....1",
        "....1",
        "1111.",
    ),
    "T": (
        "11111",
        "..1..",
        "..1..",
        "..1..",
        "..1..",
        "..1..",
    ),
    "U": (
        "1...1",
        "1...1",
        "1...1",
        "1...1",
        "1...1",
        "1...1",
        ".111.",
    ),
    "V": (
        "1...1",
        "1...1",
        "1...1",
        "1...1",
        "1...1",
        ".1.1.",
        "..1..",
    ),
    "W": (
        "1...1",
        "1...1",
        "1...1",
        "1.1.1",
        "1.1.1",
        "11.11",
        "1...1",
    ),
    "X": (
        "1...1",
        "1...1",
        ".1.1.",
        "..1..",
        ".1.1.",
        "1...1",
        "1...1",
    ),
    "Y": (
        "1...1",
        "1...1",
        ".1.1.",
        "..1..",
        "..1..",
        "..1..",
        "..1..",
    ),
    "Z": (
        "11111",
        "....1",
        "...1.",
        "..1..",
        ".1...",
        "1....",
        "11111",
    ),
    "a": (
        ".....",
        ".....",
        ".111.",
        "....1",
        ".1111",
        "1...1",
        ".1111",
    ),
    "b": (
        "1....",
        "1....",
        "1.11.",
        "11..1",
        "1...1",
        "1...1",
        "1111.",
    ),
    "c": (
        ".....",
        ".....",
        ".111.",
        "1....",
        "1....",
        "1....",
        ".111.",
    ),
    "d": (
        "....1",
        "....1",
        ".11.1",
        "1..11",
        "1...1",
        "1...1",
        ".1111",
    ),
    "e": (
        ".....",
        ".....",
        ".111.",
        "1...1",
        "11111",
        "1....",
        ".111.",
    ),
    "f": (
        "..11.",
        ".1..1",
        ".1...",
        "1111.",
        ".1...",
        ".1...",
        ".1...",
    ),
    "g": (
        ".....",
        ".....",
        ".1111",
        "1...1",
        ".1111",
        "....1",
        ".111.",
    ),
    "h": (
        "1....",
        "1....",
        "1.11.",
        "11..1",
        "1...1",
        "1...1",
        "1...1",
    ),
    "i": (
        "..1..",
        ".....",
        "..1..",
        "..1..",
        "..1..",
        "..1..",
        "..1..",
    ),
    "j": (
        "...1.",
        ".....",
        "..11.",
        "...1.",
        "...1.",
        "1..1.",
        ".11..",
    ),
    "k": (
        "1....",
        "1....",
        "1..1.",
        "1.1..",
        "11...",
        "1.1..",
        "1..1.",
    ),
    "l": (
        "..1..",
        "..1..",
        "..1..",
        "..1..",
        "..1..",
        "..1..",
        "..1..",
    ),
    "m": (
        ".....",
        ".....",
        "11.1.",
        "1.1.1",
        "1.1.1",
        "1...1",
        "1...1",
    ),
    "n": (
        ".....",
        ".....",
        "1.11.",
        "11..1",
        "1...1",
        "1...1",
        "1...1",
    ),
    "o": (
        ".....",
        ".....",
        ".111.",
        "1...1",
        "1...1",
        "1...1",
        ".111.",
    ),
    "p": (
        ".....",
        ".....",
        "1111.",
        "1...1",
        "1111.",
        "1....",
        "1....",
    ),
    "q": (
        ".....",
        ".....",
        ".1111",
        "1...1",
        ".1111",
        "....1",
        "....1",
    ),
    "r": (
        ".....",
        ".....",
        "1.11.",
        "11..1",
        "1....",
        "1....",
        "1....",
    ),
    "s": (
        ".....",
        ".....",
        ".1111",
        "1....",
        ".111.",
        "....1",
        "1111.",
    ),
    "t": (
        ".1...",
        ".1...",
        "1111.",
        ".1...",
        ".1...",
        ".1..1",
        "..11.",
    ),
    "u": (
        ".....",
        ".....",
        "1...1",
        "1...1",
        "1...1",
        "1..11",
        ".11.1",
    ),
    "v": (
        ".....",
        ".....",
        "1...1",
        "1...1",
        "1...1",
        ".1.1.",
        "..1..",
    ),
    "w": (
        ".....",
        ".....",
        "1...1",
        "1...1",
        "1.1.1",
        "1.1.1",
        ".1.1.",
    ),
    "x": (
        ".....",
        ".....",
        "1...1",
        ".1.1.",
        "..1..",
        ".1.1.",
        "1...1",
    ),
    "y": (
        ".....",
        ".....",
        "1...1",
        "1...1",
        ".1111",
        "....1",
        ".111.",
    ),
    "z": (
        ".....",
        ".....",
        "11111",
        "...1.",
        "..1..",
        ".1...",
        "11111",
    ),
    "0": (
        ".111.",
        "1...1",
        "1..11",
        "1.1.1",
        "11..1",
        "1...1",
        ".111.",
    ),
    "1": (
        "..1..",
        ".11..",
        "..1..",
        "..1..",
        "..1..",
        "..1..",
        ".111.",
    ),
    "2": (
        ".111.",
        "1...1",
        "....1",
        "...1.",
        "..1..",
        ".1...",
        "11111",
    ),
    "3": (
        "1111.",
        "....1",
        "....1",
        ".111.",
        "....1",
        "....1",
        "1111.",
    ),
    "4": (
        "1...1",
        "1...1",
        "1...1",
        "11111",
        "....1",
        "....1",
        "....1",
    ),
    "5": (
        "11111",
        "1....",
        "1....",
        "1111.",
        "....1",
        "....1",
        "1111.",
    ),
    "6": (
        ".111.",
        "1....",
        "1....",
        "1111.",
        "1...1",
        "1...1",
        ".111.",
    ),
    "7": (
        "11111",
        "....1",
        "...1.",
        "..1..",
        ".1...",
        ".1...",
        ".1...",
    ),
    "8": (
        ".111.",
        "1...1",
        "1...1",
        ".111.",
        "1...1",
        "1...1",
        ".111.",
    ),
    "9": (
        ".111.",
        "1...1",
        "1...1",
        ".1111",
        "....1",
        "....1",
        ".111.",
    ),
    ".": (
        ".....",
        ".....",
        ".....",
        ".....",
        ".....",
        ".11..",
        ".11..",
    ),
    ",": (
        ".....",
        ".....",
        ".....",
        ".....",
        ".11..",
        ".11..",
        ".1...",
    ),
    "!": (
        "..1..",
        "..1..",
        "..1..",
        "..1..",
        "..1..",
        ".....",
        "..1..",
    ),
    "?": (
        ".111.",
        "1...1",
        "....1",
        "...1.",
        "..1..",
        ".....",
        "..1..",
    ),
    ":": (
        ".....",
        ".11..",
        ".11..",
        ".....",
        ".11..",
        ".11..",
        ".....",
    ),
    ";": (
        ".....",
        ".11..",
        ".11..",
        ".....",
        ".11..",
        ".11..",
        ".1...",
    ),
    "'": (
        "..1..",
        "..1..",
        ".1...",
        ".....",
        ".....",
        ".....",
        ".....",
    ),
    '"': (
        ".1.1.",
        ".1.1.",
        "1.1..",
        ".....",
        ".....",
        ".....",
        ".....",
    ),
    "-": (
        ".....",
        ".....",
        ".....",
        ".111.",
        ".....",
        ".....",
        ".....",
    ),
    "_": (
        ".....",
        ".....",
        ".....",
        ".....",
        ".....",
        ".....",
        "11111",
    ),
    "+": (
        ".....",
        "..1..",
        "..1..",
        ".111.",
        "..1..",
        "..1..",
        ".....",
    ),
    "=": (
        ".....",
        ".....",
        ".111.",
        ".....",
        ".111.",
        ".....",
        ".....",
    ),
    "/": (
        "....1",
        "....1",
        "...1.",
        "..1..",
        ".1...",
        "1....",
        "1....",
    ),
    "\\": (
        "1....",
        "1....",
        ".1...",
        "..1..",
        "...1.",
        "....1",
        "....1",
    ),
    "(": (
        "...1.",
        "..1..",
        ".1...",
        ".1...",
        ".1...",
        "..1..",
        "...1.",
    ),
    ")": (
        ".1...",
        "..1..",
        "...1.",
        "...1.",
        "...1.",
        "..1..",
        ".1...",
    ),
    "[": (
        ".111.",
        ".1...",
        ".1...",
        ".1...",
        ".1...",
        ".1...",
        ".111.",
    ),
    "]": (
        ".111.",
        "...1.",
        "...1.",
        "...1.",
        "...1.",
        "...1.",
        ".111.",
    ),
    "{": (
        "...11",
        "..1..",
        "..1..",
        ".11..",
        "..1..",
        "..1..",
        "...11",
    ),
    "}": (
        "11...",
        "..1..",
        "..1..",
        "..11.",
        "..1..",
        "..1..",
        "11...",
    ),
    "<": (
        "...1.",
        "..1..",
        ".1...",
        "1....",
        ".1...",
        "..1..",
        "...1.",
    ),
    ">": (
        ".1...",
        "..1..",
        "...1.",
        "....1",
        "...1.",
        "..1..",
        ".1...",
    ),
    "*": (
        ".....",
        "1.1.1",
        ".111.",
        "..1..",
        ".111.",
        "1.1.1",
        ".....",
    ),
    "#": (
        ".1.1.",
        ".1.1.",
        "11111",
        ".1.1.",
        "11111",
        ".1.1.",
        ".1.1.",
    ),
    "$": (
        "..1..",
        ".1111",
        "1.1..",
        ".111.",
        "..1.1",
        "1111.",
        "..1..",
    ),
    "%": (
        "11..1",
        "11.1.",
        "...1.",
        "..1..",
        ".1...",
        ".1.11",
        "1..11",
    ),
    "&": (
        ".11..",
        "1..1.",
        "1.1..",
        ".1...",
        "1.1.1",
        "1..1.",
        ".11.1",
    ),
    "@": (
        ".111.",
        "1...1",
        "1.111",
        "1.1.1",
        "1.111",
        "1....",
        ".111.",
    ),
    "|": (
        "..1..",
        "..1..",
        "..1..",
        "..1..",
        "..1..",
        "..1..",
        "..1..",
    ),
    "~": (
        ".....",
        ".....",
        ".1...",
        "1.1.1",
        "...1.",
        ".....",
        ".....",
    ),
    "`": (
        ".1...",
        "..1..",
        "...1.",
        ".....",
        ".....",
        ".....",
        ".....",
    ),
    "^": (
        "..1..",
        ".1.1.",
        "1...1",
        ".....",
        ".....",
        ".....",
        ".....",
    ),
}

PUNCTUATION_NAMES = {
    " ": "space",
    ".": "period",
    ",": "comma",
    "!": "exclam",
    "?": "question",
    ":": "colon",
    ";": "semicolon",
    "'": "quotesingle",
    '"': "quotedbl",
    "-": "hyphen",
    "_": "underscore",
    "+": "plus",
    "=": "equal",
    "/": "slash",
    "\\": "backslash",
    "(": "parenleft",
    ")": "parenright",
    "[": "bracketleft",
    "]": "bracketright",
    "{": "braceleft",
    "}": "braceright",
    "<": "less",
    ">": "greater",
    "*": "asterisk",
    "#": "numbersign",
    "$": "dollar",
    "%": "percent",
    "&": "ampersand",
    "@": "at",
    "|": "bar",
    "~": "asciitilde",
    "`": "grave",
    "^": "asciicircum",
}

EXTRA_CMAP = {
    ord("’"): "quotesingle",
    ord("‘"): "quotesingle",
    ord("“"): "quotedbl",
    ord("”"): "quotedbl",
    ord("–"): "hyphen",
    ord("—"): "hyphen",
    ord("−"): "hyphen",
    ord("×"): "X",
    ord("•"): "asterisk",
}


def glyph_name(char: str) -> str:
    if char in PUNCTUATION_NAMES:
        return PUNCTUATION_NAMES[char]
    if char.isalnum():
        return char
    raise ValueError(f"Unsupported glyph character: {char!r}")


def filled_base_cells(pattern: Sequence[str]) -> List[Tuple[int, int]]:
    cells: List[Tuple[int, int]] = []
    for row, line in enumerate(pattern):
        for col, value in enumerate(line):
            if value == "1":
                cells.append((col, row))
    return cells


def expanded_grid(char: str, pattern: Sequence[str]) -> List[List[bool]]:
    grid = [[False for _ in range(SUB_WIDTH)] for _ in range(SUB_HEIGHT)]
    for col, row in filled_base_cells(pattern):
        for y_offset in range(SCALE):
            for x_offset in range(SCALE):
                grid[row * SCALE + y_offset][col * SCALE + x_offset] = True
    if char.isalnum():
        grid = thicken_grid(grid)
        crumble_grid(char, pattern, grid)
    return grid


def thicken_grid(grid: List[List[bool]]) -> List[List[bool]]:
    thickened = [line[:] for line in grid]
    radius = 2
    for y, line in enumerate(grid):
        for x, filled in enumerate(line):
            if not filled:
                continue
            for neighbor_y in range(max(0, y - radius), min(SUB_HEIGHT, y + radius + 1)):
                for neighbor_x in range(max(0, x - radius), min(SUB_WIDTH, x + radius + 1)):
                    thickened[neighbor_y][neighbor_x] = True
    return thickened


def filled_pixels(grid: Sequence[Sequence[bool]]) -> List[Tuple[int, int]]:
    pixels: List[Tuple[int, int]] = []
    for y, line in enumerate(grid):
        for x, filled in enumerate(line):
            if filled:
                pixels.append((x, y))
    return pixels


def edge_pixels(grid: Sequence[Sequence[bool]]) -> List[Tuple[int, int]]:
    edges: List[Tuple[int, int]] = []
    for x, y in filled_pixels(grid):
        for neighbor_x, neighbor_y in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
            if (
                neighbor_x < 0
                or neighbor_x >= SUB_WIDTH
                or neighbor_y < 0
                or neighbor_y >= SUB_HEIGHT
                or not grid[neighbor_y][neighbor_x]
            ):
                edges.append((x, y))
                break
    return edges


def interior_pixels(grid: Sequence[Sequence[bool]]) -> List[Tuple[int, int]]:
    pixels: List[Tuple[int, int]] = []
    for x, y in filled_pixels(grid):
        if x <= 0 or x >= SUB_WIDTH - 1 or y <= 0 or y >= SUB_HEIGHT - 1:
            continue
        if all(
            grid[neighbor_y][neighbor_x]
            for neighbor_x, neighbor_y in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1))
        ):
            pixels.append((x, y))
    return pixels


def clear_rect(grid: List[List[bool]], center_x: int, center_y: int, width: int, height: int) -> None:
    x0 = max(0, center_x - width // 2)
    y0 = max(0, center_y - height // 2)
    x1 = min(SUB_WIDTH, x0 + width)
    y1 = min(SUB_HEIGHT, y0 + height)
    for y in range(y0, y1):
        for x in range(x0, x1):
            grid[y][x] = False


def crumble_grid(char: str, pattern: Sequence[str], grid: List[List[bool]]) -> None:
    rng = random.Random((ord(char[0]) * 9173) + 0x4C4142)
    pixels = filled_pixels(grid)
    chip_count = 1
    if len(pixels) > 240 and rng.random() < 0.72:
        chip_count += 1
    if len(pixels) > 420 and rng.random() < 0.38:
        chip_count += 1

    edges = edge_pixels(grid)
    rng.shuffle(edges)
    for index, (x, y) in enumerate(edges[:chip_count]):
        width = rng.choice((4, 5, 6 if index == 0 else 5))
        height = rng.choice((3, 4, 5))
        clear_rect(grid, x, y, width, height)

    interiors = interior_pixels(grid)
    if interiors and len(pixels) > 320 and rng.random() < 0.55:
        x, y = rng.choice(interiors)
        clear_rect(grid, x, y, rng.choice((3, 4, 5)), rng.choice((3, 4)))

    interiors = interior_pixels(grid)
    if not interiors or rng.random() > 0.82:
        return
    x, y = rng.choice(interiors)
    step_x, step_y = rng.choice(((1, 0), (0, 1), (1, 1), (-1, 1)))
    length = rng.choice((6, 7, 8, 9))
    for index in range(length):
        crack_x = x + step_x * index
        crack_y = y + step_y * index
        if 0 <= crack_x < SUB_WIDTH and 0 <= crack_y < SUB_HEIGHT and grid[crack_y][crack_x]:
            grid[crack_y][crack_x] = False
            if index % 3 == 0 and crack_y + 1 < SUB_HEIGHT and grid[crack_y + 1][crack_x]:
                grid[crack_y + 1][crack_x] = False


def draw_rect(pen: TTGlyphPen, x: int, y: int, width: int, height: int) -> None:
    pen.moveTo((x, y))
    pen.lineTo((x + width, y))
    pen.lineTo((x + width, y + height))
    pen.lineTo((x, y + height))
    pen.closePath()


def grid_bounds(grid: Sequence[Sequence[bool]]) -> Tuple[int, int, int, int]:
    pixels = filled_pixels(grid)
    if not pixels:
        return 0, 0, 0, 0
    xs = [x for x, _y in pixels]
    ys = [y for _x, y in pixels]
    return min(xs), min(ys), max(xs), max(ys)


def grid_to_glyph_and_metrics(grid: Sequence[Sequence[bool]]) -> Tuple[object, Tuple[int, int]]:
    pen = TTGlyphPen(None)
    min_x, _min_y, max_x, _max_y = grid_bounds(grid)
    content_columns = max_x - min_x + 1
    visited = [[False for _ in range(SUB_WIDTH)] for _ in range(SUB_HEIGHT)]
    for row in range(SUB_HEIGHT):
        for col in range(SUB_WIDTH):
            if visited[row][col] or not grid[row][col]:
                continue
            width = 1
            while col + width < SUB_WIDTH and grid[row][col + width] and not visited[row][col + width]:
                width += 1
            height = 1
            while row + height < SUB_HEIGHT:
                if any(not grid[row + height][col + offset] or visited[row + height][col + offset] for offset in range(width)):
                    break
                height += 1
            for mark_y in range(row, row + height):
                for mark_x in range(col, col + width):
                    visited[mark_y][mark_x] = True
            x = LEFT_BEARING + (col - min_x) * CELL
            y = (SUB_HEIGHT - row - height) * CELL
            draw_rect(pen, x, y, width * CELL, height * CELL)
    advance = LEFT_BEARING + content_columns * CELL + RIGHT_BEARING
    return pen.glyph(), (advance, LEFT_BEARING)


def notdef_glyph() -> object:
    pen = TTGlyphPen(None)
    draw_rect(pen, LEFT_BEARING, 0, SUB_WIDTH * CELL, SUB_HEIGHT * CELL)
    draw_rect(pen, LEFT_BEARING + CELL, CELL, (SUB_WIDTH - 2) * CELL, (SUB_HEIGHT - 2) * CELL)
    return pen.glyph()


def build_font() -> None:
    supported_chars = list("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789") + list(PUNCTUATION_NAMES.keys())
    glyph_order = [".notdef"]
    for char in supported_chars:
        name = glyph_name(char)
        if name not in glyph_order:
            glyph_order.append(name)

    cmap = {}
    glyf = {".notdef": notdef_glyph()}
    metrics = {".notdef": (ADVANCE_WIDTH, LEFT_BEARING)}

    for char in supported_chars:
        name = glyph_name(char)
        if name not in glyf:
            if char == " ":
                glyf[name] = TTGlyphPen(None).glyph()
                metrics[name] = (SPACE_ADVANCE, 0)
            else:
                glyph, glyph_metrics = grid_to_glyph_and_metrics(expanded_grid(char, BASE_PATTERNS[char]))
                glyf[name] = glyph
                metrics[name] = glyph_metrics
        cmap[ord(char)] = name

    cmap.update(EXTRA_CMAP)

    fb = FontBuilder(UNITS_PER_EM, isTTF=True)
    fb.setupGlyphOrder(glyph_order)
    fb.setupCharacterMap(cmap)
    fb.setupGlyf(glyf)
    fb.setupHorizontalMetrics(metrics)
    fb.setupHorizontalHeader(ascent=ASCENT, descent=DESCENT)
    fb.setupOS2(
        sTypoAscender=ASCENT,
        sTypoDescender=DESCENT,
        usWinAscent=ASCENT,
        usWinDescent=abs(DESCENT),
    )
    fb.setupNameTable(
        {
            "familyName": FAMILY_NAME,
            "styleName": STYLE_NAME,
            "uniqueFontIdentifier": f"{FULL_NAME} {VERSION}",
            "fullName": FULL_NAME,
            "psName": "LabyrinthCrumble-Regular",
            "version": VERSION,
            "copyright": "Copyright 2026 Labyrinth project contributors.",
        }
    )
    fb.setupPost()
    fb.save(TTF_PATH)


def write_tres() -> None:
    encoded = base64.b64encode(TTF_PATH.read_bytes()).decode("ascii")
    TRES_PATH.write_text(
        "\n".join(
            [
                '[gd_resource type="FontFile" format=4]',
                "",
                "[resource]",
                f'data = PackedByteArray("{encoded}")',
                f'font_name = "{FAMILY_NAME}"',
                f'style_name = "{STYLE_NAME}"',
                "subpixel_positioning = 0",
                "msdf_pixel_range = 14",
                "msdf_size = 128",
                "",
            ]
        ),
        encoding="utf-8",
    )


def render_preview() -> None:
    font_large = ImageFont.truetype(str(TTF_PATH), 48)
    font_medium = ImageFont.truetype(str(TTF_PATH), 28)
    font_small = ImageFont.truetype(str(TTF_PATH), 18)
    image = Image.new("RGB", (1600, 780), "#201914")
    draw = ImageDraw.Draw(image)
    draw.rectangle((42, 42, 1558, 738), outline="#8b6f48", width=4)
    draw.text((82, 82), "LABYRINTH CRUMBLE", font=font_large, fill="#f1dfba")
    draw.text((82, 190), "ABCDEFGHIJKLMNOPQRSTUVWXYZ", font=font_medium, fill="#e8d2a8")
    draw.text((82, 255), "abcdefghijklmnopqrstuvwxyz", font=font_medium, fill="#d7c29d")
    draw.text((82, 320), "0123456789  ! ? . , : ; ' \" - + / ( )", font=font_medium, fill="#f0c978")
    draw.text((82, 425), "Start Run    Ember Rain    Skitter Strike", font=font_small, fill="#f5ead2")
    draw.text((82, 480), "No active combat.  Choose a reward.", font=font_small, fill="#cdbca2")
    draw.text((82, 535), "ill-lit halls / brittle little relics", font=font_small, fill="#d7c29d")
    draw.text((82, 625), "STONE-CHIPPED PIXELS WITH CRACKED EDGES", font=font_medium, fill="#f1dfba")
    image.save(PREVIEW_PATH)


def main() -> None:
    FONT_DIR.mkdir(parents=True, exist_ok=True)
    build_font()
    write_tres()
    render_preview()
    print(f"Wrote {TTF_PATH.relative_to(ROOT)}")
    print(f"Wrote {TRES_PATH.relative_to(ROOT)}")
    print(f"Wrote {PREVIEW_PATH.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
