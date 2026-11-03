"""Translate a rigid seated plate into contact with the actual solved cloth.

The convex support provides a legal starting pose. Move toward the nearest
actual fabric point, bounded by the same native collision samples, clearance
and pixel silhouette constraints. No plate dimensions or garment vertices move.
"""
import numpy as np

from .contract import BUILD_DEFAULTS
from ..raster import project


def cloth_support(objects):
    from mathutils import Vector
    from mathutils.bvhtree import BVHTree
    from .cloth_contacts import mesh_payload

    points, faces, samples = [], [], []
    for obj in objects:
        data = mesh_payload(obj)
        offset = len(points)
        points.extend(data['vertices'])
        faces.extend([i+offset for i in f] for f in data['faces'])
        samples.extend(data['vertices'])
        for face in data['faces']:
            vertices = np.array([data['vertices'][i] for i in face])
            samples.append(vertices.mean(0).tolist())
            samples.extend(((vertices+np.roll(vertices, -1, axis=0))/2).tolist())
    return (BVHTree.FromPolygons([Vector(p) for p in points], faces), np.array(samples))


def settle(points, faces, support, clearance, margin, spec, bounds):
    from mathutils import Vector
    from mathutils.bvhtree import BVHTree
    from .cloth_contacts import COLLISION_DEFAULTS, inside
    from .back_plate_seat import feasible_parameter

    points = np.asarray(points, float)
    cloth_tree, samples = support
    contacts = [(cloth_tree.find_nearest(Vector(p)), p) for p in points]
    (near, _, _, distance), vertex = min(contacts, key=lambda row: row[0][3])
    if distance <= clearance:
        return points.tolist(), {'initial_gap_m': distance, 'final_gap_m': distance, 'translation_m': [0., 0., 0.]}
    delta = (np.asarray(near)-vertex) * ((distance-clearance)/distance)
    pixels = project(spec, points)[:, 0]
    dx = project(spec, [points[0]+delta])[0, 0]-pixels[0]
    interval = feasible_parameter(pixels.min(), pixels.max(), dx, *bounds)
    if interval is None:
        raise ValueError('Plate contact starts outside the shoulder bound')
    delta *= interval[1]
    path = np.vstack((points, points+delta))
    samples = samples[((samples >= path.min(0)-margin).all(1) & (samples <= path.max(0)+margin).all(1))]
    epsilon = BUILD_DEFAULTS['collision_epsilon']

    def legal(fraction):
        current = points+fraction*delta
        tree = BVHTree.FromPolygons([Vector(p) for p in current], faces)
        if tree.overlap(cloth_tree):
            return False
        local = samples[((samples >= current.min(0)-margin).all(1) &
                         (samples <= current.max(0)+margin).all(1))]
        for raw in local:
            point = Vector(raw)
            nearest, normal, _, gap = tree.find_nearest(point)
            if gap < margin+epsilon or ((point-nearest).dot(normal) < 0 and inside(tree, point)):
                return False
        return True

    if not legal(0):
        raise ValueError('Rigid plate support pose is not collision-free')
    fraction = 1.
    if not legal(fraction):
        low, high = 0., 1.
        for _ in range(COLLISION_DEFAULTS['constraint_passes']):
            middle = (low+high)/2
            if legal(middle):
                low = middle
            else:
                high = middle
        fraction = low
    result = points+fraction*delta
    final = min(cloth_tree.find_nearest(Vector(p))[3] for p in result)
    tree = BVHTree.FromPolygons([Vector(p) for p in result], faces)
    local = samples[((samples >= result.min(0)-clearance).all(1) &
                     (samples <= result.max(0)+clearance).all(1))]
    if len(local):
        final = min(final, min(tree.find_nearest(Vector(p))[3] for p in local))
    return result.tolist(), {'initial_gap_m': distance, 'final_gap_m': final,
                             'translation_m': (fraction*delta).tolist()}
