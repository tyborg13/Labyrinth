"""mq-13 bounded bridge jobs, native proof and clean regeneration.

Never promotes a failed candidate or changes another figure. Every native job
has a hard 120-second client limit; the director owns Blender execution.
"""
import argparse
from functools import partial
import json
from pathlib import Path
import shutil
import subprocess
import sys

from spec.art_identity.maquettes.blender.compile_recipe import compile_recipe
from spec.art_identity.maquettes.blender.contract import digest
from spec.art_identity.maquettes.blender.curate_delivery import sha, write
from spec.art_identity.maquettes.blender.regenerate_delivery import compare_captures
from spec.art_identity.maquettes.gale_herald import shoulder_workflow
from spec.art_identity.maquettes.glacial_mirror.regeneration_inputs import clean_inputs, input_builder

FIGURE = Path(__file__).resolve().parent
BUILDER = FIGURE.parent / 'blender'
PROJECT = FIGURE.parents[3]
EVIDENCE = PROJECT / 'tests/mq13_validation'
DEFAULTS = {'job_timeout_s': 110, 'answer_timeout_s': 120}


def job(script, args, receipt, resume=False, diagnostic=False, saved_builds=()):
    receipt = Path(receipt)
    command = [sys.executable, '-B', str(BUILDER / 'bridge_client.py'), '--timeout', str(DEFAULTS['job_timeout_s']),
               str(Path(script).resolve()), '--', *[str(a.resolve()) if isinstance(a, Path) else str(a) for a in args]]
    revision = digest({p.name: sha(p) for p in sorted(BUILDER.glob('*.py'))})
    inputs = {str(p): sha(p) for p in (Path(script), Path(args[0])) if p.is_file()}
    body_inputs = {str(Path(folder) / name): sha(Path(folder) / name)
                   for folder in saved_builds for name in ('maquette.blend', 'build_report.json')}
    inputs.update(body_inputs)
    if body_inputs:
        helper = FIGURE / 'saved_body.py'
        inputs[str(helper)] = sha(helper)
    if resume and receipt.exists():
        prior = json.loads(receipt.read_text())
        if body_inputs and any(prior.get('inputs', {}).get(p) != value for p, value in body_inputs.items()):
            raise ValueError('Saved-body resume inputs changed; a fresh bridge receipt is required')
        if prior.get('command') == command and prior.get('builder_revision') == revision and prior.get('inputs') == inputs and prior.get('exit') == 0:
            return prior
    receipt.parent.mkdir(parents=True, exist_ok=True)
    try:
        result = subprocess.run(command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                                timeout=DEFAULTS['answer_timeout_s'], text=True)
    except subprocess.TimeoutExpired as error:
        receipt.with_suffix('.log').write_text(str(error.stdout))
        raise TimeoutError('Director bridge gave no answer in 120 s; stop mq-13') from error
    receipt.with_suffix('.log').write_text(result.stdout)
    value = {'exit': result.returncode, 'command': command, 'builder_revision': revision, 'inputs': inputs}
    write(receipt, value)
    print('MQ13_BRIDGE: ' + receipt.stem + '; exit=' + str(result.returncode), flush=True)
    if result.returncode not in ((0, 1) if diagnostic else (0,)):
        raise ValueError('Bridge job failed; see ' + str(receipt.with_suffix('.log')))
    return value


def capture(spec, build, output, resume=False, preview=False):
    # Reuse the tested mq-12 bounded capture/merge without its longer queue wait.
    previous_job, previous_probe = shoulder_workflow.job, shoulder_workflow.PROBE
    shoulder_workflow.job = partial(job, saved_builds=(build,))
    shoulder_workflow.PROBE = FIGURE / 'capture_probe.py'
    try:
        result = shoulder_workflow.capture(spec, build, output, resume, preview)
    finally:
        shoulder_workflow.job, shoulder_workflow.PROBE = previous_job, previous_probe
    report = json.loads((build / 'build_report.json').read_text())
    batches = [json.loads(p.read_text()) for p in (output.parent / (output.name + '_jobs')).glob('*/batch_checks.json')]
    require_consistent_batches(report['spec_hash'], report['combined_mesh_hash'], batches)
    return result


def require_consistent_batches(spec_hash, mesh_hash, batches):
    if not batches or any(b.get('spec_hash') != spec_hash or b.get('native_mesh_hash') != mesh_hash or
                          b.get('geometry_unchanged') is not True for b in batches):
        raise ValueError('Capture batches do not belong to one unchanged saved geometry')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('operation', choices=('build', 'capture', 'observe', 'regenerate', 'proof', 'verify-candidate', 'promote'))
    parser.add_argument('--resume', action='store_true')
    args = parser.parse_args()
    root = FIGURE / 'proof/mq13'
    recipe_path = FIGURE / 'r3/measurements.json'
    spec = compile_recipe(json.loads(recipe_path.read_text()))
    spec_path = root / 'spec_native.json'
    write(spec_path, spec)
    if args.operation == 'build':
        for name in ('cold', 'replay', 'independent_cold'):
            cache = root / ('independent_cache' if name == 'independent_cold' else 'shared_cache')
            job(BUILDER / 'build.py', [spec_path, root / name, '--build-only', '--cache', cache],
                root / 'bridge' / (name + '.json'), args.resume, diagnostic=True)
        job(BUILDER / 'exact_native_replay.py', [root, root / 'exact_native_replay.json'],
            root / 'bridge/exact_native_replay.json', args.resume,
            saved_builds=tuple(root / name for name in ('cold', 'replay', 'independent_cold')))
        return 0 if all(json.loads((root / n / 'build_report.json').read_text())['passed']
                        for n in ('cold', 'replay', 'independent_cold')) else 1
    elif args.operation == 'capture':
        target = capture(spec_path, root / 'cold', root / 'capture', args.resume)
        builds = {name: json.loads((root / name / 'build_report.json').read_text()) for name in ('cold', 'replay', 'independent_cold')}
        hashes = {name: r['combined_mesh_hash'] for name, r in builds.items()}
        observations = json.loads((target / 'native_observations.json').read_text())
        checks = {'fresh_and_replay_raw_hashes': len(set(hashes.values())) == 1,
            'joint_endpoints': max(observations['joint_errors_m'].values()) <= 1e-4,
            'native_geometry': all(r['passed'] for r in builds.values())}
        write(target / 'recipe_proof.json', {'passed': all(checks.values()), 'checks': checks,
            'spec_hash': digest(spec), 'raw_hashes_identical': len(set(hashes.values())) == 1,
            'mesh_count': len(builds['cold']['mesh_hashes']), 'joint_errors': observations['joint_errors_m'],
            'combined_mesh_hashes': hashes})
        shutil.copyfile(root / 'exact_native_replay.json', target / 'exact_native_replay.json')
        return 0 if all(checks.values()) else 1
    elif args.operation == 'observe':
        job(FIGURE / 'native_probe.py', [spec_path, root / 'cold', EVIDENCE / 'review/native_observations.json'],
            root / 'bridge/native_observations.json', args.resume, saved_builds=(root / 'cold',))
    elif args.operation == 'regenerate':
        revision = digest({p.name: sha(p) for p in sorted(BUILDER.glob('*.py'))})
        target = root / 'regeneration' / revision[:12]
        fresh = clean_inputs(target, FIGURE, recipe_path, resume=args.resume)
        job(input_builder(fresh), [fresh, target / 'build', '--build-only'], target / 'build.json', args.resume, diagnostic=True)
        new = capture(fresh, target / 'build', target / 'capture', args.resume, preview=True)
        clean_inputs(target, FIGURE, recipe_path, resume=True)
        views = compare_captures(new, root / 'capture', target)
        raster = all(r['passed'] for v in views.values() for r in v.values())
        built = json.loads((target / 'build/build_report.json').read_text())
        original = json.loads((root / 'cold/build_report.json').read_text())
        geometry = built['combined_mesh_hash'] == original['combined_mesh_hash']
        result = {'passed': raster and geometry and built['passed'], 'raster_matches': raster,
            'geometry_matches': geometry, 'native_geometry_passed': built['passed'], 'views': views,
            'native_mesh_hash': built['combined_mesh_hash'], 'reference_mesh_hash': original['combined_mesh_hash'],
            'capture_manifest_sha256': sha(root / 'capture/capture_manifest.json'), 'builder_revision': revision,
            'compiled_spec_hash': digest(spec), 'input_inventory_sha256': sha(target / 'clean_input_sha256.json'), 'cache_reused': False}
        write(EVIDENCE / 'validation/regeneration.json', result)
        print('MQ13_REGENERATION: ' + ('PASS' if result['passed'] else 'FAIL') +
              '; raster_matches=' + str(raster) + '; geometry_matches=' + str(geometry), flush=True)
        return 0 if result['passed'] else 1
    elif args.operation == 'verify-candidate':
        from spec.art_identity.maquettes.blender.delivery_validation import validate_delivery
        try:
            validate_delivery(spec, root / 'capture', require_binding=False)
            accepted, reason = True, None
        except ValueError as error:
            accepted, reason = False, str(error)
        write(EVIDENCE / 'validation/candidate_delivery.json', {'candidate_accepted': accepted,
            'spec_hash': digest(spec), 'reason': reason,
            'gate_report_sha256': sha(EVIDENCE / 'review/gates.json'),
            'canonical_delivery_replaced': (sha(FIGURE / 'measurements.json') == sha(recipe_path) and
                sha(FIGURE / 'delivery/capture_manifest.json') == sha(root / 'capture/capture_manifest.json'))})
        print('MQ13_CANDIDATE_DELIVERY: ' + ('ACCEPTED' if accepted else 'REJECTED') + '; ' + str(reason))
        return 0 if accepted else 1
    elif args.operation == 'promote':
        from .promote import promote
        promote()
    else:
        from .proof import proof
        return 0 if proof()['passed'] else 1
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
