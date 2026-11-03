"""Feedback 1: shorten inherited curved axes and thicken their cross-sections.

No body transform is performed here. Radius and axis length are independent;
uniform shrinking would reproduce the rejected pegs.
"""
from copy import deepcopy
import numpy as np

from .recipe import CONSTRAINTS, PROOF_DEFAULTS, length_m
from spec.art_identity.maquettes.blender.limb_mesh import LIMB_DEFAULTS, sampled_axis, section_mesh


def minimum_width(points):
    """Minimum Feret width of the actual planar hip polygon, not its bbox."""
    points = np.array(points, float)
    _, _, basis = np.linalg.svd(points - points.mean(0), full_matrices=False)
    flat = np.einsum('ni,ji->nj', points - points.mean(0), basis[:2])
    edges = np.roll(flat, -1, axis=0) - flat
    normals = np.stack([-edges[:, 1], edges[:, 0]], axis=1)
    normals /= np.linalg.norm(normals, axis=1)[:, None]
    return float(np.ptp(np.einsum('ni,ji->nj', flat, normals), axis=0).min())


def build(piece, placement, old_tip, axis_limit_L=None):
    origin = np.array(piece['path'][0])
    original_axis = np.array([p for p, _ in sampled_axis(piece['path'],
                             [piece['radius'] * r for r in piece['taper']])])
    # One numerical epsilon keeps the exact bounds after float32 mesh storage.
    margin = PROOF_DEFAULTS['epsilon_m']
    limit = CONSTRAINTS['leg_length_L'] if axis_limit_L is None else axis_limit_L
    factor = min(1, (limit * length_m() - margin) /
                 np.linalg.norm(np.diff(original_axis, axis=0), axis=1).sum())
    path = (np.array(piece['path']) - origin) * factor
    radii = np.array(piece['taper']) * piece['radius'] * factor
    sculpt = deepcopy(piece['sculpt'])
    sides = sculpt.get('radial_samples', LIMB_DEFAULTS['radial_samples'])
    initial, _ = section_mesh(path, radii, sculpt)
    radius_factor = max(1, (CONSTRAINTS['hip_minimum_width_L'] * length_m() + margin) /
                        minimum_width(initial[:sides]))
    radii *= radius_factor
    for spine in sculpt.get('spines', []):
        spine['length'] *= factor * radius_factor
        spine['radius'] *= factor * radius_factor
    points, faces = section_mesh(path, radii, sculpt)
    points = np.array(points)
    translation = np.array(placement['centre'])
    translation[1] += (1 if 'near' in piece['part'] else -1) * placement['width'] / 2
    translation[2] = -points[:, 2].min()
    points += translation
    base = translation.copy()
    tip = base + (np.array(old_tip) - origin) * factor
    metadata = {'axis_factor': factor, 'radius_factor': radius_factor,
                'radial_samples': sides, 'axis_samples': len(original_axis),
                'hook_span_samples': LIMB_DEFAULTS['samples_per_span']}
    return points, faces, [base, tip], metadata


def screen_gap(points, faces, spec, view, envelope):
    """Exact binary triangle coverage at the lowest occupied native row."""
    from spec.art_identity.maquettes.raster import project, triangle_samples
    px = project(spec, points, view)
    triangles = np.array([[face[0], face[i], face[i + 1]] for face in faces
                          for i in range(1, len(face) - 1)])
    tris = px[triangles]
    low, high = tris[:, :, 1].min(1), tris[:, :, 1].max(1)
    bottom = min(1023, int(np.floor(high.max() - .5)))
    while bottom >= 0:
        columns = set()
        for tri in tris[(low <= bottom + .5) & (high >= bottom + .5)]:
            samples = triangle_samples(tri, 1024, 1024)
            if samples is not None:
                yy, xx, _ = samples
                columns.update(xx[yy == bottom].tolist())
        if columns:
            # A one-pixel fringe can move the lowest sample into an adjacent
            # steep body column; a Y-only margin misses that rear-view case.
            fringe = PROOF_DEFAULTS['screen_antialias_radius_px']
            columns = {x + dx for x in columns for dx in range(-fringe, fringe + 1)
                       if 0 <= x + dx < 1024}
            if any(envelope[x] < 0 for x in columns):
                return None
            return max(max(0, bottom + fringe - envelope[x]) for x in columns)
        bottom -= 1
    return None


def fit(piece, placement, old_tip, spec, contract):
    """Keep the longest inherited axis satisfying both projected foot limits.

    Body envelopes are locked from approved native solos. The two-pixel
    antialias guard is numerical; final acceptance uses actual Blender PNGs.
    """
    upper = CONSTRAINTS['leg_length_L']
    target = CONSTRAINTS['foot_screen_clearance_px'] - PROOF_DEFAULTS['screen_raster_guard_px']
    def candidate(limit):
        result = build(piece, placement, old_tip, limit)
        points = result[0] + [0, 0, contract['floor_z_m']]
        gaps = {view: screen_gap(points, result[1], spec, view, envelope)
                for view, envelope in contract['body_lower_envelope_px'].items()}
        good = all(value is not None and value <= target for value in gaps.values())
        return result, gaps, good
    previous = upper
    for limit in np.linspace(upper, upper / PROOF_DEFAULTS['leg_fit_steps'], PROOF_DEFAULTS['leg_fit_steps']):
        result, gaps, good = candidate(float(limit))
        if good:
            break
        previous = float(limit)
    else:
        raise ValueError('No short, thick grounded leg meets the screen bound: ' + piece['id'])
    lower = float(limit)
    for _ in range(PROOF_DEFAULTS['leg_fit_refinements']):
        middle = (lower + previous) / 2
        attempt, measured, good = candidate(middle)
        if good:
            lower, result, gaps = middle, attempt, measured
        else:
            previous = middle
    result[3].update(axis_limit_L=lower, raster_clearance_px=gaps,
                     raster_guard_px=PROOF_DEFAULTS['screen_raster_guard_px'])
    return result


def measure(points, metadata, floor_z, length):
    sides, rows = metadata['radial_samples'], metadata['axis_samples']
    sections = np.array(points[:sides * rows]).reshape(rows, sides, 3)
    axis = sections.mean(1)
    hip = sections[0]
    return {'axis_length_L': float(np.linalg.norm(np.diff(axis, axis=0), axis=1).sum() / length),
            'hip_width_L': minimum_width(hip) / length,
            'hip_height_L': float((axis[0, 2] - floor_z) / length),
            'hip_top_L': float((hip[:, 2].max() - floor_z) / length),
            'hook_forward_m': float(axis[-1, 0] - axis[-1 - metadata['hook_span_samples'], 0])}
