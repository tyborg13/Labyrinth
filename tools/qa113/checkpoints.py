#!/usr/bin/env python3
"""Sample release campaign saves for QA-103's resolved-phase comparison."""

import argparse
from pathlib import Path
import sys
import time

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "qa101"))
from collect_checkpoints import POLL_SECONDS, snapshot


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("lane", type=Path)
    parser.add_argument("--out", type=Path, required=True)
    parser.add_argument("--runs", type=int, required=True)
    args = parser.parse_args()
    args.out.mkdir(parents=True, exist_ok=True)
    previous = {}
    captured = set()
    while True:
        complete = 0
        for directory in sorted(args.lane.glob("seed-*")):
            if (directory / "evidence.json").exists():
                complete += 1
            else:
                snapshot(directory, args.out, previous, captured, (args.lane.name, directory.name))
        if complete == args.runs:
            break
        time.sleep(POLL_SECONDS)
    print(f"QA113 CHECKPOINTS: {len(captured)} snapshots from {args.lane}", flush=True)


if __name__ == "__main__":
    main()
