"""Rear-only planted pose. Frozen front captures are never regenerated.

The original outline corrective remains on the bound CC0 skin. Only its real
far-leg bones change; cloth then solves against that evaluated anatomy.
"""
from copy import deepcopy
import json

import bpy
from mathutils import Matrix, Vector
import numpy as np

from .floor_contact import boundary_loops, contact_guard, harmonic_heights, require_leg_bones
from .rig import evaluated_mesh

REAR_POSE_DEFAULTS = {'bone_endpoint_error_max_m': 1e-4}


def pose_leg(spec, body, rig, posed, target):
    config = spec['rear_body']
    bones = require_leg_bones(spec, config)
    before = deepcopy(spec['joints'])
    for definition in spec['armature']['bones']:
        name = definition['name']
        if name not in bones:
            continue
        rest = rig.data.bones[name]
        head, tail = (Vector(target[definition[key]]) for key in ('head', 'tail'))
        direction = tail - head
        rotation = (rest.tail_local - rest.head_local).rotation_difference(direction)
        basis = rotation.to_matrix() @ rest.matrix_local.to_3x3()
        transform = basis.to_4x4() @ Matrix.Diagonal((definition['scale'][0],
            direction.length / rest.length, definition['scale'][1], 1))
        transform.translation = head
        rig.pose.bones[name].matrix = transform
        bpy.context.view_layer.update()
    old = posed.data
    posed.data = evaluated_mesh(body)
    bpy.data.meshes.remove(old)
    spec['joints'] = deepcopy(target)
    actual = {name: {'head': list(rig.pose.bones[name].head),
                     'tail': list(rig.pose.bones[name].tail)} for name in sorted(bones)}
    errors = [abs(np.array(actual[b['name']][end]) - target[b[key]]).max()
              for b in spec['armature']['bones'] if b['name'] in bones
              for end, key in (('head', 'head'), ('tail', 'tail'))]
    return {'method': 'real hip/knee/ankle pose on fitted skin, before native cloth',
            'joints_before': before, 'joints_after': deepcopy(target), 'bones': actual,
            'maximum_bone_endpoint_error_m': float(max(errors)),
            'corrective_shapes': [key.name for key in body.data.shape_keys.key_blocks]}


def hem_indices(obj):
    points = np.array([list(v.co) for v in obj.data.vertices])
    loops = boundary_loops([list(p.vertices) for p in obj.data.polygons])
    if len(loops) != 2:
        raise ValueError('Rear floor skirt must have one waist and one hem')
    return min(loops, key=lambda loop: float(points[loop, 2].mean()))


def hem_height(piece, spec):
    # Existing solver clearance and physical thickness, not a new drape value.
    return spec['joints']['ankle_near'][2] + piece['collision_margin'] + piece['thick'] / 2


def prepare_floor(obj, piece, spec, collection):
    from .pieces import mesh_object
    points = np.array([list(v.co) for v in obj.data.vertices])
    faces = [list(p.vertices) for p in obj.data.polygons]
    loops = boundary_loops(faces)
    hem, waist = sorted(loops, key=lambda loop: float(points[loop, 2].mean()))
    fixed = {i: 0. for i in waist}
    fixed.update({i: hem_height(piece, spec) - points[i, 2] for i in hem})
    shifts = harmonic_heights(points, faces, fixed)
    for vertex, shift in zip(obj.data.vertices, shifts):
        vertex.co.z += shift
    obj.data.update()
    # A debug-only collider extends beyond the complete orthographic scene.
    radius = spec['ortho_scale']
    floor = spec['joints']['ankle_near'][2]
    plane = mesh_object('rear_floor_collision',
        [[-radius, -radius, floor], [radius, -radius, floor],
         [radius, radius, floor], [-radius, radius, floor]], [[0, 1, 2, 3]])
    plane['native_source'] = True
    plane.hide_render = True
    plane.modifiers.new('native_floor_collision', 'COLLISION')
    plane.collision.thickness_outer = piece['collision_margin']
    plane.collision.thickness_inner = piece['collision_margin']
    collection.objects.link(plane)


def settle_floor(obj, support, piece, spec):
    from .cloth_contacts import COLLISION_DEFAULTS, project_constraints
    from .contract import BUILD_DEFAULTS
    target = hem_height(piece, spec)
    for _ in range(COLLISION_DEFAULTS['constraint_passes']):
        project_constraints(obj, support, piece)
        hem = hem_indices(obj)
        error = max(max((target - v.co.z for v in obj.data.vertices), default=0),
                    max(abs(obj.data.vertices[i].co.z - target) for i in hem))
        for vertex in obj.data.vertices:
            vertex.co.z = max(vertex.co.z, target)
        for index in hem:
            obj.data.vertices[index].co.z = target
        obj.data.update()
        if error <= BUILD_DEFAULTS['collision_epsilon']:
            break
    obj['floor_hem_indices'] = json.dumps(hem)


def floor_report(spec, objects, pose):
    from .floor_contact import spec_contacts
    config = spec['rear_body']
    garment = next(o for o in objects if o.get('piece_id') == config['hem_piece'])
    source = bpy.data.objects[config['hem_piece']]
    indices = hem_indices(source)
    count = len(source.data.vertices)
    if len(garment.data.vertices) != count * 2:
        raise ValueError('Unexpected solidified hem topology')
    heights = [float(garment.data.vertices[i + shell * count].co.z)
               for shell in (0, 1) for i in indices]
    floor = spec['joints']['ankle_near'][2]
    contacts = {**{name: row['height_m'] for name, row in spec_contacts(spec)['points'].items()},
                'hem_min': min(heights), 'hem_max': max(heights)}
    guard = contact_guard(contacts, floor, config['exceptions'])
    guard['hem_on_or_above_floor'] = min(heights) >= floor
    guard['pose'] = pose
    guard['passed'] &= (guard['hem_on_or_above_floor'] and
                        pose['maximum_bone_endpoint_error_m'] <= REAR_POSE_DEFAULTS['bone_endpoint_error_max_m'])
    return guard
