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
from rr11_knees import knee_report, support_report
from rr21_residue import source_report, outside_count, presented_feature_mask


def evaluate(native=None):
    data, build, samples = [read_json(CASE / p) for p in ('compiled_motion.json', 'proof/build.json', 'proof/samples.json')]
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
        knees = knee_report(layout, data, samples)
        # Reuse the support oracle without a creature-specific shared branch:
        # it calls its planted action 'jab'; feed each unit action separately.
        supports = {}
        for clip in ('thornwall', 'lash', 'mend', 'hit'):
            subset = dict(samples, samples=[dict(s, clip='jab' if s['clip'] == clip else s['clip']) for s in samples['samples'] if s['clip'] in ('move', clip)])
            supports[clip] = support_report(layout, data, subset)
        errors += cut + bone + directions['errors'] + knees['errors'] + reach['errors']
        for support in supports.values(): errors += support['errors']
        views[view] = {'cut_errors': cut, 'bone_errors': bone, 'direction': directions,
            'reach': reach, 'knees': knees, 'supports': supports}
    native_residue = []
    if native:
        errors += native_errors(CASE, native)
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
    findings = dict(read_json(CASE / 'inputs.json')['design_placeholders'])
    if any(views[v]['knees']['errors'] for v in views):
        findings['TODO_DESIGN_front_move_knee_apex'] = [e for v in views.values() for e in v['knees']['errors']]
    result = {'ok': not errors, 'errors': errors, 'views': views, 'residue': residues, 'native_residue': native_residue,
        'design_placeholders': findings,
        'production_ready': False, 'native_pixels': bool(native),
        'reach_policy': 'overreach diagnostic per rr-21 brief; inside-minimum targets fail; all pre-clamp violations retained',
        'residue_gate': 'G >= max(R,B)+12 AND 2*G >= 3*max(R,B); declared feature masks exempt; zero outside features'}
    write_json(CASE / ('proof/native_gates.json' if native else 'proof/gates.json'), result)
    return result


def main():
    from pathlib import Path
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--native', type=Path)
    result = evaluate(parser.parse_args().native)
    for view, report in result['views'].items():
        print('RR21 %s CUT: %s (%d errors)' % (view.upper(), 'FAIL' if report['cut_errors'] else 'PASS', len(report['cut_errors'])))
        print('RR21 %s DIRECTION: %s (%d positive checks; lash/thornwall required)' % (view.upper(), 'PASS' if report['direction']['ok'] else 'FAIL', report['direction']['positive_checks']))
        print('RR21 %s KNEES: %s (%d swings; minimum peak %.3f degrees)' % (view.upper(), 'PASS' if report['knees']['ok'] else 'FAIL', len(report['knees']['swings']), report['knees']['minimum_peak_bend_deg']))
        print('RR21 %s REACH: REPORT (%d keyed paths; %d intervals; %d inside-minimum errors; %d overreach reports)' % (view.upper(), len(report['reach']['paths']), report['reach']['dense_intervals'], len(report['reach']['errors']), len(report['reach']['overreach'])))
    print('RR21 RESIDUE: %s (%d derived surfaces; zero outside declared features)' % ('PASS' if result['residue']['ok'] else 'FAIL', len(result['residue']['surfaces'])))
    print('RR21 HEADLESS GATES: %s (%d errors)' % ('PASS' if result['ok'] else 'FAIL', len(result['errors'])))
    for error in result['errors'][:30]: print(error)
    return int(not result['ok'])


if __name__ == '__main__': raise SystemExit(main())
