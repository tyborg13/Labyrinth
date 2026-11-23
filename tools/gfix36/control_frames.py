#!/usr/bin/env python3
"""Measure control screens from identical, isolated census checkpoints."""

import argparse
from concurrent.futures import ThreadPoolExecutor
import json
import os
from pathlib import Path
import subprocess
import sys


ROOT = Path(__file__).resolve().parents[2]
OUTPUT_ROOT = Path("/private/tmp/labyrinth_codex/gfix-36")
CONTROL_SHOTS = ("combat", "guardian", "dragon", "pre_battle", "event", "victory", "defeat")
FIXTURE_SEED = 7262026
ENGINE_TIMEOUT = 180  # Same headless watchdog as the census.
JOBS = 3
RUNNER = [
    sys.executable, "tools/godot_task_runner.py", "--task-id", "gfix-36", "--stream",
    "--timeout", str(ENGINE_TIMEOUT), "--", "godot", "--headless", "--path", ".", "--script",
]


def run(project, script, args, log, cel_look, marker, run_id=None):
    command = RUNNER.copy()
    if run_id:
        command[2:2] = ["--run-id", run_id]
    env = dict(os.environ, LABYRINTH_CEL_LOOK=cel_look)
    env["PYTHONDONTWRITEBYTECODE"] = "1"
    with log.open("w", encoding="utf-8") as stream:
        result = subprocess.run(
            [*command, str(script), "--", *args], cwd=project, env=env, stdout=stream, stderr=subprocess.STDOUT,
        )
    output = log.read_text(encoding="utf-8")
    row = next((json.loads(line[len(marker):]) for line in reversed(output.splitlines())
                if line.startswith(marker)), {})
    if result.returncode or not row.get("ok"):
        raise RuntimeError(f"{log}: exit {result.returncode}, {row.get('error', 'no successful result')}")
    return row


def measure(project, scenario, output, fixtures, keep_fixtures):
    fixture_file = fixtures / f"{scenario}.json"
    if keep_fixtures:
        row = run(
            project, "tools/inspection_fixture.gd", ["--scenario", scenario, "--seed", str(FIXTURE_SEED)],
            output / f"{scenario}-fixture.log", "off", "INSPECTION_FIXTURE_RESULT ",
            f"{output.parent.name}-gfix-36-control-{scenario}",
        )
        fixture_file.write_text(json.dumps(row), encoding="utf-8")
    fixture = json.loads(fixture_file.read_text(encoding="utf-8"))
    settings = Path(fixture["progression_path"]).with_name("settings.json")
    report = run(
        project, ROOT / "tools/gfix36/control_probe.gd",
        ["--save", fixture["save_path"], "--profile", fixture["progression_path"],
         "--settings", str(settings), "--mode", fixture["mode"],
         "--size", "1920x1080", "--shot", json.dumps({"shot": scenario, "scenario": scenario}),
         "--png", str(output / f"{scenario}.png"), "--dry-run"],
        output / f"{scenario}.log", "all", "CENSUS_RESULT ",
    )
    print(f"GFIX36 CONTROL {scenario} {json.dumps(report['frame'])}", flush=True)
    return report["frame"]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("phase", choices=["before", "after"])
    parser.add_argument("run_id")
    parser.add_argument("--base-project", type=Path, default=ROOT.parent / "scn-02")
    args = parser.parse_args()
    directory = OUTPUT_ROOT / args.run_id
    destination = directory / args.phase
    destination.mkdir(parents=True, exist_ok=False)
    fixtures = directory / "fixtures"
    fixtures.mkdir(exist_ok=True)
    project = args.base_project if args.phase == "before" else ROOT
    with ThreadPoolExecutor(max_workers=JOBS) as pool:
        attempts = {shot: pool.submit(measure, project, shot, destination, fixtures, args.phase == "before")
                    for shot in CONTROL_SHOTS}
        rows = {shot: future.result() for shot, future in attempts.items()}
    (destination / "measurements.json").write_text(json.dumps(rows, indent=2) + "\n", encoding="utf-8")
    if args.phase == "after":
        before = json.loads((directory / "before/measurements.json").read_text(encoding="utf-8"))
        changes = [shot for shot in CONTROL_SHOTS if before[shot] != rows[shot]]
        if changes:
            print(f"GFIX36 CONTROLS: FAIL — changed {', '.join(changes)}")
            return 1
        print(f"GFIX36 CONTROLS: PASS — {len(rows)} exact matches")
    else:
        print(f"GFIX36 CONTROLS: BASELINE — {len(rows)} measured")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
