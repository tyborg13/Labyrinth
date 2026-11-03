"""mq-14 serial bridge workflow; publication and peer review belong to the owner."""
import argparse
import json
from pathlib import Path
import shutil
import subprocess
import sys

from spec.art_identity.maquettes.blender.contract import BUILD_DEFAULTS, digest
from spec.art_identity.maquettes.blender.curate_delivery import sha, write
from spec.art_identity.maquettes.blender.regenerate_delivery import compare_captures
from spec.art_identity.maquettes.gale_herald.shoulder_workflow import job
from .recipe import FIGURE, compile_spec

PROJECT = FIGURE.parents[3]
BUILDER = FIGURE.parent / 'blender'
WORKFLOW_DEFAULTS = {'root': '/private/tmp/labyrinth_codex/mq-14/final_delivery', 'timeout_s': 110, 'solo_batch_size': 11}


def capture(spec_path, build, output, resume=False, preview=False):
    from spec.art_identity.maquettes.gale_herald import shoulder_workflow as shared
    prior = shared.WORKFLOW_DEFAULTS['solo_batch_size']
    try:
        shared.WORKFLOW_DEFAULTS['solo_batch_size'] = WORKFLOW_DEFAULTS['solo_batch_size']
        return shared.capture(spec_path, build, output, resume, preview)
    finally:
        shared.WORKFLOW_DEFAULTS['solo_batch_size'] = prior


def specification(root):
    spec = compile_spec()
    path = root / 'spec_native.json'
    write(path, spec)
    return spec, path


def native_build(root, spec_path, resume):
    for name in ('cold', 'replay', 'independent_cold'):
        cache = root / ('independent_cache' if name == 'independent_cold' else 'shared_cache')
        job(BUILDER / 'build.py', [spec_path, root / name, '--build-only', '--cache', cache],
            root / 'bridge' / (name + '.json'), resume, diagnostic=True)
    job(BUILDER / 'exact_native_replay.py', [root, root / 'exact_native_replay.json'],
        root / 'bridge/exact_native_replay.json', resume)
    job(FIGURE / 'mq14/native_audit.py', [spec_path, root / 'cold', root / 'native_audit.json'],
        root / 'bridge/native_audit.json', resume, diagnostic=True)
    reports = [json.loads((root / name / 'build_report.json').read_text()) for name in ('cold', 'replay', 'independent_cold')]
    passed = all(r['passed'] for r in reports) and json.loads((root / 'native_audit.json').read_text())['passed']
    print('MQ14_BUILDS: ' + ('PASS' if passed else 'FAIL'), flush=True)
    return passed


def native_capture(root, spec, spec_path, resume):
    output = capture(spec_path, root / 'cold', root / 'capture', resume)
    reports = {name: json.loads((root / name / 'build_report.json').read_text())
               for name in ('cold', 'replay', 'independent_cold')}
    observed = json.loads((output / 'native_observations.json').read_text())
    hashes = {name: r['combined_mesh_hash'] for name, r in reports.items()}
    same = len(set(hashes.values())) == 1
    checks = {'fresh_and_replay_raw_hashes': same, 'joint_endpoints': max(observed['joint_errors_m'].values()) <= 1e-4,
              'native_geometry': all(r['passed'] for r in reports.values())}
    write(output / 'recipe_proof.json', {'passed': all(checks.values()), 'checks': checks,
        'spec_hash': digest(spec), 'cache_revision': BUILD_DEFAULTS['cache_revision'],
        'raw_hashes_identical': same, 'mesh_count': len(reports['cold']['mesh_hashes']),
        'joint_errors': observed['joint_errors_m'], 'combined_mesh_hashes': hashes})
    shutil.copyfile(root / 'exact_native_replay.json', output / 'exact_native_replay.json')
    print('MQ14_CAPTURE: ' + ('PASS' if all(checks.values()) else 'FAIL'), flush=True)
    return all(checks.values())


def regenerate(root, spec, resume):
    output = root / 'regeneration'
    clean = output / 'clean_project'
    inventory = output / 'clean_input_sha256.json'
    if not inventory.exists():
        if clean.exists():
            raise ValueError('Uninventoried clean input directory already exists')
        source = FIGURE.parent
        for path in sorted(source.rglob('*.py')):
            if any(p in ('__pycache__', 'proof') for p in path.relative_to(source).parts):
                continue
            target = clean / path.relative_to(PROJECT)
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(path, target)
        for path in (FIGURE / 'spec_r3.json', FIGURE / 'mq14/measurements.json'):
            target = clean / path.relative_to(PROJECT)
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(path, target)
        write(inventory, {str(p.relative_to(clean)): sha(p) for p in sorted(clean.rglob('*')) if p.is_file()})
    inputs = json.loads(inventory.read_text())
    for relative, expected in inputs.items():
        if sha(clean / relative) != expected or sha(PROJECT / relative) != expected:
            raise ValueError('Fresh input changed after inventory: ' + relative)
    new_spec = output / 'build/spec_native.json'
    new_spec.parent.mkdir(parents=True, exist_ok=True)
    # Compile with the same host numerical runtime as the canonical recipe.
    # Blender imports only the copied native builder and needs no Pillow.
    code = ('import sys,json; from pathlib import Path; sys.path.insert(0,sys.argv[1]); '
            'from spec.art_identity.maquettes.frostglass_lancer.mq14.recipe import compile_spec; '
            'Path(sys.argv[2]).write_text(json.dumps(compile_spec(),indent=2)+"\\n")')
    subprocess.run([sys.executable, '-B', '-c', code, str(clean), str(new_spec)], cwd=clean, check=True)
    if digest(json.loads(new_spec.read_text())) != digest(spec):
        raise ValueError('Fresh source compilation differs')
    job(FIGURE / 'mq14/regenerate_entry.py', [clean, output / 'build'], output / 'build.json', resume)
    capture(new_spec, output / 'build', output / 'capture', resume, preview=True)
    views = compare_captures(output / 'capture', root / 'capture', output)
    raster = all(row['passed'] for view in views.values() for row in view.values())
    built = json.loads((output / 'build/build_report.json').read_text())
    old = json.loads((root / 'cold/build_report.json').read_text())
    geometry = built['combined_mesh_hash'] == old['combined_mesh_hash']
    report = {'passed': raster and geometry and built['passed'], 'spec_hash': digest(spec),
        'views': views, 'raster_matches': raster, 'geometry_matches': geometry,
        'cache_reused': False, 'input_inventory_sha256': sha(inventory)}
    write(output / 'regeneration.json', report)
    print('MQ14_REGENERATION: ' + ('PASS' if report['passed'] else 'FAIL') +
          '; raster_matches=' + str(raster) + '; geometry_matches=' + str(geometry), flush=True)
    return report['passed']


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('operation', choices=('build', 'capture', 'regenerate', 'proof', 'curate', 'verify'))
    parser.add_argument('--out', type=Path, default=Path(WORKFLOW_DEFAULTS['root']))
    parser.add_argument('--resume', action='store_true')
    args = parser.parse_args()
    root = args.out.resolve()
    if not root.is_relative_to(Path('/private/tmp/labyrinth_codex/mq-14')):
        raise ValueError('mq-14 proof outputs must stay in the task temp tree')
    if args.operation == 'verify':
        from .curation import verify
        verify()
        return 0
    spec, spec_path = specification(root)
    if args.operation == 'build':
        passed = native_build(root, spec_path, args.resume)
    elif args.operation == 'capture':
        passed = native_capture(root, spec, spec_path, args.resume)
    elif args.operation == 'regenerate':
        passed = regenerate(root, spec, args.resume)
    elif args.operation == 'proof':
        from .proof import proof
        passed = proof(root, spec)['passed']
    else:
        from .curation import curate
        curate(root, spec)
        passed = True
    return 0 if passed else 1


if __name__ == '__main__':
    raise SystemExit(main())
