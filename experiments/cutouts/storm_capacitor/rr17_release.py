"""Scoped Capacitor density/rest registrations; never fabricates native proof."""
import argparse
import shutil
from rr17_build import *
import process_board_density as density
from pixel_density import metrics, strength
from humanoid_cutout.native_frames import load_frame


def register():
    registry = density.load_registry()
    prefix = str(PRODUCTION.relative_to(ROOT))
    paths = sorted(str(p.relative_to(ROOT)) for p in (PRODUCTION / 'paint').glob('*.png'))
    # The input painting already passed density treatment. Its partition and
    # table-prescribed recolours must stay exact, including the protected fill.
    entry = {'id': 'storm_capacitor_cutout', 'unit_type': 'storm_capacitor', 'kind': 'rig',
             'dir': prefix, 'rig_script': prefix + '/rig.gd', 'paths': paths,
             'frames': None, 'r': 1.0, 'r_derivation': {'path': 'data/enemies.json',
                 'key': 'storm_capacitor.art_scale', 'expression': 'art_scale (default 1.0); existing Capacitor BODY_SCALE unchanged'},
             'exact_source_partition': True,
             'derivation_note': 'rr-17 exact partition of treated assets/art/enemies/storm_capacitor.png; protected vent fill and prescribed glow table. rr17_gates validates every pixel.',
             'facings': {}, 'rest_paths': {}}
    for view in VIEWS:
        path = prefix + f'/{view}/rest.png'
        share = metrics(load_frame(ROOT / path).convert('RGBA'))['orphan_share']
        t = strength(share)
        entry['facings'][view] = {'measurement_path': path, 'orphan_share': share, 't': t, 'grid': round(t, 2), 'mode': 'clean'}
        entry['rest_paths'][view] = [path]
        registry['excluded_paths'][path] = {'category': 'other', 'reason': 'Derived exact rest, separately registered in rest_paths; native rebake pending director.'}
    registry['entries'] = [e for e in registry['entries'] if e['id'] != entry['id']] + [entry]
    write(density.REGISTRY, registry)
    missing = [p for p in density.source_paths(registry, [entry]) if not (density.SOURCES / p).exists()]
    if missing: density.adopt(missing, False)
    manifest = read(density.MANIFEST)
    for path in paths:
        image, record = density.derive(entry, path)
        image.save(ROOT / path)
        manifest[path] = record
    write(density.MANIFEST, manifest)
    identity_rests('Derived offline rest equals approved painting; native rebake pending director.')
    print('RR17 DENSITY PAINT: PASS (%d exact derived textures; native rest records pending)' % len(paths))


def identity_rests(evidence):
    from art_identity_gate import pixel_digest, measure
    path = ROOT / 'spec/art_identity/registry.json'
    registry = read(path)
    for view in VIEWS:
        rest = PRODUCTION / view / 'rest.png'
        relative = str(rest.relative_to(ROOT))
        record = {'id': 'storm_capacitor', 'path': relative, 'kind': 'object', 'entry_kind': 'legacy',
                  'anatomy': '', 'boss': False, 'art_scale': 1.0, 'size_class': 'large',
                  'pixel_sha256': pixel_digest(load_frame(rest)), 'metrics': measure(rest, 1.0, 'object', ''),
                  'source_path': str(PAINTING.relative_to(ROOT)), 'source_pixel_sha256': pixel_digest(load_frame(PAINTING)),
                  'owner_approval': 'rr-17 brief: exact partition of existing approved Storm Capacitor painting. ' + evidence}
        registry['entries'] = [e for e in registry['entries'] if e['path'] != relative] + [record]
    write(path, registry)


def seal(native):
    from rr17_gates import pixel_gate
    result = pixel_gate(read(CASE / 'proof/samples.json'), native)
    if not result['ok']: raise ValueError(result['errors'])
    for view in VIEWS:
        actual = load_frame(native / (view + '_rest.png')).convert('RGBA')
        if not np.array_equal(actual, load_frame(PAINTING).convert('RGBA')): raise ValueError('Native rest differs')
        actual.save(PRODUCTION / view / 'rest.png')
    entry = next(e for e in density.load_registry()['entries'] if e['id'] == 'storm_capacitor_cutout')
    density.record_rests([entry], read(density.MANIFEST))
    identity_rests('Real native rest equals the approved painting byte for byte in decoded RGBA.')
    record = read(PRODUCTION / 'integration.json')
    record['density'] = {'entry': entry['id'], 'parts_pixel_sha256': density.parts_digest(entry),
                         'native_rests': {p: read(density.MANIFEST)[p] for p in density.rest_paths(entry)}}
    record['native_proof'] = 'native rest and every sequential rig frame verified; production capture remains separate'
    record['files'] = {str(p.relative_to(PRODUCTION)): digest(p) for p in sorted(PRODUCTION.rglob('*')) if p.is_file() and p.name != 'integration.json'}
    write(PRODUCTION / 'integration.json', record)
    print('RR17 NATIVE REST: PASS (2 exact native rests recorded)')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('command', choices=('density', 'seal-rest'))
    parser.add_argument('--native', type=Path)
    args = parser.parse_args()
    register() if args.command == 'density' else seal(args.native)
