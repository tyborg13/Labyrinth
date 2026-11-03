"""Opt-in pointed plate cops (couters/poleyns) for articulated plate limbs.

A cop is one closed curved plate around the convex side of a joint: it wraps a
set fraction of the circumference, overlaps both neighbouring segments along
their own axes and rises in straight (tent) profiles to a pointed apex on the
outer bisector. Optional side wings flare the same plate at its two edges.
No spherical, bead or capsule surface is produced. Pure NumPy.
"""
import math
import numpy as np
from .faceted_forms import unit

COP_DEFAULTS = {'rows': 13, 'columns': 25, 'bend_rows': 5, 'straight_epsilon_degrees': 2.}


def rotate(v, axis, angle):
    k = unit(axis); v = np.asarray(v, float)
    return v * math.cos(angle) + np.cross(k, v) * math.sin(angle) + k * (k @ v) * (1 - math.cos(angle))


def bend_frame(proximal, distal, fallback_outer):
    """Unit proximal/distal axes, convex (outer) direction and hinge axis."""
    a, b = unit(proximal), unit(distal)
    angle = math.acos(float(np.clip(a @ b, -1, 1)))
    if math.degrees(angle) < COP_DEFAULTS['straight_epsilon_degrees']:
        outer = np.asarray(fallback_outer, float)
        outer = unit(outer - a * (outer @ a))
        hinge = unit(np.cross(a, outer))
        return a, a.copy(), outer, hinge, 0.
    outer = unit(a - b)
    hinge = unit(np.cross(a, b))
    return a, b, outer, hinge, angle


def pointed_cop(joint, proximal, distal, radius, thickness, overlap, point, wrap_degrees=180.,
                fallback_outer=(1., 0., 0.), point_half_angle_degrees=60., wings=None, columns=None):
    """Closed pointed cop shell.

    joint: joint centre. proximal: bone direction into the joint; distal: out of it.
    radius: inner surface radius (seated just outside both segments).
    overlap: plate extent along each neighbouring segment from the joint (m).
    point: apex height above the plate surface on the outer bisector (m).
    wings: optional (height, start_degrees) flaring both side edges outward.
    Returns (vertices, faces, apex_point, info).
    """
    joint = np.asarray(joint, float)
    a, b, outer, hinge, angle = bend_frame(proximal, distal, fallback_outer)
    cols = columns or COP_DEFAULTS['columns']
    half = math.radians(wrap_degrees) / 2
    psis = np.linspace(-half, half, cols)
    straight = COP_DEFAULTS['rows']
    # Spine parameter: proximal straight run, bend sweep about the hinge, distal run.
    stations = []
    for s in np.linspace(-overlap, 0, straight // 2 + 1)[:-1]:
        stations.append(('p', s, 0.))
    for phi in np.linspace(0, angle, COP_DEFAULTS['bend_rows']):
        stations.append(('b', 0., phi))
    for s in np.linspace(0, overlap, straight // 2 + 1)[1:]:
        stations.append(('d', s, angle))
    arc = radius * angle
    def spine_distance(kind, s, phi):
        if kind == 'p':
            return s - arc / 2
        if kind == 'b':
            return radius * phi - arc / 2
        return s + arc / 2
    reach = overlap + arc / 2
    e1 = outer if angle == 0 else unit(outer - a * (outer @ a))
    outer_rows, inner_rows = [], []
    for kind, s, phi in stations:
        if kind == 'p':
            centre, axis_dir, e = joint + a * s, a, e1
        elif kind == 'b':
            centre, axis_dir, e = joint, rotate(a, hinge, phi), rotate(e1, hinge, phi)
        else:
            centre, axis_dir, e = joint + b * s, b, rotate(e1, hinge, angle)
        e2 = unit(np.cross(axis_dir, e))
        d = abs(spine_distance(kind, s, phi)) / reach
        along = max(0., 1 - d)
        orow, irow = [], []
        for psi in psis:
            radial = math.cos(psi) * e + math.sin(psi) * e2
            across = max(0., 1 - abs(math.degrees(psi)) / point_half_angle_degrees)
            lift = point * along * across
            if wings:
                height, start = wings
                flare = max(0., (abs(math.degrees(psi)) - start) / (math.degrees(half) - start))
                lift += height * flare * along
            orow.append((centre + radial * (radius + thickness + lift)).tolist())
            irow.append((centre + radial * radius).tolist())
        outer_rows.append(orow); inner_rows.append(irow)
    outer_rows = np.asarray(outer_rows); inner_rows = np.asarray(inner_rows)
    nr, nc = outer_rows.shape[:2]; count = nr * nc
    vertices = np.concatenate([outer_rows.reshape(-1, 3), inner_rows.reshape(-1, 3)])
    faces = []
    for r in range(nr - 1):
        for c in range(nc - 1):
            q = [r * nc + c, r * nc + c + 1, (r + 1) * nc + c + 1, (r + 1) * nc + c]
            faces.append(q); faces.append([i + count for i in reversed(q)])
    rim = (list(range(nc)) + [r * nc + nc - 1 for r in range(1, nr)] +
           list(range(count - 2, count - nc - 1, -1)) + [r * nc for r in range(nr - 2, 0, -1)])
    for p, q in zip(rim, rim[1:] + rim[:1]):
        faces.append([p, p + count, q + count, q])
    apex_dir = rotate(e1, hinge, angle / 2)
    apex = joint + apex_dir * (radius + thickness + point)
    info = {'bend_degrees': math.degrees(angle), 'outer_bisector': apex_dir.tolist(),
            'hinge_axis': hinge.tolist(), 'wrap_degrees': wrap_degrees,
            'overlap_m': overlap, 'point_m': point, 'inner_radius_m': radius,
            'thickness_m': thickness, 'apex': apex.tolist()}
    return vertices.tolist(), faces, apex.tolist(), info
