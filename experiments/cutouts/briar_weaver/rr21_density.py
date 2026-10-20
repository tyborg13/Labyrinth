"""Scoped density/identity registration. Native rest certification stays pending."""
import sys
import subprocess
from rr21_case import PROJECT, CASE, ASSETS
sys.path[:0] = [str(PROJECT / 'tools'), str(PROJECT)]
from cutout_pipeline.cases import read_json, write_json
from pixel_density import metrics, strength
from PIL import Image
from humanoid_cutout.integration import record

ID = 'briar_weaver_cutout'
DENSITY = PROJECT / 'spec/assets/board_pixel_density'


def scoped_identity(original, own_records):
    """Replace only this unit's records, preserving all other source bytes."""
    import json
    decoder = json.JSONDecoder()
    cursor = original.index('[', original.index('"entries"')) + 1
    spans = {}
    while True:
        while original[cursor].isspace() or original[cursor] == ',': cursor += 1
        if original[cursor] == ']': break
        item, end = decoder.raw_decode(original, cursor)
        if item.get('path', '').startswith('assets/units/briar_weaver_cutout/'):
            spans[item['path']] = (cursor, end)
        cursor = end
    encoded = {item['path']: json.dumps(item, indent=2).replace('\n', '\n    ') for item in own_records}
    extra = [payload for path, payload in encoded.items() if path not in spans]
    if extra:
        original = original[:cursor].rstrip() + ',\n    ' + ',\n    '.join(extra) + '\n  ' + original[cursor:]
    for path, (start, end) in sorted(spans.items(), key=lambda row: row[1][0], reverse=True):
        original = original[:start] + encoded[path] + original[end:]
    return original


def seal():
    identity_path = PROJECT / 'spec/art_identity/registry.json'
    original = identity_path.read_text()
    pending = record(PROJECT, CASE, ASSETS)
    generated = read_json(identity_path)
    identity_path.write_text(scoped_identity(original, [e for e in generated['entries'] if e.get('path', '').startswith('assets/units/briar_weaver_cutout/')]))
    path = ASSETS / 'integration.json'
    entry = read_json(path)
    board = (PROJECT / 'scripts/combat_board_view.gd').read_text()
    import re
    entry.update(rig_directory='humanoid_v2', action_adapter='res://assets/units/briar_weaver_cutout/actions.gd',
        action_aliases={'heal': 'heal_ally'}, idle_phase_seed='slot', death_timing={'clip_seconds': read_json(CASE / 'compiled_motion.json')['clips']['death']['seconds'],
            'dissolve_frames': int(re.search(r'const ENEMY_SHADOW_DISSOLVE_FRAME_COUNT: int = (\d+)', board)[1]),
            'dissolve_frame_seconds': float(re.search(r'const ENEMY_SHADOW_DISSOLVE_FRAME_SECONDS: float = ([\d.]+)', board)[1])})
    write_json(path, entry)
    return pending


def register():
    registry_path = DENSITY / 'registry.json'
    registry = read_json(registry_path)
    paths = sorted(str(p.relative_to(PROJECT)) for view in ('front', 'rear')
        for p in (ASSETS / 'humanoid_v2' / view).glob('*.png') if p.name != 'rest.png')
    facings, rests = {}, {}
    for view in ('front', 'rear'):
        rest = str((ASSETS / 'humanoid_v2' / view / 'rest.png').relative_to(PROJECT))
        share = metrics(Image.open(PROJECT / rest).convert('RGBA'))['orphan_share']
        t = strength(share); grid = round(t, 2)
        facings[view] = {'measurement_path': rest, 'orphan_share': share, 't': t, 'grid': grid,
                         'mode': 'regrid' if grid >= 1.2 else 'clean'}
        rests[view] = [rest]
        registry['excluded_paths'][rest] = {'category': 'other', 'reason': 'Derived rr-21 native rest; separately bound in rest_paths, never live paint.'}
        layout = read_json(ASSETS / 'humanoid_v2' / (view + '.json'))
        for part in layout['parts'] + layout['joint_meshes']: part['file'] = 'humanoid_v2/' + part['file']
        layout['rest_source'] = 'humanoid_v2/' + layout['rest_source']
        write_json(ASSETS / (view + '.json'), layout)
    entry = {'id': ID, 'unit_type': 'briar_weaver', 'kind': 'rig', 'dir': str(ASSETS.relative_to(PROJECT)),
        'rig_script': str((ASSETS / 'rig.gd').relative_to(PROJECT)), 'paths': paths, 'frames': None, 'r': 1.0,
        'r_derivation': {'path': 'data/enemies.json', 'key': 'briar_weaver.art_scale',
            'expression': 'art_scale (default 1.0); standard board source-pixel registration'},
        'facings': facings, 'rest_paths': rests}
    previous = next((i for i, e in enumerate(registry['entries']) if e['id'] == ID), None)
    if previous is None: registry['entries'].append(entry)
    else: registry['entries'][previous] = entry
    write_json(registry_path, registry)
    adopted = paths + [p for group in rests.values() for p in group]
    changed = [p for p in adopted if (DENSITY / 'sources' / p).exists() and (PROJECT / p).read_bytes() != (DENSITY / 'sources' / p).read_bytes()]
    if changed: raise ValueError('Refusing to overwrite already adopted source: ' + str(changed))
    missing = [p for p in adopted if not (DENSITY / 'sources' / p).exists()]
    if missing: subprocess.run([sys.executable, 'tools/process_board_density.py', '--adopt', *missing], cwd=PROJECT, check=True)
    for relative in adopted:
        (DENSITY / 'sources' / (relative + '.import')).write_text('[remap]\n\nimporter="keep"\n')
    subprocess.run([sys.executable, 'tools/process_board_density.py', '--only', ID], cwd=PROJECT, check=True)
    seal()
    print('RR21 DENSITY PAINT: PASS (both views adopted/processed; native rest pending director)')


if __name__ == '__main__':
    if len(sys.argv) > 1 and sys.argv[1] == 'seal':
        pending = seal()
        if pending: raise ValueError('Native rest rebake pending: ' + str(pending))
        print('RR21 DENSITY REST: PASS (two native views)')
    else: register()
