"""Register/adopt only rr-20. Native rest certification belongs to the director."""
import json
import re
import subprocess
import sys
from PIL import Image
from case import ROOT, CASE, ASSETS, VIEWS, read_json, write_json, digest
from pixel_density import metrics, strength
from art_identity_gate import pixel_digest, measure
import process_board_density as density

ID = 'hollow_mimic_cutout'


def replace_owned_entries(text, records):
    """Patch only this unit, retaining unrelated JSON bytes (even legacy keys)."""
    decoder = json.JSONDecoder()
    cursor = text.index('[', text.index('"entries"')) + 1
    spans, end = [], cursor
    while True:
        while text[cursor].isspace() or text[cursor] == ',': cursor += 1
        if text[cursor] == ']':
            close = cursor
            break
        item, end = decoder.raw_decode(text, cursor)
        spans.append((cursor, end, item))
        cursor = end
    pending = {r['path']: r for r in records}
    edits = []
    for start, stop, item in spans:
        record = pending.pop(item.get('path'), None)
        if record is not None:
            serialized = json.dumps(record, indent=2).replace('\n', '\n    ')
            edits.append((start, stop, serialized))
    if pending:
        serialized = ',\n'.join('    ' + json.dumps(r, indent=2).replace('\n', '\n    ') for r in pending.values())
        edits.append((end, close, (',\n' if spans else '\n') + serialized + '\n  '))
    for start, stop, replacement in sorted(edits, reverse=True): text = text[:start] + replacement + text[stop:]
    return text


def record(case=CASE):
    identity_path = ROOT / 'spec/art_identity/registry.json'
    scale = read_json(ROOT / 'data/enemies.json')['hollow_mimic']['art_scale']
    records = []
    for view in VIEWS:
        rest = ASSETS / view / 'rest.png'
        layout_path = ASSETS / (view + '.json')
        layout = read_json(layout_path)
        layout['rest_source_sha256'] = digest(rest)
        write_json(layout_path, layout)
        relative = str(rest.relative_to(ROOT))
        entry = {'path': relative}
        job = ROOT / read_json(case/'inputs.json')[view+'_job']
        kit = read_json(job / 'kit.json')
        entry.update(id='hollow_mimic', kind='creature', entry_kind='legacy', anatomy=kit['anatomy'],
            boss=False, art_scale=scale, size_class=kit['size_class'], pixel_sha256=pixel_digest(Image.open(rest)),
            metrics=measure(rest, scale, 'creature', kit['anatomy']),
            source_path=str(job.relative_to(ROOT) / 'processed.png'), source_pixel_sha256=read_json(job/'processed.json')['pixel_sha256'],
            owner_approval=('rr-20 supplied approved mq9 paintings; native certification pending director.'
                if case == CASE else read_json(case/'anatomy.json')['integration']['owner_approval']))
        records.append(entry)
    identity_path.write_text(replace_owned_entries(identity_path.read_text(), records))
    entry = next(e for e in density.load_registry()['entries'] if e['id'] == ID)
    pending = density.rest_errors([entry], read_json(density.MANIFEST))
    board = (ROOT / 'scripts/combat_board_view.gd').read_text()
    write_json(ASSETS / 'integration.json', {
        'ready': False, 'rig': 'humanoid_v2', 'case': str(case.relative_to(ROOT)),
        'director_sha256': digest(case / 'director_motion.json'),
        'design_placeholders': read_json(case / 'inputs.json')['design_placeholders'],
        'idle_phase_seed': 'slot', 'step_selectors': {'en06_mirror': 'mirror'},
        'contact_playback_clips': ['bolt', 'mirror', 'block'],
        'death_timing': {'clip_seconds': read_json(case/'compiled_motion.json')['clips']['death']['seconds'],
            'dissolve_frames': int(re.search(r'const ENEMY_SHADOW_DISSOLVE_FRAME_COUNT: int = (\d+)', board)[1]),
            'dissolve_frame_seconds': float(re.search(r'const ENEMY_SHADOW_DISSOLVE_FRAME_SECONDS: float = ([\d.]+)', board)[1])},
        'native_proof': 'pending director density/rest/native/production/idle/review',
        'rest_identity': {view: read_json(case/'proof/build.json')['views'][view]['rest_mismatch_pixels'] for view in VIEWS},
        'density': {'entry': ID, 'native_rest_pending': pending},
        'files': {str(p.relative_to(ASSETS)): digest(p) for p in sorted(ASSETS.rglob('*'))
                  if p.is_file() and p.suffix in ('.gd', '.json', '.png') and p.name != 'integration.json'}})
    return pending


def register(refresh_sources=False, case=CASE):
    registry = read_json(density.REGISTRY)
    paths = sorted(str(p.relative_to(ROOT)) for view in VIEWS for p in (ASSETS / view).glob('*.png') if p.name != 'rest.png')
    scale = read_json(ROOT/'data/enemies.json')['hollow_mimic']['art_scale']
    # Unit width is 1.03 / 255 * art_scale; hero reference is 1.03 / 255.
    ratio = scale
    rests = {v: [str((ASSETS / v / 'rest.png').relative_to(ROOT))] for v in VIEWS}
    facings = {}
    for view in VIEWS:
        rest = rests[view][0]
        share = metrics(Image.open(ROOT / rest).convert('RGBA'))['orphan_share']
        treatment = strength(share)
        grid = round(treatment / ratio, 2)
        facings[view] = {'measurement_path': rest, 'orphan_share': share, 't': treatment,
                         'grid': grid, 'mode': 'regrid' if grid >= 1.2 else 'clean'}
        registry['excluded_paths'][rest] = {'category': 'other', 'reason': 'Derived rr-20 rest; separately certified by native rest_paths.'}
    entry = {'id': ID, 'unit_type': 'hollow_mimic', 'kind': 'rig', 'dir': str(ASSETS.relative_to(ROOT)),
        'rig_script': str((ASSETS/'rig.gd').relative_to(ROOT)), 'paths': paths,
        'measurement_path': rests['front'][0], 'frames': None,
        'r': ratio, 'r_derivation': {'path': 'data/enemies.json', 'key': 'hollow_mimic.art_scale',
            'expression': 'unit width 1.03 / 255 * art_scale / hero reference (1.03 / 255)'},
        'facings': facings, 'rest_paths': rests,
        'derivation_note': 'rr-20 approved mq9 source partition; feedback-1 residue cleanup and feedback-2 own-edge joint continuations; native rest recertification pending director.'}
    if case.name == 'rr29':
        entry['derivation_note'] = 'rr-29 approved mq11 source partition; exact rest identity; rr20 cuts and recomputed own-piece joint/rr28 continuations; native rest recertification pending director.'
        for rest in rests.values():
            registry['excluded_paths'][rest[0]]['reason'] = 'Derived rr-29 rest; separately certified by native rest_paths.'
    existing = next((e for e in registry['entries'] if e['id'] == ID), None)
    if existing is None: registry['entries'].append(entry)
    else: existing.update(entry)
    write_json(density.REGISTRY, registry)
    adopted = paths + [r[0] for r in rests.values()]
    missing = [p for p in adopted if not (density.SOURCES / p).exists()]
    # A rebuild must never silently replace the untouched baseline.
    changed = [p for p in adopted if (density.SOURCES/p).exists() and
               (ROOT/p).read_bytes() != (density.SOURCES/p).read_bytes()]
    if changed and not refresh_sources: raise ValueError('Inspect changed source adoption before rebuilding density: ' + str(changed))
    if changed:
        prefix = str(ASSETS.relative_to(ROOT)) + '/'
        if any(not p.startswith(prefix) for p in changed): raise ValueError('Refusing to adopt outside rr-20')
        subprocess.run([sys.executable, 'tools/process_board_density.py', '--adopt', *changed, '--force-adopt'], cwd=ROOT, check=True)
    if missing: subprocess.run([sys.executable, 'tools/process_board_density.py', '--adopt', *missing], cwd=ROOT, check=True)
    subprocess.run([sys.executable, 'tools/process_board_density.py', '--only', ID], cwd=ROOT, check=True)
    record(case)
    print('RR20 DENSITY PAINT: PASS (both views adopted/processed; native rest pending director)')


if __name__ == '__main__':
    if len(sys.argv) > 1 and sys.argv[1] == 'seal':
        pending = record()
        if pending: raise ValueError('Native rest rebake still pending: ' + str(pending))
        print('RR20 DENSITY REST RECORDS: PASS (2 director-rendered views)')
    else: register('--refresh-sources' in sys.argv)
