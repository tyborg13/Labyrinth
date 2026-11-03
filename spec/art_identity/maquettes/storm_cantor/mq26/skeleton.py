"""Take-three skeleton: the mq-19 pose solver on the original's leg proportion.

Only the leg chain changes: both thigh and shin scale by one factor until the
posed hip centre sits at the brief's 0.50 H. Ankles, stance, upper-body joints
and every mq-19 pose rule stay as they were; the mq-19 solver poses them.
The sash (pelvis joint) sits at the original's measured sash height.
"""
from copy import deepcopy
import json
import math
from pathlib import Path
import numpy as np

from ..mq19.pose import solve, two_bone, alignment
from ..mq19.generate_design import POSE_RULES, counter_roll

FOLDER = Path(__file__).resolve().parent
SKELETON_DEFAULTS = {'scale_bracket': [1.0, 1.8], 'bisection_iterations': 60}


def design():
    return json.loads((FOLDER / 'design.json').read_text())


def rest_bend(j, side):
    a = j['knee_' + side] - j['hip_' + side]; b = j['ankle_' + side] - j['knee_' + side]
    return math.degrees(math.acos(float(np.clip(a @ b / np.linalg.norm(a) / np.linalg.norm(b), -1, 1))))


def scaled_rest(approved, k, H, sash_offset_over_H):
    """Rest joints with k-times longer legs; ankles and hip X/Y fixed."""
    j = {name: np.asarray(v, float) for name, v in approved.items()}
    out = {name: v.copy() for name, v in j.items()}
    for side in ('near', 'far'):
        a = np.linalg.norm(j['knee_' + side] - j['hip_' + side]) * k
        b = np.linalg.norm(j['ankle_' + side] - j['knee_' + side]) * k
        bend = math.radians(rest_bend(j, side))
        reach = math.sqrt(a * a + b * b + 2 * a * b * math.cos(bend))
        ankle = j['ankle_' + side]; hip = j['hip_' + side].copy()
        horizontal = np.linalg.norm((hip - ankle)[:2])
        hip[2] = ankle[2] + math.sqrt(reach * reach - horizontal * horizontal)
        out['hip_' + side] = hip
        out['knee_' + side] = two_bone(hip, ankle, (a, b), np.array([1., 0, 0]))
    centre = (out['hip_near'] + out['hip_far']) / 2
    # The rest pelvis joint is the sash centre: the pose rotation is a pure roll.
    out['pelvis'] = centre + np.array([0, 0, sash_offset_over_H * H])
    return out


def baseline_with(baseline, joints, thigh_vertices=None):
    result = deepcopy(baseline)
    result['joints'] = {k: np.asarray(v, float).tolist() for k, v in joints.items()}
    if thigh_vertices is not None:
        piece = next(p for p in result['pieces'] if p['id'] == 'thigh_plate_near')
        piece['vertices'] = np.asarray(thigh_vertices, float).tolist()
    return result


def pose_rules():
    return dict(POSE_RULES)


def solve_skeleton(baseline, hip_metric, sash_metric, thigh_builder=None):
    """Return (rest_baseline, posed joints, frames, info).

    hip_metric(joints, frames) -> the hip joint's sprite-style height (over H);
    the leg scale solves it to the brief's 0.50. sash_metric(joints, frames,
    offset) -> the sash centre's height; the rest sash offset solves it to the
    original's measured value. thigh_builder(joints) -> posed near-thigh
    vertices, so the near-wrist rule reads the actual take-three thigh plate.
    """
    d = design(); H = baseline['mq17']['height_m']
    p = pose_rules(); resolution = counter_roll(baseline, p)
    target = d['brief']['hip_joint_over_H']
    approved = baseline['joints']
    def posed(k, thigh=None, sash=0.):
        rest = scaled_rest(approved, k, H, sash)
        base = baseline_with(baseline, rest, thigh)
        j, frames, points = solve(base, p, resolution)
        return base, j, frames, points
    lo, hi = SKELETON_DEFAULTS['scale_bracket']
    for _ in range(SKELETON_DEFAULTS['bisection_iterations']):
        mid = (lo + hi) / 2
        _, j, frames, _ = posed(mid)
        if hip_metric(j, frames) < target: lo = mid
        else: hi = mid
    k = (lo + hi) / 2
    _, j, frames, _ = posed(k)
    # The sash height is linear in its rest offset along the pelvis axis.
    goal = d['measured_original']['sash_centre_over_H']
    a0, a1 = sash_metric(j, frames, 0.), sash_metric(j, frames, .1)
    sash = .1 * (goal - a0) / (a1 - a0)
    lo = hi = None
    base, j, frames, _ = posed(k, None, sash)
    if thigh_builder is not None:
        # Map the posed take-three thigh back through the solver's own rigid
        # alignment; legs are unchanged, only the near-arm swing re-solves.
        old = {n: np.asarray(v, float) for n, v in base['joints'].items()}
        delta = alignment(old['knee_near'] - old['hip_near'], j['knee_near'] - j['hip_near'])
        thigh = np.asarray(thigh_builder(j), float)
        rest_thigh = old['hip_near'] + np.einsum('nj,jk->nk', thigh - j['hip_near'], delta)
        base, j2, frames, points = posed(k, rest_thigh, sash)
        if any(np.linalg.norm(j2[n] - j[n]) > 1e-12 for n in j if n.startswith(('hip', 'knee', 'ankle'))):
            raise ValueError('Thigh registration changed the solved legs')
        j = j2
    info = {'leg_scale': k, 'posed_hip_centre_body_over_H': float((j['hip_near'][2] + j['hip_far'][2]) / 2 / H),
            'hip_screen_over_H': float(hip_metric(j, frames)), 'rest_sash_offset_over_H': sash,
            'sash_screen_over_H': float(sash_metric(j, frames, sash)), 'pose_resolution': resolution}
    return base, j, frames, info
