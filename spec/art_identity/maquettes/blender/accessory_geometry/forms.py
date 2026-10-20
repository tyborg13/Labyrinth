"""Draft native accessories from explicit owner measurements, without taste defaults.

These helpers return existing builder piece types. They are opt-in and do not
change compilation, cache keys or pixels for any existing delivery.
"""
from copy import deepcopy
import math

import numpy as np

from ..contract import todos, vector
from ..source_recipe import common
from ..drape import tailor

GEOMETRY_DEFAULTS = {'epsilon_m': 1e-9, 'relative_epsilon': 1e-9, 'belt_samples': 32}


def complete(design):
    missing = todos(design, 'owner_design')
    if missing:
        raise ValueError('Unresolved design: ' + '; '.join(missing))


def positive(value, name):
    if type(value) not in (int, float) or not math.isfinite(value) or value <= 0:
        raise ValueError('Positive finite ' + name + ' required')
    return value


def pelvis_frame(spec):
    """The posed body's hip line supplies one frame for both camera views."""
    near, far = (np.asarray(spec['joints']['hip_' + side], float) for side in ('near', 'far'))
    lateral = near - far
    lateral[2] = 0
    width = np.linalg.norm(lateral)
    positive(float(width), 'hip width')
    lateral /= width
    up = np.array([0., 0, 1])
    return (near + far) / 2, np.cross(lateral, up), lateral, up, float(width)


def hair_piece(template, design, gates):
    complete(design)
    skull, scalp, tufts = (design[k] for k in ('skull', 'scalp', 'tufts'))
    for key in ('crown_m', 'base_m', 'ear_line_m'):
        vector(skull[key], 3, key)
    height = positive(skull['height_m'], 'skull height')
    width = positive(skull['width_m'], 'skull width')
    vector(scalp['centre_m'], 3, 'scalp centre')
    vector(scalp['radii_m'], 3, 'scalp radii')
    if min(scalp['radii_m']) <= 0:
        raise ValueError('Positive scalp radii required')
    up = np.subtract(skull['crown_m'], skull['base_m'], dtype=float)
    if not np.isclose(np.linalg.norm(up), height, atol=GEOMETRY_DEFAULTS['epsilon_m'], rtol=0):
        raise ValueError('Skull height must match the measured crown and base')
    up /= height
    centre = np.asarray(scalp['centre_m'])
    reach = float(np.linalg.norm(up * scalp['radii_m']))
    if centre @ up + reach < np.asarray(skull['crown_m']) @ up or centre @ up - reach > np.asarray(skull['ear_line_m']) @ up:
        raise ValueError('Scalp must cover the crown and sides down to ear height')
    # The cap need not extend down to the chin. Its lateral ellipsoid extent
    # must contain the skull axis in 3D, in addition to the height coverage.
    scaled_axis = up / scalp['radii_m']
    for landmark in ('crown_m', 'base_m'):
        offset = (np.asarray(skull[landmark]) - centre) / scalp['radii_m']
        lateral = offset - scaled_axis * (offset @ scaled_axis) / (scaled_axis @ scaled_axis)
        if np.linalg.norm(lateral) > 1 + GEOMETRY_DEFAULTS['relative_epsilon']:
            raise ValueError('Scalp must contain the skull axis within its lateral extent')
    if len(tufts) != gates['tuft_count'] or len({t['id'] for t in tufts}) != len(tufts):
        raise ValueError('Distinct measured tuft ids required for every tuft')
    if sum(t['role'] == 'fringe' for t in tufts) != gates['fringe_count']:
        raise ValueError('Four measured fringe tufts required')
    result = deepcopy(template)
    result.update(centre=deepcopy(scalp['centre_m']), radii=deepcopy(scalp['radii_m']))
    sections, roots, lengths, directions = [], [], [], []
    for tuft in tufts:
        if tuft['role'] not in ('mop', 'fringe'):
            raise ValueError('Tuft role must be mop or fringe')
        path, radii = tuft['path_m'], tuft['radii_m']
        if len(path) < 2 or len(path) != len(radii):
            raise ValueError('Tuft path and radii must correspond')
        for point in path:
            vector(point, 3, 'tuft path')
        for radius in radii:
            positive(radius, 'tuft radius')
        if radii[-1] >= radii[0]:
            raise ValueError('A tuft must taper to its tip')
        points = np.asarray(path)
        if np.linalg.norm((points[0] - centre) / scalp['radii_m']) > 1 + GEOMETRY_DEFAULTS['epsilon_m']:
            raise ValueError('Tuft root must join the scalp mass')
        if any(np.linalg.norm(points[0] - root) <= GEOMETRY_DEFAULTS['epsilon_m'] for root in roots):
            raise ValueError('No two tufts may share a root')
        roots.append(points[0])
        segments = np.linalg.norm(np.diff(points, axis=0), axis=1)
        if np.any(segments <= GEOMETRY_DEFAULTS['epsilon_m']):
            raise ValueError('Tuft path contains a zero-length segment')
        length = float(segments.sum()) / height
        low, high = gates['tuft_length_head_height']
        epsilon = GEOMETRY_DEFAULTS['relative_epsilon']
        if not low * (1 - epsilon) <= length <= high * (1 + epsilon):
            raise ValueError('Tuft length outside the brief head-height range: ' + tuft['id'])
        lengths.append(length)
        directions.append(points[-1] - points[0])
        sections.append({'path': deepcopy(path), 'radii': deepcopy(radii),
                         'sculpt': deepcopy(template['swept_sections'][0]['sculpt'])})
    if max(lengths) - min(lengths) <= GEOMETRY_DEFAULTS['epsilon_m']:
        raise ValueError('Tuft lengths must vary')
    # Width is measured along the explicitly supplied skull lateral axis.
    vector(skull['lateral_axis'], 3, 'skull lateral axis')
    axis = np.asarray(skull['lateral_axis'], float)
    if not np.isclose(np.linalg.norm(axis), 1, atol=GEOMETRY_DEFAULTS['epsilon_m'], rtol=0):
        raise ValueError('Skull lateral axis must be normalized')
    if not np.isclose(axis @ up, 0, atol=GEOMETRY_DEFAULTS['epsilon_m'], rtol=0):
        raise ValueError('Skull lateral and crown axes must be perpendicular')
    forward = np.cross(axis, up)
    directions = np.asarray(directions)
    vertical, sagittal, lateral = directions @ up, directions @ forward, directions @ axis
    if not (np.any(vertical > 0) and np.any((vertical > 0) & (sagittal < 0)) and
            np.any(lateral > 0) and np.any(lateral < 0) and np.any((vertical < 0) & (sagittal < 0))):
        raise ValueError('Tufts must include up, up-back, both sides and down-back directions')
    if any(not (vertical[i] < 0 and sagittal[i] > 0) for i, t in enumerate(tufts) if t['role'] == 'fringe'):
        raise ValueError('Every fringe tuft must point forward and down')
    scalp_width = 2 * float(np.linalg.norm(axis * result['radii']))
    if not np.isclose(scalp_width, width * gates['scalp_skull_width'], rtol=0,
                      atol=GEOMETRY_DEFAULTS['epsilon_m']):
        raise ValueError('Scalp width must be 1.25 times the measured skull width')
    result['swept_sections'] = sections
    return result


def belt_piece(spec, design, part, thickness):
    complete(design)
    origin, forward, lateral, up, _ = pelvis_frame(spec)
    depth, radius, height = (positive(design[k], k) for k in
                             ('forward_radius_m', 'lateral_radius_m', 'height_m'))
    positive(thickness, 'belt thickness')
    if thickness >= min(depth, radius):
        raise ValueError('Belt thickness must leave an open interior')
    n = GEOMETRY_DEFAULTS['belt_samples']
    vertices = []
    # Outer bottom/top, inner top/bottom: a closed band, never a flat tabard.
    for z, inset in ((-height / 2, 0), (height / 2, 0),
                     (height / 2, thickness), (-height / 2, thickness)):
        for angle in np.linspace(0, math.tau, n, endpoint=False):
            vertices.append((origin + up * z + forward * (depth - inset) * math.cos(angle) +
                             lateral * (radius - inset) * math.sin(angle)).tolist())
    faces = [[row * n + j, row * n + (j + 1) % n,
              ((row + 1) % 4) * n + (j + 1) % n, ((row + 1) % 4) * n + j]
             for row in range(4) for j in range(n)]
    result = common('leather_belt', 'rigid_shell', part)
    result.update(vertices=vertices, faces=faces, rig_joint='pelvis', rig_bone='pelvis', thick=thickness)
    return result


def flap_piece(template, spec, design, belt, side, gates):
    """Curved rows in the pelvis frame; no world-axis or per-view planes."""
    complete(design)
    complete(belt)
    if side not in ('front', 'rear'):
        raise ValueError('Flap side must be front or rear')
    origin, forward, lateral, up, _ = pelvis_frame(spec)
    # Outer anatomical width is an owner measurement. Joint separation alone
    # excludes the skin on both sides and must not silently define flap size.
    hip_width = positive(belt['hip_width_m'], 'outer hip width')
    sign = 1 if side == 'front' else -1
    thigh = np.mean([spec['joints']['hip_' + s][2] - spec['joints']['knee_' + s][2]
                     for s in ('near', 'far')])
    length = positive(float(thigh), 'thigh height') * gates['front_thigh_fraction'] + belt['height_m'] / 2
    if side == 'rear':
        ratio = design['front_length_ratio']
        if type(ratio) not in (int, float) or not 0 < ratio < 1:
            raise ValueError('Rear flap must be shorter than the front')
        length *= ratio
    source = design['rows']
    if len(source) < 2 or source[0]['drop_fraction'] != 0 or source[-1]['drop_fraction'] != 1:
        raise ValueError('Flap rows must cover the belt-to-hem interval')
    if any(b['drop_fraction'] <= a['drop_fraction'] for a, b in zip(source, source[1:])):
        raise ValueError('Flap rows must descend monotonically')
    if source[0]['width_fraction'] != 1 or source[0]['curve_m'] != 0:
        raise ValueError('Flap root must span half the hips in the belt tangent plane')
    n = template['pattern']['columns']
    rows = []
    for row in source:
        if not 0 < row['width_fraction'] <= 1:
            raise ValueError('Flap width fractions must lie in (0, 1]')
        if not math.isfinite(row['curve_m']) or not math.isfinite(row['forward_offset_m']):
            raise ValueError('Flap row depths must be finite')
        centre = origin + sign * forward * (belt['forward_radius_m'] + row['forward_offset_m'])
        centre += up * (belt['height_m'] / 2 - row['drop_fraction'] * length)
        width = hip_width * gates['flap_hip_width'] * row['width_fraction']
        rows.append([(centre + lateral * u * width / 2 + sign * forward * row['curve_m'] * (1 - u * u)).tolist()
                     for u in np.linspace(-1, 1, n)])
    if source[0]['forward_offset_m'] != 0:
        raise ValueError('Flap root must hang at the belt front/rear centre')
    result = deepcopy(template)
    result.pop('capture_view', None)
    result.pop('source_rows_px', None)
    result['pattern'] = {'columns': n, 'closed': False,
                         'rows': [{'points': row} for row in rows], 'pins': list(range(n))}
    settings = deepcopy(template['drape'])
    # Old world-X ray gathering is the bug being replaced. The authored root
    # is now held by the belt, while all free rows retain native collisions.
    for key in ('waist_anchor_px', 'waist_side', 'back_rest', 'gather_frames',
                'attach_pins_to_support', 'implementation_revision'):
        settings.pop(key, None)
    settings['pleat_direction'] = (sign * forward).tolist()
    return tailor(result, settings)
