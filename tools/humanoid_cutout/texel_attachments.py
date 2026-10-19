"""Copy a painted tip's weights from its eight-connected garment neighbour.

Only complete two-pixel cells containing the declared tip texels are replaced.
Their opaque texels get independent quads; all other triangles, vertices and
weights remain exact. Paint and UV registration never change.
"""
from copy import deepcopy

import numpy as np

from .mesh import GRID_PX, grid, weights_for

BARYCENTRIC_EPSILON = np.finfo(float).eps * 8  # Roundoff in the source-triangle solve.


def source_point(value):
    if not isinstance(value, list) or len(value) != 2 or any(type(v) is not int for v in value):
        raise ValueError('attachment coordinates require two source-pixel integers')
    return tuple(value)


def barycentric(mesh, point):
    """Find a point in its original grid cell, including boundary corners."""
    left, top, right, bottom = mesh['bbox']
    x, y = point
    if not left <= x <= right or not top <= y <= bottom:
        raise ValueError('attachment neighbour lies outside its garment')
    columns = (right - left + GRID_PX - 1) // GRID_PX
    rows = (bottom - top + GRID_PX - 1) // GRID_PX
    column = min(int((x - left) // GRID_PX), columns - 1)
    row = min(int((y - top) // GRID_PX), rows - 1)
    start = 2 * (row * columns + column)
    vertices = np.asarray(mesh['vertices'], dtype=float)
    for indices in mesh['triangles'][start:start + 2]:
        a, b, c = vertices[indices]
        bc = np.linalg.solve(np.column_stack((b - a, c - a)), np.asarray(point) - a)
        weights = np.array([1 - bc.sum(), *bc])
        if np.min(weights) >= -BARYCENTRIC_EPSILON:
            return indices, weights
    raise ValueError('attachment neighbour has no source triangle')


def base_mesh(mesh, layout, recipe):
    result = deepcopy(mesh)
    result.pop('texel_attachments', None)
    result['vertices'], result['uvs'], result['triangles'] = grid(mesh['bbox'])
    result['weights'] = weights_for(result['vertices'], mesh.get('weight_bounds', mesh['bbox']),
                                    layout['joints'], recipe)
    return result


def cells_for(mesh, points):
    left, top, right, bottom = mesh['bbox']
    cells = set()
    for x, y in points:
        if not left <= x < right or not top <= y < bottom:
            raise ValueError('attachment texel lies outside its garment')
        a = left + GRID_PX * ((x - left) // GRID_PX)
        b = top + GRID_PX * ((y - top) // GRID_PX)
        cells.add((a, b, min(a + GRID_PX, right), min(b + GRID_PX, bottom)))
    return cells


def attach(base, definitions):
    if not isinstance(definitions, list) or not definitions:
        raise ValueError('attachments require a nonempty neighbour list')
    parents = {}
    for row in definitions:
        if not isinstance(row, dict) or set(row) != {'texel', 'neighbour'}:
            raise ValueError('attachment requires texel and neighbour')
        point, parent = source_point(row['texel']), source_point(row['neighbour'])
        if point in parents or max(abs(a - b) for a, b in zip(point, parent)) != 1:
            raise ValueError('attachment needs one unique eight-connected neighbour')
        parents[point] = parent
    cache, resolving = {}, set()

    def inherited(point):
        if point in cache: return cache[point]
        if point in resolving: raise ValueError('cyclic texel attachment')
        resolving.add(point)
        if point in parents:
            values = inherited(parents[point])
        else:
            indices, bary = barycentric(base, (point[0] + .5, point[1] + .5))
            values = {bone: float(bary @ np.asarray(weights)[indices])
                      for bone, weights in base['weights'].items()}
        resolving.remove(point)
        cache[point] = values
        return values

    cells = cells_for(base, parents)
    result = deepcopy(base)
    vertices = np.asarray(base['vertices'])
    result['triangles'] = [indices for indices in base['triangles']
        if tuple([*vertices[indices].min(axis=0), *vertices[indices].max(axis=0)]) not in cells]
    left, top = base['bbox'][:2]
    for point in sorted(parents, key=lambda p: (p[1], p[0])):
        x, y = point
        start = len(result['vertices'])
        corners = [[x, y], [x + 1, y], [x, y + 1], [x + 1, y + 1]]
        result['vertices'].extend(corners)
        result['uvs'].extend([[u - left, v - top] for u, v in corners])
        result['triangles'].extend([[start, start + 1, start + 2], [start + 1, start + 3, start + 2]])
        for bone, value in inherited(point).items(): result['weights'][bone].extend([value] * 4)
    result['texel_attachments'] = deepcopy(definitions)
    return result


def surface_errors(layout, images, continuations):
    errors = []
    for mesh in layout.get('joint_meshes', []):
        if 'texel_attachments' not in mesh: continue
        try:
            points = {source_point(row['texel']) for row in mesh['texel_attachments']}
            parents = {source_point(row['neighbour']) for row in mesh['texel_attachments']}
            image, tuck = images[mesh['name']], continuations[mesh['name']]
            for x, y in points | parents:
                if not (0 <= y < image.shape[0] and 0 <= x < image.shape[1] and
                        image[y, x, 3] and not tuck[y, x]):
                    raise ValueError('attachment and neighbour must both be original garment paint')
            covered = set()
            for left, top, right, bottom in cells_for(mesh, points):
                covered.update((x, y) for y in range(top, bottom) for x in range(left, right)
                               if image[y, x, 3])
            if covered != points:
                raise ValueError('attachment must retain every painted texel of its replaced cells')
        except (ValueError, KeyError, TypeError) as error:
            errors.append('texel attachment: ' + mesh['name'] + ': ' + str(error))
    return errors
