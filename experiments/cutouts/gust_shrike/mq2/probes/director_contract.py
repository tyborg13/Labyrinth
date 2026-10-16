"""Independent signed oracle. Deliberately does not import the motion compiler."""
from __future__ import annotations
import math
import numpy as np
from maquette_cutout import projected, shape_center
from cutout_pipeline.cases import read_json

TIME_EPSILON = 1e-7  # Serialization tolerance, not an animation tolerance.


def expected_tracks(root):
    data = read_json(root / 'director_motion.json')
    source = root.parent / 'motion_tracks_director.json'
    if source.read_bytes() != (root / 'director_motion.json').read_bytes():
        raise ValueError('Case director copy differs from protected source')
    clock = read_json(root / 'recipes/motion_interpretation.json')
    spec = read_json(root.parent / 'maquette/spec.json')
    spec['view_transforms'] = read_json(root.parent / 'maquette/view_transforms.json')
    result = {}
    for view in ['front', 'rear']:
        origin = np.asarray(projected(spec, [0, 0, 0], view))
        def vector(p): return np.asarray(projected(spec, p, view)) - origin
        def rotation_toward(a, b):
            # A positive 2D rotation's tangent is (-y, x).
            dot = float(np.dot(np.array([-a[1], a[0]]), b))
            if abs(dot) < 1e-8: raise ValueError('Ambiguous projected axis')
            return 1 if dot > 0 else -1
        forward, up = vector([1, 0, 0]), vector([0, 0, 1])
        pitch = rotation_toward(forward, -up)
        wing_signs = {}
        for wing in ['wing_near', 'wing_far']:
            points = [shape_center(s, spec['joints']) for s in spec['shapes'] if s['part'] == wing]
            wing_signs[wing] = rotation_toward(vector(np.mean(points, axis=0) - spec['joints'][wing]), up)
        mapping = {
            'body.lift_px': [('body_y', -1)], 'body.forward_px': [('body_forward', 1)],
            'body.pitch_deg': [('body_pitch', pitch)],
            'body.roll_deg': [('body_roll', rotation_toward(up, vector([0, -1, 0])))],
            'body.squash': [('body_scale_y', 1)], 'head.tilt_deg': [('head_angle', pitch)],
            'head.turn_px': [('head_forward', 1)], 'head.lift_px': [('head_y', -1)],
            'tail.lift_deg': [('tail_angle', rotation_toward(-forward, up))],
            'legs.reach_deg': [('legs_angle', rotation_toward(vector(np.asarray(spec['joints']['root']) - spec['joints']['legs']), forward))],
            'wing_near.raise_deg': [('wing_near_angle', wing_signs['wing_near'])],
            'wing_far.raise_deg': [('wing_far_angle', wing_signs['wing_far'])],
            'wings.span': [('wing_near_span', 1), ('wing_far_span', 1)], 'recoil': [('recoil', 1)]}
        semantic = {'idle': {}}
        for channel, keys in data['idle']['keys'].items():
            if channel != 'head': semantic['idle'][channel] = [(k['t'], k['v'], 'smoothstep') for k in keys]
        poses = data['idle']['keys']['head']['keys']
        span = 2 / clock['head_snap_fps'] / data['idle']['seconds']
        for field in ['tilt_deg', 'turn_px', 'lift_px']:
            if clock['head_snap_placement'] != 'start': raise ValueError('Unreviewed head clock placement')
            keys = [(0, poses[-2].get(field, 0), 'linear'), (span, poses[0].get(field, 0), 'linear')]
            for previous, current in zip(poses, poses[1:-1]):
                keys += [(current['t'], previous.get(field, 0), 'hold'),
                         (current['t'] + span, current.get(field, 0), 'linear')]
            semantic['idle']['head.' + field] = keys + [(1, poses[-2].get(field, 0), 'hold')]
        fields = {'lift_px': ['body.lift_px'], 'lift': ['body.lift_px'],
                  'wings_raise': ['wing_near.raise_deg', 'wing_far.raise_deg'],
                  'tail': ['tail.lift_deg'], 'legs': ['legs.reach_deg'], 'pitch': ['body.pitch_deg'],
                  'roll': ['body.roll_deg'], 'squash': ['body.squash'], 'span': ['wings.span'],
                  'forward': ['body.forward_px'], 'head_tilt': ['head.tilt_deg'], 'recoil_px': ['recoil']}
        for clip in ['move', 'dive', 'talon_rake', 'hover', 'hit', 'death']:
            rows = data[clip].get('keys')
            if clip == 'dive':
                duration = .35 + 6 / 30
                rows = [dict(k, t=k['t'] * .35 / duration) for k in data[clip]['flight'][:-1]]
                recovery = [dict(k, t=(.35 + (k['frame'] - 1) / 30) / duration) for k in data[clip]['recovery_frames']]
                recovery[0]['interp'] = 'hold'
                rows += recovery + [dict(recovery[-1], t=1)]
            semantic[clip] = {}
            for field in set().union(*(set(k) for k in rows)) - {'t', 'frame', 'interp'}:
                for channel in fields[field]:
                    semantic[clip][channel] = [(k['t'], k.get(field, 1 if field in ['squash', 'span'] else 0), k.get('interp', 'smoothstep')) for k in rows]
        result[view] = {clip: {target: [{'at': t, 'value': value * sign, 'interpolation': curve} for t, value, curve in keys]
                              for channel, keys in channels.items() for target, sign in mapping[channel]}
                        for clip, channels in semantic.items()}
    return result


def value_at(keys, at):
    if at <= keys[0]['at']: return keys[0]['value']
    for a, b in zip(keys, keys[1:]):
        if at <= b['at']:
            if b['interpolation'] == 'hold': return b['value'] if at >= b['at'] else a['value']
            t = (at - a['at']) / (b['at'] - a['at'])
            if b['interpolation'] == 'smoothstep': t = t * t * (3 - 2 * t)
            return a['value'] + (b['value'] - a['value']) * t
    return keys[-1]['value']


def verify(root, samples, angle_tolerance, pixel_tolerance, scale_tolerance):
    errors = []
    expected = expected_tracks(root)
    records = samples.get('channel_samples', [])
    for view, clips in expected.items():
        for clip, channels in clips.items():
            tracks = samples.get('tracks', {}).get(view, {}).get(clip, [])
            actual = {t['channel']: t['keys'] for t in tracks}
            label = view + '/' + clip
            if set(actual) != set(channels) or len(actual) != len(tracks):
                errors.append(label + ': authored channel coverage')
            for channel, keys in channels.items():
                tolerance = scale_tolerance if channel.endswith('span') or channel == 'body_scale_y' else angle_tolerance if channel.endswith(('angle', 'pitch', 'roll')) else pixel_tolerance
                actual_keys = actual.get(channel, [])
                if len(actual_keys) != len(keys) or any(abs(a['at'] - b['at']) > TIME_EPSILON or a['interpolation'] != b['interpolation'] or abs(a['value'] - b['value']) > tolerance for a, b in zip(actual_keys, keys)):
                    errors.append(label + '/' + channel + ': authored keys/sign differ')
                times = [k['at'] for k in keys] + [(a['at'] + b['at']) / 2 for a, b in zip(keys, keys[1:])]
                for at in times:
                    hits = [r for r in records if r['view'] == view and r['clip'] == clip and abs(r['phase'] - at) <= TIME_EPSILON]
                    values = [r['values'].get(channel) for r in hits]
                    if not values or any(v is None or not math.isfinite(v) or abs(v - value_at(keys, at)) > tolerance for v in values):
                        errors.append('%s/%s: signed sample at %.9f' % (label, channel, at))
    return errors
