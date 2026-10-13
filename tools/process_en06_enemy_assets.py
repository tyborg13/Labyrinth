#!/usr/bin/env python3
"""Register en-06 approved paint with existing key/resample helpers; no new art."""
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
ENEMIES = ('storm_capacitor', 'hollow_mimic')
ICONS = ('charge', 'mirror')
CANVAS = 255
PORTRAIT_SIZE = 128
PORTRAIT_TOP = 8
HEIGHT_RATIOS = {'storm_capacitor': 1.2, 'hollow_mimic': 1.0}
# Measured centres of the approved coil/faceted head, not new design.
FRONT_SOURCE_X = {'storm_capacitor': 627, 'hollow_mimic': 630}


def resize(image, size):
    rgba = np.asarray(image.convert('RGBA'), dtype=float)
    return resize_keyed(rgba[..., :3], rgba[..., 3] / 255., size)


def portraits():
    for name in ENEMIES:
        source = Image.open(ROOT / f'assets/art/enemies/{name}.png').convert('RGBA')
        bounds = source.getchannel('A').getbbox()
        raw_bounds = key_green(Image.open(RAW / 'enemies' / f'{name}.png')).getchannel('A').getbbox()
        front_x = bounds[0] + round((FRONT_SOURCE_X[name] - raw_bounds[0]) * (bounds[2] - bounds[0]) / (raw_bounds[2] - raw_bounds[0]))
        left, top = front_x - PORTRAIT_SIZE // 2, bounds[1] - PORTRAIT_TOP
        if name == 'storm_capacitor':
            # The requested portrait feature is the central glass coil, below
            # the cap. Crop that feature at 1:1 and retain the 8px top padding.
            coil_source_y = 600
            center_y = bounds[1] + round((coil_source_y - raw_bounds[1]) * (bounds[3] - bounds[1]) / (raw_bounds[3] - raw_bounds[1]))
            height = PORTRAIT_SIZE - PORTRAIT_TOP
            top = center_y - height // 2
            portrait = Image.new('RGBA', (PORTRAIT_SIZE, PORTRAIT_SIZE))
            portrait.paste(source.crop((left, top, left + PORTRAIT_SIZE, top + height)), (0, PORTRAIT_TOP))
        else:
            portrait = source.crop((left, top, left + PORTRAIT_SIZE, top + PORTRAIT_SIZE))
        portrait.save(ROOT / f'assets/art/portraits/{name}.png')


def main():
    expected = dict((line.split()[1], line.split()[0]) for line in (ROOT / 'spec/peer_benchmark/staged/enemies/raw_sha256.txt').read_text().splitlines())
    gaoler = Image.open(ROOT / 'assets/art/enemies/chainbound_gaoler.png').convert('RGBA').getchannel('A').getbbox()
    hero = Image.open(ROOT / 'assets/units/protagonist_cutout/front/front_assembled_rest_v9.png').convert('RGBA').getchannel('A').getbbox()
    icon = Image.open(ROOT / 'assets/art/icons/blink.png').convert('RGBA').getchannel('A').getbbox()
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
                scale = min((icon[2] - icon[0]) / crop.width, (icon[3] - icon[1]) / crop.height)
                art = resize(crop, (round(crop.width * scale), round(crop.height * scale)))
                canvas = Image.new('RGBA', (64, 64))
                canvas.paste(art, ((64 - art.width) // 2, (64 - art.height) // 2))
            else:
                target_height = (hero[3] - hero[1]) * HEIGHT_RATIOS[name]
                scale = min(CANVAS / crop.width, gaoler[3] / crop.height, target_height / crop.height)
                art = resize(crop, (round(crop.width * scale), round(crop.height * scale)))
                canvas = Image.new('RGBA', (CANVAS, CANVAS))
                canvas.paste(art, ((CANVAS - art.width) // 2, gaoler[3] - art.height))
                print(f'{name}: source body height={art.height}; target={target_height:.1f}; baseline={gaoler[3]}; canvas=255')
            path = f'assets/art/{family}/{name}.png'
            canvas.save(ROOT / path)
            if family != 'enemies': continue
            m = metrics(canvas)
            strength = 1 + .5 * min(1., max(0., (m['orphan_share'] - .05) / .10))
            draw_scale = target_height / art.height
            entry = {'id': name, 'kind': 'static_enemy', 'paths': [path], 'r': draw_scale, 'r_derivation': {'path': 'data/enemies.json', 'key': f'{name}.art_scale', 'expression': 'art_scale (default 1.0)'}, 'measurement_path': path, 'frames': None, 'orphan_share': m['orphan_share'], 't': strength, 'grid': round(strength / draw_scale, 2), 'mode': 'regrid' if round(strength / draw_scale, 2) >= 1.2 else 'clean'}
            if name == 'storm_capacitor':
                entry['r_derivation'] = {'path': 'scripts/enemy_mechanics/capacitor_view.gd', 'key': 'BODY_SCALE', 'expression': '216 * 1.2 / 243; approved hero-relative body height on fixed 255 canvas'}
                entry['override'] = 'EN06 brief requires an intact 255x255 static canvas. Native treatment preserves that canvas; derived runtime scale restores the 120% body height without clipping the approved chain/base silhouette.'
            registry['entries'] = [row for row in registry['entries'] if row['id'] != name] + [entry]
    registry_path.write_text(json.dumps(registry, indent=2) + '\n')
    hashes = ROOT / 'spec/assets/enemies/raw_sha256.txt'
    existing = hashes.read_text().splitlines()
    hashes.write_text('\n'.join(existing + [r for r in records if r not in existing]) + '\n')
    portraits()
    print('EN06 APPROVED ASSET REGISTRATION: PASS')


if __name__ == '__main__':
    if '--portraits-only' in sys.argv:
        portraits()
        print('EN06 PROCESSED-ART PORTRAITS: PASS')
    else:
        main()
