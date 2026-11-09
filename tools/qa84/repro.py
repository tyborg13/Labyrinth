#!/usr/bin/env python3
"""Loop isolated real-scene quits; record signals and newly created macOS reports."""
from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import time

PROJECT = Path(__file__).resolve().parents[2]
DEFAULT_ITERATIONS = 30
LAUNCH_TIMEOUT_SECONDS = 180
REPORT_SETTLE_SECONDS = 5.0  # CrashReporter may publish after the process exits.
ARMED_MARKER = "QA84 QUIT PROBE: armed"


def crash_reports(directory: Path) -> set[Path]:
    return {path for pattern in ("Godot-*.ips", "Escape the Umbra*.ips")
            for path in directory.glob(pattern)}


def exit_signal(code: int) -> int | None:
    # The mandatory runner propagates the engine's negative subprocess code
    # through sys.exit; POSIX shells expose that as 256 - signal.
    return -code if code < 0 else (256 - code if 256 - 31 <= code <= 255 else None)


def runner_pid(stdout: str) -> int | None:
    match = re.search(r"^\s+run: qa-84-\d+-(\d+)\s*$", stdout, re.M)
    return int(match[1]) if match else None


def attribute_reports(reports: list[str], runner_pids: set[int]) -> dict:
    owned, other, unknown = [], [], []
    for name in reports:
        try:
            lines = Path(name).read_text().splitlines()
            # Modern .ips files have one metadata JSON line then a JSON body.
            report = json.loads("\n".join(lines[1:]))
            parent = int(report["parentPid"])
        except (OSError, ValueError, KeyError, TypeError):
            unknown.append(name)
            continue
        (owned if parent in runner_pids else other).append(name)
    return dict(owned_crash_reports=owned, other_process_crash_reports=other,
                unattributed_crash_reports=unknown)


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output-dir", type=Path, required=True)
    parser.add_argument("--iterations", type=int, default=DEFAULT_ITERATIONS)
    parser.add_argument("--headless", action="store_true")
    parser.add_argument("--combat", action="store_true", help="Quit in live combat instead of demo-incomplete defeat")
    parser.add_argument("--godot", default="godot")
    parser.add_argument("--project", type=Path, default=PROJECT, help="Optional baseline source snapshot")
    parser.add_argument("--app", type=Path, help="Instrumented release .app from build_release_probe.py")
    parser.add_argument("--reports-dir", type=Path,
                        default=Path.home() / "Library/Logs/DiagnosticReports")
    args = parser.parse_args(argv)
    if args.iterations < 1:
        parser.error("--iterations must be positive")
    output = args.output_dir.resolve()
    output.mkdir(parents=True, exist_ok=True)
    (output / ".gdignore").touch()
    executable = args.godot
    if args.app:
        import plistlib
        app = args.app.resolve()
        with (app / "Contents/Info.plist").open("rb") as source:
            executable = str(app / "Contents/MacOS" / plistlib.load(source)["CFBundleExecutable"])
    before = crash_reports(args.reports_dir)
    rows = []
    environment = os.environ.copy()
    environment["LABYRINTH_DEMO"] = "1"
    for index in range(args.iterations):
        command = [sys.executable, str(PROJECT / "tools/godot_task_runner.py"),
                   "--project", str(PROJECT), "--task-id", "qa-84", "--stream",
                   "--godot-home-root", str(output / "homes"), "--timeout", str(LAUNCH_TIMEOUT_SECONDS),
                   "--", executable]
        if args.headless:
            command.append("--headless")
        if not args.app:
            command += ["--path", str(args.project.resolve()), "--script", "res://tools/qa84/quit_entry.gd"]
        command += ["--audio-driver", "Dummy"]
        if args.combat:
            command += ["--", "--combat"]
        started = time.monotonic()
        result = subprocess.run(command, cwd=PROJECT, env=environment,
                                stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
        log = output / f"launch-{index + 1:02d}.log"
        log.write_text(result.stdout)
        row = dict(iteration=index + 1, returncode=result.returncode,
                   exit_signal=exit_signal(result.returncode), armed=ARMED_MARKER in result.stdout,
                   runner_pid=runner_pid(result.stdout),
                   cleanup_observed="QA84 QUIT CLEANUP: released=true pending=false" in result.stdout,
                   elapsed_seconds=round(time.monotonic() - started, 3), log=str(log), command=command)
        rows.append(row)
        print("QA84 LAUNCH %d: exit=%d signal=%s armed=%s" %
              (index + 1, result.returncode, row["exit_signal"], row["armed"]), flush=True)
        # Launch/parser failures are not quit repros. Stop instead of repeating.
        if not row["armed"]:
            break
    if not args.headless or any(row["exit_signal"] for row in rows):
        time.sleep(REPORT_SETTLE_SECONDS)
    reports = sorted(str(path) for path in crash_reports(args.reports_dir) - before)
    attribution = attribute_reports(reports, {row["runner_pid"] for row in rows if row["runner_pid"] is not None})
    aborted = sum(row["exit_signal"] == 6 for row in rows)
    failed = sum(row["returncode"] != 0 or not row["armed"] for row in rows)
    summary = dict(headless=args.headless, app=str(args.app) if args.app else None,
                   requested_iterations=args.iterations, launches=len(rows), aborts=aborted,
                   failures=failed, new_crash_reports=reports, results=rows, **attribution)
    (output / "summary.json").write_text(json.dumps(summary, indent=2) + "\n")
    print(f"QA84 REPRO RESULT: launches={len(rows)}/{args.iterations} aborts={aborted} failures={failed} new_reports={len(reports)} owned_reports={len(attribution['owned_crash_reports'])} unattributed_reports={len(attribution['unattributed_crash_reports'])}")
    return int(failed > 0 or bool(attribution['owned_crash_reports']) or
               bool(attribution['unattributed_crash_reports']) or len(rows) != args.iterations)


if __name__ == "__main__":
    raise SystemExit(main())
