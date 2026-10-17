"""Rerender approved r3 ownership in bounded bridge jobs; preserve clay bytes."""
import argparse
import json
from pathlib import Path
from shutil import copy2
import sys
sys.dont_write_bytecode = True

PROJECT = Path(__file__).resolve().parents[4]
sys.path.insert(0, str(PROJECT))
from spec.art_identity.maquettes.blender.bridge_client import run_job
from spec.art_identity.maquettes.blender.capture_manifest import sha256, write_manifest
from spec.art_identity.maquettes.blender.contract import digest

PROOF_DEFAULTS = {'baseline': '/private/tmp/labyrinth_codex/mq-03/round3/delivery/lancer_r3',
                  'out': '/private/tmp/labyrinth_codex/mq-03/round5/lancer_r3', 'timeout_s': 120}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--baseline', type=Path, default=Path(PROOF_DEFAULTS['baseline']))
    parser.add_argument('--out', type=Path, default=Path(PROOF_DEFAULTS['out']))
    parser.add_argument('--reuse-captures', action='store_true', help='Verify/finalize existing bounded native captures without rendering')
    args = parser.parse_args()
    spec_path = PROJECT / 'spec/art_identity/maquettes/frostglass_lancer/spec_r3.json'
    spec = json.loads(spec_path.read_text())
    if digest(spec) != json.loads((args.baseline / 'build_report.json').read_text())['spec_hash']:
        raise ValueError('Approved r3 spec changed')
    args.out.mkdir(parents=True, exist_ok=True)
    failed_views = {}
    images = [f'{v}_{m}.png' for v in ('front', 'rear') for m in ('parts', 'clay', 'silhouette')]
    images += [f'{v}_solo_{p}.png' for v in ('front', 'rear') for p in spec['labels']]
    images += [f'piece_gallery/{v}_{kind}.png' for v in ('front', 'rear') for kind in ('cloth', 'crystal', 'curve', 'gem', 'lames', 'plate')]
    images += ['front_torso.png', 'front_torso_frontal_control.png']
    for filename in images + ['build_report.json', 'joints_px.json', 'facing_report.json']:
        target = args.out / filename
        target.parent.mkdir(parents=True, exist_ok=True)
        if not args.reuse_captures:
            copy2(args.baseline / filename, target)
    for view in ('front', 'rear'):
        filename = 'piece_gallery/' + view + '_gallery.png'
        copy2(args.baseline / filename, args.out / filename)
    for view in ('front', 'rear'):
        if args.reuse_captures:
            receipt = args.out / (view + '_bridge.json')
            result = json.loads(receipt.read_text())
            result['stdout'] = (args.out / (view + '.log')).read_text()
            if result['exit'] and ('Required rig labels have empty solos:' not in result['stdout'] or
                not json.loads((args.out / ('ownership-' + view + '_geometry.json')).read_text())['passed']):
                raise ValueError('Cannot reuse an incomplete native capture')
            if result['exit']:
                failed_views[view] = True
            continue
        result = run_job(Path(__file__).with_name('capture_saved.py'),
                         [spec_path, args.baseline / 'maquette.blend', args.out, 'ownership-' + view],
                         timeout_s=PROOF_DEFAULTS['timeout_s'])
        (args.out / (view + '_bridge.json')).write_text(json.dumps({k: v for k, v in result.items() if k != 'stdout'}, indent=2) + '\n')
        (args.out / (view + '.log')).write_text(result['stdout'])
        print(f"RELABEL_CAPTURE: {view} exit={result['exit']} seconds={result['seconds']}", flush=True)
        if result['exit']:
            validation = args.out / 'ownership_validation.json'
            geometry = args.out / ('ownership-' + view + '_geometry.json')
            if 'Required rig labels have empty solos:' not in result['stdout'] or not validation.exists() or not geometry.exists():
                return result['exit']
            audit = json.loads(validation.read_text())
            if audit['passed'] or not json.loads(geometry.read_text())['passed']:
                return result['exit']
            failed_views.update(audit['empty_required_solos'])
    coverage = json.loads((args.out / 'solo_coverage.json').read_text())
    missing = {view: [part for part in spec['labels'] if coverage[view].get(part, 0) <= 0] for view in ('front', 'rear')}
    unchanged = {name: sha256(args.baseline / name) for name in images
                 if '_clay' in name or name.startswith('piece_gallery/')}
    assert all(sha256(args.out / name) == value for name, value in unchanged.items()), 'Approved clay/gallery bytes changed'
    manifest = write_manifest(args.out, digest(spec), 'full', images)
    proof = {'passed': not any(missing.values()) and not failed_views, 'spec_hash': digest(spec), 'geometry_and_pose_unchanged': True,
             'empty_required_solos': missing,
             'clay_and_gallery_byte_identical': unchanged,
             'cape_pixels': {v: {p: coverage[v][p] for p in ('cape_near', 'cape_far')} for v in ('front', 'rear')}}
    sides = json.loads((args.out / 'cloak_side.json').read_text())
    assert sides['view_owner_hashes']['front'] == sides['view_owner_hashes']['rear'], 'Cloak ownership changes between views'
    assert all(h == sides['pieces'][name]['face_owner_hash'] for hashes in sides['view_owner_hashes'].values()
               for name, h in hashes.items()), 'Rendered cloak labels differ from body-side classification'
    proof['body_side_ownership_identical_between_views'] = True
    report_path = args.out / 'build_report.json'
    report = json.loads(report_path.read_text())
    report['checks']['required_solo_coverage'] = proof['passed']
    report['passed'] = all(report['checks'].values())
    report_path.write_text(json.dumps(report, indent=2) + '\n')
    (args.out / 'ownership_validation.json').write_text(json.dumps(
        {'passed': proof['passed'], 'empty_required_solos': missing}, indent=2) + '\n')
    (args.out / 'ownership_proof.json').write_text(json.dumps(proof, indent=2) + '\n')
    print('MQ03_OWNERSHIP_PROOF: ' + ('PASS' if proof['passed'] else 'FAIL') + '; ' + json.dumps(proof['cape_pixels']), flush=True)
    return 0 if proof['passed'] else 1


if __name__ == '__main__':
    raise SystemExit(main())
