"""Apply rr-27's coordinate-only, clip-scoped joint coverage to mq7b.

Do not replay historical builders or repaint/density-process any texture.
The director's sources, motion, rest composites and production paths stay put.
"""
from pathlib import Path
import sys

PROJECT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(PROJECT / 'tools'))
from cutout_pipeline.cases import read_json, write_json
from humanoid_cutout.gait_continuations import nearest_donors, errors

CASE = PROJECT / 'experiments/cutouts/arc_thrall/rr11'
RECIPE = Path(__file__).with_name('rr27')
ASSETS = PROJECT / 'assets/units/arc_thrall_cutout'


def apply_front(layout):
    definition = read_json(RECIPE / 'joint_continuations.json')
    part = next(p for p in layout['parts'] if p['name'] == definition['piece'])
    recipe = nearest_donors(CASE, layout, part, definition['local_targets'])
    recipe['clips'] = definition['clips']
    layout.setdefault('gait_continuations', {})[part['name']] = recipe
    return layout


def main():
    layout = apply_front(read_json(CASE / 'layouts/front.json'))
    invalid = errors(CASE, layout)
    if invalid:
        raise ValueError(invalid)
    write_json(CASE / 'layouts/front.json', layout)
    # Production uses different path prefixes; copy only coordinate recipes.
    for path in (ASSETS / 'front.json', ASSETS / 'humanoid_v2/front.json'):
        production = read_json(path)
        production['gait_continuations'] = layout['gait_continuations']
        write_json(path, production)
    recipes = read_json(CASE / 'gait_continuations.json')
    recipes['front'] = layout['gait_continuations']
    write_json(CASE / 'gait_continuations.json', recipes)
    count = len(layout['gait_continuations']['upper_near']['texels'])
    print(f'RR27 FRONT JOINT CONTINUATIONS: PASS ({count} own-piece donor copies; jab/death only)')


if __name__ == '__main__':
    main()
