"""Audit committed deliveries and the explicitly unstaged planted rear."""
import json
from pathlib import Path
import sys

PROJECT = Path(__file__).resolve().parents[6]
sys.path.insert(0, str(PROJECT))
from spec.art_identity.maquettes.blender.compile_recipe import compile_recipe
from spec.art_identity.maquettes.blender.floor_contact import spec_contacts
from spec.art_identity.maquettes.blender.curate_delivery import sha
from tests.test_maquette_rear_turn import deliveries, observations


def write(path, value):
    path.write_text(json.dumps(value, indent=2) + '\n')


def main():
    folder = Path(__file__).resolve().parent
    figure = folder.parents[1]
    root = figure.parent
    exceptions = json.loads((folder.parent / 'feedback2/floor_guard_exceptions.json').read_text())['figures']
    floors, turns = {}, {}
    for delivery in deliveries():
        name = delivery.relative_to(root).parts[0]
        row = observations(delivery)
        turns[str(delivery.relative_to(root))] = row
        recipe = root / name / 'measurements.json'
        spec = compile_recipe(json.loads(recipe.read_text())) if recipe.exists() else json.loads((root / name / 'spec_r3.json').read_text())
        floors[name] = spec_contacts(spec, exceptions.get(name, []))
    original_seer = floors['hoarfrost_seer']
    rear_spec = compile_recipe(json.loads((folder / 'rear_recipe.json').read_text()))
    floors['hoarfrost_seer'] = spec_contacts(rear_spec, exceptions['hoarfrost_seer'])
    native = json.loads((folder / 'rear/build_report.json').read_text())
    contact = native['geometry_details']['floor_contact']
    floor_result = {'scope': 'frozen committed figures plus planted Seer rear candidate; no other figure modified',
        'figures': floors, 'seer_native': contact, 'frozen_seer_front_fit': original_seer,
        'passed': all(row['passed'] for row in floors.values()) and contact['passed']}
    if exceptions['hoarfrost_seer']:
        raise ValueError('Seer must have no floor exceptions')
    write(folder / 'floor_guard.json', floor_result)
    candidate = observations(folder / 'rear', front_folder=figure / 'delivery')
    front, rear = candidate['front'], candidate['rear']
    turn_ok = all(row['lower_foot_right'] for row in candidate.values()) and (
        front['body_side_pixels_over_torso']['near'] > front['body_side_pixels_over_torso']['far'] and
        rear['body_side_pixels_over_torso']['far'] > rear['body_side_pixels_over_torso']['near'])
    write(folder / 'turn_audit.json', {'committed_deliveries': turns,
        'seer_candidate_with_frozen_front': candidate, 'candidate_passed': turn_ok,
        'candidate_build_facing': native['geometry_details']['facing'],
        'production_staged': False})
    protected = json.loads((folder.parent / 'protected_sha256.json').read_text())
    changed = [name for name, expected in protected.items() if sha(PROJECT / name) != expected]
    allowed = {'spec/art_identity/maquettes/blender/' + name for name in
        ('build.py', 'compile_recipe.py', 'curate_delivery.py', 'render.py', 'cloth.py', 'drape_collision.py')}
    baseline = json.loads((folder.parent / 'feedback3/baseline_recipe.json').read_text())
    original = json.loads((figure / 'measurements.json').read_text())
    rear_recipe = json.loads((folder / 'rear_recipe.json').read_text())
    write(folder / 'protected_check.json', {'checked': len(protected), 'changed': changed,
        'unexpected_changes': sorted(set(changed) - allowed),
        'original_recipe_fields_unchanged': original == baseline and all(rear_recipe[k] == value for k, value in original.items()),
        'all_figure_deliveries_and_approved_paintings_unchanged': not (set(changed) - allowed)})
    print('MQ06_CANDIDATE_TURN: ' + ('PASS' if turn_ok else 'FAIL'))
    print('MQ06_FLOOR_GUARD: ' + ('PASS' if floor_result['passed'] else 'FAIL') + '; Seer exceptions=[]')
    for name, row in floors.items():
        print('FLOOR_CONTACT_GUARD: ' + name + '; documented exceptions=' + str(row['excepted_offenders']))
    print('MQ06_PROTECTED_BYTES: ' + ('PASS' if not set(changed) - allowed else 'FAIL') + '; checked=' + str(len(protected)))


if __name__ == '__main__':
    main()
