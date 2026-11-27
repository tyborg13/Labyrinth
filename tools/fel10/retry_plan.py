#!/usr/bin/env python3
"""Package the next later archived turn per effect for native capture retry."""
from __future__ import annotations

import argparse
from collections import defaultdict
from pathlib import Path
import json
import re
import shutil

from census import CHECKPOINT_FILES, checkpoint_key, json_write, read_lines

TILE = re.compile(r"^\((-?\d+), (-?\d+)\)$")


def tile(value: str) -> list[int]:
    match = TILE.fullmatch(value)
    if match is None:
        raise ValueError(f"invalid hunt tile {value!r}")
    return list(map(int, match.groups()))


def action(row: dict) -> dict:
    copied = {k: v for k, v in row.items() if k not in ("context", "decision")}
    if "tile" in copied:
        copied["tile"] = tile(copied["tile"])
    if copied.get("method") == "_on_board_tile_clicked":
        copied["args"] = [tile(copied["args"][0])]
    if copied["kind"] == "dialogue":
        copied.pop("args", None)
    if "path" in copied:
        # Keep the text/signal so fel-01's control offer can be found after Continue.
        copied["control_path"] = copied["path"].removeprefix("/root/RunScene/")
    return copied


def archive(campaigns: list[Path], wanted: set[str]) -> dict:
    candidates = defaultdict(list)
    for campaign in campaigns:
        for seed in sorted(campaign.glob("seed-*")):
            observed = read_lines(seed / "fel10-turns.jsonl")
            inputs = {event["data"]["decision"]: event["data"] for event in read_lines(seed / "trace.jsonl")
                      if event["event"] == "decision"}
            first = {(row["checkpoint"], row["id"]): row for event in observed
                     if event["event"] == "first" and (row := event["data"])["id"] in wanted}
            turns = [event["data"] for event in observed if event["event"] == "turn"]
            for index, turn in enumerate(turns, 1):
                name = f"turn-{index:06d}"
                source = seed / "witnesses" / name
                if not (source / "combat.witness").is_file():
                    continue
                start = turn["decision"] + 1
                for id in wanted.intersection(turn["effects"]):
                    evidence = first.get((name, id), {})
                    count = evidence.get("inputs", turn["inputs"])
                    prefix = [action(inputs[n]) for n in range(start, start + count)]
                    continuation = []
                    if id == "light_placement":
                        # Tile movement and a disappearing/reappearing source
                        # are not placement. The archived Flash Powder retry
                        # has an actual Illuminate input and a recorded exit.
                        if not any(row["kind"] == "illuminate" for row in prefix):
                            continue
                        n = start + count
                        while n in inputs:
                            context = inputs[n]["context"]
                            if context["mode"] != "combat" or context["room"] != turn["room"]:
                                break
                            continuation.append(action(inputs[n]))
                            n += 1
                    stamp = evidence.get("observed_at", (source / "run.save").stat().st_mtime)
                    key = checkpoint_key(campaign.name, {**turn, "checkpoint": name})
                    candidates[id].append({
                        "id": id, "checkpoint": key, "inputs": count, "observed_at": stamp,
                        "source": source, "prefix": prefix, "continuation": continuation,
                    })
    return candidates


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--primary", type=Path, required=True)
    parser.add_argument("--campaign", type=Path, action="append", required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    primary = json.loads((args.primary / "manifest.json").read_text())
    candidates = archive(args.campaign, {row["id"] for row in primary})
    args.output.mkdir()
    (args.output / ".gdignore").touch()
    plan = []
    for original in primary:
        id = original["id"]
        next_turns = sorted((row for row in candidates[id] if row["checkpoint"] != original["checkpoint"]
                             and row["observed_at"] > original["observed_at"]),
                            key=lambda row: (row["observed_at"], row["checkpoint"]))
        if not next_turns:
            continue
        row = next_turns[0]
        source = row.pop("source")
        dest = args.output / row["checkpoint"]
        if not dest.exists():
            dest.mkdir()
            for filename in CHECKPOINT_FILES:
                shutil.copyfile(source / filename, dest / filename)
        stored_prefix = source / f"{id}.inputs"
        if stored_prefix.is_file():
            shutil.copyfile(stored_prefix, dest / stored_prefix.name)
            row.pop("prefix")
        row.update(family=original["family"], path=original["path"])
        plan.append(row)
    json_write(args.output / "manifest.json", plan)
    print(f"FEL10 RETRY PLAN cases={len(plan)} without_later_checkpoint={len(primary) - len(plan)}")


if __name__ == "__main__":
    main()
