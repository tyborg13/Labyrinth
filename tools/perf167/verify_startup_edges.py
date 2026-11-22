#!/usr/bin/env python3
"""Compare settled title, Chronicle and Settings layout with the release worktree."""

import argparse
import json
import os
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
PROBE = ROOT / "tools/perf167/startup_edges.gd"
MARKER = "PERF167 EDGES "
SCENARIOS = (
    "stable",
    "aspect",
    "aspect-controller-after",
    "aspect-reverse",
    "wide-to-narrow",
    "scale-down",
    "scale-up",
    "resize-and-scale",
    "resize-round-trip",
    "viewport-scale-before-stage",
)


def capture(project, scenario, log):
    command = [
        sys.executable, str(ROOT / "tools/godot_task_runner.py"),
        "--task-id", "perf-167", "--project", str(project), "--stream", "--", "godot",
        "--headless", "--path", str(project), "--script", str(PROBE), "--", scenario,
    ]
    with log.open("w") as stream:
        result = subprocess.run(
            command, cwd=ROOT, env={**os.environ, "LABYRINTH_DEMO": "1"},
            stdout=stream, stderr=subprocess.STDOUT, check=False,
        )
    if result.returncode:
        raise RuntimeError(f"Probe exited {result.returncode}. See {log}")
    output = log.read_text()
    if 'ERROR: Condition "!is_inside_tree()"' in output:
        raise RuntimeError(f"Detached control received a viewport callback. See {log}")
    rows = [line.removeprefix(MARKER) for line in output.splitlines() if line.startswith(MARKER)]
    if len(rows) != 1:
        raise ValueError(f"Expected one layout snapshot in {log}")
    return json.loads(rows[0])


def differences(before, after, key=""):
    if isinstance(before, dict) and isinstance(after, dict):
        for field in sorted(before.keys() | after.keys()):
            path = f"{key}.{field}" if key else field
            if field not in before or field not in after:
                yield f"{path} is present on only one side"
            else:
                yield from differences(before[field], after[field], path)
    elif before != after:
        yield f"{key}: {before!r} != {after!r}"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--baseline", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    parser.add_argument("--scenario", choices=SCENARIOS, action="append", help="Run only these fixture cases")
    args = parser.parse_args()
    baseline = args.baseline.resolve()
    if baseline == ROOT:
        parser.error("Baseline must be a separate release worktree")
    args.output.mkdir(parents=True, exist_ok=False)
    results = {}
    for scenario in args.scenario or SCENARIOS:
        before = capture(baseline, scenario, args.output / f"{scenario}-baseline.log")
        after = capture(ROOT, scenario, args.output / f"{scenario}-candidate.log")
        mismatches = list(differences(before, after))
        (args.output / f"{scenario}-baseline.json").write_text(json.dumps(before, indent=2) + "\n")
        (args.output / f"{scenario}-candidate.json").write_text(json.dumps(after, indent=2) + "\n")
        results[scenario] = mismatches
        status = "FAIL" if mismatches else "PASS"
        print(f"PERF167 STARTUP EDGES {scenario}: {status} ({len(mismatches)} differences)", flush=True)
    (args.output / "summary.json").write_text(json.dumps(results, indent=2) + "\n")
    print(args.output / "summary.json")
    return 1 if any(results.values()) else 0


if __name__ == "__main__":
    raise SystemExit(main())
