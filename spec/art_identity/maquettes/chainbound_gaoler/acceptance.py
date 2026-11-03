"""mq-15 proportion, shoulder, planted true-turn and source-preservation proof."""
import json
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

from spec.art_identity.maquettes.blender.compile_recipe import compile_recipe, PROJECT
from spec.art_identity.maquettes.blender.contract import digest
from spec.art_identity.maquettes.blender.curate_delivery import sha, write
from spec.art_identity.maquettes.blender.capture_manifest import read_manifest
from spec.art_identity.maquettes.raster import project, camera
from tests.test_maquette_rear_turn import observations


PROOF_DEFAULTS = {'native_size': 1024, 'painting_scale': 4, 'alpha_threshold': 128,
                  'joint_tolerance_px': .02, 'level_tolerance_m': 1e-8,
                  'floor_tolerance_m': .005, 'endpoint_tolerance_m': 1e-4,
                  'caption_height_px': 28, 'opaque_annotation_mode':'RGB', 'webp_effort':100, 'background': (24, 24, 24, 255),
                  'guideline_colour': (80, 220, 240, 255),
                  'label_offsets_px': {'helm_bottom': -14, 'shoulder_row': 2}}
ROOT = PROJECT / 'spec/art_identity/maquettes'
APPROVED_LIMITS = {'shoulder_slope': .15, 'shoulder_tolerance_px': 10, 'rear_height_relative': .03}


def save_annotation(picture,path):
    before=np.asarray(picture.convert('RGBA'))
    if np.all(before[:,:,3]==255):picture=picture.convert(PROOF_DEFAULTS['opaque_annotation_mode'])
    picture.save(path,lossless=True,exact=True,method=6,quality=PROOF_DEFAULTS['webp_effort'])
    with Image.open(path) as saved:
        if not np.array_equal(before,np.asarray(saved.convert('RGBA'))):
            raise ValueError('Proof annotation encoding changed RGBA pixels')


def height_parity(front, rear):
    return {'passed': abs(rear - front) <= APPROVED_LIMITS['rear_height_relative'] * front,
            'relative_error': rear / front - 1}


def mask(path):
    with Image.open(path) as image:
        return np.asarray(image.convert('RGBA'))[..., 3] >= PROOF_DEFAULTS['alpha_threshold']


def pose_gates(spec, recorded, native):
    joints = {view: {name: project(spec, point, view, 1024)[:2].tolist()
                     for name, point in spec['joints'].items()} for view in ('front', 'rear')}
    near, far = (recorded['front']['shoulder_' + side] for side in ('near', 'far'))
    expected = APPROVED_LIMITS['shoulder_slope'] * abs(near[0] - far[0])
    observed = near[1] - far[1]
    level = abs(spec['joints']['shoulder_near'][2] - spec['joints']['shoulder_far'][2])
    errors = [float(np.linalg.norm(np.subtract(point, recorded[view][name])))
              for view, values in joints.items() for name, point in values.items()]
    checks = {'level_shoulders_3d': level <= PROOF_DEFAULTS['level_tolerance_m'],
              'shoulder_rule': abs(observed - expected) <= APPROVED_LIMITS['shoulder_tolerance_px'],
              'native_joint_inventory': all(set(recorded[v]) == set(joints[v]) for v in joints),
              'native_projection': max(errors) <= PROOF_DEFAULTS['joint_tolerance_px'],
              'native_endpoints': max(native['endpoint_errors_m'].values()) <= PROOF_DEFAULTS['endpoint_tolerance_m']}
    feet = {side: {'min_z_m': value['world_min'][2], 'max_z_m': value['world_max'][2]}
            for side, value in native['feet'].items()}
    checks['feet_planted'] = all(abs(value['min_z_m']) <= PROOF_DEFAULTS['floor_tolerance_m'] for value in feet.values())
    for view in ('front', 'rear'):
        chain, pelvis = (recorded[view][name] for name in ('hand_far', 'pelvis'))
        checks[view + '_chain_side'] = chain[0] < pelvis[0] if view == 'front' else chain[0] > pelvis[0]
    return {'passed': all(checks.values()), 'checks': checks,
            'observed_far_above_near_px': observed, 'expected_far_above_near_px': expected,
            'shoulder_error_px': abs(observed - expected), 'level_difference_m': level,
            'maximum_projection_error_px': max(errors), 'feet': feet}


def proportions(recipe, spec, capture, native, joints):
    source = recipe['mq15']['approved_front_annotations_px']
    scale = PROOF_DEFAULTS['painting_scale']
    reference = {'total_height': source['sole_bottom'] - source['helm_top'],
                 'helm_height': source['helm_bottom'] - source['helm_top'],
                 'torso_height': source['pelvis_row'] - source['shoulder_row'],
                 'pelvis_to_knee': source['knee_row'] - source['pelvis_row'],
                 'knee_to_sole': source['sole_bottom'] - source['knee_row'],
                 'shoulder_width': abs(source['shoulder_near'][0] - source['shoulder_far'][0])}
    helmets = native['objects']['bucket_helm_render']['views']
    heights = {}
    for view in ('front', 'rear'):
        feet = np.logical_or(*(mask(capture / f'{view}_solo_foot_{side}.png') for side in ('near', 'far')))
        head = mask(capture / f'{view}_solo_head.png')
        sole = int(np.argwhere(feet)[:, 0].max()) + 1
        head_top = int(np.argwhere(head)[:, 0].min())
        heights[view] = {'head_top_px': head_top, 'helm_top_px': helmets[view]['min'][1],
                         'sole_bottom_px': sole, 'head_to_sole_px': sole - head_top,
                         'helm_to_sole_px': sole - helmets[view]['min'][1]}
    front = joints['front']
    mean_y = lambda names: float(np.mean([front[name][1] for name in names]))
    shoulder = mean_y(['shoulder_near', 'shoulder_far'])
    pelvis = front['pelvis'][1]
    knee = mean_y(['knee_near', 'knee_far'])
    actual = {'total_height': heights['front']['helm_to_sole_px'],
              'helm_height': helmets['front']['max'][1] - helmets['front']['min'][1],
              'torso_height': pelvis - shoulder, 'pelvis_to_knee': knee - pelvis,
              'knee_to_sole': heights['front']['sole_bottom_px'] - knee,
              'shoulder_width': abs(front['shoulder_near'][0] - front['shoulder_far'][0])}
    table = {}
    for name, measured in actual.items():
        approved = reference[name] * scale
        error = measured / approved - 1
        limit = recipe['mq15']['proportion_limits'][name]
        table[name] = {'approved_source_px': reference[name], 'approved_native_px': approved,
                       'native_px': measured, 'relative_error': error,
                       'tolerance': limit, 'passed': abs(error) <= limit}
    parity = height_parity(heights['front']['head_to_sole_px'], heights['rear']['head_to_sole_px'])
    return {'passed': all(row['passed'] for row in table.values()) and parity['passed'],
            'table': table, 'native_heights': heights, 'rear_relative_error': parity['relative_error'],
            'height_parity_passed': parity['passed'],
            'definition': '1024 pixels; original painting x4 without per-view resizing. Helmet excludes the top ring; head includes it. Longitudinal landmarks use the shoulder/knee midpoint, pelvis pivot and lowest sole.'}


def inspect(folder, capture):
    folder, capture = Path(folder), Path(capture)
    recipe = json.loads((folder / 'measurements.json').read_text())
    spec = compile_recipe(recipe)
    read_manifest(capture, digest(spec), ('full',))
    native = json.loads((capture / 'native_probe.json').read_text())
    build = json.loads((capture / 'build_report.json').read_text())
    if native['spec_hash'] != digest(spec) or native['native_mesh_hash'] != build['combined_mesh_hash']:
        raise ValueError('Stale native geometry observation')
    joints = json.loads((capture / 'joints_px.json').read_text())
    pose = pose_gates(spec, joints, native)
    fit = proportions(recipe, spec, capture, native, joints)
    from .mass_gates import inspect_mass
    mass = inspect_mass(folder, capture, spec, native, joints)
    from .pose_fit import inspect_fit
    front_fit=inspect_fit(folder,capture,PROJECT,spec,native)
    turn = observations(capture, labels=spec['labels'])
    turn_checks = {view + '_lower_foot_right': turn[view]['lower_foot_right'] for view in turn}
    # The arm pose is deliberately asymmetric. Reflection cannot reproduce the
    # actual depth-order exchange, and the 180-degree camera matrix is proper.
    for view in ('front', 'rear'):
        matrix = camera(spec, view)[0]
        turn_checks[view + '_proper_rotation'] = bool(np.isclose(np.linalg.det(matrix[:3, :3]), 1))
    turn_checks['rear_is_half_turn'] = bool(np.allclose(camera(spec, 'rear')[0][:3, :3], np.diag([-1, -1, 1])))
    with Image.open(capture / 'front_parts.png') as image:
        front = np.asarray(image.convert('RGBA'))
    with Image.open(capture / 'rear_parts.png') as image:
        rear = np.asarray(image.convert('RGBA'))
    turn_checks['rear_not_mirror'] = not np.array_equal(front[:, ::-1], rear)
    sources = all(sha(PROJECT / path) == recipe['source_sha256'][v] for v, path in recipe['sources'].items())
    result = {'spec_hash': digest(spec), 'passed': front_fit['passed'] and mass['passed'] and pose['passed'] and fit['passed'] and all(turn_checks.values()) and native['passed'] and sources,
              'front_fit':front_fit, 'mass': mass, 'pose': pose, 'proportions': fit, 'true_turn': {'observations': turn, 'checks': turn_checks, 'passed': all(turn_checks.values())},
              'protected_sources_unchanged': sources,
              'inputs_sha256': {**{name: sha(capture / name) for name in ('native_probe.json', 'capture_manifest.json', 'build_report.json')}, 'mass_annotations.json':sha(folder/'mass_annotations.json'), 'cloth_annotations.json':sha(folder/'cloth_annotations.json'), 'fit_annotations.json':sha(folder/'fit_annotations.json')}}
    write(capture / 'mq15_acceptance.json', result)
    lines = ['| Measure | Approved x4 px | Native px | Error | Limit | Gate |', '|---|---:|---:|---:|---:|---|']
    for name, row in fit['table'].items():
        lines.append(f"| {name} | {row['approved_native_px']:.3f} | {row['native_px']:.3f} | {row['relative_error']:+.2%} | ±{row['tolerance']:.0%} | {'PASS' if row['passed'] else 'FAIL'} |")
    lines += ['', '| Mass measure | Approved x4 px | Part map px | Error | Limit | Gate |', '|---|---:|---:|---:|---:|---|']
    for name, row in mass['table'].items():
        limit=f"±{row['tolerance']:.0%}" if row['tolerance'] else f"≥{row['minimum_px']} px"
        lines.append(f"| {name} | {row['approved_native_px']:.3f} | {row['native_px']:.3f} | {row['relative_error']:+.2%} | {limit} | {'PASS' if row['passed'] else 'FAIL'} |")
    lines += ['', '| Fit centroid (255px) | Offset X px | Offset Y px | Distance px | Limit px | Gate |', '|---|---:|---:|---:|---:|---|']
    for name,row in front_fit['table'].items():
        lines.append(f"| {name} | {row['offset_px'][0]:+.3f} | {row['offset_px'][1]:+.3f} | {row['distance_px']:.3f} | {row['limit_px']} | {'PASS' if row['passed'] else 'FAIL'} |")
    for view,row in front_fit['views'].items():
        lines += ['', f"{view} silhouette IoU: {row['iou']:.6f}; best translation {row['translation_px']} px. " + ('Limit ≥0.82.' if view=='front' else 'Informational; rear follows the true turn.')]
    lines += ['',front_fit['method']]
    lines += ['', mass['method'], '', 'Mass checks: ' + json.dumps(mass['checks'], sort_keys=True), '', 'See-through: ' + json.dumps(mass['no_see_through'], sort_keys=True), '', 'Open front: ' + json.dumps(mass['open_front'], sort_keys=True), '', 'Barrel chest: ' + json.dumps(mass['chest'], sort_keys=True), '', 'Collar extensions beyond helm: ' + json.dumps(mass['collar_extensions'], sort_keys=True), '', 'Largest unfilled part hole: ' + str(max(v['maximum_width_px'] for v in mass['part_holes'].values())) + ' px.']
    lines += ['', mass['cloth']['method'], '', 'Native ragged hems: '+json.dumps({n:{'tip_count':v['tip_count']} for n,v in mass['cloth']['hem_points'].items()},sort_keys=True), '', 'Gloved grip: '+json.dumps(native['gloved_grip'],sort_keys=True)]
    lines += ['', f"Shoulders: observed {pose['observed_far_above_near_px']:.3f} px; expected {pose['expected_far_above_near_px']:.3f} px; error {pose['shoulder_error_px']:.3f} px; 3D level difference {pose['level_difference_m']:.9g} m.", '',
              f"Native head-to-sole heights: front {fit['native_heights']['front']['head_to_sole_px']} px; rear {fit['native_heights']['rear']['head_to_sole_px']} px; difference {fit['rear_relative_error']:+.3%} (limit ±3%)."]
    for view in ('front', 'rear'):
        feet = turn[view]
        lines += ['', f"{view}: chain fist x={joints[view]['hand_far'][0]:.2f}, pelvis x={joints[view]['pelvis'][0]:.2f}; "
                  f"foot centroids near={feet['feet']['near']}, far={feet['feet']['far']}; lower foot={feet['lower_foot']}, lower foot right={feet['lower_foot_right']}."]
    lines += ['', 'Native sole minimum Z (m): ' + ', '.join(f"{side}={value['min_z_m']:.9f}" for side, value in pose['feet'].items()) + '.',
              '', 'Rear is the proper rotation diag(-1,-1,1), determinant +1; labels do not swap. The tabard emblem is anterior geometry in the tabard label, covered by the cloth from behind.']
    (capture / 'proportion_table.md').write_text('\n'.join(lines) + '\n')
    print('MQ15_ACCEPTANCE: ' + ('PASS' if result['passed'] else 'FAIL') + '; ' + json.dumps({'mass': mass['checks'], 'pose': pose['checks'], 'turn': turn_checks, 'proportions': {n: r['passed'] for n, r in fit['table'].items()}, 'heights': fit['native_heights']}, sort_keys=True))
    return result


def review_sheet(folder, capture):
    folder, capture = Path(folder).resolve(), Path(capture).resolve()
    recipe = json.loads((folder / 'measurements.json').read_text())
    size, header = PROOF_DEFAULTS['native_size'], PROOF_DEFAULTS['caption_height_px']
    sheet = Image.new('RGBA', (4 * size, 2 * (size + header)), PROOF_DEFAULTS['background'])
    draw = ImageDraw.Draw(sheet)
    receipts = {}
    for row, view in enumerate(('front', 'rear')):
        cells = [(PROJECT / recipe['sources'][view], 'Gaoler approved ' + view, 4),
                 (capture / (view + '_clay.png'), 'Gaoler mq-15 ' + view, 1),
                 (ROOT / 'gloam_stalker/delivery/reference/lancer_r3' / (view + '_clay.png'), 'Lancer r3 reference ' + view, 1),
                 (ROOT / 'gloam_stalker/delivery' / (view + '_clay.png'), 'Gloam r3 ' + view, 1)]
        for column, (path, caption, scale) in enumerate(cells):
            with Image.open(path) as image:
                picture = image.convert('RGBA')
            if scale != 1:
                picture = picture.resize(tuple(d * scale for d in picture.size), Image.Resampling.NEAREST)
            x, y = column * size, row * (size + header)
            sheet.alpha_composite(picture, (x + (size - picture.width) // 2, y + header))
            draw.text((x + 4, y + 4), caption, fill='white')
            receipts[str(path.relative_to(PROJECT))] = sha(path)
    sheet.save(capture / 'contact_sheet.webp', lossless=True, exact=True, method=6, quality=PROOF_DEFAULTS['webp_effort'])
    write(capture / 'contact_sheet.json', {'source_sha256': receipts, 'sha256': sha(capture / 'contact_sheet.webp'),
          'native_scale': '1024 px / 2.4 m, no figure-specific resizing', 'painting_scale': 4,
          'lancer_limitation': 'mq-14 delivery absent at this checkout; retained r3 native clay reference used.'})
    # Native proportion guide, with the approved reference alongside it.
    overlay = Image.new('RGBA', (2 * size, size + header), PROOF_DEFAULTS['background'])
    draw = ImageDraw.Draw(overlay)
    for column, path in enumerate((PROJECT / recipe['sources']['front'], capture / 'front_clay.png')):
        with Image.open(path) as image:
            picture = image.convert('RGBA')
        if column == 0:
            picture = picture.resize(tuple(d * 4 for d in picture.size), Image.Resampling.NEAREST)
        overlay.alpha_composite(picture, (column * size, header))
    result = json.loads((capture / 'mq15_acceptance.json').read_text())
    joints = json.loads((capture / 'joints_px.json').read_text())['front']
    annotation = recipe['mq15']['approved_front_annotations_px']
    native = json.loads((capture / 'native_probe.json').read_text())['objects']['bucket_helm_render']['views']['front']
    actual = {'helm_top': native['min'][1], 'helm_bottom': native['max'][1],
              'shoulder_row': np.mean([joints['shoulder_near'][1], joints['shoulder_far'][1]]),
              'pelvis_row': joints['pelvis'][1], 'knee_row': np.mean([joints['knee_near'][1], joints['knee_far'][1]]),
              'sole_bottom': result['proportions']['native_heights']['front']['sole_bottom_px']}
    for name, native_y in actual.items():
        for column, y in enumerate((annotation[name] * 4, native_y)):
            draw.line((column * size, y + header, (column + 1) * size - 1, y + header), fill=PROOF_DEFAULTS['guideline_colour'])
            offset = PROOF_DEFAULTS['label_offsets_px'].get(name, 2)
            draw.text((column * size + 4, y + header + offset), name, fill='white')
    save_annotation(overlay,capture/'proportion_overlay.webp')
    from .mass_gates import source_measurements, labels
    data,masks,reference=source_measurements(folder,PROJECT/recipe['sources']['front'])
    proof=Image.new('RGBA',(2*size,size),PROOF_DEFAULTS['background'])
    with Image.open(PROJECT/recipe['sources']['front']) as original:
        proof.alpha_composite(original.convert('RGBA').resize((1020,1020),Image.Resampling.NEAREST))
    with Image.open(capture/'front_parts.png') as parts:
        proof.alpha_composite(parts.convert('RGBA'),(size,0))
    draw=ImageDraw.Draw(proof)
    for label,polygon in data['source_masks'].items():
        if label in data.get('source_mask_files',{}):continue
        draw.line([tuple(4*v for v in p) for p in polygon+[polygon[0]]],fill=PROOF_DEFAULTS['guideline_colour'],width=1)
    for name,(label,y) in data['source_scanlines'].items():
        y=int(round(y)) # Same source row used by mass_gates.span.
        xs=np.flatnonzero(masks[label][y]);draw.line((int(xs[0])*4,y*4,int(xs[-1]+1)*4,y*4),fill='white',width=2)
        draw.text((int(xs[-1]+1)*4,y*4),name,fill='white')
    for label,(a,b) in data['source_arm_axes'].items():
        draw.line([tuple(4*v for v in p) for p in (a,b)],fill='white',width=1)
    native_masks=labels(capture/'front_parts.png',recipe['labels'])
    for name,observation in result['mass']['native_scanlines'].items():
        y=int(round(observation['row_px']));xs=np.flatnonzero(native_masks[observation['label']][y])
        draw.line((size+int(xs[0]),y,size+int(xs[-1]),y),fill='white',width=2)
        draw.text((size+int(xs[-1])+2,y),name,fill='white')
    save_annotation(proof,capture/'source_mass_landmarks.webp')
    from .cloth_gates import review_cloth
    review_cloth(folder,capture,result['mass']['cloth'],PROOF_DEFAULTS['background'],PROOF_DEFAULTS['guideline_colour'])
    from .pose_fit import outline_overlay
    outline_overlay(folder,capture,PROJECT,result['front_fit'])
    sheet_receipt=json.loads((capture/'contact_sheet.json').read_text())
    sheet_receipt['proof_artifacts_sha256']={name:sha(capture/name) for name in ('source_mass_landmarks.webp','proportion_overlay.webp','proportion_table.md','cloth_landmarks.webp','front_fit_overlay.webp')}
    write(capture/'contact_sheet.json',sheet_receipt)



def validate_acceptance(folder, capture):
    """Recompute from current native observations and pixels; never trust PASS alone."""
    path = Path(capture) / 'mq15_acceptance.json'
    retained = path.read_bytes()
    # Compute in a temporary copy so validation has no write side effects.
    import tempfile
    import shutil
    with tempfile.TemporaryDirectory(prefix='mq15_acceptance_') as temporary:
        temporary = Path(temporary)
        for source in Path(capture).iterdir():
            if source.is_file():
                shutil.copyfile(source, temporary / source.name)
        result = inspect(folder, temporary)
        if not result['passed'] or json.loads(retained) != result:
            raise ValueError('Missing, failed or stale mq-15 acceptance')
    return result
