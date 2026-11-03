"""Native linked comparison sheets and honest mq-12 acceptance measurements."""
from copy import deepcopy
import json
from pathlib import Path

import numpy as np
from PIL import Image

from spec.art_identity.maquettes.blender.backend import load_render
from spec.art_identity.maquettes.blender.compile_recipe import compile_recipe, PROJECT
from spec.art_identity.maquettes.blender.contract import digest
from spec.art_identity.maquettes.blender.curate_delivery import sha, write
from spec.art_identity.maquettes.blender.pixel_coverage import part_coverage
from spec.art_identity.maquettes.fitting import measure
from tests.test_maquette_rear_turn import observations

PROOF_DEFAULTS = {'size': 1024, 'marker_radius_px': 9, 'marker_width_px': 3,
                  'near_colour': '#ffff00', 'far_colour': '#00ffff', 'epsilon': 1e-10,
                  'background': '#181818', 'foreground': 'white', 'font': '16px sans-serif'}


def fit(recipe, spec, capture):
    result = {}
    for view in ('front', 'rear'):
        source = PROJECT / recipe['sources'][view]
        if sha(source) != recipe['source_sha256'][view]:
            raise ValueError('Protected original painting changed')
        measured = deepcopy(spec)
        measured['fit'].update(recipe['fit'][view])
        raster = load_render(spec, capture, view)
        report, _ = measure(measured, Image.open(source).convert('RGBA'), raster=raster)
        result[view] = {'iou': report['iou'], 'iou_min': recipe['fit'][view]['gate']['iou_min'],
            'passed': report['iou'] >= recipe['fit'][view]['gate']['iou_min'],
            'source_frame': report['source_frame'], 'maquette_frame': report['maquette_frame'],
            'normalisation': report['normalisation']}
    return result


def sheet(figure, before, after, output):
    # Every image is an unchanged native 1024 cell; the overlay is proof only.
    lines = ['<!doctype html><meta charset="utf-8">', '<title>mq-12 ' + figure.name + '</title>',
        '<style>body{background:' + PROOF_DEFAULTS['background'] + ';color:' + PROOF_DEFAULTS['foreground'] +
        ';font:' + PROOF_DEFAULTS['font'] + '}table{border-collapse:collapse}'
        'td{padding:0;vertical-align:top}.cell{position:relative;width:1024px;height:1024px}'
        '.cell img,.cell svg{position:absolute;inset:0;width:1024px;height:1024px}</style>',
        '<p>' + figure.name + ' — native 1024 cells. Yellow: near shoulder; cyan: far shoulder. '
        'Candidate collision failures are reported in mq12_gates.json.</p>', '<table>',
        '<tr><th>Old clay</th><th>New clay</th><th>New part map</th></tr>']
    for view in ('front', 'rear'):
        lines.append('<tr>')
        for version, kind, prefix in ((before, 'clay', '../../delivery/'),
                                      (after, 'clay', '../capture/'), (after, 'parts', '../capture/')):
            path = prefix + view + '_' + kind + '.png'
            lines.append('<td><div class="cell"><img alt="' + view + ' ' + kind + '" src="' + path + '">'
                         '<svg viewBox="0 0 1024 1024">')
            for side in ('near', 'far'):
                x, y = version[view]['shoulder_' + side]
                lines.append(f'<circle cx="{x}" cy="{y}" r="{PROOF_DEFAULTS["marker_radius_px"]}" '
                    f'fill="none" stroke="{PROOF_DEFAULTS[side + "_colour"]}" stroke-width="{PROOF_DEFAULTS["marker_width_px"]}"/>')
            lines.append('</svg></div></td>')
        lines.append('</tr>')
    lines.append('</table>')
    output.write_text('\n'.join(lines) + '\n')


def evaluate(figure, recipe_path=None, root=None, before_root=None, regeneration=None, recorded_occlusions=None):
    figure = Path(figure)
    root = root or figure / 'proof/mq12'
    before_root = before_root or figure / 'proof/mq12_before'
    recipe_path = recipe_path or figure / 'r2/measurements.json'
    if not recipe_path.exists():
        recipe_path = figure / 'measurements.json'
    old_recipe, recipe = [json.loads(p.read_text()) for p in (before_root / 'measurements.json', recipe_path)]
    old_spec, spec = map(compile_recipe, (old_recipe, recipe))
    old_joints = json.loads((before_root / 'delivery/joints_px.json').read_text())
    joints = json.loads((root / 'capture/joints_px.json').read_text())
    near, far = (np.array(joints['front']['shoulder_' + side]) for side in ('near', 'far'))
    expected = .15 * abs(near[0] - far[0])
    lengths = {b['name']: abs(np.linalg.norm(np.subtract(spec['joints'][b['tail']], spec['joints'][b['head']])) -
        np.linalg.norm(np.subtract(old_spec['joints'][b['tail']], old_spec['joints'][b['head']])))
        for b in spec['armature']['bones']}
    before_build = json.loads((before_root / 'build/build_report.json').read_text())
    new_build = json.loads((root / 'cold/build_report.json').read_text())
    affected = {'body_upper_far', 'body_fore_far', 'body_hand_far'}
    affected |= {name + '_render' for name in spec['deferred_surface_pose']}
    affected |= {name + '_render' for name in spec.get('shoulder_garment_motion', {})}
    # Skin blend vertices at the shoulder can affect adjacent body regions;
    # report those hashes explicitly instead of hiding a changed torso mesh.
    meshes = {name: {'before': value, 'after': new_build['mesh_hashes'].get(name),
        'unchanged': value == new_build['mesh_hashes'].get(name)}
        for name, value in before_build['mesh_hashes'].items() if name not in affected}
    fit_before = fit(old_recipe, old_spec, before_root / 'delivery')
    fit_after = fit(recipe, spec, root / 'capture')
    coverage, missing = {}, {}
    for view in ('front', 'rear'):
        raster = load_render(spec, root / 'capture', view)
        coverage[view] = part_coverage(spec, raster, Image.open(root / 'capture' / (view + '_parts.png')).convert('RGBA'))
        missing[view] = [name for name, row in coverage[view].items() if not row['solo_pixels'] or
            row['clipped_at_canvas'] or (not row['pure_owner_pixels'] and not recipe['occlusions'].get(view, {}).get(name)
                and not (recorded_occlusions or {}).get(view, {}).get(name))]
    turn = observations(root / 'capture', labels=spec['labels'])
    turned = all(v['lower_foot_right'] and v['body_side_pixels_over_torso']['near' if view == 'front' else 'far'] >
                 v['body_side_pixels_over_torso']['far' if view == 'front' else 'near'] for view, v in turn.items())
    regen = json.loads((regeneration or figure / 'proof/mq12_regeneration/regeneration.json').read_text())
    replay = json.loads((root / 'exact_native_replay.json').read_text())
    recipe_proof = json.loads((root / 'capture/recipe_proof.json').read_text())
    from spec.art_identity.maquettes.blender.delivery_validation import seal_delivery
    delivery_error = None
    try:
        seal_delivery(spec, root / 'capture')
    except ValueError as error:
        delivery_error = str(error)
    gates = {'shoulder_front_rule': abs(near[1] - far[1] - expected) <= 10,
        'shoulder_far_x_unchanged': abs(far[0] - old_joints['front']['shoulder_far'][0]) <= PROOF_DEFAULTS['epsilon'],
        'level_body_space_shoulders': abs(spec['joints']['shoulder_near'][2] - spec['joints']['shoulder_far'][2]) <= PROOF_DEFAULTS['epsilon'],
        'all_limb_lengths_unchanged': max(lengths.values()) <= PROOF_DEFAULTS['epsilon'],
        'spine_neck_legs_joints_unchanged': all(spec['joints'][j] == old_spec['joints'][j] for j in spec['joints']
            if j not in ('shoulder_far', 'elbow_far', 'hand_far', 'hand_tip_far')),
        'protected_garments_unchanged': all(row['unchanged'] for name, row in meshes.items() if not name.startswith('body_')),
        'labels_unchanged': old_recipe['labels'] == recipe['labels'],
        'facing': json.loads((root / 'capture/facing_report.json').read_text())['passed'],
        'collision': new_build['checks']['cloth_collision_margin'], 'native_geometry': new_build['passed'],
        'ownership': new_build['checks']['polygon_material_ownership'] and new_build['checks']['body_weight_ownership'] and not any(missing.values()),
        'determinism': replay['passed'] and recipe_proof['checks']['fresh_and_replay_raw_hashes'],
        'mq06_true_turn_both_views': turned, 'fit_front': fit_after['front']['passed'], 'fit_rear': fit_after['rear']['passed'],
        'fresh_regeneration_matches': regen['raster_matches'] and regen['geometry_matches'],
        'hash_bound_delivery': delivery_error is None}
    gates = {name: bool(value) for name, value in gates.items()}
    return {'passed': all(gates.values()), 'gates': gates, 'spec_hash': digest(spec),
        'joint_table': {view: {j: {'before': old_joints[view][j], 'after': joints[view][j]} for j in
            ('shoulder_near', 'shoulder_far', 'elbow_far', 'hand_far')} for view in ('front', 'rear')},
        'fit_before': fit_before, 'fit_after': fit_after, 'shoulder_expected_difference_px': expected,
        'bone_length_error_m': lengths, 'protected_meshes': meshes, 'mq06_turn_observations': turn,
        'part_coverage': coverage, 'missing_or_clipped_parts': missing,
        'collision_failures': {k: v for k, v in new_build['cloth'].items() if not v['passed']},
        'delivery_error': delivery_error,
        'capture_sha256': {p.name: sha(p) for p in sorted((root / 'capture').glob('*.png'))}}


def proof(figure):
    result = evaluate(figure)
    review = figure / 'r2/review'
    review.mkdir(parents=True, exist_ok=True)
    write(review / 'mq12_gates.json', result)
    old = json.loads((figure / 'proof/mq12_before/delivery/joints_px.json').read_text())
    new = json.loads((figure / 'proof/mq12/capture/joints_px.json').read_text())
    sheet(figure, old, new, review / 'mq12_shoulders.html')
    rows = ['| View | Joint | Before (px) | After (px) |', '|---|---|---|---|']
    for view, joints in result['joint_table'].items():
        for name, values in joints.items():
            rows.append(f'| {view} | {name} | {values["before"]} | {values["after"]} |')
    rows += ['', '| View | Original IoU | Corrected IoU | Gate |', '|---|---:|---:|---:|']
    for view in ('front', 'rear'):
        rows.append(f'| {view} | {result["fit_before"][view]["iou"]:.9f} | '
                    f'{result["fit_after"][view]["iou"]:.9f} | {result["fit_after"][view]["iou_min"]} |')
    (review / 'mq12_joint_table.md').write_text('\n'.join(rows) + '\n')
    print('MQ12_GATES: ' + ('PASS' if result['passed'] else 'FAIL') + '; ' + figure.name + '; ' +
          '; '.join(k + '=' + str(v) for k, v in result['gates'].items()), flush=True)
    return result
