#!/usr/bin/env python3
"""Export and load packed runtime scripts/scenes in the native release template."""
from __future__ import annotations

import argparse
import json
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile
import time


PROJECT = Path(__file__).resolve().parents[1]
TASK_ID = "tool-01"
LAUNCH_TIMEOUT_SECONDS = 300
PROBE_DIRECTORY = "__export_smoke__"
# Match the Steam staging exclusions, plus experiments (excluded by every
# release preset). Never import into the caller's checkout or reuse its cache.
STAGING_EXCLUDES = frozenset({
    ".git", ".godot", ".import", ".steam", ".codex", "build", "output",
    "playtest", "spec", "tests", "tmp", "tools", "experiments",
})
NATIVE_EXPORTS = {
    "Steam macOS": ("darwin", "Escape the Umbra.app"),
    "Steam Windows": ("win32", "Escape the Umbra.exe"),
    "Steam Linux": ("linux", "Escape the Umbra.x86_64"),
}
ERROR_LINE = re.compile(
    r"SCRIPT ERROR:|Parse Error:|(?:^|\s)ERROR:.*(?:"
    r"script|resource|file|loader|res://|EXPORT_SMOKE|"
    r"(?:failed|cannot|can't|could not|error) (?:to )?(?:load|open)|not found|does not exist)",
    re.I,
)
ANSI_ESCAPE = re.compile(r"\x1b\[[0-9;]*[A-Za-z]")
SUCCESS_LINE = re.compile(r"^EXPORT_SMOKE_LOADED scripts=([1-9][0-9]*) scenes=([1-9][0-9]*)$", re.M)
# Inspect source before export: loading a .gdc to discover its base would already
# compile it in the release template. Ignore comments and strings/doc examples.
GDSCRIPT_NON_CODE = re.compile(
    r'"""(?:\\.|(?!""").)*"""|\'\'\'(?:\\.|(?!\'\'\').)*\'\'\'|'
    r'"(?:\\.|[^"\\])*"|\'(?:\\.|[^\'\\])*\'|#[^\r\n]*', re.S,
)
EDITOR_BASE = re.compile(r"\bextends\s+Editor[A-Za-z0-9_]*\b")

PACK_PROBE = '''extends Node

var scripts: PackedStringArray = PackedStringArray()
var scenes: PackedStringArray = PackedStringArray()
var failures: int = 0
var editor_only_scripts: PackedStringArray = PackedStringArray(__EDITOR_ONLY_SCRIPTS__)
var editor_only_scenes: PackedStringArray = PackedStringArray(__EDITOR_ONLY_SCENES__)

func _ready() -> void:
\t# A successful editor run would defeat this gate's purpose.
\tif OS.has_feature("editor") or not OS.has_feature("release"):
\t\tpush_error("EXPORT_SMOKE requires the release export template")
\t\tget_tree().quit(1)
\t\treturn
\t_collect("res://")
\tscripts.sort()
\tscenes.sort()
\t# Editor panels load their scripts as dependencies. Resolve their compiled
\t# aliases without loading the scene or compiling those excluded scripts.
\tfor path: String in editor_only_scenes.duplicate():
\t\tif FileAccess.file_exists(path + ".remap"):
\t\t\tvar remap := ConfigFile.new()
\t\t\tif remap.load(path + ".remap") != OK:
\t\t\t\tpush_error("EXPORT_SMOKE cannot read scene remap: " + path)
\t\t\t\tfailures += 1
\t\t\telse:
\t\t\t\tvar target: String = str(remap.get_value("remap", "path", ""))
\t\t\t\tif not target.is_empty() and not editor_only_scenes.has(target):
\t\t\t\t\teditor_only_scenes.append(target)
\tvar loaded_scripts: int = 0
\tvar loaded_scenes: int = 0
\tfor path: String in scripts:
\t\tvar source_path: String = path.trim_suffix(".gdc") + ".gd" if path.ends_with(".gdc") else path
\t\tif source_path.match("res://addons/*/editor/*") or editor_only_scripts.has(source_path):
\t\t\tprint("EXPORT_SMOKE SKIPPED (editor-only): " + path)
\t\t\tcontinue
\t\tprint("EXPORT_SMOKE_LOAD " + path)
\t\tloaded_scripts += 1
\t\tvar resource: Resource = ResourceLoader.load(path)
\t\tif not resource is Script:
\t\t\tpush_error("EXPORT_SMOKE missing/invalid script: " + path)
\t\t\tfailures += 1
\tfor path: String in scenes:
\t\tif path.match("res://addons/*/editor/*") or editor_only_scenes.has(path):
\t\t\tprint("EXPORT_SMOKE SKIPPED (editor-only): " + path)
\t\t\tcontinue
\t\tprint("EXPORT_SMOKE_LOAD " + path)
\t\tloaded_scenes += 1
\t\tvar resource: Resource = ResourceLoader.load(path)
\t\tif not resource is PackedScene:
\t\t\tpush_error("EXPORT_SMOKE missing/invalid scene: " + path)
\t\t\tfailures += 1
\tif loaded_scripts == 0 or loaded_scenes == 0:
\t\tpush_error("EXPORT_SMOKE empty pack inventory")
\t\tfailures += 1
\tprint("EXPORT_SMOKE_LOADED scripts=%d scenes=%d" % [loaded_scripts, loaded_scenes])
\tget_tree().quit(1 if failures else 0)

func _collect(directory: String) -> void:
\t# ResourceLoader exposes original paths through .remap/.gdc exports.
\tfor entry: String in ResourceLoader.list_directory(directory):
\t\tvar path: String = directory + entry
\t\tif path == "res://__export_smoke__/":
\t\t\tcontinue
\t\tif entry.ends_with("/"):
\t\t\t_collect(path)
\t\telif entry.get_extension() in ["gd", "gdc"]:
\t\t\tscripts.append(path)
\t\telif entry.get_extension() in ["tscn", "scn"]:
\t\t\tscenes.append(path)
'''


def editor_only_scripts(project: Path) -> list[str]:
    paths = []
    for path in sorted(project.rglob("*.gd")):
        relative = path.relative_to(project)
        parts = relative.parts
        addon_editor = len(parts) > 3 and parts[0] == "addons" and parts[2] == "editor"
        source = GDSCRIPT_NON_CODE.sub(" ", path.read_text(encoding="utf-8-sig"))
        if addon_editor or EDITOR_BASE.search(source):
            paths.append("res://" + relative.as_posix())
    return paths


def editor_only_scenes(project: Path) -> list[str]:
    # Only addon editor panels qualify. Runtime scenes that accidentally depend
    # on editor code must still load and fail, rather than inherit this exemption.
    return sorted("res://" + path.relative_to(project).as_posix()
                  for path in project.glob("addons/*/editor/**/*")
                  if path.suffix in (".tscn", ".scn"))


def report_errors(output: str) -> bool:
    """Keep the engine's file/line context, including errors with exit code 0."""
    lines = ANSI_ESCAPE.sub("", output).splitlines()
    failed = False
    context = ""
    for index, line in enumerate(lines):
        if line.startswith("EXPORT_SMOKE_LOAD "):
            context = line
        if not ERROR_LINE.search(line):
            continue
        # Godot may retain cyclic resources until shutdown after bulk loading.
        # This diagnostic is neither a missing resource nor a load failure.
        if re.fullmatch(r"ERROR: \d+ resources? still in use at exit \(run with --verbose for details\)\.", line):
            continue
        failed = True
        if context:
            print(context, flush=True)
        print("\n".join(lines[index:index + 4]), flush=True)
    return failed


def run_stage(name: str, command: list[str], project: Path, logs: Path) -> tuple[bool, str]:
    log = logs / (name + ".log")
    print("EXPORT_SMOKE %s; log: %s" % (name, log), flush=True)
    with log.open("w") as stream:
        result = subprocess.run(command, cwd=project, stdout=stream, stderr=subprocess.STDOUT)
    output = log.read_text(errors="replace")
    errors = report_errors(output)
    if result.returncode:
        print("EXPORT_SMOKE %s exited %d" % (name, result.returncode), flush=True)
        if not errors:
            print("\n".join(output.splitlines()[-12:]), flush=True)
    return result.returncode == 0 and not errors, output


def smoke(project: Path, preset: str, logs: Path) -> bool:
    platform, filename = NATIVE_EXPORTS[preset]
    if sys.platform != platform:
        raise ValueError("%s needs a native %s host to launch its release binary" % (preset, platform))
    if not (project / "project.godot").is_file():
        raise ValueError("Missing project.godot: " + str(project))
    # The selected project's wrapper owns its asset inputs and cel manifest.
    # In particular, --project may be a historical commit, not this checkout.
    wrapper = project / "tools/export_game.py"
    if not wrapper.is_file():
        raise ValueError("Missing export wrapper: " + str(wrapper))
    ok, _ = run_stage("cel", [sys.executable, str(project / "tools/cel_look.py"),
                              "build", "--if-stale"], project, logs)
    if not ok:
        return False
    with tempfile.TemporaryDirectory(prefix="runtime-", dir=logs) as temporary:
        work = Path(temporary)
        staged = work / "project"

        def ignore(directory: str, names: list[str]) -> set[str]:
            excluded = set(STAGING_EXCLUDES) if Path(directory) == project else set()
            return (excluded | {".DS_Store", "__pycache__"}).intersection(names)

        shutil.copytree(project, staged, ignore=ignore)
        # Official release templates disallow --script/--main-pack/--path.
        # Give only this disposable export a packed bootstrap scene instead.
        # Product scripts, scenes, assets and export presets remain byte-identical.
        probe_directory = staged / PROBE_DIRECTORY
        if probe_directory.exists():
            raise ValueError("Reserved smoke probe directory already exists: " + str(probe_directory))
        probe_directory.mkdir()
        probe = PACK_PROBE.replace("__EDITOR_ONLY_SCRIPTS__", json.dumps(editor_only_scripts(staged)))
        probe = probe.replace("__EDITOR_ONLY_SCENES__", json.dumps(editor_only_scenes(staged)))
        (probe_directory / "probe.gd").write_text(probe)
        (probe_directory / "probe.tscn").write_text(
            '[gd_scene load_steps=2 format=3]\n'
            '[ext_resource type="Script" path="res://__export_smoke__/probe.gd" id="1"]\n'
            '[node name="ExportSmoke" type="Node"]\nscript = ExtResource("1")\n')
        config_path = staged / "project.godot"
        config, replacements = re.subn(r'^run/main_scene=.*$',
                                       'run/main_scene="res://__export_smoke__/probe.tscn"',
                                       config_path.read_text(), flags=re.M)
        if replacements != 1:
            raise ValueError("Expected one application main scene in project.godot")
        config_path.write_text(config)
        output = work / filename
        ok, _ = run_stage("export", [sys.executable, str(wrapper), "--task-id", TASK_ID,
                                    "--preset", preset, "--project", str(staged),
                                    "--output", str(output)], project, logs)
        if not ok:
            return False
        if platform == "darwin":
            executables = [p for p in (output / "Contents/MacOS").iterdir() if p.is_file()]
            if len(executables) != 1:
                raise ValueError("Expected one exported macOS executable: " + str(output))
            binary = executables[0]
        else:
            binary = output
        binary.chmod(binary.stat().st_mode | 0o111)
        command = [sys.executable, str(project / "tools/godot_task_runner.py"),
                   "--project", str(work), "--task-id", TASK_ID, "--stream",
                   "--godot-home-root", str(work / "home"),
                   "--timeout", str(LAUNCH_TIMEOUT_SECONDS), "--", str(binary),
                   "--headless", "--audio-driver", "Dummy",
                   "--log-file", str(logs / "release-engine.log")]
        ok, launch = run_stage("launch", command, project, logs)
        for line in launch.splitlines():
            if line.startswith("EXPORT_SMOKE SKIPPED (editor-only): "):
                print(line, flush=True)
        summary = SUCCESS_LINE.search(launch)
        if summary:
            print(summary.group(), flush=True)
        else:
            print("EXPORT_SMOKE missing release inventory completion marker", flush=True)
        return ok and summary is not None


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--preset", required=True, choices=NATIVE_EXPORTS)
    parser.add_argument("--project", type=Path, default=PROJECT)
    parser.add_argument("--output-dir", type=Path, help="Retain logs here (defaults to a unique temporary directory).")
    args = parser.parse_args(argv)
    started = time.monotonic()
    passed = False
    try:
        logs = args.output_dir.resolve() if args.output_dir else Path(tempfile.mkdtemp(prefix="labyrinth-export-smoke-"))
        logs.mkdir(parents=True, exist_ok=True)
        project = args.project.resolve()
        # Prevent recursively copying a caller-selected log directory.
        if logs == project or project in logs.parents:
            raise ValueError("--output-dir must be outside --project")
        passed = smoke(project, args.preset, logs)
    except (OSError, ValueError) as exc:
        print("EXPORT_SMOKE error: " + str(exc), file=sys.stderr, flush=True)
    finally:
        print("EXPORT_SMOKE RESULT: %s (%.2f seconds)" % (
            "PASS" if passed else "FAIL", time.monotonic() - started), flush=True)
    return 0 if passed else 1


if __name__ == "__main__":
    raise SystemExit(main())
