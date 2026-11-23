"""Stage the base comparison sources and optional headless draw observers."""

import argparse
import json
from pathlib import Path

from assets import BASE, METADATA, ROOT, atlas_path, base_file

BOARD = "combat_board_view.gd"
RUN = "run_scene.gd"
BASE_SCRIPTS = (BOARD, RUN, "shot_fx.gd", "resolved_contact_bursts.gd")
OBSERVERS = {
    "_draw_fireball_travel_composite": '\tEngine.set_meta(&"fx23_legacy_flight", true)',
    "_draw_lightning_travel": '\tEngine.set_meta(&"fx23_legacy_flight", true)',
    "_draw_elemental_release": '\tif style == AttackFxLibrary.STYLE_FIREBALL or style == AttackFxLibrary.STYLE_LIGHTNING_BOLT:\n'
                              '\t\tEngine.set_meta(&"fx23_legacy_release", true)',
}


def observe(source):
    for name, line in OBSERVERS.items():
        offset = source.index("\n", source.index(f"func {name}("))
        assert source[offset - len(" -> void:"):offset] == " -> void:"
        source = source[:offset] + "\n" + line + source[offset:]
    return source


def stage(directory, base, instrument):
    names = BASE_SCRIPTS if base else (BOARD, RUN)
    directory.mkdir(parents=True)
    path = "res://" + str(directory.relative_to(ROOT))
    if base:
        metadata = json.loads(base_file(METADATA))
        for sheet in metadata["sizes"]:
            atlas = atlas_path(sheet)
            name = Path(atlas).name
            (directory / name).write_bytes(base_file(atlas))
            sheet["atlas"] = f"{path}/{name}"
        (directory / "shots.json").write_text(json.dumps(metadata))
    for name in names:
        original = f"scripts/{name}"
        source = base_file(original).decode() if base else (ROOT / original).read_text()
        source = source.replace("class_name CombatBoardView\n", "")
        for other in names:
            source = source.replace(f"res://scripts/{other}", f"{path}/{other}")
        if base:
            source = source.replace(f"res://{METADATA}", f"{path}/shots.json")
        if instrument and name == BOARD:
            source = observe(source)
        (directory / name).write_text(source)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=f"{__doc__} Base is {BASE}.")
    parser.add_argument("directory", type=Path)
    parser.add_argument("--observe", action="store_true")
    args = parser.parse_args()
    directory = args.directory.resolve()
    stage(directory / "before", base=True, instrument=args.observe)
    if args.observe:
        stage(directory / "after", base=False, instrument=True)
