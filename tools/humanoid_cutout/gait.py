"""Director's protagonist-walk expansion, in inspectable source-pixel tracks.

The hero's local Hermite has tangent -swing_duration (tile units). Adding
linear root travel cancels that tangent, leaving world-space smoothstep.
No creature identity or hidden animation tuning belongs here.
"""
import math

from maquette_motion.compiler import evaluate as legacy_evaluate

SIDES = ('near', 'far')
FIELDS = {'model', 'steps_per_tile', 'lead', 'stance_fraction', 'lift_px',
          'lane_narrowing', 'leg_scale_max', 'settle_px', 'arm_swing', 'max_fit_px'}


def schedule(gait):
    n = gait['steps_per_tile'] - 1
    a = gait['stance_fraction'] / n
    positions = dict.fromkeys(SIDES, 0.)
    swings = []
    for i in range(1, n + 1):
        side = gait['lead'] if i % 2 else next(s for s in SIDES if s != gait['lead'])
        previous, landing = positions[side], i / n
        swings.append({'side': side, 'start': previous + a if i > 1 else 0.,
                       'end': landing - a, 'from': previous, 'to': landing})
        positions[side] = landing
    side = min(positions, key=positions.get)
    swings.append({'side': side, 'start': positions[side] + a,
                   'end': 1., 'from': positions[side], 'to': 1.})
    return swings


def validate(gait, clip):
    if clip != 'move': raise ValueError('gait: only move clips may declare a gait')
    if set(gait) - FIELDS: raise ValueError('gait: unknown fields: ' + str(sorted(set(gait) - FIELDS)))
    required = FIELDS - {'leg_scale_max'}
    if required - set(gait): raise ValueError('gait: missing fields: ' + str(sorted(required - set(gait))))
    if gait['model'] != 'protagonist_walk': raise ValueError('gait: expected protagonist_walk model')
    count = gait['steps_per_tile']
    if type(count) is not int or count < 2 or count % 2: raise ValueError('gait: step count must be positive and even')
    if gait['lead'] not in SIDES: raise ValueError('gait: invalid lead')
    if not .5 < gait['stance_fraction'] < 1: raise ValueError('gait: stance_fraction must be between .5 and 1')
    if set(gait['settle_px']) != {'contact', 'down', 'passing', 'up'}: raise ValueError('gait: unknown/missing settle fields')
    if set(gait['arm_swing']) - set(SIDES): raise ValueError('gait: unknown arm side')
    for arm in gait['arm_swing'].values():
        if set(arm) != {'bone', 'px'}: raise ValueError('gait: unknown/missing arm fields')
    numbers = [gait[k] for k in ('lift_px', 'lane_narrowing', 'max_fit_px')]
    numbers += list(gait['settle_px'].values()) + [a['px'] for a in gait['arm_swing'].values()]
    numbers += [gait.get('leg_scale_max', 1.22)]
    if any(not isinstance(v, (int, float)) or not math.isfinite(v) or v < 0 for v in numbers):
        raise ValueError('gait: values must be finite and nonnegative')


def expand(gait, layout, clip):
    validate(gait, clip)
    swings = schedule(gait)
    generated = {'root.forward_mode': 'fraction_of_step', 'root.forward_px': [[0, 0, 'linear'], [1, 1, 'linear']]}
    for side in SIDES:
        foot, thigh = 'foot_' + side, 'thigh_' + side
        if foot not in layout['joints'] or thigh not in layout['joints']: raise ValueError('gait: visible legs required')
        steps = [s for s in swings if s['side'] == side]
        forward, lift, lane = {0.: 0.}, {0.: (0., 'smoothstep')}, {0.: 0.}
        delta = (layout['joints'][thigh]['position'][0] - layout['joints'][foot]['position'][0]) * gait['lane_narrowing']
        for i, swing in enumerate(steps):
            start, end = swing['start'], swing['end']
            forward[start], forward[end] = swing['from'], swing['to']
            lift[start] = (0., 'smoothstep')
            lift[(start + end) / 2.] = (gait['lift_px'], 'sine_power')
            lift[end] = (0., 'sine_power')
            lane[start], lane[end] = (0. if i == 0 else delta), (0. if i == len(steps)-1 else delta)
        forward[1.], lane[1.] = 1., 0.
        lift.setdefault(1., (0., 'smoothstep'))
        generated.update({foot + '.forward_mode': 'world_step',
            foot + '.forward_px': [[at, value] for at, value in sorted(forward.items())],
            foot + '.lift_px': [[at, value, curve] for at, (value, curve) in sorted(lift.items())],
            foot + '.lane_px': [[at, value] for at, value in sorted(lane.items())]})
    # Settle intervals run from the previous landing to the next landing.
    settle = {0.: 0., 1.: 0.}
    start = 0.
    for i, swing in enumerate(swings):
        end = swing['end']
        amplitude = .5 if i in (0, len(swings)-1) else 1.
        settle[start] = 0. if start == 0. else -gait['settle_px']['contact'] * amplitude
        for u, name in ((.16, 'down'), (.5, 'passing'), (.8, 'up')):
            settle[start + (end-start)*u] = -gait['settle_px'][name] * amplitude
        settle[end] = 0. if end == 1. else -gait['settle_px']['contact'] * amplitude
        start = end
    generated['pelvis.lift_px'] = [[at, value] for at, value in sorted(settle.items())]
    for side, arm in gait['arm_swing'].items():
        rows = [[0., 0.]]
        for i, swing in enumerate(swings):
            amplitude = .5 if i in (0, len(swings)-1) else 1.
            amount = arm['px'] * amplitude * (-1 if side == swing['side'] else 1)
            rows.append([swing['end'], 0. if swing['end'] == 1. else amount])
        generated[arm['bone'] + '.forward_px'] = rows
    return generated


def evaluate(keys, phase):
    for a, b in zip(keys, keys[1:]):
        if a['at'] <= phase <= b['at'] and b['interpolation'] == 'sine_power':
            u = (phase-a['at']) / (b['at']-a['at'])
            weight = math.sin(math.pi * .5 * (u if b['value'] > a['value'] else 1-u)) ** 1.35
            return max(a['value'], b['value']) * weight
    return legacy_evaluate(keys, phase)


def fit_state(layout, values, forward, step, fk):
    """Independent pre-IK targets/scale/fit from authored FK (numpy oracle)."""
    import numpy as np
    joints = layout['joints']
    root = np.asarray(joints['root']['position'])
    progress = values['root']['forward_px']
    result = {'fit_px': 0., 'legs': {}}
    for side in SIDES:
        a, b, c = [np.asarray(joints[n + '_' + side]['position']) for n in ('thigh', 'shin', 'foot')]
        value = values['foot_' + side]
        anchor = c + [value['lane_px'], 0.]
        ground = anchor + forward * (value['forward_px'] - progress) * step
        target = ground + forward * progress * step - [0., value['lift_px']]
        length = float(np.linalg.norm(b-a) + np.linalg.norm(c-b))
        scale = float(np.clip(1 + (ground[1]-anchor[1])/length, .78,
                              layout.get('gait_leg_scale_max', 1.22)))
        start = fk['thigh_' + side][:2, 2]
        reach = length * scale - .10
        vertical = math.sqrt(max(.01, reach*reach - (target[0]-start[0])**2))
        result['fit_px'] = max(result['fit_px'], float(target[1]-start[1]-vertical))
        result['legs'][side] = {'target': target, 'ground': ground, 'scale': scale, 'length': length}
    return result


def adjust_fk(layout, values, forward, step, fk):
    if not any('lane_px' in value for value in values.values()): return None
    state = fit_state(layout, values, forward, step, fk)
    for name, transform in fk.items():
        if name not in ('root', 'foot_near', 'foot_far'): transform[1, 2] += state['fit_px']
    return state
