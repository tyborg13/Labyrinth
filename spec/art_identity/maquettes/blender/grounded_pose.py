"""Plant the articulated skin on the preserved near sole's floor plane.

The foot translates without rotation. A mesh-harmonic correction blends into
the shin and is zero at the knee and everywhere outside that lower leg.
The editable bound anatomy receives the same corrective as the frozen skin.
"""
import json

import numpy as np

from .floor_contact import harmonic_heights

GROUND_DEFAULTS = {'skinning_error_max_m': 1e-4}


def sole_correction(points, faces, owners):
    points = np.asarray(points, float)
    used = {side: {i for face, owner in zip(faces, owners) if owner == 'foot_' + side for i in face}
            for side in ('near', 'far')}
    if not all(used.values()):
        raise ValueError('Articulated floor requires both native foot surfaces')
    floor = float(points[sorted(used['near']), 2].min())
    shift = floor - float(points[sorted(used['far']), 2].min())
    shin = {i for face, owner in zip(faces, owners) if owner == 'shin_far' for i in face}
    fixed = {i: 0. for i in range(len(points)) if i not in shin}
    fixed.update({i: 0. for i in used['near']})
    fixed.update({i: shift for i in used['far']})
    changes = harmonic_heights(points, faces, fixed)
    return changes, {'floor_z_m': floor, 'far_sole_translation_m': shift}


def apply(body, rig, posed):
    import bpy
    from mathutils import Vector
    from .rig import evaluated_mesh
    from .source_cage import unpose_point

    points = np.array([list(posed.matrix_world @ v.co) for v in posed.data.vertices])
    faces = [list(face.vertices) for face in posed.data.polygons]
    owners = json.loads(posed['face_owners'])
    shifts, report = sole_correction(points, faces, owners)
    desired = points.copy()
    desired[:, 2] += shifts
    matrices = {bone.name: np.array(bone.matrix @ rig.data.bones[bone.name].matrix_local.inverted())
                for bone in rig.pose.bones}
    key = body.shape_key_add(name='articulated_floor_fit', from_mix=False)
    for previous in body.data.shape_keys.key_blocks:
        if previous != body.data.shape_keys.key_blocks[0]:
            previous.value = 0
    inverse = body.matrix_world.inverted()
    for vertex, point in zip(body.data.vertices, desired):
        weights = {body.vertex_groups[g.group].name: g.weight for g in vertex.groups
                   if g.weight > 0 and body.vertex_groups[g.group].name in matrices}
        key.data[vertex.index].co = unpose_point(list(inverse @ Vector(point)),
            [matrices[name] for name in weights], list(weights.values()))
    key.value = 1
    bpy.context.view_layer.update()
    old = posed.data
    posed.data = evaluated_mesh(body)
    bpy.data.meshes.remove(old)
    actual = np.array([list(posed.matrix_world @ v.co) for v in posed.data.vertices])
    report['maximum_skinning_error_m'] = float(np.linalg.norm(actual - desired, axis=1).max())
    report['passed'] = report['maximum_skinning_error_m'] <= GROUND_DEFAULTS['skinning_error_max_m']
    posed['articulated_floor_contact'] = json.dumps(report)
    if not report['passed']:
        raise ValueError('Articulated floor corrective does not match the bound anatomy')
