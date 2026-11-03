"""Opt-in faceted plate forms: polygon lofts, tapered segments and blades.

Pure NumPy construction (no bpy). Every form is one closed, manifold shell with
flat end caps; nothing here closes a segment with a sphere, bead or capsule.
Only recipes that import this module use it; no existing figure does.
"""
import math
import numpy as np

FACETED_DEFAULTS = {'epsilon': 1e-12, 'tip_fraction': 1e-4}


def unit(v):
    v = np.asarray(v, float)
    n = np.linalg.norm(v)
    if n <= FACETED_DEFAULTS['epsilon']:
        raise ValueError('Undefined faceted direction')
    return v / n


def frame(axis, reference):
    """Orthonormal (side, front, axis); front is the reference made normal to axis."""
    w = unit(axis)
    f = np.asarray(reference, float) - w * (np.asarray(reference, float) @ w)
    if np.linalg.norm(f) <= 1e-9:
        f = np.cross(w, [0., 0., 1.]) if abs(w[2]) < .9 else np.cross(w, [1., 0., 0.])
    f = unit(f)
    s = np.cross(f, w)
    return s, f, w


def polygon_loft(sections, cap_start=True, cap_end=True):
    """Closed loft through equal-count polygon rings; a ring may collapse to a point.

    A single-point section closes that end as a sharp apex (no cap face).
    """
    rings = [np.asarray(s, float).reshape(-1, 3) for s in sections]
    n = max(len(r) for r in rings)
    if n < 3 or any(len(r) not in (1, n) for r in rings) or len(rings) < 2:
        raise ValueError('Polygon loft requires rings of one shared count, or apexes')
    if any(len(r) == 1 for r in rings[1:-1]):
        raise ValueError('Only an end section may be an apex')
    vertices, starts = [], []
    for r in rings:
        starts.append(len(vertices))
        vertices.extend(r.tolist())
    faces, flat = [], []
    for k in range(len(rings) - 1):
        a, b = starts[k], starts[k + 1]
        la, lb = len(rings[k]), len(rings[k + 1])
        for c in range(n):
            d = (c + 1) % n
            if la == 1:
                faces.append([a, b + d, b + c])
            elif lb == 1:
                faces.append([a + c, a + d, b])
            else:
                faces.append([a + c, a + d, b + d, b + c])
    if len(rings[0]) == n and cap_start:
        flat.append(len(faces))
        faces.append(list(reversed(range(starts[0], starts[0] + n))))
    if len(rings[-1]) == n and cap_end:
        flat.append(len(faces))
        faces.append(list(range(starts[-1], starts[-1] + n)))
    return vertices, faces, flat


def profile_ring(centre, side, front, half_width, half_depth, profile):
    """Place a unit 2D profile [(s, f), ...] at a station; s across, f forward."""
    c = np.asarray(centre, float)
    return [(c + side * half_width * s + front * half_depth * f).tolist() for s, f in profile]


def octagon_profile(ridge=0.0, back_flat=0.0):
    """Eight facets; the front vertex is pushed out by `ridge` (a medial plate ridge)."""
    out = []
    for k in range(8):
        a = math.tau * k / 8 + math.pi / 2
        s, f = math.cos(a), math.sin(a)
        if k == 0:
            f *= 1 + ridge
        if back_flat and f < -.5:
            f *= 1 - back_flat
        out.append((s, f))
    # Start at the front ridge and run toward +side; consistent winding.
    return out


def segment(start, end, reference, half_width, half_depth, stations, profile=None,
            extend=(0., 0.), back_bulge=None):
    """Tapered faceted plate tube from start to end with flat, overlapping ends.

    stations: [(t, scale)] with t in [0, 1] along start->end; extend lengthens the
    tube past either joint (metres) so it slides under a neighbouring cop/plate.
    back_bulge: optional [(t, extra)] added to the rear half-depth (calf shaping).
    """
    start, end = np.asarray(start, float), np.asarray(end, float)
    side, front, axis = frame(end - start, reference)
    length = np.linalg.norm(end - start)
    profile = profile or octagon_profile()
    sections = []
    for t, scale in stations:
        centre = start + axis * (-extend[0] + t * (length + extend[0] + extend[1]))
        bulge = float(np.interp(t, *zip(*back_bulge))) if back_bulge else 0.
        ring = []
        for s, f in profile:
            depth = half_depth * scale * (1 + (bulge if f < 0 else 0.))
            ring.append((centre + side * half_width * scale * s + front * depth * f).tolist())
        sections.append(ring)
    return polygon_loft(sections)


def blade(path, half_widths, half_depths, reference, sides=4):
    """Pointed faceted blade along a polyline: diamond (4) or hexagonal (6) section.

    The final station collapses to a sharp apex. `reference` gives the broad
    plane's normal (depth direction). No circular or rounded end is produced.
    """
    path = np.asarray(path, float)
    if len(path) < 2 or len(half_widths) != len(path) or len(half_depths) != len(path):
        raise ValueError('Blade needs one width/depth per path station')
    tangents = np.vstack([path[1] - path[0], path[2:] - path[:-2], path[-1] - path[-2]])
    sections = []
    for k, (p, t) in enumerate(zip(path, tangents)):
        if k == len(path) - 1:
            sections.append([p.tolist()])
            continue
        side, front, _ = frame(t, reference)
        ring = []
        for j in range(sides):
            a = math.tau * j / sides
            ring.append((p + side * half_widths[k] * math.cos(a) + front * half_depths[k] * math.sin(a)).tolist())
        sections.append(ring)
    return polygon_loft(sections)


def thick_sheet(rows, thickness, normals=None, periodic=False):
    """Closed two-skin sheet from a rectangular grid of mid-surface points."""
    rows = np.asarray(rows, float)
    nr, nc, _ = rows.shape
    if normals is None:
        along = np.gradient(rows, axis=0)
        across = (np.roll(rows, -1, axis=1) - np.roll(rows, 1, axis=1)) if periodic else np.gradient(rows, axis=1)
        normals = np.cross(across, along)
        normals /= np.maximum(np.linalg.norm(normals, axis=2), 1e-20)[:, :, None]
    count = nr * nc
    v = np.concatenate([(rows + normals * thickness / 2).reshape(-1, 3), (rows - normals * thickness / 2).reshape(-1, 3)])
    faces = []
    for r in range(nr - 1):
        for c in range(nc if periodic else nc - 1):
            d = (c + 1) % nc
            a, b = r * nc + c, r * nc + d
            face = [a, b, b + nc, a + nc]
            faces.extend([face, [i + count for i in reversed(face)]])
    if periodic:
        rims = [list(range(nc)), list(range((nr - 1) * nc, nr * nc))]
    else:
        rims = [list(range(nc)) + [r * nc + nc - 1 for r in range(1, nr)] +
                list(range(count - 2, count - nc - 1, -1)) + [r * nc for r in range(nr - 2, 0, -1)]]
    for ring in rims:
        for a, b in zip(ring, ring[1:] + ring[:1]):
            faces.append([a, a + count, b + count, b])
    return v.tolist(), faces
