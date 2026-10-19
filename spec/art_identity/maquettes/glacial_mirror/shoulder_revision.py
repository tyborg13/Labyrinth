"""Reproduce mq-08's authored shoulder correction from the frozen mq-05 recipe.

This is an explicit recipe migration, never an implicit builder adjustment.
All unaffected surfaces and joints are copied exactly. The existing near crest
supplies the far pauldron's dimensions and sculpt, rather than inventing a form.
"""
from copy import deepcopy
import json
import math
from pathlib import Path

import numpy as np

from spec.art_identity.maquettes.blender.compile_recipe import compile_recipe
from spec.art_identity.maquettes.blender.contract import digest
from spec.art_identity.maquettes.blender.pose_adjustment import corrected_joints
from spec.art_identity.maquettes.raster import camera, project

SHOULDER_CONTRACT = {'slope': .15, 'joint_tolerance_px': 10,
                     'pauldron_tolerance_px': 12, 'native_size': 1024}
REVISION_DEFAULTS = {'rotation_epsilon': 1e-10}


def rotation_between(a, b):
    a, b = (np.asarray(p, float) / np.linalg.norm(p) for p in (a, b))
    cross = np.cross(a, b)
    cosine = a @ b
    if cosine < -1 + REVISION_DEFAULTS['rotation_epsilon']:
        raise ValueError('Antiparallel bone correction needs an authored bend axis')
    skew = np.array([[0, -cross[2], cross[1]], [cross[2], 0, -cross[0]],
                     [-cross[1], cross[0], 0]])
    return np.eye(3) + skew + skew @ skew / (1 + cosine)


def euler_matrix(angles):
    x, y, z = angles
    cx, sx, cy, sy, cz, sz = math.cos(x), math.sin(x), math.cos(y), math.sin(y), math.cos(z), math.sin(z)
    return np.array([[cz, -sz, 0], [sz, cz, 0], [0, 0, 1]]) @ np.array(
        [[cy, 0, sy], [0, 1, 0], [-sy, 0, cy]]) @ np.array([[1, 0, 0], [0, cx, -sx], [0, sx, cx]])


def matrix_euler(matrix):
    return [math.atan2(matrix[2, 1], matrix[2, 2]),
            math.atan2(-matrix[2, 0], math.hypot(matrix[0, 0], matrix[1, 0])),
            math.atan2(matrix[1, 0], matrix[0, 0])]


def paired_pixels(spec, point):
    return [project(spec, [point], view, size=256)[0, :2].tolist() for view in ('front', 'rear')]


def revise(before):
    result = deepcopy(before)
    spec = compile_recipe(before)
    near, far = project(spec, [spec['joints'][n] for n in ('shoulder_near', 'shoulder_far')])[:, :2]
    target = [float(far[0]), float(near[1] - SHOULDER_CONTRACT['slope'] * abs(near[0] - far[0]))]
    joints = corrected_joints(spec, [{'chain': ['shoulder_far', 'elbow_far', 'hand_far'],
        'shoulder_front_px': target, 'shoulder_height_joint': 'shoulder_near',
        'translate_with_hand': ['hand_tip_far']}])
    changed = ('shoulder_far', 'elbow_far', 'hand_far', 'hand_tip_far')
    for name in changed:
        result['joints_px'][name] = paired_pixels(spec, joints[name])
    pieces = {p['id']: p for p in spec['pieces']}
    bones = {b['name']: b for b in spec['armature']['bones']}
    for surface in result['native_solids']['surfaces']:
        name = surface['rig_bone']
        # The bedding is the torso socket: retain its existing intersection
        # with the protected torso, while the shoulder cap/arm move over it.
        if name not in changed or surface['id'] == 'shoulder_far_bedding':
            continue
        bone = bones[name]
        a, b = (np.asarray(spec['joints'][bone[k]]) for k in ('head', 'tail'))
        c, d = (np.asarray(joints[bone[k]]) for k in ('head', 'tail'))
        rotation = rotation_between(b - a, d - c)
        piece = pieces[surface['id']]
        surface['centre_px'] = paired_pixels(spec, c + rotation @ (np.asarray(piece['centre']) - a))
        surface['rot'] = matrix_euler(rotation @ euler_matrix(surface['rot']))
    # Match the near shoulder's existing top boulder exactly in size/sculpt.
    # Its vertical offset from the real shoulder is preserved in the front;
    # centre it on the far joint horizontally so it covers that joint.
    surfaces = {p['id']: p for p in result['native_solids']['surfaces']}
    crest = deepcopy(surfaces['shoulder_near_crest'])
    centre = np.asarray(pieces['shoulder_near_crest']['centre']) + np.subtract(joints['shoulder_far'], joints['shoulder_near'])
    matrix, _, basis, scale = camera(spec)
    right = basis[0] @ matrix[:3, :3]
    crest_x = project(spec, [centre])[0, 0]
    centre += right * (target[0] - crest_x) * scale / SHOULDER_CONTRACT['native_size']
    crest.update(id='shoulder_far_mass', part='upper_far', rig_bone='shoulder_far',
                 centre_px=paired_pixels(spec, centre))
    surfaces['shoulder_far_mass'].clear()
    surfaces['shoulder_far_mass'].update(crest)
    result['feedback_1_contract']['locked_joints_sha256'] = digest(result['joints_px'])
    result['shoulder_revision_contract'] = {
        'authority': 'mq-08: humanoid_cutout_rig.md section 3; level shoulders, minimum-displacement length-preserving far arm, near-sized pauldron.',
        'superseded_joint_lock_sha256': before['feedback_1_contract']['locked_joints_sha256'],
        'source_recipe_sha256': digest(before), 'changed_joints': list(changed),
        'target_shoulder_front_px': target, 'pauldron_template': 'shoulder_near_crest',
        'limits': SHOULDER_CONTRACT}
    return result


if __name__ == '__main__':
    import argparse
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('before', type=Path)
    parser.add_argument('output', type=Path)
    args = parser.parse_args()
    args.output.write_text(json.dumps(revise(json.loads(args.before.read_text())), indent=2) + '\n')
