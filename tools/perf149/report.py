#!/usr/bin/env python3
"""Compare physical input frames, checkpoint continuation and exact receipts."""
import argparse
from collections import Counter
import json
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "perf140"))
from compare import read  # noqa: E402

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "perf134"))
from measure import pixel_difference  # noqa: E402

CHECKPOINT = "post_draw:run_scene:_resolve_enemy_round:3"
OTHER_LIMIT = 33_000
PRESS_FRACTION = 0.50
CHECKPOINT_FRACTION = 0.60


def metrics(rows):
    return {
        "press": max(row["usec"] for row in rows if row["cohort"] == "press"),
        "checkpoint": max(row["spans"].get(CHECKPOINT, 0) for row in rows),
        "checkpoint_frame": max(row["usec"] for row in rows if CHECKPOINT in row["spans"]),
        "other": sum(row["usec"] > OTHER_LIMIT for row in rows
                     if row["cohort"] != "press" and CHECKPOINT not in row["spans"]),
    }


def read_rounds(path):
    return json.loads((path / "pass-rounds.json").read_text())


def compare_rounds(path):
    results = {arm: [read_rounds(take) for take in sorted(path.glob(f"{arm}[1-3]")) if take.is_dir()]
               for arm in ("A", "B")}
    if not results["A"] or len(results["A"]) != len(results["B"]):
        raise ValueError("Matched A and B takes are required.")
    paired = list(zip(results["A"], results["B"]))
    if any(set(before) != set(after) or not before for before, after in paired):
        raise ValueError("The variants must have the same nonempty encounter roster.")
    ok = True
    for kind in paired[0][0]:
        identical = all(before[kind]["receipt"] == after[kind]["receipt"] for before, after in paired)
        print(f"PERF-149 {kind} RECEIPTS: {'PASS' if identical else 'FAIL'} ({len(paired)} pairs)")
        ok &= identical
        for number, (before, after) in enumerate(paired, 1):
            a, b = metrics(before[kind]["frames"]), metrics(after[kind]["frames"])
            print(f"  pair {number}: press {a['press']/1000:.3f} -> {b['press']/1000:.3f} ms, "
                  f"checkpoint span {a['checkpoint']/1000:.3f} -> {b['checkpoint']/1000:.3f} ms, "
                  f"checkpoint frame {a['checkpoint_frame']/1000:.3f} -> {b['checkpoint_frame']/1000:.3f} ms, "
                  f"other >33 ms {a['other']} -> {b['other']}")
        arms = [[metrics(take[kind]["frames"]) for take in result] for result in results.values()]
        a, b = ({key: (sum if key == "other" else max)(take[key] for take in arm)
                 for key in arm[0]} for arm in arms)
        checks = {
            "press max": (b["press"] <= PRESS_FRACTION * a["press"], a["press"], b["press"]),
            "checkpoint span max": (b["checkpoint"] <= CHECKPOINT_FRACTION * a["checkpoint"], a["checkpoint"], b["checkpoint"]),
            "other frames over 33 ms": (b["other"] <= a["other"], a["other"], b["other"]),
        }
        if kind.endswith("-accept"):
            checks.pop("press max")
        for label, (passed, first, second) in checks.items():
            unit = "" if label.startswith("other") else " usec"
            print(f"PERF-149 {kind} {label}: {'PASS' if passed else 'FAIL'} ({first} -> {second}{unit})")
            ok &= passed
    return ok


def compare_identity(path):
    before, after = (read(path / name, "receipts") for name in ("A1", "B1"))
    differences = sorted(key for key in before.keys() | after.keys() if before.get(key) != after.get(key))
    forecasts = sum("steps" in row for row in before.values())
    print(f"PERF-140 IDENTITY: {'FAIL' if differences else 'PASS'} "
          f"({forecasts} forecasts, {len(before) - forecasts} badge receipts; {len(differences)} differences)")
    for key in differences:
        print(key)
    return not differences


CAPTURE_FIXTURES = ("normal", "tharokh")


def compare_captures(path):
    files = {}
    ok = True
    for kind in CAPTURE_FIXTURES:
        witnesses = []
        images = []
        for arm in ("A", "B"):
            stem = path / f"{arm}-{kind}" / f"{kind}-pass-ready"
            witness = json.loads(stem.with_suffix(".json").read_text())
            if (witness["fixture"] != kind or ("tharokh" in witness["enemies"]) != (kind == "tharokh")
                    or not witness["enemies"] or witness["size"] != [1920, 1080]
                    or witness["ui_scale"] != 1.0 or witness["fps"] != 60 or not witness["movie"]):
                raise ValueError(f"Unexpected capture witness: {stem}")
            witnesses.append(witness)
            images.append(stem.with_suffix(".png"))
            files[arm, kind] = images[-1]
        diff = pixel_difference(*images)
        matches = witnesses[0] == witnesses[1] and diff["different_pixels"] == 0
        print(f"PERF-149 CAPTURE {kind}: {'PASS' if matches else 'FAIL'} "
              f"({diff['different_pixels']} differing pixels, frame {witnesses[0]['frame']}, bbox {diff['bbox']})")
        ok &= matches
    for arm in ("A", "B"):
        distinct = pixel_difference(*(files[arm, kind] for kind in CAPTURE_FIXTURES))["different_pixels"] > 0
        print(f"PERF-149 CAPTURE {arm} fixture separation: {'PASS' if distinct else 'FAIL'}")
        ok &= distinct
    return ok


def census(path):
    rows = []
    with path.open() as stream:
        for line in stream:
            row = json.loads(line)
            context = row["context"]
            if (context["screen"] == "combat" and "Xbox Y," in context["action"]
                    and "demo-7-normal-warm-on-" in row["run"] and row["game_ms"] > 50):
                rows.append(row)
    spans = Counter(label for row in rows for label in row["hitch_phase_times_us"])
    print(f"PERF-149 CENSUS: {len(rows)} Y-labelled frames >50 ms, max {max(r['game_ms'] for r in rows):.3f} ms")
    for label, count in spans.most_common():
        peak = max(row["hitch_phase_times_us"].get(label, 0) for row in rows)
        print(f"  {label}: {count} frames, max {peak/1000:.3f} ms")
    return bool(rows)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("path", type=Path)
    parser.add_argument("--mode", choices=("pairs", "identity", "census", "captures"), default="pairs")
    args = parser.parse_args()
    check = {"pairs": compare_rounds, "identity": compare_identity, "census": census, "captures": compare_captures}[args.mode]
    raise SystemExit(0 if check(args.path) else 1)
