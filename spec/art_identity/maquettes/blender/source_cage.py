"""Two-view outline cages for the approved anatomy's editable corrective shape.

The cage changes native CC0 vertices, retaining topology, heat weights and the
armature. Outlines are measurements supplied by the figure recipe, not paint.
"""
import numpy as np

from ..raster import camera, project


CAGE_DEFAULTS = {'source_size': 256, 'profile_bins': 32, 'epsilon': 1e-8,
                 'support_weight_min': .25}


def relax_offsets(offsets, faces, selected, iterations, factor):
    """Regularize only the corrective field, preserving native skin detail.

    Coordinates are never Laplacian-smoothed: doing so would shrink anatomy.
    Unfitted vertices remain fixed and disconnected components cannot mix.
    """
    if type(iterations) is not int or not 0 <= iterations <= 64 or not 0 <= factor <= 1:
        raise ValueError('Source relaxation requires bounded iterations and factor')
    values = np.asarray(offsets, float).copy()
    edges = sorted({tuple(sorted((int(a), int(b)))) for face in faces
                    for a, b in zip(face, [*face[1:], face[0]])})
    if not edges or not iterations:
        return values
    pairs = np.asarray(edges)
    source, target = np.r_[pairs[:, 0], pairs[:, 1]], np.r_[pairs[:, 1], pairs[:, 0]]
    degree = np.bincount(source, minlength=len(values))
    active = np.asarray(selected, bool) & (degree > 0)
    for _ in range(iterations):
        average = np.column_stack([np.bincount(source, weights=values[target, axis],
                                               minlength=len(values)) for axis in range(3)])
        average[active] /= degree[active, None]
        values[active] = (1 - factor) * values[active] + factor * average[active]
    return values


def polygon_bounds(polygon, y):
    polygon = np.asarray(polygon, float)
    y = np.clip(y, polygon[:, 1].min() + CAGE_DEFAULTS['epsilon'],
                polygon[:, 1].max() - CAGE_DEFAULTS['epsilon'])
    intersections = []
    for a, b in zip(polygon, np.roll(polygon, -1, axis=0)):
        if min(a[1], b[1]) <= y < max(a[1], b[1]):
            intersections.append(a[0] + (b[0] - a[0]) * (y - a[1]) / (b[1] - a[1]))
    if len(intersections) < 2:
        raise ValueError('Measured outline has no interior at row ' + str(y))
    return min(intersections), max(intersections)


def warped_projection(points, polygon):
    points = np.asarray(points, float)
    polygon = np.asarray(polygon, float)
    lo, hi = points[:, 1].min(), points[:, 1].max()
    if hi - lo < CAGE_DEFAULTS['epsilon']:
        raise ValueError('Degenerate native region projection')
    bins = np.linspace(lo, hi, CAGE_DEFAULTS['profile_bins'] + 1)
    centres, left, right = [], [], []
    for a, b in zip(bins[:-1], bins[1:]):
        selected = points[(points[:, 1] >= a) & (points[:, 1] <= b)]
        if len(selected):
            centres.append((a + b) / 2)
            left.append(selected[:, 0].min())
            right.append(selected[:, 0].max())
    lower = np.interp(points[:, 1], centres, left)
    upper = np.interp(points[:, 1], centres, right)
    fraction = np.clip((points[:, 0] - lower) / np.maximum(upper - lower, CAGE_DEFAULTS['epsilon']), 0, 1)
    y = polygon[:, 1].min() + (points[:, 1] - lo) / (hi - lo) * np.ptp(polygon[:, 1])
    bounds = np.array([polygon_bounds(polygon, row) for row in y])
    return np.column_stack([bounds[:, 0] + fraction * (bounds[:, 1] - bounds[:, 0]), y])


def fit_points(spec, points, profiles):
    """Fit one anatomical region to both measured outlines in one 3D solve."""
    points = np.asarray(points, float)
    if len(profiles) == 1:
        # A partly occluded opposite view supplies no full silhouette. Retain
        # the approved native depth and fit the observed camera plane only.
        view, polygon = next(iter(profiles.items()))
        pixels = project(spec, points, view, CAGE_DEFAULTS['source_size'])[:, :2]
        desired = warped_projection(pixels, polygon)
        matrix, _, basis, scale = camera(spec, view)
        right, up = (axis @ matrix[:3, :3] for axis in basis[:2])
        delta = (desired - pixels) * scale / CAGE_DEFAULTS['source_size']
        return points + delta[:, :1] * right - delta[:, 1:] * up
    equations, values = [], []
    for view in ('front', 'rear'):
        pixels = warped_projection(project(spec, points, view, CAGE_DEFAULTS['source_size'])[:, :2], profiles[view])
        matrix, target, basis, scale = camera(spec, view)
        for axis, value in [(0, (pixels[:, 0] / CAGE_DEFAULTS['source_size'] - .5) * scale),
                            (1, (.5 - pixels[:, 1] / CAGE_DEFAULTS['source_size']) * scale)]:
            equations.append(basis[axis] @ matrix[:3, :3])
            values.append(value + basis[axis] @ (target - matrix[:3, 3]))
    return np.linalg.lstsq(np.asarray(equations), np.asarray(values), rcond=None)[0].T


def unpose_point(point, matrices, weights):
    weights = np.asarray(weights, float)
    weights /= weights.sum()
    skinning = np.einsum('i,ijk->jk', weights, np.asarray(matrices))
    return np.linalg.solve(skinning, [*point, 1])[:3]


def fit_body(spec, body, rig, posed):
    import bpy
    from .rig import evaluated_mesh
    profiles = spec['base'].get('source_profiles')
    if not profiles:
        return None
    regions = {b['name']: b['region'] for b in spec['armature']['bones']}
    weights = [{body.vertex_groups[g.group].name: g.weight for g in v.groups if g.weight > 0 and
                body.vertex_groups[g.group].name in regions} for v in body.data.vertices]
    source = np.asarray([list(v.co) for v in posed.data.vertices])
    desired = source.copy()
    totals = [{region: sum(weight for bone, weight in vertex.items() if regions[bone] == region)
               for region in set(regions.values())} for vertex in weights]
    # Fit the complete support of each region, then blend at weight boundaries.
    offsets = np.zeros_like(source)
    normalization = np.zeros(len(source))
    for region, outlines in profiles.items():
        indices = [i for i, vertex in enumerate(totals) if vertex.get(region, 0) > CAGE_DEFAULTS['support_weight_min']]
        if not indices:
            raise ValueError('Measured source region has no heat-weight support: ' + region)
        fitted = fit_points(spec, source[indices], outlines)
        for index, destination in zip(indices, fitted):
            weight = totals[index][region]
            offsets[index] += (destination - source[index]) * weight
            normalization[index] += weight
    selected = normalization > CAGE_DEFAULTS['epsilon']
    offsets[selected] /= normalization[selected, None]
    relaxation = spec['base'].get('source_fit_relaxation')
    if relaxation:
        relaxed = selected.copy()
        for region in relaxation.get('preserve_regions', []):
            relaxed &= np.array([vertex.get(region, 0) <= CAGE_DEFAULTS['support_weight_min'] for vertex in totals])
        offsets = relax_offsets(offsets, [list(p.vertices) for p in posed.data.polygons], relaxed,
                                relaxation['iterations'], relaxation['factor'])
    desired[selected] += offsets[selected]
    transforms = {name: np.asarray(rig.pose.bones[name].matrix @ rig.data.bones[name].matrix_local.inverted())
                  for name in regions}
    body.shape_key_add(name='CC0_original')
    corrective = body.shape_key_add(name='source_outline_fit')
    for index in np.flatnonzero(selected):
        vertex = weights[index]
        corrective.data[index].co = unpose_point(desired[index], [transforms[name] for name in vertex], list(vertex.values()))
    corrective.value = 1
    bpy.context.view_layer.update()
    old = posed.data
    posed.data = evaluated_mesh(body)
    bpy.data.meshes.remove(old)
    actual = np.asarray([list(v.co) for v in posed.data.vertices])
    error = np.linalg.norm(actual[selected] - desired[selected], axis=1)
    return {'regions': sorted(profiles), 'vertices': int(selected.sum()),
            'profile_views': {part: sorted(views) for part, views in profiles.items()},
            'maximum_skinning_error': float(error.max()),
            'maximum_displacement': float(np.linalg.norm(desired - source, axis=1).max()),
            'native_corrective_shape': corrective.name}
