"""Curate only mq-14 outputs; every pre-existing Lancer byte is protected."""
import json
from pathlib import Path
import shutil

from spec.art_identity.maquettes.blender.compact_capture import compact_capture
from spec.art_identity.maquettes.blender.contract import digest
from spec.art_identity.maquettes.blender.curate_delivery import sha, stage, verify as verify_inventory, write
from spec.art_identity.maquettes.blender.delivery_validation import seal_delivery, validate_delivery
from spec.art_identity.maquettes.blender.delivery_validation import passing
from .recipe import FIGURE, compile_spec

REQUIRED_CHECKS = ('native_geometry_ownership_and_mutation', 'facing', 'shoulder_rule', 'true_180_rotation',
                   'true_turn_feet_and_depth_both_views', 'fit_and_part_coverage', 'exact_native_determinism',
                   'fresh_regeneration', 'hash_bound_native_delivery')
BINDING_REPORTS = ('review/mq14_gates.json', 'fit_report.json', 'review/fit_table.md',
                  'review/per_part_coverage.csv', 'review/contact_sheet.webp', 'review/review_inputs.json',
                  'regeneration.json', 'native_audit.json', 'scope.json', 'clean_input_sha256.json')
FIT_MINIMUMS = {'front': .70, 'rear': .65}
NATIVE_CHECKS = ('current_spec', 'native_geometry', 'both_feet_planted', 'spear_planted', 'spear_at_grip',
                 'native_endpoints', 'material_mutation_caught', 'features_in_required_views')


def validate_acceptance(spec, delivery):
    delivery = Path(delivery)
    validate_delivery(spec, delivery)
    binding = json.loads((delivery/'acceptance_binding.json').read_text())
    gates = json.loads((delivery/'review/mq14_gates.json').read_text())
    fit = json.loads((delivery/'fit_report.json').read_text())
    native = json.loads((delivery/'native_audit.json').read_text())
    regen = json.loads((delivery/'regeneration.json').read_text())
    scope = json.loads((delivery/'scope.json').read_text())
    for name, data in (('gates', gates), ('fit', fit), ('native', native), ('regeneration', regen), ('scope', scope)):
        passing(data, name)
    if gates.get('passed') is not True or any(gates.get('checks', {}).get(k) is not True for k in REQUIRED_CHECKS):
        raise ValueError('Missing or failed mq-14 acceptance check')
    if any(data.get('passed') is not True for data in (fit, native, regen, scope)):
        raise ValueError('Missing or failed mq-14 proof')
    if any(native.get('checks', {}).get(key) is not True for key in NATIVE_CHECKS):
        raise ValueError('Missing or failed mq-14 native check')
    if any(data.get('spec_hash') != digest(spec) for data in (gates, fit, native, regen)):
        raise ValueError('Stale mq-14 spec proof')
    if set(fit.get('views', {})) != set(FIT_MINIMUMS) or any(
            row['iou_min'] != FIT_MINIMUMS[view] or row['iou'] < FIT_MINIMUMS[view] or row['missing_or_clipped_parts']
            for view, row in fit['views'].items()):
        raise ValueError('Failed mq-14 fit or coverage')
    for view, row in fit['views'].items():
        expected = FIGURE.parents[3]/('spec/art_identity/jobs/frostglass_lancer/mq4_'+view+'/processed.png')
        if row['source_sha256'] != sha(expected):
            raise ValueError('Protected mq-14 painting changed')
    manifest = sha(delivery/'capture_manifest.json')
    if binding['spec_hash'] != digest(spec) or binding['capture_manifest_sha256'] != manifest or gates['capture_manifest_sha256'] != manifest:
        raise ValueError('Stale mq-14 capture binding')
    actual = {name: sha(delivery/name) for name in BINDING_REPORTS}
    if binding['reports_sha256'] != actual:
        raise ValueError('Stale mq-14 report binding')
    if binding.get('measurement_input_sha256') != sha(FIGURE/'mq14/measurements.json'):
        raise ValueError('Stale mq-14 measurement input binding')
    if gates['fit_report_sha256'] != sha(delivery/'fit_report.json'):
        raise ValueError('Stale mq-14 fit binding')
    return binding


def verify():
    spec = compile_spec()
    canonical = json.loads((FIGURE/'measurements.json').read_text())
    if canonical != spec:
        raise ValueError('Canonical input differs from source compilation')
    result = verify_inventory(FIGURE)
    validate_acceptance(spec, FIGURE/'delivery')
    print('MQ14_DELIVERY: PASS; bytes='+str(result['bytes'])+'; files='+str(result['files']), flush=True)
    return result


def curate(root, spec):
    from .proof import proof
    from .scope import scope
    capture = root/'capture'
    compact_capture(spec, capture)
    seal_delivery(spec, capture)
    value = proof(root, spec)
    if not value['passed']:
        raise ValueError('Failed candidate cannot replace the canonical delivery')
    scope(root/'scope.json')
    write(FIGURE/'measurements.json', spec)
    for name in ('fit_report.json', 'fit_overlay.png'):
        shutil.copyfile(root/'review'/name, capture/name)
    stage(FIGURE, capture)
    delivery = FIGURE/'delivery'
    shutil.copytree(root/'review', delivery/'review', dirs_exist_ok=True)
    for source, name in ((root/'regeneration/regeneration.json', 'regeneration.json'),
                         (root/'regeneration/clean_input_sha256.json', 'clean_input_sha256.json'),
                         (root/'native_audit.json', 'native_audit.json'), (root/'scope.json', 'scope.json')):
        shutil.copyfile(source, delivery/name)
    binding = {'spec_hash': digest(spec), 'capture_manifest_sha256': sha(delivery/'capture_manifest.json'),
               'reports_sha256': {name: sha(delivery/name) for name in BINDING_REPORTS},
               'measurement_input_sha256': sha(FIGURE/'mq14/measurements.json')}
    write(delivery/'acceptance_binding.json', binding)
    validate_acceptance(spec, delivery)
    # No source/provenance files are removed. Temporary native inputs and
    # candidates are hashed into the task archive before their deletion.
    temporary = Path('/private/tmp/labyrinth_codex/mq-14')
    paths = sorted(p for p in temporary.rglob('*') if p.is_file())
    archive = {'schema': 1, 'root': str(temporary), 'columns': ['path', 'bytes', 'sha256'],
               'files': [[str(p.relative_to(temporary)), p.stat().st_size, sha(p)] for p in paths]}
    write(FIGURE/'discarded_proof_sha256.json', archive)
    generated = FIGURE/'mq14/spec_native.json'
    if generated.exists():
        archive['generated_repository_files'] = [[str(generated.relative_to(FIGURE)), generated.stat().st_size, sha(generated)]]
        write(FIGURE/'discarded_proof_sha256.json', archive)
        generated.unlink()
    # Retain focused test result logs, then remove only task-owned temp proof.
    logs = FIGURE/'mq14/validation'
    logs.mkdir(exist_ok=True)
    for pattern in ('focused*.log', 'mq14_unit*.log', 'mutations.log'):
        for path in temporary.glob(pattern):
            shutil.copyfile(path, logs/path.name)
    if (temporary/'mutations').exists():
        shutil.copytree(temporary/'mutations', logs/'mutations', dirs_exist_ok=True)
    for path in sorted(root.rglob('*')):
        if path.is_file() and path.suffix in ('.log', '.json') and (
                path.parent.name == 'bridge' or path.parent.name.endswith('_jobs') or path.name == 'build.json'):
            target = logs/'bridge'/path.relative_to(root)
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(path, target)
    for path in paths:
        path.unlink()
    for path in sorted(temporary.rglob('*'), key=lambda p: len(p.parts), reverse=True):
        if path.is_dir() and not any(path.iterdir()):
            path.rmdir()
    manifest = FIGURE/'COMMIT_MANIFEST.txt'
    listed = {str(p.relative_to(FIGURE)) for p in FIGURE.rglob('*') if p.is_file()} | {manifest.name}
    manifest.write_text('# mq-14 curated input, native delivery, proof, and untouched painting provenance.\n'+
                        '\n'.join(sorted(listed))+'\n')
    return verify()
