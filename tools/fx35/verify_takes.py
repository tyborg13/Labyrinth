"""Check the headless before/after contact plans and their selected Shadow rows."""

import json
from pathlib import Path
import sys

SAMPLE_OFFSETS = (0, 6, 14, 22)
CLIP_FRAMES = 240
EXPECTED_PAIRS = {"area_ranged": (1, 2), "closing_shade": (1, 0)}


def read_take(directory, case):
    report = json.loads((directory / case / "take.json").read_text())
    beat, = report["beats"]
    contact = beat["contact"]
    samples = [report["columns"][str(index)] for index in range(len(SAMPLE_OFFSETS))]
    if contact < 0 or samples != [contact + offset for offset in SAMPLE_OFFSETS]:
        raise ValueError(f"{directory}/{case}: missed a contact sample")
    if report["clip_frames"] != CLIP_FRAMES or not 0 <= report["done"] < CLIP_FRAMES:
        raise ValueError(f"{directory}/{case}: incomplete game-speed clip")
    rows = list(beat["pairs"].values())
    hit_count, floor_count = EXPECTED_PAIRS[case]
    counts = {f"shadow_{kind}_{depth}": count for kind, count in (("hit", hit_count), ("floor", floor_count))
              for depth in ("rear", "front")}
    if len(rows) != 2 * (hit_count + floor_count) or any(
        sum(pair["row"] == row and pair["first_visible"] >= 0 for pair in rows) != count
        for row, count in counts.items()
    ):
        raise ValueError(f"{directory}/{case}: unexpected visible Shadow rows")
    if beat["losses"]["hp"] <= 0 or len(beat["tiles"]) != hit_count + floor_count or beat["hidden"]:
        raise ValueError(f"{directory}/{case}: expected hero Health loss and the specified visible tiles")
    beat["pairs"] = sorted(rows, key=lambda pair: (pair["tile"], pair["row"]))
    return report


def main(output):
    for case in EXPECTED_PAIRS:
        before = read_take(output / "before", case)
        after = read_take(output / "after", case)
        if before != after:
            raise ValueError(f"{case}: before and after contact plans differ")
        contact = after["beats"][0]["contact"]
        print(f"FX-35 TAKE PLAN: {case} contact={contact} samples={list(after['columns'].values())} "
              f"clip={after['clip_frames']} frames; before/after identical")
    print(f"FX-35 NATIVE DRY RUN: PASS ({len(EXPECTED_PAIRS)} before/after pairs) {output}")


if __name__ == "__main__":
    main(Path(sys.argv[1]))
