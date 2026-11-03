"""Cheap source/sidecar freshness check before the full Godot suite parses."""
from __future__ import annotations

import json
import os
from pathlib import Path
import re
import subprocess
import sys
import time

IMPORT_TIMEOUT_SECONDS = 1800
INDEX_VERSION = 1
INDEX_PATH = ".godot/program_suite_imports.json"


def _build_index(project: Path) -> dict:
    rows, directories = [], {}
    for directory, subdirs, files in os.walk(project):
        folder = Path(directory)
        subdirs[:] = [name for name in subdirs if name not in (".git", ".godot")
                      and not (folder / name / ".gdignore").exists()]
        directories[folder.relative_to(project).as_posix()] = folder.stat().st_mtime_ns
        for name in files:
            if not name.endswith(".import"):
                continue
            sidecar = folder / name
            source = sidecar.with_suffix("")
            if not source.is_file():
                continue
            text = sidecar.read_text(encoding="utf-8")
            # dest_files lists every platform variant, unlike remap.path.
            destinations = re.search(r"^dest_files\s*=\s*\[(.*?)\]", text, re.M | re.S)
            if destinations:
                rows.append({"source": source.relative_to(project).as_posix(),
                             "sidecar": sidecar.relative_to(project).as_posix(),
                             "sidecar_mtime": sidecar.stat().st_mtime_ns,
                             "artifacts": re.findall(r'"res://([^"]+)"', destinations[1])})
    index = {"version": INDEX_VERSION, "directories": directories, "rows": rows}
    path = project / INDEX_PATH
    temporary = path.with_suffix(".tmp")
    temporary.write_text(json.dumps(index), encoding="utf-8")
    temporary.replace(path)
    return index


def _load_index(project: Path) -> dict:
    try:
        index = json.loads((project / INDEX_PATH).read_text(encoding="utf-8"))
        if (index["version"] == INDEX_VERSION and "." in index["directories"]
                and isinstance(index["rows"], list)
                and all((project / name).stat().st_mtime_ns == stamp
                        for name, stamp in index["directories"].items())
                and all((project / row["sidecar"]).stat().st_mtime_ns == row["sidecar_mtime"]
                        for row in index["rows"])):
            return index
    except (OSError, ValueError, KeyError, TypeError, AttributeError):
        pass
    # Directory mtimes catch new/deleted sources and sidecars. Sidecar mtimes
    # invalidate the destination mapping. File contents are only read on rebuild.
    return _build_index(project)


def stale_reason(project: Path) -> str:
    if not (project / ".godot/global_script_class_cache.cfg").is_file():
        return "missing script class cache"
    for row in _load_index(project)["rows"]:
        source_time = (project / row["source"]).stat().st_mtime_ns
        for relative in row["artifacts"]:
            artifact = project / relative
            try:
                imported_time = artifact.stat().st_mtime_ns
            except FileNotFoundError:
                return "missing artifact: " + relative
            if imported_time < source_time:
                return "stale artifact: " + relative
    return ""


def ensure_imported(project: Path, godot: str, task_id: str) -> int:
    started = time.monotonic()
    reason = stale_reason(project)
    checked = time.monotonic() - started
    print("GODOT IMPORT CHECK: %s (%.3f seconds)" % (reason or "warm", checked), flush=True)
    if not reason:
        return 0
    # This is an intentional import bootstrap, never an editor parser check.
    code = subprocess.call([
        sys.executable, str(Path(__file__).with_name("godot_task_runner.py")),
        "--project", str(project), "--task-id", task_id + "-import",
        "--timeout", str(IMPORT_TIMEOUT_SECONDS), "--stream", "--",
        godot, "--headless", "--path", str(project), "--import",
    ])
    if code == 0:
        _build_index(project)
    print("GODOT IMPORT RESULT: %s (%.3f seconds)" % (
        "PASS" if code == 0 else "FAIL", time.monotonic() - started), flush=True)
    return code


def full_suite_project(command: list[str], cwd: Path) -> Path | None:
    if "--script" not in command:
        return None
    script = command[command.index("--script") + 1].replace("\\", "/")
    project = Path(command[command.index("--path") + 1]) if "--path" in command else cwd
    if not project.is_absolute():
        project = cwd / project
    project = project.resolve()
    candidate = Path(script.removeprefix("res://"))
    if not candidate.is_absolute():
        candidate = project / candidate
    if candidate.resolve() == project / "tests/run_tests.gd":
        return project
    return None
