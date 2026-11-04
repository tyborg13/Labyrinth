"""Measure the approved attack targets and exact protected pose differences."""
import argparse
import math
from pathlib import Path
import numpy as np
from rr48_build import CASE, VIEWS
from rr48_gates import elbow_errors
from rr48_raised_motion import TARGETS, BASE
from cutout_pipeline.cases import read_json, write_json, digest

DEFAULTS = {'serialized_tolerance_px': .001}


def pose_diff(a, b):
    differences = []
    for group in ('bones', 'parts'):
        if set(a[group]) != set(b[group]): return float('inf')
        for name in a[group]:
            field = 'global' if group == 'bones' else 'transform'
            differences.extend(abs(x-y) for x, y in zip(a[group][name][field], b[group][name][field]))
    return max(differences, default=0)


def measure(samples):
    motion = read_json(CASE/'compiled_motion.json')
    if samples['compiled_sha256'] != digest(CASE/'compiled_motion.json'): raise ValueError('Stale exact poses')
    rows = {(r['variant'], r['view'], r['clip'], r['phase'], r['kind']): r for r in samples['samples']}
    peaks = []; contacts = []; recovery = []; follow = []; preserved = []
    for view in VIEWS:
        layout = read_json(CASE/f'layouts/{view}.json')
        grip = np.asarray(layout['joints']['falchion']['position'])
        tip = np.asarray(layout['held_items']['falchion']['floor_end'])-grip
        for clip, target in TARGETS.items():
            phase = target['peak']
            for kind in ('authored', 'presented'):
                row = rows['current', view, clip, phase, kind]
                bones = row['bones']; wrist = bones['hand_far']['global'][4:]; shoulder = bones['upper_far']['global'][4:]
                transform = bones['falchion']['global']; a, b, c, d, x, y = transform
                vector = np.array([a*tip[0]+c*tip[1], b*tip[0]+d*tip[1]])
                dy = wrist[1]-shoulder[1]
                effective=target['hand_below_shoulder_px'];budget_path=CASE/'rr57/front_guard_budget.json'
                if view=='front' and clip=='fall' and budget_path.exists():effective=read_json(budget_path)['effective_hand_below_shoulder_px']
                peaks.append({'view': view, 'clip': clip, 'kind': kind, 'phase': phase,
                              'hand_xy': wrist, 'shoulder_xy': shoulder,
                              'hand_below_shoulder_px': dy, 'target_below_shoulder_px': target['hand_below_shoulder_px'],
                              'effective_below_shoulder_px':effective,
                              'height_error_px': abs(dy-effective),
                              'requested_height_shortfall_px':dy-target['hand_below_shoulder_px'],
                              'blade_angle_deg': math.degrees(math.atan2(vector[1], vector[0])),
                              'blade_off_vertical_deg': math.degrees(math.atan2(abs(vector[0]), -vector[1])),
                              'tip_xy': [x+vector[0], y+vector[1]]})
                at = motion['clips'][clip]['contact']
                current = rows['current', view, clip, at, kind]
                baseline = rows['baseline', view, clip, at, kind]
                contacts.append({'view': view, 'clip': clip, 'kind': kind,
                                 'max_pose_diff': pose_diff(current, baseline),
                                 'production_pose_diff': pose_diff(current, rows['production', view, clip, at, kind])})
        for key, row in rows.items():
            variant, v, clip, phase, kind = key
            if variant == 'current' and v == view and (view == 'rear' or phase >= motion['clips'][clip]['contact']):
                preserved.append({'view':view,'clip':clip,'phase':phase,'kind':kind,
                                  'max_pose_diff':pose_diff(row,rows['feedback1',view,clip,phase,kind])})
            if variant == 'current' and v == view and clip == 'fall' and phase >= .5:
                recovery.append({'view': view, 'phase': phase, 'kind': kind,
                                 'max_pose_diff': pose_diff(row, rows['baseline', view, clip, phase, kind])})
        for phase in (.6, .75):
            row = rows['current', view, 'sweep', phase, 'presented']; bones = row['bones']
            wrist = bones['hand_far']['global'][4:]; knee = bones['shin_far']['global'][4:]
            shoulder = bones['upper_far']['global'][4:]
            joints = layout['joints']
            reach = sum(math.dist(joints[a]['position'], joints[b]['position']) for a,b in
                        [('upper_far','fore_far'), ('fore_far','hand_far')])
            follow.append({'view': view, 'phase': phase, 'hand_xy': wrist, 'far_knee_xy': knee,
                           'hand_above_knee_px': knee[1]-wrist[1], 'arm_length_px': reach,
                           'shoulder_to_knee_px': math.dist(shoulder, knee),
                           'status': 'UNREACHABLE_fixed_arm_length' if math.dist(shoulder, knee)>reach else 'reachable'})
    elbow = elbow_errors(motion, {'samples': [r for r in samples['samples'] if r['variant'] == 'current']})
    ok = all(p['height_error_px'] <= DEFAULTS['serialized_tolerance_px'] for p in peaks)
    ok &= all(c['max_pose_diff'] == 0 and c['production_pose_diff'] == 0 for c in contacts)
    ok &= all(r['max_pose_diff'] == 0 for r in recovery) and elbow['ok']
    ok &= all(r['max_pose_diff'] == 0 for r in preserved)
    return {'ok': bool(ok), 'native_pixels': False, 'peaks': peaks, 'contacts': contacts,
            'fall_recovery': recovery, 'sweep_follow': follow, 'elbows': elbow, 'feedback1_preserved_poses':preserved,
            'compiled_sha256': digest(CASE/'compiled_motion.json'), 'defaults': DEFAULTS,
            'native_status': 'pending director native-clean frames and CPU superset verification'}


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--samples', type=Path, required=True); parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args(); report = measure(read_json(args.samples)); write_json(args.output, report)
    print('RR57 HEIGHT/CONTACT/ELBOW:', 'PASS' if report['ok'] else 'FAIL',
          f"({len(report['peaks'])} peak measurements; max contact diff {max(r['max_pose_diff'] for r in report['contacts']):g}; "
          f"max fall recovery diff {max(r['max_pose_diff'] for r in report['fall_recovery']):g}; "
          f"reported height shortfall {max(r['requested_height_shortfall_px'] for r in report['peaks']):.3f} px)")
    raise SystemExit(0 if report['ok'] else 1)
