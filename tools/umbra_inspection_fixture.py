#!/usr/bin/env python3
"""Build or launch named Umbra and Radiance inspection combats."""

from __future__ import annotations

import argparse
from dataclasses import dataclass
from pathlib import Path
import re
import subprocess
import sys


TASK_ID = "implement-umbra-fog-radiance-cards-and-inspection-fixtures"
STAGE_HAND = "lantern_shot,dawnstep,prism_sight,daybreak,brace"
ENEMIES = "warden,harrier,lightning_wisp,acolyte,crawler,grave_surgeon"
ENEMY_POSITIONS = "3:4,2:2,4:3,6:4,7:4,7:3"


@dataclass(frozen=True)
class Fixture:
    stage: str
    hand: str
    summary: str


FIXTURES: dict[str, Fixture] = {
    **{
        f"stage_{stage}": Fixture(
            stage=stage,
            hand=STAGE_HAND,
            summary=f"Continue opens the {stage.capitalize()} Umbra combat with enemies at distances 1 through 6.",
        )
        for stage in ("clear", "fringe", "advancing", "pressing", "deep", "heart", "eclipse")
    },
    "card_lantern_shot": Fixture("deep", "lantern_shot,brace,threaded_path", "Continue opens a Deep Umbra combat with Lantern Shot ready."),
    "card_guiding_flare": Fixture("deep", "guiding_flare,brace,threaded_path", "Continue opens a Deep Umbra combat with Guiding Flare ready."),
    "card_dawnstep": Fixture("deep", "dawnstep,brace,threaded_path", "Continue opens a Deep Umbra combat with Dawnstep ready."),
    "card_prism_sight": Fixture("heart", "prism_sight,brace,threaded_path", "Continue opens a Heart Umbra combat with Prism Sight ready."),
    "card_storm_beacon": Fixture("deep", "storm_beacon,brace,threaded_path", "Continue opens a Deep Umbra combat with Storm Beacon ready."),
    "card_glowstone_ward": Fixture("heart", "glowstone_ward,brace,threaded_path", "Continue opens a Heart Umbra combat with Glowstone Ward ready."),
    "card_daybreak": Fixture("eclipse", "daybreak,brace,threaded_path", "Continue opens an Eclipse Umbra combat with Daybreak ready."),
}


def slugify(value: str) -> str:
    slug = re.sub(r"[^A-Za-z0-9._-]+", "-", value.strip().lower())
    return re.sub(r"-{2,}", "-", slug).strip("-._") or "umbra-inspection"


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("fixture", nargs="?", default="stage_deep", choices=FIXTURES)
    parser.add_argument("--project", default=".")
    parser.add_argument("--task-id", default=TASK_ID)
    parser.add_argument("--build-all", action="store_true", help="Generate every named fixture namespace.")
    parser.add_argument("--list", action="store_true", help="List fixture names and exit.")
    parser.add_argument("--launch", action="store_true", help="Launch the selected fixture after generating it.")
    parser.add_argument("--dry-run", action="store_true")
    return parser


def fixture_command(project: Path, task_id: str, name: str, dry_run: bool) -> list[str]:
    fixture = FIXTURES[name]
    run_id = slugify(f"{task_id}-umbra-{name}")
    command = [
        sys.executable,
        "tools/inspection_fixture.py",
        "--project",
        str(project),
        "--task-id",
        task_id,
        "--run-id",
        run_id,
        "--scenario",
        "combat",
        "--umbra-stage",
        fixture.stage,
        "--player-position",
        "2:4",
        "--enemy-types",
        ENEMIES,
        "--enemy-positions",
        ENEMY_POSITIONS,
        "--hand",
        fixture.hand,
        "--draw",
        "brace,threaded_path,quick_stab",
        "--elemental-intensity",
        "fire=3,ice=3,lightning=3,air=3,earth=3",
        "--notice",
        f"Umbra inspection: {name.replace('_', ' ')}.",
        "--summary",
        fixture.summary,
    ]
    if dry_run:
        command.append("--dry-run")
    return command


def launch_command(project: Path, task_id: str, name: str) -> list[str]:
    run_id = slugify(f"{task_id}-umbra-{name}")
    return [
        sys.executable,
        "tools/godot_task_runner.py",
        "--project",
        str(project),
        "--task-id",
        task_id,
        "--run-id",
        run_id,
        "--",
        "godot",
        "--path",
        ".",
    ]


def main() -> int:
    args = build_parser().parse_args()
    project = Path(args.project).expanduser().resolve()
    if args.list:
        for name, fixture in FIXTURES.items():
            print(f"{name:24} {fixture.stage:10} {fixture.summary}")
        return 0
    names = list(FIXTURES) if args.build_all else [args.fixture]
    for name in names:
        print(f"\nBuilding Umbra fixture: {name}")
        result = subprocess.run(fixture_command(project, args.task_id, name, args.dry_run), cwd=project)
        if result.returncode != 0:
            return result.returncode
    selected = args.fixture
    print("\nSelected launch command:")
    print("  " + " ".join(subprocess.list2cmdline([part]) for part in launch_command(project, args.task_id, selected)))
    if args.launch and not args.dry_run:
        return subprocess.run(launch_command(project, args.task_id, selected), cwd=project).returncode
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
