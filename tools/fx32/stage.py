"""Expose the exact base versions of the touched resources in a proof project."""

import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
BASE = "0d3ccfd26"
BASE_FILES = {
    "scripts": {"combat_board_view.gd", "shot_fx.gd"},
    "data": {"shots.json"},
}


def stage(destination):
    for source in ROOT.iterdir():
        if source.name.startswith(".") or source.name == "override.cfg":
            continue
        target = destination / source.name
        if source.name not in BASE_FILES:
            target.symlink_to(source)
            continue
        target.mkdir()
        for entry in source.iterdir():
            result = target / entry.name
            if entry.name in BASE_FILES[source.name]:
                resource = entry.relative_to(ROOT).as_posix()
                result.write_bytes(subprocess.check_output(["git", "show", f"{BASE}:{resource}"], cwd=ROOT))
            else:
                result.symlink_to(entry)
    cache = destination / ".godot"
    cache.mkdir()
    for name in ("imported", "global_script_class_cache.cfg", "uid_cache.bin", "extension_list.cfg"):
        (cache / name).symlink_to(ROOT / ".godot" / name)


if __name__ == "__main__":
    stage(Path(sys.argv[1]).resolve())
