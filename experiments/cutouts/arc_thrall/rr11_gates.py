"""rr-10 gates plus rr-11's every-swing-frame knee requirement."""
import argparse
from pathlib import Path
from rr11_build import CASE, DIRECTOR, read_json, write_json
from rr11_knees import knee_report, support_report
from tools.humanoid_cutout.gates import structure_errors, source_errors, bone_errors, native_errors, bindings


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--native', type=Path)
    args = parser.parse_args()
    data, build, samples = [read_json(CASE / p) for p in ('compiled_motion.json', 'proof/build.json', 'proof/samples.json')]
    errors, cut_errors, knees, supports = [], [], {}, {}
    current = bindings(CASE)
    if (CASE / 'director_motion.json').read_bytes() != DIRECTOR.read_bytes(): errors.append('protected director tracks changed')
    for view in data['view_tracks']:
        layout = read_json(CASE / f'layouts/{view}.json')
        cut_errors += structure_errors(layout, build) + source_errors(CASE, layout, build)
        errors += bone_errors(layout, data, samples, current)
        knees[view] = knee_report(layout, data, samples)
        supports[view] = support_report(layout, data, samples)
        errors += knees[view]['errors']
    errors += cut_errors
    if args.native: errors += native_errors(CASE, args.native)
    placeholders = read_json(CASE / 'cutout.json')['design_placeholders']
    write_json(CASE / 'proof/knees.json', knees)
    write_json(CASE / 'proof/supports.json', supports)
    write_json(CASE / ('proof/native_gates.json' if args.native else 'proof/gates.json'),
        {'ok': not errors, 'errors': errors, 'production_ready': not errors and not placeholders and bool(args.native),
         'design_placeholders': placeholders, 'scope': 'headless source and real Bone2D evidence' if not args.native else 'native windowed proof'})
    print('RR11 SOURCE/CUT GATES: %s (%d errors; both views)' % ('FAIL' if cut_errors else 'PASS', len(cut_errors)))
    print('RR11 %s GATES: %s (%d errors)' % ('NATIVE' if args.native else 'BONE/CUT/KNEE', 'FAIL' if errors else 'PASS', len(errors)))
    for view, report in knees.items():
        print('RR11 %s SWING KNEES: %s (%d samples; minimum %.3f degrees)' %
              (view.upper(), 'PASS' if report['ok'] else 'FAIL', len(report['swing_frames']), report['minimum_bend_deg']))
    for error in errors[:20]: print(error)
    return int(bool(errors))


if __name__ == '__main__': raise SystemExit(main())
