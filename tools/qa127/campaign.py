#!/usr/bin/env python3
"""Drive the whole-run hunt with reproducible headless frames and Pass receipts."""

from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import run_hunt

FIXED_FPS = 30
DRIVER = "tools/qa127/whole_run.gd"


if __name__ == "__main__":
    sys.argv[1:1] = ["--task-id", "qa-127", "--script", DRIVER, "--fixed-fps", str(FIXED_FPS)]
    raise SystemExit(run_hunt.main())
