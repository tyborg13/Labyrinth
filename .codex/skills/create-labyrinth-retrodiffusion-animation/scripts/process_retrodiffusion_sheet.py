#!/usr/bin/env python3
"""Validate and clean a Retro Diffusion animation sheet for Labyrinth."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Iterable

from PIL import Image, ImageDraw


def is_suspect_matte(pixel: tuple[int, int, int, int]) -> bool:
    r, g, b, a = pixel
    if a <= 0:
        return False
    if r > 150 and g > 70 and b < 85:
        return False
    return (
        r >= 85
        and b >= 80
        and g <= 125
        and (r + b) > g * 2.35 + 50
        and abs(r - b) <= 125
    )


def transparent_neighbor_counts(pixels, x: int, y: int, width: int, height: int, radius: int) -> tuple[int, int]:
    transparent = 0
    opaque = 0
    for dy in range(-radius, radius + 1):
        for dx in range(-radius, radius + 1):
            if dx == 0 and dy == 0:
                continue
            nx = x + dx
            ny = y + dy
            if nx < 0 or ny < 0 or nx >= width or ny >= height:
                transparent += 1
            elif pixels[nx, ny][3] <= 20:
                transparent += 1
            else:
                opaque += 1
    return transparent, opaque


def cleanup_exterior_matte(image: Image.Image, passes: int, radius: int) -> int:
    pixels = image.load()
    width, height = image.size
    removed = 0
    for _ in range(passes):
        remove: list[tuple[int, int]] = []
        for y in range(height):
            for x in range(width):
                if not is_suspect_matte(pixels[x, y]):
                    continue
                transparent, opaque = transparent_neighbor_counts(pixels, x, y, width, height, radius)
                if transparent >= 5 and opaque <= 18:
                    remove.append((x, y))
        for x, y in remove:
            pixels[x, y] = (0, 0, 0, 0)
        removed += len(remove)
        if not remove:
            break
    return removed


def iter_bright_edge_matte(image: Image.Image, columns: int, rows: int) -> Iterable[tuple[int, int, tuple[int, int, int, int]]]:
    pixels = image.load()
    width, height = image.size
    cell_w = width // columns
    cell_h = height // rows
    for y in range(height):
        for x in range(width):
            r, g, b, a = pixels[x, y]
            if a <= 0:
                continue
            bright_magenta = r > 120 and b > 100 and g < 140 and (r + b) > g * 2.2
            near_sheet_edge = x < 8 or y < 8 or x >= width - 8 or y >= height - 8
            near_cell_edge = x % cell_w < 4 or y % cell_h < 4 or x % cell_w > cell_w - 5 or y % cell_h > cell_h - 5
            if bright_magenta and (near_sheet_edge or near_cell_edge):
                yield x, y, (r, g, b, a)


def write_contact_sheet(image: Image.Image, path: Path, columns: int, rows: int, scale: float) -> None:
    cell_w = image.width // columns
    cell_h = image.height // rows
    checker = Image.new("RGBA", image.size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(checker)
    tile = 16
    for y in range(0, image.height, tile):
        for x in range(0, image.width, tile):
            color = (52, 52, 58, 255) if ((x // tile + y // tile) % 2) else (96, 96, 104, 255)
            draw.rectangle([x, y, x + tile - 1, y + tile - 1], fill=color)
    checker.alpha_composite(image)
    for x in range(0, image.width + 1, cell_w):
        draw.line([(x, 0), (x, image.height)], fill=(255, 255, 255, 120), width=2)
    for y in range(0, image.height + 1, cell_h):
        draw.line([(0, y), (image.width, y)], fill=(255, 255, 255, 120), width=2)
    if scale != 1.0:
        size = (max(1, int(checker.width * scale)), max(1, int(checker.height * scale)))
        checker = checker.resize(size, Image.Resampling.NEAREST)
    path.parent.mkdir(parents=True, exist_ok=True)
    checker.save(path)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--columns", type=int, default=4)
    parser.add_argument("--rows", type=int, default=4)
    parser.add_argument("--expected-cell", type=int, default=255)
    parser.add_argument("--cleanup-passes", type=int, default=3)
    parser.add_argument("--neighbor-radius", type=int, default=2)
    parser.add_argument("--contact-sheet", type=Path)
    parser.add_argument("--contact-scale", type=float, default=0.5)
    parser.add_argument("--report-json", type=Path)
    args = parser.parse_args()

    image = Image.open(args.input).convert("RGBA")
    expected = (args.columns * args.expected_cell, args.rows * args.expected_cell)
    if image.size != expected:
        raise SystemExit(f"Expected sheet size {expected}, got {image.size}")

    removed = cleanup_exterior_matte(image, args.cleanup_passes, args.neighbor_radius)
    remaining_edge = list(iter_bright_edge_matte(image, args.columns, args.rows))

    args.output.parent.mkdir(parents=True, exist_ok=True)
    image.save(args.output)

    if args.contact_sheet:
        write_contact_sheet(image, args.contact_sheet, args.columns, args.rows, args.contact_scale)

    report = {
        "input": str(args.input),
        "output": str(args.output),
        "size": list(image.size),
        "columns": args.columns,
        "rows": args.rows,
        "frame_size": [args.expected_cell, args.expected_cell],
        "frames": args.columns * args.rows,
        "removed_matte_pixels": removed,
        "remaining_bright_edge_matte_pixels": len(remaining_edge),
        "remaining_bright_edge_examples": remaining_edge[:20],
        "contact_sheet": str(args.contact_sheet) if args.contact_sheet else None,
    }
    if args.report_json:
        args.report_json.parent.mkdir(parents=True, exist_ok=True)
        args.report_json.write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps(report, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
