"""rr-12 geometry adapter around the unchanged rr-04/rr-05 gates."""
import argparse
from unittest.mock import patch
from rr12_inputs import *
from rr12_prepare import case_for
from rr12_build import native_operations
from rr12_contract import approved_source, expected
from maquette_motion import gates, certificates
from maquette_cutout_polish import gate as pixel_gate
from rr12_stray import report as stray_report


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


def strict_pixel_gate(case, samples, native=None, additional_errors=()):
    """Seal the stray gate together with the unchanged rr-05 report.

    Native verification and review must retain this same strict certificate;
    the review composer cannot silently fall back to the historical distance
    allowance. Refuse inputs changed during either half of the computation.
    """
    tested_bindings = certificates.bindings(case)
    report = pixel_gate(case, samples, native)
    report['stray_pixels'] = stray_report(case, read_json(samples), native)
    report['errors'].extend(report['stray_pixels']['errors'])
    report['errors'].extend(additional_errors)
    report['ok'] = not report['errors']
    report['certificate'] = certificates.issue(case, report, tested_bindings)
    return report


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
            report = strict_pixel_gate(case, args.input or case / 'proof/continuity_samples.json')
            if report['ok']:
                certificates.save(case, report)
        elif args.command == 'native':
            errors = gates.native_errors(case, args.input)
            report = strict_pixel_gate(case, args.input / 'pixel_samples.json', args.input, errors)
            if report['ok']:
                certificates.save(case, report)
        elif args.command == 'production':
            errors = gates.production_errors(read_json(args.input), read_json(case / 'compiled_motion.json'))
            report = {'ok': not errors, 'errors': errors}
        else:
            import maquette_cutout_review as review
            with patch.object(review, 'pixel_gate', strict_pixel_gate):
                review.compose(case, args.input, args.output)
            return 0
    target = args.output or case / ('proof/' + args.command + '_gates.json')
    write_json(target, report)
    print('RR12 %s GATES: %s (%s; %d errors)' % (args.command.upper(),
        'PASS' if report['ok'] else 'FAIL', args.creature, len(report['errors'])))
    for error in report['errors'][:15]:
        print(error)
    return 0 if report['ok'] else 1


if __name__ == '__main__':
    raise SystemExit(main())
