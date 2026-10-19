"""Explicit batch-C bridge jobs, acceptance, clean replay and compact curation.

No commit/publication action and no Blender process is launched here. The
director-owned bridge is the sole native execution path.
"""
import argparse
import json
from pathlib import Path
import shutil
import subprocess
import sys

from spec.art_identity.maquettes.blender.bridge_client import run_job
from spec.art_identity.maquettes.blender.compile_recipe import compile_recipe
from spec.art_identity.maquettes.blender.compact_capture import compact_capture
from spec.art_identity.maquettes.blender.curate_delivery import (
    stage, inventory, discard_evidence, verify, write)
from spec.art_identity.maquettes.blender.delivery_validation import seal_delivery, validate_delivery
from .batch_proof import FIGURES, ROOT, inspect, review_sheet
from .acceptance import seal as seal_acceptance, validate as validate_acceptance
from .shape_proof import finish as measure_shape


WORKFLOW_DEFAULTS = {'timeout_s': 900, 'proof_subdir': 'proof/final'}


def native_job(folder, name, script, values):
    output = folder / 'proof/bridge'
    output.mkdir(parents=True, exist_ok=True)
    result = run_job(ROOT / 'blender' / script, [str(v) for v in values],
                     timeout_s=WORKFLOW_DEFAULTS['timeout_s'])
    write(output / (name + '.json'), {k: v for k, v in result.items() if k != 'stdout'})
    (output / (name + '.log')).write_text(result['stdout'])
    print('MQ09_BRIDGE: ' + folder.name + '/' + name + '; exit=' + str(result['exit']), flush=True)
    if result['exit'] or result.get('refused'):
        raise ValueError('Native stage failed: ' + str(output / (name + '.log')))


def build(folder, proof_subdir):
    recipe = json.loads((folder / 'measurements.json').read_text())
    spec = compile_recipe(recipe)
    spec_path = folder / 'spec_native.json'
    write(spec_path, spec)
    capture = folder / proof_subdir
    if capture.exists() and any(capture.iterdir()):
        raise ValueError('Native capture requires an empty directory: ' + str(capture))
    native_job(folder, 'capture', 'build.py', [spec_path, capture])
    proof = capture / 'determinism'
    native_job(folder, 'cold_cache_replay', 'recipe_proof.py', [spec_path, proof])
    native_job(folder, 'exact_replay', 'exact_native_replay.py', [proof, proof / 'exact_native_replay.json'])
    job = folder / 'proof/native_validation_job.json'
    write(job, [{'spec': str(spec_path), 'build': str(capture)}])
    native_job(folder, 'material_mutation', 'native_delivery_checks.py', [job, folder / 'proof/native_validation.json'])
    if folder.name == 'slag_mortar':
        native_job(folder, 'head_occlusion', folder / 'occlusion_probe.py',
                   [spec_path, capture, folder / 'proof/head_occlusion.json'])
    compact_capture(spec, capture)
    shape = None
    if folder.name != 'hollow_mimic':
        native_job(folder, 'shape_measurements', ROOT / 'hollow_mimic/native_shape_probe.py',
                   [spec_path, capture, folder / 'proof/native_shape.json'])
        shape = json.loads((folder / 'proof/native_shape.json').read_text())
    measure_shape(folder, spec, capture, shape)
    fit = inspect(folder, capture)
    if not fit['passed']:
        raise ValueError('Fit, coverage or true-turn gate failed: ' + folder.name)
    seal_delivery(spec, capture)
    validate_delivery(spec, capture)
    stage(folder, capture)
    output = folder / 'delivery/validation'
    output.mkdir(exist_ok=True)
    shutil.copyfile(folder / 'proof/native_validation.json', output / 'native_validation.json')
    shutil.copyfile(capture / 'shape_measurements.json', output / 'shape_measurements.json')
    if folder.name == 'slag_mortar':
        shutil.copyfile(folder / 'proof/head_occlusion.json', output / 'head_occlusion.json')
    shutil.copytree(folder / 'proof/bridge', output / 'bridge', dirs_exist_ok=True)
    return spec


def regenerate(folder, subdir='proof/regeneration'):
    output = folder / subdir
    command = [sys.executable, '-B', '-m', 'spec.art_identity.maquettes.blender.regenerate_delivery',
               str(folder), '--out', str(output), '--verify', '--discard-build']
    subprocess.run(command, check=True)
    shutil.copytree(output, folder / 'delivery/validation/regeneration', dirs_exist_ok=True)
    seal_acceptance(folder)


def curate(folder):
    """mq-04 inventory/budget gate, preserving the owned batch proof entrypoints."""
    archive, manifest = folder / 'discarded_proof_sha256.json', folder / 'COMMIT_MANIFEST.txt'
    keep = {p for p in inventory(folder) if p.is_relative_to(folder / 'delivery')}
    keep |= set(folder.glob('*.py'))
    keep |= {folder / name for name in ('measurements.json', 'README.md', '.gdignore')}
    keep |= {archive, manifest}
    spec = compile_recipe(json.loads((folder / 'measurements.json').read_text()))
    validate_delivery(spec, folder / 'delivery')
    validate_acceptance(folder)
    # Never cull a failed or unproved delivery to make it look finished.
    report = json.loads((folder / 'delivery/fit_report.json').read_text())
    regeneration = json.loads((folder / 'delivery/validation/regeneration/regeneration.json').read_text())
    if not report['passed'] or not regeneration['passed']:
        raise ValueError('Curation requires passing acceptance and clean regeneration')
    discard_evidence(folder, [p for p in inventory(folder) if p not in keep], archive)
    manifest.write_text('# Paths relative to this figure; shared native builder: ../blender/*.py\n' +
                        '\n'.join(sorted(str(p.relative_to(folder)) for p in keep)) + '\n')
    for path in sorted(folder.rglob('*'), key=lambda p: len(p.parts), reverse=True):
        if path.is_dir() and not any(path.iterdir()):
            path.rmdir()
    return verify(folder)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('stage', choices=('build', 'regenerate', 'curate', 'verify', 'sheet'))
    parser.add_argument('figures', nargs='*', metavar='FIGURE')
    parser.add_argument('--proof-subdir', default=WORKFLOW_DEFAULTS['proof_subdir'])
    parser.add_argument('--regeneration-subdir', default='proof/regeneration')
    args = parser.parse_args()
    names = args.figures or FIGURES
    if len(set(names)) != len(names) or not set(names) <= set(FIGURES):
        parser.error('Use distinct figure names from: ' + ', '.join(FIGURES))
    for name in names:
        folder = ROOT / name
        if args.stage == 'build':
            build(folder, args.proof_subdir)
        elif args.stage == 'regenerate':
            regenerate(folder, args.regeneration_subdir)
        elif args.stage == 'curate':
            curate(folder)
        elif args.stage == 'verify':
            recipe = json.loads((folder / 'measurements.json').read_text())
            report = json.loads((folder / 'delivery/fit_report.json').read_text())
            if report != inspect(folder, folder / 'delivery') or not report['passed']:
                raise ValueError('Stale or failed acceptance report: ' + name)
            validate_delivery(compile_recipe(recipe), folder / 'delivery')
            validate_acceptance(folder)
            verify(folder)
            print('MQ09_ACCEPTANCE: PASS; ' + name + '; fit_pose_turn_native_regeneration_hash_bound=true')
    if args.stage == 'sheet':
        review_sheet({n: ROOT / n / 'delivery' for n in FIGURES}, ROOT / 'hollow_mimic/delivery/review')
    return 0


if __name__ == '__main__':
    try:
        raise SystemExit(main())
    except (ValueError, TimeoutError, OSError, subprocess.CalledProcessError) as error:
        print('MQ09_WORKFLOW_ERROR: ' + str(error), file=sys.stderr)
        raise SystemExit(2)
