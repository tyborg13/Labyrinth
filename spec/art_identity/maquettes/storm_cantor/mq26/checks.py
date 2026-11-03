"""mq-26 observations on compiled (portable) or opened native geometry.

Pose rows, shoulder/turn/facing, cloak and tabard reuse mq-19's observers;
the take-three forms add proportions, cops, helm, ribs, pauldrons, sabatons,
fork, hands and the joint-sphericity gate. Nothing reads recipe targets back
as measurements: every value comes from vertices, faces and joints.
"""
import math
import numpy as np

from spec.art_identity.maquettes.blender.facing import axis_report
from spec.art_identity.maquettes.blender import joint_sphericity as sphericity
from spec.art_identity.maquettes.raster import camera, project
from ..native_checks import angle
from ..mq19.pose import rotation
from ..mq19.checks import captured_pose_gates, observe_cloak, observe_tabard
from .proportions import measure as measure_proportions, registered_height, screen

CHECK_DEFAULTS = {'angle_tolerance_degrees': 1., 'ratio_tolerance': .01, 'native_tolerance_m': 1e-5,
                  'form_tolerance_over_H': .0015, 'proportion_tolerance_fraction': .10,
                  'sphere_window_over_H': .04, 'sphere_fraction_limit': .5, 'sphere_isotropy_limit': .45,
                  'rib_yaw_tolerance_degrees': 2., 'rib_minimum_turn_degrees': 10.,
                  'wrap_minimum_degrees': 150., 'apex_tolerance_m': 1e-6, 'tine_visible_extent_over_H': .06, 'open_lame_gap_degrees': 50.}
JOINTS = ['elbow_near', 'elbow_far', 'knee_near', 'knee_far', 'hand_near', 'wrist_far', 'ankle_near', 'ankle_far',
          'shoulder_near', 'shoulder_far']


def unit(v):
    v = np.asarray(v, float); return v / np.linalg.norm(v)


def chest_frame(j, forwards):
    spine = j['head'] - j['torso']; up = unit(spine); anterior = unit(forwards['torso'])
    return np.column_stack([anterior, np.cross(up, anterior), up])


# ------------------------------------------------------------- pose rows ---
def pose_rows(spec, j, forwards, pts):
    """mq-19 §1-9 rows (its finger rows are superseded by the mq-26 hand rows)."""
    p = spec['mq19']['design']['pose']; H = spec['mq19']['gauge_H_m']; L = spec['mq19']['gauge_L_m']; rows = []
    def add(number, name, target, value, angular=False):
        tolerance = CHECK_DEFAULTS['angle_tolerance_degrees'] if angular else CHECK_DEFAULTS['ratio_tolerance']
        rows.append({'requirement': number, 'name': name, 'target': target, 'measured': float(value),
                     'tolerance': tolerance, 'passed': bool(abs(value - target) <= tolerance)})
    for side in ('near', 'far'):
        add(1, side + '_knee_degrees', p[side + '_knee_degrees'], angle(j['knee_' + side] - j['hip_' + side], j['ankle_' + side] - j['knee_' + side]), True)
    hips = j['hip_near'] - j['hip_far']
    add(2, 'pelvis_down_near_degrees', p['pelvis_down_near_degrees'], math.degrees(math.atan2(-hips[2], hips[1])), True)
    spine = j['head'] - j['torso']; facing = rotation([0, 0, 1], p['chest_yaw_toward_viewer_degrees'])[:, 0]
    add(2, 'forward_lean_degrees', p['forward_lean_degrees'], math.degrees(math.atan2(spine @ facing, spine[2])), True)
    head, chest, pelvis = (np.asarray(forwards[k], float) for k in ('head', 'torso', 'pelvis'))
    yaw = lambda v: math.degrees(math.atan2(v[1], v[0]))
    add(3, 'chest_yaw_toward_viewer_degrees', p['chest_yaw_toward_viewer_degrees'], yaw(chest) - yaw(pelvis), True)
    add(4, 'head_down_degrees', p['head_down_degrees'], math.degrees(math.atan2(-head[2], np.linalg.norm(head[:2]))), True)
    add(4, 'head_matches_chest_yaw', 0, yaw(head) - yaw(chest), True)
    frame = chest_frame(j, forwards)
    W = abs(((j['shoulder_near'] - j['shoulder_far']) @ frame)[1])
    add(5, 'ankle_span_over_shoulders', p['ankle_span_over_shoulders'], abs(j['ankle_near'][1] - j['ankle_far'][1]) / W)
    add(6, 'near_step_over_L', p['near_step_over_L'], (j['ankle_near'][0] - j['ankle_far'][0]) / L)
    fist, shoulder = j['hand_far'], j['shoulder_far']
    add(7, 'fist_height_over_H', p['fist_height_over_H'], fist[2] / H)
    add(7, 'fist_forward_over_L', p['fist_forward_over_L'], (fist[0] - shoulder[0]) / L)
    add(7, 'fist_outward_over_L', p['fist_outward_over_L'], -(fist[1] - shoulder[1]) / L)
    staff = pts['staff_render']; a, b = spec['mq17']['staff_components']['shaft']
    shaft = staff[a:b].reshape(-1, 12, 3).mean(1); axis = unit(shaft[-1] - shaft[0])
    add(7, 'staff_from_vertical_degrees', p['staff_from_vertical_degrees'], angle(axis, [0, 0, 1]), True)
    add(7, 'staff_forward_degrees', p['staff_forward_degrees'], math.degrees(math.atan2(axis[0], axis[2])), True)
    add(7, 'staff_butt_sole_over_H', 0, staff[a:a + 12, 2].min() / H)
    add(7, 'staff_grip_axis_distance_over_L', 0, np.linalg.norm(np.cross(fist - shaft[0], axis)) / L)
    v = j['elbow_far'] - shoulder; reach = unit(fist - shoulder); v -= reach * (v @ reach)
    pole = v - reach * (v[0] / reach[0])
    add(8, 'far_elbow_outward_degrees', p['far_elbow_outward_degrees'], math.degrees(math.atan2(-pole[1], -pole[2])), True)
    upper = (j['elbow_near'] - j['shoulder_near']) @ frame; fore = (j['hand_near'] - j['elbow_near']) @ frame
    add(9, 'near_upper_out_degrees', p['near_upper_out_degrees'], math.degrees(math.asin(upper[1] / np.linalg.norm(upper))), True)
    add(9, 'near_elbow_degrees', p['near_elbow_degrees'], angle(upper, fore), True)
    add(9, 'near_wrist_ahead_over_L', p['near_wrist_ahead_over_L'], (j['hand_near'][0] - pts['thigh_plate_near_render'][:, 0].max()) / L)
    return rows, {'shaft_axis': axis, 'shaft_base': shaft[0], 'W': W, 'frame': frame, 'fore': fore, 'upper': upper}


# ----------------------------------------------------------------- hands ---
def phalanx_axis(vertices):
    v = np.asarray(vertices); sides = 6
    start = v[:sides].mean(0)
    end = v[-1] if len(v) == 2 * sides + 1 else v[sides:2 * sides].mean(0)
    return start, end, float(np.linalg.norm(v[0] - v[3]))


def digit_chain(pts, prefix, count):
    out = [phalanx_axis(pts[prefix + str(k) + '_render']) for k in range(count)]
    return out


def hands(spec, pts, info):
    H = spec['mq19']['gauge_H_m']; b = spec['mq26']['brief']['hand']; rows = {}; checks = {}
    tol = CHECK_DEFAULTS['form_tolerance_over_H']
    palm = np.asarray(pts['palm_near_render']); centred = palm - palm.mean(0)
    normal = np.linalg.svd(centred, full_matrices=False)[2][-1]
    fingers = [digit_chain(pts, 'finger_' + str(i) + '_near_', 3) for i in range(4)]
    tip = np.mean([f[-1][1] for f in fingers], axis=0)
    if (tip - palm.mean(0)) @ normal < 0: normal = -normal
    directions = [[unit(e - s) for s, e, w in f] for f in fingers]
    curls = []
    for i, d in enumerate(directions):
        mcp = math.degrees(math.asin(np.clip(d[0] @ normal, -1, 1)))
        curls.append([mcp, angle(d[0], d[1]), angle(d[1], d[2])])
    spreads = []
    for a, c in zip(directions, directions[1:]):
        pa = unit(a[0] - normal * (a[0] @ normal)); pc = unit(c[0] - normal * (c[0] @ normal))
        spreads.append(angle(pa, pc))
    widths = {'base_over_H': [f[0][2] / H for f in fingers],
              'claw_ring_over_H': [float(np.linalg.norm(np.asarray(pts['finger_' + str(i) + '_near_2_render'])[6] -
                                                         np.asarray(pts['finger_' + str(i) + '_near_2_render'])[9]) / H) for i in range(4)]}
    claws = all(len(pts['finger_' + str(i) + '_' + s + '_2_render']) == 13 for i in range(4) for s in ('near', 'far')) and \
        all(len(pts['thumb_' + s + '_1_render']) == 13 for s in ('near', 'far'))
    near_ok = (len(fingers) == 4 and all(abs(c - t) <= CHECK_DEFAULTS['angle_tolerance_degrees'] for row in curls for c, t in zip(row, b['near_knuckle_curls_degrees'])) and
               all(abs(s - b['near_finger_spread_degrees']) <= CHECK_DEFAULTS['angle_tolerance_degrees'] for s in spreads))
    checks['near_four_fingers_three_phalanges_thumb_two'] = all(('finger_%d_near_%d_render' % (i, k)) in pts for i in range(4) for k in range(3)) and \
        all(('thumb_near_%d_render' % k) in pts for k in range(2)) and 'thumb_near_2_render' not in pts and 'finger_0_near_3_render' not in pts
    checks['far_four_fingers_three_phalanges_thumb_two'] = all(('finger_%d_far_%d_render' % (i, k)) in pts for i in range(4) for k in range(3)) and \
        all(('thumb_far_%d_render' % k) in pts for k in range(2))
    checks['near_knuckle_curls_and_spread'] = bool(near_ok)
    checks['finger_widths'] = bool(all(abs(w - b['finger_width_base_over_H']) <= tol for w in widths['base_over_H']) and
                                   all(abs(w - b['finger_width_tip_over_H']) <= tol for w in widths['claw_ring_over_H']))
    checks['pointed_claws'] = bool(claws)
    # Far grip: every finger sweeps around the shaft at a seated radius; the
    # thumb crosses over the top (above the index finger) the other way round.
    axis = info['shaft_axis']; base = info['shaft_base']
    radius_frame = None; wraps = []; radii = []
    def polar(p):
        r = p - base; r = r - axis * (r @ axis)
        return r
    ref = polar(digit_chain(pts, 'finger_0_far_', 3)[0][0]); ref = unit(ref); other = np.cross(axis, ref)
    def theta(p):
        r = polar(p); return math.degrees(math.atan2(r @ other, r @ ref))
    for i in range(4):
        chain = digit_chain(pts, 'finger_' + str(i) + '_far_', 3)
        points = [chain[0][0]] + [e for s, e, w in chain]
        angles = np.unwrap(np.radians([theta(q) for q in points]))
        wraps.append(float(abs(math.degrees(angles[-1] - angles[0]))))
        radii += [float(np.linalg.norm(polar(q)) / H) for q in points]
    thumb = digit_chain(pts, 'thumb_far_', 2); index = digit_chain(pts, 'finger_0_far_', 3)
    thumb_height = float(np.mean([(e - base) @ axis for s, e, w in thumb])); index_height = float(np.mean([(e - base) @ axis for s, e, w in index]))
    t_angles = np.unwrap(np.radians([theta(thumb[0][0])] + [theta(e) for s, e, w in thumb]))
    f_angles = np.unwrap(np.radians([theta(index[0][0])] + [theta(e) for s, e, w in index]))
    shaft_r = spec['mq26']['construction']['shaft_radius']
    checks['far_fingers_wrap_shaft'] = bool(min(wraps) >= CHECK_DEFAULTS['wrap_minimum_degrees'] and
                                            min(radii) >= shaft_r * .95 and max(radii) <= shaft_r + 2 * b['finger_width_base_over_H'])
    checks['far_thumb_over_the_top'] = bool(thumb_height > index_height and (t_angles[-1] - t_angles[0]) * (f_angles[-1] - f_angles[0]) < 0)
    return {'checks': checks, 'near_curls_degrees': curls, 'near_spread_degrees': spreads, 'widths': widths,
            'far_wrap_degrees': wraps, 'far_radius_over_H': [min(radii), max(radii)],
            'thumb_height_over_index_m': thumb_height - index_height,
            'definition': 'Phalanx axes from opened ring centroids; MCP curl is the proximal axis out of the palm plane (palm PCA normal), '
                          'PIP/DIP the angles between successive phalanx axes; spread is between adjacent proximal axes in the palm plane. '
                          'Far wrap: angular sweep of each finger\'s joint points about the measured shaft axis.'}


# ------------------------------------------------------------------ cops ---
def cops(spec, pts, j, jj):
    H = spec['mq19']['gauge_H_m']; b = spec['mq26']['brief']; tol = CHECK_DEFAULTS['form_tolerance_over_H']; out = {}; checks = {}
    for kind, chain in (('elbow', ('shoulder', 'elbow', 'hand')), ('knee', ('hip', 'knee', 'ankle'))):
        target = b[kind + '_cop']
        for side in ('near', 'far'):
            a0, joint, c0 = (np.asarray(jj[n + '_' + side]) for n in chain)
            proximal = unit(joint - a0); distal = unit(c0 - joint)
            v = np.asarray(pts[kind + '_cop_' + side + '_render']) - joint
            outer = unit(proximal - distal)
            reach_p = float((v @ -proximal).max()); reach_d = float((v @ distal).max())
            seat = spec['mq26'][kind + '_cops'][kind + '_' + side]['seated_radius_over_H'] * H
            radial = np.linalg.norm(v - np.outer(v @ outer, outer), axis=1)
            apex = float((v @ outer).max()); plate = float(np.percentile(np.linalg.norm(v, axis=1), 50))
            # The apex rises above the plate's outer surface (seat + thickness).
            thickness = spec['mq26']['construction'][kind]['thickness'] * H
            beyond = apex - seat - thickness
            row = {'proximal_overlap_over_H': reach_p / H, 'distal_overlap_over_H': reach_d / H,
                   'point_beyond_plate_over_H': beyond / H, 'apex_direction_vs_outer_degrees': angle(v[np.argmax(v @ outer)], outer)}
            # Measured overlap includes the plate's own radius around a bend; take the axial reach of the straight runs.
            row['overlap_definition'] = 'max axial reach of cop vertices along each neighbouring segment beyond the joint'
            ok_point = abs(row['point_beyond_plate_over_H'] - target['point_beyond_over_H']) <= tol
            ok_overlap = all(r / H >= target['overlap_over_H'] - tol for r in (reach_p, reach_d))
            checks[kind + '_cop_' + side] = bool(ok_point and ok_overlap)
            out[kind + '_' + side] = row
    return {'checks': checks, 'rows': out}


# ------------------------------------------------------------------ helm ---
def helm(spec, pts, j, forwards):
    H = spec['mq19']['gauge_H_m']; b = spec['mq26']['brief']['helm']; tol = CHECK_DEFAULTS['form_tolerance_over_H']
    head = unit(forwards['head']); up = unit(j['head_tip'] - j['head']); up = unit(up - head * (up @ head)); side = np.cross(up, head)
    def local(name):
        v = np.asarray(pts[name + '_render']) - j['head']
        return np.column_stack([v @ head, v @ side, v @ up])
    helm_v = local('great_helm'); count = 9
    rings = helm_v.reshape(-1, count, 3)
    face = rings[:, [0, 1, 2, 6, 7, 8]]
    width = float(np.ptp(face[..., 1].reshape(-1)) / H)
    zs = face[..., 2]; height = float((rings[:, [0, 8], 2].max() - rings[:, [0, 8], 2].min()) / H)
    visor = local('visor_slit')
    groove = (rings[:, 0, 2] >= visor[:, 2].min() - .005 * H) & (rings[:, 0, 2] <= visor[:, 2].max() + .005 * H)
    # Ridge vs facets: outside the visor groove the ridge is the most forward
    # column of each ring, then the crease, then the face-plate edge.
    ridge_front = bool(np.all(rings[~groove][:, [0, 8], 0].mean(1) >= rings[~groove][:, [1, 7], 0].mean(1) - 1e-9) and
                       np.all(rings[:, [1, 7], 0].mean(1) >= rings[:, [2, 6], 0].mean(1) - 1e-9))
    v_width = float(np.ptp(visor[:, 1]) / H); v_height = float(np.ptp(visor[:, 2]) / H)
    # Recess: depth of the visor front below the two inner facets, extended
    # across the slit from their creases with the facet slope of the nearest
    # rings outside the groove.
    ridge = rings[:, [0, 8]].mean(1); crease = rings[:, [1, 7]]
    slope = (ridge[:, 0] - crease[..., 0].mean(1)) / abs(crease[..., 1]).mean(1)
    outside = (ridge[:, 2] < visor[:, 2].min() - .005 * H) | (ridge[:, 2] > visor[:, 2].max() + .005 * H)
    order = np.argsort(ridge[outside, 2])
    facet_slope = np.interp(visor[:, 2], ridge[outside, 2][order], slope[outside][order])
    crease_x = np.interp(visor[:, 2], ridge[:, 2], crease[..., 0].mean(1)); crease_y = np.interp(visor[:, 2], ridge[:, 2], abs(crease[..., 1]).mean(1))
    surface = crease_x + facet_slope * (crease_y - abs(visor[:, 1]))
    recess = float((surface - visor[:, 0]).min() / H)
    recessed = bool(recess > 0)
    crown = float(helm_v[:, 2].max())
    back_top = float(rings[:, [3, 4, 5], 2].max())
    tines = {}
    for s in ('near', 'far'):
        t = local('helm_tine_' + s)
        line = np.vstack([t[k * 4:(k + 1) * 4].mean(0) for k in range(len(t) // 4)] + [t[-1]])
        base_w = float(np.linalg.norm(t[0] - t[2]) / H)
        apex = line[-1]; topmost = line[np.argmax(line[:, 2])]
        tines[s] = {'rise_above_crown_over_H': float((line[:, 2].max() - crown) / H), 'base_width_over_H': base_w,
                    'tip_hook_forward_over_H': float((apex[0] - topmost[0]) / H), 'single_apex': bool(len(t) % 4 == 1)}
    # Hood crown: the soft point (last mid-surface ring) above the helm's back top.
    nr, nc = spec['mq26']['cowl_grid']; cowl = local('hood_cowl'); count = nr * nc
    mid = ((cowl[:count] + cowl[count:]) / 2).reshape(nr, nc, 3)
    hood_point = float((mid[-1].mean(0)[2] - back_top) / H)
    checks = {'face_plate_width': abs(width - b['face_plate_width_over_H']) <= tol,
              'face_plate_brow_to_chin': abs(height - b['face_plate_brow_to_chin_over_H']) <= tol,
              'ridge_and_two_facets_per_side': ridge_front,
              'visor_slit_size': abs(v_width - b['visor_width_over_H']) <= tol and abs(v_height - b['visor_height_over_H']) <= tol,
              'visor_recessed': recessed,
              'far_tine_rise_above_crown': abs(tines['far']['rise_above_crown_over_H'] - b['far_tine_rise_above_crown_over_H']) <= tol,
              'near_tine_rise_above_crown': abs(tines['near']['rise_above_crown_over_H'] - b['near_tine_rise_above_crown_over_H']) <= tol,
              'far_tine_is_taller': tines['far']['rise_above_crown_over_H'] > tines['near']['rise_above_crown_over_H'],
              'tine_base_widths': all(abs(t['base_width_over_H'] - b['tine_base_width_over_H']) <= tol for t in tines.values()),
              'far_tine_forward_hook': abs(tines['far']['tip_hook_forward_over_H'] - b['far_tine_forward_hook_over_H']) <= tol,
              'near_tine_backward_hook': abs(tines['near']['tip_hook_forward_over_H'] + b['near_tine_backward_hook_over_H']) <= tol,
              'sharp_tine_points': all(t['single_apex'] for t in tines.values()),
              'hood_crown_point': abs(hood_point - b['hood_crown_point_above_helm_back_over_H']) <= tol,
              'hood_present': 'hood_cowl_render' in pts and 'hood_mantle_render' in pts}
    return {'checks': {k: bool(v) for k, v in checks.items()}, 'face_plate_width_over_H': width, 'face_plate_height_over_H': height,
            'visor_width_over_H': v_width, 'visor_height_over_H': v_height, 'visor_recess_over_H': recess, 'tines': tines,
            'hood_point_above_helm_back_over_H': hood_point,
            'definition': 'Head frame from the native head bone (forward) and the head-to-tip axis. Crown = the helm top; tine rises '
                          'are the highest centreline station above it; hook = apex minus topmost station along head forward.'}


def hood_fall(spec, pts, j, forwards):
    """The mantle's back profile is concave: it hugs the neck, then falls (no hump)."""
    H = spec['mq19']['gauge_H_m']; frame = chest_frame(j, forwards); hc = (j['hip_near'] + j['hip_far']) / 2
    nr, nc = spec['mq26']['support_hems']['hood_mantle']['grid']; v = np.asarray(pts['hood_mantle_render']); count = nr * nc
    mid = ((v[:count] + v[count:]) / 2).reshape(nr, nc, 3)
    back = (mid[:, nc // 2] - hc) @ frame                     # column at phi = pi, torso-local
    chord = back[-1] - back[0]; normal = np.array([-chord[2], 0., chord[0]]); normal /= np.linalg.norm(normal)
    if normal[0] > 0: normal = -normal                          # outward = backward (-x)
    bulge = float(max((p - back[0]) @ normal for p in back[1:-1]) / H)
    return {'checks': {'mantle_back_concave_no_hump': bulge <= 0.}, 'maximum_outward_bulge_over_H': bulge,
            'definition': 'Mantle mid-surface back column (phi = pi) in the native torso frame; signed distance of every interior '
                          'row outside the straight neck-to-hem chord. Positive is a hump.'}


# ------------------------------------------------------------------ ribs ---
RIB_ROWS = 5


def rib_lines(pts, name):
    v = np.asarray(pts[name + '_render']); half = len(v) // 2; n = half // RIB_ROWS
    return v.reshape(2, RIB_ROWS, n, 3).mean(axis=(0, 1))


def ribs(spec, pts, j, forwards, view_points=None):
    H = spec['mq19']['gauge_H_m']; b = spec['mq26']['brief']['ribs']; tol = CHECK_DEFAULTS['form_tolerance_over_H']
    frame = chest_frame(j, forwards); names = sorted(n[:-7] for n in pts if n.startswith('rib_'))
    near = sorted(n for n in names if n.startswith('rib_near_')); far = sorted(n for n in names if n.startswith('rib_far_'))
    def turning(line2d):
        d = np.diff(line2d, axis=0); a = np.unwrap(np.arctan2(d[:, 1], d[:, 0]))
        return float(math.degrees(a[-1] - a[0]))
    rows = []; yaw_errors = []; thick = []
    chest_yaw = math.degrees(math.atan2(frame[1, 0], frame[0, 0]))
    for a, c in zip(near, far):
        ln, lf = rib_lines(pts, a), rib_lines(pts, c)
        # 3D: the bilateral symmetry of each rib pair fixes the cage's facing.
        # Its lateral (outer end to outer end) is compared with the native torso
        # frame's lateral inside the chest's own transverse plane.
        world = (ln[-1] - lf[-1]); world[2] = 0
        cage_world_yaw = math.degrees(math.atan2(-world[0], world[1]))
        local = (ln[-1] - lf[-1]) @ frame
        yaw_errors.append(math.degrees(math.atan2(-local[0], local[1])))
        # In the chest's horizontal plane each band curves around the chest
        # surface; traversed from the sternum outward the turn reverses sign.
        local_n = (ln - j['torso']) @ frame; local_f = (lf - j['torso']) @ frame
        tn, tf = turning(local_n[:, :2]), turning(local_f[:, :2])
        sn = screen(spec, ln); sf = screen(spec, lf)
        rows.append({'near': a, 'far': c, 'plan_turn_near_degrees': tn, 'plan_turn_far_degrees': tf,
                     'screen_turn_near_degrees': turning(sn), 'screen_turn_far_degrees': turning(sf),
                     'screen_length_near_over_H': float(np.linalg.norm(np.diff(sn, axis=0), axis=1).sum() / registered_height(spec)),
                     'screen_length_far_over_H': float(np.linalg.norm(np.diff(sf, axis=0), axis=1).sum() / registered_height(spec)),
                     'cage_yaw_minus_chest_yaw_degrees': yaw_errors[-1], 'cage_world_yaw_degrees': cage_world_yaw})
        for n in (a, c):
            v = np.asarray(pts[n + '_render']); half = len(v) // 2
            thick.append(float(np.linalg.norm(v[:half] - v[half:], axis=1).max() / H))
    limit = CHECK_DEFAULTS['rib_minimum_turn_degrees']
    droops = []
    for n in near + far:
        line = (rib_lines(pts, n) - j['torso']) @ frame
        droops.append(float((line[0, 2] - line[-1, 2]) / H))
    checks = {'five_ribs_per_side': len(near) == b['per_side'] and len(far) == b['per_side'],
              'rib_droop_sternum_to_flank': all(abs(x - b['droop_over_H']) <= tol for x in droops),
              'band_thickness': all(abs(t - b['band_thickness_over_H']) <= tol for t in thick),
              'plan_curvature_reverses_across_sternum': all(r['plan_turn_near_degrees'] * r['plan_turn_far_degrees'] < 0 and
                                                            min(abs(r['plan_turn_near_degrees']), abs(r['plan_turn_far_degrees'])) >= limit for r in rows),
              'screen_curvature_reverses_across_sternum': all(r['screen_turn_near_degrees'] * r['screen_turn_far_degrees'] < 0 and
                                                              min(abs(r['screen_turn_near_degrees']), abs(r['screen_turn_far_degrees'])) >= limit for r in rows),
              'cage_follows_chest_yaw': all(abs(e) <= CHECK_DEFAULTS['rib_yaw_tolerance_degrees'] for e in yaw_errors),
              'far_ribs_foreshortened': all(r['screen_length_far_over_H'] < r['screen_length_near_over_H'] for r in rows),
              'sternum_bar': 'sternum_bar_render' in pts}
    bell = bell_inside(spec, pts, j, forwards, near + far)
    checks.update(bell['checks'])
    return {'checks': {k: bool(v) for k, v in checks.items()}, 'rows': rows, 'band_thickness_over_H': thick,
            'droop_over_H': droops, 'bell': bell,
            'chest_yaw_degrees': chest_yaw,
            'definition': 'Band centreline = mean of its skin vertices per station; thickness = its greatest two-skin separation. Turn = signed tangent rotation from the '
                          'sternum end outward, in the chest plan and on the front capture. Cage yaw: the near/far outer-end '
                          'line of each rib pair against the native torso frame (bone facing and spine) in the chest plane; '
                          'its world yaw is reported beside the torso facing yaw.'}


def bell_inside(spec, pts, j, forwards, ribs):
    """The bell hangs inside the cage: behind the front bands, mouth on the lower edge."""
    H = spec['mq19']['gauge_H_m']; frame = chest_frame(j, forwards); o = j['torso']
    bell = (np.asarray(pts['bell_render']) - o) @ frame
    near_sternum = []
    for n in ribs:
        v = (np.asarray(pts[n + '_render']) - o) @ frame
        v = v[abs(v[:, 1]) <= .012 * H]
        if len(v): near_sternum.append(v)
    cage = np.concatenate(near_sternum)
    inner_front = float(cage[:, 0].min()) if len(cage) else -np.inf
    lower = float(cage[:, 2].min()); upper = float(cage[:, 2].max())
    sternum = (np.asarray(pts['sternum_bar_render']) - o) @ frame
    abdomen = (np.asarray(pts['lower_abdomen_render']) - o) @ frame
    front_line = float(np.median(cage[:, 0]))
    row = {'bell_front_behind_band_inner_over_H': (inner_front - bell[:, 0].max()) / H,
           'mouth_minus_cage_lower_edge_over_H': (bell[:, 2].min() - lower) / H,
           'top_below_sternum_top_over_H': (sternum[:, 2].max() - bell[:, 2].max()) / H,
           'abdomen_front_behind_cage_front_over_H': (front_line - abdomen[:, 0].max()) / H}
    tol = CHECK_DEFAULTS['form_tolerance_over_H']
    checks = {'bell_inside_cage': row['bell_front_behind_band_inner_over_H'] > 0,
              'bell_mouth_on_cage_lower_edge': abs(row['mouth_minus_cage_lower_edge_over_H']) <= .003,
              'bell_top_just_below_sternum_top': 0 < row['top_below_sternum_top_over_H'] <= .012,
              'nothing_bulges_in_front_of_abdomen': row['abdomen_front_behind_cage_front_over_H'] >= -tol}
    return {'checks': {k: bool(v) for k, v in checks.items()}, 'values': {k: float(v) for k, v in row.items()},
            'definition': 'Native torso frame. Cage front = rib-band vertices within 0.012 H of the sternum plane; the bell must '
                          'lie behind their inner face, its mouth within 0.003 H of their lowest edge, its top below the sternum top.'}


# ------------------------------------------------------------- pauldrons ---
def pauldrons(spec, pts, j):
    H = spec['mq19']['gauge_H_m']; b = spec['mq26']['brief']['pauldrons']; out = {}; checks = {}
    lo, hi = b['lame_size_range_over_H']; tol = CHECK_DEFAULTS['form_tolerance_over_H']
    # Measured from opened vertices: per-lame axial extent and spikes as apex vertices.
    for side in ('near', 'far'):
        v = np.asarray(pts['pauldron_' + side + '_render']); ranges = spec['mq26']['pauldron_ranges'][side]
        sizes = []; spikes = []
        for k, (a, c) in enumerate(ranges['lames']):
            lame = v[a:c]; axis = np.asarray(ranges['axes'][k])
            sizes.append(float(np.ptp(lame @ axis) / H))
        for a, c in ranges['spikes']:
            s = v[a:c]; root = s[4:8].mean(0); apex = s[-1]
            spikes.append({'length_over_H': float(np.linalg.norm(apex - root) / H),
                           'up_back': bool(apex[2] > root[2]), 'pointed': (c - a) % 4 == 1})
        out[side] = {'lame_sizes_over_H': sizes, 'spikes': spikes}
        a, c = ranges['lames'][0]; axis = np.asarray(ranges['axes'][0]); top = v[a:c]
        shoulder = j['shoulder_' + side]; rel = top - shoulder; rel -= np.outer(rel @ axis, axis)
        ref = rel[np.argmax(np.linalg.norm(rel, axis=1))]; ref = ref / np.linalg.norm(ref); other = np.cross(axis, ref)
        angles = np.sort(np.degrees(np.arctan2(rel @ other, rel @ ref)) % 360)
        gap = float(max(np.diff(np.r_[angles, angles[0] + 360])))
        cols, rows_ = 9, spec['mq26']['construction']['pauldron']['cup_rows']
        grid = top[:rows_ * cols].reshape(rows_, cols, 3) - shoulder
        radius = lambda q: np.linalg.norm(q - np.outer(q @ axis, axis), axis=1).mean()
        cup = float(radius(grid[0]) / radius(grid[-1]))
        out[side].update(top_lame_open_gap_degrees=gap, top_lame_cup_ratio=cup)
        checks[side + '_top_lame_open_not_a_can'] = gap >= CHECK_DEFAULTS['open_lame_gap_degrees']
        checks[side + '_top_lame_cups_over_shoulder'] = cup <= .6
        checks[side + '_three_lames'] = len(sizes) == b['lames_per_side']
        checks[side + '_lame_sizes'] = all(lo - tol <= s <= hi + tol for s in sizes)
        checks[side + '_one_spike_per_lame'] = len(spikes) == len(sizes)
        checks[side + '_spikes'] = all(abs(s['length_over_H'] - b['spike_length_over_H']) <= tol and s['up_back'] and s['pointed'] for s in spikes)
    return {'checks': {k: bool(v) for k, v in checks.items()}, 'sides': out}


def spec_piece(spec, name):
    return next(p for p in spec['pieces'] if p['id'] == name)


# ----------------------------------------------------------- legs / fork ---
def legs_and_fork(spec, pts, j):
    H = spec['mq19']['gauge_H_m']; b = spec['mq26']['brief']; tol = CHECK_DEFAULTS['form_tolerance_over_H']; checks = {}; out = {}
    for side in ('near', 'far'):
        v = np.asarray(pts['pointed_sabaton_' + side + '_render'])
        out['toe_beyond_ankle_' + side + '_over_H'] = float((v[:, 0].max() - j['ankle_' + side][0]) / H)
        checks['sabaton_toe_' + side] = abs(out['toe_beyond_ankle_' + side + '_over_H'] - b['sabaton_toe_beyond_ankle_over_H']) <= tol
        checks['sabaton_on_floor_' + side] = abs(float(v[:, 2].min())) <= CHECK_DEFAULTS['native_tolerance_m']
        checks['ankle_wraps_' + side] = all(('ankle_wrap_%s_%d_render' % (side, k)) in pts for k in range(3))
    staff = np.asarray(pts['staff_render']); comps = spec['mq17']['staff_components']; tines = {}
    for name in ('fork_centre', 'fork_outer', 'fork_inner'):
        a, c = comps[name]; t = staff[a:c]
        root = t[:4].mean(0); apex = t[-1]
        path = np.vstack([t[k * 4:(k + 1) * 4].mean(0) for k in range((c - a - 1) // 4)] + [apex])
        d = np.diff(path, axis=0); turns = [angle(x, y) for x, y in zip(d, d[1:])]
        tines[name] = {'length_over_H': float(np.linalg.norm(np.diff(path, axis=0), axis=1).sum() / H),
                       'base_width_over_H': float(np.linalg.norm(t[0] - t[2]) / H),
                       'bends_over_30_degrees': int(sum(x > 30 for x in turns)), 'single_apex': (c - a) % 4 == 1}
    centre = tines['fork_centre']['length_over_H']
    out['fork'] = tines
    checks['fork_three_tines'] = len(tines) == b['fork']['tines']
    checks['fork_two_zigzag_bends'] = all(t['bends_over_30_degrees'] == b['fork']['zigzag_bends'] for t in tines.values())
    checks['fork_base_width'] = all(abs(t['base_width_over_H'] - b['fork']['tine_base_width_over_H']) <= tol for t in tines.values())
    checks['fork_side_ratio'] = all(abs(tines[n]['length_over_H'] / centre - b['fork']['side_to_centre_length']) <= .02 for n in ('fork_outer', 'fork_inner'))
    checks['fork_centre_tallest'] = all(centre > tines[n]['length_over_H'] for n in ('fork_outer', 'fork_inner'))
    checks['fork_sharp_points'] = all(t['single_apex'] for t in tines.values())
    return {'checks': {k: bool(v) for k, v in checks.items()}, 'values': out}


def tine_visibility(spec, pts, faces):
    """Both tines clearly visible above the hood in both capture cameras."""
    from .hand_capture import window_pieces
    H = spec['mq19']['gauge_H_m']; size = spec['mq19']['capture_px']; out = {}; checks = {}
    names = [n for n in ('great_helm', 'visor_slit', 'helm_tine_near', 'helm_tine_far', 'hood_cowl', 'hood_mantle')]
    for view in ('front', 'rear'):
        _, _, _, scale = camera(spec, view); px_per_H = size / scale * registered_height(spec)
        ids, order = window_pieces(spec, pts, faces, view, [n + '_render' for n in names])
        hood = np.argwhere(ids == order.index('hood_cowl_render'))
        hood_top = int(hood[:, 0].min()) if len(hood) else size
        rows = {}
        for side in ('near', 'far'):
            mask = np.argwhere(ids == order.index('helm_tine_' + side + '_render'))
            above = mask[mask[:, 0] < hood_top]
            extent = float((above[:, 0].max() - above[:, 0].min() + 1) / px_per_H) if len(above) else 0.
            rows[side] = {'visible_pixels': int(len(mask)), 'pixels_above_hood': int(len(above)), 'extent_above_hood_over_H': extent}
            checks[view + '_' + side + '_tine_above_hood'] = extent >= CHECK_DEFAULTS['tine_visible_extent_over_H']
        out[view] = {'hood_top_row_px': hood_top, 'tines': rows}
    return {'checks': checks, 'views': out,
            'definition': 'Depth-tested piece raster of the head region in each capture camera; a tine is clearly visible when its '
                          'visible pixels above the hood cowl\'s topmost pixel row span at least 0.06 H on screen.'}


# ------------------------------------------------------------ sphericity ---
def joint_points(spec, j):
    jj = {k: np.asarray(v, float) for k, v in j.items()}
    jj['wrist_far'] = np.asarray(spec['mq26']['wrists']['far'])
    return jj


def sphere_gate(spec, pts, faces, j, views=('front', 'rear'), joints=None):
    H = spec['mq19']['gauge_H_m']; size = spec['mq19']['capture_px']
    tris, owners = [], []
    for name, v in pts.items():
        t = sphericity.triangles(v, faces[name]); tris.append(t); owners += [name[:-7]] * len(t)
    tris = np.concatenate(tris); owners = np.asarray(owners, object)
    radius = CHECK_DEFAULTS['sphere_window_over_H'] * H; out = {}
    for view in views:
        matrix, _, basis, scale = camera(spec, view)
        toward = basis[2] @ matrix[:3, :3]
        screen_fn = lambda p, view=view: project(spec, p, view, size)
        radius_px = radius / scale * size
        out[view] = {}
        for name in joints or JOINTS:
            out[view][name] = sphericity.joint_region(tris, owners, screen_fn, j[name], radius_px, radius, toward)
    limit = CHECK_DEFAULTS['sphere_fraction_limit']; iso = CHECK_DEFAULTS['sphere_isotropy_limit']
    for v in out.values():
        for r in v.values():
            r['near_sphere'] = bool(r['applicable'] and r['sphere_fraction'] > limit and r['normal_isotropy'] > iso)
    worst = max((min(r['sphere_fraction'] / limit, r['normal_isotropy'] / iso) for v in out.values() for r in v.values() if r['applicable']), default=0.)
    passed = not any(r['near_sphere'] for v in out.values() for r in v.values())
    return {'passed': bool(passed), 'sphere_fraction_limit': limit, 'normal_isotropy_limit': iso,
            'worst_score_over_limit': worst, 'views': out,
            'window_over_H': CHECK_DEFAULTS['sphere_window_over_H'],
            'definition': 'Per capture camera and joint: pixel-centre rays within the projected 0.04 H window; hits within 0.04 H '
                          'of the joint form its visible region; a least-squares sphere is fitted; sphere fraction = share of hits '
                          'within 12% radial residual and 15 degrees normal agreement; normal isotropy = sqrt of the ratio of the two largest '
                          'normal spreads. A joint region is a near-sphere when sphere fraction > 0.5 AND isotropy > 0.45; a visible ball '
                          'scores near 1 on both. worst_score_over_limit = max over regions of min(fraction/0.5, isotropy/0.45).'}


# --------------------------------------------------------------- observe ---
def observe(spec, points, joints, forwards, faces, sphere=True):
    H = spec['mq19']['gauge_H_m']
    j = {k: np.asarray(v, float) for k, v in joints.items()}; pts = {k: np.asarray(v, float) for k, v in points.items()}
    rows, info = pose_rows(spec, j, forwards, pts)
    jj = joint_points(spec, j)
    soles = {s: float(pts['pointed_sabaton_' + s + '_render'][:, 2].min()) for s in ('near', 'far')}
    projected = {v: {n: project(spec, q, v, spec['mq19']['capture_px'])[:2] for n, q in joints.items()} for v in ('front', 'rear')}
    gates = captured_pose_gates(spec, projected, {'observed_joints': joints})
    tolerance = CHECK_DEFAULTS['native_tolerance_m']; L = spec['mq19']['gauge_L_m']
    shaft = info['shaft_base']
    checks = {'pose_values': all(r['passed'] for r in rows),
              'feet_planted': all(abs(v) <= tolerance for v in soles.values()),
              'staff_butt_outward_of_far_foot': j['ankle_far'][1] - shaft[1] >= spec['mq19']['design']['pose_resolution']['minimum_staff_clearance_over_L'] * L - 1e-7,
              'far_elbow_not_forward': j['elbow_far'][0] <= j['shoulder_far'][0] + tolerance,
              'forearm_forward': info['fore'][0] > info['upper'][0],
              'shoulder_rule': gates['checks']['shoulder_rule'],
              'level_shoulders': abs(j['shoulder_near'][2] - j['shoulder_far'][2]) <= .005 * H,
              'true_turn': gates['checks']['proper_true_turn'],
              'facing': axis_report(spec, forwards['torso'])['passed']}
    cloak = observe_cloak(spec, pts['full_back_cloak_render'], faces['full_back_cloak_render'], j, pts, faces)
    checks['cloak'] = cloak['passed']
    tabard = observe_tabard(spec, pts['front_tabard_render'], j)
    checks['tabard'] = tabard['passed']
    proportions = measure_proportions(spec, pts, j, H, faces)
    tol = CHECK_DEFAULTS['proportion_tolerance_fraction']; brief = spec['mq26']['brief']
    targets = {'hip_joint': brief['hip_joint_over_H'], 'thigh_width': brief['thigh_width_over_H'], 'shin_width': brief['shin_width_over_H'],
               'upper_arm_width': brief['upper_arm_width_over_H'], 'forearm_width': brief['forearm_width_over_H'],
               'waist_sash': brief['waist_sash_across_over_H'], 'chest': brief['chest_across_over_H'], 'pauldron_span': brief['pauldron_span_over_H']}
    accepted = spec['mq26'].get('director_accepted_rows', {})
    proportion_rows = {}
    for name, t in targets.items():
        value = proportions[name]['screen_over_H']
        row = {'original_over_H': t, 'measured_over_H': value, 'relative_error': value / t - 1,
               'within_10_percent': abs(value / t - 1) <= tol}
        if name in accepted:
            # Director accepted the as-built value (review round 2); it may not drift.
            row.update(director_accepted_over_H=accepted[name], error_vs_accepted=value / accepted[name] - 1,
                       within_10_percent_of_accepted=abs(value / accepted[name] - 1) <= tol)
        proportion_rows[name] = row
    checks['proportions_within_10_percent'] = all(r['within_10_percent'] or r.get('within_10_percent_of_accepted', False)
                                                  for r in proportion_rows.values())
    strict = all(r['within_10_percent'] for r in proportion_rows.values())
    sections = {'hands': hands(spec, pts, info), 'cops': cops(spec, pts, j, jj), 'helm': helm(spec, pts, j, forwards),
                'ribs': ribs(spec, pts, j, forwards), 'pauldrons': pauldrons(spec, pts, j), 'legs_fork': legs_and_fork(spec, pts, j),
                'hood_fall': hood_fall(spec, pts, j, forwards), 'tines_above_hood': tine_visibility(spec, pts, faces)}
    for name, section in sections.items():
        checks[name] = all(section['checks'].values())
    gate = sphere_gate(spec, pts, faces, jj) if sphere else None
    if sphere: checks['no_spherical_joints'] = gate['passed']
    gates['checks'] = {k: bool(v) for k, v in gates['checks'].items()}
    checks = {k: bool(v) for k, v in checks.items()}
    return {'passed': all(checks.values()), 'checks': checks, 'pose_values': rows, 'soles_m': soles,
            'staff_top_over_H': float(pts['staff_render'][:, 2].max() / H),
            'shoulder_and_turn': gates, 'cloak': cloak, 'tabard': tabard, 'proportions': proportions,
            'proportion_rows': proportion_rows, 'proportions_strict_all_rows': strict, 'director_accepted_rows': sorted(accepted),
            'sections': sections, 'joint_sphericity': gate,
            'definition': 'H and L retain the mq-17 gauges. Proportions are sprite-style front-capture measurements over the '
                          'registered H (see proportions.definition).'}


def observe_native(spec, objects, joints, forwards, build):
    points = {o.name: [list(o.matrix_world @ v.co) for v in o.data.vertices] for o in objects}
    faces = {o.name: [list(f.vertices) for f in o.data.polygons] for o in objects}
    return observe(spec, points, joints, forwards, faces)
