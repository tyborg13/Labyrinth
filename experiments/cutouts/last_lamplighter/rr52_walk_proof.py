"""Run walk-01's unchanged gates for the Last Lamplighter only."""
import argparse
from pathlib import Path
from rr52_build import ROOT
from humanoid_cutout import walk_proof

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--samples', type=Path, required=True)
    parser.add_argument('--baseline', default='d924af0bf')
    parser.add_argument('--motion-dir', type=Path)
    parser.add_argument('--move-only', action='store_true')
    args = parser.parse_args()
    walk_proof.TYPES = ('last_lamplighter',)
    result = walk_proof.prove(args.samples, args.baseline, args.motion_dir, args.move_only)
    raise SystemExit(0 if result['ok'] else 1)
