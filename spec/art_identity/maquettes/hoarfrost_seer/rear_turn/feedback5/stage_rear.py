"""Stage the director-accepted rear, without rendering or rewriting the front."""
from copy import deepcopy
import hashlib
import json
from pathlib import Path
import shutil
import sys

from PIL import Image

PROJECT = Path(__file__).resolve().parents[6]
sys.path.insert(0, str(PROJECT))
from spec.art_identity.maquettes.blender.capture_manifest import read_manifest, write_manifest
from spec.art_identity.maquettes.blender.compile_recipe import compile_recipe
from spec.art_identity.maquettes.blender.contract import digest
from spec.art_identity.maquettes.blender.curate_delivery import discard_evidence, sha
from spec.art_identity.maquettes.blender.delivery_validation import seal_delivery, validate_delivery


def load(path):
    return json.loads(path.read_text())


def write(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2, allow_nan=False) + '\n')


def rear_certificate(folder, source, proof, spec):
    folder.mkdir(parents=True, exist_ok=True)
    for name in ('capture_checks.json', 'capture_manifest.json', 'joints_px.json', 'solo_coverage.json',
                 'ownership_validation.json', 'native_capture_manifest.json', 'capture_frame.json', 'cloak_side.json'):
        shutil.copyfile(source / name, folder / name)
    build, capture = load(source / 'build_report.json'), load(source / 'capture_checks.json')
    build['geometry_scope'] = ['rear']
    build['checks']['capture_geometry_unchanged'] = capture['geometry_unchanged']
    build['passed'] = all(build['checks'].values())
    write(folder / 'build_report.json', build)
    for name in ('recipe_proof.json', 'exact_native_replay.json'):
        shutil.copyfile(proof / name, folder / name)
    seal_delivery(spec, folder, views=('rear',), image_folder=source)


def main():
    folder = Path(__file__).resolve().parent
    figure, previous = folder.parents[1], folder.parent / 'feedback4'
    output, source = figure / 'delivery', previous / 'rear'
    base = compile_recipe(load(figure / 'measurements.json'))
    rear_recipe = previous / 'rear_recipe.json'
    rear = compile_recipe(load(rear_recipe))
    frozen = load(previous / 'front_freeze.json')
    policy = load(folder / 'fit_policy.json')
    accepted = load(previous / 'proof_report.json')
    if (output / 'view_sources.json').exists():
        validate_delivery(base, output)
        print('MQ06_REAR_STAGE: PASS; already staged and sealed')
        return
    validate_delivery(base, output)
    manifest = read_manifest(source, digest(rear), ('full',))
    if frozen['files'] != {p.name: sha(p) for p in output.glob('front_*')}:
        raise ValueError('Frozen front changed before staging')
    if accepted['rear_iou_fixed_original'] < policy['iou_min'] or any(
            not value for key, value in accepted['checks'].items() if key != 'rear_iou'):
        raise ValueError('Accepted rear has a failed native, framing, coverage or fixed fit gate')
    certificate = folder / 'staging_certificate'
    rear_certificate(certificate, source, previous, rear)
    # The native source input and all raw cold/replay mesh hashes stay intact.
    # The root's original body certificate now explicitly covers the front.
    metadata = {name: load(output / name) for name in ('build_report.json', 'capture_checks.json',
        'recipe_proof.json', 'solo_coverage.json', 'joints_px.json', 'provenance.json',
        'native_capture_manifest.json', 'cloak_side.json')}
    original_manifest = load(output / 'capture_manifest.json')
    write(folder / 'original_front_native_binding.json', metadata['recipe_proof.json']['delivery_binding'])
    replacing = [output / name for name in manifest['images']]
    replacing += [output / name for name in metadata]
    replacing += [output / name for name in ('capture_manifest.json', 'rear_proportion_report.json',
                                           'fit_overlay.png', 'regeneration.json', 'frozen_geometry.json') if (output / name).exists()]
    discard_evidence(figure, replacing, figure / 'discarded_proof_sha256.json')
    for name in manifest['images']:
        shutil.copyfile(source / name, output / name)
    destination = output / 'rear_native'
    shutil.copytree(certificate, destination)
    for name in ('build_report.json', 'capture_checks.json', 'recipe_proof.json'):
        metadata[name]['geometry_scope'] = ['front']
    metadata['solo_coverage.json']['rear'] = load(source / 'solo_coverage.json')['rear']
    metadata['joints_px.json']['rear'] = load(source / 'joints_px.json')['rear']
    metadata['cloak_side.json']['view_owner_hashes']['rear'] = load(source / 'cloak_side.json')['view_owner_hashes']['rear']
    native = load(source / 'native_capture_manifest.json')
    raw_front = metadata['native_capture_manifest.json']
    raw_front['images'] = {name: entry for name, entry in raw_front['images'].items() if name.startswith('front_')}
    raw_front['geometry_scope'] = ['front']
    raw_front['rear_native_manifest'] = 'rear_native/native_capture_manifest.json'
    raw_front['joint_scope'] = 'Original paired native capture, retained for the frozen front only. Current rear has its own native manifest and single-view joints.'
    provenance = metadata['provenance.json']
    provenance['native_image_sha256'].update({name: entry['sha256'] for name, entry in native['images'].items()})
    provenance['native_clay_rgba_sha256']['rear_clay.png'] = hashlib.sha256(Image.open(source / 'rear_clay.png').convert('RGBA').tobytes()).hexdigest()
    provenance['view_spec_hashes'] = {'front': digest(base), 'rear': digest(rear)}
    provenance['geometry_sources'] = 'Frozen front uses measurements.json; planted rear uses view_sources.json and rear_native/ with its own sealed native proof.'
    for name, value in metadata.items():
        write(output / name, value)
    shutil.copyfile(source / 'capture_frame.json', output / 'capture_frame.json')
    fit = {'schema': 3, 'view': 'rear', 'spec_hash': digest(rear), 'passed': True,
        'authority': policy['authority'], 'registration_method': policy['method'],
        'registration_reason': policy['reason'], 'iou': accepted['rear_iou_fixed_original'],
        'iou_min': policy['iou_min'], 'fixed_original_iou': accepted['rear_iou_fixed_original'],
        'dynamic_iou': accepted['rear_iou_dynamic'], 'before_iou': accepted['rear_iou_before'],
        'source_frame': policy['fixed_source_frame'], 'maquette_frame': accepted['rear_fixed_frame_with_pan'],
        'checks': {**{key: value for key, value in accepted['checks'].items() if key != 'rear_iou'}, 'fixed_original_iou': True},
        'per_part_coverage': accepted['per_part_coverage']}
    write(output / 'rear_proportion_report.json', fit)
    sources = {'schema': 1, 'base_views': ['front'], 'base_spec_hash': digest(base),
        'frozen_front': frozen,
        'overrides': {'rear': {'recipe': str(rear_recipe.relative_to(figure)), 'recipe_sha256': sha(rear_recipe),
            'spec_hash': digest(rear), 'certificate': 'rear_native'}},
        'fit_policy': str((folder / 'fit_policy.json').relative_to(figure)),
        'fit_report': 'rear_proportion_report.json', 'authority': policy['authority']}
    write(output / 'view_sources.json', sources)
    write_manifest(output, digest(base), 'full', original_manifest['images'])
    seal_delivery(base, output)
    if frozen['files'] != {p.name: sha(p) for p in output.glob('front_*')} or frozen['joints'] != load(output / 'joints_px.json')['front']:
        raise ValueError('Staging changed the frozen front')
    hashes = {str(p.relative_to(output)): sha(p) for p in sorted(output.rglob('*')) if p.is_file() and
              (p.name.startswith('rear_') or p.is_relative_to(destination) or p.name in ('capture_frame.json', 'joints_px.json', 'view_sources.json'))}
    write(folder / 'staged_rear_sha256.json', {'algorithm': 'sha256', 'files': hashes,
        'rear_joint_entries_sha256': hashlib.sha256(json.dumps(metadata['joints_px.json']['rear'], sort_keys=True, separators=(',', ':')).encode()).hexdigest()})
    print('MQ06_REAR_STAGE: PASS; images=' + str(len(manifest['images'])) + '; front files unchanged=' + str(len(frozen['files'])))
    print('MQ06_REAR_FIT: PASS; method=' + policy['method'] + '; fixed=' + str(fit['iou']) + '; dynamic=' + str(fit['dynamic_iou']))
    print('MQ06_VIEW_CERTIFICATES: PASS; independent front/rear spec and cold-mesh bindings')


if __name__ == '__main__':
    main()
