"""rr-12 promotion and derived registrations; native rebakes stay director-owned."""
import argparse
import json
import shutil
from unittest.mock import patch
from rr12_inputs import *
from rr12_prepare import case_for
from rr12_build import native_operations
from maquette_motion import gates, certificates
import maquette_cutout_build as release
import process_board_density as density
from pixel_density import metrics, strength


def promote(creature):
    case = case_for(creature)
    motion = read_json(case / 'proof/motion_gates.json')
    if not motion['ok']:
        raise CutoutError('Signed bone motion must pass before promotion')
    with native_operations(case), patch.object(release, 'case_for', case_for), \
         patch.object(release, 'approved_source', lambda _: DIRECTOR):
        release.validate_derived_material(case)
        destination = PROJECT / 'assets/units' / (creature + '_cutout')
        for folder in ('segmented', 'hidden', 'seams', 'features', 'front', 'rear'):
            shutil.rmtree(destination / folder, ignore_errors=True)
        result = release.promote(creature)
    with patch.object(release, 'SOURCE', DIRECTOR):
        release.update_rest_identity_ledger(creature)
    label_rest_approval(creature)
    return result


def label_rest_approval(creature):
    from art_identity_gate import measure
    path = PROJECT / 'spec/art_identity/registry.json'
    registry = read_json(path)
    prefix = 'assets/units/' + creature + '_cutout/'
    for entry in registry['entries']:
        if entry['path'].startswith(prefix):
            view = Path(entry['path']).parent.name
            kit = read_json(job_for(creature, view) / 'kit.json')
            entry['size_class'] = kit['size_class']
            entry['anatomy'] = kit['anatomy']
            entry['metrics'] = measure(PROJECT / entry['path'], entry['art_scale'], 'creature', kit['anatomy'])
            entry['owner_approval'] = ('rr-12 brief: supplied approved paired maquette painting; '
                'derived offline rest snapshot, not a worker art verdict or native renderer proof.')
    write_json(path, registry)


def register_density(creature):
    base = PROJECT / 'assets/units' / (creature + '_cutout')
    registry = density.load_registry()
    scale = read_json(PROJECT / 'data/enemies.json')[creature].get('art_scale', 1.0)
    prefix = str(base.relative_to(PROJECT))
    paths = sorted({prefix + '/' + p['file'] for v in VIEWS
                    for p in read_json(base / (v + '.json'))['parts']})
    entry = {'id': creature + '_cutout', 'unit_type': creature, 'kind': 'rig', 'dir': prefix,
             'rig_script': prefix + '/rig.gd', 'paths': paths, 'frames': None, 'r': scale,
             'r_derivation': {'path': 'data/enemies.json', 'key': creature + '.art_scale',
                              'expression': 'art_scale (default 1.0)'}, 'facings': {}, 'rest_paths': {}}
    for view in VIEWS:
        path = prefix + '/' + view + '/rest.png'
        share = metrics(Image.open(PROJECT / path).convert('RGBA'))['orphan_share']
        t = strength(share)
        grid = round(t / scale, 2)
        entry['facings'][view] = {'measurement_path': path, 'orphan_share': share,
                                  't': t, 'grid': grid, 'mode': 'regrid' if grid >= 1.2 else 'clean'}
        entry['rest_paths'][view] = [path]
    registry['entries'] = [e for e in registry['entries'] if e['id'] != entry['id']] + [entry]
    for path in base.rglob('*.png'):
        relative = str(path.relative_to(PROJECT))
        if relative not in paths:
            registry['excluded_paths'][relative] = {
                'category': 'other' if path.name == 'rest.png' else 'never_drawn',
                'reason': 'Derived rest snapshot, separately bound in rest_paths; never live paint'
                          if path.name == 'rest.png' else 'Feature ownership mask; metadata, never drawn'}
    write_json(density.REGISTRY, registry)
    missing = [p for p in density.source_paths(registry, [entry]) if not (density.SOURCES / p).exists()]
    if missing:
        density.adopt(missing, False)
    manifest = read_json(density.MANIFEST)
    for path in paths:
        image, record = density.derive(entry, path)
        image.save(PROJECT / path)
        manifest[path] = record
    density.MANIFEST.write_text(json.dumps(manifest, indent=2) + '\n')
    record = read_json(base / 'integration.json')
    record['density'] = {'entry': entry['id'], 'paint': 'processed from untouched adopted parts',
                         'native_rests': 'pending director windowed rebake; no rest record fabricated'}
    record['files'] = {str(p.relative_to(base)): digest(p) for p in base.rglob('*')
                       if p.is_file() and p.name != 'integration.json'}
    write_json(base / 'integration.json', record)
    return {'ok': not density.paint_errors([entry], manifest), 'entry': entry['id'],
            'native_rest_pending': density.rest_errors([entry], manifest)}


def refresh_headless(creature):
    case = case_for(creature)
    certificates.require_current(case)
    base = PROJECT / 'assets/units' / (creature + '_cutout')
    record = read_json(base / 'integration.json')
    record['files'] = {str(p.relative_to(base)): digest(p) for p in base.rglob('*')
                       if p.is_file() and p.name != 'integration.json'}
    record['native_proof'] = 'pending design-owner windowed proof and density rest rebake'
    record['headless_pixel_certificate_sha256'] = digest(case / certificates.CERTIFICATE_PATH)
    write_json(base / 'integration.json', record)
    return {'ok': True, 'native_proof': record['native_proof']}


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('command', choices=('promote', 'density', 'refresh-headless', 'seal-density'))
    p.add_argument('--creature', choices=CREATURES, required=True)
    args = p.parse_args()
    if args.command == 'promote':
        result = promote(args.creature)
    elif args.command == 'density':
        result = register_density(args.creature)
    elif args.command == 'refresh-headless':
        result = refresh_headless(args.creature)
    else:
        with patch.object(release, 'SOURCE', DIRECTOR):
            result = release.seal_density(args.creature)
        label_rest_approval(args.creature)
    print(json.dumps(result, indent=2))


if __name__ == '__main__':
    main()
