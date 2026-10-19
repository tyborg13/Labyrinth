"""Thrall compatibility entrypoints; both-leg walking lives in shared gates."""
from humanoid_cutout.walk_gates import report as knee_report, support_report, knee
from humanoid_cutout.walk_gates import EPSILON, TARGET_TOLERANCE_PX as PRESENTED_TARGET_TOLERANCE_PX


def swing_intervals(keys):
    result, start = [], None
    for index, row in enumerate(keys):
        if row['value'] > 0 and start is None: start = keys[max(0, index-1)]['at']
        if row['value'] == 0 and start is not None:
            result.append((start, row['at']))
            start = None
    if start is not None: result.append((start, keys[-1]['at']))
    return result


def lift_track(layout, data, side='near'):
    return next(t for t in data['view_tracks'][layout['facing']]['move']
                if t['bone']=='foot_'+side and t['channel']=='lift_px')
