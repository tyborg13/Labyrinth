"""Seat a fully pinned source panel behind the native collision anatomy.

This is a rest-surface constraint, not a per-view garment or a simulation
fallback. It uses the same authored clearance as the cloth contact solver.
"""
import numpy as np


STATIC_DRAPE_DEFAULTS = {'revision': 5}


def validate(piece):
    config = piece['back_attachment']
    axis = np.asarray(config['forward'], float)
    count = piece['pattern']['columns'] * len(piece['pattern']['rows'])
    if (axis.shape != (3,) or not np.isfinite(axis).all() or np.linalg.norm(axis) == 0 or
            config.get('revision') != STATIC_DRAPE_DEFAULTS['revision'] or
            piece.get('drape') or piece['frames'] != 1 or set(piece['pattern']['pins']) != set(range(count))):
        raise ValueError('Static back attachment requires a finite axis and fully pinned one-frame cloth')


def resolve(obj, body, piece):
    """Keep complete contact triangles behind the body after refinement.

    A vertex-only ray projection can leave triangles spanning an armpit or
    a silhouette edge. Resolve those triangles conservatively; preserve the
    source drape outside contact, including its free trailing edge.
    """
    from mathutils import Vector
    from mathutils.bvhtree import BVHTree
    from .cloth_contacts import COLLISION_DEFAULTS, inside, mesh_payload
    import bpy
    from .rig import active
    from .floor_contact import harmonic_heights
    validate(piece)
    if piece['collision_refine_levels']:
        active(obj)
        modifier = obj.modifiers.new('static_back_resolution', 'SUBSURF')
        modifier.subdivision_type = 'SIMPLE'
        modifier.levels = piece['collision_refine_levels']
        bpy.ops.object.modifier_apply(modifier=modifier.name)
    payload = mesh_payload(body)
    tree = BVHTree.FromPolygons([Vector(p) for p in payload['vertices']], payload['faces'])
    direction = Vector(piece['back_attachment']['forward']).normalized()
    clearance = piece.get('solver_margin', piece['collision_margin']) + piece['thick']/2
    plane = min(Vector(p).dot(direction) for p in payload['vertices']) - clearance
    inverse = obj.matrix_world.inverted()
    original = np.array([list(obj.matrix_world @ v.co) for v in obj.data.vertices])
    faces = [list(p.vertices) for p in obj.data.polygons]
    counts = {}
    for face in faces:
        for a, b in zip(face, face[1:]+face[:1]):
            edge = tuple(sorted((a, b)))
            counts[edge] = counts.get(edge, 0)+1
    fixed = {i: 0. for edge, count in counts.items() if count == 1 for i in edge}
    constraints = {}
    for _ in range(COLLISION_DEFAULTS['constraint_passes']):
        points = [obj.matrix_world @ v.co for v in obj.data.vertices]
        faces = [list(p.vertices) for p in obj.data.polygons]
        surface = BVHTree.FromPolygons(points, faces)
        affected = {i for face, _ in surface.overlap(tree) for i in faces[face]}
        for face in faces:
            vertices = [points[i] for i in face]
            samples = vertices + [(a+b)/2 for a, b in zip(vertices, vertices[1:]+vertices[:1])]
            samples.append(sum(vertices, Vector())/len(vertices))
            for sample in samples:
                near, normal, _, distance = tree.find_nearest(sample)
                if distance < piece['collision_margin']+piece['thick']/2 or ((sample-near).dot(normal)<0 and inside(tree, sample)):
                    affected.update(face)
                    break
        if not affected:
            return
        for index in affected:
            constraints[index] = min(0., plane-float(np.dot(original[index], direction)))
        values = harmonic_heights(original, faces, {**fixed, **constraints})
        for vertex, point, distance in zip(obj.data.vertices, original, values):
            vertex.co = inverse @ (Vector(point)+direction*distance)
        obj.data.update()
    raise ValueError('Static back contact constraints did not converge')
