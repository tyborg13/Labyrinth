"""Stage the fx-27 comparison scripts beside the normal project."""

import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
BASE = "7179c630c"
RUNTIME = "maquette_cutout_runtime/"
SCRIPTS = (
    "run_scene.gd",
    "combat_board_view.gd",
    "shot_fx.gd",
    RUNTIME + "action.gd",
    RUNTIME + "contact_actions.gd",
    RUNTIME + "effect_sockets.gd",
)


def stage(directory):
    staged = "res://" + directory.relative_to(ROOT).as_posix() + "/"
    for name in SCRIPTS:
        source = subprocess.check_output(
            ["git", "show", f"{BASE}:scripts/{name}"], cwd=ROOT, text=True,
        )
        source = source.replace("class_name CombatBoardView\n", "")
        if name == "run_scene.gd":
            # The merge cannot parse until this redundant call is removed.
            old = "hits.has(tile) or ResolvedContactBursts._terrain_lost(before, state, tile)"
            if source.count(old) != 1:
                raise ValueError("Expected the union's obsolete terrain-loss call")
            source = source.replace(old, "hits.has(tile)")
        if name.startswith(RUNTIME):
            stem = "res://scripts/" + RUNTIME
            source = source.replace('preload("', f'preload("{stem}')
            source = source.replace(stem + "res://", "res://")
        for other in SCRIPTS:
            source = source.replace("res://scripts/" + other, staged + other)
        target = directory / name
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(source)


if __name__ == "__main__":
    stage(Path(sys.argv[1]).resolve())
