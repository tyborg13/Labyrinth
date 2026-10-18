"""Length-preserving pose corrections after fitting the approved source anatomy.

Recipes supply every target. The source corrective shape is fitted at its
original pose, then the native armature carries that same anatomy to the target.
"""
from copy import deepcopy

import numpy as np

from ..raster import camera


POSE_DEFAULTS = {'epsilon': 1e-10, 'source_size': 1024, 'native_length_tolerance_m': 1e-5}


def solve_two_bone(shoulder, elbow, hand, target_shoulder):
    """Keep both lengths and the bend side; minimize the hand's displacement."""
    a, b, c, target = (np.asarray(p, float) for p in (shoulder, elbow, hand, target_shoulder))
    upper, fore = np.linalg.norm(b - a), np.linalg.norm(c - b)
    delta = c - target
    distance = np.linalg.norm(delta)
    if min(upper, fore, distance) <= POSE_DEFAULTS['epsilon']:
        raise ValueError('Two-bone correction requires nonzero limbs and target direction')
    direction = delta / distance
    reach = np.clip(distance, abs(upper - fore), upper + fore)
    if reach <= POSE_DEFAULTS['epsilon']:
        raise ValueError('Two-bone correction has an undefined folded elbow')
    end = target + direction * reach
    along = (upper * upper - fore * fore + reach * reach) / (2 * reach)
    height = np.sqrt(max(0, upper * upper - along * along))
    bend = b - a - direction * np.dot(b - a, direction)
    if height > POSE_DEFAULTS['epsilon'] and np.linalg.norm(bend) <= POSE_DEFAULTS['epsilon']:
        raise ValueError('Two-bone correction requires an authored bend side')
    middle = target + direction * along
    if height > POSE_DEFAULTS['epsilon']:
        middle += bend / np.linalg.norm(bend) * height
    return middle.tolist(), end.tolist()


def corrected_joints(spec, constraints):
    joints = deepcopy(spec['joints'])
    for item in constraints:
        shoulder, elbow, hand = item['chain']
        origin = np.asarray(joints[shoulder], float)
        matrix, camera_target, basis, scale = camera(spec, 'front')
        # The rig spec permits only perspective height differences: both real
        # shoulders lie on one body-space height plane. This fixes the third
        # coordinate without inventing a rear-view placement.
        right, up = (axis @ matrix[:3, :3] for axis in basis[:2])
        x, y = item['shoulder_front_px']
        values = [(x / POSE_DEFAULTS['source_size'] - .5) * scale + basis[0] @ (camera_target - matrix[:3, 3]),
                  (.5 - y / POSE_DEFAULTS['source_size']) * scale + basis[1] @ (camera_target - matrix[:3, 3]),
                  joints[item['shoulder_height_joint']][2]]
        target = np.linalg.solve([right, up, [0, 0, 1]], values)
        middle, end = solve_two_bone(origin, joints[elbow], joints[hand], target)
        translation = np.subtract(end, joints[hand])
        joints.update({shoulder: target.tolist(), elbow: middle, hand: end})
        for name in item.get('translate_with_hand', []):
            joints[name] = (np.asarray(joints[name]) + translation).tolist()
    return joints


def repose(spec, body, rig, posed):
    """Repose fitted native anatomy without refitting it to the old outlines."""
    import bpy
    from mathutils import Vector
    from .rig import evaluated_mesh

    original = spec.get('source_fit_joints')
    if original is None:
        return
    matrices = {bone.name: bone.matrix.copy() for bone in rig.pose.bones}
    # Set every world matrix in hierarchy order, so inherited transforms cannot
    # move an unchanged bone or apply the correction twice to a child.
    pending = {b['name']: b for b in spec['armature']['bones']}
    done = set()
    while pending:
        for name, bone in list(pending.items()):
            if bone.get('parent') and bone['parent'] not in done:
                continue
            transform = matrices[name].copy()
            if any(original[bone[k]] != spec['joints'][bone[k]] for k in ('head', 'tail')):
                old_head, old_tail = (Vector(original[bone[k]]) for k in ('head', 'tail'))
                head, tail = (Vector(spec['joints'][bone[k]]) for k in ('head', 'tail'))
                if abs((tail - head).length - (old_tail - old_head).length) > POSE_DEFAULTS['native_length_tolerance_m']:
                    raise ValueError('Pose correction changed native limb length: ' + name)
                rotation = (old_tail - old_head).rotation_difference(tail - head).to_matrix()
                transform = (rotation @ transform.to_3x3()).to_4x4()
                transform.translation = head
            rig.pose.bones[name].matrix = transform
            bpy.context.view_layer.update()
            done.add(name)
            del pending[name]
    old = posed.data
    posed.data = evaluated_mesh(body)
    bpy.data.meshes.remove(old)
