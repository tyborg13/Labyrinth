"""Stage the two proof projects with the exact source atlas for each side."""

import json
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
BASE = "codex/fx-34"
CATALOG = "data/tile_bursts.json"
OTHER_BURST_CATALOGS = ("data/self_bursts.json", "data/strikes.json")
CACHE_LINKS = ("imported", "global_script_class_cache.cfg", "uid_cache.bin", "extension_list.cfg")


def base_file(path):
    return subprocess.check_output(["git", "show", f"{BASE}:{path}"], cwd=ROOT)


def atlas_paths(catalog):
    return {entry["atlas"].removeprefix("res://") for entry in json.loads(catalog)["sizes"]}


def stage(destination, before):
    catalog = base_file(CATALOG) if before else (ROOT / CATALOG).read_bytes()
    atlases = atlas_paths(catalog)
    source_pngs = atlases.union(*(atlas_paths((ROOT / path).read_bytes()) for path in OTHER_BURST_CATALOGS))
    staged_paths = source_pngs | {CATALOG}

    def mirror(source, target):
        path = source.relative_to(ROOT).as_posix()
        # The regular player can load source PNGs when no import sidecar exists.
        # Use that path for both takes so a shared .ctex cannot mask the rebake.
        if path.endswith(".import") and path.removesuffix(".import") in source_pngs:
            return
        if path == CATALOG:
            target.write_bytes(catalog)
        elif path in atlases:
            target.write_bytes(base_file(path) if before else source.read_bytes())
        elif any(item.startswith(path + "/") for item in staged_paths):
            target.mkdir()
            for child in source.iterdir():
                mirror(child, target / child.name)
        else:
            target.symlink_to(source)

    destination.mkdir()
    for source in ROOT.iterdir():
        if not source.name.startswith(".") and source.name != "override.cfg":
            mirror(source, destination / source.name)
    cache = destination / ".godot"
    cache.mkdir()
    for name in CACHE_LINKS:
        (cache / name).symlink_to(ROOT / ".godot" / name)


if __name__ == "__main__":
    parent = Path(sys.argv[1]).resolve()
    stage(parent / "before", before=True)
    stage(parent / "after", before=False)
