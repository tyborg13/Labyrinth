"""Task-local focused native proof and contact mutations, through the bridge."""
import json
from pathlib import Path
import sys
sys.dont_write_bytecode = True
PROJECT = Path(__file__).resolve().parents[5]
sys.path.insert(0, str(PROJECT))

import bpy
import numpy as np

from spec.art_identity.maquettes.burrow_grub.v2.build import evaluated
from spec.art_identity.maquettes.burrow_grub.v2.floor_report import measure
from spec.art_identity.maquettes.burrow_grub.v2.recipe import BASELINE, CONSTRAINTS, LEGS, RINGS, PROOF_DEFAULTS
from spec.art_identity.maquettes.blender.contract import digest, mesh_hash
from spec.art_identity.maquettes.blender.build import write
from spec.art_identity.maquettes.blender.creature_recipe import compile_solids
from spec.art_identity.maquettes.raster import camera


def main(build_dir, out):
    bpy.ops.wm.open_mainfile(filepath=str(build_dir / 'maquette.blend'))
    spec = json.loads((build_dir / 'source_spec.json').read_text())
    report = json.loads((build_dir / 'build_report.json').read_text())
    saved = json.loads((build_dir / 'floor_contact_report.json').read_text())
    baseline = compile_solids(json.loads(BASELINE.read_text()))
    objects = [o for o in bpy.context.scene.objects if o.type == 'MESH' and o.get('part') and not o.get('native_source')]
    groups = {o['piece_id']: evaluated(o)[0] for o in objects}
    def remeasure(data):
        return measure(data, baseline['pieces'], report['placements'], report['spine_floor_m'],
                       report['leg_shapes'], saved['floor_z_m'])
    checks = {'recomputed_floor_report_matches': remeasure(groups) == saved,
              'spec_digest_matches': digest(spec) == report['spec_hash'],
              'original_joint_names': set(spec['joints']) == set(baseline['joints']),
              'original_labels': spec['labels'] == baseline['labels']}
    contract = json.loads((Path(__file__).parent / 'feedback_1_contract.json').read_text())
    checks['approved_body_meshes_unchanged'] = all(report['mesh_hashes'][name] == value
                                                 for name, value in contract['protected_mesh_hashes'].items())
    checks['approved_floor_unchanged'] = saved['floor_z_m'] == contract['floor_z_m']
    checks['approved_body_joints_unchanged'] = all(spec['joints'][name] == value
                                                 for name, value in contract['protected_joints'].items())
    for obj in objects:
        vertices, faces = evaluated(obj)
        checks['mesh_hash_' + obj.name] = mesh_hash(vertices.tolist(), faces, obj['part']) == report['mesh_hashes'][obj.name]
        source = bpy.data.objects[obj['piece_id']]
        checks['bound_source_' + obj.name] = source.parent_type == 'BONE' and source.parent_bone == obj['part']
        checks['source_pose_' + obj.name] = bool(np.allclose(evaluated(source)[0], vertices, atol=1e-6))
    mutations = {}
    for name in RINGS + LEGS:
        shifted = dict(groups)
        shifted[name] = groups[name].copy()
        tolerance = CONSTRAINTS['ring_gap_L'] if name in RINGS else CONSTRAINTS['foot_gap_L']
        shifted[name][:, 2] += saved['L_m'] * tolerance * PROOF_DEFAULTS['lift_mutation_limit_multiplier']
        row = remeasure(shifted)
        mutations[name + '_lift_rejected'] = not row['passed']
    for name in LEGS:
        metadata = report['leg_shapes'][name]
        sides, rows = metadata['radial_samples'], metadata['axis_samples']
        sections = groups[name][:sides * rows].reshape(rows, sides, 3)
        axis = sections.mean(1)
        thin = groups[name].copy()
        thin[:sides * rows] = (axis[:, None, :] + (sections - axis[:, None, :]) / 2).reshape(-1, 3)
        thinned = remeasure({**groups, name: thin})['feet'][name]
        mutations[name + '_thin_hip_rejected'] = not thinned['passed'] and thinned['hip_width_L'] < CONSTRAINTS['hip_minimum_width_L']
        stretch = (CONSTRAINTS['leg_length_L'] * saved['L_m'] * PROOF_DEFAULTS['lift_mutation_limit_multiplier'] /
                   saved['feet'][name]['axis_length_m'])
        long = axis[0] + (groups[name] - axis[0]) * stretch
        elongated = remeasure({**groups, name: long})['feet'][name]
        mutations[name + '_long_axis_rejected'] = not elongated['passed'] and elongated['axis_length_L'] > CONSTRAINTS['leg_length_L']
        high = groups[name] + [0, 0, saved['L_m'] * CONSTRAINTS['hip_maximum_height_L']]
        raised = remeasure({**groups, name: high})['feet'][name]
        mutations[name + '_high_hip_rejected'] = not raised['passed'] and raised['hip_height_L'] > CONSTRAINTS['hip_maximum_height_L']
        reversed_hook = groups[name].copy()
        reversed_hook[:, 0] = 2 * axis[0, 0] - reversed_hook[:, 0]
        backward = remeasure({**groups, name: reversed_hook})['feet'][name]
        mutations[name + '_backward_hook_rejected'] = not backward['passed'] and backward['hook_forward_m'] < 0
    front = camera(spec, 'front')[0]
    rear = camera(spec, 'rear')[0]
    checks['same_pose_true_180'] = bool(np.allclose(rear[:3, :3], np.diag([-1, -1, 1]) @ front[:3, :3]))
    checks['rear_preserves_up'] = bool(np.allclose(rear @ [0, 0, 1, 0], [0, 0, 1, 0]))
    checks['floor_report_passed'] = saved['passed']
    result = {'checks': checks, 'contact_mutations': mutations,
              'passed': all(checks.values()) and all(mutations.values())}
    write(out, result)
    print(f"MQ27_FOCUSED: {'PASS' if result['passed'] else 'FAIL'}; {sum(checks.values())}/{len(checks)} checks; "
          f"{sum(mutations.values())}/{len(mutations)} contact/leg mutations rejected")
    return 0 if result['passed'] else 1


if __name__ == '__main__':
    args = sys.argv[sys.argv.index('--') + 1:]
    raise SystemExit(main(Path(args[0]), Path(args[1])))
