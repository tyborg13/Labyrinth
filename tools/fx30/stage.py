"""Expose the five base presentation scripts at their original resource paths."""

import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
BASE = "2c3f8fb82"
BASE_FILES = (
    "combat_board_view.gd",
    "dragon_shadow_fx.gd",
    "dragon_shadow_fx.gd.uid",
    "dragon_spell_presentation.gd",
    "run_scene.gd",
    "shot_fx.gd",
)


def stage(destination):
    scripts = destination / "scripts"
    scripts.mkdir()
    for source in ROOT.iterdir():
        if source.name.startswith(".") or source.name in {"scripts", "override.cfg"}:
            continue
        (destination / source.name).symlink_to(source)
    for source in (ROOT / "scripts").iterdir():
        if source.name not in BASE_FILES:
            (scripts / source.name).symlink_to(source)
    for name in BASE_FILES:
        data = subprocess.check_output(["git", "show", f"{BASE}:scripts/{name}"], cwd=ROOT)
        (scripts / name).write_bytes(data)
    cache = destination / ".godot"
    cache.mkdir()
    for name in ("imported", "global_script_class_cache.cfg", "uid_cache.bin", "extension_list.cfg"):
        (cache / name).symlink_to(ROOT / ".godot" / name)


if __name__ == "__main__":
    stage(Path(sys.argv[1]).resolve())
