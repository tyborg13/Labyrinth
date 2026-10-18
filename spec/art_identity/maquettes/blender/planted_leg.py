"""Projection-preserving floor plant using mq-06's real-bone re-pose.

Keep the fitted hip and front projection. The ankle reaches the near ankle's
floor plane; the knee follows the existing height interpolation. Native bone
transforms carry the fitted skin before the cloth collision solve.
"""
from copy import deepcopy

import numpy as np

from .floor_contact import along_front_ray, far_leg_changes, require_leg_bones


def corrected_joints(spec, config):
    require_leg_bones(spec, config)
    joints = deepcopy(spec['joints'])
    for name in [*config['joint_chain'], *config.get('translate_with_ankle', [])]:
        point = np.array([spec['joints'][name]])
        joints[name] = along_front_ray(spec, point, far_leg_changes(spec, point))[0].tolist()
    return joints
