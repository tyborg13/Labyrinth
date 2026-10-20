"""mq-11 director commands. All native jobs use the existing serial bridge.

No staging, Git writes, review, publication, artwork generation or windowed
Godot session is performed. Incomplete owner data fails before any submission.
"""
import argparse
import json
from pathlib import Path
import re
import sys

from spec.art_identity.maquettes.blender.bridge_client import run_job
from spec.art_identity.maquettes.blender.contract import digest
from spec.art_identity.maquettes.blender.curate_delivery import sha, write
from spec.art_identity.maquettes.blender.delivery_validation import seal_delivery, validate_delivery
from .candidate import ROOT, FIGURES, compile_candidate, folder
from .preservation import HERE, PROJECT, check, status
from .proof import inspect, sheet

WORKFLOW_DEFAULTS = {'timeout_s': 900, 'run_id': 'owner_01'}


def output_folder(name, run_id):
    if not re.fullmatch(r'[a-zA-Z0-9_-]+', run_id):
        raise ValueError('Use a plain task-local proof run id')
    folder(name)  # Validate the owned figure before constructing any path.
    return PROJECT / 'tests/mq11_proof' / run_id / name


def inputs():
    paths = list((ROOT / 'blender').rglob('*.py'))
    paths += list(HERE.glob('*.py'))
    paths += [ROOT / n / 'measurements.json' for n in FIGURES]
    paths += [ROOT / n / 'owner_review/design.json' for n in FIGURES]
    paths += [HERE / 'baseline.json']
    return {str(p.relative_to(PROJECT)): sha(p) for p in sorted(paths)}


def prepare(run_id):
    check()
    # Compile every figure before creating directories, writing specs or
    # calling the bridge. A half-filled design never starts a partial batch.
    specs = {name: compile_candidate(name) for name in FIGURES}
    destinations = {name: output_folder(name, run_id) for name in FIGURES}
    if any(path.exists() and any(path.iterdir()) for path in destinations.values()):
        raise ValueError('Use fresh empty mq-11 proof directories')
    for name, path in destinations.items():
        path.mkdir(parents=True, exist_ok=True)
        write(path / 'spec_native.json', specs[name])
        write(path / 'input_sha256.json', inputs())
    return destinations


def native_job(output, name, script, args, allow_gate_failure=False):
    result = run_job(script, [str(a) for a in args], timeout_s=WORKFLOW_DEFAULTS['timeout_s'])
    logs = output / 'bridge'
    logs.mkdir(exist_ok=True)
    write(logs / (name + '.json'), {k: v for k, v in result.items() if k != 'stdout'})
    (logs / (name + '.log')).write_text(result['stdout'])
    print('MQ11_BRIDGE: ' + name + '; exit=' + str(result['exit']), flush=True)
    if result.get('refused') or (result['exit'] != 0 and not (allow_gate_failure and result['exit'] == 1)):
        raise ValueError('Native proof failed; inspect ' + str(logs / (name + '.log')))


def build(run_id):
    outputs = prepare(run_id)
    builder = ROOT / 'blender'
    for name, output in outputs.items():
        path, capture = output / 'spec_native.json', output / 'capture'
        spec = json.loads(path.read_text())
        native_job(output, 'capture', builder / 'build.py', [path, capture])
        native_job(output, 'cold_cache_independent', builder / 'recipe_proof.py', [path, capture / 'determinism'])
        native_job(output, 'exact_replay', builder / 'exact_native_replay.py',
                   [capture / 'determinism', capture / 'determinism/exact_native_replay.json'])
        job = output / 'native_validation_job.json'
        write(job, [{'spec': str(path), 'build': str(capture)}])
        native_job(output, 'ownership_mutation', builder / 'native_delivery_checks.py',
                   [job, capture / 'mq11_native_validation.json'])
        native_job(output, 'accessory_measurements', HERE / 'native_probe.py',
                   [path, capture, capture / 'mq11_shape.json'], allow_gate_failure=True)
        fit = inspect(spec, capture)
        # Keep the native comparison sheets even when a numerical gate fails.
        sheet(spec, capture, output / 'review')
        if not fit['passed']:
            raise ValueError('mq-11 fit/turn/accessory/preservation gate failed: ' + name)
        seal_delivery(spec, capture)
        validate_delivery(spec, capture)
        receipt = {'passed': True, 'spec_hash': digest(spec), 'inputs_sha256': inputs(),
                   'files_sha256': {str(p.relative_to(output)): sha(p) for p in sorted(output.rglob('*'))
                                    if p.is_file() and p.suffix in ('.json', '.png', '.log')},
                   'production_deliveries_preserved': check()}
        write(output / 'acceptance.json', receipt)
    verify(run_id)


def verify(run_id):
    check()
    for name in FIGURES:
        spec = compile_candidate(name)
        output = output_folder(name, run_id)
        receipt = json.loads((output / 'acceptance.json').read_text())
        if receipt.get('passed') is not True or receipt['spec_hash'] != digest(spec) or receipt['inputs_sha256'] != inputs():
            raise ValueError('Missing, failed or stale mq-11 acceptance: ' + name)
        for relative, expected in receipt['files_sha256'].items():
            path = (output / relative).resolve()
            if not path.is_relative_to(output.resolve()) or sha(path) != expected:
                raise ValueError('Changed proof artifact: ' + relative)
        validate_delivery(spec, output / 'capture')
        if not inspect(spec, output / 'capture')['passed']:
            raise ValueError('Recomputed mq-11 acceptance failed: ' + name)
    print('MQ11_ACCEPTANCE: PASS; figures=2; native_fit_shape_turn_collision_ownership_determinism_bound=true')


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('stage', choices=('status', 'prepare', 'build', 'verify'))
    parser.add_argument('--run-id', default=WORKFLOW_DEFAULTS['run_id'])
    args = parser.parse_args(argv)
    if args.stage == 'status':
        print(json.dumps(status(), indent=2))
    elif args.stage == 'prepare':
        prepare(args.run_id)
    elif args.stage == 'build':
        build(args.run_id)
    else:
        verify(args.run_id)
    return 0


if __name__ == '__main__':
    try:
        raise SystemExit(main())
    except (ValueError, OSError, KeyError, TimeoutError) as error:
        print('MQ11_WORKFLOW_ERROR: ' + str(error), file=sys.stderr)
        raise SystemExit(2)
