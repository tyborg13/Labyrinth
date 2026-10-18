"""rr-10 gates. Native proof is only accepted after director windowed capture."""
import argparse
from rr10_build import CASE, DIRECTOR, read_json, write_json, digest
from tools.humanoid_cutout.gates import structure_errors, source_errors, bone_errors, native_errors


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--native', type=str)
    args = parser.parse_args()
    data = read_json(CASE / 'compiled_motion.json')
    data['_sha256'] = digest(CASE / 'compiled_motion.json')
    errors = []
    if (CASE / 'director_motion.json').read_bytes() != DIRECTOR.read_bytes():
        errors.append('protected director tracks changed')
    for view in data['view_tracks']:
        layout = read_json(CASE / f'layouts/{view}.json')
        errors += structure_errors(layout, read_json(CASE / 'proof/build.json'))
        errors += source_errors(CASE, layout, read_json(CASE / 'proof/build.json'))
        errors += bone_errors(layout, data, read_json(CASE / 'proof/samples.json'))
    if args.native:
        from pathlib import Path
        errors += native_errors(CASE, Path(args.native))
    write_json(CASE / ('proof/native_gates.json' if args.native else 'proof/gates.json'), {'ok': not errors, 'errors': errors,
        'production_ready': False, 'design_placeholders':read_json(CASE / 'cutout.json')['design_placeholders'],
        'scope': 'front; headless structure and real bones' if not args.native else 'native windowed proof'})
    print('RR10 %s GATES: %s (%d errors)' % ('NATIVE' if args.native else 'FRONT BONE/CUT', 'FAIL' if errors else 'PASS', len(errors)))
    for error in errors[:30]: print(error)
    return int(bool(errors))


if __name__ == '__main__':
    raise SystemExit(main())
