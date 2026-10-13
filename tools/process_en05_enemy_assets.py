#!/usr/bin/env python3
"""Register only the unchanged director-approved en-05 paintings.

Uses the repository green-key and premultiplied resampling helpers. No paint is
generated. Body registration follows the brief's exact hero-height ratios,
the existing canvas, and Gaoler's measured baseline. Portrait framing inherits
the existing turn-order pipeline's head-and-shoulders crop.
"""
from pathlib import Path
import hashlib
import json
import sys

import numpy as np
from PIL import Image

from process_biome_art import key_green
from process_visual_pass_4_assets import resize_keyed
from pixel_density import metrics

ROOT = Path(__file__).resolve().parents[1]
RAW = Path('/Users/borgerding/workspace/Labyrinth/output/peer-benchmark-2026-10-12/raw_art')
ENEMIES = ('glacial_mirror', 'gust_shrike')
ICONS = ('reflect', 'dive', 'flying')
CANVAS = 255
PORTRAIT_CANVAS = 128
PORTRAIT_TOP = 8
HERO_HEIGHT_RATIOS = {'glacial_mirror': 1.15, 'gust_shrike': .85}
# Measured face centres in the approved raw paintings, not new framing choices.
HEAD_FRONT_SOURCE_PIXELS = {'glacial_mirror': (581, 124), 'gust_shrike': (452, 150)}


def resize(image, size):
    rgba = np.asarray(image.convert('RGBA'), dtype=float)
    return resize_keyed(rgba[..., :3], rgba[..., 3] / 255., size)


def portraits():
    for name in ENEMIES:
        source = Image.open(ROOT / f'assets/art/enemies/{name}.png').convert('RGBA')
        board_bounds = source.getchannel('A').getbbox()
        raw = key_green(Image.open(RAW / 'enemies' / f'{name}.png'))
        raw_bounds = raw.getchannel('A').getbbox()
        head_x = board_bounds[0] + round((HEAD_FRONT_SOURCE_PIXELS[name][0] - raw_bounds[0]) *
                                       (board_bounds[2] - board_bounds[0]) / (raw_bounds[2] - raw_bounds[0]))
        left = head_x - PORTRAIT_CANVAS // 2
        top = board_bounds[1] - PORTRAIT_TOP
        # Exact 1:1 crop of processed production art, with alpha padding outside.
        portrait = source.crop((left, top, left + PORTRAIT_CANVAS, top + PORTRAIT_CANVAS))
        portrait.save(ROOT / f'assets/art/portraits/{name}.png')


def main():
    expected = dict((line.split()[1], line.split()[0]) for line in
                    (ROOT / 'spec/peer_benchmark/staged/enemies/raw_sha256.txt').read_text().splitlines())
    gaoler = Image.open(ROOT / 'assets/art/enemies/chainbound_gaoler.png').convert('RGBA').getchannel('A').getbbox()
    hero = Image.open(ROOT / 'assets/units/protagonist_cutout/front/front_assembled_rest_v9.png').convert('RGBA').getchannel('A').getbbox()
    icon_ref = Image.open(ROOT / 'assets/art/icons/blink.png').convert('RGBA').getchannel('A').getbbox()
    icon_fit = (icon_ref[2] - icon_ref[0], icon_ref[3] - icon_ref[1])
    registry_path = ROOT / 'spec/assets/board_pixel_density/registry.json'
    registry = json.loads(registry_path.read_text())
    records = []
    for family, names in [('enemies', ENEMIES), ('icons', ICONS)]:
        for name in names:
            raw = RAW / family / f'{name}.png'
            digest = hashlib.sha256(raw.read_bytes()).hexdigest()
            assert digest == expected[f'{family}/{name}.png'], raw
            records.append(f'{digest}  {family}/{name}.png')
            keyed = key_green(Image.open(raw))
            crop = keyed.crop(keyed.getchannel('A').getbbox())
            if family == 'icons':
                scale = min(icon_fit[0] / crop.width, icon_fit[1] / crop.height)
                art = resize(crop, (round(crop.width * scale), round(crop.height * scale)))
                canvas = Image.new('RGBA', (64, 64))
                canvas.paste(art, ((64 - art.width) // 2, (64 - art.height) // 2))
            else:
                scale = min(CANVAS / crop.width, (hero[3] - hero[1]) * HERO_HEIGHT_RATIOS[name] / crop.height)
                art = resize(crop, (round(crop.width * scale), round(crop.height * scale)))
                canvas = Image.new('RGBA', (CANVAS, CANVAS))
                canvas.paste(art, ((CANVAS - art.width) // 2, gaoler[3] - art.height))
            path = f'assets/art/{family}/{name}.png'
            canvas.save(ROOT / path)
            if family != 'enemies': continue
            m = metrics(canvas)
            strength = 1 + .5 * min(1., max(0., (m['orphan_share'] - .05) / .10))
            grid = round(strength, 2) # Enemy art_scale defaults to 1, native 255 canvas.
            entry = {'id': name, 'kind': 'static_enemy', 'paths': [path], 'r': 1.,
                     'r_derivation': {'path': 'data/enemies.json', 'key': f'{name}.art_scale', 'expression': 'art_scale (default 1.0)'},
                     'measurement_path': path, 'frames': None, 'orphan_share': m['orphan_share'], 't': strength,
                     'grid': grid, 'mode': 'regrid' if grid >= 1.2 else 'clean'}
            registry['entries'] = [row for row in registry['entries'] if row['id'] != name] + [entry]
    registry_path.write_text(json.dumps(registry, indent=2) + '\n')
    hashes = ROOT / 'spec/assets/enemies/raw_sha256.txt'
    hashes.parent.mkdir(parents=True, exist_ok=True)
    previous = hashes.read_text().splitlines() if hashes.exists() else []
    hashes.write_text('\n'.join(previous + [r for r in records if r not in previous]) + '\n')
    portraits()
    print('EN05 APPROVED ASSET REGISTRATION: PASS')


if __name__ == '__main__':
    if '--portraits-only' in sys.argv:
        portraits()
        print('EN05 PROCESSED-ART PORTRAITS: PASS')
    else:
        main()
