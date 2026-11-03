"""Strict action direction coverage for hand targets and the torso-led horn blast.

Director feedback 1 removes Gust Bolt's folded horn-hand target. Its positive
forward channel is now torso.forward_px. Measure that actual continuous torso
against the same FK pose with only its forward channel zeroed, retaining the
shared strict positive-dot rule. No motion, clamp or earlier rig is changed.
"""
import copy
import numpy as np
from rr32_case import CASE, ACTION_DIRECTION_CLIPS
from cutout_pipeline.cases import read_json
from humanoid_cutout.action_direction import report as hand_report, pose_values
from humanoid_cutout.bone_contracts import fk_world
from humanoid_cutout.bone_evidence import evidence_errors

EVIDENCE_EPSILON = 0.0001 # Existing serialized Bone2D tolerance.


def report(layout, data, samples, current_bindings, *, require_presented=False, body_contract=None):
    result = hand_report(layout, data, samples, current_bindings, require_presented=require_presented)
    if evidence_errors(data, samples, current_bindings, EVIDENCE_EPSILON): return result
    contract = read_json(CASE / 'cutout.json')
    bodies = contract['body_direction_clips'] if body_contract is None else body_contract
    hands = set(contract['direction_clips'])
    if hands & set(bodies) or hands | set(bodies) != set(ACTION_DIRECTION_CLIPS):
        result['errors'].append('action direction coverage: each action requires one hand or body contract')
    view = layout['facing']
    forward = np.asarray(data['projection'][view]['forward'])
    step = samples['step_distance_px'] / samples['screen_pixel_scale']
    body_checks = {clip: 0 for clip in bodies}
    for row in samples['samples']:
        clip = row['clip']
        if row['view'] != view or clip not in bodies: continue
        bone = bodies[clip]
        if row['kind'] == 'presented' and 'direction_bones' not in row:
            if require_presented: result['errors'].append(view + '/' + clip + ': missing continuous body direction evidence')
            continue
        bones = row.get('direction_bones', row['bones'])
        if bone not in bones:
            result['errors'].append(view + '/' + clip + ': missing body direction bone: ' + bone)
            continue
        phase = row.get('direction_phase', row['phase'])
        values, modes = pose_values(data, view, clip, phase)
        amount = values.get(bone, {}).get('forward_px', 0.)
        if amount <= 0: continue
        neutral_values = copy.deepcopy(values)
        neutral_values[bone]['forward_px'] = 0.
        neutral = fk_world(layout, neutral_values, modes, forward, step)[bone][:2, 2]
        actual = np.asarray(bones[bone]['global'][4:])
        dot = float((actual - neutral) @ forward)
        body_checks[clip] += 1
        if not np.isfinite(dot) or dot <= 0:
            result['errors'].append('%s/%s/%s: body forward direction reversed or stationary: %s (dot %.9f)' %
                                    (view, clip, phase, bone, dot))
        result['rows'].append({'view': view, 'clip': clip, 'kind': row['kind'], 'frame': row['frame'],
            'phase': row['phase'], 'direction_phase': phase, 'target': bone, 'channel_kind': 'body',
            'forward_px': amount, 'forward': forward.tolist(), 'solved_tip': actual.tolist(),
            'neutral_solved_tip': neutral.tolist(), 'forward_channel_dot': dot})
    for clip, count in body_checks.items():
        if not count: result['errors'].append(view + '/' + clip + ': no positive direction checks for required body clip')
        result['clip_positive_checks'][clip] = count
        result['positive_checks'] += count
    result['body_positive_checks'] = body_checks
    result['errors'] = sorted(set(result['errors']))
    result['ok'] = not result['errors']
    result['minimum_forward_channel_dot'] = min((r['forward_channel_dot'] for r in result['rows'] if r['forward_px'] > 0), default=None)
    return result
