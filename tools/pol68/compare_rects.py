#!/usr/bin/env python3
"""Check census snapshots in output pixels."""

import argparse
import json
from pathlib import Path


BADGE_PARTS = {"GrimoireBadge", "LoadoutBadge"}
BOARD_SETTLE_EPSILON_PX = 0.001


def snapshot(path, shots):
    manifest = json.loads(path.read_text())
    rows = {row["shot"]: row for row in manifest["shots"] if row["shot"] in shots}
    if rows.keys() != shots or any(not row["ok"] or row["capped"] for row in rows.values()):
        raise ValueError(f"{path}: missing or unsettled shot")
    return manifest, rows


def compare(left, right, shots, native):
    a, a_rows = snapshot(left, shots)
    b, b_rows = snapshot(right, shots)
    expected_size = "1280x800" if native else "1920x1080"
    expected_scale = 1.15 if native else 1.0
    if any(r["size"] != expected_size or r["ui_scale"] != expected_scale for r in (a, b)):
        raise ValueError("Manifests use different sizes or UI scales from the proof contract")
    if native and (not a["dry_run"] or b["dry_run"]):
        raise ValueError("Native comparison requires headless followed by native")
    errors = []
    for name in sorted(shots):
        before = a_rows[name]
        after = b_rows[name]
        if native and not after.get("capture"):
            errors.append(f"{name}: native capture missing")
        if before["geometry"] != after["geometry"] or before["geometry"]["path"] != "shipping_window":
            errors.append(f"{name}: shipping viewport metrics differ")
        first, second = before["control_rects"], after["control_rects"]
        max_delta = 0.0
        count = 0
        for path in sorted(first.keys() | second.keys()):
            if not native and BADGE_PARTS.intersection(path.split("/")):
                continue
            if path not in first or path not in second:
                errors.append(f"{name}: control present on one side only: {path}")
                continue
            count += 1
            delta = max(abs(x - y) for x, y in zip(edges(first[path]), edges(second[path])))
            max_delta = max(delta, max_delta)
            tolerance = 1.0 if native else 0.0
            if not native and "BoardUnderlay" in path.split("/"):
                # The stage camera eases independently of the modal controls.
                tolerance = BOARD_SETTLE_EPSILON_PX
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
    parser.add_argument("--shots", required=True, help="Comma-separated shot names.")
    parser.add_argument("--native", action="store_true", help="Check Deck headless against Deck native within 1 px.")
    args = parser.parse_args()
    try:
        return compare(args.left, args.right, set(args.shots.split(",")), args.native)
    except (KeyError, OSError, ValueError) as error:
        parser.error(str(error))


if __name__ == "__main__":
    raise SystemExit(main())
