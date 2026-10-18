"""Independent source-space target and length checks for humanoid chains."""
import math

import numpy as np


def target_chains(layout, values):
    joints = layout['joints']
    chains = list(layout.get('ik_chains', []))
    for side in ('near', 'far'):
        for first, second, target in (('upper_', 'fore_', 'hand_'), ('thigh_', 'shin_', 'foot_')):
            a, b, c = first + side, second + side, target + side
            if (all(n in joints for n in (a, b, c)) and
                    joints[b]['parent'] == a and joints[c]['parent'] == b):
                chains.append({'first': a, 'second': b, 'target': c})
    return [chain for chain in chains if any(key in values.get(chain['target'], {})
            for key in ('forward_px', 'lift_px', 'inward_px'))]


def fk_world(layout, values, modes, forward, step):
    """Reconstruct the unsolved parent-relative target without runtime code."""
    result = {}
    joints = layout['joints']
    def visit(name):
        if name in result: return result[name]
        joint = joints[name]
        parent = joint['parent']
        position = np.asarray(joint['position'], dtype=float)
        origin = position - (np.asarray(joints[parent]['position']) if parent else 0.)
        channels = values.get(name, {})
        amount = channels.get('forward_px', 0.)
        mode = modes.get(name, 'pixels')
        if mode == 'fraction_of_step': amount *= step
        if mode == 'world_step': amount = (amount - values.get('root', {}).get('forward_px', 0.)) * step
        origin += forward * amount + [np.sign(joints['root']['position'][0] - position[0]) *
                                      channels.get('inward_px', 0.), -channels.get('lift_px', 0.)]
        angle = math.radians(channels.get('lean_deg', 0.))
        c, s = math.cos(angle), math.sin(angle)
        local = np.array([[c, -s, origin[0]], [s, c, origin[1]], [0., 0., 1.]])
        result[name] = visit(parent) @ local if parent else local
        return result[name]
    for name in joints: visit(name)
    return result


def ik_errors(layout, bones, chain, fk, epsilon):
    names = [chain[key] for key in ('first', 'second', 'target')]
    a, b, c = [np.asarray(bones[n]['global'][4:]) for n in names]
    ra, rb, rc = [np.asarray(layout['joints'][n]['position']) for n in names]
    first, second = np.linalg.norm(rb-ra), np.linalg.norm(rc-rb)
    errors = []
    if not np.allclose([np.linalg.norm(b-a), np.linalg.norm(c-b)], [first, second], atol=epsilon, rtol=0):
        errors.append('IK length: ' + names[-1])
    def cross(u, v): return u[0] * v[1] - u[1] * v[0]
    if cross(c-a, b-a) * cross(rc-ra, rb-ra) < -epsilon:
        errors.append('IK changed rest bend side: ' + names[-1])
    ray = fk[names[-1]][:2, 2] - a
    distance = np.clip(np.linalg.norm(ray), abs(first-second) + 1e-6, first+second)
    axis = ray / np.linalg.norm(ray) if np.linalg.norm(ray) > 1e-6 else (rc-ra) / np.linalg.norm(rc-ra)
    kind = 'foot' if names[-1].startswith('foot_') else 'hand'
    if not np.allclose(c, a + axis * distance, atol=epsilon, rtol=0):
        errors.append('signed ' + kind + ' target: ' + names[-1])
    return errors
