"""Adopt/process rr-22 only; native rest certification stays with the director."""
import json
import re
import subprocess
import sys
from PIL import Image
from rr22_case import PROJECT, CASE, ASSETS
from cutout_pipeline.cases import read_json, write_json
from pixel_density import metrics, strength

DENSITY = PROJECT / 'spec/assets/board_pixel_density'
ID = 'slag_mortar_cutout'


def declaration():
    data = read_json(CASE / 'compiled_motion.json')
    board = (PROJECT / 'scripts/combat_board_view.gd').read_text()
    return {'rig_directory': 'humanoid_v2', 'action_adapter': 'res://assets/units/slag_mortar_cutout/actions.gd',
        'idle_phase_seed': 'slot', 'death_timing': {'clip_seconds': data['clips']['death']['seconds'],
            'dissolve_frames': int(re.search(r'const ENEMY_SHADOW_DISSOLVE_FRAME_COUNT: int = (\d+)', board)[1]),
            'dissolve_frame_seconds': float(re.search(r'const ENEMY_SHADOW_DISSOLVE_FRAME_SECONDS: float = ([\d.]+)', board)[1])}}


def preserve_identity_entries(before, updated):
    # Preserve unrelated raw records, including pre-existing duplicate JSON
    # keys in the integrated registry. A whole-file JSON rewrite loses those.
    marker = '"entries": ['
    start = before.index(marker) + len(marker)
    decoder, cursor, entries = json.JSONDecoder(), start, []
    while True:
        while before[cursor].isspace() or before[cursor] == ',': cursor += 1
        if before[cursor] == ']': break
        item, end = decoder.raw_decode(before, cursor)
        if not str(item.get('path', '')).startswith('assets/units/slag_mortar_cutout/'):
            entries.append(before[before.rfind('\n', 0, cursor) + 1:end])
        cursor = end
    for item in updated['entries']:
        if str(item.get('path', '')).startswith('assets/units/slag_mortar_cutout/'):
            entries.append('    ' + json.dumps(item, indent=2).replace('\n', '\n    '))
    return before[:start] + '\n' + ',\n'.join(entries) + '\n  ' + before[cursor:]


def seal():
    from humanoid_cutout.integration import record
    identity_path = PROJECT / 'spec/art_identity/registry.json'
    identity_before = identity_path.read_text()
    pending = record(PROJECT, CASE, ASSETS)
    identity_path.write_text(preserve_identity_entries(identity_before, read_json(identity_path)))
    path = ASSETS / 'integration.json'
    write_json(path, {**read_json(path), **declaration()})
    return pending


def register():
    registry = read_json(DENSITY / 'registry.json')
    entry = next((e for e in registry['entries'] if e['id'] == ID), None)
    if entry is None:
        entry = {'id': ID, 'kind': 'rig', 'unit_type': 'slag_mortar', 'dir': str(ASSETS.relative_to(PROJECT)),
            'rig_script': str((ASSETS / 'rig.gd').relative_to(PROJECT)), 'paths': [], 'frames': None,
            'r': read_json(PROJECT / 'data/enemies.json')['slag_mortar']['art_scale'],
            'r_derivation': {'path': 'data/enemies.json', 'key': 'slag_mortar.art_scale', 'expression': 'art_scale / hero reference'},
            'facings': {}, 'rest_paths': {}}
        registry['entries'].append(entry)
    entry['paths'] = sorted(str(p.relative_to(PROJECT)) for view in ('front', 'rear')
        for p in (ASSETS / 'humanoid_v2' / view).glob('*.png') if p.name != 'rest.png')
    adopt = list(entry['paths'])
    for view in ('front', 'rear'):
        rest = str((ASSETS / f'humanoid_v2/{view}/rest.png').relative_to(PROJECT))
        share = metrics(Image.open(PROJECT / rest).convert('RGBA'))['orphan_share']
        t = strength(share)
        grid = round(t / entry['r'], 2)
        entry['facings'][view] = {'measurement_path': rest, 'orphan_share': share, 't': t, 'grid': grid,
                                'mode': 'regrid' if grid >= 1.2 else 'clean'}
        entry['rest_paths'][view] = [rest]
        registry['excluded_paths'][rest] = {'category': 'other', 'reason': 'rr-22 derived rest; native rebake pending director; not live paint.'}
        adopt.append(rest)
        layout = read_json(ASSETS / f'humanoid_v2/{view}.json')
        for part in layout['parts'] + layout['joint_meshes']: part['file'] = 'humanoid_v2/' + part['file']
        layout['rest_source'] = 'humanoid_v2/' + layout['rest_source']
        write_json(ASSETS / (view + '.json'), layout)
    write_json(DENSITY / 'registry.json', registry)
    missing = [p for p in adopt if not (DENSITY / 'sources' / p).exists()]
    if missing: subprocess.run([sys.executable, 'tools/process_board_density.py', '--adopt', *missing], cwd=PROJECT, check=True)
    subprocess.run([sys.executable, 'tools/process_board_density.py', '--only', ID], cwd=PROJECT, check=True)
    seal()
    print('RR22 DENSITY PAINT: PASS (both views adopted/processed; native rests pending director)')


if __name__ == '__main__':
    if 'seal' in sys.argv:
        pending = seal()
        if pending: raise ValueError('Native rest rebake pending: ' + str(pending))
        print('RR22 DENSITY REST RECORDS: PASS')
    else: register()
