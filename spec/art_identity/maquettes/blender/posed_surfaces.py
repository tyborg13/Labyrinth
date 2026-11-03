"""Carry solved garments through an opt-in articulated body correction.

Attachment fields use the existing source joint heights and garment hem.
Rigid shell seating uses the solved cloak envelope and existing clearance.
No source measurements, labels or cloth settings are changed.
"""
from copy import deepcopy
import json

import numpy as np

def attachment_weights(points, low, high):
    if high <= low:
        raise ValueError('Garment attachment must be above its hem')
    return np.clip((np.asarray(points)[:, 2] - low) / (high - low), 0, 1)


def apply(spec, body, rig, posed):
    import bpy
    from mathutils import Matrix, Vector
    from .deferred_pose import bone_transform
    from .pose_adjustment import repose
    from .cloth_contacts import project_constraints

    source = deepcopy(spec)
    source['source_fit_joints'] = spec['articulated_pose_source_joints']
    repose(source, body, rig, posed)
    from .grounded_pose import apply as plant_skin
    plant_skin(body, rig, posed)
    reports = {}
    for piece in spec['pieces']:
        name = piece['id']
        obj = bpy.data.objects[name + '_render']
        points = np.array([list(obj.matrix_world @ v.co) for v in obj.data.vertices])
        if piece['part'].startswith('claw_'):
            transform = bone_transform(source, 'elbow_' + piece['part'].split('_')[-1])
            obj.matrix_world = Matrix(transform.tolist()) @ obj.matrix_world
            continue
        if piece['type'] != 'cloth':
            continue
        if piece['kind'] == 'hood':
            transform = bone_transform(source, 'head')
            shifted = points @ transform[:3, :3].T + transform[:3, 3]
            floor = spec['articulated_pose']['hood_reference']['head_floor_z']
            cover = points[:, 2] >= floor
            back_transform = bone_transform(source, 'torso')
            back_points = points @ back_transform[:3, :3].T + back_transform[:3, 3]
            low = max(source['source_fit_joints']['shoulder_' + s][2] for s in ('near', 'far'))
            weights = attachment_weights(points, low, floor)
            shifted = back_points + weights[:, None] * (shifted - back_points)
            obj['articulated_head_cover_indices'] = json.dumps(np.flatnonzero(cover).tolist())
        else:
            transform = bone_transform(source, 'torso')
            high = np.mean([source['source_fit_joints']['shoulder_' + s][2] for s in ('near', 'far')])
            low = (points[:, 2].min() if piece['kind'] == 'cloak'
                   else source['source_fit_joints']['pelvis'][2])
            weights = attachment_weights(points, low, high)
            moved = points @ transform[:3, :3].T + transform[:3, 3]
            shifted = points + weights[:, None] * (moved - points)
        inverse = obj.matrix_world.inverted()
        for vertex, point in zip(obj.data.vertices, shifted):
            vertex.co = inverse @ Vector(point)
        obj.data.update()
        # The source fold mesh is retained; only contact violations against
        # the corrected native body receive the established constraint solve.
        project_constraints(obj, posed, piece)
        if piece['kind'] == 'hood':
            clear_shoulder_contacts(obj, posed, piece, spec)
        reports[name] = {'vertices': len(points), 'source_fold_topology_retained': True}
    from .back_plate_seat import seat_shell
    seat_shell(spec)
    posed['articulated_surface_motion'] = json.dumps(reports)
    bpy.context.view_layer.update()


def clear_shoulder_contacts(obj, body, piece, spec):
    """Resolve concave neck contacts without inflating untouched hood vertices."""
    from mathutils import Vector
    from mathutils.bvhtree import BVHTree
    from .cloth_contacts import COLLISION_DEFAULTS, inside, project_constraints
    from .conformance import regional_body

    points = [body.matrix_world @ v.co for v in body.data.vertices]
    tree = BVHTree.FromPolygons(points, [list(p.vertices) for p in body.data.polygons])
    regions = sorted(set(piece.get('contact_regions', [])) |
                     {b['region'] for b in spec['armature']['bones'] if b['region'].startswith('upper_')})
    support = regional_body(body, {'id': 'articulated_' + piece['id'],
        'body_regions': regions, 'contact_hull': True})
    for _ in range(COLLISION_DEFAULTS['constraint_passes']):
        saved = [v.co.copy() for v in obj.data.vertices]
        points = [obj.matrix_world @ p for p in saved]
        faces = [list(p.vertices) for p in obj.data.polygons]
        cloth = BVHTree.FromPolygons(points, faces)
        affected = {i for face, _ in cloth.overlap(tree) for i in faces[face]}
        for i, point in enumerate(points):
            near, normal, _, distance = tree.find_nearest(point)
            if distance < piece['collision_margin'] or ((point - near).dot(normal) < 0 and inside(tree, point)):
                affected.add(i)
        if not affected:
            return
        project_constraints(obj, support, piece)
        for vertex, original in zip(obj.data.vertices, saved):
            if vertex.index not in affected:
                vertex.co = original
        obj.data.update()


