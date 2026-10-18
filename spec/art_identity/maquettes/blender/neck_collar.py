"""Metric iron collar and gravity-hanging oval chain, from unchanged anatomy.

The neck circle is fitted to the native torso's intersection with the specified
collar plane. Link outer dimensions and wire diameter are director data. The
chain follows gravity until the chest supports it; no anatomy is displaced.
"""
import math
import numpy as np

COLLAR_DEFAULTS = {'ring_samples': 96, 'link_samples': 64, 'plane_epsilon': 1e-8,
                   'chest_ray_length': 2.4, 'contact_clearance': .003}


def oval(length, width, wire, samples):
    if not length > width > wire > 0:
        raise ValueError('Oval outer dimensions must exceed wire diameter')
    a, b = (length - wire) / 2, (width - wire) / 2
    return np.array([[b * math.sin(t), a * math.cos(t)] for t in np.linspace(0, math.tau, samples, endpoint=False)])


def neck_circle(vertices, faces, owners, centre, tilt_degrees, region):
    angle = math.radians(tilt_degrees)
    first = np.array([math.cos(angle), 0, -math.sin(angle)])
    second = np.array([0, 1, 0.])
    normal = np.cross(first, second)
    points = np.array(vertices, float)
    distances = (points - centre) @ normal
    intersections = []
    for face, owner in zip(faces, owners):
        if owner != region:
            continue
        for a, b in zip(face, face[1:] + face[:1]):
            if distances[a] * distances[b] < 0:
                t = distances[a] / (distances[a] - distances[b])
                intersections.append(points[a] + (points[b] - points[a]) * t)
    if len(intersections) < 3:
        raise ValueError('Collar plane does not intersect the native neck region')
    points = np.array(intersections)
    uv = np.column_stack(((points - centre) @ first, (points - centre) @ second))
    # Circle enclosing the measured neck slice; the inner surface is exactly
    # the measured radius plus the director's 0.01 m neck clearance.
    lo, hi = uv.min(axis=0), uv.max(axis=0)
    offset = (lo + hi) / 2
    actual_centre = np.array(centre) + offset[0] * first + offset[1] * second
    radius = float(np.max(np.linalg.norm(uv - offset, axis=1)))
    return actual_centre, radius, first, second


def build(piece, spec, body):
    import json
    import bpy
    from mathutils import Vector
    from .conformance import body_tree
    from .pieces import place
    vertices = [list(body.matrix_world @ v.co) for v in body.data.vertices]
    faces = [list(p.vertices) for p in body.data.polygons]
    centre, neck_radius, first, second = neck_circle(vertices, faces, json.loads(body['face_owners']),
        piece['centre'], piece['tilt_degrees'], piece['neck_region'])
    tube_radius = piece['tube_diameter'] / 2
    radius = neck_radius + piece['neck_clearance'] + tube_radius
    ring = np.array([centre + radius * (math.cos(t) * first + math.sin(t) * second)
                     for t in np.linspace(0, math.tau, COLLAR_DEFAULTS['ring_samples'], endpoint=False)])
    data = bpy.data.curves.new(piece['id'], 'CURVE')
    data.dimensions = '3D'
    data.resolution_u = 1
    data.bevel_depth = 1
    data.bevel_resolution = 3
    def spline(points, wire_radius):
        item = data.splines.new('POLY')
        item.points.add(len(points) - 1)
        for vertex, point in zip(item.points, points):
            vertex.co = (*point, 1)
            vertex.radius = wire_radius
        item.use_cyclic_u = True
    spline(ring, tube_radius)
    anchor = centre + radius * first
    chain = piece['chain']
    shape = oval(chain['length'], chain['width'], chain['wire_diameter'], COLLAR_DEFAULTS['link_samples'])
    tree = body_tree(body)
    link_centres = []
    # A freely hanging short chain has vertical tension above contact. At chest
    # contact, the native chest surface supplies the reaction along +forward.
    for index in range(chain['count']):
        z = anchor[2] - (chain['length'] - chain['wire_diameter']) / 2 - index * (chain['length'] - 2 * chain['wire_diameter'])
        position = np.array([anchor[0], anchor[1], z])
        lateral = np.array([0., 1., 0.]) if index % 2 == 0 else np.array([1., 0., 0.])
        points = position + shape[:, :1] * lateral + shape[:, 1:] * np.array([0., 0., 1.])
        shift = 0.
        for point in points:
            start = Vector((COLLAR_DEFAULTS['chest_ray_length'], point[1], point[2]))
            hit, _, _, _ = tree.ray_cast(start, Vector((-1, 0, 0)))
            if hit is not None:
                shift = max(shift, hit.x + chain['wire_diameter'] / 2 + COLLAR_DEFAULTS['contact_clearance'] - point[0])
        position[0] += shift
        points[:, 0] += shift
        spline(points, chain['wire_diameter'] / 2)
        link_centres.append(position.tolist())
    obj = bpy.data.objects.new(piece['id'], data)
    bpy.context.scene.collection.objects.link(obj)
    place(obj, piece, spec)
    obj['metric_collar'] = json.dumps({'neck_radius': neck_radius,
        'inner_radius': radius - tube_radius, 'neck_clearance': piece['neck_clearance'],
        'tube_diameter': piece['tube_diameter'], 'tilt_degrees': piece['tilt_degrees'],
        'centre': centre.tolist(), 'chain': chain, 'link_centres': link_centres,
        'gravity': spec['simulation']['gravity'], 'contact_model': 'vertical tension / native chest reaction'})
    return obj
