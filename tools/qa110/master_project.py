#!/usr/bin/env python3
"""Stage a read-only gameplay comparison at 047c5848f without changing Git state."""

from pathlib import Path
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[2]
MASTER = "047c5848f"
OUTPUT = ROOT / "tools/qa110/out/master-project"
LINK_DIRS = ("addons", "assets", "cel_look_variants", "data", "fonts", "scenes", "shaders", "themes")
SUPPORT_DIRS = ("tests", "tools")


def git(*arguments):
    return subprocess.check_output(("git", *arguments), cwd=ROOT)


def stage():
    revision = git("rev-parse", MASTER).decode().strip()
    if OUTPUT.exists():
        if (OUTPUT / "base.txt").read_text().strip() != revision:
            raise RuntimeError(f"{OUTPUT} has different provenance")
        return OUTPUT
    changed = set(git("diff", "--name-only", MASTER, "HEAD").decode().splitlines())
    if any(path.split("/", 1)[0] in LINK_DIRS for path in changed):
        raise RuntimeError("A linked runtime directory differs from master")
    OUTPUT.mkdir(parents=True)
    for name in LINK_DIRS + SUPPORT_DIRS:
        (OUTPUT / name).symlink_to(ROOT / name, target_is_directory=True)
    for name in git("ls-tree", "-r", "--name-only", MASTER, "--", "scripts", "project.godot").decode().splitlines():
        path = OUTPUT / name
        path.parent.mkdir(parents=True, exist_ok=True)
        if name in changed:
            path.write_bytes(git("show", f"{MASTER}:{name}"))
        else:
            path.symlink_to(ROOT / name)
    cache = OUTPUT / ".godot"
    cache.mkdir()
    (cache / "imported").symlink_to(ROOT / ".godot/imported", target_is_directory=True)
    for name in ("global_script_class_cache.cfg", "uid_cache.bin"):
        shutil.copyfile(ROOT / ".godot" / name, cache / name)
    (OUTPUT / "base.txt").write_text(revision + "\n")
    return OUTPUT


if __name__ == "__main__":
    print(stage())
