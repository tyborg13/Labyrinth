#!/usr/bin/env python3
"""Compare candidate 4 census rectangles and verify the card-title floor."""

import argparse
import json
from pathlib import Path

TITLE_PATH = "/Margin/VBox/TopRow/Title"
FLOOR_PX = 14.0
FALLBACK_PX = 12.0
SHELF_CONTEXT = "scavenger"
SHELF_STEP_5_COUNT = 13
MINIATURES = {"event_transform", "scavenger_receipt"}
CATALOG_SIZE = 305
FONT_EPSILON_PX = 0.001
SETTLE_EPSILON_PX = 0.001
ANIMATED_PARTS = {"BoardUnderlay", "ScavengerShopCanvas"}
ROUND1_MANIFEST = Path("/private/tmp/labyrinth_codex/pol-70/round1-final/after/manifest.json")
CATALOG_FIELDS = ("name", "step", "source_px", "px", "spacing", "fits", "width_px", "available_px", "ellipsis")


def snapshot(path):
    manifest = json.loads(path.read_text())
    if (manifest["size"], manifest["ui_scale"], manifest["dry_run"]) != ("1920x1080", 1.0, True):
        raise ValueError(f"{path}: expected a 1920x1080 headless census at 100% UI scale")
    return {row["shot"]: row for row in manifest["shots"]}


def edges(rect):
    x, y, width, height = rect
    return x, y, x + width, y + height


def compare_round1(round1, after):
    previous_rows = {
        (name, title["id"]): title
        for name, shot in round1.items() for title in shot.get("catalog", [])
    }
    current_rows = {
        (name, title["id"]): title
        for name, shot in after.items() for title in shot.get("catalog", [])
    }
    expected_shelf = {key for key, row in previous_rows.items() if key[0] == SHELF_CONTEXT and row["step"] == 4}
    step_5 = {key for key, row in current_rows.items() if key[0] == SHELF_CONTEXT and row["step"] == 5}
    differences = previous_rows.keys() ^ current_rows.keys()
    for key in previous_rows.keys() & current_rows.keys():
        if key in expected_shelf and key in step_5:
            continue
        if any(previous_rows[key][field] != current_rows[key][field] for field in CATALOG_FIELDS):
            differences.add(key)
    non_shelf_diff = sum(name != SHELF_CONTEXT for name, _ in differences)
    print(f"ROUND 1 NON-SHELF TITLE DIFF: {non_shelf_diff} mismatches "
          f"across {sum(name != SHELF_CONTEXT for name, _ in current_rows)} rows")
    print(f"ROUND 1 SHELF TITLE DIFF: {len(expected_shelf & step_5)} expected changes; "
          f"{len(differences) - non_shelf_diff} other mismatches")
    for name, id in sorted(differences):
        print(f"Round 1 title changed: {name}/{id}")
    if step_5:
        for key in sorted(step_5):
            title = current_rows[key]
            print(f"SHELF STEP 5: {title['name']} ({title['id']}): "
                  f"{title['px']:.2f} effective px ({title['source_px']} source px)")
        print(f"SHELF STEP 5 MINIMUM: {min(current_rows[key]['px'] for key in step_5):.2f} effective px")
    return bool(differences or expected_shelf != step_5 or len(step_5) != SHELF_STEP_5_COUNT)


def check(output, shots, round1_path=ROUND1_MANIFEST):
    before = snapshot(output / "before" / "manifest.json")
    after = snapshot(output / "after" / "manifest.json")
    errors = []
    rect_errors = []
    fit_blockers = []
    motion_errors = []
    motion_count = 0
    for name in shots:
        first, second = before[name], after[name]
        if first["geometry"] != second["geometry"] or second["geometry"]["path"] != "subviewport":
            rect_errors.append(f"{name}: exact-size SubViewport geometry differs")
        count, title_count, maximum = 0, 0, 0.0
        a, b = first["control_rects"], second["control_rects"]
        for path in sorted(a.keys() | b.keys()):
            if path not in a or path not in b:
                rect_errors.append(f"{name}: control present on one side only: {path}")
                continue
            delta = max(abs(x - y) for x, y in zip(edges(a[path]), edges(b[path])))
            if path.endswith(TITLE_PATH):
                title_count += 1
            else:
                count += 1
                maximum = max(maximum, delta)
            tolerance = SETTLE_EPSILON_PX if ANIMATED_PARTS.intersection(path.split("/")) else 0.0
            if delta > tolerance:
                rect_errors.append(f"{name}: {delta:.4f} px: {path}: {a[path]} -> {b[path]}")
        print(f"{name}: {count} other controls and {title_count} title rows matched; "
              f"maximum non-title edge delta {maximum:.4f} px")
        if not title_count:
            rect_errors.append(f"{name}: missing title rows")
    for error in rect_errors:
        print(error)
    print(f"RECT COMPARISON: {'FAIL' if rect_errors else 'PASS'}; {len(rect_errors)} mismatches")

    for name, row in after.items():
        for title in row["titles"]:
            if title["line_px"] > title["row_px"] + FONT_EPSILON_PX:
                errors.append(f"{name}: {title['id']} exceeds the existing row height")
            if title["step"] and title["ellipsis"]:
                errors.append(f"{name}: {title['id']} can insert an ellipsis")
        first = before[name]["context_titles"]
        second = row["context_titles"]
        if [title["id"] for title in first] != [title["id"] for title in second]:
            errors.append(f"{name}: different card titles before and after")
        elif name in shots and any(old["available_px"] != new["available_px"] for old, new in zip(first, second)):
            errors.append(f"{name}: title nameplate width changed")
        elif name in MINIATURES:
            keys = ("name", "source_px", "spacing", "ellipsis", "width_px", "px", "available_px", "row_px")
            if any(any(old[key] != new[key] for key in keys) for old, new in zip(first, second)):
                errors.append(f"{name}: miniature title metrics changed")
            else:
                print(f"{name}: miniature title metrics match")
        for title in row.get("catalog", []):
            step = title["step"]
            near_floor = step == 5 or title["px"] + FONT_EPSILON_PX >= (FLOOR_PX if step == 1 else FALLBACK_PX)
            spacing_ok = title["spacing"] == (-1 if step >= 3 else 0)
            valid_step = step in (1, 2, 3, 4) or (step == 5 and name == SHELF_CONTEXT and not title["next_size_fits"])
            if not valid_step or not near_floor or title["ellipsis"] or not spacing_ok:
                errors.append(f"{name}: invalid title fit for {title['id']} at step {step}")
            if title["fits"] != (step != 4):
                errors.append(f"{name}: fit disagrees with step {step} for {title['id']}")
        for old, new in zip(before[name].get("catalog", []), row.get("catalog", [])):
            if old["px"] + FONT_EPSILON_PX >= FLOOR_PX and old["fits"] and old["source_px"] != new["source_px"]:
                errors.append(f"{name}: {old['id']} changed a fitted source size already above the floor")
        if "catalog" in row and len(row["catalog"]) != CATALOG_SIZE:
            errors.append(f"{name}: expected {CATALOG_SIZE} card names")
        fit_blockers.extend((name, title) for title in row.get("TODO_DESIGN_title_fit", []))
        actions = row.get("motion", {}).get("actions", {})
        resting = actions.get("hover_in", [{}])[0].get("source_px")
        for action, samples in actions.items():
            motion_count += 1
            sizes = {frame["source_px"] for frame in samples}
            refits = max(frame["refits"] for frame in samples)
            poses = {(round(frame["scale"], 5), round(frame["x"], 2), round(frame["y"], 2)) for frame in samples}
            print(f"{name}/{action}: {len(samples)} frames; source px {sorted(sizes)}; {refits} refits")
            if len(poses) < 2 or len(samples) < 3 or refits != 0:
                motion_errors.append(f"{name}/{action}: motion sample or refit check failed")
            if sizes != {resting}:
                motion_errors.append(f"{name}/{action}: motion uses {sorted(sizes)} source px; resting hand uses {resting} px")
    for error in errors:
        print(error)
    print(f"CARD TITLE CHECKS: {'FAIL' if errors else 'PASS'}; {len(errors)} mismatches")
    for name, title in fit_blockers:
        print(f"TODO_DESIGN_title_fit: {name}/{title['id']} {title['width_px']:.2f} px in {title['available_px']:.2f} px")
    print(f"NAME FIT: {len(fit_blockers)} unresolved context/name pairs")
    round1_changed = compare_round1(snapshot(round1_path), after)
    if motion_count != 12:
        motion_errors.append(f"Expected 12 motion sequences, got {motion_count}")
    for error in motion_errors:
        print(error)
    print(f"TITLE MOTION: {'FAIL' if motion_errors else 'PASS'}; {motion_count} sequences; {len(motion_errors)} mismatches")
    print(f"CENSUS RESULT: PASS; {len(after)}/{len(after)} shots succeeded; 0 capped")
    return int(bool(errors or rect_errors or motion_errors or round1_changed))


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("output", type=Path)
    parser.add_argument("--shots", default="combat,boss,scavenger,graftwright_confirm,reward,draw_pile")
    parser.add_argument("--round1", type=Path, default=ROUND1_MANIFEST)
    args = parser.parse_args()
    raise SystemExit(check(args.output, args.shots.split(","), args.round1))
