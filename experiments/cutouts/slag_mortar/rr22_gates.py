"""rr-22 source/Bone2D gates and strict native gates; no invented exceptions."""
import argparse
import math
from rr22_case import CASE, ASSETS, DIRECTOR
from cutout_pipeline.cases import read_json, write_json
from humanoid_cutout.gates import structure_errors, source_errors, bone_errors, native_errors, bindings
from humanoid_cutout.action_direction import report as direction_report
from humanoid_cutout.reach import report as reach_report
from humanoid_cutout.gait import evaluate
from humanoid_cutout.walk_gates import report as knee_report, support_report
from rr22_records import samples as read_samples, summary, space_summary
import rr22_residue_gate as residue
import rr22_surface_gates as surfaces
EPSILON = 0.0001


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
    return {'ok': not errors, 'errors': errors, 'rows': rows,
            'minimum_angle_deg': min((r['angle_deg'] for r in rows), default=0.),
            'maximum_angle_deg': max((r['angle_deg'] for r in rows), default=0.)}


def run(native=None):
    data, build = [read_json(CASE / p) for p in ('compiled_motion.json', 'proof/build.json')]
    samples = read_samples()
    errors, reports = [], {}
    placeholders = read_json(CASE / 'cutout.json')['design_placeholders']
    errors += ['unresolved design placeholder: ' + name for name in placeholders]
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
        errors += residue.source_errors(CASE, layout)
        errors += surfaces.errors(CASE, layout)
        production = read_json(ASSETS / f'humanoid_v2/{view}.json')
        errors += residue.source_errors(ASSETS / 'humanoid_v2', production,
                                      feature_case=CASE, feature_layout=layout)
    spaces = []
    if native:
        if read_json(native / 'frames.json')['inputs'] != current:
            errors.append('stale native proof inputs; rerun the director windowed capture for the new cut and gait')
        else:
            errors += native_errors(CASE, native, failure_output=CASE / 'proof/seam_cpu/native_failures',
                                    space_details=spaces)
            errors += residue.native_errors(CASE, native)
    result = {'ok': not errors, 'errors': errors, 'native_pixels': bool(native), 'views': {view: {name: summary(report) for name, report in checks.items()} for view, checks in reports.items()},
              'design_placeholders': placeholders, 'source_space': space_summary(spaces)}
    result['production_ready'] = not errors and not result['design_placeholders'] and bool(native)
    full_name = 'native_gates_full' if native else 'gates_full'
    write_json(CASE / ('proof/logs/' + full_name + '.json'), dict(result, views=reports, passed_spaces=spaces))
    write_json(CASE / ('proof/native_gates.json' if native else 'proof/gates.json'), result)
    print('RR22 %s GATES: %s (%d errors; both views)' % ('NATIVE' if native else 'SOURCE/BONE/KNEE', 'FAIL' if errors else 'PASS', len(errors)))
    for view, checks in reports.items():
        print('RR22 %s: %d swings; minimum peak %.3f degrees; support drift %.6f px; reach %d paths, %d overreach reports' %
            (view.upper(), len(checks['knees']['swings']), checks['knees']['minimum_peak_bend_deg'], checks['supports']['maximum_stance_frame_change_px'],
             len(checks['reach']['paths']), len(checks['reach']['overreach'])))
        print('RR22 %s WALK: %s (maximum fit %.6f px; total drop %.6f px)' % (view.upper(), 'PASS' if checks['knees']['ok'] else 'FAIL', checks['knees']['maximum_fit_px'], checks['knees']['maximum_total_pelvis_drop_px']))
    for error in errors[:20]: print(error)
    return result


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--native', type=__import__('pathlib').Path)
    raise SystemExit(not run(parser.parse_args().native)['ok'])
