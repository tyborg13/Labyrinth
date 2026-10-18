"""Source-pixel registration for fitted native maquettes; no artwork is produced.

All appearance inputs belong to each figure's measured JSON recipe. These
helpers convert those measurements through the existing board camera.
"""
from copy import deepcopy
import math

import numpy as np

from ..raster import camera, project


RECIPE_DEFAULTS = {'source_size': 256, 'panel_columns': 16,
                   'linear_solve_rcond': None, 'length_epsilon': 1e-10}


def paired_point(spec, front, rear, size=256):
    """Least-squares triangulation; retain the residual instead of hiding it."""
    equations, values = [], []
    for view, pixel in [('front', front), ('rear', rear)]:
        matrix, target, basis, scale = camera(spec, view)
        for axis, value in [(0, (pixel[0] / size - .5) * scale),
                            (1, (.5 - pixel[1] / size) * scale)]:
            equations.append(basis[axis] @ matrix[:3, :3])
            values.append(value + basis[axis] @ (target - matrix[:3, 3]))
    return np.linalg.lstsq(equations, values, rcond=RECIPE_DEFAULTS['linear_solve_rcond'])[0].tolist()


def plane_point(spec, pixel, axis, coordinate, size=256, view='front'):
    """Intersect a source ray with an explicitly measured body-space plane."""
    matrix, target, basis, scale = camera(spec, view)
    normal = np.eye(3)[axis]
    equations = np.array([basis[0] @ matrix[:3, :3], basis[1] @ matrix[:3, :3], normal])
    values = [(pixel[0] / size - .5) * scale + basis[0] @ (target - matrix[:3, 3]),
              (.5 - pixel[1] / size) * scale + basis[1] @ (target - matrix[:3, 3]), coordinate]
    return np.linalg.solve(equations, values).tolist()


def common(identifier, kind, part):
    return {'id': identifier, 'type': kind, 'part': part, 'at': 'root',
            'offset': [0, 0, 0], 'rot': [0, 0, 0]}


def path_points(spec, item):
    if 'joints' in item:
        return [spec['joints'][name] for name in item['joints']]
    if 'rear_path_px' in item:
        if len(item['rear_path_px']) != len(item['path_px']):
            raise ValueError('Spatial path requires corresponding front/rear controls')
        return [paired_point(spec, front, rear) for front, rear in zip(item['path_px'], item['rear_path_px'])]
    return [plane_point(spec, pixel, item['plane_axis'], item['plane_coordinate']) for pixel in item['path_px']]


def cloth(identifier, part, kind, rows, closed, physics, pins=None):
    """An authored static drape, using native cloth and the existing cache."""
    n = len(rows[0])
    if any(len(row) != n for row in rows):
        raise ValueError('Cloth rows must have equal sample counts')
    result = common(identifier, 'cloth', part)
    result.update(deepcopy(physics))
    result.update(kind=kind, pattern={'columns': n, 'closed': closed,
        'rows': [{'points': row} for row in rows],
        'pins': list(range(n * len(rows))) if pins is None else pins},
        pin_group=identifier + '_pins')
    return result


def panel(spec, identifier, part, kind, source_rows, axis, coordinate, physics, view='front'):
    n = RECIPE_DEFAULTS['panel_columns']
    rows = [[plane_point(spec, [(1 - u) * a[0] + u * b[0],
                                (1 - u) * a[1] + u * b[1]], axis, coordinate, view=view)
             for u in np.linspace(0, 1, n)] for a, b in source_rows]
    result = cloth(identifier, part, kind, rows, False, physics)
    result['source_rows_px'] = source_rows
    return result


def sleeve(spec, identifier, part, centres, radii, physics, seam_direction=None, seam_end=None):
    """Native sewn tube following measured limb centres and half-widths."""
    points = np.array(centres, float)
    rows = []
    for i, (point, radius) in enumerate(zip(points, radii)):
        direction = points[min(i + 1, len(points) - 1)] - points[max(i - 1, 0)]
        if seam_direction is not None and ((seam_end == 'start' and i == 0) or (seam_end == 'end' and i == len(points) - 1)):
            direction = np.array(seam_direction, float)
        direction /= np.linalg.norm(direction)
        first = np.cross(direction, [1, 0, 0])
        if np.linalg.norm(first) < RECIPE_DEFAULTS['length_epsilon']:
            first = np.cross(direction, [0, 1, 0])
        first /= np.linalg.norm(first)
        second = np.cross(direction, first)
        rows.append([(point + radius * (first * math.cos(a) + second * math.sin(a))).tolist()
                     for a in np.linspace(0, math.tau, RECIPE_DEFAULTS['panel_columns'], endpoint=False)])
    return cloth(identifier, part, 'skirt', rows, True, physics)


def curve(identifier, part, path, radius, taper, closed=False):
    result = common(identifier, 'curve', part)
    result.update(path=path, radius=radius, taper=taper, closed=closed,
                  spline='POLY', resolution=8, bevel_resolution=2)
    return result


def measurement_residuals(spec, measurements):
    return {view: {name: (project(spec, spec['joints'][name], view,
                  RECIPE_DEFAULTS['source_size'])[:2] - pixels[index]).tolist()
                  for name, pixels in measurements.items()}
            for index, view in enumerate(('front', 'rear'))}


def bounded_hem(spec, points, contours, size=256):
    """Raise a measured hem only as far as both source lower contours allow."""
    result = []
    for raw in points:
        point = np.array(raw, float)
        for view, contour in contours.items():
            matrix, target, basis, scale = camera(spec, view)
            pixel = project(spec, point, view, size)
            bottom = float(np.interp(pixel[0], *np.array(contour, float).T))
            up = basis[1] @ matrix[:3, :3]
            desired = (.5 - bottom / size) * scale + basis[1] @ (target - matrix[:3, 3])
            point[2] = max(point[2], (desired - up[:2] @ point[:2]) / up[2])
        result.append(point.tolist())
    return result
