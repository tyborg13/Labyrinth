"""Native post-solve floor correction, preserving evaluated front triangles."""
from copy import deepcopy
import json

import bpy
import numpy as np
from mathutils import Matrix, Vector
from mathutils.bvhtree import BVHTree
from mathutils.geometry import barycentric_transform

from .floor_contact import along_front_ray, far_leg_changes, far_hem_changes, projection_error, contact_guard, require_leg_bones
from .rig import evaluated_mesh

NATIVE_FLOOR_DEFAULTS = {'skinning_error_max_m': 1e-4}


def world_points(obj):
    return np.array([list(obj.matrix_world @ vertex.co) for vertex in obj.data.vertices])


def set_points(obj, corrected):
    inverse = obj.matrix_world.inverted()
    for vertex, point in zip(obj.data.vertices, corrected):
        if list(obj.matrix_world @ vertex.co) != list(point):
            vertex.co = inverse @ Vector(point)
    obj.data.update()


def carry_far_anatomy(spec, body, original, desired, cloth_before, cloth_after, triangles, leg_names, clearance):
    """Carry covered far anatomy through the robe's old/new camera-ray gaps.

    The front projection and original triangle correspondence define the map.
    Body points keep their position within a void, or their gap to an open hem;
    they cannot overtake a hem that lowers less than the ankle. Uncovered foot
    geometry retains the rigid ankle translation. No contact radius is tuned.
    """
    from ..raster import camera
    from .cloth_contacts import COLLISION_DEFAULTS
    matrix, _, basis, _ = camera(spec, 'front')
    ray = Vector(np.linalg.solve(matrix[:3, :3], basis[2])).normalized()
    direction = np.array(ray)
    depths = cloth_before @ direction
    maximum, span = float(depths.max()), float(np.ptp(depths))
    tree = BVHTree.FromPolygons([Vector(point) for point in cloth_before], triangles)
    epsilon = COLLISION_DEFAULTS['ray_epsilon']
    moved, invalid, maximum_change = 0, 0, 0.
    for index, point in enumerate(original):
        if not any(group.weight > 0 and body.vertex_groups[group.group].name in leg_names
                   for group in body.data.vertices[index].groups):
            continue
        start = Vector(point) + ray * (maximum - float(point @ direction) + span)
        hits = []
        for _ in range(len(triangles)):
            hit, _, face, _ = tree.ray_cast(start, -ray)
            if hit is None:
                break
            vertices = triangles[face]
            mapped = barycentric_transform(hit, *[Vector(cloth_before[i]) for i in vertices],
                                            *[Vector(cloth_after[i]) for i in vertices])
            a, b, c = [Vector(cloth_after[i]) for i in vertices]
            normal = (b - a).cross(c - a).normalized()
            slope = abs(normal.dot(ray))
            if slope <= epsilon:
                invalid += 1
                hits = []
                break
            hits.append((float(hit.dot(ray)), float(mapped.dot(ray)), clearance / slope))
            start = hit - ray * epsilon
        if not hits:
            continue
        depth = float(point @ direction)
        slot = sum(hit[0] >= depth for hit in hits)
        if slot == 0:
            target = depth + hits[0][1] - hits[0][0]
        elif slot == len(hits):
            target = depth + hits[-1][1] - hits[-1][0]
        elif slot % 2:
            invalid += 1
            continue
        else:
            near, far = hits[slot - 1], hits[slot]
            if near[0] - far[0] <= epsilon or near[1] <= far[1]:
                invalid += 1
                continue
            fraction = (depth - far[0]) / (near[0] - far[0])
            target = far[1] + fraction * (near[1] - far[1])
            lower, upper = far[1] + far[2], near[1] - near[2]
            if lower > upper:
                invalid += 1
                continue
            target = min(upper, max(lower, target))
        destination = point + (target - depth) * direction
        maximum_change = max(maximum_change, float(np.linalg.norm(destination - desired[index])))
        desired[index] = destination
        moved += 1
    return {'mapped_vertices': moved, 'unresolved_ray_intervals': invalid,
            'maximum_additional_displacement_m': maximum_change}


def correct_rig_and_skin(spec, body, rig, posed, desired, config):
    """Keep the editable rig and bound source in agreement with the baked pass."""
    from .source_cage import unpose_point
    names = set(config['leg_bones'])
    for bone in spec['armature']['bones']:
        if bone['name'] not in names:
            continue
        rest = rig.data.bones[bone['name']]
        head, tail = (Vector(spec['joints'][bone[key]]) for key in ('head', 'tail'))
        direction = tail - head
        rotation = (rest.tail_local - rest.head_local).rotation_difference(direction)
        basis = rotation.to_matrix() @ rest.matrix_local.to_3x3()
        transform = basis.to_4x4() @ Matrix.Diagonal((bone['scale'][0], direction.length / rest.length, bone['scale'][1], 1))
        transform.translation = head
        rig.pose.bones[bone['name']].matrix = transform
        bpy.context.view_layer.update()
    matrices = {bone.name: np.array(bone.matrix @ rig.data.bones[bone.name].matrix_local.inverted())
                for bone in rig.pose.bones}
    key = body.shape_key_add(name='floor_contact_fit', from_mix=False)
    for previous in body.data.shape_keys.key_blocks:
        if previous != body.data.shape_keys.key_blocks[0]:
            previous.value = 0
    inverse = body.matrix_world.inverted()
    for vertex, destination in zip(body.data.vertices, desired):
        weights = {body.vertex_groups[group.group].name: group.weight for group in vertex.groups
                   if group.weight > 0 and body.vertex_groups[group.group].name in matrices}
        key.data[vertex.index].co = unpose_point(list(inverse @ Vector(destination)),
            [matrices[name] for name in weights], list(weights.values()))
    key.value = 1
    bpy.context.view_layer.update()
    old = posed.data
    posed.data = evaluated_mesh(body)
    bpy.data.meshes.remove(old)
    error = float(np.linalg.norm(world_points(posed) - desired, axis=1).max())
    return {'corrective_shape': key.name, 'maximum_skinning_error_m': error,
            'passed': error <= NATIVE_FLOOR_DEFAULTS['skinning_error_max_m']}


def apply(spec, objects, body, rig, posed, target_joints):
    """Run once after native simulation, before material assignment and hashes."""
    config = spec['floor_contact_correction']
    floor = spec['joints'][config['floor_joint']][2]
    leg_names = require_leg_bones(spec, config)
    weights = np.array([sum(group.weight for group in vertex.groups
                           if body.vertex_groups[group.group].name in leg_names)
                        for vertex in body.data.vertices])
    errors = {}
    original_body = world_points(posed)
    desired = along_front_ray(spec, original_body, far_leg_changes(spec, original_body, weights))
    foot_region = next(bone['region'] for bone in spec['armature']['bones'] if bone['name'] == config['leg_bones'][-1])
    owners = json.loads(posed['face_owners'])
    foot_vertices = sorted({index for face, owner in zip(posed.data.polygons, owners)
                            if owner == foot_region for index in face.vertices})
    desired[foot_vertices] = along_front_ray(spec, original_body[foot_vertices],
        np.full(len(foot_vertices), floor - spec['joints'][config['ankle_joint']][2]))
    source = bpy.data.objects[config['hem_piece']]
    before_hem = world_points(source)
    changes, contacts = far_hem_changes(spec, before_hem, [list(p.vertices) for p in source.data.polygons])
    frozen = bpy.data.objects[config['hem_piece'] + '_render']
    if len(frozen.data.vertices) != 2 * len(before_hem):
        raise ValueError('Floor correction requires the two evaluated Solidify shells')
    frozen.data.calc_loop_triangles()
    triangles = [list(triangle.vertices) for triangle in frozen.data.loop_triangles]
    parents = [triangle.polygon_index for triangle in frozen.data.loop_triangles]
    before = world_points(frozen)
    set_points(frozen, along_front_ray(spec, before, np.tile(changes, 2)))
    errors[frozen.name] = projection_error(spec, before, world_points(frozen))
    old = frozen.data
    data = bpy.data.meshes.new(frozen.name + '_floor_triangles')
    data.from_pydata([list(vertex.co) for vertex in old.vertices], [], triangles)
    data.update()
    for polygon, parent in zip(data.polygons, parents):
        polygon.material_index = old.polygons[parent].material_index
        polygon.use_smooth = old.polygons[parent].use_smooth
    frozen.data = data
    bpy.data.meshes.remove(old)
    piece = next(piece for piece in spec['pieces'] if piece['id'] == config['hem_piece'])
    contact_fit = carry_far_anatomy(spec, body, original_body, desired, before, world_points(frozen), triangles, leg_names,
                                    piece['collision_margin'])
    for obj in objects:
        if obj.get('piece_type') == 'body':
            before_body = world_points(obj)
            set_points(obj, desired)
            errors[obj.name] = projection_error(spec, before_body, world_points(obj))
    after_hem = along_front_ray(spec, before_hem, changes)
    before_contacts = {config['ankle_joint']: spec['joints'][config['ankle_joint']][2],
                       config['hem_piece'] + '.hem_far_min': float(before_hem[contacts, 2].min()),
                       config['hem_piece'] + '.hem_far_max': float(before_hem[contacts, 2].max())}
    spec['joints'] = deepcopy(target_joints)
    after_contacts = {config['ankle_joint']: spec['joints'][config['ankle_joint']][2],
                      config['hem_piece'] + '.hem_far_min': float(after_hem[contacts, 2].min()),
                      config['hem_piece'] + '.hem_far_max': float(after_hem[contacts, 2].max())}
    prop = next(piece for piece in spec['pieces'] if piece['id'] == config['prop_piece'])
    butt = min(prop['path'][0][2], prop['path'][-1][2])
    before_contacts[prop['id'] + '.prop_foot'] = after_contacts[prop['id'] + '.prop_foot'] = butt
    skin = correct_rig_and_skin(spec, body, rig, posed, desired, config)
    from .ray_contacts import clear as clear_contacts
    before_clearance = world_points(frozen)
    clearance = clear_contacts(spec, frozen, posed, piece['collision_margin'],
        [*contacts, *[index + len(before_hem) for index in contacts]])
    clearance_delta = world_points(frozen) - before_clearance
    after_hem += (clearance_delta[:len(after_hem)] + clearance_delta[len(after_hem):]) / 2
    after_contacts[config['hem_piece'] + '.hem_far_min'] = float(after_hem[contacts, 2].min())
    after_contacts[config['hem_piece'] + '.hem_far_max'] = float(after_hem[contacts, 2].max())
    errors[frozen.name] = projection_error(spec, before, world_points(frozen))
    from .cloth_contacts import collision_report
    collisions = {piece['id']: collision_report(
        next(obj for obj in objects if obj.get('piece_id') == piece['id']), posed, piece['collision_margin'])
        for piece in spec['pieces'] if piece['type'] == 'cloth'}
    guard = contact_guard(after_contacts, floor, config['exceptions'])
    result = {'floor_m': floor, 'before_heights_m': before_contacts,
              'before_lifts_m': {name: height - floor for name, height in before_contacts.items()}, 'after': guard,
              'hem_contact_vertices': len(contacts), 'front_projection_error_px': errors,
              'native_skin': skin,
              'covered_body_contact': contact_fit, 'robe_contact_clearance': clearance,
              'method': 'front-ray lowering after native solve; original evaluated triangles retained',
              'passed': bool(guard['passed'] and skin['passed'] and all(row['passed'] for row in collisions.values()))}
    return result, collisions
