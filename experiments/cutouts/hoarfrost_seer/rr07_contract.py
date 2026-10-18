"""Independent rr-07 authored-key and native-solo angular oracle.

Does not import/call the semantic compiler or the geometry adapter's projection.
The frozen director recipe is checked against native joint endpoints again.
"""
import math
import numpy as np
from PIL import Image
from rr07_inputs import DIRECTOR, read_json, digest, projected, CutoutError, VIEWS
ANGLE_EPSILON = 1e-12  # Oracle degeneracy check; never motion tuning.


def approved_source(case):
    if (case / 'director_motion.json').read_bytes() != DIRECTOR.read_bytes():
        raise CutoutError('Protected rr-07 motion differs')
    return DIRECTOR


def expected(case):
    source = approved_source(case)
    recipe = read_json(case / 'rig_recipe.json')
    spec = read_json(case / 'source/spec.json')
    creature = recipe['character_id']
    author = read_json(source)[creature]
    points, parents = {}, {}
    for name, item in recipe['joints'].items():
        position = (spec['joints'][item['joint']] if 'joint' in item else
                    next(p for p in spec['pieces'] if p['id'] == 'staff_shaft')['path'][-1])
        if position != item['position_3d']:
            raise CutoutError('Recipe pivot differs from native input: ' + name)
        points[name], parents[name] = position, item['parent']
    required = {'root': None, 'torso': 'root', 'head': 'torso', 'collar': 'torso'}
    if creature == 'hoarfrost_seer':
        required.update(skirt_near='torso', skirt_far='torso', foot_near='root', foot_far='root',
                        staff_shaft='hand_far', staff_crystal='staff_shaft')
    else:
        required.update(thigh_near='root', thigh_far='root', loincloth='torso')
    if any(parents.get(n) != p for n, p in required.items()):
        raise CutoutError('Director feedback-1 hierarchy differs')
    views = {}
    for view in VIEWS:
        zero = np.asarray(projected(spec, [0, 0, 0], view))
        up = np.subtract(projected(spec, [0, 0, 1], view), zero)
        forward = np.subtract(projected(spec, [1, 0, 0], view), zero)

        def turn(ray, target):
            angle = math.atan2(target[1], target[0]) - math.atan2(ray[1], ray[0])
            sine = math.sin(angle)
            return None if abs(sine) < ANGLE_EPSILON else math.copysign(1., sine)

        axes = {}
        for bone, anchor in points.items():
            item = {'lean_deg': turn(up, forward), 'joint_3d': anchor}
            pixels = np.zeros((1024, 1024), dtype=bool)
            for material, target in recipe['parts'].items():
                if target == bone:
                    pixels |= np.asarray(Image.open(case / f'source/maquette/{view}_solo_{material}.png').convert('RGBA'))[..., 3] > 128
            ys, xs = np.nonzero(pixels)
            if len(xs):
                ray = np.subtract([np.mean(xs) + .5, np.mean(ys) + .5], projected(spec, anchor, view))
                direction = turn(ray, up)
                if direction is not None:
                    item['raise_deg'] = direction
            axes[bone] = item
        views[view] = {'forward': (forward / math.hypot(*forward)).tolist(), 'parts': axes}
    result = {'creature': creature, 'director_sha256': digest(source), 'joints_3d': points,
              'parents': parents, 'parts': recipe['parts'], 'projection': views,
              'clips': {}, 'view_tracks': {view: {} for view in VIEWS}, 'TODO_DESIGN': {}}
    for clip, data in author['clips'].items():
        result['clips'][clip] = {k: v for k, v in data.items() if k != 'keys'}
        for view in VIEWS:
            tracks = []
            for channel, keys in data['keys'].items():
                part, field = channel.rsplit('.', 1)
                if field == 'forward_mode':
                    continue
                bone = 'root' if part == 'body' else part
                sign = views[view]['parts'][bone][field] if field in ('raise_deg', 'lean_deg') else 1.
                tracks.append({'source': channel, 'bone': bone, 'channel': field,
                    'keys': [{'at': r[0], 'value': r[1] * sign,
                              'interpolation': r[2] if len(r) > 2 else 'smoothstep'} for r in keys],
                    'forward_mode': data['keys'].get(part + '.forward_mode', 'pixels')})
            result['view_tracks'][view][clip] = tracks
    return result
