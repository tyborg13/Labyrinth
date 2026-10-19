"""Native two-segment thumb opposition against the closed index finger."""
import numpy as np
from .pose_adjustment import solve_two_bone

THUMB_DEFAULTS = {'tail_quantiles': [.02, .98], 'root_quantile': .1,
                  'root_palm_fraction': .5, 'middle_span': [.4, .6],
                  'index_tip_quantile': .95, 'joint_blend_start': .25, 'joint_blend_span': .5,
                  'epsilon': 1e-9, 'root_error_m': 1e-6}


def rotation_between(before, after):
    a, b = np.asarray(before, float), np.asarray(after, float)
    a, b = a / np.linalg.norm(a), b / np.linalg.norm(b)
    axis = np.cross(a, b)
    sine, cosine = np.linalg.norm(axis), float(a @ b)
    if sine <= THUMB_DEFAULTS['epsilon']:
        if cosine > 0:
            return np.eye(3)
        normal = np.cross(a, np.eye(3)[np.argmin(abs(a))])
        normal /= np.linalg.norm(normal)
        return 2 * np.outer(normal, normal) - np.eye(3)
    x, y, z = axis / sine
    cross = np.array([[0, -z, y], [z, 0, -x], [-y, x, 0]])
    return np.eye(3) + cross * sine + cross @ cross * (1 - cosine)


def oppose(points, posed, groups, along, normal, lateral):
    available = np.ones(len(points), bool)
    available[np.concatenate(groups)] = False
    sideways = points @ lateral
    centre = float(np.median(sideways[available]))
    low, high = np.quantile(sideways[available], THUMB_DEFAULTS['tail_quantiles'])
    sign = 1 if high - centre > centre - low else -1
    threshold = min(high - centre, centre - low) * THUMB_DEFAULTS['root_palm_fraction']
    extension = sign * (sideways - centre) - threshold
    selected = available & (extension > 0)
    if not selected.any():
        raise ValueError('Native fist could not locate its thumb')
    reach = float(extension[selected].max())
    base = selected & (extension <= np.quantile(extension[selected], THUMB_DEFAULTS['root_quantile']))
    tips = selected & (extension >= reach * THUMB_DEFAULTS['tail_quantiles'][1])
    root, tip = points[base].mean(0), points[tips].mean(0)
    thumb_axis = tip - root
    length = np.linalg.norm(thumb_axis)
    if length <= THUMB_DEFAULTS['epsilon']:
        raise ValueError('Native thumb has no length')
    thumb_axis /= length
    progress = (points - root) @ thumb_axis / length
    middle = selected & (progress >= THUMB_DEFAULTS['middle_span'][0]) & (progress <= THUMB_DEFAULTS['middle_span'][1])
    joint = points[middle].mean(0) if middle.any() else (root + tip) / 2
    bend = joint - root - thumb_axis * ((joint - root) @ thumb_axis)
    if np.linalg.norm(bend) <= THUMB_DEFAULTS['epsilon']:
        joint += normal * max(float(np.std(points[base] @ normal)), THUMB_DEFAULTS['root_error_m'])
    index = max(groups, key=lambda group: sign * float(sideways[group].mean()))
    index_tips = [i for i in index if along[i] >= np.quantile(along[index], THUMB_DEFAULTS['index_tip_quantile'])]
    pad_radius = float(np.std(points[base] @ normal) + np.std(posed[index_tips] @ normal))
    target = posed[index_tips].mean(0) + normal * pad_radius
    upper, lower = np.linalg.norm(joint - root), np.linalg.norm(tip - joint)
    vector = target - root
    distance = np.linalg.norm(vector)
    if distance <= THUMB_DEFAULTS['epsilon']:
        raise ValueError('Native thumb has no opposition target')
    target = root + vector / distance * np.clip(distance, abs(upper - lower) + THUMB_DEFAULTS['epsilon'],
                                               upper + lower - THUMB_DEFAULTS['epsilon'])
    new_joint, new_root = solve_two_bone(tip, joint, root, target)
    new_joint = np.asarray(new_joint)
    if np.linalg.norm(np.subtract(new_root, root)) > THUMB_DEFAULTS['root_error_m']:
        raise ValueError('Thumb opposition displaced its native palm root')
    proximal = rotation_between(joint - root, new_joint - root)
    distal = rotation_between(tip - joint, target - new_joint)
    indices = np.flatnonzero(selected)
    blend = np.clip((progress[indices] - THUMB_DEFAULTS['joint_blend_start']) / THUMB_DEFAULTS['joint_blend_span'], 0, 1)
    blend = blend * blend * (3 - 2 * blend)
    first = root + (points[indices] - root) @ proximal.T
    second = new_joint + (points[indices] - joint) @ distal.T
    target_points = first * (1 - blend[:, None]) + second * blend[:, None]
    root_blend = np.clip(extension[indices] / (reach * THUMB_DEFAULTS['root_quantile']), 0, 1)
    root_blend = root_blend * root_blend * (3 - 2 * root_blend)
    posed[indices] = points[indices] * (1 - root_blend[:, None]) + target_points * root_blend[:, None]
    return len(indices)
