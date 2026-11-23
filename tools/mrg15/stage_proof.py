#!/usr/bin/env python3
"""Stage pinned proof comparators with their matching presentation dependencies."""

import argparse
import json
from pathlib import Path
import subprocess
import sys


ROOT = Path(__file__).resolve().parents[2]
BOARD = "scripts/combat_board_view.gd"
RUN = "scripts/run_scene.gd"
SHOT = "scripts/shot_fx.gd"
REFLECT = "scripts/enemy_mechanics/reflect_view.gd"
CONTACT_BURSTS = "scripts/resolved_contact_bursts.gd"
SHOT_DATA = "data/shots.json"
OLD_OUTLINES = ("scripts/board_occlusion_silhouettes.gd", "scripts/board_unit_team_outlines.gd")
OLD_BOARD_DEPENDENCIES = (
    *OLD_OUTLINES,
    "scripts/enemy_mechanics/bramble_view.gd",
    "scripts/enemy_mechanics/icefall_view.gd",
    "scripts/dragon_spell_presentation.gd",
    "scripts/veilbound_acolyte_cutout/fx.gd",
)


def source(revision, path):
    return subprocess.check_output(["git", "show", f"{revision}:{path}"], cwd=ROOT)


def stage(directory, revision, scripts, *, shot_data=False, live=()):
    directory.mkdir(parents=True, exist_ok=True)
    resource = "res://" + directory.relative_to(ROOT).as_posix()
    redirects = {f"res://{path}": f"{resource}/{Path(path).name}" for path in scripts}
    if shot_data:
        metadata = json.loads(source(revision, SHOT_DATA))
        for sheet in metadata["sizes"]:
            art = sheet["atlas"].removeprefix("res://")
            name = Path(art).name
            (directory / name).write_bytes(source(revision, art))
            sheet["atlas"] = f"{resource}/{name}"
        (directory / "shots.json").write_text(json.dumps(metadata))
        redirects[f"res://{SHOT_DATA}"] = f"{resource}/shots.json"
    for path in (*scripts, *live):
        text = (ROOT / path).read_text() if path in live else source(revision, path).decode()
        text = text.replace("class_name CombatBoardView\n", "")
        for original, staged in redirects.items():
            text = text.replace(f'"{original}"', f'"{staged}"')
        (directory / Path(path).name).write_text(text)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("proof", choices=("gfix34", "fx20", "fx23", "fx29"))
    parser.add_argument("directory", type=Path)
    parser.add_argument("--observe", action="store_true")
    args = parser.parse_args()
    directory = args.directory.resolve()
    if args.proof == "gfix34":
        # This board predates the merged removal of four legacy painters.
        stage(directory, "90d5574ff", (BOARD, RUN, SHOT, REFLECT, *OLD_BOARD_DEPENDENCIES),
              shot_data=True, live=("tools/gfix34/probe_scene.gd",))
    elif args.proof == "fx29":
        stage(directory, "5adb3d0d1", (BOARD, SHOT, REFLECT, *OLD_BOARD_DEPENDENCIES,
              "assets/units/glacial_mirror_cutout/actions.gd"), shot_data=True)
    elif args.proof == "fx20":
        stage(directory, "f21b6ff47", (BOARD, RUN, SHOT, REFLECT, CONTACT_BURSTS, *OLD_OUTLINES,
              "scripts/enemy_strike_points.gd", "scripts/enemy_strike_trail.gd",
              "scripts/veilbound_acolyte_cutout/fx.gd"), shot_data=True)
    else:
        sys.path.insert(0, str(ROOT / "tools/fx23"))
        from stage import observe, stage as stage_fx23

        stage(directory / "before", "8f38fb277", (BOARD, RUN, SHOT, CONTACT_BURSTS, REFLECT, *OLD_OUTLINES),
              shot_data=True)
        if args.observe:
            original = directory / "before" / Path(BOARD).name
            original.write_text(observe(original.read_text()))
            stage_fx23(directory / "after", base=False, instrument=True)


if __name__ == "__main__":
    main()
