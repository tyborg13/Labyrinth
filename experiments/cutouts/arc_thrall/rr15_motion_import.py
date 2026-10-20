"""Adopt the director's new motion bytes without rebuilding accepted paint."""
from pathlib import Path
import sys

PROJECT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(PROJECT / 'tools'))
from cutout_pipeline.cases import read_json, write_json, digest
from humanoid_cutout.compiler import compile_motion
from humanoid_cutout.integration import record

CASE = PROJECT / 'experiments/cutouts/arc_thrall/rr11'
DIRECTOR = PROJECT / 'spec/peer_benchmark/staged/rr-11/motion_tracks.json'
ASSETS = PROJECT / 'assets/units/arc_thrall_cutout'


def main(*, owned_only=False):
    original = DIRECTOR.read_bytes()
    previous = read_json(CASE / 'compiled_motion.json')
    layouts = {v: read_json(CASE / f'layouts/{v}.json') for v in previous['view_tracks']}
    compiled = compile_motion(DIRECTOR, 'arc_thrall', layouts, previous['projection'])
    if DIRECTOR.read_bytes() != original:
        raise ValueError('Director data changed during import')
    protected = [p for base in (CASE, ASSETS) for p in base.rglob('*')
                 if p.is_file() and 'proof' not in p.relative_to(base).parts
                 and (p.suffix == '.png' or p.name in ('front.json', 'rear.json'))]
    before = {p: digest(p) for p in protected}
    for base in (CASE, ASSETS / 'humanoid_v2'):
        (base / 'director_motion.json').write_bytes(original)
        write_json(base / 'compiled_motion.json', compiled)
    config = read_json(CASE / 'cutout.json')
    if config['clips'] != compiled['clips']:
        config['clips'] = compiled['clips']
        write_json(CASE / 'cutout.json', config)
    build = read_json(CASE / 'proof/build.json')
    build.update(director_sha256=digest(DIRECTOR), native_proof='pending director feedback-2 captures')
    write_json(CASE / 'proof/build.json', build)
    if owned_only:
        # rr-27 implementation ownership excludes the shared identity/density
        # registries. Import the exact director data and refresh only our
        # existing production closure; int-03/director owns shared records.
        path = ASSETS / 'integration.json'
        integration = read_json(path)
        integration['director_sha256'] = digest(DIRECTOR)
        integration['native_proof'] = 'pending director feedback-2 captures'
        integration['files'] = {name:digest(ASSETS / name) for name in integration['files']}
        write_json(path,integration)
    else:
        record(PROJECT, CASE, ASSETS)
    if any(digest(p) != expected for p, expected in before.items()):
        raise ValueError('Motion import changed accepted paint/layouts')
    assert (CASE / 'director_motion.json').read_bytes() == original
    assert (ASSETS / 'humanoid_v2/director_motion.json').read_bytes() == original
    print('RR15 MOTION IMPORT: PASS (director byte-identical; accepted paint/layouts unchanged)')


if __name__ == '__main__':
    import argparse
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--owned-only', action='store_true',
        help='Import motion and owned closure hashes without shared registry writes')
    main(owned_only=parser.parse_args().owned_only)
