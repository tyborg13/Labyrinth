#!/usr/bin/env python3
"""Compare fel-08 hover evidence with a pre-change fel-07 census and witness."""

import argparse
import json
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "fel07"))
from compare_census import off_square, samples, without_popup


PILLAR_PICKS = {("01", "C"), ("09", "C")}
PILLAR_TILE = "(7, 7)"
PILLAR_ENTRY = {"title": "Pillar", "description": "Blocks movement and sight.", "icon": ""}
PILLAR_PANEL = {"title": "Pillar", "icon": "", "builder_key": "",
                "text": ["PILLAR", PILLAR_ENTRY["description"]]}


def compare_census(base_path, branch_path):
    base, branch = samples(base_path), samples(branch_path)
    if base.keys() != branch.keys() or off_square(base) or off_square(branch):
        raise ValueError("Both censuses must select identical squares with square-owned pop-ups")
    problems = []
    unchanged = 0
    for key, before in base.items():
        after = branch[key]
        if key not in PILLAR_PICKS:
            if before == after:
                unchanged += 1
            else:
                problems.append(f"{key} changed outside a pillar pick")
            continue
        new_hover = after["hover"]
        popups = new_hover["tooltips"]
        if (before["hover"]["tooltips"] or new_hover["tooltip_tile"] != PILLAR_TILE
                or after["contents"]["tile"] != PILLAR_TILE or after["contents"]["grid"] != "pillar"
                or len(popups) != 1 or popups[0]["panels"] != [PILLAR_PANEL]):
            problems.append(f"{key} did not add exactly the Pillar panel at {PILLAR_TILE}")
        if without_popup(before) != without_popup(after):
            problems.append(f"{key} changed evidence outside its hover pop-up")
    if problems:
        raise ValueError("\n".join(problems))
    print(f"FEL08 CENSUS DIFF PASS unchanged={unchanged} pillar_popup_only={len(PILLAR_PICKS)} off_square=0")


def compare_stacks(base_path, branch_path):
    base = json.loads(base_path.read_text())
    branch = json.loads(branch_path.read_text())
    if base.keys() != branch.keys():
        raise ValueError("The two witnesses selected different controls")
    controls = 0
    for key, before in base.items():
        after = branch[key]
        fixture, kind = key.split()
        if (fixture[:2], kind) in PILLAR_PICKS:
            if (before != {"tile": PILLAR_TILE, "mouse": [], "focus": []}
                    or after != {"tile": PILLAR_TILE, "mouse": [PILLAR_ENTRY], "focus": [PILLAR_ENTRY]}):
                raise ValueError(f"Unexpected pillar stack at {key}")
        else:
            if before != after:
                raise ValueError(f"Control stack changed at {key}")
            controls += 1
    print(f"FEL08 STACK DIFF PASS unchanged_controls={controls} exact_pillar_stacks={len(PILLAR_PICKS)}")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("base_census", type=Path)
    parser.add_argument("branch_census", type=Path)
    parser.add_argument("base_stacks", type=Path)
    parser.add_argument("branch_stacks", type=Path)
    args = parser.parse_args()
    try:
        compare_census(args.base_census, args.branch_census)
        compare_stacks(args.base_stacks, args.branch_stacks)
    except ValueError as error:
        parser.exit(1, f"FEL08 DIFF FAIL {error}\n")


if __name__ == "__main__":
    main()
