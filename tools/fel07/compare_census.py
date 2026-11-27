#!/usr/bin/env python3
"""Compare the fel-06 base observations with the fel-07 branch observations."""

import argparse
import json
from pathlib import Path
import re

EXPECTED = {
    ("02", "A"): ("(4, 5)", "FIRE"),
    ("04", "A"): ("(4, 5)", "FIRE"),
    ("07", "D"): ("(2, 6)", "LOB SLAG"),
    ("10", "A"): ("(3, 6)", "FIRE"),
    ("12", "A"): ("(6, 4)", "FIRE"),
}
POPUP_FIELDS = {"tooltips", "tooltip_tile", "lob_tooltip_owner", "icefall_tooltip_owner"}
NODE_SERIAL = re.compile(r"(?<=@)\d+(?=/|$)")


def stable_node_names(entries):
    serials = sorted({int(serial) for path in entries for serial in NODE_SERIAL.findall(path)})
    ranks = {serial: rank for rank, serial in enumerate(serials)}
    return {
        NODE_SERIAL.sub(lambda match: str(ranks[int(match[0])]), path): value
        for path, value in entries.items()
    }


def stable_sample(sample):
    # Godot appends a process-local serial to generated node names. Preserve
    # hierarchy, sibling order, and all observed values while comparing runs.
    sample["hovered_control"] = NODE_SERIAL.sub("0", sample["hovered_control"])
    for phase in ("rest", "hover"):
        evidence = sample[phase]
        for field in ("controls", "rail"):
            evidence[field] = stable_node_names(evidence[field])
        for popup in evidence["tooltips"]:
            popup["owner"] = NODE_SERIAL.sub("0", popup["owner"])
    return sample


def samples(path, mode="headless"):
    data = json.loads(path.read_text())
    if data["mode"] != mode or len(data["fixtures"]) != 12:
        raise ValueError(f"Expected a {mode} run with 12 fixtures")
    result = {}
    for fixture in data["fixtures"]:
        for sample in fixture["samples"]:
            key = fixture["id"][:2], sample["contents"]["category"]
            if key in result:
                raise ValueError(f"Duplicate sample {key}")
            result[key] = stable_sample(sample)
    if len(result) != 46:
        raise ValueError("Expected 46 hover samples")
    return result


def off_square(observations):
    return {
        key for key, sample in observations.items()
        if sample["hover"]["tooltips"] and sample["hover"]["tooltip_tile"] != sample["contents"]["tile"]
    }


def first_line(sample):
    for popup in sample["hover"]["tooltips"]:
        for panel in popup["panels"]:
            if panel["text"]:
                return panel["text"][0].splitlines()[0]
    return ""


def without_popup(sample):
    return {
        **sample,
        "hover": {key: value for key, value in sample["hover"].items() if key not in POPUP_FIELDS},
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("base", type=Path)
    parser.add_argument("branch", type=Path)
    args = parser.parse_args()
    base, branch = samples(args.base), samples(args.branch)
    if base.keys() != branch.keys():
        parser.exit(1, "Base and branch selected different census samples\n")
    base_off, branch_off = off_square(base), off_square(branch)
    print(f"FEL07 CENSUS base off_square={len(base_off)} branch off_square={len(branch_off)}")
    problems = []
    if base_off != EXPECTED.keys() or branch_off:
        problems.append(f"Off-square sample IDs: base={sorted(base_off)} branch={sorted(branch_off)}")
    unchanged = 0
    for key, before in base.items():
        after = branch[key]
        if key not in EXPECTED:
            if before == after:
                unchanged += 1
            else:
                fields = [field for field in before if before[field] != after[field]]
                problems.append(f"{key} unexpected change in {', '.join(fields)}")
            continue
        tile, expected = EXPECTED[key]
        actual = first_line(after)
        print(f"FEL07 POPUP {key[0]} {key[1]} {tile}: {actual or '(none)'}")
        allowed = {expected, ""} if key == ("07", "D") else {expected}
        if actual not in allowed or after["contents"]["tile"] != tile:
            problems.append(f"{key} expected {expected} at {tile}")
        if without_popup(before) != without_popup(after):
            problems.append(f"{key} changed evidence outside the hover popup")
    if problems:
        parser.exit(1, "\n".join(problems) + "\n")
    print(f"FEL07 DIFF PASS unchanged={unchanged} popup_only={len(EXPECTED)}")


if __name__ == "__main__":
    main()
