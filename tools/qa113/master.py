#!/usr/bin/env python3
"""Stage master sources for focused, read-only runtime comparisons."""

from pathlib import Path
import shutil
import subprocess

ROOT = Path(__file__).resolve().parents[2]
MASTER = "047c5848f"
OUTPUT = ROOT / "tools/qa113/out/master-project"
RUNTIME_DIRS = ("addons", "assets", "cel_look_variants", "data", "fonts", "scenes", "scripts", "shaders", "themes")


def git(*args):
    return subprocess.check_output(("git", *args), cwd=ROOT)


def stage():
    revision = git("rev-parse", MASTER).decode().strip()
    if OUTPUT.exists():
        if (OUTPUT / "revision.txt").read_text().strip() != revision:
            raise RuntimeError(f"{OUTPUT} has different provenance")
        return OUTPUT
    OUTPUT.mkdir(parents=True)
    changed = set(git("diff", "--name-only", MASTER, "HEAD", "--", *RUNTIME_DIRS, "project.godot").decode().splitlines())
    for name in (*RUNTIME_DIRS, "project.godot"):
        local = ROOT / name
        if not any(path == name or path.startswith(name + "/") for path in changed):
            (OUTPUT / name).symlink_to(local, target_is_directory=local.is_dir())
            continue
        files = git("ls-tree", "-r", "--name-only", MASTER, "--", name).decode().splitlines()
        for rel in files:
            target = OUTPUT / rel
            target.parent.mkdir(parents=True, exist_ok=True)
            if rel in changed:
                target.write_bytes(git("show", f"{MASTER}:{rel}"))
            else:
                target.symlink_to(ROOT / rel)
    for name in ("tests", "tools"):
        (OUTPUT / name).symlink_to(ROOT / name, target_is_directory=True)
    cache = OUTPUT / ".godot"
    cache.mkdir()
    (cache / "imported").symlink_to(ROOT / ".godot/imported", target_is_directory=True)
    for name in ("global_script_class_cache.cfg", "uid_cache.bin"):
        shutil.copyfile(ROOT / ".godot" / name, cache / name)
    (OUTPUT / "revision.txt").write_text(revision + "\n")
    return OUTPUT


if __name__ == "__main__":
    print(stage())
