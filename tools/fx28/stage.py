"""Stage the baseline and count procedural lob calls without touching the live scripts."""

import argparse
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[2]
BASE = "7179c630c"
LOB = "scripts/enemy_mechanics/lob_view.gd"
BOARD = "scripts/combat_board_view.gd"
RUN = "scripts/run_scene.gd"
SCENE = "scenes/run_scene.tscn"
CONTACT_TRACKER = "scripts/resolved_contact_bursts.gd"
MISSING_TERRAIN_HELPER = "hits.has(tile) or ResolvedContactBursts._terrain_lost(before, state, tile)"
EXISTING_STEP_HELPER = "TileBurstFx.step_hit_tiles(before, state, board_view._resolved_unit_footprint).has(tile)"


def instrument(source):
    lines = source.splitlines()
    for index, line in enumerate(lines):
        for painter in ("travel", "impact"):
            call = f"Fx.{painter}("
            if call not in line:
                continue
            call_at = line.index(call)
            if ": " in line[:call_at]:
                line = line[:call_at].rstrip() + "\n" + line[:len(line) - len(line.lstrip())] + "\t" + line[call_at:]
            indent = line.rsplit("\n", 1)[-1]
            indent = indent[:len(indent) - len(indent.lstrip())]
            key = f'&"fx28_{painter}"'
            marker = f"{indent}Engine.set_meta({key}, int(Engine.get_meta({key}, 0)) + 1)"
            tail = line.rsplit("\n", 1)
            lines[index] = "\n".join((*tail[:-1], marker, tail[-1]))
    return "\n".join(lines) + "\n"


def stage(directory, before, observe):
    directory.mkdir(parents=True)
    prefix = "res://" + directory.relative_to(ROOT).as_posix()
    sources = (LOB, BOARD, RUN, SCENE)
    tracker = (ROOT / CONTACT_TRACKER).read_text()
    for name in sources:
        source = (subprocess.check_output(["git", "show", f"{BASE}:{name}"], cwd=ROOT, text=True)
                  if before else (ROOT / name).read_text())
        source = source.replace("class_name CombatBoardView\n", "")
        for other in sources:
            source = source.replace(f"res://{other}", f"{prefix}/{Path(other).name}")
        if name == LOB and observe:
            source = instrument(source)
        if name == RUN and "static func _terrain_lost(" not in tracker:
            # The united base references an absent fx-26 helper in chain
            # playback. Neither take exercises that code. Keep the shim local
            # to the staged scene so the before and after can both parse.
            source = source.replace(MISSING_TERRAIN_HELPER, EXISTING_STEP_HELPER)
        (directory / Path(name).name).write_text(source)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("directory", type=Path)
    parser.add_argument("--observe", action="store_true")
    args = parser.parse_args()
    stage(args.directory.resolve() / "before", True, args.observe)
    stage(args.directory.resolve() / "after", False, args.observe)
