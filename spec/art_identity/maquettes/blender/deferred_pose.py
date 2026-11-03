"""Opt-in pose migration after solving protected source garments/accessories.

The recipe names accessories that follow a bone. All other surfaces retain
their original solved meshes; collision is measured again against the new body.
No saved mesh or cloth cache is required as an input.
"""
from copy import deepcopy

import numpy as np

DEFERRED_DEFAULTS = {'epsilon': 1e-10, 'length_tolerance_m': 1e-5}


def validate_config(spec):
    config = spec['deferred_surface_pose']
    pieces = {p['id'] for p in spec['pieces']}
    bones = {b['name'] for b in spec['armature']['bones']}
    if not spec.get('source_fit_joints') or not config or not set(config) <= pieces or not set(config.values()) <= bones:
        raise ValueError('Deferred surface pose requires source joints and known piece/bone bindings')


def construction_spec(spec):
    if not spec.get('deferred_surface_pose'):
        return spec
    result = deepcopy(spec)
    result['joints'] = result.pop('source_fit_joints')
    return result


def bone_transform(spec, name):
    bone = next(b for b in spec['armature']['bones'] if b['name'] == name)
    a, b = (np.asarray(spec['source_fit_joints'][bone[k]], float) for k in ('head', 'tail'))
    c, d = (np.asarray(spec['joints'][bone[k]], float) for k in ('head', 'tail'))
    u, v = b - a, d - c
    lengths = np.linalg.norm(u), np.linalg.norm(v)
    if min(lengths) <= DEFERRED_DEFAULTS['epsilon'] or abs(lengths[0] - lengths[1]) > DEFERRED_DEFAULTS['length_tolerance_m']:
        raise ValueError('Deferred pose changed bone length: ' + name)
    u, v = u / lengths[0], v / lengths[1]
    cross, cosine = np.cross(u, v), u @ v
    if cosine <= -1 + DEFERRED_DEFAULTS['epsilon']:
        raise ValueError('Deferred pose needs an authored antiparallel axis')
    skew = np.array([[0, -cross[2], cross[1]], [cross[2], 0, -cross[0]], [-cross[1], cross[0], 0]])
    rotation = np.eye(3) + skew + skew @ skew / (1 + cosine)
    transform = np.eye(4)
    transform[:3, :3], transform[:3, 3] = rotation, c - rotation @ a
    return transform


def apply(spec, body, rig, posed, surfaces, cloth_reports):
    import bpy
    from mathutils import Matrix
    from .pose_adjustment import repose
    from .cloth_contacts import collision_report

    final_spec = spec
    if spec.get('articulated_pose'):
        spec = deepcopy(spec)
        spec['joints'] = spec['articulated_pose_source_joints']

    # Capture source matrices before changing the rig's bone hierarchy.
    bound = dict((obj.name, (obj, bone)) for obj, bone in surfaces)
    for obj, bone in list(bound.values()):
        if obj.get('contact_target'):
            target = bpy.data.objects[obj['contact_target']]
            bound[target.name] = (target, bone)
    matrices = [(obj, obj.matrix_world.copy(), bone_transform(spec, bone)) for obj, bone in bound.values()]
    repose(spec, body, rig, posed)
    for obj, matrix, transform in matrices:
        obj.matrix_world = Matrix(transform.tolist()) @ matrix
    bpy.context.view_layer.update()
    from .shoulder_garments import apply as follow_shoulder
    motion = follow_shoulder(spec, posed)
    if motion:
        posed['shoulder_garment_motion'] = __import__('json').dumps(motion)
    if final_spec.get('articulated_pose'):
        from .posed_surfaces import apply as articulate
        articulate(final_spec, body, rig, posed)
        spec = final_spec
    for piece in spec['pieces']:
        if piece['type'] == 'cloth':
            cloth_reports[piece['id']] = collision_report(
                bpy.data.objects[piece['id'] + '_render'], posed, piece['collision_margin'])
