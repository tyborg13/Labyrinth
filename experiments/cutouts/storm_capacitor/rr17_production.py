"""Validate real callback progression without seeking frames or inventing poses."""
from rr17_contract import *
from maquette_motion.gates import input_bindings, production_bindings, unpack
from rr17_build import PRODUCTION, compile_motion
from maquette_motion import pixels
import numpy as np


def presented_matches(observed, bone, part, layout):
    if observed is None: return False
    actual = unpack(observed)
    expected = pixels.presented(bone, part, layout, {})
    # Serialized phases and Bone2D are float32. Only an exact authored half
    # pixel can select either adjacent integer; all other coordinates are exact.
    painted = pixels.painted(bone, part, layout)
    for axis in (0, 1):
        value = painted[axis, 2]
        if abs(value - (np.floor(value) + .5)) < TOLERANCE:
            if actual[axis, 2] in (np.floor(value), np.ceil(value)):
                expected[axis, 2] = actual[axis, 2]
    return np.allclose(actual, expected, atol=TOLERANCE, rtol=0)


def production_errors(report):
    errors = []
    bindings = input_bindings(CASE) | production_bindings(PRODUCTION)
    if report.get('inputs') != bindings: errors.append('Stale production/case runtime bindings')
    if read(PRODUCTION / 'compiled_motion.json') != compile_motion(): errors.append('Production motion differs from protected compilation')
    for row in report['frames']:
        snapshot = row['snapshot']
        view = snapshot['facing']
        expected = bones(row['stage'], snapshot['presented_phase'], view, row.get('forward_reflection', 1))
        layout = read(PRODUCTION / (view + '.json'))
        for name, bone in expected.items():
            for space in ('local', 'global'):
                observed = row.get('bones', {}).get(name, {}).get(space)
                if observed is None or not np.allclose(unpack(observed), bone[space], atol=TOLERANCE, rtol=0):
                    errors.append(row['stage'] + '/' + name + ': production signed ' + space + ' motion differs')
        for part in layout['parts']:
            observed = row.get('parts', {}).get(part['name'], {}).get('transform')
            if not presented_matches(observed, expected[part['bone']]['global'], part, layout):
                errors.append(row['stage'] + '/' + part['name'] + ': production stepped motion differs')
    for clip in read(DIRECTOR / 'motion_tracks.json')['storm_capacitor']['clips']:
        rows = [r for r in report['frames'] if r['stage'] == clip]
        phases = [r['snapshot']['phase'] for r in rows]
        if len(rows) < MIN_ACTION_CHANGING_FRAMES: errors.append(clip + ': fewer than six sampled frames')
        if clip != 'idle':
            if not phases or max(phases) - min(phases) < .5: errors.append(clip + ': phase did not progress')
            if any(b + 1e-6 < a for a, b in zip(phases, phases[1:])): errors.append(clip + ': clip restarted')
            states = {r['pose_sha256'] for r in rows}
            if len(states) < MIN_ACTION_CHANGING_FRAMES:
                errors.append(clip + ': fewer than six changing presented states (%d)' % len(states))
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
