"""rr-20 gates: certified source, real Bone2D evidence and native GPU pieces."""
import argparse
from pathlib import Path
import sys
import numpy as np
from PIL import Image
from case import ROOT, CASE, ASSETS, DIRECTOR, VIEWS, read_json, write_json, digest
sys.path.insert(0, str(ROOT / 'experiments/cutouts/arc_thrall'))
from rr11_knees import knee_report, lift_track, PRESENTED_TARGET_TOLERANCE_PX
from humanoid_cutout.gates import structure_errors, source_errors, bone_errors, native_errors, bindings
from humanoid_cutout.action_direction import report as direction_report
from humanoid_cutout.reach import report as reach_report
from humanoid_cutout.compiler import compile_motion
from maquette_motion.compiler import evaluate

EPSILON = 0.0001  # Existing serialized Bone2D tolerance.
GREEN_DOMINANCE_MARGIN = 12  # Mirror set: rr-18 feedback 3, requirement 2.


def green_pixels(image):
    rgba = np.asarray(image).astype(int)
    margin = GREEN_DOMINANCE_MARGIN
    return int(((rgba[..., 3] > 0) & (rgba[..., 1] > rgba[..., 0] + margin) & (rgba[..., 1] > rgba[..., 2] + margin)).sum())


def protected_errors():
    errors = []
    for name, expected in read_json(CASE / 'protected_inputs.json').items():
        if digest(ROOT / name) != expected: errors.append('Protected/baseline bytes changed: ' + name)
    if (CASE / 'director_motion.json').read_bytes() != DIRECTOR.read_bytes(): errors.append('Protected director copy changed')
    layouts = {v: read_json(CASE / f'layouts/{v}.json') for v in VIEWS}
    data = read_json(CASE / 'compiled_motion.json')
    if compile_motion(DIRECTOR, 'hollow_mimic', layouts, data['projection']) != data: errors.append('Compiled director channels differ')
    if read_json(ASSETS / 'compiled_motion.json') != data: errors.append('Production director channels differ')
    return errors


def supports(layout, data, samples):
    """Stride stance is world planted; both boots plant during body actions."""
    from humanoid_cutout.anatomy import for_layout
    anatomy = for_layout(layout)
    view = layout['facing']
    stride = 'foot_' + layout['leg_roles']['stride']
    forward = np.asarray(data['projection'][view]['forward'])
    step = samples['step_distance_px'] / samples['screen_pixel_scale']
    lift = lift_track(layout, data)
    progress = next(t for t in data['view_tracks'][view]['move'] if t['bone'] == stride and t['channel'] == 'forward_px')
    errors, rows, previous, overreach = [], [], {}, []
    for sample in samples['samples']:
        if sample['view'] != view: continue
        clip, phase = sample['clip'], sample['phase']
        feet = [stride] if clip == 'move' else ['foot_near', 'foot_far']
        if clip == 'move' and evaluate(lift['keys'], phase) > EPSILON: continue
        for foot in feet:
            rest = np.asarray(layout['joints'][foot]['position'])
            target = rest + forward * evaluate(progress['keys'], phase) * step if clip == 'move' else rest
            clamped = False
            if clip == 'death':
                # Protected death raises the pelvis 1px at .15. A nearly
                # straight leg cannot keep that boot on the floor without
                # stretching. Retain the keys and report the unclamped reach,
                # exactly as the dense reach gate does for authored flings.
                from humanoid_cutout.action_direction import pose_values
                from humanoid_cutout.bone_contracts import fk_world
                values, modes = pose_values(data, view, clip, sample.get('direction_phase', phase))
                fk = fk_world(layout, values, modes, forward, step)
                hip = fk[foot.replace('foot_', 'thigh_')][:2, 2]
                a, b, c = [np.asarray(layout['joints'][foot.replace('foot_', n)]['position']) for n in ('thigh_', 'shin_', 'foot_')]
                length = np.linalg.norm(b - a) + np.linalg.norm(c - b)
                ray = target - hip
                if np.linalg.norm(ray) > length + EPSILON:
                    overreach.append({'foot': foot, 'phase': phase, 'kind': sample['kind'], 'excess_px': float(np.linalg.norm(ray) - length)})
                    target = hip + ray / np.linalg.norm(ray) * length
                    clamped = True
            actual = np.asarray(sample['bones'][foot]['global'][4:])
            presented = rest + np.rint(actual - rest) if sample['kind'] == 'presented' else actual
            distance = float(np.linalg.norm(presented - target))
            limit = PRESENTED_TARGET_TOLERANCE_PX if sample['kind'] == 'presented' else anatomy['planted_tolerance_px'] + EPSILON
            if distance > limit: errors.append(f'{view}/{clip}/{foot}/{sample["kind"]}/{phase}: support target error {distance:.6f}')
            key = (clip, foot)
            if sample['kind'] == 'presented':
                last = previous.get(key)
                if last and not clamped and not last['clamped'] and sample['frame'] == last['frame'] + 1 and not np.array_equal(presented, last['presented']):
                    errors.append(f'{view}/{clip}/{foot}/frame {sample["frame"]}: support slid')
                previous[key] = {'frame': sample['frame'], 'presented': presented, 'clamped': clamped}
            rows.append({'clip': clip, 'foot': foot, 'kind': sample['kind'], 'frame': sample['frame'], 'target_error_px': distance})
    for clip in data['clips']:
        if not any(r['clip'] == clip and r['kind'] == 'presented' for r in rows): errors.append(view + '/' + clip + ': missing support evidence')
    return {'ok': not errors, 'errors': errors, 'rows': rows, 'overreach': overreach,
            'maximum_target_error_px': max((r['target_error_px'] for r in rows), default=None)}


def headless(samples):
    errors = protected_errors()
    data, build, current = read_json(CASE/'compiled_motion.json'), read_json(CASE/'proof/build.json'), bindings(CASE)
    reports = {}
    for view in VIEWS:
        layout = read_json(CASE / f'layouts/{view}.json')
        cut = structure_errors(layout, build) + source_errors(CASE, layout, build)
        for part in layout['parts']:
            if green_pixels(Image.open(CASE / part['file']).convert('RGBA')): cut.append(view + '/' + part['name'] + ': green-dominant source texel')
        bones = bone_errors(layout, data, samples, current)
        direction = direction_report(layout, data, samples, current, require_presented=True)
        reach = reach_report(layout, data, step_distance_px=samples['step_distance_px'], screen_pixel_scale=samples['screen_pixel_scale'])
        knees, support = knee_report(layout, data, samples), supports(layout, data, samples)
        errors += cut + bones + direction['errors'] + reach['errors'] + knees['errors'] + support['errors']
        reports[view] = {'source_errors': cut, 'bone_errors': bones,
            'direction': {k: v for k, v in direction.items() if k != 'rows'}, 'reach': reach, 'knees': knees, 'supports': support}
    return {'ok': not errors, 'errors': sorted(set(errors)), 'native_pixels': False,
            'native_pending': 'director must run density/rest/native/idle/production/review', 'views': reports}


def native(capture):
    errors = native_errors(CASE, capture)
    manifest = read_json(capture / 'frames.json')
    for row in manifest['frames']:
        if green_pixels(Image.open(capture / row['file']).convert('RGBA')):
            errors.append(f'{row["view"]}/{row["clip"]}/{row["frame"]}: green-dominant presented texel')
    return {'ok': not errors, 'errors': errors, 'native_pixels': True}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--native', type=Path)
    args = parser.parse_args()
    result = native(args.native) if args.native else headless(read_json(CASE / 'proof/samples.json'))
    write_json(CASE / ('proof/native_gates.json' if args.native else 'proof/gates.json'), result)
    print('RR20 %s GATES: %s (%d errors; both views)' % ('NATIVE' if args.native else 'SOURCE/BONE/DIRECTION/KNEE/SUPPORT/REACH', 'PASS' if result['ok'] else 'FAIL', len(result['errors'])))
    for view, report in result.get('views', {}).items():
        print('RR20 %s SWING KNEES: %s (%d swings; minimum peak %.3f degrees)' % (view.upper(), 'PASS' if report['knees']['ok'] else 'FAIL', len(report['knees']['swings']), report['knees']['minimum_peak_bend_deg']))
        print('RR20 %s REACH: %s (%d paths; 1000 intervals; %d overreach reports)' % (view.upper(), 'PASS' if report['reach']['ok'] else 'FAIL', len(report['reach']['paths']), len(report['reach']['overreach'])))
    for error in result['errors'][:25]: print(error)
    return int(not result['ok'])


if __name__ == '__main__': raise SystemExit(main())
