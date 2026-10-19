"""Signed action direction and per-frame arm evidence; no native pixels."""
import argparse
from pathlib import Path
import sys

PROJECT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(PROJECT / 'tools'))
from cutout_pipeline.cases import read_json, write_json
from humanoid_cutout.action_direction import report
from humanoid_cutout.gates import bindings

SCRATCH = Path('/private/tmp/labyrinth_codex/rr-15')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--case', type=Path, required=True)
    parser.add_argument('--samples', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    if not args.output.resolve().is_relative_to(SCRATCH):
        raise ValueError('Direction traces must stay under ' + str(SCRATCH))
    data, samples = read_json(args.case / 'compiled_motion.json'), read_json(args.samples)
    current = bindings(args.case)
    views = {view: report(read_json(args.case / f'layouts/{view}.json'), data, samples,
                        current, require_presented=True) for view in data['view_tracks']}
    if current != bindings(args.case):
        raise ValueError('Inputs changed during direction trace')
    write_json(args.output, {'native_pixels': False, 'inputs': current,
        'scope': 'real Bone2D continuous/presented trace; forward channel isolated from lift/body/recovery',
        'ok': all(r['ok'] for r in views.values()), 'views': views})
    for view, result in views.items():
        print('RR15 %s %s DIRECTION: %s (%d positive checks; minimum dot %.9f)' %
            (data['creature'].upper(), view.upper(), 'PASS' if result['ok'] else 'FAIL',
             result['positive_checks'], result.get('minimum_forward_channel_dot') or 0.))
        for error in result['errors'][:10]: print(error)
    return int(any(not r['ok'] for r in views.values()))


if __name__ == '__main__':
    raise SystemExit(main())
