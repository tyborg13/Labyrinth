"""Independent signed forward-channel checks and an arm-pipeline trace.

Lift, body motion and recovery can move a hand against the facing even while
its forward channel is positive. Isolate that channel against the same pose
with only that target's forward amount zeroed; retain the same reach clamp.
No interpolation, authoring value, bend side or runtime behavior is changed.
"""
import copy
import math
from pathlib import Path

import numpy as np

from .bone_contracts import fk_world, target_chains
from .bone_evidence import evidence_errors
from maquette_motion.compiler import evaluate
from maquette_motion.pixels import phase_for, unpack
from cutout_pipeline.cases import read_json

SOLVE_EPSILON = 1e-6  # Existing runtime reach clamp, not a direction tolerance.
EVIDENCE_EPSILON = 1e-4  # Existing serialized Bone2D evidence tolerance.


def required_clips(layout):
    """Coverage belongs to case data, independently of the mutable channels."""
    path = layout['motion_data']
    if path.startswith('res://'):
        path = str(Path(__file__).resolve().parents[2] / path[6:])
    case = Path(path).parent / 'cutout.json'
    return read_json(case).get('direction_clips', []) if case.exists() else []


def pose_values(data, view, clip, phase):
    values, modes = {}, dict(data.get('view_forward_modes', {}).get(view, {}).get(clip, {}))
    for track in data['view_tracks'][view][clip]:
        values.setdefault(track['bone'], {})[track['channel']] = evaluate(track['keys'], phase)
        modes[track['bone']] = track['forward_mode']
    return values, modes


def clamped_target(shoulder, target, rest):
    a, b, c = rest
    first, second = np.linalg.norm(b - a), np.linalg.norm(c - b)
    ray = target - shoulder
    distance = np.linalg.norm(ray)
    axis = ray / distance if distance > SOLVE_EPSILON else (c - a) / np.linalg.norm(c - a)
    reached = float(np.clip(distance, abs(first - second) + SOLVE_EPSILON,
                            first + second - SOLVE_EPSILON))
    return shoulder + axis * reached, [float(first), float(second)], float(distance), reached


def report(layout, data, samples, current_bindings, *, require_presented=False):
    errors = evidence_errors(data, samples, current_bindings, EVIDENCE_EPSILON)
    if errors:
        return {'ok': False, 'errors': errors, 'rows': [], 'positive_checks': 0}
    view = layout['facing']
    forward = np.asarray(data['projection'][view]['forward'])
    step = samples['step_distance_px'] / samples['screen_pixel_scale']
    explicit = {chain['target'] for chain in layout.get('ik_chains', [])}
    rows, checked, coverage = [], 0, {}
    for sample in samples['samples']:
        if sample['view'] != view or sample['clip'] == 'idle':
            continue
        clip, phase = sample['clip'], sample['phase']
        if sample['kind'] == 'presented':
            if 'direction_bones' not in sample:
                if require_presented:
                    errors.append('%s/%s/%s: missing continuous direction evidence' % (view, clip, phase))
                continue
            phase = phase_for(data['clips'][clip], phase)
        bones = sample.get('direction_bones', sample.get('bones'))
        if not isinstance(bones, dict) or not bones:
            errors.append('%s/%s/%s: missing skeletal direction evidence' % (view, clip, phase))
            continue
        values, modes = pose_values(data, view, clip, phase)
        fk = fk_world(layout, values, modes, forward, step)
        for chain in target_chains(layout, values):
            first, second, target = [chain[k] for k in ('first', 'second', 'target')]
            if not (target.startswith('hand_') or target in explicit):
                continue
            if any(name not in bones for name in (first, second, target)):
                errors.append('%s/%s/%s: missing skeletal direction chain: %s' % (view, clip, phase, target))
                continue
            amount = values.get(target, {}).get('forward_px', 0.)
            mode = modes.get(target, 'pixels')
            if mode == 'fraction_of_step': amount *= step
            if mode == 'world_step':
                amount = (amount - values.get('root', {}).get('forward_px', 0.)) * step
            neutral_values = copy.deepcopy(values)
            neutral_values[target]['forward_px'] = (values.get('root', {}).get('forward_px', 0.)
                                                    if mode == 'world_step' else 0.)
            neutral_fk = fk_world(layout, neutral_values, modes, forward, step)
            rest = [np.asarray(layout['joints'][n]['position']) for n in (first, second, target)]
            shoulder = np.asarray(bones[first]['global'][4:])
            elbow = np.asarray(bones[second]['global'][4:])
            solved = np.asarray(bones[target]['global'][4:])
            neutral, lengths, requested_distance, reached_distance = clamped_target(
                shoulder, neutral_fk[target][:2, 2], rest)
            _, _, authored_distance, solved_distance = clamped_target(shoulder, fk[target][:2, 2], rest)
            dot = float((solved - neutral) @ forward)
            if amount > 0:
                checked += 1
                coverage[clip] = coverage.get(clip, 0) + 1
                if not math.isfinite(dot) or dot <= 0:
                    errors.append('%s/%s/%s: forward direction reversed or stationary: %s (dot %.9f)' %
                                  (view, clip, phase, target, dot))
            basis = bones[second]['global']
            row = {'view': view, 'clip': clip, 'kind': sample['kind'], 'frame': sample['frame'],
                'phase': sample['phase'], 'direction_phase': phase, 'target': target,
                'forward_px': amount, 'channels': values[target], 'forward': forward.tolist(),
                'authored_target': fk[target][:2, 2].tolist(), 'solved_tip': solved.tolist(),
                'shoulder': shoulder.tolist(), 'elbow': elbow.tolist(),
                'rest_tip': rest[2].tolist(), 'segment_lengths': lengths,
                'authored_reach': authored_distance, 'clamped_reach': solved_distance,
                'neutral_requested_reach': requested_distance, 'neutral_clamped_reach': reached_distance,
                'neutral_solved_tip': neutral.tolist(), 'forward_channel_dot': dot,
                'authored_forward_from_rest': float((fk[target][:2, 2] - rest[2]) @ forward),
                'solved_forward_from_rest': float((solved - rest[2]) @ forward),
                'fore_world_angle_deg': math.degrees(math.atan2(basis[1], basis[0])),
                'axis_world_angle_deg': math.degrees(math.atan2(*(solved - elbow)[::-1])),
                'held_world_angles_deg': {name: math.degrees(math.atan2(bones[name]['global'][1],
                    bones[name]['global'][0])) for name in layout.get('held_items', {})}}
            if target == 'tube_tip' and 'tube' in sample.get('parts', {}):
                part = next(p for p in layout['parts'] if p['name'] == 'tube')
                cap = unpack(sample['parts']['tube']['transform']) @ np.append(rest[2] - part['offset'], 1.)
                row['painted_cap'] = cap[:2].tolist()
                row['painted_cap_forward_from_rest'] = float((cap[:2] - rest[2]) @ forward)
            rows.append(row)
    positive_tracks = [track for tracks in data['view_tracks'][view].values() for track in tracks
        if track['channel'] == 'forward_px' and (track['bone'].startswith('hand_') or track['bone'] in explicit)
        and any(key['value'] > 0 for key in track['keys'])]
    if positive_tracks and not checked:
        errors.append(view + ': no positive keyed hand/tube direction checks')
    for clip in required_clips(layout):
        if not coverage.get(clip):
            errors.append('%s/%s: no positive direction checks for required clip' % (view, clip))
    return {'ok': not errors, 'errors': sorted(set(errors)), 'rows': rows,
            'positive_checks': checked, 'clip_positive_checks': coverage, 'minimum_forward_channel_dot': min(
                (r['forward_channel_dot'] for r in rows if r['forward_px'] > 0), default=None)}
