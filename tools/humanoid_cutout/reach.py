"""Dense, unclamped FK target reach gate; never tune the runtime to pass it."""
import math

import numpy as np

from .action_direction import pose_values
from .bone_contracts import fk_world, target_chains
from .gait import evaluate

DENSE_INTERVALS = 1000
MIN_REACH_MARGIN_PX = 4.0
MAX_REACH_OVERSHOOT = 0.02
MINIMUM_PHASE_RESOLUTION = 1e-6
POSITION_CHANNELS = ('forward_px', 'lift_px', 'inward_px', 'lane_px')


def proven_linear(tracks, start, end):
    """Sufficient condition for an affine target in the first bone's frame.

    Key-partitioned intervals have no interior interpolation changes. Constant
    rotations and affine translations compose to affine positions; a changing
    hold, smoothstep or rotation needs the conservative bound instead.
    """
    for track in tracks:
        channel, keys = track['channel'], track['keys']
        if channel not in (*POSITION_CHANNELS, 'lean_deg', 'swing_deg'):
            continue
        if evaluate(keys, start) == evaluate(keys, end):
            continue
        if channel in ('lean_deg', 'swing_deg'):
            return False
        middle = (start + end) / 2.
        interpolation = next(b['interpolation'] for a, b in zip(keys, keys[1:])
                             if a['at'] <= middle <= b['at'])
        if interpolation != 'linear':
            return False
    return True


def _point(value):
    return float(value), float(value)


def _outward(low, high):
    return math.nextafter(low, -math.inf), math.nextafter(high, math.inf)


def _add(a, b):
    return _outward(a[0] + b[0], a[1] + b[1])


def _negative(a):
    return -a[1], -a[0]


def _multiply(a, b):
    products = (a[0] * b[0], a[0] * b[1], a[1] * b[0], a[1] * b[1])
    return _outward(min(products), max(products))


def _trig_bounds(angle, function):
    if not all(math.isfinite(value) for value in angle):
        return -1., 1.  # No tighter certificate for an unbounded angle.
    middle = angle[0] / 2. + angle[1] / 2.
    radius = math.nextafter(max(middle - angle[0], angle[1] - middle), math.inf)
    # Both sine and cosine are 1-Lipschitz, including intervals spanning extrema.
    center = function(middle)
    bound = _add(_outward(center, center), (-radius, radius))
    return max(-1., bound[0]), min(1., bound[1])


def world_bounds(layout, data, view, clip, forward, step, start, end):
    """Conservative FK boxes, not endpoint chords or a curvature estimate.

    Each supported interpolation is monotone between its keys, so endpoint
    channel ranges contain the complete key-partitioned interval (including
    hold jumps). Outward-rounded interval sums/products and sine/cosine bounds
    contain each composed transform by induction over the FK hierarchy.
    Dependency loss only widens a box; it cannot exclude an interior dip.
    """
    left, modes = pose_values(data, view, clip, start)
    right, _ = pose_values(data, view, clip, end)
    values = {bone: {channel: tuple(sorted((value, right[bone][channel])))
                     for channel, value in channels.items()} for bone, channels in left.items()}
    joints, result = layout['joints'], {}
    zero = _point(0.)

    def visit(name):
        if name in result:
            return result[name]
        joint = joints[name]
        parent, position = joint['parent'], joint['position']
        channels = values.get(name, {})
        mode = modes.get(name, 'pixels')
        if (layout.get('leg_roles') or 'lane_px' in channels) and mode == 'world_step' and name.startswith('foot_'):
            parent = 'root'  # Same world-step floor-anchor parent as fk_world.
        origin = [_point(position[i] - (joints[parent]['position'][i] if parent else 0.)) for i in range(2)]
        amount = channels.get('forward_px', zero)
        if mode == 'fraction_of_step':
            amount = _multiply(amount, _point(step))
        if mode == 'world_step':
            amount = _multiply(_add(amount, _negative(values.get('root', {}).get('forward_px', zero))), _point(step))
        origin = [_add(origin[i], _multiply(_point(forward[i]), amount)) for i in range(2)]
        inward_sign = int(joints['root']['position'][0] > position[0]) - int(joints['root']['position'][0] < position[0])
        origin[0] = _add(origin[0], channels.get('lane_px', zero))
        origin[0] = _add(origin[0], _multiply(_point(inward_sign), channels.get('inward_px', zero)))
        origin[1] = _add(origin[1], _negative(channels.get('lift_px', zero)))
        local_angle = _multiply(channels.get('lean_deg', zero), _point(math.pi / 180.))
        if 'swing_deg' in channels:
            local_angle = _multiply(_add(channels.get('lean_deg', zero), channels['swing_deg']), _point(math.pi / 180.))
        if parent:
            parent_position, parent_angle = visit(parent)
            cosine, sine = _trig_bounds(parent_angle, math.cos), _trig_bounds(parent_angle, math.sin)
            rotated = (_add(_multiply(cosine, origin[0]), _negative(_multiply(sine, origin[1]))),
                       _add(_multiply(sine, origin[0]), _multiply(cosine, origin[1])))
            result[name] = tuple(_add(parent_position[i], rotated[i]) for i in range(2)), _add(parent_angle, local_angle)
        else:
            result[name] = tuple(origin), local_angle
        return result[name]

    for name in joints:
        visit(name)
    positions = {name: transform[0] for name, transform in result.items()}
    if 'gait' in data.get('clips', {}).get(clip, {}):
        # Bound the same post-authored fit as the sampler, with outward
        # interval arithmetic. A sample chord cannot certify this curve.
        fit_low, fit_high = 0., 0.
        for side in ('near', 'far'):
            foot = 'foot_' + side
            a, b, c = [np.asarray(joints[n+'_'+side]['position']) for n in ('thigh','shin','foot')]
            length = float(np.linalg.norm(b-a) + np.linalg.norm(c-b))
            travel = _multiply(_add(values[foot]['forward_px'], _negative(values['root']['forward_px'])), _point(step))
            scale = _add(_point(1.), _multiply(travel, _point(forward[1]/length)))
            maximum = data['clips'][clip]['gait'].get('leg_scale_max', 1.22)
            scale = tuple(float(np.clip(value, .78, maximum)) for value in scale)
            reach = _add(_multiply(_point(length), scale), _point(-.10))
            hip, target = positions['thigh_'+side], positions[foot]
            horizontal = _add(target[0], _negative(hip[0]))
            horizontal_max = max(abs(value) for value in horizontal)
            horizontal_min = max(0., horizontal[0], -horizontal[1])
            vertical_low = math.sqrt(max(.01, math.nextafter(reach[0]*reach[0]-horizontal_max*horizontal_max, -math.inf)))
            vertical_high = math.sqrt(max(.01, math.nextafter(reach[1]*reach[1]-horizontal_min*horizontal_min, math.inf)))
            drop = _add(_add(target[1], _negative(hip[1])), _negative(_outward(vertical_low, vertical_high)))
            fit_low, fit_high = max(fit_low, drop[0]), max(fit_high, drop[1])
        for name, position in positions.items():
            if name not in ('root','foot_near','foot_far'):
                positions[name] = position[0], _add(position[1], (fit_low, fit_high))
    return positions


def box_minimum(first, target):
    difference = [_add(target[i], _negative(first[i])) for i in range(2)]
    nearest = [max(0., bounds[0], -bounds[1]) for bounds in difference]
    # Distance is invariant under the first bone's rotation; its world-space
    # difference box therefore bounds the same local-frame reach minimum.
    squared = [_multiply(_point(value), _point(value)) for value in nearest]
    total = max(0., _add(*squared)[0])
    return max(0., math.nextafter(math.sqrt(total), -math.inf))


def segment_minimum(a, b):
    """Distance from the root to the straight segment in the first bone's frame."""
    delta = b - a
    squared = float(delta @ delta)
    fraction = float(np.clip(-(a @ delta) / squared, 0., 1.)) if squared else 0.
    return float(np.linalg.norm(a + fraction * delta))


def report(layout, data, *, step_distance_px, screen_pixel_scale):
    view = layout['facing']
    forward = np.asarray(data['projection'][view]['forward'])
    step = step_distance_px / screen_pixel_scale
    paths, errors, overreach = [], [], []
    for clip, tracks in data['view_tracks'][view].items():
        # No consecutive segment crosses a key/interpolation boundary, even
        # when two keys are much closer than the global dense sample spacing.
        phases = set(np.linspace(0., 1., DENSE_INTERVALS + 1).tolist())
        phases.update(key['at'] for track in tracks for key in track['keys'])
        summaries, vectors, intervals = {}, {}, {}

        def sample(phase):
            if phase in vectors:
                return vectors[phase]
            values, modes = pose_values(data, view, clip, phase)
            fk = fk_world(layout, values, modes, forward, step)
            points = {}
            for chain in target_chains(layout, values):
                first, second, target = [chain[k] for k in ('first', 'second', 'target')]
                rest = [np.asarray(layout['joints'][n]['position']) for n in (first, second, target)]
                lengths = [float(np.linalg.norm(rest[i + 1] - rest[i])) for i in range(2)]
                # Remove the first bone's animated translation AND rotation.
                # Common body motion must not create an artificial chord dip.
                point = fk[first][:2, :2].T @ (fk[target][:2, 2] - fk[first][:2, 2])
                points[target] = point
                distance = float(np.linalg.norm(point))
                row = summaries.setdefault(target, {'clip': clip, 'target': target,
                    'chain': chain, 'segment_lengths': lengths, 'samples': 0,
                    'allowed_minimum_px': abs(lengths[0] - lengths[1]) + MIN_REACH_MARGIN_PX,
                    'allowed_maximum_px': sum(lengths) * (1. + MAX_REACH_OVERSHOOT),
                    'minimum_px': float('inf'), 'maximum_px': -float('inf')})
                row['samples'] += 1
                if not np.isfinite(distance):
                    errors.append('%s/%s/%s: nonfinite reach at %.9f' % (view, clip, target, phase))
                if distance < row['minimum_px']:
                    row['minimum_px'], row['minimum_phase'] = distance, phase
                if distance > row['maximum_px']:
                    row['maximum_px'], row['maximum_phase'] = distance, phase
            vectors[phase] = points
            return points

        phases = sorted(phases)
        for phase in phases:
            sample(phase)

        def refine(target, start, end):
            row = summaries[target]
            if not all(np.isfinite(sample(phase)[target]).all() for phase in (start, end)):
                return  # The sampled nonfinite reach has already failed.
            key = (start, end)
            if key not in intervals:
                intervals[key] = (None if proven_linear(tracks, start, end) else
                                  world_bounds(layout, data, view, clip, forward, step, start, end))
            boxes = intervals[key]
            bound = (segment_minimum(sample(start)[target], sample(end)[target]) if boxes is None else
                     box_minimum(boxes[row['chain']['first']], boxes[target]))
            if not np.isfinite(bound):
                bound = 0.  # An unbounded box provides no pruning certificate.
            # Prune only certified-safe intervals or ones unable to improve an
            # already observed violation. Nonlinear intervals use FK boxes.
            if bound >= min(row['allowed_minimum_px'], row['minimum_px']):
                return
            middle = (start + end) / 2.
            sample(middle)
            if end - start <= MINIMUM_PHASE_RESOLUTION:
                return
            refine(target, start, middle)
            refine(target, middle, end)

        for start, end in zip(phases, phases[1:]):
            for target in summaries:
                refine(target, start, end)
        for row in summaries.values():
            tag = '%s/%s/%s' % (view, clip, row['target'])
            if row['minimum_px'] < row['allowed_minimum_px']:
                errors.append('%s: minimum reach %.6f px < %.6f px at %.9f' %
                    (tag, row['minimum_px'], row['allowed_minimum_px'], row['minimum_phase']))
            # Director 2026-10-19: overreach straightens the chain toward its target (an intended fling or full
            # extension), so it is reported, not failed. Only inside-minimum targets fold the elbow wrongly.
            if row['maximum_px'] > row['allowed_maximum_px']:
                overreach.append('%s: maximum reach %.6f px > %.6f px at %.6f' %
                    (tag, row['maximum_px'], row['allowed_maximum_px'], row['maximum_phase']))
            paths.append(row)
    return {'ok': not errors, 'errors': sorted(set(errors)), 'overreach': sorted(set(overreach)), 'paths': paths,
            'dense_intervals': DENSE_INTERVALS, 'minimum_margin_px': MIN_REACH_MARGIN_PX,
            'minimum_phase_resolution': MINIMUM_PHASE_RESOLUTION, 'maximum_overshoot': MAX_REACH_OVERSHOOT,
            'step_distance_px': step_distance_px, 'screen_pixel_scale': screen_pixel_scale}
