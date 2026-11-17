#!/usr/bin/env python3
"""Measure existing/native peak captures. Does not render or alter any image.

A 4px pixel-art grid joins dither neighbours before 8-connected components.
Components are computed on the UNION of target diamonds (not separately, which
would hide cross-tile connections). Paired clear frames exclude unchanged UI.
Area is reported in authored tile-diamond units as well as raw tile touches.
Thin sky filaments can cross multiple diamonds even in the director's target;
the opaque-area budget is one diamond, without suppressing that diagnostic.
Actor rectangles are visibility proxies, not segmentation of sprite silhouettes.
"""
from __future__ import annotations
import argparse
import json
from collections import deque
from pathlib import Path
from PIL import Image, ImageDraw

PROOF_BRIGHT_LUMA = 180
PROOF_LUMA_GAIN = 24
PROOF_GRID_PIXELS = 4
PROOF_MIN_TILE_PIXELS = 4
PROOF_SIZE = (1920, 1080)


def luma(rgb):
    return (2126 * rgb[0] + 7152 * rgb[1] + 722 * rgb[2]) // 10000


def measure(image_path, peak, clear_path=None):
    im = Image.open(image_path).convert('RGB')
    assert im.size == PROOF_SIZE, (image_path, im.size)
    clear = Image.open(clear_path).convert('RGB') if clear_path else None
    labels = Image.new('I', im.size)
    draw = ImageDraw.Draw(labels)
    for i, tile in enumerate(peak['tiles'], 1):
        draw.polygon([tuple(p) for p in tile['polygon']], fill=i)
    pixels, owners = im.load(), labels.load()
    old = clear.load() if clear else None
    cells, per_tile = {}, [0] * len(peak['tiles'])
    tile_area = [sum(n for n, label in labels.getcolors(im.width * im.height) if label == i)
                 for i in range(1, len(peak['tiles']) + 1)]
    for y in range(im.height):
        for x in range(im.width):
            tile = owners[x, y]
            if not tile or luma(pixels[x, y]) < PROOF_BRIGHT_LUMA:
                continue
            if old and luma(pixels[x, y]) - luma(old[x, y]) < PROOF_LUMA_GAIN:
                continue
            per_tile[tile - 1] += 1
            cell = (x // PROOF_GRID_PIXELS, y // PROOF_GRID_PIXELS)
            counts = cells.setdefault(cell, {})
            counts[tile] = counts.get(tile, 0) + 1
    components = []
    pending = set(cells)
    while pending:
        start = min(pending)
        pending.remove(start)
        todo = deque([start])
        tiles, count = {}, 0
        while todo:
            x, y = todo.popleft()
            for tile, n in cells[x, y].items():
                tiles[tile] = tiles.get(tile, 0) + n
                count += n
            for dx in (-1, 0, 1):
                for dy in (-1, 0, 1):
                    other = (x + dx, y + dy)
                    if other in pending:
                        pending.remove(other)
                        todo.append(other)
        touched = [tile for tile, n in tiles.items() if n >= PROOF_MIN_TILE_PIXELS]
        components.append({'pixels': count, 'tiles_touched': len(touched),
                           'tiles': [peak['tiles'][i - 1]['tile'] for i in touched]})
    actors = []
    for actor in peak.get('actors', []):
        x, y, w, h = actor['rect']
        rect = (max(0, int(x)), max(0, int(y)), min(im.width, int(x + w)), min(im.height, int(y + h)))
        points = [(px, py) for py in range(rect[1], rect[3]) for px in range(rect[0], rect[2])]
        # All actor ROI pixels, including the vertical sky bolt above the floor.
        obscured = sum(luma(pixels[p]) >= PROOF_BRIGHT_LUMA and
                       (not old or luma(pixels[p]) - luma(old[p]) >= PROOF_LUMA_GAIN)
                       for p in points)
        actors.append({'key': actor['key'], 'roi_pixels': len(points), 'bright_pixels': obscured,
                       'nonbright_fraction': round(1 - obscured / max(1, len(points)), 6)})
    max_tiles = max((c['tiles_touched'] for c in components), default=0)
    largest = max((c['pixels'] for c in components), default=0)
    budget = min(tile_area, default=0)
    return {'image': str(image_path), 'paired_clear_frame': bool(clear),
            'struck_tiles': len(per_tile), 'tile_bright_pixels': per_tile,
            'components': len(components), 'largest_component_pixels': largest,
            'one_tile_area_pixels': budget, 'largest_component_tile_areas': round(largest / max(1, budget), 6),
            'max_component_tiles': max_tiles,
            'multi_tile_components': [c for c in components if c['tiles_touched'] > 1],
            'actor_visibility_proxy': actors,
            'raw_tile_touch_pass': max_tiles <= 1, 'bright_area_pass': largest <= budget,
            'every_tile_has_bright_art': all(n >= PROOF_MIN_TILE_PIXELS for n in per_tile)}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', type=Path, required=True)
    parser.add_argument('--require-pass', action='store_true')
    args = parser.parse_args()
    rows = []
    for report_path in sorted(args.root.glob('*.json')):
        if report_path.name == 'brightness.json':
            continue
        report = json.loads(report_path.read_text())
        for peak in report.get('deterministic_peaks', []):
            if not Path(peak['image']).is_file():
                raise SystemExit(f'Missing native peak: {peak["image"]}; headless is not pixel proof')
            rows.append(measure(peak['image'], peak, peak['clear_image']))
    if not rows:
        raise SystemExit('No native peak captures found')
    result = {'thresholds': {'luma': PROOF_BRIGHT_LUMA, 'gain': PROOF_LUMA_GAIN,
                           'grid_pixels': PROOF_GRID_PIXELS, 'min_tile_pixels': PROOF_MIN_TILE_PIXELS},
              'captures': rows}
    (args.root / 'brightness.json').write_text(json.dumps(result, indent=2) + '\n')
    ok = all(r['bright_area_pass'] and r['every_tile_has_bright_art'] for r in rows)
    for row in rows:
        print(f'ATK14 BRIGHT AREA {Path(row["image"]).name}: tiles={row["struck_tiles"]} '
              f'per_tile={row["tile_bright_pixels"]} largest={row["largest_component_pixels"]}px '
              f'area_tiles={row["largest_component_tile_areas"]} raw_tile_touches={row["max_component_tiles"]}')
    print(f'ATK14 NATIVE BRIGHT AREA: {"PASS" if ok else "FAIL"} ({len(rows)} peaks)')
    return 1 if args.require_pass and not ok else 0


if __name__ == '__main__':
    raise SystemExit(main())
