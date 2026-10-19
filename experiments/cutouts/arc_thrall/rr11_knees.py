"""Director swing/facing rules and feedback-2 pixel-snapped stride supports."""
import math
import numpy as np
from maquette_motion.compiler import evaluate
from humanoid_cutout.anatomy import for_layout
from humanoid_cutout.leg_roles import roles_for

MINIMUM_SWING_PEAK_DEG = 15.0  # Director feedback 1, requirement 3.
FACING_BEND_SIDE = {'front': 1., 'rear': -1.}
EPSILON = 0.0001  # Serialized source-pixel evidence tolerance.
PRESENTED_TARGET_TOLERANCE_PX = 0.7072  # Director feedback 2: rounded sqrt(2)/2.


def knee(sample, side):
    a, b, c = [np.asarray(sample['bones'][n + '_' + side]['global'][4:]) for n in ('thigh', 'shin', 'foot')]
    upper, lower = b-a, c-b
    cross = upper[0] * lower[1] - upper[1] * lower[0]
    bend = abs(math.degrees(math.atan2(float(cross), float(np.sum(upper * lower)))))
    side_cross = (c-a)[0] * (b-a)[1] - (c-a)[1] * (b-a)[0]
    return {'bend_deg': bend, 'facing_direction_ok': bool(side_cross * FACING_BEND_SIDE[sample['view']] > EPSILON)}


def swing_intervals(keys):
    result, start = [], None
    for index, row in enumerate(keys):
        if row['value'] > 0 and start is None: start = keys[max(0, index-1)]['at']
        if row['value'] == 0 and start is not None:
            result.append((start, row['at']))
            start = None
    if start is not None: result.append((start, keys[-1]['at']))
    return result


def move_rows(layout, samples):
    return sorted([s for s in samples['samples'] if s['view'] == layout['facing'] and
                   s['clip'] == 'move' and s['kind'] == 'presented'], key=lambda s: s['frame'])


def lift_track(layout, data):
    anatomy = for_layout(layout)
    foot = 'foot_' + roles_for(anatomy, layout['facing'])['stride']
    return next(t for t in data['view_tracks'][layout['facing']]['move'] if t['bone'] == foot and t['channel'] == 'lift_px')


def knee_report(layout, data, samples):
    view, anatomy = layout['facing'], for_layout(layout)
    roles = roles_for(anatomy, view)
    threshold = anatomy['knee_policy']['near_straight_deg']
    track = lift_track(layout, data)
    errors, frames, swings = [], [], []
    rows = move_rows(layout, samples)
    for sample in rows:
        record = {'frame': sample['frame'], 'phase': sample['phase'],
                  'lift_px': evaluate(track['keys'], sample['phase'])}
        for role, side in roles.items():
            record[role] = knee(sample, side)
            if record[role]['bend_deg'] > threshold and not record[role]['facing_direction_ok']:
                errors.append(f'{view}/move/frame {sample["frame"]}/{role}: bent knee against facing ({record[role]["bend_deg"]:.6f} degrees)')
        frames.append(record)
    for index, (start, end) in enumerate(swing_intervals(track['keys'])):
        candidates = [r for r in frames if start < r['phase'] < end and r['lift_px'] > EPSILON]
        if not candidates:
            errors.append(f'{view}/move/swing {index}: missing presented swing frames')
            continue
        peak = max(candidates, key=lambda r: r['stride']['bend_deg'])
        apex = max(candidates, key=lambda r: r['lift_px'])
        record = {'swing': index, 'start': start, 'end': end, 'peak_frame': peak['frame'],
                  'peak_phase': peak['phase'], 'peak_bend_deg': peak['stride']['bend_deg'],
                  'apex_frame': apex['frame'], 'apex_phase': apex['phase'],
                  'apex_stride_bend_deg': apex['stride']['bend_deg'],
                  'apex_stance_bend_deg': apex['trailing']['bend_deg']}
        swings.append(record)
        if record['peak_bend_deg'] + EPSILON < MINIMUM_SWING_PEAK_DEG:
            errors.append(f'{view}/move/swing {index}/frame {peak["frame"]}: peak knee {record["peak_bend_deg"]:.6f} degrees below 15')
        if record['apex_stride_bend_deg'] <= record['apex_stance_bend_deg'] + EPSILON:
            errors.append(f'{view}/move/swing {index}/frame {apex["frame"]}: apex stride knee {record["apex_stride_bend_deg"]:.6f} <= stance {record["apex_stance_bend_deg"]:.6f} degrees')
    if not rows or not swings: errors.append(view + ': missing stride swing evidence')
    return {'ok': not errors, 'errors': errors, 'frames': frames, 'swings': swings,
            'minimum_peak_bend_deg': min((s['peak_bend_deg'] for s in swings), default=None)}


def support_report(layout, data, samples):
    """Zero presented stance motion, with the director's pixel-snap target radius."""
    anatomy, view = for_layout(layout), layout['facing']
    foot = 'foot_' + roles_for(anatomy, view)['stride']
    tolerance = anatomy['planted_tolerance_px']
    lift = lift_track(layout, data)
    progress_track = next(t for t in data['view_tracks'][view]['move'] if t['bone'] == foot and t['channel'] == 'forward_px')
    forward = np.asarray(data['projection'][view]['forward'])
    step = samples['step_distance_px'] / samples['screen_pixel_scale']
    rest = np.asarray(layout['joints'][foot]['position'])
    errors, stance, jab = [], [], []
    for sample in samples['samples']:
        if sample['view'] != view or sample['clip'] not in ('move', 'jab'): continue
        if sample['clip'] == 'move':
            if evaluate(lift['keys'], sample['phase']) > EPSILON: continue
            progress = evaluate(progress_track['keys'], sample['phase'])
            target = rest + forward * progress * step
        else:
            target = rest
        actual = np.asarray(sample['bones'][foot]['global'][4:])
        # Presentation snaps deltas from fractional bind joints to whole
        # source pixels. Recover that exact grid from serialized Bone2D
        # floats before requiring zero movement; do not invent a drift budget.
        presented = rest + np.rint(actual-rest) if sample['kind'] == 'presented' else actual
        target_error = float(np.linalg.norm(presented-target))
        record = {'kind': sample['kind'], 'frame': sample['frame'], 'phase': sample['phase'],
                  'target_px': target.tolist(), 'actual_px': actual.tolist(),
                  'presented_px': presented.tolist(), 'target_error_px': target_error}
        (stance if sample['clip'] == 'move' else jab).append(record)
        limit = PRESENTED_TARGET_TOLERANCE_PX if sample['kind'] == 'presented' else tolerance + EPSILON
        if target_error > limit:
            errors.append(f'{view}/{sample["clip"]}/{sample["kind"]}/frame {sample["frame"]}/phase {sample["phase"]}: stride target error {target_error:.6f} px > {limit}')
    maximum_change = {}
    for clip, records in [('move', stance), ('jab', jab)]:
        previous = None
        maximum_change[clip] = 0.0
        for record in sorted((r for r in records if r['kind'] == 'presented'), key=lambda r: r['frame']):
            # A gap contains swing frames and starts another stance interval.
            if previous is not None and record['frame'] == previous['frame'] + 1:
                change = float(np.linalg.norm(np.asarray(record['presented_px'])-previous['presented_px']))
                record['frame_change_px'] = change
                maximum_change[clip] = max(maximum_change[clip], change)
                if change != 0.0:
                    errors.append(f'{view}/{clip}/presented/frame {record["frame"]}/phase {record["phase"]}: stride stance moved {change:.6f} px from frame {previous["frame"]}; required 0')
            previous = record
    if not stance: errors.append(view + ': missing stride stance evidence')
    if not jab: errors.append(view + ': missing jab support evidence')
    return {'ok': not errors, 'errors': errors, 'scope': 'headless Bone2D support evidence, not native pixels',
            'stance': stance, 'jab': jab,
            'presented_target_tolerance_px': PRESENTED_TARGET_TOLERANCE_PX,
            'maximum_stance_frame_change_px': maximum_change['move'],
            'maximum_jab_frame_change_px': maximum_change['jab'],
            'maximum_stance_target_error_px': max((r['target_error_px'] for r in stance), default=None),
            'maximum_jab_target_error_px': max((r['target_error_px'] for r in jab), default=None)}
