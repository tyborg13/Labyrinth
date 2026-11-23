#!/usr/bin/env python3
"""Compare pol-69 SubViewport snapshots using pol-68’s output-pixel edge check."""

import argparse
import json
from pathlib import Path


SHOT_EXCLUSIONS = {
    "combat_character_skills": {
        "SkillBranchHeader_Foresight", "SkillBranchHeader_Resolve",
        "SkillBranchHeader_Tactics", "SkillBranchHeader_Traverse", "SkillBranchHeader_Radiance",
    },
    "event_open": {"LogOverlay"},
    "event_closed": {"LogOverlay"},
    "fresh_run": {"LogOverlay", "GrimoireBadge"},
    "hero_fire_peak": set(),  # The floating number is a board draw command.
}
CAMERA_EPSILON_PX = 0.001
CAMERA_TRACKING_PARTS = {"BoardUnderlay", "CombatObjectiveHud", "CardPlayMeter", "PlayerMovementMeter"}


def snapshot(path, shots):
    manifest = json.loads(path.read_text())
    rows = {row["shot"]: row for row in manifest["shots"] if row["shot"] in shots}
    if rows.keys() != shots or any(not row["ok"] or row["capped"] for row in rows.values()):
        raise ValueError(f"{path}: missing or unsettled shot")
    return manifest, rows


def compare(left, right, shots):
    a, a_rows = snapshot(left, shots)
    b, b_rows = snapshot(right, shots)
    expected_size = "1920x1080"
    expected_scale = 1.0
    if any(r["size"] != expected_size or r["ui_scale"] != expected_scale for r in (a, b)):
        raise ValueError("Manifests use different sizes or UI scales from the proof contract")
    errors = []
    for name in sorted(shots):
        before = a_rows[name]
        after = b_rows[name]
        if before["geometry"] != after["geometry"] or before["geometry"]["path"] != "subviewport":
            errors.append(f"{name}: capture viewport metrics differ")
        first, second = before["control_rects"], after["control_rects"]
        max_delta = 0.0
        count = 0
        for path in sorted(first.keys() | second.keys()):
            if SHOT_EXCLUSIONS[name].intersection(path.split("/")):
                continue
            if path not in first or path not in second:
                errors.append(f"{name}: control present on one side only: {path}")
                continue
            count += 1
            delta = max(abs(x - y) for x, y in zip(edges(first[path]), edges(second[path])))
            max_delta = max(delta, max_delta)
            tolerance = 0.0
            if CAMERA_TRACKING_PARTS.intersection(path.split("/")):
                # The stage camera eases independently of the modal controls.
                tolerance = CAMERA_EPSILON_PX
            if delta > tolerance:
                errors.append(f"{name}: {delta:.4f} px: {path}: {first[path]} -> {second[path]}")
        if not count:
            errors.append(f"{name}: control rectangles missing")
        print(f"{name}: {count} matched paths; maximum edge delta {max_delta:.4f} px")
    for error in errors:
        print(error)
    print(f"RECT COMPARISON: {'FAIL' if errors else 'PASS'}; {len(errors)} mismatches")
    return bool(errors)


def edges(rect):
    x, y, width, height = rect
    return x, y, x + width, y + height


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("left", type=Path)
    parser.add_argument("right", type=Path)
    args = parser.parse_args()
    try:
        return compare(args.left, args.right, set(SHOT_EXCLUSIONS))
    except (KeyError, OSError, ValueError) as error:
        parser.error(str(error))


if __name__ == "__main__":
    raise SystemExit(main())
