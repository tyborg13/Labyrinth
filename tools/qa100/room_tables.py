#!/usr/bin/env python3
"""Write room and node-type tables from completed lifetime_hunt traces."""

import argparse
import csv
import json
from pathlib import Path


SEEDS = (96101, 96109)
SAMPLES = {"lifetime_room", "lifetime_finish", "lifetime_teardown"}
FIELDS = (
    "event", "seed", "section", "room", "room_kind", "mode", "decision",
    "attached", "orphans", "objects", "resources", "static_bytes",
)
RETAINED_FIELDS = (
    "asset_textures", "asset_original_textures", "asset_flipped_textures",
    "asset_bounds", "asset_alpha_polygons", "asset_audio", "asset_audio_loops",
    "board_tile_layers", "aim_canvas_records", "aim_live_canvases", "aim_visible_canvases",
    "hand_pool", "pile_pool", "pile_warm_limit", "pile_is_open",
)


def read_samples(directory: Path) -> list[dict]:
    samples = []
    finish = None
    with (directory / "trace.jsonl").open() as trace:
        for line in trace:
            entry = json.loads(line)
            event, data = entry["event"], entry["data"]
            if event in SAMPLES:
                samples.append({"event": event, **data})
            elif event == "finish":
                finish = data

    rooms = [row for row in samples if row["event"] == "lifetime_room"]
    if (
        finish is None or finish["outcome"] not in ("victory", "defeat", "embrace")
        or finish["context"]["section"] != 5
        or len(rooms) != len(finish["room_samples"])
        or [row["event"] for row in samples[-2:]] != ["lifetime_finish", "lifetime_teardown"]
    ):
        raise ValueError(f"{directory} has no complete section-5 lifetime trace")
    for row in samples:
        for total, histogram in (("attached", "attached_types"), ("orphans", "orphan_types")):
            if sum(row[histogram].values()) != row[total]:
                raise ValueError(f"{directory} decision {row['decision']}: {total} census mismatch")
    print(
        f"QA100 TRACE seed={finish['seed']} outcome={finish['outcome']} "
        f"section={finish['context']['section']} decisions={finish['decisions']} "
        f"rooms={len(rooms)} teardown_orphans={samples[-1]['orphans']}"
    )
    return samples


def write_tables(directory: Path, samples: list[dict]) -> None:
    with (directory / "rooms.csv").open("w", newline="") as file:
        writer = csv.DictWriter(file, fieldnames=FIELDS + RETAINED_FIELDS, extrasaction="ignore")
        writer.writeheader()
        writer.writerows({**row, **row.get("retained_counts", {})} for row in samples)
    with (directory / "node_types.csv").open("w", newline="") as file:
        writer = csv.writer(file)
        writer.writerow([*FIELDS[:7], "lifetime", "type", "count"])
        for row in samples:
            context = [row[field] for field in FIELDS[:7]]
            for lifetime in ("attached", "orphan"):
                for kind, count in sorted(row[f"{lifetime}_types"].items()):
                    writer.writerow([*context, lifetime, kind, count])


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("phase_directory", type=Path)
    args = parser.parse_args()
    for seed in SEEDS:
        directory = args.phase_directory / f"seed-{seed}"
        write_tables(directory, read_samples(directory))


if __name__ == "__main__":
    main()
