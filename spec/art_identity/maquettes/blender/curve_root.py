"""Seat a measured thorn/root in its native support, retaining its tip."""
from copy import deepcopy
import numpy as np

ROOT_DEFAULTS = {'epsilon': 1e-8}


def reroot(path, root):
    points = np.asarray(path, float)
    if len(points) < 2:
        raise ValueError('A seated curve requires a root and a tip')
    delta = np.asarray(root) - points[0]
    return (points + np.linspace(1, 0, len(points))[:, None] * delta).tolist()


def fit(piece):
    import bpy
    from mathutils import Vector
    from .conformance import body_tree, regional_body
    target = bpy.data.objects['posed_body' if piece['root_on'] == '@body' else piece['root_on'] + '_render']
    if piece['root_on'] == '@body':
        target = regional_body(target, {'id': piece['id'] + '_root_support', 'body_regions': [piece['part']]})
    tree = body_tree(target)
    root, tip = Vector(piece['path'][0]), Vector(piece['path'][-1])
    direction = root - tip
    hit = normal = None
    if direction.length > ROOT_DEFAULTS['epsilon']:
        hit, normal, _, _ = tree.ray_cast(tip, direction.normalized())
    if hit is None:
        hit, normal, _, _ = tree.find_nearest(root)
    if hit is None:
        raise ValueError('Curve root missed native support: ' + piece['id'])
    seated = hit - normal * piece['radius'] * piece['taper'][0] / 2
    return reroot(piece['path'], seated)


def validate(spec):
    import bpy
    from .conformance import body_tree, regional_body
    reports = {}
    for piece in spec['pieces']:
        if not piece.get('root_on'):
            continue
        source = bpy.data.objects[piece['id']]
        target = bpy.data.objects['posed_body' if piece['root_on'] == '@body' else piece['root_on'] + '_render']
        if piece['root_on'] == '@body':
            target = regional_body(target, {'id': piece['id'] + '_root_support', 'body_regions': [piece['part']]})
        from mathutils import Vector
        if source.type == 'CURVE':
            spline = source.data.splines[0]
            root = spline.bezier_points[0].co if spline.type == 'BEZIER' else spline.points[0].co.to_3d()
        else:
            root = Vector(source['seated_root'])
        _, _, _, distance = body_tree(target).find_nearest(source.matrix_world @ root)
        radius = piece['radius'] * piece['taper'][0]
        reports[piece['id']] = {'support': target.name, 'root_distance_m': distance,
                                'root_radius_m': radius, 'passed': distance <= radius + ROOT_DEFAULTS['epsilon']}
    return reports
