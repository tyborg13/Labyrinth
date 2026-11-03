"""Take-three limbs: faceted tapered plates, pointed cops, real hands, lames.

All forms are posed directly on the solved joints. Segments taper and overlap
at every bend; cops cover the convex side; nothing ends in a sphere or bead.
"""
import math
import numpy as np

from spec.art_identity.maquettes.blender.faceted_forms import segment, octagon_profile, polygon_loft, blade, unit, frame, thick_sheet
from spec.art_identity.maquettes.blender.plate_cop import pointed_cop, bend_frame, rotate
from spec.art_identity.maquettes.blender import hand_v3
from ..forms import shell

LIMB_TOPOLOGY = {'lame_columns': 9, 'lame_rows': 3, 'wrap_columns': 24}


def octagon_radius(profile):
    return max(math.hypot(s, f) for s, f in profile)


def plate_segment(identifier, part, joint, start, end, reference, width, depth_ratio, stations, ridge, extend,
                  back_bulge=None):
    profile = octagon_profile(ridge)
    v, f, flat = segment(start, end, reference, width / 2, width / 2 * depth_ratio, stations, profile, extend, back_bulge)
    return shell(identifier, part, joint, v, f, list(range(len(f))))


def max_radius_near(piece, joint, axis, reach):
    """Largest distance from a bone axis among a segment's vertices near a joint."""
    p = np.asarray(piece['vertices']) - joint; axis = unit(axis)
    along = p @ axis; radial = np.linalg.norm(p - np.outer(along, axis), axis=1)
    near = abs(along) <= reach
    return float(radial[near].max()) if near.any() else float(radial.max())


def cop_piece(identifier, part, joint_name, j, proximal, distal, segments, c, H, kind):
    joint = j[joint_name]; spec = c[kind]
    reach = spec['overlap'] * H
    r = max(max_radius_near(s, joint, d, reach + spec['clearance'] * H) for s, d in segments) + spec['clearance'] * H
    v, f, apex, info = pointed_cop(joint, proximal, distal, r, spec['thickness'] * H, reach, spec['point'] * H,
                                   spec['wrap_degrees'], spec['fallback_outer'],
                                   spec['point_half_angle_degrees'],
                                   (spec['wing_height'] * H, spec['wing_start_degrees']) if spec.get('wing_height') else None,
                                   spec.get('columns'))
    piece = shell(identifier, part, joint_name, v, f, list(range(len(f))))
    info['seated_radius_over_H'] = r / H
    return piece, info


def arms(j, c, H):
    pieces, cops = [], {}
    for side in ('near', 'far'):
        s, e, w = j['shoulder_' + side], j['elbow_' + side], j['hand_' + side]
        a, b, outer, hinge, angle = bend_frame(e - s, w - e, c['elbow']['fallback_outer'])
        wrist = j['wrist_' + side]
        upper = plate_segment('upper_plate_' + side, 'upper_' + side, 'shoulder_' + side, s, e, -outer,
                              c['upper_width'] * H, c['arm_depth_ratio'], c['upper_stations'], c['arm_ridge'],
                              (c['upper_extend'][0] * H, c['upper_extend'][1] * H))
        fore = plate_segment('fore_plate_' + side, 'fore_' + side, 'elbow_' + side, e, wrist, -outer,
                             c['fore_width'] * H, c['arm_depth_ratio'], c['fore_stations'], c['arm_ridge'],
                             (c['fore_extend'][0] * H, c['fore_extend'][1] * H))
        cop, info = cop_piece('elbow_cop_' + side, 'fore_' + side, 'elbow_' + side, j, e - s, w - e,
                              [(upper, e - s), (fore, w - e)], c, H, 'elbow')
        pieces += [upper, fore, cop]; cops['elbow_' + side] = info
    return pieces, cops


def legs(j, c, H):
    pieces, cops = [], {}
    for side in ('near', 'far'):
        hip, knee, ankle = j['hip_' + side], j['knee_' + side], j['ankle_' + side]
        a, b, outer, hinge, angle = bend_frame(knee - hip, ankle - knee, [1., 0, 0])
        thigh = plate_segment('thigh_plate_' + side, 'thigh_' + side, 'hip_' + side, hip, knee, outer,
                              c['thigh_width'] * H, c['thigh_depth_ratio'], c['thigh_stations'], c['thigh_ridge'],
                              (c['thigh_extend'][0] * H, c['thigh_extend'][1] * H))
        shin = plate_segment('shin_plate_' + side, 'shin_' + side, 'knee_' + side, knee, ankle, outer,
                             c['shin_width'] * H, c['shin_depth_ratio'], c['shin_stations'], c['shin_ridge'],
                             (c['shin_extend'][0] * H, c['shin_extend'][1] * H), c['calf_bulge'])
        cop, info = cop_piece('knee_cop_' + side, 'shin_' + side, 'knee_' + side, j, knee - hip, ankle - knee,
                              [(thigh, knee - hip), (shin, ankle - knee)], c, H, 'knee')
        pieces += [thigh, shin, cop]; cops['knee_' + side] = info
        pieces += ankle_wraps(side, j, c, H, shin)
        pieces.append(sabaton(side, j, c, H))
    return pieces, cops


def ankle_wraps(side, j, c, H, shin):
    knee, ankle = j['knee_' + side], j['ankle_' + side]
    axis = unit(knee - ankle); pieces = []
    for k, (height, tilt) in enumerate(c['ankle_wraps']):
        centre = ankle + axis * height * H
        radius = max_radius_near(shin, centre, axis, c['wrap_band'] * H) + c['wrap_gap'] * H
        side_v, front, w = frame(axis, [1., 0, 0])
        tilt_axis = side_v
        rows = []
        for dz in (-c['wrap_band'] / 2, c['wrap_band'] / 2):
            row = []
            for t in np.linspace(0, math.tau, LIMB_TOPOLOGY['wrap_columns'], endpoint=False):
                radial = front * math.cos(t) + side_v * math.sin(t)
                lift = math.tan(math.radians(tilt)) * radius * math.cos(t)
                row.append(centre + radial * radius + w * (dz * H + lift))
            rows.append(row)
        rows = np.asarray(rows)
        normals = rows - centre; normals -= np.einsum('rcj,j->rc', normals, w)[..., None] * w
        normals /= np.linalg.norm(normals, axis=2)[..., None]
        v, f = thick_sheet(rows, c['wrap_thickness'] * H, normals, periodic=True)
        pieces.append(shell('ankle_wrap_' + side + '_' + str(k), 'shin_' + side, 'ankle_' + side, v, f))
    return pieces


def sabaton(side, j, c, H):
    """Long pointed plated sabaton; the sole is exactly on the floor plane."""
    ankle = j['ankle_' + side]; sections = []
    for x, height, half_width, ridge in c['sabaton_stations']:
        cx, cy = ankle[0] + x * H, ankle[1]
        hw, h = half_width * H, height * H
        ring = [[cx, cy - hw, 0.], [cx, cy - hw * .92, h * .55], [cx, cy - hw * .45, h * .92],
                [cx, cy, h * (1 + ridge)], [cx, cy + hw * .45, h * .92], [cx, cy + hw * .92, h * .55], [cx, cy + hw, 0.]]
        sections.append(ring)
    tip = [ankle[0] + c['sabaton_toe'] * H, ankle[1], c['sabaton_tip_height'] * H]
    sections.append([tip])
    v, f, flat = polygon_loft(sections)
    return shell('pointed_sabaton_' + side, 'foot_' + side, 'ankle_' + side, v, f, list(range(len(f))))


def lame_band(axis_origin, axis, outward, s0, s1, r0, r1, thickness, wrap_degrees, columns, rows, peak=0., peak_degrees=50.):
    """Flared partial frustum about an arm axis, open on the body side (closed shell).

    The top edge rises to a pointed peak on the outer side (where its spike roots).
    """
    side, front, w = frame(axis, outward)
    half = math.radians(wrap_degrees) / 2; grid = []; axial = []
    for t in np.linspace(0, 1, rows):
        row = []; arow = []
        for psi in np.linspace(-half, half, columns):
            top = s0 - peak * max(0., 1 - abs(math.degrees(psi)) / peak_degrees)
            s = top + (s1 - top) * t; r = r0 + (r1 - r0) * t
            radial = front * math.cos(psi) + side * math.sin(psi)
            row.append(axis_origin + w * s + radial * r); arow.append(s)
        grid.append(row); axial.append(arow)
    grid = np.asarray(grid)
    centre = axis_origin + np.asarray(axial)[..., None] * w
    normals = grid - centre; normals -= np.einsum('rcj,j->rc', normals, w)[..., None] * w
    normals /= np.linalg.norm(normals, axis=2)[..., None]
    return thick_sheet(grid + normals * thickness / 2, thickness, normals)


def cup_band(origin, axis, outward, s0, s1, r1, top_fraction, thickness, wrap_degrees, columns, rows, peak, peak_degrees):
    """Lame whose upper rows close toward the axis, cupping over the joint."""
    side, front, w = frame(axis, outward)
    half = math.radians(wrap_degrees) / 2; grid = []; axial = []
    for t in np.linspace(0, 1, rows):
        r = r1 * (top_fraction + (1 - top_fraction) * math.sin(math.pi * t / 2))
        row = []; arow = []
        for psi in np.linspace(-half, half, columns):
            top = s0 - peak * max(0., 1 - abs(math.degrees(psi)) / peak_degrees)
            s = top + (s1 - top) * t
            radial = front * math.cos(psi) + side * math.sin(psi)
            row.append(origin + w * s + radial * r); arow.append(s)
        grid.append(row); axial.append(arow)
    grid = np.asarray(grid)
    centre = origin + np.asarray(axial)[..., None] * w
    normals = np.cross(np.gradient(grid, axis=1), np.gradient(grid, axis=0))
    normals /= np.linalg.norm(normals, axis=2)[..., None]
    radial = grid - centre
    normals *= np.sign(np.einsum('rcj,rcj->rc', normals, radial))[..., None]
    v, f = thick_sheet(grid + normals * thickness / 2, thickness, normals)
    return v, f, columns, rows


def pauldrons(j, fr, c, H):
    """Three overlapping lames per side, each with one swept-back spike.

    The cap sits on the shoulder (its axis mostly the torso's down axis); the
    lower lames turn progressively onto the upper-arm axis.
    """
    pieces, hems, spikes = [], {}, {}
    p = c['pauldron']
    for side, sign in (('near', 1), ('far', -1)):
        shoulder = j['shoulder_' + side]; elbow = j['elbow_' + side]
        arm = unit(elbow - shoulder); down = -fr.Rc[:, 2]
        lateral = fr.Rc[:, 1] * sign
        vertices, faces, flat = [], [], []
        ranges = {'lames': [], 'spikes': [], 'axes': []}
        def add(v, f, all_flat=True):
            offset = len(vertices); start = len(faces)
            vertices.extend(np.asarray(v).tolist()); faces.extend([[i + offset for i in q] for q in f])
            if all_flat: flat.extend(range(start, len(faces)))
            return [offset, len(vertices)]
        frames = []
        for blend in p['axis_blend']:
            axis = unit(down * blend + arm * (1 - blend))
            outward = unit(lateral - axis * (lateral @ axis))
            frames.append((axis, outward) + frame(axis, outward))
        # Top lame: an open faceted plate that cups over the shoulder (no can, no
        # dome): its radius closes toward the top, the body side stays open.
        cap = p['lames'][0]
        axis, outward, side_v, front, w = frames[0]
        v, f, cols, rows = cup_band(shoulder, axis, outward, cap['s0'] * H, cap['s1'] * H, cap['r1'] * H,
                                    p['cup_top_radius_fraction'], p['thickness'] * H, p['cup_wrap_degrees'],
                                    LIMB_TOPOLOGY['lame_columns'], p['cup_rows'], p['peak'] * H, p['peak_degrees'])
        cap_range = add(v, f); ranges['lames'].append(cap_range); ranges['axes'].append(axis.tolist())
        # The top lame's outer lower rim is the cloak seam's live hem (the cloak tucks under it).
        hem_range = [cap_range[0] + (rows - 1) * cols, cap_range[0] + rows * cols]
        for k, lame in enumerate(p['lames'][1:], 1):
            axis, outward = frames[k][:2]
            v, f = lame_band(shoulder, axis, outward, lame['s0'] * H, lame['s1'] * H, lame['r0'] * H, lame['r1'] * H,
                             p['thickness'] * H, p['wrap_degrees'], LIMB_TOPOLOGY['lame_columns'], LIMB_TOPOLOGY['lame_rows'],
                             p['peak'] * H, p['peak_degrees'])
            ranges['lames'].append(add(v, f)); ranges['axes'].append(axis.tolist())
        # One swept-back pointed spike per lame, rooted on its upper outer edge.
        back = -fr.Rc[:, 0]; up = fr.Rc[:, 2]
        tips = []
        for k, lame in enumerate(p['lames']):
            axis, outward, side_v, front, w = frames[k]
            psi = math.radians(p['spike_root_degrees'])
            radial = front * math.cos(psi) + side_v * math.sin(psi)
            s_ = lame['s0'] - p['peak'] + p['spike_root_below_edge'] + (lame.get('crown', 0) if k == 0 else 0)
            if k:
                r = lame['r0'] + p['thickness']
            else:
                # On the cup the spike roots where the plate has its radius at that height.
                t = p['spike_root_below_edge'] / (cap['s1'] - (cap['s0'] - p['peak']))
                f = p['cup_top_radius_fraction']
                r = cap['r1'] * (f + (1 - f) * math.sin(math.pi * t / 2)) + p['thickness']
            root = shoulder + w * s_ * H + radial * r * H
            direction = unit(up * p['spike_up'] + back * p['spike_back'] + outward * p['spike_out'])
            length = p['spike_length'] * H
            # Root ring sits on the lame surface; a sunk ring seats it in the plate.
            path = [root - radial * p['spike_root_sink'] * H, root, root + direction * length * .45, root + direction * length]
            hw = p['spike_base_width'] / 2 * H
            v, f, _ = blade(path, [hw, hw, hw * .55, 0.], [hw * .6, hw * .6, hw * .35, 0.], radial)
            ranges['spikes'].append(add(v, f)); tips.append({'root': root.tolist(), 'tip': (root + direction * length).tolist()})
        pieces.append(shell('pauldron_' + side, 'pauldron_' + side, 'shoulder_' + side, vertices, faces, flat))
        hems['pauldron_' + side] = {'hem_vertex_range': hem_range}; spikes[side] = tips
        hems.setdefault('_ranges', {})[side] = ranges
    return pieces, hems, spikes


# ------------------------------------------------------------------ hands ---
def near_hand(j, fr, c, H):
    h = c['hand']; side = 'near'
    wrist = j['wrist_near']; axis = unit(j['hand_near'] - j['elbow_near'])
    # The back of the hand faces the board camera, so the palm (and the curl)
    # faces back and toward the body; the spread fingers read side by side.
    away = -np.asarray(c['board_camera_toward'], float)
    palm_side = unit(away - axis * (away @ axis))
    across = unit(np.cross(palm_side, axis))
    # Thumb on the forward side of the knuckle line.
    if across @ fr.Rc[:, 0] < 0:
        across = -across
    knuckle_centre = wrist + axis * h['palm_length'] * H
    spacing = h['finger_base'] * H * (1 + h['knuckle_gap_fraction'])
    pieces, fingers = [], {}
    knuckles = []
    for i in range(4):
        offset = (1.5 - i) * spacing
        k = knuckle_centre + across * offset
        direction = rotate(axis, palm_side, math.radians((1.5 - i) * h['near_spread_degrees']))
        curl_axis = unit(np.cross(direction, palm_side))
        points = hand_v3.curled_points(k, direction, curl_axis, [x * H for x in h['phalanges']], h['near_curls'])
        fingers[str(i)] = [p.tolist() for p in points]; knuckles.append(k)
    pieces += digit_pieces('hand_near', fingers, -palm_side, h, H)
    thumb_base = wrist + axis * h['thumb_root_along'] * H + across * (2 * spacing + h['thumb_root_out'] * H) + palm_side * h['thumb_root_palm'] * H
    t_dir = unit(axis * math.cos(math.radians(h['near_thumb_out_degrees'])) + across * math.sin(math.radians(h['near_thumb_out_degrees'])) + palm_side * h['near_thumb_palm'])
    t_axis = unit(np.cross(t_dir, palm_side + across * .3))
    thumb = hand_v3.curled_points(thumb_base, t_dir, t_axis, [x * H for x in h['thumb_phalanges']], h['near_thumb_curls'])
    pieces += digit_pieces('hand_near', {'thumb': [p.tolist() for p in thumb]}, -palm_side, h, H)
    v, f, _ = hand_v3.palm(wrist, knuckles, -palm_side, h['palm_thickness'] * H, h['wrist_width'] * H)
    pieces.append(shell('palm_near', 'hand_near', 'hand_near', v, f, list(range(len(f)))))
    v, f, _ = hand_v3.cuff(wrist + axis * h['cuff_forward'] * H, axis, -palm_side, h['cuff_radius'] * H, h['cuff_length'] * H,
                           h['cuff_flare'], h['cuff_thickness'] * H)
    pieces.append(shell('gauntlet_cuff_near', 'hand_near', 'hand_near', v, f, list(range(len(f)))))
    tip = knuckle_centre
    return pieces, {'fingers': fingers, 'thumb': [p.tolist() for p in thumb], 'palm_normal': palm_side.tolist(),
                    'hand_axis': axis.tolist(), 'hand_tip': tip.tolist()}


def far_hand(j, fr, c, H, shaft_axis):
    """Hammer grip: fingers wrap the shaft; the thumb crosses over the top."""
    h = c['hand']; grip = j['hand_far']; s = unit(shaft_axis)
    fore = unit(j['hand_far'] - j['elbow_far']); f = unit(fore - s * (fore @ s))
    n = unit(np.cross(s, f)) * h['grip_side']
    R = h['shaft_radius'] * H; Rf = R + h['finger_base'] * H * h['grip_wrap_offset']
    def ring_point(theta, height, radius=Rf):
        return grip + s * height + (-f * math.cos(theta) + n * math.sin(theta)) * radius
    spacing = h['finger_base'] * H * (1 + h['knuckle_gap_fraction'])
    fingers, knuckles = {}, []
    for i in range(4):
        height = (1.5 - i) * spacing + h['grip_height_offset'] * H
        theta = math.radians(h['grip_knuckle_degrees'])
        points = [ring_point(theta, height)]
        for length in h['phalanges']:
            theta += 2 * math.asin(min(1., length * H / (2 * Rf)))
            points.append(ring_point(theta, height))
        fingers[str(i)] = [p.tolist() for p in points]; knuckles.append(points[0])
    pieces = digit_pieces('hand_far', fingers, None, h, H, around=(grip, s))
    # Thumb from the palm's lower edge, wrapping the other way over the top.
    theta = math.radians(h['grip_thumb_root_degrees'])
    top = 1.5 * spacing + h['grip_height_offset'] * H + h['grip_thumb_above'] * H
    points = [ring_point(theta, top, Rf + h['finger_base'] * H * .2)]
    for length in h['thumb_phalanges']:
        theta -= 2 * math.asin(min(1., length * H / (2 * Rf)))
        points.append(ring_point(theta, top, Rf + h['finger_base'] * H * .2))
    thumb = [p.tolist() for p in points]
    pieces += digit_pieces('hand_far', {'thumb': thumb}, None, h, H, around=(grip, s))
    wrist = j['wrist_far']
    v, fc, _ = hand_v3.palm(wrist, knuckles, n, h['palm_thickness'] * H, h['wrist_width'] * H)
    pieces.append(shell('palm_far', 'hand_far', 'hand_far', v, fc, list(range(len(fc)))))
    v, fc, _ = hand_v3.cuff(wrist + fore * h['cuff_forward'] * H, fore, n, h['cuff_radius'] * H, h['cuff_length'] * H,
                            h['cuff_flare'], h['cuff_thickness'] * H)
    pieces.append(shell('gauntlet_cuff_far', 'hand_far', 'hand_far', v, fc, list(range(len(fc)))))
    return pieces, {'fingers': fingers, 'thumb': thumb, 'shaft_axis': s.tolist(), 'grip_radius_m': Rf,
                    'hand_tip': (grip + n * Rf).tolist(), 'wrap_frame': [(-f).tolist(), n.tolist()]}


def digit_pieces(part, digits, dorsal, h, H, around=None):
    pieces = []
    for name, points in digits.items():
        if around is not None:
            # Grip digits: each phalanx's dorsal side faces away from the shaft.
            centre, s = around; d = []
            for a, b in zip(points, points[1:]):
                mid = (np.asarray(a) + np.asarray(b)) / 2 - centre
                d.append(unit(mid - s * (mid @ s)))
        else:
            d = dorsal
        parts, widths = hand_v3.digit(points, h['finger_base'] * H, h['finger_tip'] * H, d, h['finger_depth_ratio'])
        for k, (v, f, flat) in enumerate(parts):
            label = ('thumb' if name == 'thumb' else 'finger_' + str(name)) + '_' + part.split('_')[1] + '_' + str(k)
            pieces.append(shell(label, part, part, v, f, list(range(len(f)))))
    return pieces
