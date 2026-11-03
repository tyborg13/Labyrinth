"""Native mq-13 comparison sheet, joint table and honest acceptance gates."""
from copy import deepcopy
import json
from pathlib import Path
import shutil

import numpy as np
from PIL import Image, ImageDraw

from spec.art_identity.maquettes.blender.backend import load_render
from spec.art_identity.maquettes.blender.compile_recipe import compile_recipe
from spec.art_identity.maquettes.blender.contract import digest
from spec.art_identity.maquettes.blender.curate_delivery import sha, write
from spec.art_identity.maquettes.fitting import measure
from spec.art_identity.maquettes.raster import project

FIGURE = Path(__file__).resolve().parent
PROJECT = FIGURE.parents[3]
EVIDENCE = PROJECT / 'tests/mq13_validation'
PROOF_DEFAULTS = {'panel_size': 1024, 'joint_radius_px': 4, 'joint_colour': 'cyan',
                  'background': 'black', 'caption_colour': 'white', 'caption_position': [12, 12],
                  'joint_tolerance_m': 1e-4, 'webp_method': 6, 'caption_font': 'Pillow default'}
JOINTS = ('ankle_near', 'ankle_far', 'knee_near', 'knee_far', 'head',
          'shoulder_near', 'shoulder_far', 'hand_near', 'hand_far')


def pose_gates(spec):
    points = {n: project(spec, [p])[0, :2] for n, p in spec['joints'].items()}
    origin, end = project(spec, [[0, 0, 0], [1, 0, 0]])[:, :2]
    facing = end - origin
    knees = {}
    for side in ('near', 'far'):
        hip, knee, ankle = (points[n + side] for n in ('hip_', 'knee_', 'ankle_'))
        line = ankle - hip
        toward = facing - line * (line @ facing) / (line @ line)
        knees[side] = float((knee - hip) @ toward / np.linalg.norm(toward))
    near, far = points['shoulder_near'], points['shoulder_far']
    spread = float(abs(points['ankle_near'][0] - points['ankle_far'][0]))
    residual = float(abs((near[1] - far[1]) - .15 * abs(near[0] - far[0])))
    gates = {'ankle_near_target': bool(np.max(abs(points['ankle_near'] - [650, 900])) <= 12),
        'ankle_far_target': bool(np.max(abs(points['ankle_far'] - [430, 790])) <= 12),
        'head_target': bool(np.max(abs(points['head'] - [440, 330])) <= 10),
        'ankle_spread': spread <= 240, 'knees_face_forward': all(v > 0 for v in knees.values()),
        'level_shoulders': residual <= 10}
    return gates, {'ankle_spread_horizontal_px': spread, 'knee_facing_distance_px': knees,
                   'shoulder_residual_px': residual}


def proof():
    recipe = json.loads((FIGURE / 'r3/measurements.json').read_text())
    spec = compile_recipe(recipe)
    root, review = FIGURE / 'proof/mq13', EVIDENCE / 'review'
    capture = root / 'capture'
    native = json.loads((review / 'native_observations.json').read_text())
    if native['spec_hash'] != digest(spec):
        raise ValueError('Native observations are stale')
    before = json.loads((review / 'before_joints_px.json').read_text())
    after = json.loads((capture / 'joints_px.json').read_text())
    gates, metrics = pose_gates(spec)
    gates['design_resolved'] = not recipe.get('unresolved_design')
    old_spec = compile_recipe(json.loads((FIGURE / 'r3/review/before_recipe.json').read_text()))
    old, new = old_spec['joints'], spec['joints']
    gates['labels_unchanged'] = spec['labels'] == old_spec['labels']
    gates['hips_fixed'] = all(old[n] == new[n] for n in ('pelvis', 'hip_near', 'hip_far'))
    gates['bone_lengths_preserved'] = all(abs(np.linalg.norm(np.subtract(old[b['tail']], old[b['head']])) -
        np.linalg.norm(np.subtract(new[b['tail']], new[b['head']]))) <= PROOF_DEFAULTS['joint_tolerance_m'] for b in spec['armature']['bones'])
    shell_source = next(p for p in recipe['surfaces'] if p['id'] == recipe['articulated_pose']['shell']['piece'])
    gates['closed_scaled_carapace'] = (native['carapace_closed_components'] > 0 and
        native['carapace_closed_components'] == native['carapace_seating']['closed_plates_retained'] and
        native['carapace_seating']['source_clearance']['source_closed_plates'] == len(shell_source['layers']) and
        native['carapace_manifold_edges'] and native['carapace_seating']['scale'] == .6 and
        native['carapace_seating']['maximum_rigidity_error_m'] <= PROOF_DEFAULTS['joint_tolerance_m'])
    from spec.art_identity.maquettes.blender.contract import BUILD_DEFAULTS
    gates['flush_carapace_contact'] = all(row['final_gap_m'] <=
        native['carapace_seating']['clearance'] + BUILD_DEFAULTS['collision_epsilon']
        for row in native['carapace_seating']['actual_cloth_contacts'])
    from spec.art_identity.maquettes.blender.floor_contact import FLOOR_DEFAULTS
    gates['feet_remain_flat'] = (native['sole_height_difference_m'] <= FLOOR_DEFAULTS['maximum_lift_m'] and
        all(np.linalg.norm(np.subtract(old['foot_tip_' + s], old['ankle_' + s]) -
                           np.subtract(new['foot_tip_' + s], new['ankle_' + s])) <= PROOF_DEFAULTS['joint_tolerance_m'] for s in ('near', 'far')))
    build = json.loads((capture / 'build_report.json').read_text())
    gates.update(native_geometry=build['passed'],
        native_endpoints=max(native['joint_errors_m'].values()) <= PROOF_DEFAULTS['joint_tolerance_m'],
        native_geometry_unchanged=native['geometry_unchanged'] and native['native_mesh_hash'] == build['combined_mesh_hash'],
        carapace_overhang=all(v['carapace_overhang_passed'] for v in native['views'].values()))
    for name in ('recipe_proof', 'exact_native_replay'):
        report = json.loads((capture / (name + '.json')).read_text())
        gates[name] = report['passed'] and report['spec_hash'] == digest(spec)
    # The mq-06 regression determines depth from real foot solos and flat
    # depth-tested owners, independently of anatomical naming/facing reports.
    from tests.test_maquette_rear_turn import observations
    turn = observations(capture, labels=spec['labels'])
    gates['true_turn_feet_both_views'] = all(v['lower_foot_right'] for v in turn.values())
    gates['true_turn_ownership'] = (turn['front']['body_side_pixels_over_torso']['near'] > turn['front']['body_side_pixels_over_torso']['far'] and
        turn['rear']['body_side_pixels_over_torso']['far'] > turn['rear']['body_side_pixels_over_torso']['near'])
    fit = {}
    for view in ('front', 'rear'):
        measured = deepcopy(spec)
        measured['fit'].update(recipe['fit'][view])
        raster = load_render(spec, capture, view)
        report, _ = measure(measured, Image.open(PROJECT / recipe['sources'][view]).convert('RGBA'), raster=raster)
        fit[view] = report
    write(review / 'fit_report_only.json', {'policy': 'Report only: mq-13 accepts the specified pose, not the old silhouette.', 'views': fit})
    table = ['| View | Joint | Before (px) | After (px) |', '|---|---|---:|---:|']
    for view in ('front', 'rear'):
        for name in JOINTS:
            table.append('| ' + view + ' | ' + name + ' | ' + str(before[view][name]) + ' | ' + str(after[view][name]) + ' |')
    (review / 'joint_table.md').write_text('\n'.join(table) + '\n')
    size = PROOF_DEFAULTS['panel_size']
    sheet = Image.new('RGB', (size * 3, size * 2), PROOF_DEFAULTS['background'])
    sources = {}
    for row, view in enumerate(('front', 'rear')):
        native_folder = review / 'native'
        native_folder.mkdir(exist_ok=True)
        for kind in ('clay', 'parts'):
            shutil.copyfile(capture / (view + '_' + kind + '.png'), native_folder / ('new_' + view + '_' + kind + '.png'))
        paths = [(review / ('old_' + view + '_clay.png'), before[view], 'old ' + view + ' clay'),
                 (native_folder / ('new_' + view + '_clay.png'), after[view], 'new ' + view + ' clay'),
                 (native_folder / ('new_' + view + '_parts.png'), after[view], 'new ' + view + ' part map')]
        for column, (path, joints, caption) in enumerate(paths):
            panel = Image.new('RGB', (size, size), PROOF_DEFAULTS['background'])
            image = Image.open(path).convert('RGBA')
            if image.size != (size, size):
                raise ValueError('Proof panels must be native 1024')
            panel.paste(image, mask=image.getchannel('A'))
            draw = ImageDraw.Draw(panel)
            draw.text(PROOF_DEFAULTS['caption_position'], caption, fill=PROOF_DEFAULTS['caption_colour'])
            for name in JOINTS:
                x, y = joints[name]
                r = PROOF_DEFAULTS['joint_radius_px']
                draw.ellipse([x-r, y-r, x+r, y+r], outline=PROOF_DEFAULTS['joint_colour'])
                draw.text([x+r, y], name, fill=PROOF_DEFAULTS['joint_colour'])
            sheet.paste(panel, (column * size, row * size))
            sources[caption] = {'path': str(path.relative_to(PROJECT)), 'sha256': sha(path)}
    sheet.save(review / 'mq13_native_sheet.webp', lossless=True, method=PROOF_DEFAULTS['webp_method'])
    regen = EVIDENCE / 'validation/regeneration.json'
    regenerated = json.loads(regen.read_text()) if regen.exists() else {}
    native_manifest = capture / 'native_render_manifest.json'
    if not native_manifest.exists():
        native_manifest = capture / 'capture_manifest.json'
    gates['fresh_regeneration'] = (regenerated.get('passed') is True and
        regenerated.get('compiled_spec_hash') == digest(spec) and
        regenerated.get('native_mesh_hash') == build['combined_mesh_hash'] and
        regenerated.get('reference_mesh_hash') == build['combined_mesh_hash'] and
        regenerated.get('capture_manifest_sha256') == sha(native_manifest))
    result = {'passed': all(gates.values()), 'spec_hash': digest(spec), 'gates': gates,
              'pose_metrics': metrics, 'native_observations': native, 'true_turn': turn,
              'report_only': {'rear_hood_above_back_px': native['views']['rear']['back_top_y'] - native['views']['rear']['hood_top_y'],
                  'policy': 'Director feedback 1 accepts the r3 profile. Rear camera elevation projects the forward-bent head higher; this measurement is not an acceptance gate.'},
              'fit_iou_report_only': {v: r['iou'] for v, r in fit.items()}, 'sheet_inputs': sources}
    write(review / 'gates.json', result)
    write(capture / 'articulated_pose_checks.json', {'passed': result['passed'],
        'checks': gates, 'spec_hash': digest(spec), 'native_mesh_hash': build['combined_mesh_hash'],
        'report_only': result['report_only'],
        'capture_manifest_sha256': sha(capture / 'capture_manifest.json')})
    print('MQ13_GATES: ' + ('PASS' if result['passed'] else 'FAIL') + '; ' + json.dumps(gates, sort_keys=True))
    return result
