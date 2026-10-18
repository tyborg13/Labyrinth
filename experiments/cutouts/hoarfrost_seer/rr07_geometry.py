"""rr-07 director hierarchy over the untouched mq-04 native delivery.

Only the supplied native joints/curve endpoints determine pivots. Static cloth
does not become a simulated mesh: the brief requests rr-05 rigid cutout parts.
"""
import numpy as np
from PIL import Image

from rr07_inputs import (PROJECT, DIRECTOR, VIEWS, read_json, write_json,
                         compile_recipe, projected, CutoutError)

DECISIONS = {
    'authority': 'Director rr-07 feedback 1',
    'pelvis': 'No pelvis bone. Torso is a root child, pivoting at the native lower-back/pelvis joint.',
    'collar': 'Torso child at native head joint (neck base); head bows independently.',
    'seer_skirts': 'Torso children at each native hip/waist joint above its half.',
    'seer_feet': 'Root children at their own native ankle joints; independent of torso lean.',
    'seer_staff': 'Shaft is a far-hand child at grip. Crystal is always a shaft child at the shaft tip, including death.',
    'thrall_thighs': 'Root children at native hip joints; shins and feet retain the native limb chains.',
    'thrall_loincloth': 'Torso child at native pelvis/waist joint, following hunch and death.'}


def recipe_for(creature, spec):
    joints = {}

    def joint(name, source, parent):
        joints[name] = {'joint': source, 'position_3d': spec['joints'][source], 'parent': parent}

    joint('root', 'root', None)
    joint('torso', 'pelvis', 'root')
    joint('head', 'head', 'torso')
    joint('collar', 'head', 'torso')
    for side in ('near', 'far'):
        joint('upper_' + side, 'shoulder_' + side, 'torso')
        joint('fore_' + side, 'elbow_' + side, 'upper_' + side)
        joint('hand_' + side, 'hand_' + side, 'fore_' + side)
        if creature == 'hoarfrost_seer':
            joint('skirt_' + side, 'hip_' + side, 'torso')
            joint('foot_' + side, 'ankle_' + side, 'root')
        else:
            joint('thigh_' + side, 'hip_' + side, 'root')
            joint('shin_' + side, 'knee_' + side, 'thigh_' + side)
            joint('foot_' + side, 'ankle_' + side, 'shin_' + side)
    if creature == 'hoarfrost_seer':
        joint('staff_shaft', 'hand_far', 'hand_far')
        tip = next(p for p in spec['pieces'] if p['id'] == 'staff_shaft')['path'][-1]
        joints['staff_crystal'] = {'position_3d': tip, 'parent': 'staff_shaft',
                                  'native_curve_endpoint': 'staff_shaft.path[-1]'}
    else:
        joint('loincloth', 'pelvis', 'torso')
    parts = {p: 'hand_near' if p == 'club' else p for p in spec['labels']}
    clips = read_json(DIRECTOR)[creature]['clips']
    return {'character_id': creature, 'director_decisions': DECISIONS,
            'joints': joints, 'parts': parts, 'motion': 'motion.gd',
            'rigid_bones': [], 'contact_feet': [], 'design_placeholders': {},
            'materials': {p: ('native body skin' if creature == 'arc_thrall' and p not in
                              ('club', 'collar', 'loincloth') else p + ' approved paint')
                          for p in spec['labels']},
            'features': 'features.json',
            'clips': {n: {'frames': round(c['seconds'] * 60), 'duration': c['seconds'],
                          'loop': c.get('loop', False)} for n, c in clips.items()},
            'proof_defaults': {'native_fps': 60, 'render_size': 1024}}


def bind_layout(spec, view, transform, projected_joints, recipe):
    return {name: {'position': transform.point(projected_joints[item['joint']] if 'joint' in item
                    else projected(spec, item['position_3d'], view)), 'parent': item['parent']}
            for name, item in recipe['joints'].items()}, recipe['parts']


def native_depths(spec, view):
    """Camera-axis centers from the native source, not guessed sprite layers.

    Body centers use explicit native bone endpoints. Other surfaces use their
    source pattern/curve vertices; side-split sewn cloth uses its body region.
    Per-pixel visible ownership still comes exclusively from the part map.
    """
    from maquette_cutout import camera_view
    matrix, target, azimuth, elevation, _, distance = camera_view(spec, view)
    direction = np.array([np.cos(elevation) * np.cos(azimuth),
                          np.cos(elevation) * np.sin(azimuth), np.sin(elevation)])
    centers = {}
    for label in spec['labels']:
        bones = [b for b in spec['armature']['bones'] if b['region'] == label]
        points = [spec['joints'][b[k]] for b in bones for k in ('head', 'tail')]
        if not points:
            for p in spec['pieces']:
                if p['part'] != label:
                    continue
                if 'path' in p:
                    points.extend(p['path'])
                elif 'pattern' in p:
                    points.extend(q for row in p['pattern']['rows'] for q in row['points'])
                elif 'centre' in p:
                    points.append(p['centre'])
        if not points:
            raise CutoutError('Missing native material center: ' + label)
        center = (matrix @ np.append(np.mean(points, axis=0), 1))[:3]
        centers[label] = float(distance - (center - target) @ direction)
    return centers


def projection_for(case, spec, points, mapping, view):
    """Signed raise follows the supplied solo's material ray about its joint."""
    origin = np.asarray(projected(spec, [0, 0, 0], view))
    up = np.asarray(projected(spec, [0, 0, 1], view)) - origin
    forward = np.asarray(projected(spec, [1, 0, 0], view)) - origin
    result = {'forward': (forward / np.linalg.norm(forward)).tolist(), 'parts': {}}
    for bone, pivot in points.items():
        masks = [np.asarray(Image.open(case / f'source/maquette/{view}_solo_{p}.png').convert('RGBA'))[..., 3] > 128
                 for p in spec['labels'] if mapping[p] == bone]
        item = {'lean_deg': float(np.sign(np.cross(up, forward))), 'joint_3d': pivot}
        if masks:
            ys, xs = np.nonzero(np.logical_or.reduce(masks))
            ray = np.array([xs.mean() + .5, ys.mean() + .5]) - projected(spec, pivot, view)
            cross = float(np.cross(ray, up))
            if abs(cross) > 1e-8:
                item['raise_deg'] = float(np.sign(cross))
        result['parts'][bone] = item
    return result
