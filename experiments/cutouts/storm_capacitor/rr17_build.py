"""Exact rr-17 painting partition and integer glow bake. Never paints new art."""
from pathlib import Path
import hashlib
import json
import math
import shutil
import sys
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / 'tools'))
CASE = ROOT / 'experiments/cutouts/storm_capacitor/mq5'
PRODUCTION = ROOT / 'assets/units/storm_capacitor_cutout'
DIRECTOR = ROOT / 'spec/peer_benchmark/staged/rr-17'
PAINTING = ROOT / 'assets/art/enemies/storm_capacitor.png'
VIEWS = ('front', 'rear')
CAP_PIVOT = [131, 75]  # Director brief, source pixels.
# Coordinate gauges only; neither stationary bone rotates or scales.
BIND_ORIGIN = [0, 0]
LEVELS = {-2: ([42, 18, 24], .90), -1: ([42, 18, 24], .55),
          0: ([0, 0, 0], 0.), 1: ([242, 230, 255], .35), 2: ([242, 230, 255], .70)}


def read(path):
    return json.loads(Path(path).read_text())


def write(path, value):
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2) + '\n')


def digest(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def arc_mask(paint):
    rgb = np.asarray(paint).astype(np.int16)
    return (rgb[..., 3] > 0) & (rgb[..., 2] - rgb[..., 0] > 20) & (rgb[..., 2] - rgb[..., 1] > 40)


def glow(paint, level):
    result = np.asarray(paint).copy()
    selected = arc_mask(result)
    color, weight = LEVELS[level]
    # 8-bit per-channel nearest integer (positive half ties round upwards).
    result[..., :3][selected] = np.floor(result[..., :3][selected] * (1 - weight) + np.array(color) * weight + .5).astype(np.uint8)
    return Image.fromarray(result)


def compile_motion():
    author = read(DIRECTOR / 'motion_tracks.json')['storm_capacitor']
    result = {'version': 1, 'creature': 'storm_capacitor', 'source_units': 'source_pixels',
              'director_sha256': digest(DIRECTOR / 'motion_tracks.json'), 'clips': {},
              'projection': {}, 'view_tracks': {}, 'TODO_DESIGN': {}}
    for view in VIEWS:
        # Existing 2:1 isometric forward axes. Rear uses the same paint.
        sign = -1 if view == 'front' else 1
        result['projection'][view] = {'forward': [sign * 2 / math.sqrt(5), -sign / math.sqrt(5)]}
        result['view_tracks'][view] = {}
        for clip, definition in author['clips'].items():
            result['clips'][clip] = {k: v for k, v in definition.items() if k != 'keys'}
            tracks = []
            for channel, keys in definition['keys'].items():
                bone, field = channel.split('.')
                if bone == 'body': bone = 'root'
                tracks.append({'source': channel, 'bone': bone, 'channel': field, 'forward_mode': 'pixels',
                    'keys': [{'at': row[0], 'value': row[1] * (sign if field == 'lean_deg' else 1),
                              'interpolation': row[2] if len(row) > 2 else 'smoothstep'} for row in keys]})
            result['view_tracks'][view][clip] = tracks
    return result


def build():
    CASE.mkdir(parents=True, exist_ok=True)
    for name in ('motion_tracks.json', 'cap_mask.png', 'vent_fill.png'):
        target = 'director_motion.json' if name == 'motion_tracks.json' else 'source/' + name
        (CASE / target).parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(DIRECTOR / name, CASE / target)
    art = Image.open(PAINTING).convert('RGBA')
    mask = np.asarray(Image.open(DIRECTOR / 'cap_mask.png'))[..., 3] > 0
    raw = np.asarray(art)
    cap, column = raw.copy(), raw.copy()
    cap[~mask] = 0
    column[mask] = 0
    vent = Image.open(DIRECTOR / 'vent_fill.png').convert('RGBA')
    merged = vent.copy()
    merged.alpha_composite(Image.fromarray(column))
    pieces = {'cap': Image.fromarray(cap), 'column': merged}
    parts = []
    for name, image in pieces.items():
        box = image.getbbox()
        relative = 'paint/' + name + '.png'
        (CASE / relative).parent.mkdir(parents=True, exist_ok=True)
        image.crop(box).save(CASE / relative)
        parts.append({'name': name, 'bone': name, 'file': relative,
                      'offset': list(box[:2]), 'z_index': 1 if name == 'cap' else 0})
    column_part = next(p for p in parts if p['name'] == 'column')
    glow_paths = {}
    for level in LEVELS:
        path = 'paint/column_glow_%d.png' % level
        glow(Image.open(CASE / column_part['file']), level).save(CASE / path)
        glow_paths[str(level)] = path
    data = compile_motion()
    write(CASE / 'compiled_motion.json', data)
    for view in VIEWS:
        target = CASE / f'source/{view}/processed.png'
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(PAINTING, target)
        layout = {'version': 1, 'facing': view, 'canvas_size': [255, 255],
                  'joints': {'root': {'parent': None, 'position': BIND_ORIGIN},
                             'column': {'parent': 'root', 'position': BIND_ORIGIN},
                             'cap': {'parent': 'column', 'position': CAP_PIVOT}},
                  'parts': sorted(parts, key=lambda p: p['z_index']), 'glow_textures': glow_paths,
                  'rest_source': f'source/{view}/processed.png',
                  'motion_data': 'res://' + str(CASE.relative_to(ROOT)) + '/compiled_motion.json'}
        write(CASE / f'layouts/{view}.json', layout)
        (CASE / view).mkdir(exist_ok=True)
        shutil.copyfile(PAINTING, CASE / view / 'rest.png')
    config = {'version': 1, 'character_id': 'storm_capacitor', 'source_size': [255, 255],
              'runtime_paths': ['assets/units/storm_capacitor_cutout/renderer.gd', 'assets/units/storm_capacitor_cutout/actions.gd',
                  'assets/units/storm_capacitor_cutout/death.gd', 'assets/units/storm_capacitor_cutout/rig.gd', 'scripts/static_enemy_facing.gd',
                  *['tests/rr17/' + p for p in ('native_capture.gd', 'production_capture.gd', 'capture_scene.gd', 'capture_contract.gd', 'samples.gd')],
                  *[str((PRODUCTION / p).relative_to(ROOT)) for p in glow_paths.values()],
                  *[str((CASE / p).relative_to(ROOT)) for p in glow_paths.values()],
                  str((CASE / 'source/cap_mask.png').relative_to(ROOT)), str((CASE / 'source/vent_fill.png').relative_to(ROOT))],
              'clips': [{'name': name, 'seconds': item['seconds'], 'loop': item.get('loop', False),
                         'frames': round(item['seconds'] * 60)} for name, item in data['clips'].items()],
              'sources': ['director_motion.json', 'source/cap_mask.png', 'source/vent_fill.png'],
              'TODO_DESIGN': {'TODO_DESIGN_hit_changing_frames': 'Protected hit has four transitions/four unique states; the brief requires six changing frames per action.'}}
    write(CASE / 'cutout.json', config)
    # Compatibility closure for the existing proof binding collector; no maquette.
    write(CASE / 'source/spec.json', {'basis': 'approved painting; no maquette; one rotationally symmetric view'})
    (CASE / 'motion.gd').write_text('extends "res://scripts/maquette_cutout_runtime/motion.gd"\n')
    for folder in ('paint', 'front', 'rear'):
        shutil.copytree(CASE / folder, PRODUCTION / folder, dirs_exist_ok=True)
    shutil.copyfile(CASE / 'compiled_motion.json', PRODUCTION / 'compiled_motion.json')
    for view in VIEWS:
        layout = read(CASE / f'layouts/{view}.json')
        layout['rest_source'] = f'{view}/rest.png'
        layout['motion_data'] = 'res://assets/units/storm_capacitor_cutout/compiled_motion.json'
        write(PRODUCTION / f'{view}.json', layout)
    inputs = {str(p.relative_to(ROOT)): digest(p) for p in (PAINTING, DIRECTOR / 'motion_tracks.json', DIRECTOR / 'cap_mask.png', DIRECTOR / 'vent_fill.png')}
    write(CASE / 'protected_inputs.json', inputs)
    write(PRODUCTION / 'integration.json', {'character_id': 'storm_capacitor', 'case': str(CASE.relative_to(ROOT)),
        'TODO_DESIGN': config['TODO_DESIGN'],
        'protected_inputs': inputs, 'native_proof': 'pending director windowed proof',
        'density': 'exact partition of existing treated painting; prescribed glow; protected vent fill',
        'files': {str(p.relative_to(PRODUCTION)): digest(p) for p in sorted(PRODUCTION.rglob('*')) if p.is_file() and p.name != 'integration.json'}})
    print('RR17 BUILD: PASS (2 rigid pieces; 5 baked glow levels; protected inputs copied byte for byte)')


if __name__ == '__main__':
    build()
