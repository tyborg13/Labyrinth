"""Negative proofs on copied opened-native (or compiled) arrays; never on the model.

Each mutation changes one named form and must fail its own gate, on top of a
passing baseline: a cop swapped back to a ball; ribs turned to face the camera
or straightened into face-on bars; near fingers fused into a mitten; far
fingers unwrapped from the shaft; the staff detached from the grip.
"""
import math
import numpy as np

from ..mq19.pose import rotation
from ..mq19.drape_checks import front_exposure
from . import checks as gates
from .hand_capture import portable as hand_capture

MUTATION_DEFAULTS = {'ball_radius_over_H': .04, 'camera_yaw_degrees': 39., 'staff_shift_over_L': 1., 'stub_scale': .3,
                     'bell_shift_over_H': .05, 'hump_over_H': .03}


def far_exposure(spec, points, faces):
    """mq-19's far-side cloak exposure, with the take-three far hand as the staff hand."""
    pts = dict(points)
    pts['gauntlet_far_render'] = np.concatenate([np.asarray(v) for n, v in points.items()
                                                 if n.endswith('_far_render') and (n.startswith(('finger_', 'thumb_', 'palm_')))])
    return front_exposure(spec, pts, faces)


def ball(points, name, centre, radius):
    v = np.asarray(points[name], float) - centre
    return centre + v / np.linalg.norm(v, axis=1)[:, None] * radius


def native_mutations(spec, points, joints, forwards, faces):
    H = spec['mq19']['gauge_H_m']; L = spec['mq19']['gauge_L_m']
    pts = {k: np.asarray(v, float) for k, v in points.items()}
    j = {k: np.asarray(v, float) for k, v in joints.items()}; jj = gates.joint_points(spec, j)
    out = {}
    def record(name, gate, value, detail=None):
        out[name] = {'gate': gate, 'caught': bool(not value), 'detail': detail}
    for kind, joint in (('elbow', 'elbow_near'), ('knee', 'knee_near')):
        m = dict(pts); m[kind + '_cop_' + joint.split('_')[1] + '_render'] = ball(pts, kind + '_cop_near_render', j[joint], MUTATION_DEFAULTS['ball_radius_over_H'] * H)
        r = gates.sphere_gate(spec, m, faces, jj, joints=[joint])
        record(kind + '_cop_swapped_for_ball', 'no_spherical_joints', r['passed'],
               {v: {k: (x['sphere_fraction'], x['normal_isotropy']) for k, x in rows.items() if x['applicable']} for v, rows in r['views'].items()})
    ribs = [n for n in pts if n.startswith('rib_')]
    centre = j['torso']
    turn = rotation([0, 0, 1], MUTATION_DEFAULTS['camera_yaw_degrees'])
    m = dict(pts)
    for n in ribs: m[n] = centre + (pts[n] - centre) @ turn.T
    r = gates.ribs(spec, m, j, forwards)
    record('ribs_turned_to_face_camera', 'ribs.cage_follows_chest_yaw', r['checks']['cage_follows_chest_yaw'],
           [row['cage_yaw_minus_chest_yaw_degrees'] for row in r['rows']])
    frame = gates.chest_frame(j, forwards); m = dict(pts)
    for n in ribs:
        # A straight lateral bar facing the chest front: no wrap, no curvature.
        local = ((pts[n] - centre) @ frame).reshape(2, gates.RIB_ROWS, -1, 3)
        sign = 1. if n.startswith('rib_near') else -1.
        reach = abs(local[..., 1]).max()
        local[..., 0] = local[..., 0].max()
        local[..., 1] = sign * np.linspace(0, reach, local.shape[2])
        m[n] = centre + local.reshape(-1, 3) @ frame.T
    r = gates.ribs(spec, m, j, forwards)
    record('ribs_flattened_to_face_on_bars', 'ribs.plan_curvature_reverses_across_sternum',
           r['checks']['plan_curvature_reverses_across_sternum'] and r['checks']['screen_curvature_reverses_across_sternum'],
           [(row['plan_turn_near_degrees'], row['plan_turn_far_degrees']) for row in r['rows']])
    rows, info = gates.pose_rows(spec, j, forwards, pts)
    m = dict(pts)
    for i in range(4):
        for k in range(3): m['finger_%d_near_%d_render' % (i, k)] = pts['finger_1_near_%d_render' % k]
    hands = gates.hands(spec, m, info); capture = hand_capture(spec, m, faces)
    record('near_fingers_fused', 'hands.near_knuckle_curls_and_spread + near capture separation',
           hands['checks']['near_knuckle_curls_and_spread'] or capture['near']['passed'],
           {'spread_degrees': hands['near_spread_degrees'], 'capture_separated': capture['near']['passed']})
    m = dict(pts)
    for i in range(4):
        first = pts['finger_%d_far_0_render' % i]; start, end, _ = gates.phalanx_axis(first)
        step = end - start
        for k in (1, 2):
            source = pts['finger_%d_far_%d_render' % (i, k)]; s0, _, _ = gates.phalanx_axis(source)
            # Straight finger: each phalanx continues the proximal axis, unbent.
            direction = step / np.linalg.norm(step)
            target = end + direction * np.linalg.norm(step) * (k - 1)
            local = source - s0
            axis = gates.phalanx_axis(source)[1] - s0; axis /= np.linalg.norm(axis)
            v = np.cross(axis, direction); s = np.linalg.norm(v); c = axis @ direction
            if s > 1e-9:
                k_ = v / s; K = np.array([[0, -k_[2], k_[1]], [k_[2], 0, -k_[0]], [-k_[1], k_[0], 0]])
                R = np.eye(3) + s * K + (1 - c) * K @ K
            else:
                R = np.eye(3)
            m['finger_%d_far_%d_render' % (i, k)] = target + local @ R.T
    hands = gates.hands(spec, m, info)
    record('far_fingers_unwrapped', 'hands.far_fingers_wrap_shaft', hands['checks']['far_fingers_wrap_shaft'], hands['far_wrap_degrees'])
    # Round-2 forms: tines, droop, the bell inside, the hood crown and fall, the open cup.
    m = dict(pts)
    for side in ('near', 'far'):
        name = 'helm_tine_' + side + '_render'; root = pts[name][:4].mean(0)
        m[name] = root + (pts[name] - root) * MUTATION_DEFAULTS['stub_scale']
    helm = gates.helm(spec, m, j, forwards); seen = gates.tine_visibility(spec, m, faces)
    record('tines_shrunk_to_stubs', 'helm tine rises + tines_above_hood',
           helm['checks']['far_tine_rise_above_crown'] or all(seen['checks'].values()),
           {k: v['rise_above_crown_over_H'] for k, v in helm['tines'].items()})
    m = dict(pts)
    for n in ribs:
        local = ((pts[n] - centre) @ frame).reshape(2, gates.RIB_ROWS, -1, 3)
        # Undo the arc: every station keeps the sternum station's height offset.
        line = local.mean(axis=(0, 1)); local[..., 2] -= (line[:, 2] - line[0, 2])
        m[n] = centre + local.reshape(-1, 3) @ frame.T
    r = gates.ribs(spec, m, j, forwards)
    record('ribs_without_droop', 'ribs.rib_droop_sternum_to_flank', r['checks']['rib_droop_sternum_to_flank'], r['droop_over_H'][:2])
    m = dict(pts); m['bell_render'] = pts['bell_render'] + frame[:, 0] * MUTATION_DEFAULTS['bell_shift_over_H'] * H
    r = gates.ribs(spec, m, j, forwards)
    record('bell_pushed_out_of_cage', 'ribs.bell_inside_cage', r['checks']['bell_inside_cage'], r['bell']['values'])
    m = dict(pts); nr, nc = spec['mq26']['support_hems']['hood_mantle']['grid']; v = pts['hood_mantle_render'].copy(); count = nr * nc
    hc = (j['hip_near'] + j['hip_far']) / 2
    for skin in (0, count):
        for row in range(1, nr - 1):
            for col in range(nc):
                k = skin + row * nc + col; phi = math.tau * col / nc
                if math.cos(phi) < -.5:
                    v[k] -= frame[:, 0] * MUTATION_DEFAULTS['hump_over_H'] * H * math.sin(math.pi * row / (nr - 1))
    m['hood_mantle_render'] = v
    r = gates.hood_fall(spec, m, j, forwards)
    record('mantle_back_humped', 'hood_fall.mantle_back_concave_no_hump', r['checks']['mantle_back_concave_no_hump'], r['maximum_outward_bulge_over_H'])
    m = dict(pts); nr, nc = spec['mq26']['cowl_grid']; v = pts['hood_cowl_render'].copy(); count = nr * nc
    for skin in (0, count):
        v[skin + (nr - 1) * nc: skin + nr * nc] = v[skin + (nr - 3) * nc: skin + (nr - 2) * nc]
        v[skin + (nr - 2) * nc: skin + (nr - 1) * nc] = v[skin + (nr - 3) * nc: skin + (nr - 2) * nc]
    m['hood_cowl_render'] = v
    r = gates.helm(spec, m, j, forwards)
    record('hood_crown_rounded_off', 'helm.hood_crown_point', r['checks']['hood_crown_point'], r['hood_point_above_helm_back_over_H'])
    m = dict(pts); ranges = spec['mq26']['pauldron_ranges']['far']; a, c = ranges['lames'][0]
    axis = np.asarray(ranges['axes'][0]); shoulder = j['shoulder_far']; v = pts['pauldron_far_render'].copy()
    lame = v[a:c] - shoulder; turned = shoulder + lame @ rotation(axis, 180.).T
    v = np.concatenate([v[:a], np.concatenate([v[a:c], turned]), v[c:]])
    shifted = dict(spec['mq26']['pauldron_ranges']); far = dict(ranges)
    far['lames'] = [[a, c + (c - a)]] + [[x + (c - a), y + (c - a)] for x, y in ranges['lames'][1:]]
    far['spikes'] = [[x + (c - a), y + (c - a)] for x, y in ranges['spikes']]
    shifted['far'] = far; probe = dict(spec); probe['mq26'] = dict(spec['mq26'], pauldron_ranges=shifted)
    m['pauldron_far_render'] = v
    r = gates.pauldrons(probe, m, j)
    record('far_top_lame_closed_into_a_can', 'pauldrons.far_top_lame_open_not_a_can', r['checks']['far_top_lame_open_not_a_can'],
           r['sides']['far']['top_lame_open_gap_degrees'])
    m = dict(pts); m['staff_render'] = pts['staff_render'] + np.array([L * MUTATION_DEFAULTS['staff_shift_over_L'], 0, 0])
    rows, _ = gates.pose_rows(spec, j, forwards, m)
    record('detached_staff', 'pose_values', all(r['passed'] for r in rows))
    return out
