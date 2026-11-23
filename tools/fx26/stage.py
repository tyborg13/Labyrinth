"""Stage the fx-26 baseline and optionally observe procedural board draw calls."""

import argparse
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[2]
BASE = "0923853479e021c8491f9d72c2cae16af2b10203"
BOARD = "combat_board_view.gd"
SCRIPTS = (BOARD, "run_scene.gd", "shot_fx.gd", "resolved_contact_bursts.gd")
TRAVEL_PAINTERS = (
    "_draw_ice_shard_travel", "_draw_air_gust_travel", "_draw_fireball_travel_composite",
    "_draw_lightning_travel",
)


def marker(key):
    return f'Engine.set_meta(&"fx26_{key}", true)'


def observe(source):
    for name in (*TRAVEL_PAINTERS, "_draw_elemental_release"):
        offset = source.index("\n", source.index(f"func {name}("))
        key = "release" if name == "_draw_elemental_release" else "travel"
        source = source[:offset] + "\n\t" + marker(key) + source[offset:]
    sites = {
        '\t\tElementalSpellFx.ground(self, "earth", point,': ("\t\t", "travel"),
        "\t\t\tvar hop: Callable =": ("\t\t\t", "hop_arc"),
        "\tvar warmup_progress: float =": ("\t", "generic_travel"),
    }
    for anchor, (indent, key) in sites.items():
        start = source.index("func _draw_ranged_projectile_effect(") if key == "generic_travel" else 0
        offset = source.index(anchor, start)
        source = source[:offset] + indent + marker(key) + "\n" + source[offset:]
    return source


def stage(directory, before, instrument):
    directory.mkdir(parents=True)
    path = "res://" + directory.relative_to(ROOT).as_posix()
    for name in SCRIPTS:
        original = f"scripts/{name}"
        if before:
            source = subprocess.check_output(["git", "show", f"{BASE}:{original}"], cwd=ROOT, text=True)
        else:
            source = (ROOT / original).read_text()
        source = source.replace("class_name CombatBoardView\n", "")
        for other in SCRIPTS:
            source = source.replace(f"res://scripts/{other}", f"{path}/{other}")
        if name == BOARD and instrument:
            source = observe(source)
        (directory / name).write_text(source)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("directory", type=Path)
    parser.add_argument("--observe", action="store_true")
    args = parser.parse_args()
    directory = args.directory.resolve()
    stage(directory / "before", before=True, instrument=args.observe)
    if args.observe:
        stage(directory / "after", before=False, instrument=True)
