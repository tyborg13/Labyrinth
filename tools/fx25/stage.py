"""Stage the fx-26 parent of the union for the fx-25 comparison."""

import subprocess
import sys
from pathlib import Path

BASE = "3e946d932"
ROOT = Path(__file__).resolve().parents[2]

# Fork the directories that contain changed resources. Keep res:// paths and
# script types intact, and reuse the approved base's identical imported assets.
BASE_FILES = (
    "data/tile_bursts.json",
    "scripts/tile_burst_fx.gd",
    "scripts/resolved_contact_bursts.gd",
    "scripts/shot_fx.gd",
    "scripts/maquette_cutout_runtime/contact_actions.gd",
)


def overlay(destination, relative=Path()):
    for source in (ROOT / relative).iterdir():
        name = source.name
        if not relative.parts and (name.startswith(".") or name == "override.cfg"):
            continue
        target = destination / name
        path = relative / name
        if path.as_posix() in BASE_FILES:
            target.write_bytes(subprocess.check_output(["git", "show", f"{BASE}:{path}"], cwd=ROOT))
        elif source.is_dir() and any(file.startswith(path.as_posix() + "/") for file in BASE_FILES):
            target.mkdir()
            overlay(target, path)
        else:
            target.symlink_to(source)


def stage(destination):
    overlay(destination)
    cache = destination / ".godot"
    cache.mkdir()
    for name in ("imported", "global_script_class_cache.cfg", "uid_cache.bin", "extension_list.cfg"):
        (cache / name).symlink_to(ROOT / ".godot" / name)


if __name__ == "__main__":
    stage(Path(sys.argv[1]).resolve())
