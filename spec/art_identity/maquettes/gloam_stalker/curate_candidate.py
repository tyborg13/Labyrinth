"""Retain accepted mq-13 proof and hash generated intermediates before removal."""
import gzip
import json
from pathlib import Path
import shutil

from spec.art_identity.maquettes.blender.compile_recipe import compile_recipe
from spec.art_identity.maquettes.blender.contract import digest
from spec.art_identity.maquettes.blender.curate_delivery import sha, verify, write
from spec.art_identity.maquettes.blender.delivery_validation import validate_delivery
from .promote import verify_approved
from .workflow import FIGURE, PROJECT, EVIDENCE


def main():
    root = FIGURE / 'proof/mq13'
    validation = EVIDENCE / 'validation'
    destination = validation / 'native'
    destination.mkdir(exist_ok=True)
    for name in ('build_report.json',):
        shutil.copyfile(root / 'cold' / name, destination / name)
    for build in ('replay', 'independent_cold'):
        shutil.copyfile(root / build / 'build_report.json', destination / (build + '_build_report.json'))
    for name in ('joints_px.json', 'capture_checks.json', 'facing_report.json', 'ownership_validation.json',
                 'solo_coverage.json', 'cloak_side.json', 'recipe_proof.json', 'exact_native_replay.json',
                 'capture_manifest.json', 'articulated_pose_checks.json'):
        shutil.copyfile(root / 'capture' / name, destination / name)
    for name in ('native_render_manifest.json', 'capture_packing.json'):
        shutil.copyfile(root / 'capture' / name, destination / name)
    for path in sorted((root / 'bridge').glob('*')):
        if path.suffix in ('.json', '.log'):
            target = validation / 'bridge' / path.name
            target.parent.mkdir(exist_ok=True)
            shutil.copyfile(path, target)
    for path in sorted((root / 'capture_jobs').glob('*')):
        if path.suffix in ('.json', '.log'):
            target = validation / 'bridge/capture' / path.name
            target.parent.mkdir(exist_ok=True)
            shutil.copyfile(path, target)
    for path in sorted((root / 'capture_jobs').glob('*/batch_checks.json')):
        target = destination / 'batches' / (path.parent.name + '.json')
        target.parent.mkdir(exist_ok=True)
        shutil.copyfile(path, target)
    for path in sorted((root / 'regeneration').rglob('clean_input_sha256.json')):
        if sha(path) != json.loads((validation / 'regeneration.json').read_text())['input_inventory_sha256']:
            continue
        for name in ('clean_input_sha256.json', 'input_state.json', 'build.json', 'build.log'):
            shutil.copyfile(path.parent / name, validation / ('regeneration_' + name))
        for receipt in sorted((path.parent / 'capture_jobs').glob('*')):
            if receipt.suffix in ('.json', '.log'):
                target = validation / 'bridge/regeneration' / receipt.name
                target.parent.mkdir(exist_ok=True)
                shutil.copyfile(receipt, target)

    scope_path = validation / 'scope_before.json'
    scope = json.loads(scope_path.read_text())
    actual = {name: digest(compile_recipe(json.loads((FIGURE.parent / name / 'measurements.json').read_text())))
              for name in scope['compiled_specs']}
    passed = actual == scope['compiled_specs'] and all(sha(PROJECT / p) == h for p, h in scope['files_sha256'].items())
    if not passed:
        raise ValueError('Other figure scope changed')
    write(validation / 'scope_after.json', {'passed': passed, 'compiled_specs': actual,
        'files_checked': len(scope['files_sha256']), 'scope_before_sha256': sha(scope_path)})
    spec = compile_recipe(json.loads((FIGURE / 'measurements.json').read_text()))
    validate_delivery(spec, FIGURE / 'delivery')
    verify_approved(spec, FIGURE / 'delivery')
    canonical = json.loads((validation / 'promoted_delivery.json').read_text())
    if (sha(FIGURE / 'measurements.json') != sha(FIGURE / 'r3/measurements.json') or
            any(sha(FIGURE / 'delivery' / p) != h for p, h in canonical['files'].items())):
        raise ValueError('Canonical delivery differs from the promoted r3 receipt')

    # Receipt is durable and round-trip verified before deleting any generated
    # blend, source-cache, duplicate capture or input-only snapshot.
    inventory = [[str(p.relative_to(PROJECT)), p.stat().st_size, sha(p)]
                 for p in sorted(root.rglob('*')) if p.is_file()]
    archive = validation / 'discarded_generated_sha256.json.gz'
    prior = json.loads(gzip.decompress(archive.read_bytes())) if archive.exists() else {'files': []}
    payload = {'schema': 1, 'columns': ['path', 'bytes', 'sha256'], 'files': prior['files'] + inventory}
    archive.write_bytes(gzip.compress(json.dumps(payload, separators=(',', ':')).encode(), mtime=0))
    if json.loads(gzip.decompress(archive.read_bytes())) != payload:
        raise ValueError('Generated evidence inventory failed round-trip verification')
    shutil.rmtree(root)
    if not any(root.parent.iterdir()):
        root.parent.rmdir()
    manifest = FIGURE / 'COMMIT_MANIFEST.txt'
    manifest.write_text('# Paths relative to this figure. Director-accepted mq-13 r3 is canonical.\n'
        '# Native mq-13 fixtures: tests/mq13_validation/COMMIT_MANIFEST.txt at project root.\n' +
        '\n'.join(sorted(str(p.relative_to(FIGURE)) for p in FIGURE.rglob('*') if p.is_file())) + '\n')
    result = verify(FIGURE)
    proof_manifest = EVIDENCE / 'COMMIT_MANIFEST.txt'
    proof_manifest.write_text('# Paths relative to tests/mq13_validation. Accepted native proof; implementation remains uncommitted.\n' +
        '\n'.join(sorted({'COMMIT_MANIFEST.txt', 'validation/curation.json'} |
                         {str(p.relative_to(EVIDENCE)) for p in EVIDENCE.rglob('*') if p.is_file()})) + '\n')
    write(validation / 'curation.json', {'passed': True, 'figure': result,
        'generated_files_archived': len(payload['files']), 'candidate_promoted': True})
    proof_bytes = sum(p.stat().st_size for p in EVIDENCE.rglob('*') if p.is_file())
    print('MQ13_CURATION: PASS; figure_bytes=' + str(result['bytes']) + '; proof_bytes=' + str(proof_bytes))


if __name__ == '__main__':
    main()
