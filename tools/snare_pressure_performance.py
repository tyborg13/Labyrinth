#!/usr/bin/env python3
"""Repeat the review's headless real-iteration CPU sweep, without Git mutations.

The base is an archived source snapshot inside this worktree, not a checkout.
Both sides use the same turn-three fixture adapter and pointer workload. This
is CPU/_draw evidence only; it cannot measure native renderer frame pacing.
"""
import argparse
import hashlib
import io
import json
from pathlib import Path
import subprocess
import sys
import tarfile
import tempfile

ROOT = Path(__file__).resolve().parents[1]
BASE_REVISION = "d96eadf4f"
PROBE = "tests/snare_pressure_frame_benchmark.gd"


def run(side: str, output: Path, fixtures: Path = None) -> int:
    output = output.resolve()
    output.parent.mkdir(parents=True, exist_ok=True)
    fixture = (ROOT / "tests/helpers/snare_pressure_frame_fixture.gd").read_bytes()
    with tempfile.TemporaryDirectory(prefix=".spx06-frame-", dir=ROOT) as temporary:
        project = ROOT
        if side == "base":
            project = Path(temporary)
            archive = subprocess.check_output([
                "git", "archive", BASE_REVISION, "project.godot", "scripts", "scenes",
                "data", "themes", "shaders", "addons", "tools/snare_inspection.gd",
            ], cwd=ROOT)
            with tarfile.open(fileobj=io.BytesIO(archive)) as source:
                source.extractall(project)  # Only this repository's trusted Git archive.
            for directory in ("assets", "fonts"):
                (project / directory).symlink_to(ROOT / directory, target_is_directory=True)
            (project / ".godot").mkdir()
            (project / ".godot/imported").symlink_to(ROOT / ".godot/imported", target_is_directory=True)
            (project / "tests").mkdir()
            (project / PROBE).write_bytes((ROOT / PROBE).read_bytes())
            (project / "tests/helpers").mkdir()
            (project / "tests/helpers/snare_pressure_frame_fixture.gd").write_bytes(fixture)
        command = [
            sys.executable, "tools/godot_task_runner.py", "--task-id", "spx-06",
            "--stream", "--", "godot", "--headless", "--path", str(project),
            "--script", "res://" + PROBE, "--", "--baseline", "--output=" + str(output),
        ]
        if fixtures is not None:
            command.append("--fixtures=" + str(fixtures))
        result = subprocess.run(command, cwd=ROOT, check=False)
        if output.exists():
            report = json.loads(output.read_text())
            report["source"] = {
                "side": side,
                "revision": subprocess.check_output(["git", "rev-parse", BASE_REVISION if side == "base" else "HEAD"], cwd=ROOT, text=True).strip(),
                "uncommitted_diff_sha256": hashlib.sha256(subprocess.check_output(["git", "diff", "HEAD"], cwd=ROOT)).hexdigest() if side == "head" else "",
                "probe_sha256": hashlib.sha256((ROOT / PROBE).read_bytes()).hexdigest(),
                "fixture_adapter_sha256": hashlib.sha256(fixture).hexdigest(),
                "canonical_fixtures": {path.name: hashlib.sha256(path.read_bytes()).hexdigest() for path in sorted(fixtures.glob("*.bin"))} if fixtures else {},
                "measurement": "headless real-iteration CPU including queued CanvasItem draws; no native/GPU claim",
            }
            output.write_text(json.dumps(report, indent=2) + "\n")
        return result.returncode


def compare(base: Path, head: Path) -> None:
    reports = [json.loads(path.read_text()) for path in (base, head)]
    for key in ("probe_sha256", "fixture_adapter_sha256", "canonical_fixtures"):
        if reports[0]["source"][key] != reports[1]["source"][key]:
            raise SystemExit("Unmatched measurement input: " + key)
    print("Headless CPU sweep (ms): biome | base median/p95/max | HEAD median/p95/max | HEAD top draw section (ms)")
    assert len(reports[0]["cases"]) == len(reports[1]["cases"])
    for before, after in zip(reports[0]["cases"], reports[1]["cases"]):
        assert before["case"] == after["case"]
        values = [case["sweep"]["frame_ms"] for case in (before, after)]
        sections = after["render"]["dynamic_draw_frame_top"][0]["section_usec"]
        # Parent sections overlap their children; show the top concrete leaves.
        leaves = {key: value for key, value in sections.items() if key not in {"scene_tiles", "tile_overlays", "effects_and_feedback", "ambient_particles", "unit_huds"}}
        top = sorted(leaves.items(), key=lambda item: item[1], reverse=True)[:3]
        print(after["case"] + " | " + " | ".join("/".join(f"{v[k]:.3f}" for k in ("median", "p95", "max")) for v in values) + " | " + ", ".join(f"{name}={value / 1000:.3f}" for name, value in top))
    print("SPX06 FRAME COMPARISON: CPU evidence only; inspect raw samples, section costs and variance before attribution")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    subparsers = parser.add_subparsers(dest="command", required=True)
    measure = subparsers.add_parser("run")
    measure.add_argument("--side", choices=("base", "head"), required=True)
    measure.add_argument("--output", type=Path, required=True)
    pair = subparsers.add_parser("pair")
    pair.add_argument("--output-dir", type=Path, required=True)
    comparison = subparsers.add_parser("compare")
    comparison.add_argument("base", type=Path)
    comparison.add_argument("head", type=Path)
    args = parser.parse_args()
    if args.command == "run":
        return run(args.side, args.output)
    if args.command == "pair":
        with tempfile.TemporaryDirectory(prefix=".spx06-frame-fixtures-", dir=ROOT) as directory:
            subprocess.run([sys.executable, "tools/godot_task_runner.py", "--task-id", "spx-06", "--stream", "--", "godot", "--headless", "--path", ".", "--script", PROBE, "--", "--export-fixtures=" + directory], cwd=ROOT, check=True)
            paths = [args.output_dir / (side + ".json") for side in ("base", "head")]
            for side, path in zip(("base", "head"), paths):
                result = run(side, path, Path(directory))
                if result:
                    return result
            compare(*paths)
        return 0
    compare(args.base, args.head)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
