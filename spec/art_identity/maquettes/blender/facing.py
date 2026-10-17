"""One board frame for every v2 build; asset-native forward is -Y.

Registration matrices in authored specs can contain any yaw. Normalize that
registration and rest joints to +X before binding. Posed bone frames keep
anatomical forward +X; director-authored joint coordinates, plate outlines and
world-space paths retain their placements. Head/neck attachments and front chest plates/gems turn with the
anatomy. This is an asset/rig conversion, never a camera or per-spec yaw fix.
The original spec remains the provenance/fit input; board_spec is a working copy.
"""
from copy import deepcopy
import math

import numpy as np

FACING_DEFAULTS = {'native_forward': [0, -1, 0], 'board_forward': [1, 0, 0],
                   'axis_cosine_min': .995, 'asymmetry_min': .01,
                   'epsilon': 1e-9}


def board_spec(spec):
    result = deepcopy(spec)
    matrix = np.asarray(spec['base']['matrix'], float)
    forward = matrix[:3, :3] @ FACING_DEFAULTS['native_forward']
    yaw = -math.atan2(forward[1], forward[0])
    c, s = math.cos(yaw), math.sin(yaw)
    rotation = np.array([[c, -s, 0], [s, c, 0], [0, 0, 1.]])
    pivot = np.asarray(spec['joints']['pelvis'], float)
    transform = np.eye(4)
    transform[:3, :3] = rotation
    transform[:3, 3] = pivot - rotation @ pivot
    def point(value):
        return (pivot + rotation @ (np.asarray(value) - pivot)).tolist()
    def vector(value):
        return (rotation @ value).tolist()
    result['base']['matrix'] = (transform @ matrix).tolist()
    for name in result['armature']['rest_joints']:
        result['armature']['rest_joints'][name] = point(result['armature']['rest_joints'][name])
    head = np.asarray(spec['joints'].get('head', pivot))
    def head_point(value):
        return (head + rotation @ (np.asarray(value) - head)).tolist()
    for p in result['pieces']:
        # Piece outlines and world-space paths are explicit director placements.
        # Shrinkwrap projects armour onto the newly oriented anatomy. Neck/head
        # garments and the visor rotate in their anatomical attachment frame.
        if p['part'] in ('head', 'torso') and p['type'] in ('plate', 'gem'):
            p['rot'] = [p['rot'][0], p['rot'][1], p['rot'][2] + yaw]
            p['offset'] = vector(p['offset'])
        if p['type'] == 'cloth' and p['kind'] in ('hood', 'collar'):
            for row in p['pattern']['rows']:
                if 'points' in row:
                    row['points'] = [head_point(v) for v in row['points']]
                elif 'centre' in row:
                    row['centre'] = head_point(row['centre'])
                    row['angles'] = [row['angles'][0] + yaw, row['angles'][1]]
            for key in ('symmetry_front', 'symmetry_lateral'):
                if key in p:
                    p[key] = vector(p[key])
            if 'symmetry_origin' in p:
                p['symmetry_origin'] = head_point(p['symmetry_origin'])
        if 'conform_direction' in p and p.get('conform_target'):
            p['conform_direction'] = vector(p['conform_direction'])
            p['path'] = [head_point(v) for v in p['path']]
        for slot in p.get('slots', []):
            slot['path'] = [head_point(v) for v in slot['path']]
            slot['conform_direction'] = vector(slot['conform_direction'])
    result['_board_frame'] = {'yaw_radians': yaw, 'pivot': pivot.tolist(),
                              'matrix': transform.tolist(), 'forward': [1, 0, 0]}
    return result


def axis_report(spec, forward):
    from ..raster import camera
    matrix, _, basis, _ = camera(spec)
    f = np.asarray(matrix)[:3, :3] @ np.asarray(forward, float)
    anatomical_forward = f.copy()
    f[2] = 0  # Board facing is horizontal heading; a leaning spine is allowed.
    projected = np.array([np.dot(f, basis[0]), -np.dot(f, basis[1])])
    expected = np.array([np.dot([1, 0, 0], basis[0]), -np.dot([1, 0, 0], basis[1])])
    cosine = float(np.dot(projected, expected) / max(np.linalg.norm(projected) * np.linalg.norm(expected), FACING_DEFAULTS['epsilon']))
    return {'forward_world': f.tolist(), 'anatomical_forward_world': anatomical_forward.tolist(), 'front_forward_screen': projected.tolist(),
            'rear_forward_screen': (-projected).tolist(), 'board_axis_cosine': cosine,
            'passed': bool(projected[0] < 0 < projected[1] and cosine >= FACING_DEFAULTS['axis_cosine_min'])}
