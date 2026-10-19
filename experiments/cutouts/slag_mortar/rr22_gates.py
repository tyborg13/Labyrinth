"""rr-22 source/Bone2D gates and strict native gates; no invented exceptions."""
import argparse
import math
import sys
import numpy as np
from PIL import Image
from rr22_case import PROJECT, CASE, DIRECTOR
from cutout_pipeline.cases import read_json, write_json
from humanoid_cutout.gates import structure_errors, source_errors, bone_errors, native_errors, bindings
from humanoid_cutout.action_direction import report as direction_report
from humanoid_cutout.reach import report as reach_report
from maquette_motion.compiler import evaluate
sys.path.insert(0, str(PROJECT / 'experiments/cutouts/arc_thrall'))
from rr11_knees import knee_report, lift_track, PRESENTED_TARGET_TOLERANCE_PX

EPSILON = 0.0001


def support_report(layout, data, samples):
    view = layout['facing']
    foot = 'foot_' + data['leg_roles'][view]['stride']
    rest = np.asarray(layout['joints'][foot]['position'])
    tracks = data['view_tracks'][view]['move']
    progress = next(t for t in tracks if t['bone'] == foot and t['channel'] == 'forward_px')
    lift = lift_track(layout, data)
    forward = np.asarray(data['projection'][view]['forward'])
    step = samples['step_distance_px'] / samples['screen_pixel_scale']
    rows, errors, previous, maximum = [], [], None, 0.0
    for row in samples['samples']:
        if row['view'] != view or row['clip'] != 'move' or row['kind'] != 'presented': continue
        if evaluate(lift['keys'], row['phase']) > EPSILON: continue
        target = rest + forward * evaluate(progress['keys'], row['phase']) * step
        actual = rest + np.rint(np.asarray(row['bones'][foot]['global'][4:]) - rest)
        distance = float(np.linalg.norm(actual - target))
        if distance > PRESENTED_TARGET_TOLERANCE_PX: errors.append(f'{view}/move/{row["frame"]}: support target {distance}')
        if previous is not None and previous['frame'] + 1 == row['frame']:
            delta = float(np.linalg.norm(actual - previous['actual']))
            maximum = max(maximum, delta)
            if delta != 0: errors.append(f'{view}/move/{row["frame"]}: support slid {delta}')
        previous = {'frame': row['frame'], 'actual': actual}
        rows.append({'frame': row['frame'], 'target_error_px': distance})
    if not rows: errors.append(view + ': missing support evidence')
    return {'ok': not errors, 'errors': errors, 'rows': rows, 'maximum_stance_frame_change_px': maximum}


def lob_report(layout, data, samples):
    """Lob deliberately has no forward hand keys: check its signed item angle."""
    view, errors, rows = layout['facing'], [], []
    track = next(t for t in data['view_tracks'][view]['lob'] if t['source'] == 'mortar.angle_deg')
    for row in samples['samples']:
        if row['view'] != view or row['clip'] != 'lob' or row['kind'] != 'authored': continue
        angle = math.degrees(math.atan2(*row['bones']['mortar']['global'][1::-1]))
        expected = evaluate(track['keys'], row['phase'])
        if abs(angle - expected) > EPSILON: errors.append(f'{view}/lob/{row["phase"]}: mortar signed angle differs')
        rows.append({'phase': row['phase'], 'angle_deg': angle, 'expected_deg': expected})
    if not any(abs(r['phase'] - data['clips']['lob']['contact']) < EPSILON and abs(r['angle_deg']) > 0 for r in rows):
        errors.append(view + ': missing lob contact direction')
    return {'ok': not errors, 'errors': errors, 'rows': rows}


def green_pixels(image):
    rgba = np.asarray(image.convert('RGBA')).astype(np.int16)
    return int(((rgba[..., 3] > 0) & (rgba[..., 1] > rgba[..., 0]) & (rgba[..., 1] > rgba[..., 2])).sum())


def run(native=None):
    data, build, samples = [read_json(CASE / p) for p in ('compiled_motion.json', 'proof/build.json', 'proof/samples.json')]
    errors, reports = [], {}
    current = bindings(CASE)
    if (CASE / 'director_motion.json').read_bytes() != DIRECTOR.read_bytes(): errors.append('protected motion import differs')
    for view in data['view_tracks']:
        layout = read_json(CASE / f'layouts/{view}.json')
        errors += structure_errors(layout, build) + source_errors(CASE, layout, build)
        errors += bone_errors(layout, data, samples, current)
        reports[view] = {'direction': direction_report(layout, data, samples, current, require_presented=True),
            'lob': lob_report(layout, data, samples), 'knees': knee_report(layout, data, samples),
            'supports': support_report(layout, data, samples),
            'reach': reach_report(layout, data, step_distance_px=samples['step_distance_px'], screen_pixel_scale=samples['screen_pixel_scale'])}
        for value in reports[view].values(): errors += value['errors']
        # R >= G for every source paint texel is closed under the runtime's
        # nearest/linear texture sampling and alpha composition. Native frames
        # are still scanned independently below, never inferred from this.
        green = sum(green_pixels(Image.open(CASE / p['file'])) for p in layout['parts'])
        if green: errors.append(f'{view}: green-dominant source texels: {green}')
    if native:
        errors += native_errors(CASE, native)
        for row in read_json(native / 'frames.json')['frames']:
            count = green_pixels(Image.open(native / row['file']))
            if count: errors.append(f'{row["file"]}: {count} green-dominant presented texels')
    result = {'ok': not errors, 'errors': errors, 'native_pixels': bool(native), 'views': reports,
              'design_placeholders': read_json(CASE / 'cutout.json')['design_placeholders']}
    result['production_ready'] = not errors and not result['design_placeholders'] and bool(native)
    write_json(CASE / ('proof/native_gates.json' if native else 'proof/gates.json'), result)
    print('RR22 %s GATES: %s (%d errors; both views)' % ('NATIVE' if native else 'SOURCE/BONE/KNEE', 'FAIL' if errors else 'PASS', len(errors)))
    for view, checks in reports.items():
        print('RR22 %s: %d swings; minimum peak %.3f degrees; support drift %.6f px; reach %d paths, %d overreach reports' %
            (view.upper(), len(checks['knees']['swings']), checks['knees']['minimum_peak_bend_deg'], checks['supports']['maximum_stance_frame_change_px'],
             len(checks['reach']['paths']), len(checks['reach']['overreach'])))
    for error in errors[:20]: print(error)
    return result


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--native', type=__import__('pathlib').Path)
    raise SystemExit(not run(parser.parse_args().native)['ok'])
