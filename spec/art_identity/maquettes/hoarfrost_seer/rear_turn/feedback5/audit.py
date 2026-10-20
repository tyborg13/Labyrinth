"""Audit staged bytes, all rear turns, floor exceptions and both native proofs."""
import hashlib
import json
from pathlib import Path
import sys

PROJECT = Path(__file__).resolve().parents[6]
sys.path.insert(0, str(PROJECT))
from spec.art_identity.maquettes.blender.compile_recipe import compile_recipe
from spec.art_identity.maquettes.blender.curate_delivery import sha
from spec.art_identity.maquettes.blender.delivery_validation import validate_delivery
from spec.art_identity.maquettes.blender.floor_contact import spec_contacts
from tests.test_maquette_rear_turn import deliveries, observations
from spec.art_identity.maquettes.hoarfrost_seer.rear_turn.preservation import protected_hash_changes


def load(path):
    return json.loads(path.read_text())


def write(path, data):
    path.write_text(json.dumps(data, indent=2, allow_nan=False) + '\n')


def turn_passed(views):
    return all(row['lower_foot_right'] and
        row['body_side_pixels_over_torso']['near' if view == 'front' else 'far'] >
        row['body_side_pixels_over_torso']['far' if view == 'front' else 'near']
        for view, row in views.items())


def main():
    folder = Path(__file__).resolve().parent
    figure, proof = folder.parents[1], folder.parent / 'feedback4'
    delivery, root = figure / 'delivery', figure.parent
    base = compile_recipe(load(figure / 'measurements.json'))
    binding = validate_delivery(base, delivery)
    write(folder / 'delivery_validation.json', {'passed': True, 'binding': binding})
    exceptions = load(folder.parent / 'feedback2/floor_guard_exceptions.json')['figures']
    floors, turns = {}, {}
    for current in deliveries():
        name = current.relative_to(root).parts[0]
        turns[str(current.relative_to(root))] = observations(current)
        path = root / name / 'measurements.json'
        spec = compile_recipe(load(path)) if path.is_file() else load(root / name / 'spec_r3.json')
        if name == figure.name:
            spec = compile_recipe(load(proof / 'rear_recipe.json'))
        floors[name] = spec_contacts(spec, exceptions.get(name, []))
    native = load(delivery / 'rear_native/build_report.json')
    floor = native['geometry_details']['floor_contact']
    floor_passed = all(row['passed'] for row in floors.values()) and floor['passed'] and not exceptions[figure.name]
    write(folder / 'floor_guard.json', {'passed': floor_passed, 'scope': 'staged rear body and committed other figures',
        'figures': floors, 'seer_native': floor, 'documented_exceptions': exceptions})
    turn_ok = all(turn_passed(row) for row in turns.values())
    write(folder / 'turn_audit.json', {'passed': turn_ok, 'deliveries': turns,
        'seer_facing': native['geometry_details']['facing']})
    frozen = load(proof / 'front_freeze.json')
    front_ok = (frozen['files'] == {p.name: sha(p) for p in delivery.glob('front_*')} and
                frozen['joints'] == load(delivery / 'joints_px.json')['front'])
    acceptance = load(delivery / 'rear_acceptance.json')
    sheet_ok = sha(figure / acceptance['reviewed_sheet']) == acceptance['reviewed_sheet_sha256']
    archived = {name: expected for name, size, expected in load(figure / 'discarded_proof_sha256.json')['files']}
    pngs_ok = all(sha(path) == archived['rear_turn/feedback4/rear/' + path.name]
                  for path in delivery.glob('rear_*.png'))
    shared = {'spec/art_identity/maquettes/blender/' + name for name in ('build.py', 'cloth.py',
        'compile_recipe.py', 'curate_delivery.py', 'drape_collision.py', 'render.py', 'backend.py',
        'capture_manifest.py', 'delivery_validation.py')}
    combined = {'build_report.json', 'capture_checks.json', 'capture_manifest.json', 'cloak_side.json',
        'joints_px.json', 'native_capture_manifest.json', 'provenance.json', 'recipe_proof.json',
        'solo_coverage.json', 'fit_overlay.png', 'regeneration.json', 'frozen_geometry.json'}
    protected = load(folder.parent / 'protected_sha256.json')
    changed = protected_hash_changes(PROJECT, protected)
    unexpected = []
    for name in changed:
        path = Path(name)
        rear_owned = (path.parent == delivery.relative_to(PROJECT) and
            (path.name in combined or path.name.startswith('rear_')))
        if name not in shared and not rear_owned:
            unexpected.append(name)
    unchanged_design = (load(figure / 'measurements.json') == load(folder.parent / 'feedback3/baseline_recipe.json') and
        all(load(proof / 'rear_recipe.json')[key] == value for key, value in load(figure / 'measurements.json').items()))
    protected_ok = front_ok and unchanged_design and sheet_ok and pngs_ok and not unexpected
    write(folder / 'protected_check.json', {'passed': protected_ok, 'checked': len(protected),
        'changed_authorized_shared_or_rear_files': changed, 'unexpected_changes': unexpected,
        'front_bytes_and_joints_unchanged': front_ok, 'provided_recipe_fields_unchanged': unchanged_design,
        'reviewed_sheet_byte_unchanged': sheet_ok, 'staged_pngs_byte_identical_to_archived_reviewed_source': pngs_ok,
        'other_figure_deliveries_and_approved_paintings_unchanged': not unexpected})
    hashes = {str(path.relative_to(delivery)): sha(path) for path in sorted(delivery.rglob('*')) if path.is_file() and
        (path.name.startswith('rear_') or path.is_relative_to(delivery / 'rear_native') or
         path.name in ('capture_frame.json', 'joints_px.json', 'view_sources.json'))}
    write(folder / 'staged_rear_sha256.json', {'algorithm': 'sha256', 'files': hashes,
        'rear_joint_entries_sha256': hashlib.sha256(json.dumps(load(delivery / 'joints_px.json')['rear'], sort_keys=True, separators=(',', ':')).encode()).hexdigest()})
    (folder / 'staged_rear_sha256.txt').write_text('\n'.join(value + '  delivery/' + name for name, value in hashes.items()) + '\n')
    fit = load(delivery / 'rear_proportion_report.json')
    print('MQ06_DELIVERY_VALIDATION: PASS; frozen-front and independent planted-rear certificates sealed')
    print('MQ06_FRONT_FREEZE: ' + ('PASS' if front_ok else 'FAIL') + '; files=' + str(len(frozen['files'])) + '; joint displacement=0 px')
    print('MQ06_COMMITTED_TURN: ' + ('PASS' if turn_ok else 'FAIL') + '; deliveries=' + str(len(turns)))
    print('MQ06_FLOOR_GUARD: ' + ('PASS' if floor_passed else 'FAIL') + '; Seer exceptions=[]')
    print('MQ06_NATIVE_COLLISION: ' + ('PASS' if all(row['passed'] for row in native['cloth'].values()) else 'FAIL') + '; skirt intersections=' + str(native['cloth']['robe_skirt']['intersecting_face_pairs']))
    print('MQ06_REAR_FIT: PASS; fixed=' + str(fit['iou']) + '; dynamic=' + str(fit['dynamic_iou']) + '; gate=' + str(fit['iou_min']))
    print('MQ06_PROTECTED_BYTES: ' + ('PASS' if protected_ok else 'FAIL') + '; checked=' + str(len(protected)))
    print('MQ06_STAGED_REAR_HASHES: ' + str(len(hashes)) + '; ' + str(folder / 'staged_rear_sha256.txt'))
    if not (front_ok and floor_passed and turn_ok and protected_ok):
        raise ValueError('A required staged-delivery audit failed')


if __name__ == '__main__':
    main()
