"""Scoped density/identity registration. Native rest certification stays pending."""
import sys
import subprocess
from rr38_case import PROJECT, CASE, ASSETS
sys.path[:0] = [str(PROJECT / 'tools'), str(PROJECT)]
from cutout_pipeline.cases import read_json, write_json
from pixel_density import metrics, strength
from PIL import Image
from humanoid_cutout.integration import record

ID = 'chainbound_gaoler_cutout'
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
        if item.get('path', '').startswith('assets/units/chainbound_gaoler_cutout/'):
            spans[item['path']] = (cursor, end)
        cursor = end
    encoded = {item['path']: json.dumps(item, indent=2).replace('\n', '\n    ') for item in own_records}
    extra = [payload for path, payload in encoded.items() if path not in spans]
    if extra:
        original = original[:cursor].rstrip() + ',\n    ' + ',\n    '.join(extra) + '\n  ' + original[cursor:]
    for path, (start, end) in sorted(spans.items(), key=lambda row: row[1][0], reverse=True):
        original = original[:start] + encoded[path] + original[end:]
    return original


def board_constant(name, kind):
    """The board's dissolve constant, literal or one preload hop away.

    rr-51: rr-46 (8477f8cf2) moved the literals into playback_timing.gd and
    left preload aliases in combat_board_view.gd, which broke this seal.
    """
    import re
    board = (PROJECT / 'scripts/combat_board_view.gd').read_text()
    literal = re.search(r'const %s: %s = ([\d.]+)\n' % (name, kind), board)
    if literal: return literal[1]
    source = re.search(r'const %s: %s = preload\("res://([^"]+)"\)\.%s\n' % (name, kind, name), board)[1]
    return re.search(r'const %s: %s = ([\d.]+)\n' % (name, kind), (PROJECT / source).read_text())[1]


def seal():
    identity_path = PROJECT / 'spec/art_identity/registry.json'
    original = identity_path.read_text()
    pending = record(PROJECT, CASE, ASSETS)
    generated = read_json(identity_path)
    # rr-51 director decision (2026-10-29): the v2 rests' size_class follows their
    # drawn height by the gate's own bands (art_identity_gate.adopt_legacy's rule),
    # not the 255px kit's; at art_scale 1.10 both draw 236-238px, which is large.
    from art_identity_gate import in_band
    bands = read_json(PROJECT / 'spec/art_identity/bands.json')['size_class_canvas_height']
    live = {str((ASSETS / 'humanoid_v2' / view / 'rest.png').relative_to(PROJECT)) for view in ('front', 'rear')}
    for entry in generated['entries']:
        if entry.get('path') in live:
            entry['size_class'] = next(k for k, b in bands.items() if in_band(entry['metrics']['height_drawn'], b))
    identity_path.write_text(scoped_identity(original, [e for e in generated['entries'] if e.get('path', '').startswith('assets/units/chainbound_gaoler_cutout/')]))
    path = ASSETS / 'integration.json'
    entry = read_json(path)
    entry.update(effect_anchors={"reel":"chain", "pin":"chain", "press":"hand_near", "guard":"hand_far"}, ready=False, design_placeholders=read_json(CASE/"inputs.json")["design_placeholders"], rig_directory='humanoid_v2',
        contact_playback_clips=['reel', 'pin', 'press', 'guard'], idle_phase_seed='slot', death_timing={'clip_seconds': read_json(CASE / 'compiled_motion.json')['clips']['death']['seconds'],
            'dissolve_frames': int(board_constant('ENEMY_SHADOW_DISSOLVE_FRAME_COUNT', 'int')),
            'dissolve_frame_seconds': float(board_constant('ENEMY_SHADOW_DISSOLVE_FRAME_SECONDS', 'float'))})
    write_json(path, entry)
    return pending


def prune_empty_sources():
    """Remove only obsolete derived paint for the director's empty rear nodes."""
    registry=read_json(DENSITY/'registry.json')
    active={p for e in registry['entries'] for p in e['paths']}
    manifest=read_json(DENSITY/'outputs.json')
    prefix=str((ASSETS/'humanoid_v2/rear').relative_to(PROJECT))+'/'
    for name in read_json(CASE/'anatomy.json').get('intentionally_empty',{}).get('rear',{}):
        path=prefix+'hidden_'+name+'.png'
        if path in active or (PROJECT/path).exists():
            raise ValueError('Intentionally empty rear source still live: '+path)
        manifest.pop(path,None)
        for suffix in ('','.import'):(DENSITY/'sources'/(path+suffix)).unlink(missing_ok=True)
    write_json(DENSITY/'outputs.json',dict(sorted(manifest.items())))


def expected_rests():
    """Mirror rr-18: independent treated rest, without forging a native seal."""
    from cutout_pipeline.cases import digest
    reports={}
    for view in ('front','rear'):
        path=ASSETS/f'humanoid_v2/{view}.json';layout=read_json(path)
        rest=Image.new('RGBA',(255,255))
        for part in sorted(layout['parts'],key=lambda p:p['z_index']):
            rest.alpha_composite(Image.open(ASSETS/'humanoid_v2'/part['file']).convert('RGBA'),tuple(part['offset']))
        target=ASSETS/'humanoid_v2'/layout['rest_source'];rest.save(target)
        layout['rest_source_sha256']=digest(target);write_json(path,layout)
        reports[view]={'sha256':digest(target),'native_pixels':False}
    write_json(CASE/'proof/density_rest.json',reports)


def register(rebuild_derived_sources=False):
    from humanoid_cutout.promotion import promote
    # Adoption always starts from this case's untouched derived cut, never a
    # previously density-processed production PNG.
    layouts = {v: read_json(CASE / f'layouts/{v}.json') for v in ('front', 'rear')}
    promote(PROJECT, CASE, ASSETS / 'humanoid_v2', layouts)
    registry_path = DENSITY / 'registry.json'
    registry = read_json(registry_path)
    paths = sorted(str(p.relative_to(PROJECT)) for view in ('front', 'rear')
        for p in (ASSETS / 'humanoid_v2' / view).glob('*.png') if p.name != 'rest.png')
    facings, rests = {}, {}
    draw_scale = read_json(PROJECT/'data/enemies.json')['chainbound_gaoler'].get('art_scale', 1.0)
    for view in ('front', 'rear'):
        rest = str((ASSETS / 'humanoid_v2' / view / 'rest.png').relative_to(PROJECT))
        share = metrics(Image.open(PROJECT / rest).convert('RGBA'))['orphan_share']
        t = strength(share); grid = round(t / draw_scale, 2)
        facings[view] = {'measurement_path': rest, 'orphan_share': share, 't': t, 'grid': grid,
                         'mode': 'regrid' if grid >= 1.2 else 'clean'}
        rests[view] = [rest]
        registry['excluded_paths'][rest] = {'category': 'other', 'reason': 'Derived rr-38 native rest; separately bound in rest_paths, never live paint.'}
    retained_paint = {p for e in registry['entries'] if e['id'] != ID for p in e['paths']}
    for old in ASSETS.rglob('*.png'):
        relative = str(old.relative_to(PROJECT))
        if relative not in paths and relative not in retained_paint and relative not in [p for group in rests.values() for p in group]:
            registry['excluded_paths'][relative] = {'category': 'other', 'reason': 'Historical Gaoler cutout; v2 registration supersedes this unused runtime paint.'}
    entry = {'id': ID, 'unit_type': 'chainbound_gaoler', 'kind': 'rig', 'dir': str((ASSETS / 'humanoid_v2').relative_to(PROJECT)),
        'rig_script': str((ASSETS / 'rig.gd').relative_to(PROJECT)), 'paths': paths, 'frames': None, 'r': draw_scale,
        'r_derivation': {'path': 'data/enemies.json', 'key': 'chainbound_gaoler.art_scale',
            'expression': 'art_scale (default 1.0); standard board source-pixel registration'},
        'facings': facings, 'rest_paths': rests}
    previous = next((i for i, e in enumerate(registry['entries']) if e['id'] == ID), None)
    if previous is None: registry['entries'].append(entry)
    else: registry['entries'][previous] = entry
    write_json(registry_path, registry)
    adopted = paths + [p for group in rests.values() for p in group]
    changed = [p for p in adopted if (DENSITY / 'sources' / p).exists() and (PROJECT / p).read_bytes() != (DENSITY / 'sources' / p).read_bytes()]
    if changed:
        if not rebuild_derived_sources: raise ValueError('Rebuild changed derived source parts; use --rebuild-derived-sources: ' + str(changed))
        # These are this unit's derived partitions, never director paintings.
        subprocess.run([sys.executable, 'tools/process_board_density.py', '--force-adopt', '--adopt', *changed], cwd=PROJECT, check=True)
    missing = [p for p in adopted if not (DENSITY / 'sources' / p).exists()]
    if missing: subprocess.run([sys.executable, 'tools/process_board_density.py', '--adopt', *missing], cwd=PROJECT, check=True)
    for relative in adopted:
        (DENSITY / 'sources' / (relative + '.import')).write_text('[remap]\n\nimporter="keep"\n')
    subprocess.run([sys.executable, 'tools/process_board_density.py', '--only', ID], cwd=PROJECT, check=True)
    expected_rests()
    seal()
    from rr38_proof_case import build
    build()
    seal()
    print('RR38 DENSITY PAINT: PASS (both views adopted/processed; native rest pending director)')


if __name__ == '__main__':
    if len(sys.argv) > 1 and sys.argv[1] == 'seal':
        pending = seal()
        if pending: raise ValueError('Native rest rebake pending: ' + str(pending))
        print('RR38 DENSITY REST: PASS (two native views)')
    else: register('--rebuild-derived-sources' in sys.argv)
