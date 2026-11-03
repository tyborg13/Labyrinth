"""Promote only the director-approved, fully verified r3 native delivery."""
import hashlib
import json
from pathlib import Path
import shutil

import numpy as np
from PIL import Image

from spec.art_identity.maquettes.blender.compact_capture import compact_capture
from spec.art_identity.maquettes.blender.compile_recipe import compile_recipe
from spec.art_identity.maquettes.blender.contract import digest
from spec.art_identity.maquettes.blender.curate_delivery import sha, stage, write
from spec.art_identity.maquettes.blender.delivery_validation import seal_delivery, validate_delivery
from spec.art_identity.maquettes.blender.regenerate_delivery import compare_captures
from .workflow import EVIDENCE, FIGURE


def visible_hash(path):
    with Image.open(path) as image:
        pixels = np.array(image.convert('RGBA'))
    pixels[pixels[:, :, 3] == 0, :3] = 0
    return hashlib.sha256(pixels.tobytes()).hexdigest()


def verify_approved(spec, folder):
    status = json.loads((FIGURE / 'r3/design_status.json').read_text())
    build = json.loads((folder / 'build_report.json').read_text())
    if (status['status'] != 'director_accepted' or status['TODO_DESIGN'] or
            build['combined_mesh_hash'] != status['approved_native_mesh_hash'] or build['spec_hash'] != digest(spec)):
        raise ValueError('Delivery differs from the director-approved native body')
    for name, expected in status['approved_visible_rgba_sha256'].items():
        if visible_hash(folder / name) != expected:
            raise ValueError('Delivery pixels differ from the director-approved sheet: ' + name)


def canonical_regeneration():
    root = FIGURE / 'proof/mq13'
    regeneration = json.loads((EVIDENCE / 'validation/regeneration.json').read_text())
    inventories = [p for p in (root / 'regeneration').glob('*/clean_input_sha256.json')
                   if sha(p) == regeneration['input_inventory_sha256']]
    if not regeneration['passed'] or len(inventories) != 1:
        raise ValueError('Canonical comparison requires one matching fresh input-only regeneration')
    fresh = inventories[0].parent
    views = compare_captures(fresh / 'capture', FIGURE / 'delivery', fresh / 'canonical_comparison')
    passed = all(r['passed'] for view in views.values() for r in view.values())
    write(EVIDENCE / 'validation/canonical_regeneration.json', {'passed': passed, 'views': views,
        'spec_hash': regeneration['compiled_spec_hash'], 'native_mesh_hash': regeneration['native_mesh_hash'],
        'recipe_sha256': sha(FIGURE / 'measurements.json'),
        'capture_manifest_sha256': sha(FIGURE / 'delivery/capture_manifest.json')})
    if not passed:
        raise ValueError('Fresh native captures differ from canonical r3')
    print('MQ13_CANONICAL_REGENERATION: PASS; clay_and_part_map_pixels_exact=True')


def promote():
    root = FIGURE / 'proof/mq13'
    capture = root / 'capture'
    recipe = FIGURE / 'r3/measurements.json'
    spec = compile_recipe(json.loads(recipe.read_text()))
    gates = json.loads((EVIDENCE / 'review/gates.json').read_text())
    if not gates['passed'] or not all(gates['gates'].values()) or gates['spec_hash'] != digest(spec):
        raise ValueError('All r3 gates must pass before promotion')
    verify_approved(spec, capture)
    compact_capture(spec, capture)
    pose_path = capture / 'articulated_pose_checks.json'
    pose = json.loads(pose_path.read_text())
    pose['capture_manifest_sha256'] = sha(capture / 'capture_manifest.json')
    write(pose_path, pose)
    seal_delivery(spec, capture)
    existing = EVIDENCE / 'validation/promoted_delivery.json'
    if sha(FIGURE / 'measurements.json') == sha(recipe) and existing.exists():
        receipt = json.loads(existing.read_text())
        actual = {str(p.relative_to(FIGURE / 'delivery')): sha(p)
                  for p in (FIGURE / 'delivery').rglob('*') if p.is_file()}
        if receipt['files'] != actual:
            raise ValueError('Previously promoted canonical r3 changed')
        validate_delivery(spec, FIGURE / 'delivery')
        verify_approved(spec, FIGURE / 'delivery')
        canonical_regeneration()
        print('MQ13_PROMOTION: PASS; canonical=r3; already_current=True')
        return
    prepared = root / 'prepared'
    prepared.mkdir(exist_ok=True)
    shutil.copyfile(recipe, prepared / 'measurements.json')
    for name in ('reference', 'review'):
        if (FIGURE / 'delivery' / name).exists():
            shutil.copytree(FIGURE / 'delivery' / name, prepared / 'delivery' / name, dirs_exist_ok=True)
    stage(prepared, capture)
    verify_approved(spec, prepared / 'delivery')
    validate_delivery(spec, prepared / 'delivery')

    prior = {str(p.relative_to(FIGURE)): sha(p) for p in (FIGURE / 'delivery').rglob('*') if p.is_file()}
    prior['measurements.json'] = sha(FIGURE / 'measurements.json')
    sealed = json.loads((FIGURE / 'r2/validation/sealed_delivery.json').read_text())['files']
    expected = {'delivery/' + p: h for p, h in sealed.items()}
    expected['measurements.json'] = sha(FIGURE / 'r3/review/before_recipe.json')
    if prior != expected:
        raise ValueError('Canonical mq-12 baseline changed before the authorized promotion')
    baseline = EVIDENCE / 'validation/canonical_before_promotion.json'
    write(baseline, {'passed': True, 'files_sha256': prior})
    old = root / 'previous_delivery'
    (FIGURE / 'delivery').rename(old)
    try:
        (prepared / 'delivery').rename(FIGURE / 'delivery')
        shutil.copyfile(recipe, FIGURE / 'measurements.json')
        validate_delivery(spec, FIGURE / 'delivery')
        verify_approved(spec, FIGURE / 'delivery')
        canonical_regeneration()
    except Exception:
        shutil.rmtree(FIGURE / 'delivery', ignore_errors=True)
        old.rename(FIGURE / 'delivery')
        shutil.copyfile(FIGURE / 'r3/review/before_recipe.json', FIGURE / 'measurements.json')
        raise
    write(EVIDENCE / 'validation/promoted_delivery.json', {'passed': True, 'spec_hash': digest(spec),
        'recipe_sha256': sha(FIGURE / 'measurements.json'), 'native_mesh_hash': gates['native_observations']['native_mesh_hash'],
        'director_status_sha256': sha(FIGURE / 'r3/design_status.json'),
        'gate_report_sha256': sha(EVIDENCE / 'review/gates.json'),
        'previous_canonical_inventory_sha256': sha(baseline),
        'files': {str(p.relative_to(FIGURE / 'delivery')): sha(p)
                  for p in sorted((FIGURE / 'delivery').rglob('*')) if p.is_file()}})
    print('MQ13_PROMOTION: PASS; canonical=r3; approved_geometry_and_pixels_exact=True')


if __name__ == '__main__':
    promote()
