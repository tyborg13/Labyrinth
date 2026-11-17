#!/usr/bin/env python3
"""Release-data, deadline-bounded Guardian/dragon measurement. No game writes."""
from __future__ import annotations

import argparse
import base64
from concurrent.futures import ThreadPoolExecutor
import gzip
import json
import os
from pathlib import Path
import shlex
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tools"))
from run_curve import policy_hash, sha256, write_scores

WORKERS = 4
LOADOUTS = 8
TARGET_REPEATS = 8
FALLBACK_REPEATS = 6
BATCH_FIGHTS = 8
WALL_SECONDS = 90 * 60
REPORT_RESERVE_SECONDS = 90
PROJECTION_MARGIN = 1.15
PLANNING_TIMEOUT_SECONDS = 300


def write_json(path: Path, value) -> None:
    path.write_text(json.dumps(value, indent=2, sort_keys=True) + "\n")


def archive(path: Path, rows: list[dict]) -> None:
    with path.open("wb") as raw, gzip.GzipFile(filename="", fileobj=raw, mode="wb", mtime=0) as stream:
        for row in rows:
            stream.write((json.dumps(row, sort_keys=True, separators=(",", ":")) + "\n").encode())


def command(script: str, args: list[str], timeout: float) -> list[str]:
    return [sys.executable, "tools/godot_task_runner.py", "--task-id", "meas-07", "--timeout", str(timeout),
            "--stream", "--", "godot", "--headless", "--path", ".", "--script", script, "--", *args]


def execute(cmd: list[str], log: Path, marker: str) -> dict:
    started = time.time()
    with log.open("w") as stream:
        result = subprocess.run(cmd, cwd=ROOT, env={**os.environ, "LABYRINTH_CEL_LOOK": "off"},
                                stdout=stream, stderr=subprocess.STDOUT)
    record = {"command": shlex.join(cmd), "log": str(log), "started_unix": started,
              "elapsed_seconds": time.time() - started, "returncode": result.returncode}
    write_json(log.with_suffix(".command.json"), record)
    if result.returncode or marker not in log.read_text():
        raise RuntimeError(f"Worker failed: {log}; exit={result.returncode}")
    return record


def collect(scratch: Path, output: Path, reuse: bool, archived: bool = False) -> None:
    output.mkdir(parents=True, exist_ok=True)
    if (output / "runs.jsonl.gz").exists():
        raise RuntimeError("Use a fresh output directory; do not overwrite measurements")
    scratch.mkdir(parents=True, exist_ok=True)
    started = time.time()
    if archived:
        reference = ROOT / "spec/peer_benchmark/encounter_redesign/measurements/run_curve_2026-11"
        if not (scratch / "recovery_started.json").exists():
            write_json(scratch / "recovery_started.json", {"started_unix": started})
        with gzip.open(reference / "dragons_loadouts.jsonl.gz", "rt") as stream:
            for entry in map(json.loads, stream):
                if entry["ladder_seed"] <= LOADOUTS:
                    payload = base64.b64decode(entry["typed_payload_base64"])
                    path = scratch / f"entry-{entry['ladder_seed']}-{entry['section']}.bin"
                    if path.exists() and path.read_bytes() != payload:
                        raise RuntimeError("Existing loadout differs from the provided archive")
                    path.write_bytes(payload)
        with gzip.open(reference / "ladder_runs.jsonl.gz", "rt") as stream:
            for ladder in map(json.loads, stream):
                if ladder["seed"] <= LOADOUTS:
                    write_json(scratch / f"ladder-{ladder['seed']}.json", ladder)
        (scratch / "scores.json").write_bytes((reference / "ladder_card_scores.json").read_bytes())
    if reuse or archived:
        started = json.loads((scratch / "recovery_started.json").read_text())["started_unix"]
    deadline = started + WALL_SECONDS - REPORT_RESERVE_SECONDS
    frozen = policy_hash()
    source_paths = [*sorted((ROOT / "scripts").rglob("*.gd")), *sorted((ROOT / "data").rglob("*.json")),
                    ROOT / "tools/encounter_bot.gd", ROOT / "tools/run_curve.gd", ROOT / "tools/run_curve_ladder.gd",
                    ROOT / "tools/run_curve_choices.gd", ROOT / "tools/run_curve_combat.gd", ROOT / "tools/card_heuristic.py"]
    hashes = {str(p.relative_to(ROOT)): sha256(p) for p in source_paths}
    head = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip()
    release = subprocess.check_output(["git", "rev-parse", "codex/release"], cwd=ROOT, text=True).strip()
    release_base = subprocess.check_output(["git", "merge-base", "HEAD", "codex/release"], cwd=ROOT, text=True).strip()
    if head != release_base:
        raise RuntimeError("Measurement HEAD must be the owner-prepared release baseline")
    contract = {"task": "meas-07", "risk_tier": "standard", "source_head": head, "release_head": head,
                "release_ref_at_collection": release,
                "policy_sha256": frozen, "source_sha256": hashes, "started_unix": started,
                "deadline_unix": deadline, "wall_seconds_limit": WALL_SECONDS, "max_workers": WORKERS,
                "loadout_seeds": list(range(1, LOADOUTS + 1)), "target_repeats": TARGET_REPEATS,
                "fallback_repeats": FALLBACK_REPEATS, "batch_fights": BATCH_FIGHTS,
                "report_reserve_seconds": REPORT_RESERVE_SECONDS, "projection_margin": PROJECTION_MARGIN,
                "scores_sha256": sha256(scratch / "scores.json") if reuse or archived else None,
                "loadout_mode": "archived_dragon_entry" if archived else "section_entry",
                "loadout_archive_sha256": sha256(ROOT / "spec/peer_benchmark/encounter_redesign/measurements/run_curve_2026-11/dragons_loadouts.jsonl.gz") if archived else None,
                "acceptance": ["Each Guardian and dragon in eight native production-map placements",
                               "Standard controls paired by section, tier and ladder-entry loadout",
                               "64 fights/cohort, or 48 if projected wall time exceeds 90 minutes",
                               "Wilson intervals, median turns, gross Health loss and boss Health at hero death",
                               "Comparison-only report, gzipped JSONL, exact commands and elapsed wall time"],
                "inspection": "Not applicable: offline headless measurement; no player-facing changes",
                "reused_in_session_recovery": reuse}
    write_json(output / "contract.json", contract)
    if not reuse and not archived:
        write_scores(scratch / "scores.json")
        def recover(seed: int) -> dict:
            return execute(command("tools/meas07/recover.gd", ["--seed", str(seed), "--directory", str(scratch),
                           "--scores", str(scratch / "scores.json")], max(1, deadline - time.time())),
                           scratch / f"recover-{seed}.log", "MEAS07_RECOVERY_PASS")
        with ThreadPoolExecutor(max_workers=WORKERS) as pool:
            list(pool.map(recover, range(1, LOADOUTS + 1)))
    for seed in range(1, LOADOUTS + 1):
        ladder = json.loads((scratch / f"ladder-{seed}.json").read_text())
        if not ladder["completed_ladder"] or ladder["policy_sha256"] != frozen:
            raise RuntimeError("Incomplete or changed-policy ladder recovery")
    execute(command("tools/meas07/measure.gd", ["--native-plan", "--directory", str(scratch)], PLANNING_TIMEOUT_SECONDS),
            scratch / "plan.log", "MEAS07_NATIVE_PLAN_PASS")
    plan = json.loads((scratch / "plan.json").read_text())
    cells = sorted({r["cell"] for r in plan})
    if len(cells) != 24 or any(sum(t["cell"] == c for t in plan) != LOADOUTS for c in cells):
        raise RuntimeError("Expected exactly eight loadouts in each of 24 native-placement cohorts")
    for index, task in enumerate(plan):
        task["task_file"] = str(scratch / f"task-{index}.json")
        write_json(Path(task["task_file"]), task)
    batch_index = 0

    def run_jobs(jobs: list[dict]) -> None:
        nonlocal batch_index
        batches = []
        for offset in range(0, len(jobs), BATCH_FIGHTS):
            path = scratch / f"batch-{batch_index}.json"
            batch_index += 1
            write_json(path, jobs[offset:offset + BATCH_FIGHTS])
            batches.append(path)
        def batch(path: Path):
            if time.time() >= deadline:
                return
            try:
                return execute(command("tools/meas07/measure.gd", ["--jobs", str(path), "--deadline-unix", str(deadline)],
                                       max(1, deadline - time.time())), path.with_suffix(".log"), "MEAS07_BATCH_PASS")
            except RuntimeError:
                if time.time() < deadline:
                    raise
                print(f"MEAS07_DEADLINE partial_batch={path.name}", flush=True)
        with ThreadPoolExecutor(max_workers=WORKERS) as pool:
            list(pool.map(batch, batches))

    def jobs_for(repeat: int, selected: list[dict]) -> list[dict]:
        return [{"task": t["task_file"], "repeat": repeat,
                 "output": str(scratch / f"fight-{t['cell']}-l{t['ladder_seed']}-r{repeat}.jsonl")}
                for t in selected]

    pilot = [t for t in plan if t["ladder_seed"] == 1]
    pilot_started = time.time()
    run_jobs(jobs_for(0, pilot))
    pilot_elapsed = time.time() - pilot_started
    projected_remaining_64 = pilot_elapsed / len(pilot) * (len(plan) * TARGET_REPEATS - len(pilot)) * PROJECTION_MARGIN
    repeats = FALLBACK_REPEATS if projected_remaining_64 > deadline - time.time() else TARGET_REPEATS
    contract.update({"pilot_fights": len(pilot), "pilot_elapsed_seconds": pilot_elapsed,
                     "projected_remaining_64_seconds": projected_remaining_64, "selected_repeats": repeats,
                     "selected_n": repeats * LOADOUTS})
    write_json(output / "contract.json", contract)
    print(f"MEAS07_BUDGET selected_n={repeats * LOADOUTS} pilot_seconds={pilot_elapsed:.1f} projected_remaining_64={projected_remaining_64:.1f}", flush=True)
    run_jobs(jobs_for(0, [t for t in plan if t["ladder_seed"] != 1]))
    for repeat in range(1, repeats):
        if time.time() >= deadline:
            break
        run_jobs(jobs_for(repeat, plan))
        print(f"MEAS07_REPEAT_DONE repeat={repeat} elapsed_seconds={time.time()-started:.1f}", flush=True)
    rows = [json.loads(path.read_text()) for path in sorted(scratch.glob("fight-*.jsonl")) if path.stat().st_size]
    identities = {(r["cell"], r["ladder_seed"], r["repeat"]) for r in rows}
    if len(identities) != len(rows):
        raise RuntimeError("Duplicate fights")
    if any(r["policy_sha256"] != frozen or r["hp_before"] != r["max_hp"] for r in rows):
        raise RuntimeError("Policy or full-Health protocol mismatch")
    if any(sha256(ROOT / path) != digest for path, digest in hashes.items()):
        raise RuntimeError("Production sources changed during measurement")
    archive(output / "runs.jsonl.gz", rows)
    inputs = []
    for task in plan:
        path = Path(task["input_file"])
        if sha256(path) != task["input_sha256"]:
            raise RuntimeError("Constructor payload changed")
        inputs.append({**{k: v for k, v in task.items() if k not in ("task_file", "input_file")},
                       "typed_payload_base64": base64.b64encode(path.read_bytes()).decode()})
    archive(output / "inputs.jsonl.gz", inputs)
    archive(output / "ladders.jsonl.gz", [json.loads((scratch / f"ladder-{s}.json").read_text()) for s in range(1, 9)])
    archive(output / "entry_loadouts.jsonl.gz", [{"ladder_seed": s, "section": section,
            "sha256": sha256(scratch / f"entry-{s}-{section}.bin"),
            "typed_payload_base64": base64.b64encode((scratch / f"entry-{s}-{section}.bin").read_bytes()).decode()}
            for s in range(1, 9) for section in range(6)])
    commands = [json.loads(p.read_text()) for p in sorted(scratch.glob("*.command.json"))]
    commands += [{"command": shlex.join(json.loads(p.read_text())), "phase": "adopted recovery"}
                 for p in sorted(scratch.glob("command-recover-*.json"))]
    if reuse:
        first_command = command("tools/meas07/recover.gd", ["--seed", "1", "--directory", str(scratch),
                                "--scores", str(scratch / "scores.json")], 1200)
        first_command[0] = "python3"
        commands.append({"command": shlex.join(first_command), "phase": "adopted recovery seed 1"})
    write_json(output / "commands.json", commands)
    archive(output / "worker_logs.jsonl.gz", [{"path": str(p), "text": p.read_text()}
                                             for p in sorted(scratch.glob("*.log"))])
    tool_paths = [*sorted((ROOT / "tools/meas07").glob("*.py")), *sorted((ROOT / "tools/meas07").glob("*.gd"))]
    contract["measurement_tool_sha256"] = {str(p.relative_to(ROOT)): sha256(p) for p in tool_paths}
    contract["elapsed_seconds"] = time.time() - started
    contract["completed_fights"] = len(rows)
    contract["complete"] = len(rows) == len(plan) * repeats
    contract["artifact_sha256"] = {p.name: sha256(p) for p in output.glob("*.gz")}
    write_json(output / "contract.json", contract)
    from report import write_report
    write_report(output)
    print(f"MEAS07_SAMPLE_{'PASS' if contract['complete'] else 'INCOMPLETE'} cells=24 n={repeats*8} fights={len(rows)} wall_seconds={contract['elapsed_seconds']:.1f}", flush=True)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--scratch-dir", type=Path, required=True)
    parser.add_argument("--output-dir", type=Path, default=ROOT / "spec/peer_benchmark/encounter_redesign/measurements/bosses_2026-11")
    parser.add_argument("--reuse-recovery", action="store_true", help="Adopt this session's already-running, same-source recovery")
    parser.add_argument("--archived-loadouts", action="store_true", help="Use the existing dragon tool's saved ladder-entry snapshots")
    args = parser.parse_args()
    collect(args.scratch_dir.resolve(), args.output_dir.resolve(), args.reuse_recovery, args.archived_loadouts)
