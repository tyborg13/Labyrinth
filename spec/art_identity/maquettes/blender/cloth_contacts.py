"""Native contact preparation, fixed collision constraints and geometric gates."""
import json

import bpy
from mathutils import Vector
from mathutils.bvhtree import BVHTree

from .contract import BUILD_DEFAULTS
from .rig import active, evaluated_mesh

COLLISION_DEFAULTS = {'ray_epsilon': 1e-5, 'constraint_passes': 24,
                      'ray_directions': [[.381, .717, .583], [-.819, .391, .419], [.219, -.489, .844]]}


def inside(tree, p):
    votes = 0
    epsilon = COLLISION_DEFAULTS['ray_epsilon']
    for raw in COLLISION_DEFAULTS['ray_directions']:
        direction = Vector(raw).normalized()
        start = p + direction * epsilon
        count = 0
        for _ in range(128):
            hit, _, _, _ = tree.ray_cast(start, direction)
            if hit is None:
                break
            count += 1
            start = hit + direction * epsilon
        votes += count % 2
    return votes >= 2


def stabilise_collision(obj, body, piece):
    """Refine cloth's contact triangles and project violated collision constraints.

    The native solver supplies the drape. This deterministic contact correction
    prevents large cloth triangles tunnelling through the posed collision mesh;
    vertices away from contact keep the simulated pattern and its ragged hem.
    """
    levels = piece.get('collision_refine_levels', 0)
    if not levels:
        return
    # Slit interiors contain no cloth faces. Remove their loose pattern
    # vertices before refinement/solidification (they cannot carry fabric).
    import bmesh
    topology = bmesh.new()
    topology.from_mesh(obj.data)
    bmesh.ops.delete(topology, geom=[v for v in topology.verts if not v.link_faces], context='VERTS')
    topology.to_mesh(obj.data)
    topology.free()
    active(obj)
    sub = obj.modifiers.new('contact_resolution', 'SUBSURF')
    sub.subdivision_type = 'SIMPLE'
    sub.levels = levels
    bpy.ops.object.modifier_apply(modifier=sub.name)
    # Concave shoulder and hip contacts can alternate nearest sides across
    # a single cloth quad. A Blender convex regional contact surface prevents
    # tunnelling while the final gate still checks the complete posed anatomy.
    if (piece.get('contact_regions') or piece['kind'] in ('collar', 'tabard', 'cloak')) and 'face_owners' in body:
        from .conformance import regional_body
        regions = piece.get('contact_regions', (['torso', 'head', 'upper_near', 'upper_far'] if piece['kind'] == 'collar'
                   else ['pelvis', 'thigh_near', 'thigh_far'] if piece['kind'] == 'tabard'
                   else []))
        body = regional_body(body, {'id': 'cloth_contact_' + piece['id'],
            'body_regions': regions, 'contact_hull': True})
    project_constraints(obj, body, piece)


def project_constraints(obj, body, piece):
    body_data = mesh_payload(body)
    tree = BVHTree.FromPolygons([Vector(p) for p in body_data['vertices']], body_data['faces'])
    inverse = obj.matrix_world.inverted()
    margin = piece.get('solver_margin', piece['collision_margin']) + piece['thick'] / 2
    for _ in range(COLLISION_DEFAULTS['constraint_passes']):
        points = [obj.matrix_world @ v.co for v in obj.data.vertices]
        faces = [list(p.vertices) for p in obj.data.polygons]
        surface = BVHTree.FromPolygons(points, faces)
        contacts = {i for i, _ in surface.overlap(tree)}
        affected = {i for f in contacts for i in faces[f]}
        moved = 0
        for i, p in enumerate(points):
            near, normal, _, distance = tree.find_nearest(p)
            if distance < margin or i in affected or ((p - near).dot(normal) < 0 and inside(tree, p)):
                target = near + normal * margin
                obj.data.vertices[i].co = inverse @ target
                moved += 1
        obj.data.update()
        if not moved:
            break


def prune_pattern(obj, pins):
    """Remove slit-interior loose points before cloth self-collision starts."""
    import bmesh
    topology = bmesh.new()
    topology.from_mesh(obj.data)
    tag = topology.verts.layers.int.new('pattern_index')
    for i, vertex in enumerate(topology.verts):
        vertex[tag] = i
    bmesh.ops.delete(topology, geom=[v for v in topology.verts if not v.link_faces], context='VERTS')
    topology.verts.index_update()
    mapping = {v[tag]: v.index for v in topology.verts}
    if any(i not in mapping for i in pins):
        raise ValueError('A cloth pin references a cut-away pattern vertex')
    result = [mapping[i] for i in pins]
    topology.to_mesh(obj.data)
    topology.free()
    return result


def mesh_payload(obj):
    data = evaluated_mesh(obj)
    try:
        return {'vertices': [list(obj.matrix_world @ v.co) for v in data.vertices],
                'faces': [list(p.vertices) for p in data.polygons]}
    finally:
        bpy.data.meshes.remove(data)


def collision_report(obj, body, margin):
    a, b = mesh_payload(obj), mesh_payload(body)
    tree = BVHTree.FromPolygons([Vector(p) for p in b['vertices']], b['faces'])
    cloth_tree = BVHTree.FromPolygons([Vector(p) for p in a['vertices']], a['faces'])
    samples = [Vector(p) for p in a['vertices']]
    for face in a['faces']:
        pts = [Vector(a['vertices'][i]) for i in face]
        samples.append(sum(pts, Vector()) / len(pts))
        samples.extend((p + q) / 2 for p, q in zip(pts, pts[1:] + pts[:1]))
    minimum = float('inf')
    below_margin = 0
    for p in samples:
        near, normal, _, distance = tree.find_nearest(p)
        if near is None:
            raise ValueError('Empty body collision surface')
        is_inside = (p - near).dot(normal) < 0 and inside(tree, p)
        signed = -distance if is_inside else distance
        minimum = min(minimum, signed)
        below_margin += signed < margin - BUILD_DEFAULTS['collision_epsilon']
    overlaps = len(cloth_tree.overlap(tree))
    return {'minimum_signed_distance': minimum, 'margin': margin,
            'samples_below_margin': below_margin, 'intersecting_face_pairs': overlaps,
            'passed': below_margin == 0 and overlaps == 0}

