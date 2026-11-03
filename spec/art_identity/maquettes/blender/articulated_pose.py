"""Opt-in, length-preserving sagittal poses from front pixel constraints.

Source fitting remains in the measured pose. The same native bones and solved
surfaces carry the correction; neither camera nor rear joints are authored.
"""
from copy import deepcopy

import numpy as np

from ..raster import camera

POSE_DEFAULTS = {'size_px': 1024, 'epsilon': 1e-10, 'revision': 1}


def front_point(spec, pixels, fixed_axis, fixed_value):
    matrix, target, basis, scale = camera(spec, 'front')
    rows = [axis @ matrix[:3, :3] for axis in basis[:2]]
    values = [(pixels[0] / POSE_DEFAULTS['size_px'] - .5) * scale + basis[0] @ (target - matrix[:3, 3]),
              (.5 - pixels[1] / POSE_DEFAULTS['size_px']) * scale + basis[1] @ (target - matrix[:3, 3])]
    rows.append(np.eye(3)[fixed_axis])
    return np.linalg.solve(rows, [*values, fixed_value])


def two_bone(a, b, c, target, facing):
    a, b, c, target, facing = (np.asarray(p, float) for p in (a, b, c, target, facing))
    upper, lower = np.linalg.norm(b - a), np.linalg.norm(c - b)
    distance = np.linalg.norm(target - a)
    if not abs(upper - lower) < distance < upper + lower:
        raise ValueError('Articulated target is outside existing bone reach')
    axis = (target - a) / distance
    bend = facing - axis * (facing @ axis)
    if np.linalg.norm(bend) <= POSE_DEFAULTS['epsilon']:
        raise ValueError('Facing cannot define this chain bend')
    along = (upper ** 2 - lower ** 2 + distance ** 2) / (2 * distance)
    return a + axis * along + bend / np.linalg.norm(bend) * np.sqrt(upper ** 2 - along ** 2)


def pitch(angle):
    c, s = np.cos(angle), np.sin(angle)
    return np.array([[c, 0, s], [0, 1, 0], [-s, 0, c]])


def corrected_joints(spec, config):
    old = {k: np.asarray(v, float) for k, v in spec['joints'].items()}
    joints = deepcopy(spec['joints'])
    for side, pixels in config['ankles_front_px'].items():
        hip, knee, ankle = ('hip_' + side, 'knee_' + side, 'ankle_' + side)
        target = front_point(spec, pixels, 2, old[config['floor_joint']][2])
        joints[knee] = two_bone(old[hip], old[knee], old[ankle], target, config['facing']).tolist()
        joints[ankle] = target.tolist()
        joints['foot_tip_' + side] = (old['foot_tip_' + side] + target - old[ankle]).tolist()
    # Preserve lateral coordinates: pitch the two spine segments in their
    # sagittal plane, with no roll or side bend. Their planar lengths follow
    # uniquely from their existing lengths and unchanged lateral offsets.
    head = front_point(spec, config['head_front_px'], 1, old['head'][1])
    planar = [old[k][[0, 2]] for k in ('pelvis', 'torso', 'head')]
    # The intermediate joint is the back of the hunch; the neck reaches
    # forward from that back, rather than folding the neck backwards.
    torso_xz = two_bone(*planar, head[[0, 2]], [-1, 0])
    torso = np.array([torso_xz[0], old['torso'][1], torso_xz[1]])
    before = old['head'] - old['torso']
    after = head - torso
    angle = np.arctan2(after[0], after[2]) - np.arctan2(before[0], before[2])
    rotation = pitch(angle)
    joints.update(torso=torso.tolist(), head=head.tolist(),
                  head_tip=(head + rotation @ (old['head_tip'] - old['head'])).tolist())
    # The shoulder bar follows the spine at its centre, retaining the accepted
    # level bar. Arms translate with it, exactly as the mq-12 claw correction.
    centre = (old['shoulder_near'] + old['shoulder_far']) / 2
    delta = torso + rotation @ (centre - old['torso']) - centre
    for side in ('near', 'far'):
        for name in ('shoulder_', 'elbow_', 'hand_', 'hand_tip_'):
            joints[name + side] = (old[name + side] + delta).tolist()
    return joints
