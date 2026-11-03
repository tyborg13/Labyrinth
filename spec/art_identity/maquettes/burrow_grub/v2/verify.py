"""Portable checks for this delivery only; no new repository-wide guard."""
import json
from pathlib import Path
import sys
sys.dont_write_bytecode = True
PROJECT = Path(__file__).resolve().parents[5]
sys.path.insert(0, str(PROJECT))

import numpy as np
from PIL import Image

from spec.art_identity.maquettes.burrow_grub.v2.recipe import HERE, BASELINE, LEGS, RINGS, PROOF_DEFAULTS, CONSTRAINTS, length_m
from spec.art_identity.maquettes.burrow_grub.v2.workflow import sha, visibility
from spec.art_identity.maquettes.burrow_grub.v2.screen_clearance import measure as screen_measure, from_masks
from spec.art_identity.maquettes.blender.contract import digest
from spec.art_identity.maquettes.raster import project


def main():
    delivery = HERE / 'delivery'
    def read(name):
        return json.loads((delivery / name).read_text())
    build, capture, floor, spec = map(read, ['build_report.json', 'capture_report.json',
                                           'floor_contact_report.json', 'source_spec.json'])
    checks = {'build_passed': build['passed'], 'capture_passed': capture['passed'],
              'floor_passed': floor['passed'], 'spec_bound': digest(spec) == build['spec_hash'],
              'baseline_unchanged': sha(BASELINE) == build['provenance']['baseline_measurements_sha256'],
              'all_contact_rows': set(floor['rings']) == set(RINGS) and set(floor['feet']) == set(LEGS),
              'L_derived_from_board_scale': abs(floor['L_m'] - length_m()) < 1e-6,
              'rear_same_pose_180': capture['rear_is_same_pose_yaw_deg'] == 180,
              'camera_mq05': capture['camera'] == {'azimuth_deg': 45, 'elevation_deg': 30,
                                                'ortho_scale_m': 2.4, 'target': [0, 0, 1.12]}}
    checks['captures_bind_current_geometry'] = all(c['combined_mesh_hash'] == build['combined_mesh_hash'] and
                                                 c['spec_hash'] == build['spec_hash'] for c in capture['captures'])
    for name, value in build['provenance']['implementation_sha256'].items():
        checks['implementation_' + name] = sha(HERE / name) == value
    expected_pngs = {f'{view}_{kind}.png' for view in ('front', 'rear') for kind in ('clay', 'parts', 'silhouette')}
    expected_pngs |= {f'{view}_solo_{part}.png' for view in ('front', 'rear') for part in spec['labels']}
    checks['all_34_native_pngs'] = set(capture['png_sha256']) == expected_pngs
    for name, value in capture['png_sha256'].items():
        checks['png_' + name] = sha(delivery / name) == value and Image.open(delivery / name).size == (1024, 1024)
    checks['leg_visibility_recomputed'] = visibility(delivery, spec) == read('solo_coverage.json')
    checks['screen_clearance_recomputed'] = screen_measure(delivery, spec, read('solo_coverage.json')) == floor['screen_clearance']
    checks['screen_clearance_passed'] = floor['screen_clearance']['passed']
    contract_path = HERE / 'feedback_1_contract.json'
    contract = json.loads(contract_path.read_text())
    checks['body_contract_bound'] = sha(contract_path) == build['provenance']['feedback_1_contract_sha256']
    checks['approved_body_meshes_unchanged'] = all(build['mesh_hashes'][name] == value for name, value in contract['protected_mesh_hashes'].items())
    checks['approved_body_solos_unchanged'] = all(sha(delivery / name) == value for name, value in contract['protected_solo_sha256'].items())
    # Synthetic single-column boundary fixture derives its dimensions from
    # the director's exact limit; 34 px passes, the next pixel fails.
    limit = CONSTRAINTS['foot_screen_clearance_px']
    fixture_body = np.zeros((limit + 3, 1), dtype=bool)
    fixture_body[0, 0] = True
    for extra, expected in [(0, True), (1, False)]:
        fixture_foot = np.zeros_like(fixture_body)
        fixture_foot[limit + extra, 0] = True
        checks['screen_boundary_' + str(limit + extra)] = from_masks(fixture_body, fixture_foot)['passed'] == expected
    joints = read('joints_px.json')
    for view in ('front', 'rear'):
        checks[view + '_joint_names'] = set(joints[view]) == set(spec['joints'])
        checks[view + '_joint_projection'] = all(np.allclose(project(spec, point, view)[:2], joints[view][name],
                                                            atol=PROOF_DEFAULTS['joint_projection_tolerance_px'])
                                                for name, point in spec['joints'].items())
    probe = read('focused_native_proof.json')
    checks['native_proof_passed'] = probe['passed']
    for name, row in floor['rings'].items():
        checks[name + '_floor'] = abs(row['gap_L']) <= row['maximum_gap_L'] and row['contact_vertices'] > 0
        checks[name + '_cross_section'] = abs(row['height_width'] - .8) < 1e-6
    for name, row in floor['feet'].items():
        checks[name + '_floor'] = abs(row['gap_L']) <= row['maximum_gap_L']
        checks[name + '_length'] = row['axis_length_L'] <= CONSTRAINTS['leg_length_L']
        checks[name + '_hip_width'] = row['hip_width_L'] >= CONSTRAINTS['hip_minimum_width_L']
        checks[name + '_hip_height'] = row['hip_height_L'] <= CONSTRAINTS['hip_maximum_height_L']
        checks[name + '_forward_hook'] = row['hook_forward_m'] > 0
    passed = all(checks.values())
    (delivery / 'portable_proof.json').write_text(json.dumps({'checks': {k: bool(v) for k, v in checks.items()},
                                                            'passed': bool(passed)}, indent=2) + '\n')
    print(f"MQ27_PORTABLE: {'PASS' if passed else 'FAIL'}; {sum(checks.values())}/{len(checks)} checks")
    if not passed:
        print('Failures: ' + ', '.join(k for k, v in checks.items() if not v))
    return 0 if passed else 1


if __name__ == '__main__':
    raise SystemExit(main())
