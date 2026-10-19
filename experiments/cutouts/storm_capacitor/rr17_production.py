"""Validate real callback progression without seeking frames or inventing poses."""
from rr17_contract import *
from maquette_motion.gates import input_bindings


def production_errors(report):
    errors = []
    if any(report.get('inputs', {}).get(k) != v for k, v in input_bindings(CASE).items()): errors.append('Stale production/case runtime bindings')
    for clip in read(DIRECTOR / 'motion_tracks.json')['storm_capacitor']['clips']:
        rows = [r for r in report['frames'] if r['stage'] == clip]
        phases = [r['snapshot']['phase'] for r in rows]
        if len(rows) < MIN_ACTION_CHANGING_FRAMES: errors.append(clip + ': fewer than six sampled frames')
        if clip != 'idle':
            if not phases or max(phases) - min(phases) < .5: errors.append(clip + ': phase did not progress')
            if any(b + 1e-6 < a for a, b in zip(phases, phases[1:])): errors.append(clip + ': clip restarted')
            states = {r['pose_sha256'] for r in rows}
            if len(states) < MIN_ACTION_CHANGING_FRAMES:
                errors.append(('TODO_DESIGN_hit_changing_frames' if clip == 'hit' else clip) + ': fewer than six changing presented states (%d)' % len(states))
            if report['native_pixels'] and len({r.get('pixels_sha256') for r in rows}) < MIN_ACTION_CHANGING_FRAMES:
                errors.append(clip + ': fewer than six changing native states')
        elif len({r['pose_sha256'] for r in rows}) < 2: errors.append('idle: frozen buzz')
        contact = definition(clip).get('contact')
        if contact is not None:
            if not any(abs(p - contact) < 1e-6 for p in phases): errors.append(clip + ': missing real contact frame')
            for row in rows:
                at = row['snapshot']['phase']
                if at < contact - 1e-6 and row['effect']: errors.append(clip + ': VFX before contact')
                if abs(at - contact) < 1e-6 and not row['effect']: errors.append(clip + ': no VFX at contact')
    if report['completions'].get('hit', {}).get('clip') != 'idle': errors.append('hit: missing return to idle')
    return sorted(set(errors))
