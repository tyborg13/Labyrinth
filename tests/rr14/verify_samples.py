"""Compare fresh Bone2D evidence byte-for-byte outside the input manifest."""
import argparse
import json
from pathlib import Path
import sys

PROJECT = Path(__file__).resolve().parents[2]
sys.path[:0] = [str(PROJECT / 'tests'), str(PROJECT / 'tools')]
from test_rr14_seer_identity import without_bindings
from humanoid_cutout.gates import bindings

CASE = PROJECT / 'experiments/cutouts/hoarfrost_seer/rr10'


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--samples', type=Path, required=True)
    args = parser.parse_args()
    before = (CASE / 'proof/samples.json').read_bytes()
    after = args.samples.read_bytes()
    if without_bindings(before) != without_bindings(after):
        raise ValueError('Seer headless pose payload changed')
    report = json.loads(after)
    if report['inputs'] != bindings(CASE): raise ValueError('Stale headless bindings')
    print('RR14 SEER SAMPLES: PASS (%d poses; byte-identical outside input bindings)' % len(report['samples']))


if __name__ == '__main__':
    main()
