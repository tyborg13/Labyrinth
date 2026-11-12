#!/usr/bin/env python3
"""Serial A/B, B/A, A/B headless replay using immutable instrumented snapshots."""
import argparse
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
TAKE_TIMEOUT_SECONDS = 100


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--before', required=True, type=Path)
    parser.add_argument('--after', required=True, type=Path)
    parser.add_argument('--output', required=True, type=Path)
    args = parser.parse_args()
    for pair, order in enumerate(('AB', 'BA', 'AB'), 1):
        for label in order:
            output = args.output / f'pair-{pair}-{label}'
            project = args.before if label == 'A' else args.after
            command = [sys.executable, str(ROOT / 'tools/perf126/replay.py'), '--output', str(output), '--project', str(project)]
            subprocess.run(command, check=True, timeout=TAKE_TIMEOUT_SECONDS)
    print('PERF126 PAIRS: completed A/B, B/A, A/B', flush=True)


if __name__ == '__main__':
    main()
