#!/usr/bin/env python3
"""Audit executable Godot test registration; run supplemental process fixtures.

Only call edges count: an unused preload, parse-only load, or a commented path
cannot register a test. Tiny assertion-free wrappers may share an already-run
suite entry point. Renderer exclusions are exact paths with explicit reasons.
"""
from __future__ import annotations

import argparse
import ast
from collections import Counter
from concurrent.futures import ThreadPoolExecutor
import json
import os
from pathlib import Path
import posixpath
import re
import subprocess
import sys
import tempfile
import time

sys.path.insert(0, str(Path(__file__).resolve().parent))
import gdscript_test_calls as gd
from program_suite_fixture import CAPTURE_VIDEO_QUALITY, PACK_TIMEOUT_SECONDS, fixture_stages
from test_execution_sources import python_program_coverage, PARTITIONED_PROGRAMS, program_paths

ROOT = Path(__file__).resolve().parents[1]
PROGRAM_MANIFEST = "tests/headless_test_programs.json"
PROGRAM_DISPATCHER = "tools/program_suite_runner.gd"
WINDOWED_MANIFEST = "tests/windowed_test_allowlist.json"
QUARANTINE_MANIFEST = "tests/quarantine.json"
QUARANTINE_FIELDS = ("path", "category", "reason", "evidence_log", "follow_up")
QUARANTINE_OWNERS = {
    "export-workflow": {"qa-12"},
    "stale-reference": {"qa-09"},
    "legacy-cutout": {"qa-10"},
    "long-diagnostic": {"qa-11"},
    "needs-design": {"design-01"},
    "possible-bug": {"bug-01", "bug-02"},
}
PROGRAM_HELPERS = ("tests/helpers/program_sub_suites.gd", "tests/static_facing_program_suites.gd")
TEST_SUFFIXES = ("_test.gd", "_suite.gd", "_probe.gd")
PROGRAM_TIMEOUT_SECONDS = 180
SUPPLEMENTAL_WORKERS = 4


def read_json(root: Path, relative: str, default):
    path = root / relative
    return json.loads(path.read_text(encoding="utf-8")) if path.exists() else default


def program_manifest(root: Path) -> list[dict]:
    """Read the scheduler's original tuple plus its guarded supplemental set."""
    base = []
    path = root / "tools/program_suite_runner.py"
    if path.is_file():
        for node in ast.parse(path.read_text(encoding="utf-8")).body:
            if isinstance(node, ast.Assign) and any(isinstance(t, ast.Name) and t.id == "BASE_SUITES" for t in node.targets):
                base = ast.literal_eval(node.value)
                break
    programs = [{"path": "tests/" + name + ".gd"} for name in base] + read_json(root, PROGRAM_MANIFEST, [])
    return [dict(program, path=part) for program in programs for part in program_paths(program["path"])]


def source(root: Path, path: str) -> str:
    file = root / path
    if not file.is_file():
        return ""
    return file.read_text(encoding="utf-8")


def resource_path(owner: str, path: str) -> str:
    # Godot resource paths use forward slashes on Windows as well.
    relative = path.removeprefix("res://") if path.startswith("res://") else posixpath.join(posixpath.dirname(owner), path)
    return posixpath.normpath(relative)


def alias_path(root: Path, aliases: dict, chain: str, read_script=None) -> str:
    first, *nested = chain.split(".")
    path = aliases.get(first, "")
    for name in nested:
        parsed = read_script(path) if read_script else gd.script(source(root, path))
        constants = {a: resource_path(path, p) for a, p in gd.aliases(parsed.class_tokens).items()}
        path = constants.get(name, "")
    return path


def execution_graph(root: Path, programs: list[dict], entrypoints=None) -> set[tuple[str, str]]:
    cache = {}

    def info(path):
        if path not in cache:
            cache[path] = gd.script(source(root, path))
        return cache[path]

    def resolve(receiver, method):
        path = receiver
        aliases = {}
        visited = set()
        owner, body = "", []
        while path and path not in visited:
            visited.add(path)
            parsed = info(path)
            constants = {a: resource_path(path, p) for a, p in gd.aliases(parsed.class_tokens).items()}
            aliases.update({k: v for k, v in constants.items() if k not in aliases})
            if not owner and method in parsed.methods:
                owner, body = path, parsed.methods[method]
            path = resource_path(path, parsed.parent) if parsed.parent else ""
        # A method's locals shadow class constants only for that invocation.
        aliases.update({a: resource_path(owner, p) for a, p in gd.aliases(body).items()})
        return owner, body, aliases

    entrypoints = ["tests/run_tests.gd"] if entrypoints is None else entrypoints
    reached = {(path, "__program__") for path in entrypoints}
    visited = set()
    pending = [(path, "_initialize") for path in entrypoints]
    while pending:
        receiver, method = pending.pop()
        if (receiver, method) in visited:
            continue
        visited.add((receiver, method))
        owner, body, aliases = resolve(receiver, method)
        if not owner:
            continue
        reached.add((owner, method))
        reached.add((receiver, method))
        # A manifest/list counts only while its dispatcher is itself executed.
        if owner == PROGRAM_DISPATCHER and method == "start":
            pending += [(p["path"], "_initialize") for p in programs]
            reached.update((p["path"], "__program__") for p in programs)
        if owner in PROGRAM_HELPERS and method == "run":
            names = gd.suite_names(info(owner).class_tokens)
            pending += [("tests/" + name + ".gd", "_initialize") for name in names]
            reached.update(("tests/" + name + ".gd", "__program__") for name in names)
        calls = gd.calls(body)
        pending += [(resource_path(owner, p), m) for p, m in calls.inline
                    if resource_path(owner, p).startswith("tests/") or resource_path(owner, p) == PROGRAM_DISPATCHER]
        for alias, called_method in calls.aliases:
            path = alias_path(root, aliases, alias, info)
            if path.startswith("tests/") or path == PROGRAM_DISPATCHER:
                pending.append((path, called_method))
        if owner in ("tests/suites/section_map_regression_suite.gd",
                     "tests/suites/section_map_performance_suite.gd"):
            pending += [("tests/" + child, "_initialize") for child in calls.children]
            reached.update(("tests/" + child, "__program__") for child in calls.children)
        pending += [(receiver, name) for name in calls.local + calls.deferred]
    return reached


def shared_wrapper(root: Path, path: str, reached: set[tuple[str, str]]) -> list[str]:
    """Recognize small dispatch-only wrappers; never discard local assertions."""
    text = source(root, path)
    parsed = gd.script(text)
    methods = parsed.methods
    if len(text.splitlines()) > 70 or not methods or {name for name in methods if not name.startswith("_run_")} - {
        "_initialize", "_run", "_expect", "_assert", "_finish", "_check"
    }:
        return []
    class_aliases = {a: resource_path(path, p) for a, p in gd.aliases(parsed.class_tokens).items()}
    calls = []
    for name, body in methods.items():
        if name in {"_expect", "_assert", "_check"}:
            continue
        edges = gd.calls(body)
        if set(edges.local) & {"_expect", "_assert", "_check", "assert"}:
            return []
        aliases = dict(class_aliases)
        aliases.update({a: resource_path(path, p) for a, p in gd.aliases(body).items()})
        calls += [(resource_path(path, p), m) for p, m in edges.inline
                  if resource_path(path, p).startswith("tests/")]
        calls += [(alias_path(root, aliases, a), m) for a, m in edges.aliases
                  if alias_path(root, aliases, a).startswith("tests/")]
        # Inherited focused aliases of run_tests call its already-run assertions.
        if parsed.parent == "res://tests/run_tests.gd":
            calls += [("tests/run_tests.gd", m) for m in edges.local if m.startswith("_test_")]

    if not calls or any(call not in reached for call in calls):
        return []
    return sorted({f"{p}::{m}" for p, m in calls})


def audit(root: Path = ROOT) -> tuple[list[dict], list[str]]:
    programs = program_manifest(root)
    windowed = read_json(root, WINDOWED_MANIFEST, {})
    quarantine = read_json(root, QUARANTINE_MANIFEST, [])
    python_coverage = python_program_coverage(root)
    reached = execution_graph(root, programs)
    direct = {p["path"] for p in programs}
    rows = []
    errors = []
    paths = sorted(p.relative_to(root).as_posix() for p in (root / "tests").rglob("*.gd")
                   if p.name.endswith(TEST_SUFFIXES))
    counts = Counter(p["path"] for p in programs)
    for path, count in counts.items():
        if count != 1 or not path.startswith("tests/") or not (root / path).is_file():
            errors.append(f"Invalid or duplicate program registration: {path}")
    for path, reason in windowed.items():
        if path not in paths or not str(reason).strip() or path in direct:
            errors.append(f"Invalid renderer exclusion: {path}")
    quarantined, quarantine_errors = validate_quarantine(root, quarantine, paths, windowed, reached)
    errors.extend(quarantine_errors)
    for path in paths:
        wrapper = shared_wrapper(root, path, reached)
        if path in windowed:
            category, evidence = "windowed probe", windowed[path]
        elif (path, "__program__") in reached or any(
                p == path and m.startswith("run") for p, m in reached):
            category, evidence = "full suite", "program" if path in direct else "called by full-suite execution graph"
        elif path in PARTITIONED_PROGRAMS:
            if all((part, "__program__") in reached for part in PARTITIONED_PROGRAMS[path]):
                category, evidence = "full suite", "partitioned headless entrypoint: " + ", ".join(PARTITIONED_PROGRAMS[path])
            else:
                category, evidence = "orphaned", "partitioned entrypoint is missing a program"
                errors.append(f"Unregistered headless test: {path}")
        elif wrapper:
            category, evidence = "full suite", "shared wrapper: " + ", ".join(wrapper)
        elif path in python_coverage:
            category, evidence = "full suite", python_coverage[path]
        elif path in quarantined:
            entry = quarantined[path]
            category, evidence = "quarantined", f"{entry['category']}; {entry['follow_up']}; {entry['reason']} ({entry['evidence_log']})"
        else:
            category, evidence = "orphaned", "no executed entry point"
            errors.append(f"Unregistered headless test: {path}")
        rows.append({"path": path, "classification": category, "evidence": evidence})
    return rows, errors


def validate_quarantine(root, entries, paths, windowed, reached):
    """Exact, owned exceptions; evidence paths refer to retained proof artifacts.

    Logs need not exist on a fresh checkout. Slow mode creates new local logs;
    missing/empty fields and paths outside the project are always errors.
    """
    valid, errors = {}, []
    if not isinstance(entries, list):
        return valid, ["Invalid quarantine: expected a list"]
    seen = set()
    for entry in entries:
        if not isinstance(entry, dict):
            errors.append("Invalid quarantine entry: expected an object")
            continue
        path = entry.get("path", "<missing>")
        missing = [field for field in QUARANTINE_FIELDS
                   if not isinstance(entry.get(field), str) or not entry[field].strip()]
        if missing:
            errors.append(f"Incomplete quarantine entry: {path} (missing {', '.join(missing)})")
            continue
        issue = ""
        if path in seen or path not in paths:
            issue = "missing test or duplicate path"
        elif path in windowed or (path, "__program__") in reached or any(
                p == path and m.startswith("run") for p, m in reached) or shared_wrapper(root, path, reached):
            issue = "already registered or windowed"
        elif entry["follow_up"] not in QUARANTINE_OWNERS.get(entry["category"], set()):
            issue = "unknown category or follow-up owner"
        elif not project_relative_path(entry["evidence_log"]):
            issue = "evidence_log must be a project-relative path"
        entrypoint = entry.get("entrypoint", path)
        if not issue and entrypoint != path:
            graph = execution_graph(root, [], [entrypoint]) if entrypoint in paths else set()
            if not any(p == path and m.startswith("run") for p, m in graph):
                issue = "entrypoint does not execute the quarantined suite"
        if not issue and path.endswith("_suite.gd") and entrypoint == path:
            issue = "library suite requires an executable entrypoint"
        seen.add(path)
        if issue:
            errors.append(f"Invalid quarantine entry: {path} ({issue})")
        else:
            valid[path] = entry
    return valid, errors


def project_relative_path(path):
    return bool(path and "\\" not in path and ":" not in path and
                not path.startswith("/") and ".." not in path.split("/") and
                posixpath.normpath(path) == path and path != ".")


def run_program(program: dict, root: Path, output: Path) -> dict:
    path = program["path"]
    log = output / (path.removeprefix("tests/").replace("/", "_") + ".log")
    started = time.monotonic()
    commands = []
    with tempfile.TemporaryDirectory(prefix="test-program-", dir=output) as temp:
        temp = Path(temp)
        mode = program.get("mode", "script")
        commands = fixture_stages(root, program, temp)
        logs = []
        exit_code = 0
        for project, script, args in commands:
            cmd = [sys.executable, str(root / "tools/godot_task_runner.py"), "--project", str(project),
                   "--task-id", os.environ.get("LABYRINTH_TASK_ID", "qa-08"), "--timeout",
                   str(PACK_TIMEOUT_SECONDS if mode.endswith("pack") else PROGRAM_TIMEOUT_SECONDS),
                   "--stream", "--", os.environ.get("GODOT", "godot"),
                   "--headless", "--path", str(project)]
            if script:
                cmd += ["--script", script]
            if args:
                cmd += (["--"] if script else []) + args
            result = subprocess.run(cmd, cwd=root, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                                    text=True, encoding="utf-8", errors="replace")
            logs.append(result.stdout)
            if result.returncode:
                exit_code = result.returncode
                break
        log.write_text("\n".join(logs), encoding="utf-8")
    return {"path": path, "exit": exit_code, "seconds": round(time.monotonic() - started, 3), "log": str(log)}


def check_quarantine(root: Path, output: Path, execute=run_program) -> tuple[list[dict], list[str]]:
    """Re-run every quarantined assertion, sharing only explicit suite wrappers."""
    entries = read_json(root, QUARANTINE_MANIFEST, [])
    entrypoints = sorted({entry.get("entrypoint", entry["path"]) for entry in entries})
    with ThreadPoolExecutor(max_workers=SUPPLEMENTAL_WORKERS) as pool:
        results = list(pool.map(lambda path: execute(program_for_path(root, path), root, output), entrypoints))
    by_path = {result["path"]: result for result in results}
    rows, errors = [], []
    for entry in entries:
        entrypoint = entry.get("entrypoint", entry["path"])
        result = dict(by_path[entrypoint], path=entry["path"], entrypoint=entrypoint,
                      follow_up=entry["follow_up"])
        rows.append(result)
        if result["exit"] == 0:
            errors.append(f"Quarantined test now passes; register it and remove quarantine: {entry['path']}")
    return rows, errors


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--project", type=Path, default=ROOT)
    parser.add_argument("--json", type=Path)
    parser.add_argument("--markdown", type=Path)
    runs = parser.add_mutually_exclusive_group()
    runs.add_argument("--run-orphans", action="store_true")
    runs.add_argument("--check-quarantine", action="store_true",
                      help="slow guard: fail if any quarantined program now passes")
    parser.add_argument("--output-dir", type=Path)
    args = parser.parse_args(argv)
    root = args.project.resolve()
    rows, errors = audit(root)
    if args.json:
        args.json.write_text(json.dumps({"tests": rows, "errors": errors}, indent=2) + "\n", encoding="utf-8")
    if args.markdown:
        args.markdown.write_text("| Script | Classification | Evidence |\n|---|---|---|\n" + "".join(
            f"| `{r['path']}` | {r['classification']} | {r['evidence']} |\n" for r in rows), encoding="utf-8")
    if args.run_orphans or args.check_quarantine:
        if args.output_dir is None:
            parser.error("--output-dir is required when running tests")
        output = args.output_dir.resolve()
        output.mkdir(parents=True, exist_ok=True)
        if errors and not args.run_orphans:
            print("\n".join(errors))
            return 1
        if args.check_quarantine:
            started = time.monotonic()
            results, errors = check_quarantine(root, output)
            for result in results:
                print("QUARANTINE %s: %s (exit %d; %.3f seconds; %s; %s)" % (
                    result["path"], "NOW PASSING" if result["exit"] == 0 else "STILL FAILING",
                    result["exit"], result["seconds"], result["follow_up"], result["log"]), flush=True)
            (output / "results.json").write_text(json.dumps(results, indent=2) + "\n", encoding="utf-8")
            for error in errors:
                print(error)
            programs_count = len({r["entrypoint"] for r in results})
            print("QUARANTINE RUNTIME: %.3f seconds (%d workers)" % (time.monotonic() - started, SUPPLEMENTAL_WORKERS))
            print("QUARANTINE CHECK: %s (%d entries; %d programs; %d now passing)" % (
                "FAIL" if errors else "PASS", len(results), programs_count, len(errors)))
            return int(bool(errors))
        programs = [program_for_path(root, r["path"]) for r in rows if r["classification"] == "orphaned"
                    and not r["path"].endswith("_suite.gd")]
        results = []
        started = time.monotonic()
        with ThreadPoolExecutor(max_workers=SUPPLEMENTAL_WORKERS) as pool:
            for result in pool.map(lambda program: run_program(program, root, output), programs):
                results.append(result)
                print("SUPPLEMENTAL %s: %s (%.3f seconds; %s)" % (
                    result["path"], "PASS" if result["exit"] == 0 else "FAIL", result["seconds"], result["log"]), flush=True)
                if result["exit"]:
                    print(Path(result["log"]).read_text(encoding="utf-8"), flush=True)
        (output / "results.json").write_text(json.dumps(results, indent=2) + "\n", encoding="utf-8")
        print("SUPPLEMENTAL RUNTIME: %.3f seconds (%d workers; %.3f process seconds)" % (
            time.monotonic() - started, SUPPLEMENTAL_WORKERS, sum(r["seconds"] for r in results)))
        return int(any(r["exit"] for r in results))
    for error in errors:
        print(error)
    counts = Counter(r["classification"] for r in rows)
    print("TEST REGISTRATION AUDIT: %s (%d scripts; %s)" % (
        "FAIL" if errors else "PASS", len(rows), ", ".join(f"{k}={v}" for k, v in sorted(counts.items()))))
    return int(bool(errors))


def program_for_path(root: Path, path: str) -> dict:
    program = {"path": path}
    if path.endswith("_pack_test.gd"):
        program["mode"] = "cutout_pack" if "build|verify" in source(root, path) else "roster_pack"
    elif path == "tests/demo_capture_settings_test.gd":
        program["mode"] = "capture_settings"
    return program


if __name__ == "__main__":
    raise SystemExit(main())
