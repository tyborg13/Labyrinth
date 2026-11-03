"""Unrelaxed humanoid gates, including director feedback 1 body-led direction."""
import argparse
from pathlib import Path
import sys
import numpy as np
from rr32_case import PROJECT, CASE, DIRECTOR
sys.path[:0] = [str(PROJECT / 'tools'), str(PROJECT)]
from cutout_pipeline.cases import read_json, write_json
from humanoid_cutout.gates import structure_errors, source_errors, bone_errors, native_errors, bindings, EPSILON
from rr32_direction import report as direction_report
from rr32_repair_checks import errors as repair_errors
from humanoid_cutout.reach import report as reach_report
from humanoid_cutout.walk_gates import report as walk_report, support_report, summary
from humanoid_cutout.bone_evidence import read_report


def cloth_errors(data):
    errors = []
    for view, clips in data['view_tracks'].items():
        for clip, tracks in clips.items():
            for track in tracks:
                if not track['bone'].startswith('cape_'): continue
                tag = view + '/' + clip + '/' + track['source']
                if any(abs(k['value']) > 4 for k in track['keys']): errors.append(tag + ': cloth exceeds 4 px')
                if not data['clips'][clip].get('terminal', False) and track['keys'][-1]['value'] != 0:
                    errors.append(tag + ': cloth not settled at end')
                if data['clips'][clip].get('terminal', False) and len(track['keys']) > 1:
                    last, previous = track['keys'][-1], track['keys'][-2]
                    if last['interpolation'] == 'linear' and last['value'] != previous['value']:
                        errors.append(tag + ': terminal cloth still moving at end')
    return errors


def horn_grip_errors(report, view):
    """Held horn and fist share an origin before and after presentation snaps."""
    errors = []
    for row in report.get('samples', []):
        if row.get('view') != view: continue
        tag = '%s/%s/%s/%s' % (view, row.get('clip'), row.get('kind'), row.get('frame'))
        try:
            horn, hand = [np.asarray(row['bones'][name]['global'][4:], dtype=float)
                          for name in ('horn', 'hand_far')]
            valid = (horn.shape == hand.shape == (2,) and np.isfinite(horn).all() and
                     np.isfinite(hand).all() and np.allclose(horn, hand, atol=EPSILON, rtol=0))
        except (KeyError, TypeError, ValueError):
            valid = False
        if not valid: errors.append(tag + ': horn grip origin differs from hand_far')
    return errors


def evaluate(native=None, case=CASE, output=None):
    output = Path(output) if output is not None else case / 'proof'
    data, build = [read_json(case / p) for p in ('compiled_motion.json', 'proof/build.json')]
    samples, current = read_report(case), bindings(case)
    errors, views = cloth_errors(data), {}
    if (case / 'director_motion.json').read_bytes() != DIRECTOR.read_bytes(): errors.append('Protected director import differs')
    for view in data['view_tracks']:
        layout = read_json(case / f'layouts/{view}.json')
        cut = structure_errors(layout, build) + source_errors(case, layout, build) + repair_errors(case, layout)
        bone = bone_errors(layout, data, samples, current) + horn_grip_errors(samples, view)
        direction = direction_report(layout, data, samples, current, require_presented=True)
        reach = reach_report(layout, data, step_distance_px=samples['step_distance_px'], screen_pixel_scale=samples['screen_pixel_scale'])
        walk, supports = walk_report(layout, data, samples), support_report(layout, data, samples)
        errors += cut + bone + direction['errors'] + reach['errors'] + walk['errors'] + supports['errors']
        views[view] = {'cut_errors': cut, 'bone_errors': bone, 'direction': direction,
                       'reach': reach, 'walk': walk, 'supports': supports}
    if native: errors += native_errors(case, native, failure_output=output / 'logs/native_failures')
    placeholders = read_json(case / 'inputs.json')['design_placeholders']
    result = {'ok': not errors, 'errors': sorted(set(errors)), 'views': views,
              'design_placeholders': placeholders, 'native_pixels': bool(native),
              'production_ready': not errors and bool(native) and not placeholders,
              'reach_policy': 'overreach reported; inside-minimum targets fail'}
    name = 'native_gates' if native else 'gates'
    write_json(output / f'logs/{name}.json', result)
    compact = dict(result, views={v: dict(r, direction={k: x for k, x in r['direction'].items() if k != 'rows'},
        walk=summary(r['walk']), supports=summary(r['supports'])) for v, r in views.items()})
    write_json(output / f'{name}.json', compact)
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--case', type=Path, default=CASE)
    parser.add_argument('--native', type=Path)
    parser.add_argument('--output', type=Path, help='Proof directory; defaults to the supplied case/proof')
    args = parser.parse_args()
    result = evaluate(args.native, args.case, args.output)
    for view, row in result['views'].items():
        for label, findings in [('CUT', row['cut_errors']), ('BONES', row['bone_errors']),
                                ('DIRECTION', row['direction']['errors']), ('WALK', row['walk']['errors']),
                                ('SUPPORTS', row['supports']['errors'])]:
            print('RR32 %s %s: %s (%d errors)' % (view.upper(), label, 'FAIL' if findings else 'PASS', len(findings)))
        print('RR32 %s REACH: REPORT (%d paths; %d intervals; %d errors; %d overreach reports)' %
              (view.upper(), len(row['reach']['paths']), row['reach']['dense_intervals'], len(row['reach']['errors']), len(row['reach']['overreach'])))
    print('RR32 HEADLESS GATES: %s (%d errors)' % ('PASS' if result['ok'] else 'FAIL', len(result['errors'])))
    for error in result['errors'][:20]: print(error)
    return int(not result['ok'])


if __name__ == '__main__': raise SystemExit(main())
