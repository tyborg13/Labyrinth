#!/usr/bin/env python3
"""Register the approved EN01 paint; reuse the repository key/density tools."""
from __future__ import annotations

import hashlib
import json
import sys
from pathlib import Path

from PIL import Image

from process_biome_art import key_green
from pixel_density import metrics

ROOT = Path(__file__).resolve().parents[1]
RAW_ROOT = Path('/Users/borgerding/workspace/Labyrinth/output/peer-benchmark-2026-10-12/raw_art')
CANVAS_SIZE = 255
PORTRAIT_SIZE = 128
PORTRAIT_HEAD_WIDTH = 0.70
PORTRAIT_MARGIN = 8
ICON_SIZE = 64
ICON_PADDING = 4  # Existing blink.png registration.
BODY_HEIGHT_FRACTION = {'burrow_grub': 0.75, 'ember_tick': 0.45}
# Measured feature bounds in the approved paintings: mouth ring / front shell.
RAW_HEAD_BOUNDS = {'burrow_grub': (105, 315, 445, 680), 'ember_tick': (310, 525, 620, 807)}


def registration(enemy_id: str) -> tuple[Image.Image, tuple[int, int, int, int], float, tuple[int, int]]:
    keyed = key_green(Image.open(RAW_ROOT / f'enemies/{enemy_id}.png'))
    bbox = keyed.getbbox()
    hero = Image.open(ROOT / 'assets/units/protagonist_cutout/front/front_assembled_rest_v9.png').getbbox()
    height = round((hero[3] - hero[1]) * BODY_HEIGHT_FRACTION[enemy_id])
    scale = height / (bbox[3] - bbox[1])
    size = (round((bbox[2] - bbox[0]) * scale), height)
    baseline = Image.open(ROOT / 'assets/art/enemies/chainbound_gaoler.png').getbbox()[3]
    offset = ((CANVAS_SIZE - size[0]) // 2, baseline - size[1])
    canvas = Image.new('RGBA', (CANVAS_SIZE, CANVAS_SIZE))
    canvas.paste(keyed.crop(bbox).resize(size, Image.Resampling.BOX), offset)
    return canvas, bbox, scale, offset


def write_portrait(enemy_id: str, canvas: Image.Image) -> None:
    _, bbox, scale, offset = registration(enemy_id)
    head = RAW_HEAD_BOUNDS[enemy_id]
    center = (offset[0] + ((head[0] + head[2]) / 2 - bbox[0]) * scale,
              offset[1] + ((head[1] + head[3]) / 2 - bbox[1]) * scale)
    inner = PORTRAIT_SIZE - 2 * PORTRAIT_MARGIN
    side = (head[2] - head[0]) * scale * inner / (PORTRAIT_SIZE * PORTRAIT_HEAD_WIDTH)
    crop = tuple(round(v) for v in (center[0] - side / 2, center[1] - side / 2,
                                   center[0] + side / 2, center[1] + side / 2))
    portrait = Image.new("RGBA", (PORTRAIT_SIZE, PORTRAIT_SIZE))
    portrait.paste(canvas.crop(crop).resize((inner, inner), Image.Resampling.BOX), (PORTRAIT_MARGIN, PORTRAIT_MARGIN))
    portrait.save(ROOT / f'assets/art/portraits/{enemy_id}.png')


def icons() -> None:
    for concept in ('burrow', 'erupt', 'burst'):
        raw = RAW_ROOT / f'icons/{concept}.png'
        keyed = key_green(Image.open(raw))
        body = keyed.crop(keyed.getbbox())
        scale = (ICON_SIZE - ICON_PADDING * 2) / max(body.size)
        fitted = body.resize(tuple(round(v * scale) for v in body.size), Image.Resampling.BOX)
        canvas = Image.new('RGBA', (ICON_SIZE, ICON_SIZE))
        canvas.paste(fitted, ((ICON_SIZE - fitted.width) // 2, (ICON_SIZE - fitted.height) // 2))
        canvas.save(ROOT / f'assets/art/icons/{concept}.png')
        print(f'EN01 ICON REGISTERED: {concept} {canvas.size} bounds={canvas.getbbox()}')
    hashes = [f'{hashlib.sha256((RAW_ROOT / f"icons/{key}.png").read_bytes()).hexdigest()}  {RAW_ROOT / f"icons/{key}.png"}'
              for key in ('burrow', 'erupt', 'burst')]
    (ROOT / 'spec/assets/enemies/raw_icons_sha256.txt').write_text('\n'.join(hashes) + '\n')


def main() -> None:
    registry_path = ROOT / 'spec/assets/board_pixel_density/registry.json'
    registry = json.loads(registry_path.read_text())
    hashes = []
    for enemy_id, fraction in BODY_HEIGHT_FRACTION.items():
        raw = RAW_ROOT / f'enemies/{enemy_id}.png'
        hashes.append(f'{hashlib.sha256(raw.read_bytes()).hexdigest()}  {raw}')
        canvas, _, _, _ = registration(enemy_id)
        path = f'assets/art/enemies/{enemy_id}.png'
        canvas.save(ROOT / path)
        orphan = metrics(canvas)['orphan_share']
        strength = 1 + 0.5 * max(0, min(1, (orphan - 0.05) / 0.10))
        grid = round(strength, 2)
        entry = {'id': enemy_id, 'kind': 'static', 'paths': [path], 'measurement_path': path,
                 'frames': None, 'r': 1.0, 'r_derivation': {'path': 'data/enemies.json', 'key': f'{enemy_id}.art_scale',
                 'expression': '_unit_size width 1.03 / 255 * default art_scale 1.0 / hero reference (1.03 / 255)'},
                 'orphan_share': orphan, 't': strength, 'grid': grid, 'mode': 'regrid' if grid >= 1.2 else 'clean'}
        registry['entries'] = [old for old in registry['entries'] if old['id'] != enemy_id] + [entry]
        print(f'EN01 ART REGISTERED: {enemy_id} hero_height_fraction={fraction} bounds={canvas.getbbox()}')
    registry_path.write_text(json.dumps(registry, indent=2) + '\n')
    (ROOT / 'spec/assets/enemies/raw_sha256.txt').write_text('\n'.join(hashes) + '\n')
    icons()


if __name__ == '__main__':
    if '--portraits-only' in sys.argv:
        for enemy_id in BODY_HEIGHT_FRACTION:
            write_portrait(enemy_id, Image.open(ROOT / f'assets/art/enemies/{enemy_id}.png').convert('RGBA'))
        print('EN01 PORTRAITS WRITTEN: processed paint; approved head framing')
    else:
        main()
