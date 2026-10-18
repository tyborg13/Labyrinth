"""Independent every-frame knee angle/direction acceptance, not an IK solver."""
import math
import numpy as np
from maquette_motion.compiler import evaluate

MINIMUM_SWING_BEND_DEG = 15.0  # rr-11 requirement 5.
FACING_BEND_SIDE = {'front': 1., 'rear': -1.}  # (ankle-hip) cross (knee-hip).
EPSILON = 0.0001  # Serialized source-pixel evidence tolerance.


def knee_report(layout, data, samples):
    view = layout['facing']
    errors, rows = [], []
    tracks = {t['source']: t for t in data['view_tracks'][view]['move']}
    for sample in samples['samples']:
        if sample['view'] != view or sample['clip'] != 'move' or sample['kind'] != 'presented': continue
        for side in ('near', 'far'):
            lift = evaluate(tracks['foot_' + side + '.lift_px']['keys'], sample['phase'])
            if lift <= EPSILON: continue
            a, b, c = [np.asarray(sample['bones'][n + '_' + side]['global'][4:]) for n in ('thigh', 'shin', 'foot')]
            upper, lower = b - a, c - b
            cosine = np.clip(np.sum(upper * lower) / (np.linalg.norm(upper) * np.linalg.norm(lower)), -1., 1.)
            bend = math.degrees(math.acos(float(cosine)))
            cross = (c-a)[0] * (b-a)[1] - (c-a)[1] * (b-a)[0]
            direction_ok = cross * FACING_BEND_SIDE[view] > EPSILON
            row = {'view': view, 'side': side, 'frame': sample['frame'], 'phase': sample['phase'],
                   'lift_px': lift, 'bend_deg': bend, 'facing_direction_ok': bool(direction_ok)}
            rows.append(row)
            tag = f'{view}/move/{sample["frame"]}/{side}'
            if bend + EPSILON < MINIMUM_SWING_BEND_DEG: errors.append(tag + ': swing knee below 15 degrees')
            if not direction_ok: errors.append(tag + ': knee bends against facing or is straight')
    if not rows: errors.append(view + ': missing every-frame swing evidence')
    return {'ok': not errors, 'errors': errors, 'swing_frames': rows,
            'minimum_bend_deg': min((r['bend_deg'] for r in rows), default=None)}


def support_report(layout, data, samples):
    """Authored stance against the world-step floor; no invented drift limit."""
    view = layout['facing']
    forward = np.asarray(data['projection'][view]['forward'])
    step = samples['step_distance_px'] / samples['screen_pixel_scale']
    tracks = {t['source']: t for t in data['view_tracks'][view]['move']}
    rows = []
    for sample in samples['samples']:
        if sample['view'] != view or sample['clip'] != 'move' or sample['kind'] != 'authored': continue
        for side in ('near', 'far'):
            foot = 'foot_' + side
            if abs(evaluate(tracks[foot + '.lift_px']['keys'], sample['phase'])) > EPSILON: continue
            progress = evaluate(tracks[foot + '.forward_px']['keys'], sample['phase'])
            floor = np.asarray(layout['joints'][foot]['position']) + forward * progress * step
            actual = np.asarray(sample['bones'][foot]['global'][4:])
            rows.append({'phase': sample['phase'], 'side': side,
                         'floor_target_px': floor.tolist(), 'actual_px': actual.tolist(),
                         'drift_px': float(np.linalg.norm(actual - floor))})
    return {'scope': 'authored stance diagnostics, not native pixels', 'stance_samples': rows,
            'maximum_drift_px': max((r['drift_px'] for r in rows), default=None)}
