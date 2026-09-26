#!/usr/bin/env python3
"""Fork dragon authoring cases and synchronize their current production closure.

This is a reproducible case-preparation recipe for the contextual animation pass,
not a historical art builder. It copies current production PNGs and layouts, keeps
case-owned clips and source provenance, and snapshots current runtime cadence.
"""
from __future__ import annotations

import argparse
import re
import shutil
from pathlib import Path

from cutout_pipeline.cases import PROJECT, baseline, digest, fork_case, image_records, read_json, write_json

ACTORS = ("zekarion", "vyraketh", "iskaldra", "noctyrax", "vaeloryx", "tharokh")


def constant(path: Path, name: str) -> float:
    match = re.search(rf"^const {re.escape(name)}: (?:float|int) = ([0-9.]+)$", path.read_text(), re.MULTILINE)
    if match is None:
        raise ValueError(f"Cannot snapshot {name} in {path}; update the explicit timing recipe")
    return float(match[1])


def prepare(actor: str, output: Path) -> Path:
    source = PROJECT / "experiments/cutouts" / actor / "v01"
    config_path = fork_case(source, output / actor, actor + "_contextual")
    case = config_path.parent
    config = read_json(config_path)
    production = PROJECT / "assets/units" / (actor + "_cutout")
    source_hashes: dict[str, str] = {}

    def record(path: Path) -> None:
        source_hashes[str(path.relative_to(PROJECT))] = digest(path)

    def copy_image(value: str) -> str:
        path = PROJECT / value.removeprefix("res://") if value.startswith("res://") else production / value
        relative = Path("production_assets") / path.relative_to(production)
        target = case / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(path, target)
        Path(str(target) + ".import").write_text('[remap]\n\nimporter="keep"\n')
        record(path)
        return str(relative)

    for facing, destination in config["layouts"].items():
        source_layout = production / (facing + ".json")
        layout = read_json(source_layout)
        record(source_layout)
        for item in image_records(layout):
            item["file"] = copy_image(item["file"])
        if "rest_source" in layout:
            layout["rest_source"] = copy_image(layout["rest_source"])
        write_json(case / destination, layout)
    motion = PROJECT / "scripts" / (actor + "_cutout") / "motion.gd"
    renderer = motion.with_name("renderer.gd")
    shutil.copyfile(motion, case / config["motion"])
    record(motion)
    record(renderer)
    for clip, name in (("walk", "WALK_CYCLE_SECONDS"), ("idle", "IDLE_CYCLE_SECONDS")):
        config["clips"][clip]["duration"] = constant(renderer, name)
    context = PROJECT / "scripts/cutout_context.gd"
    board = PROJECT / "scripts/combat_board_view.gd"
    record(context)
    record(board)
    config["clips"]["hit"] = {"frames": 24, "duration": constant(context, "HIT_SECONDS"), "loop": False}
    death_seconds = constant(board, "ENEMY_SHADOW_DISSOLVE_FRAME_COUNT") * constant(board, "ENEMY_SHADOW_DISSOLVE_FRAME_SECONDS") * constant(context, "DEATH_SETTLE_PROGRESS")
    config["clips"]["death"] = {"frames": 36, "duration": death_seconds, "loop": False}
    config["source_baseline"] = {"kind": "current_production_synchronized_fork", "original_case": str(source.relative_to(PROJECT)), "files": source_hashes}
    write_json(config_path, config)
    baseline(case)
    return config_path


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True, help="Fresh case parent; actor directories must not exist")
    parser.add_argument("--actor", choices=ACTORS, action="append", help="Repeat to select a subset; default all six")
    args = parser.parse_args()
    for actor in args.actor or ACTORS:
        print(prepare(actor, args.output))


if __name__ == "__main__":
    main()
