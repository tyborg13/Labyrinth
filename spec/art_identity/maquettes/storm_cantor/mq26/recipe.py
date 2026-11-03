"""Opt-in mq-26 compiler: take-three forms on the mq-19 pose; mq-17/19 untouched.

Order: skeleton (hip and sash at the original's sprite heights) -> head, feet
and limb forms -> sprite-style width calibration -> torso and pauldrons ->
staff -> tabard -> mq-19 cloak generator on this body -> framing and contract.
"""
from copy import deepcopy
import json
import math
from pathlib import Path
import numpy as np

from spec.art_identity.maquettes.blender.contract import validate, digest
from spec.art_identity.maquettes.blender.curate_delivery import write
from spec.art_identity.maquettes.blender.faceted_forms import unit
from ..recipe import compile_spec as mq17_spec, FOLDER as BASE
from ..mq19.recipe import frame_spec, PROOF_CAMERA
from ..mq19.cloth import closed_surface
from .frames import Frames, screen_heights, screen_basis
from .layout import construction, design
from .skeleton import solve_skeleton, pose_rules
from . import body, limbs, staff as staff_forms, garments
from .proportions import measure, registered_height

FOLDER = Path(__file__).resolve().parent
CALIBRATION_DEFAULTS = {'passes': 3}
NATIVE_FEATURES = {
    'visor_slit': ('head', {'front': 'visible', 'rear': 'occluded'}),
    'bell': ('bell', {'front': 'visible', 'rear': 'occluded'}),
    'medallion': ('sash', {'front': 'visible', 'rear': 'occluded'}),
    'tabard_sigils': ('tabard', {'front': 'visible', 'rear': 'occluded'}),
    'pennant_sigils': ('staff', {'front': 'visible', 'rear': 'visible'}),
    'spine_ridge': ('torso', {'front': 'occluded'})}


def head_tine_points(c, H):
    out = []
    for side, sign in (('near', 1), ('far', -1)):
        t = c['helm']['tines'][side]
        root = np.array([t['root_x'], sign * t['root_y'], c['helm']['chin_z'] + t['root_above_chin']])
        out += [(root + np.array([x, sign * y, z])) * H for x, y, z in t['path']]
    return np.asarray(out)


def sole_points(j, c, H):
    pts = []
    for side in ('near', 'far'):
        a = j['ankle_' + side]
        for x, height, hw, ridge in c['sabaton_stations']:
            pts += [[a[0] + x * H, a[1] + s * hw * H, 0.] for s in (-1, 1)]
        pts.append([a[0] + c['sabaton_toe'] * H, a[1], c['sabaton_tip_height'] * H])
    return np.asarray(pts)


def sprite_height(spec, point, j, frames, c, H):
    """Height above the sole line over the registered H (the original's 232 px)."""
    sole = screen_heights(spec, sole_points(j, c, H)).min()
    return float((screen_heights(spec, [point])[0] - sole) / registered_height(spec))


def wrist_far(j, c, H, shaft_axis):
    h = c['hand']; s = unit(shaft_axis); fore = unit(j['hand_far'] - j['elbow_far'])
    f = unit(fore - s * (fore @ s)); n = unit(np.cross(s, f)) * h['grip_side']
    R = h['shaft_radius'] * H
    return j['hand_far'] - f * (R + h['palm_length'] * H * .75) + n * h['palm_length'] * H * .25


def lames(arm_radius, c):
    """Cap plus two flared lames, shingled down the upper arm (H units)."""
    p = c['pauldron']; heights = p['lame_heights']; r = arm_radius + p['clearance']
    s1 = .028
    cap_r1 = r + 2 * p['stack_step'] + p['flare']
    # The top lame's size is its full axial extent, its pointed peak included.
    # The cupped top rows tilt the plate's outer skin along the arm; lower the
    # nominal top by that overhang so the outer extent is the lame size.
    s0 = s1 - heights[0] + p['peak']
    for _ in range(3):
        slope = cap_r1 * (1 - p['cup_top_radius_fraction']) * math.pi / 2
        s0 = s1 - heights[0] + p['peak'] + p['thickness'] * slope / math.hypot(slope, s1 - (s0 - p['peak']))
    out = [{'s0': s0, 'crown': 0., 'r0': cap_r1 * p['cup_top_radius_fraction'], 'r1': cap_r1, 's1': s1}]
    top = s1 - .016
    for k, height in enumerate(heights[1:], 1):
        # A lame's size is its full axial extent, its pointed top peak included.
        radius = r + (2 - k) * p['stack_step']; band = height - p['peak']
        out.append({'s0': top, 's1': top + band, 'r0': radius, 'r1': radius + p['flare']})
        top += band - .016
    return out


def build(baseline, c, d):
    H = baseline['mq17']['height_m']; L = baseline['mq17']['leg_length_m']
    p = pose_rules()
    sole_fn = lambda j, f: sprite_height(baseline, (j['hip_near'] + j['hip_far']) / 2, j, f, c, H)
    def sash_fn(j, f, offset):
        centre = (j['hip_near'] + j['hip_far']) / 2 + f['pelvis'] @ np.array([0, 0, offset * H])
        return sprite_height(baseline, centre, j, f, c, H)
    def thigh(j):
        jj = dict(j)
        _, _, outer, _, _ = limbs.bend_frame(j['knee_near'] - j['hip_near'], j['ankle_near'] - j['knee_near'], [1., 0, 0])
        piece = limbs.plate_segment('thigh_plate_near', 'thigh_near', 'hip_near', j['hip_near'], j['knee_near'], outer,
                                    c['thigh_width'] * H, c['thigh_depth_ratio'], c['thigh_stations'], c['thigh_ridge'],
                                    (c['thigh_extend'][0] * H, c['thigh_extend'][1] * H))
        return piece['vertices']
    rest, j, frames, info = solve_skeleton(baseline, sole_fn, sash_fn, thigh)
    fr = Frames(rest['joints'], j, frames, H)
    from ..mq19.pose import staff_frame
    shaft_axis = staff_frame(p)[:, 2]
    jj = dict(j); jj['wrist_near'] = j['hand_near']; jj['wrist_far'] = wrist_far(j, c, H, shaft_axis)
    # The gauntlet cuff seats just outside the vambrace's tapered wrist end.
    c['hand']['cuff_radius'] = c['fore_width'] / 2 * c['fore_stations'][-1][1] * (1 + c['arm_ridge']) + c['elbow']['clearance']
    pieces = []
    helm = c['helm']
    toward = np.asarray(screen_basis(baseline, 'front')[2]); face = frames['head'].T @ toward; face[2] = 0
    helm['tine_face'] = (face / np.linalg.norm(face)).tolist()
    c['board_camera_toward'] = np.asarray(toward).tolist()
    cowl, cowl_grid = body.cowl(fr, helm, H)
    pieces += [body.helm(fr, helm, H), body.visor(fr, helm, H)] + body.tines(fr, helm, H) + [cowl]
    arm_pieces, elbow = limbs.arms(jj, c, H)
    leg_pieces, knee = limbs.legs(jj, c, H)
    pieces += arm_pieces + leg_pieces
    near_pieces, near_hand = limbs.near_hand(jj, fr, c, H)
    far_pieces, far_hand = limbs.far_hand(jj, fr, c, H, shaft_axis)
    pieces += near_pieces + far_pieces
    # Torso, in local coordinates about the rest hip centre.
    cg = c['cage']
    local_shoulder = fr.to_torso([j['shoulder_near'], j['shoulder_far']])
    def local_z_for(screen_ratio, x_local):
        # Solve the torso-local height whose posed point has the sprite height.
        p0 = fr.torso([[x_local, 0, 0.]])[0]; p1 = fr.torso([[x_local, 0, .1 * H]])[0]
        a0 = sprite_height(baseline, p0, j, frames, c, H); a1 = sprite_height(baseline, p1, j, frames, c, H)
        return .1 * (screen_ratio - a0) / (a1 - a0)
    a_max = cg['half_width_max']
    cg['centre_x'] = a_max * (cg['depth_to_width'] - cg['source_depth_to_width'])
    front = cg['centre_x'] + a_max * cg['depth_to_width']
    top_z = local_z_for(d['measured_original']['top_rib_over_H'], front)
    bottom_z = local_z_for(d['measured_original']['bottom_rib_over_H'], front)
    rib_z = list(np.linspace(top_z, bottom_z, d['brief']['ribs']['per_side']))
    cg['rib_z'] = rib_z
    cg['half_width'] = [(bottom_z - .04, .9 * a_max), (bottom_z, .95 * a_max), (rib_z[2], a_max), (top_z, .94 * a_max), (top_z + .03, .9 * a_max)]
    # The kept bell hangs inside the cage: mouth on the cage's lower edge at the
    # sternum, axis set back so the mouth clears the bands' inner faces.
    # Mouth on the cage's lower edge at the sternum; dome top just below the
    # sternum top. The kept lathe (0.09 H mouth) stretches only along its axis.
    mouth_z = bottom_z - cg['band_width'] / 2
    bell_height = rib_z[0] + cg['band_width'] / 2 - cg['bell_top_gap'] - mouth_z
    bell_scale = bell_height / (.18 / H)
    bell_rows = body.bell_lathe(c['bell_mouth'] / 2 * H, bell_scale)
    inner_front = cg['centre_x'] + (.95 * a_max - cg['band_thickness'] / 2) * cg['depth_to_width'] - cg['band_thickness'] / 2
    hook_local = np.array([inner_front - c['bell_mouth'] / 2 - cg['bell_inner_clearance'], 0., mouth_z + bell_height])
    sash_local_z = float(fr.to_pelvis([j['pelvis']])[0, 2] / H)
    s = c['sash']; s['centre_z'] = sash_local_z
    ratio = cg['depth_to_width']; sash_ratio = s['depth_to_width']
    cg['abdomen'] = [(bottom_z - .004, .95, ratio), (sash_local_z + s['height'] * .2, s['half_width'] / a_max * .95, sash_ratio),
                     (sash_local_z - s['height'] * .3, s['half_width'] / a_max * .9, sash_ratio)]
    cage_pieces, ribs = body.cage(fr, cg, H, hook_local, bell_rows)
    pieces += cage_pieces + [body.bell(fr, hook_local, c['bell_mouth'], H, bell_scale)]
    m = c['mantle']; neck = fr.to_torso([fr.head([[0, 0, -.022 * H]])[0]])[0] / H
    m['neck_centre'] = neck.tolist()
    m['hem_z'] = float(local_shoulder[:, 2].mean() / H)
    m['back_drop'] = m['drop']; m['front_v_z'] = rib_z[0] + cg['band_width'] * .3
    top_front = cg['half_width'][3][1] * cg['depth_to_width']
    m['hem_centre_x'] = cg['centre_x']
    m['hem_front_depth'] = top_front + cg['band_thickness'] / 2 + m['thickness']
    m['hem_back_depth'] = top_front + cg['plate_thickness'] * .5 + m['thickness']
    m['shear'] = baseline['mq17']['shoulder_shear']
    mantle, mantle_grid = body.mantle(fr, c, H)
    pieces.append(mantle)
    pieces.append(body.sash(fr, c, H))
    hip_local = fr.to_pelvis([j['hip_near'], j['hip_far']]) / H
    pp = c['pelvis_plate']
    pp['stations'] = [(sash_local_z - s['height'] * .45, s['half_width'] * .97, s['half_width'] * s['depth_to_width'] * .97),
                      (float(hip_local[:, 2].mean()) - .012, .086, .064), (float(hip_local[:, 2].mean()) - .06, .08, .058)]
    pieces.append(body.pelvis_plate(fr, c, H))
    arm_radius = max(limbs.max_radius_near(next(q for q in pieces if q['id'] == 'upper_plate_' + side), j['shoulder_' + side],
                                           j['elbow_' + side] - j['shoulder_' + side], .12 * H) for side in ('near', 'far')) / H
    c['pauldron']['lames'] = lames(arm_radius, c)
    pauldron_pieces, hems, spikes = limbs.pauldrons(j, fr, c, H)
    pauldron_ranges = hems.pop('_ranges')
    pieces += pauldron_pieces
    staff_pieces, staff_info = staff_forms.staff(baseline, j, p, c, H)
    pieces += staff_pieces
    supports = [q for q in pieces if q['id'] in ('pelvis_plate', 'thigh_plate_near', 'thigh_plate_far',
                                                 'knee_cop_near', 'knee_cop_far', 'shin_plate_near', 'shin_plate_far')]
    c['tabard']['top_z'] = sash_local_z - s['height'] * .35
    tabard, sigils, tabard_design, grid = garments.tabard(fr, j, c, baseline, supports, H)
    pieces += [tabard, sigils]
    local_tabard = fr.to_pelvis(tabard['vertices']).reshape(2, grid[0], grid[1], 3) / H
    def tabard_front(z):
        centre = local_tabard[:, :, grid[1] // 2]
        x = centre[..., 0].max(0); zs = centre[..., 2].mean(0)
        return float(np.interp(z, zs[::-1], x[::-1]))
    pieces += body.sash_front(fr, c, H, tabard_front)
    joints = {k: np.asarray(v, float) for k, v in j.items()}
    joints['bell_hook'] = fr.torso([hook_local * H])[0]
    joints['hand_tip_near'] = np.asarray(near_hand['hand_tip']); joints['hand_tip_far'] = np.asarray(far_hand['hand_tip'])
    for side in ('near', 'far'):
        joints['foot_tip_' + side] = np.array([j['ankle_' + side][0] + c['sabaton_toe'] * H, j['ankle_' + side][1], c['sabaton_tip_height'] * H])
    layout = {'elbow_cops': elbow, 'knee_cops': knee, 'near_hand': near_hand, 'far_hand': far_hand, 'staff': staff_info,
              'ribs': ribs, 'rib_z_local_over_H': rib_z, 'cowl_grid': cowl_grid, 'bell_height_scale': bell_scale, 'hook_local_over_H': hook_local.tolist(),
              'support_hems': {'hood_mantle': {'grid': [mantle_grid['rows'], mantle_grid['columns']]}, **hems},
              'pauldron_spikes': spikes, 'pauldron_ranges': pauldron_ranges, 'wrists': {'near': jj['wrist_near'].tolist(), 'far': jj['wrist_far'].tolist()},
              'skeleton': info, 'tabard_grid': grid, 'frames': {k: np.asarray(v).tolist() for k, v in frames.items()},
              'rest_joints': rest['joints']}
    return pieces, joints, layout, tabard_design, info, rest


def calibrate(baseline, d):
    """Sprite-style widths: rescale each 3D width until the capture measures the original."""
    H = baseline['mq17']['height_m']; b = d['brief']; c = construction(d)
    c['cage']['half_width_max'] = b['chest_across_over_H'] / 2 * 1.1
    c['sash']['half_width'] = b['waist_sash_across_over_H'] / 2 * 1.1
    targets = {'thigh_width': ('thigh_width', b['thigh_width_over_H']), 'shin_width': ('shin_width', b['shin_width_over_H']),
               'upper_width': ('upper_arm_width', b['upper_arm_width_over_H']), 'fore_width': ('forearm_width', b['forearm_width_over_H'])}
    history = []
    for _ in range(CALIBRATION_DEFAULTS['passes']):
        trial = deepcopy(c)
        pieces, joints, layout, _, _, _ = build(baseline, trial, d)
        points = {q['id'] + '_render': q['vertices'] for q in pieces}
        observed = measure(baseline, points, joints, H, {q['id'] + '_render': q['faces'] for q in pieces})
        history.append({k: v['screen_over_H'] for k, v in observed.items() if isinstance(v, dict)})
        for key, (name, goal) in targets.items():
            c[key] *= goal / observed[name]['screen_over_H']
        c['cage']['half_width_max'] *= b['chest_across_over_H'] / observed['chest']['screen_over_H']
        c['sash']['half_width'] *= b['waist_sash_across_over_H'] / observed['waist_sash']['screen_over_H']
    return c, history


def compile_spec():
    d = design(); baseline = mq17_spec(); H = baseline['mq17']['height_m']; L = baseline['mq17']['leg_length_m']
    c, history = calibrate(baseline, d)
    pieces, joints, layout, tabard_design, info, rest = build(baseline, deepcopy(c), d)
    spec = deepcopy(baseline)
    spec['pieces'] = pieces
    spec['joints'] = {k: np.asarray(v, float).tolist() for k, v in joints.items()}
    frames = {k: np.asarray(v) for k, v in layout['frames'].items()}
    spec['volume_layout']['tabard_grid'] = layout['tabard_grid']
    spec['native_features'] = {name: {'part': part, 'objects': [name], 'visibility': vis} for name, (part, vis) in NATIVE_FEATURES.items()}
    spec['native_features']['ribs'] = {'part': 'torso', 'objects': layout['ribs'], 'visibility': {'front': 'visible'}}
    spec['mq17']['staff_components'] = layout['staff']['components']
    spec['mq17']['staff'] = {**spec['mq17']['staff'], 'butt': layout['staff']['butt'], 'fork_base': layout['staff']['fork_base']}
    pose = pose_rules()
    spec['mq19'] = {'design': {'pose': pose, 'authority': 'mq-19 pose rules (kept by mq-26); near knuckles per mq-26 hand v3',
                               'pose_resolution': info['pose_resolution'], 'tabard': tabard_design},
                    'gauge_H_m': H, 'gauge_L_m': L, 'bone_forward': {k: r[:, 0].tolist() for k, r in frames.items()},
                    'diagnostic_only': False, 'capture_px': PROOF_CAMERA['canvas_px'],
                    'reference_ortho_scale': baseline['ortho_scale'],
                    'staff_butt': layout['staff']['butt'], 'staff_fork_base': layout['staff']['fork_base']}
    decisions = d['construction']['director_decisions']
    accepted = {row: item['value'] for item in decisions.values() for row in item.get('accepted_rows', [])}
    spec['mq26'] = {'design_sha256': digest(d), 'brief': d['brief'], 'measured_original': d['measured_original'],
                    'director_accepted_rows': accepted,
                    'director_decisions': {k: v['value'] for k, v in decisions.items()},
                    'construction': json.loads(json.dumps(c)), 'calibration': history,
                    **{k: v for k, v in layout.items() if k not in ('frames',)}}
    generated = garments.cloak(spec)
    seam = {i: direction for i, direction in zip(generated['surface']['layout']['shoulder_indices'],
                                                 generated['surface']['layout']['attachment_normals'])}
    piece, cloak_layout = closed_surface('full_back_cloak', 'cloak', 'torso',
        np.asarray(generated['surface']['vertices_over_H'], float) * H, generated['surface']['faces'],
        generated['thickness_over_H'] * H, horizontal_tips=[v['tip_index'] for v in generated['surface']['layout']['strips']],
        edge_normals=seam)
    cloak_layout.update(generated['surface']['layout'])
    spec['pieces'].append(piece)
    spec['mq19']['cloak_layout'] = cloak_layout
    cloak_rules = {k: v for k, v in generated.items() if k not in ('surface', 'removed_quads')}
    cloak_rules['surface'] = {'generated_mesh_sha256': digest(generated['surface'])}
    cloak_rules['removed_quads'] = {'count': len(generated['removed_quads']), 'sha256': digest(generated['removed_quads'])}
    spec['mq19']['design']['cloak'] = cloak_rules
    spec['delivery_reports'] = ['mq26_native.json', 'mq26_acceptance.json']
    frame_spec(spec)
    validate(spec)
    return spec


def main():
    import argparse
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--out', type=Path, required=True)
    args = parser.parse_args()
    result = compile_spec(); write(args.out, result)
    print('MQ26_SPEC: PASS; pieces=' + str(len(result['pieces'])) + '; ' + str(args.out))


if __name__ == '__main__': main()
