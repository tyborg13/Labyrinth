"""rr-07 geometry adapter around the unchanged rr-04/rr-05 gates."""
import argparse
from unittest.mock import patch
from rr07_inputs import *
from rr07_prepare import case_for
from rr07_build import native_operations
from rr07_contract import approved_source, expected
from maquette_motion import gates, certificates
from maquette_cutout_polish import gate as pixel_gate


def motion_errors(case, samples):
    original = gates.read_json

    def read(path):
        if path == PROJECT / 'spec/art_identity/maquettes' / read_json(case / 'cutout.json')['character_id'] / 'spec.json':
            return original(case / 'source/spec.json')
        return original(path)

    with patch.object(gates, 'approved_source', approved_source), \
         patch.object(gates, 'director_contract', lambda *_: expected(case)), \
         patch.object(gates, 'read_json', read):
        return gates.errors(case, samples)


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('command', choices=('motion', 'pixels', 'native', 'production', 'review'))
    p.add_argument('--creature', choices=CREATURES, required=True)
    p.add_argument('--input', type=Path)
    p.add_argument('--output', type=Path)
    args = p.parse_args()
    case = case_for(args.creature)
    with native_operations(case):
        if args.command == 'motion':
            errors = motion_errors(case, args.input or case / 'proof/motion_samples.json')
            report = {'ok': not errors, 'errors': errors}
        elif args.command == 'pixels':
            report = pixel_gate(case, args.input or case / 'proof/continuity_samples.json')
            if report['ok']:
                certificates.save(case, report)
        elif args.command == 'native':
            errors = gates.native_errors(case, args.input)
            report = pixel_gate(case, args.input / 'pixel_samples.json', args.input)
            report['errors'].extend(errors)
            report['ok'] = not report['errors']
        elif args.command == 'production':
            errors = gates.production_errors(read_json(args.input), read_json(case / 'compiled_motion.json'))
            report = {'ok': not errors, 'errors': errors}
        else:
            from maquette_cutout_review import compose
            compose(case, args.input, args.output)
            return 0
    target = args.output or case / ('proof/' + args.command + '_gates.json')
    write_json(target, report)
    print('RR07 %s GATES: %s (%s; %d errors)' % (args.command.upper(),
        'PASS' if report['ok'] else 'FAIL', args.creature, len(report['errors'])))
    for error in report['errors'][:15]:
        print(error)
    return 0 if report['ok'] else 1


if __name__ == '__main__':
    raise SystemExit(main())
