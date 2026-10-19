"""Thrall/Mirror gates for rr-21. Reach violations are reported, never hidden."""
import argparse
import sys
from PIL import Image
from rr21_case import PROJECT, CASE, ASSETS, DIRECTOR
sys.path[:0] = [str(PROJECT), str(PROJECT / 'tools'), str(PROJECT / 'experiments/cutouts/arc_thrall')]
from cutout_pipeline.cases import read_json, write_json
from humanoid_cutout.gates import structure_errors, source_errors, bone_errors, native_errors, bindings
from humanoid_cutout.action_direction import report as direction_report
from humanoid_cutout.reach import report as reach_report
from humanoid_cutout.walk_gates import report as walk_report, support_report, summary as walk_summary
from humanoid_cutout.bone_evidence import load_samples
from rr21_residue import source_report, outside_count, presented_feature_mask


def evaluate(native=None):
    data, build = [read_json(CASE / p) for p in ('compiled_motion.json', 'proof/build.json')]
    samples = load_samples(CASE)
    current = bindings(CASE)
    residues = source_report(CASE, ASSETS)
    errors, views = list(residues['errors']), {}
    if (CASE / 'director_motion.json').read_bytes() != DIRECTOR.read_bytes(): errors.append('Protected director tracks differ')
    for view in data['view_tracks']:
        layout = read_json(CASE / f'layouts/{view}.json')
        cut = structure_errors(layout, build) + source_errors(CASE, layout, build)
        bone = bone_errors(layout, data, samples, current)
        directions = direction_report(layout, data, samples, current, require_presented=True)
        reach = reach_report(layout, data, step_distance_px=samples['step_distance_px'], screen_pixel_scale=samples['screen_pixel_scale'])
        walk = walk_report(layout, data, samples)
        supports = support_report(layout, data, samples)
        errors += cut + bone + directions['errors'] + walk['errors'] + supports['errors'] + reach['errors']
        views[view] = {'cut_errors': cut, 'bone_errors': bone, 'direction': directions,
            'reach': reach, 'walk': walk, 'supports': supports}
    native_residue = []
    if native:
        errors += native_errors(CASE, native, failure_output=CASE / 'proof/logs/native_failures')
        manifest = read_json(native / 'frames.json')
        native_pieces = {}
        for piece in manifest['pieces']:
            key = (piece['view'], piece['clip'], piece['frame'])
            native_pieces.setdefault(key, []).append(dict(piece, absolute_file=str(native / piece['file'])))
        for row in manifest['frames']:
            image = Image.open(native / row['file']).convert('RGBA')
            layout = read_json(CASE / f'layouts/{row["view"]}.json')
            key = (row['view'], row['clip'], row['frame'])
            try:
                exempt = presented_feature_mask(CASE, layout, native_pieces.get(key, []), (image.height, image.width))
                count = outside_count(image, exempt)
            except ValueError as error:
                errors.append(str(error))
                continue
            native_residue.append({'view': row['view'], 'clip': row['clip'], 'frame': row['frame'], 'residue_outside_features': count})
            if count: errors.append(f'{row["view"]}/{row["clip"]}/{row["frame"]}: {count} native residue texels outside declared features')
    findings = read_json(CASE / 'inputs.json')['design_placeholders']
    result = {'ok': not errors, 'errors': sorted(set(errors)), 'views': views, 'residue': residues, 'native_residue': native_residue,
        'design_placeholders': findings,
        'production_ready': not errors and bool(native) and not findings, 'native_pixels': bool(native),
        'reach_policy': 'overreach diagnostic per rr-21 brief; inside-minimum targets fail; all pre-clamp violations retained',
        'residue_gate': 'G >= max(R,B)+12 AND 2*G >= 3*max(R,B); declared feature masks exempt; zero outside features'}
    name = 'native_gates' if native else 'gates'
    write_json(CASE / f'proof/logs/{name}.json', result)
    compact = dict(result, views={})
    for view, report in views.items():
        compact['views'][view] = dict(report,
            direction={k: v for k, v in report['direction'].items() if k != 'rows'},
            walk=walk_summary(report['walk']), supports=walk_summary(report['supports']))
    compact['native_residue'] = {'frames': len(native_residue),
        'maximum_outside_features': max((r['residue_outside_features'] for r in native_residue), default=0),
        'failures': [r for r in native_residue if r['residue_outside_features']]}
    write_json(CASE / f'proof/{name}.json', compact)
    return result


def main():
    from pathlib import Path
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--native', type=Path)
    result = evaluate(parser.parse_args().native)
    for view, report in result['views'].items():
        print('RR21 %s CUT: %s (%d errors)' % (view.upper(), 'FAIL' if report['cut_errors'] else 'PASS', len(report['cut_errors'])))
        print('RR21 %s DIRECTION: %s (%d positive checks; lash/thornwall required)' % (view.upper(), 'PASS' if report['direction']['ok'] else 'FAIL', report['direction']['positive_checks']))
        walk = report['walk']
        print('RR21 %s WALK: %s (%d swings; minimum peak %.3f degrees; fit %.6f px; total drop %.6f px; stance shift %.6f px; target error %.6f px)' %
            (view.upper(), 'PASS' if walk['ok'] else 'FAIL', len(walk['swings']), walk['minimum_peak_bend_deg'],
             walk['maximum_fit_px'], walk['maximum_total_pelvis_drop_px'], walk['maximum_stance_frame_change_px'], walk['maximum_stance_target_error_px']))
        print('RR21 %s REACH: REPORT (%d keyed paths; %d intervals; %d inside-minimum errors; %d overreach reports)' % (view.upper(), len(report['reach']['paths']), report['reach']['dense_intervals'], len(report['reach']['errors']), len(report['reach']['overreach'])))
    print('RR21 RESIDUE: %s (%d derived surfaces; zero outside declared features)' % ('PASS' if result['residue']['ok'] else 'FAIL', len(result['residue']['surfaces'])))
    print('RR21 HEADLESS GATES: %s (%d errors)' % ('PASS' if result['ok'] else 'FAIL', len(result['errors'])))
    for error in result['errors'][:30]: print(error)
    return int(not result['ok'])


if __name__ == '__main__': raise SystemExit(main())
