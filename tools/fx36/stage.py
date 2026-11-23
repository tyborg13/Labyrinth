"""Stage committed presentations and import only their effect sheets."""

import argparse
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[2]
EFFECTS = Path("assets/art/effects")
OVERLAY = (Path("tools/fx36"), Path("tools/fx33/cases.gd"), Path("cel_look_variants"))
CACHE_FILES = ("global_script_class_cache.cfg", "uid_cache.bin", "extension_list.cfg")
# These authoring and test directories are outside the playable capture. In
# particular their CSVs must not trigger a full import through staged symlinks.
OMIT = {"experiments", "output", "spec", "tests", "override.cfg"}


def git(*args):
    return subprocess.check_output(["git", "--no-optional-locks", *args], cwd=ROOT)


def revision_project(destination, revision):
    commit = git("rev-parse", "--verify", revision).decode().strip()
    changed = {
        Path(os.fsdecode(path))
        for path in git("diff", "--name-only", "--no-renames", "-z", commit, "--").split(b"\0")
        if path
    }
    split_dirs = {parent for path in changed.union(OVERLAY) for parent in path.parents}
    tracked = {
        Path(os.fsdecode(path))
        for path in git("ls-tree", "-r", "--name-only", "-z", commit).split(b"\0")
        if path and not path.startswith(b".") and os.fsdecode(path).split("/", 1)[0] not in OMIT
    }
    directories = {parent for path in tracked for parent in path.parents}
    children = {}
    for path in directories.union(tracked, OVERLAY):
        if path != Path("."):
            children.setdefault(path.parent, []).append(path)
    for path in OVERLAY:
        for parent in path.parents:
            if parent != Path(".") and parent not in directories:
                children.setdefault(parent.parent, []).append(parent)

    def mirror(path):
        target = destination / path
        if path in OVERLAY:
            target.symlink_to(ROOT / path)
        elif path in split_dirs:
            if path != Path("."):
                target.mkdir()
            for child in sorted(set(children.get(path, []))):
                mirror(child)
        elif path in changed:
            target.write_bytes(git("show", f"{commit}:{path.as_posix()}"))
        else:
            target.symlink_to(ROOT / path)

    destination.mkdir()
    mirror(Path("."))
    stage_cache(destination)
    print(f"FX-36 STAGE {revision} {commit}", flush=True)


def stage_cache(destination):
    (destination / ".godot").mkdir()
    for name in CACHE_FILES:
        shutil.copyfile(ROOT / ".godot" / name, destination / ".godot" / name)


def working_project(destination):
    destination.mkdir()
    for source in ROOT.iterdir():
        if not source.name.startswith(".") and source.name not in OMIT:
            (destination / source.name).symlink_to(source)
    stage_cache(destination)
    (destination / ".godot" / "imported").symlink_to(ROOT / ".godot" / "imported")
    print(f"FX-36 STAGE working tree {ROOT}", flush=True)


def import_effects(project):
    # Use a small import-only project so no worktree source or sidecar can be
    # rewritten. The relative resource paths match the production paths.
    with tempfile.TemporaryDirectory(prefix="fx36-import-", dir=project.parent if project != ROOT else ROOT / ".godot") as temp:
        scratch = Path(temp)
        (scratch / "project.godot").write_text('config_version=5\n\n[rendering]\nrenderer/rendering_method="gl_compatibility"\n')
        for source in (project / EFFECTS).rglob("*.png.import"):
            destination = scratch / source.relative_to(project)
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(source, destination)
            shutil.copyfile(source.with_suffix(""), destination.with_suffix(""))
        subprocess.run(
            ["python3", "tools/godot_task_runner.py", "--task-id", "fx-36", "--stream",
             "--", "godot", "--headless", "--path", str(scratch), "--import"],
            cwd=ROOT, check=True,
        )
        cache = project / ".godot" / "imported"
        cache.mkdir(exist_ok=True)
        for path in (scratch / ".godot" / "imported").iterdir():
            with tempfile.NamedTemporaryFile(dir=cache, delete=False) as staged:
                with path.open("rb") as source:
                    shutil.copyfileobj(source, staged)
            os.replace(staged.name, cache / path.name)
        if project != ROOT:
            for entry in (ROOT / ".godot" / "imported").iterdir():
                if not (cache / entry.name).exists():
                    (cache / entry.name).symlink_to(entry)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("destination", type=Path)
    parser.add_argument("--revision")
    args = parser.parse_args()
    project = args.destination.resolve()
    if args.revision:
        revision_project(project, args.revision)
    elif project != ROOT:
        working_project(project)
        return
    import_effects(project)


if __name__ == "__main__":
    main()
