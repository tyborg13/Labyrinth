"""Replay rr-28's clip-scoped own-piece texel continuations, without repainting."""
from pathlib import Path
import sys

PROJECT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(PROJECT / 'tools'))
from cutout_pipeline.cases import read_json, write_json, digest
from humanoid_cutout.gait_continuations import nearest_donors, errors

RIGS = {'seer': ('hoarfrost_seer', 'rr10'), 'mimic': ('hollow_mimic', 'rr20')}
BASE_REVISION = '370ab4b13b298b4a32bc1670f4c36916541850da'


def production_layouts(assets, view):
    return [p for p in (assets / f'{view}.json', assets / f'humanoid_v2/{view}.json') if p.is_file()]


def paths(name):
    unit, version = RIGS[name]
    folder = PROJECT / 'experiments/cutouts' / unit
    return folder / version, PROJECT / 'assets/units' / (unit + '_cutout'), folder / 'rr28'


def apply(case, layout, definitions):
    for name, definition in definitions.get(layout['facing'], {}).items():
        part = next(p for p in layout['parts'] if p['name'] == name)
        recipe = nearest_donors(case, layout, part, definition['local_targets'])
        recipe['clips'] = definition['clips']
        layout.setdefault('gait_continuations', {})[name] = recipe
    invalid = errors(case, layout)
    if invalid:
        raise ValueError(invalid)
    return layout


def build(name):
    case, assets, recipe = paths(name)
    definitions = read_json(recipe / 'joint_continuations.json')
    counts = {}
    for view in ('front', 'rear'):
        if view not in definitions:
            continue
        layout = apply(case, read_json(case / f'layouts/{view}.json'), definitions)
        write_json(case / f'layouts/{view}.json', layout)
        # Preserve the production-specific prefixes, fields and geometry.
        for path in production_layouts(assets, view):
            production = read_json(path)
            production['gait_continuations'] = layout['gait_continuations']
            write_json(path, production)
        counts[view] = sum(len(r['texels']) for r in layout['gait_continuations'].values())
    # Only this owned closure changes. Shared density/identity/shadow records
    # and every PNG stay byte-identical; playback copies the treated donors.
    path = assets / 'integration.json'
    integration = read_json(path)
    integration['files'] = {name: digest(assets / name) for name in integration['files']}
    write_json(path, integration)
    print(f'RR28 {name.upper()} CONTINUATIONS: PASS ({counts}; own-piece coordinates only)')


if __name__ == '__main__':
    for name in RIGS:
        build(name)
