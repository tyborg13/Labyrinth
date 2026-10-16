#!/usr/bin/env python3
"""Task-local validation, Movie Maker capture and deterministic take comparison."""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[2]
DIRECTOR = ROOT / "tools/demo_clips/clips.json"
PROTECTED = ROOT / "spec/peer_benchmark/staged/demo-01/clips.json"
OUTPUT = ROOT / "output/demo-clips-2026-10-15"
PROCESS_TIMEOUT_S = 300  # Host watchdog only; no authored timing.
GUI_LEASE_TIMEOUT_S = 30
sys.path.insert(0, str(ROOT))


def clips():
    if DIRECTOR.read_bytes() != PROTECTED.read_bytes():
        raise ValueError("Protected director data differs from the byte-for-byte import")
    return [clip for reel in json.loads(DIRECTOR.read_text())["reels"] for clip in reel["clips"]]


RECORDING_CLIP_FIELDS = ("id", "enemies", "traps", "forced_intents", "actions", "combat_speed")


def recording_director(director):
    """Only consumed capture inputs; captions and reel composition are encoding inputs."""
    return {"defaults": director["defaults"], "clips": [
        {key: clip[key] for key in RECORDING_CLIP_FIELDS if key in clip}
        for reel in director["reels"] for clip in reel["clips"]]}


def recording_director_hash(path=None):
    value = recording_director(json.loads((path or DIRECTOR).read_text()))
    return hashlib.sha256(json.dumps(value, sort_keys=True, separators=(",", ":"), ensure_ascii=False).encode()).hexdigest()


def hashes():
    paths = [DIRECTOR, PROTECTED, ROOT / "project.godot",
             ROOT / "tests/sfx_sync_sources.gd", ROOT / "tests/sfx_sync_pacing.gd"]
    if (ROOT / "override.cfg").is_file(): paths.append(ROOT / "override.cfg")
    for folder in ("scripts", "scenes", "data", "tools/demo_clips", "fonts"):
        paths += [p for p in (ROOT / folder).rglob("*") if p.is_file() and p.suffix in {".gd", ".tscn", ".json", ".py", ".ttf", ".tres", ".import", ".gdshader"}]
    # Audio/art provenance is captured too. Never change/import their values.
    paths += [p for p in (ROOT / "assets").rglob("*") if p.is_file() and p.suffix in {".png", ".ogg", ".wav", ".tres", ".import"}]
    return {str(p.relative_to(ROOT)): (recording_director_hash(p) if p in (DIRECTOR, PROTECTED)
            else hashlib.sha256(p.read_bytes()).hexdigest()) for p in sorted(set(paths))}


def canonical_events(report):
    # Headless repeat runs remain exact; native comparison has its own tolerance.
    return {key: report[key] for key in ("clip", "fps", "start_frame", "end_frame", "events", "frames", "errors", "director_sha256")}


def compare(left: Path, right: Path):
    a, b = json.loads(left.read_text()), json.loads(right.read_text())
    if canonical_events(a) != canonical_events(b):
        raise ValueError(f"DETERMINISM FAIL: {left} != {right}")
    return a


def command(clip_id: str, directory: Path, recording: bool):
    project = str(directory / "capture-project") if recording else "."
    cmd = [sys.executable, "tools/godot_task_runner.py", "--task-id", "demo-01", "--stream", "--", "godot", "--path", project, "--fixed-fps", "60"]
    if recording:
        cmd += ["--resolution", "1920x1080", "--windowed", "--write-movie", str(directory / "movie.avi")]
    else:
        cmd += ["--headless"]
    return cmd + ["res://tools/demo_clips/demo_clip.tscn", "--", f"--clip={clip_id}", f"--output={directory}",
                  f"--recording-director-sha256={recording_director_hash()}"]


def run_all(mode, selected, output):
    failures = []
    results = []
    if mode == "record":
        from tools.demo_clips import recording
        return recording.run(selected, output)
    capture_root = output / "validation" / str(time.time_ns())
    provenance = hashes()
    for clip in selected:
        reports = []
        for take in ("a", "b"):
            directory = capture_root / take / clip["id"]
            directory.mkdir(parents=True, exist_ok=True)
            (directory / ".gdignore").touch()
            if (directory / "events.json").exists():
                raise ValueError(f"Refusing stale take: {directory}; use --output with a fresh directory")
            cmd = command(clip["id"], directory, False)
            print("RUN", " ".join(cmd), flush=True)
            try:
                result = subprocess.run(cmd, cwd=ROOT, capture_output=True, text=True, timeout=PROCESS_TIMEOUT_S)
                (directory / "godot.log").write_text(result.stdout + result.stderr)
                for line in result.stdout.splitlines():
                    if line.startswith(("DEMO CLIP", "DEMO ERROR")): print(line, flush=True)
                if result.returncode:
                    failures.append(f"{clip['id']}/{take}: process exit {result.returncode}")
            except subprocess.TimeoutExpired:
                failures.append(f"{clip['id']}/{take}: process watchdog")
            reports.append(directory / "events.json")
        try:
            report = compare(*reports)
            print(f"DEMO DETERMINISM {clip['id']}: PASS", flush=True)
            results.append({"clip": clip["id"], "deterministic": True, "fixture_valid": report["fixture_valid"], "errors": report["errors"], "logs": [str(p) for p in reports]})
        except (OSError, ValueError, KeyError) as exc:
            failures.append(str(exc))
            results.append({"clip": clip["id"], "deterministic": False})
    if hashes() != provenance: failures.append("Inputs changed during validation/capture; this report cannot authorize recording")
    (output / f"{mode}-report.json").write_text(json.dumps({"mode": mode, "results": results, "failures": failures, "input_hashes": provenance}, indent=2))
    print(f"DEMO {mode.upper()} RESULT: {'FAIL' if failures else 'PASS'} ({len(selected)} clips, {len(failures)} failures)")
    return bool(failures)


def probes(selected, output):
    failures = []
    for clip in selected:
        directory = output / "proof" / clip["id"]
        directory.mkdir(parents=True, exist_ok=True)
        cmd = [sys.executable, "tools/visual_probe_runner.py", "--task-id", "demo-01", "--no-headless",
               "--audio-driver", "Dummy",
               "--timeout", str(PROCESS_TIMEOUT_S), "--expect-size", "1920x1080",
               "--proof-contract", "tools/demo_clips/proof.json", "--result-manifest", str(directory/"proof.json"),
               "tools/demo_clips/probe.gd", "--", "--probe", f"--clip={clip['id']}", f"--output={directory}",
               f"--recording-director-sha256={recording_director_hash()}"]
        result = subprocess.run(cmd, cwd=ROOT)
        if result.returncode: failures.append(clip["id"])
    print(f"DEMO VISUAL PROOF: {'FAIL' if failures else 'PASS'} ({len(selected)} clips)")
    return bool(failures)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("mode", choices=["validate", "record", "compare", "probe"])
    parser.add_argument("--clip", action="append", default=[])
    parser.add_argument("--output", type=Path, default=OUTPUT)
    args = parser.parse_args()
    selected = [c for c in clips() if not args.clip or c["id"] in args.clip]
    if not selected or set(args.clip) - {c["id"] for c in selected}: parser.error("Unknown clip")
    args.output = args.output.resolve()
    if args.mode == "record": return run_all(args.mode, selected, args.output)
    args.output.mkdir(parents=True, exist_ok=True)
    (args.output / ".gitignore").write_text("*\n")
    (args.output / ".gdignore").touch()
    if args.mode == "probe": return probes(selected, args.output)
    if args.mode == "compare":
        from tools.demo_clips import recording
        return recording.compare_all(selected, args.output)
    return run_all(args.mode, selected, args.output)


if __name__ == "__main__":
    raise SystemExit(main())
