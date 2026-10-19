"""Dense, unclamped FK target reach gate; never tune the runtime to pass it."""
import numpy as np

from .action_direction import pose_values
from .bone_contracts import fk_world, target_chains

DENSE_INTERVALS = 1000
MIN_REACH_MARGIN_PX = 4.0
MAX_REACH_OVERSHOOT = 0.02


def report(layout, data, *, step_distance_px, screen_pixel_scale):
    view = layout['facing']
    forward = np.asarray(data['projection'][view]['forward'])
    step = step_distance_px / screen_pixel_scale
    paths, errors, overreach = [], [], []
    for clip, tracks in data['view_tracks'][view].items():
        phases = set(np.linspace(0., 1., DENSE_INTERVALS + 1).tolist())
        phases.update(key['at'] for track in tracks for key in track['keys'])
        summaries = {}
        for phase in sorted(phases):
            values, modes = pose_values(data, view, clip, phase)
            chains = target_chains(layout, values)
            if not chains: continue
            fk = fk_world(layout, values, modes, forward, step)
            for chain in chains:
                first, second, target = [chain[k] for k in ('first', 'second', 'target')]
                rest = [np.asarray(layout['joints'][n]['position']) for n in (first, second, target)]
                lengths = [float(np.linalg.norm(rest[i + 1] - rest[i])) for i in range(2)]
                distance = float(np.linalg.norm(fk[target][:2, 2] - fk[first][:2, 2]))
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
        for row in summaries.values():
            tag = '%s/%s/%s' % (view, clip, row['target'])
            if row['minimum_px'] < row['allowed_minimum_px']:
                errors.append('%s: minimum reach %.6f px < %.6f px at %.6f' %
                    (tag, row['minimum_px'], row['allowed_minimum_px'], row['minimum_phase']))
            # Director 2026-10-19: overreach straightens the chain toward its target (an intended fling or full
            # extension), so it is reported, not failed. Only inside-minimum targets fold the elbow wrongly.
            if row['maximum_px'] > row['allowed_maximum_px']:
                overreach.append('%s: maximum reach %.6f px > %.6f px at %.6f' %
                    (tag, row['maximum_px'], row['allowed_maximum_px'], row['maximum_phase']))
            paths.append(row)
    return {'ok': not errors, 'errors': sorted(set(errors)), 'overreach': sorted(set(overreach)), 'paths': paths,
            'dense_intervals': DENSE_INTERVALS, 'minimum_margin_px': MIN_REACH_MARGIN_PX,
            'maximum_overshoot': MAX_REACH_OVERSHOOT,
            'step_distance_px': step_distance_px, 'screen_pixel_scale': screen_pixel_scale}
