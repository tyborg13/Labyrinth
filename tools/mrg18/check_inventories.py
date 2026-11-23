#!/usr/bin/env python3
"""Check the candidate 7 source union and the director's permitted ancestry."""

import subprocess

from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools"))
from mrg17 import check_exports

BASE = "33d6d09f2"
TIPS = ("93ce8fa7b", "5fc49329c", "dda1a033c", "c20d6c02b")
FORBIDDEN = re.compile(r"^(eco-|pt-25|pol-(72|75|76)|qa-133|dmq-|drg-|ux-20|txt-(29|31|32))")
RESTORED_PIN = "assets/art/effects/defense_heal_casts.png"


def main():
    check_exports.BASE = BASE
    check_exports.check_exports(TIPS)
    check_exports.check_assets(TIPS)
    for name, paths in check_exports.filters((ROOT / "export_presets.cfg").read_text()).items():
        assert RESTORED_PIN in paths, (name, RESTORED_PIN)
    for ref in (*TIPS, "HEAD"):
        commits = subprocess.check_output(
            ["git", "log", f"{BASE}..{ref}", "--format=%h %s"], cwd=ROOT, text=True,
        ).splitlines()
        for commit in commits:
            assert not FORBIDDEN.match(commit.split(" ", 1)[1]), commit
    print("MRG-18 APPROVED ANCESTRY: PASS (4 requested tips, 0 forbidden subjects)")


if __name__ == "__main__":
    main()
