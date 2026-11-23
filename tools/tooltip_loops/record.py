#!/usr/bin/env python3
"""Director-only deterministic recorder. No artwork is generated or substituted."""
import argparse
import json
import os
from pathlib import Path
import shlex
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[2]
OUTPUT = Path("/private/tmp/labyrinth_codex/tip-05/record")
RECORD_TIMEOUT_SECONDS = 240  # GPU-backed recordings plus production asset warmup.
FPS = 30


def selected_rows(registry, loop_ids):
    rows = registry["loops"]
    if loop_ids is not None:
        rows = rows + registry.get("pending_recordings", [])
    return [row for row in rows
            if not row.get("todo_design") and (loop_ids is None or row["id"] in loop_ids)]


def movie_clock(directory: Path, godot: str) -> Path:
    """Drive the renderer at a fixed rate while the probe reads its own SubViewport."""
    wrapper = directory / "godot-clock.sh"
    wrapper.write_text(
        "#!/bin/sh\nexec " + shlex.quote(godot) + " --write-movie "
        + shlex.quote(str(directory / "clock.avi")) + f' --fixed-fps {FPS} "$@"\n'
    )
    wrapper.chmod(0o755)
    return wrapper


def record_native(args, rows, output, proof_contract, env):
    output.mkdir(parents=True, exist_ok=True)
    loop_ids = ",".join(row["id"] for row in rows)
    with tempfile.TemporaryDirectory(prefix="tip01-clock-") as directory:
        wrapper = movie_clock(Path(directory), args.godot)
        command = [
            "python3", "tools/visual_probe_runner.py", "tools/tooltip_loops/record.gd",
            "--task-id", args.task_id, "--godot", str(wrapper), "--no-headless",
            "--display-driver", "macos", "--audio-driver", "Dummy",
            "--timeout", str(RECORD_TIMEOUT_SECONDS), "--expect-size", "1920x1080",
            "--min-images", str(len(rows) * 3), "--result-manifest", str(output / "manifest.json"),
            "--overwrite-result-manifest",
        ]
        if proof_contract:
            command.extend(["--proof-contract", str(proof_contract)])
        return subprocess.call(
            command, cwd=ROOT, env=dict(env, TIP01_OUT=str(output), TOOLTIP_LOOP_IDS=loop_ids),
        )


def compress_native(output, loops):
    command = [
        "python3", "tools/tooltip_loops/compress.py", "--input-dir", str(output / "raw"),
        "--report", str(output / "compression-report.json"), "--loops", loops,
    ]
    return subprocess.call(command, cwd=ROOT)


def record_independently(args, rows, output, env):
    # Isolate renderer output and proof per loop. The visual runner can keep
    # rejecting failed probes, and a stale raw file cannot pass on a retry.
    contract = json.loads(args.proof_contract.read_text()) if args.proof_contract else None
    output.mkdir(parents=True, exist_ok=True)
    run = Path(tempfile.mkdtemp(prefix="attempt-", dir=output))
    print(f"Recording attempt: {run}", flush=True)
    results, compression = [], []
    for row in rows:
        loop_id = row["id"]
        target = run / loop_id
        target.mkdir()
        proof = None
        if contract is not None:
            images = [
                image for image in contract["required_images"]
                if image["pattern"].startswith(f"{loop_id}_source_")
            ]
            proof = target / "contract.json"
            proof.write_text(json.dumps(dict(contract, required_images=images, min_images=len(images))))
        stage = "recording"
        code = record_native(args, [row], target, proof, env)
        if not code:
            stage = "compression"
            code = compress_native(target, loop_id)
        report = target / "compression-report.json"
        if report.is_file():
            compression.extend(json.loads(report.read_text()))
        results.append({
            "id": loop_id, "ok": code == 0, "stage": stage, "exit_code": code,
            "manifest": str(target / "manifest.json"),
        })
        print(f"TIP01 INSTALL {loop_id}: {'PASS' if not code else f'FAIL ({stage}, exit {code})'}", flush=True)
    installed = sum(result["ok"] for result in results)
    failed = len(results) - installed
    (output / "manifest.json").write_text(json.dumps({"ok": not failed, "attempt": str(run), "loops": results}, indent=2) + "\n")
    (output / "compression-report.json").write_text(json.dumps(compression, indent=2) + "\n")
    print(f"TIP01 INSTALL RESULT: {'FAIL' if failed else 'PASS'} ({installed} installed, {failed} failed)")
    return int(failed > 0)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", default="godot")
    parser.add_argument("--check-only", action="store_true", help="Check the encoder and fixture semantics headlessly")
    parser.add_argument("--loops", help="Comma-separated registry IDs, including pending recordings; default: active loops")
    parser.add_argument("--task-id", default="tip-05", help="Task-local runner identity")
    parser.add_argument("--output-dir", type=Path, default=OUTPUT, help="Task-local recording evidence")
    parser.add_argument("--proof-contract", type=Path, help="Optional exact source-image contract")
    parser.add_argument("--keep-passing", action="store_true",
                        help="Record, validate and install each selected loop independently")
    args = parser.parse_args()
    registry = json.loads((ROOT / "data/tooltip_loops.json").read_text())
    selected_ids = set(args.loops.split(",")) if args.loops else None
    rows = selected_rows(registry, selected_ids)
    if selected_ids is not None and selected_ids != {row["id"] for row in rows}:
        parser.error("Unknown or TODO_DESIGN loop selected")
    if args.keep_passing and not args.loops:
        parser.error("--keep-passing requires explicit --loops")
    if args.check_only:
        from webp_encode import Encoder
        Encoder() # Fail before a native recording if the offline encoder ABI is unavailable.
        return subprocess.call(
            ["python3", "tools/godot_task_runner.py", "--task-id", args.task_id, "--stream", "--",
             args.godot, "--headless", "--path", ".", "--script", "tools/tooltip_loops/record.gd", "--", "--semantics-only"],
            cwd=ROOT, env=dict(os.environ, TOOLTIP_LOOP_IDS=args.loops or ""),
        )
    env = dict(os.environ, LABYRINTH_CEL_LOOK="all")
    output = args.output_dir.resolve()
    env["TIP01_COMMIT"] = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip()
    env["TIP01_DIRTY"] = subprocess.check_output(["git", "status", "--porcelain"], cwd=ROOT, text=True)
    if args.keep_passing:
        return record_independently(args, rows, output, env)
    result = record_native(args, rows, output, args.proof_contract, env)
    if result:
        return result
    return compress_native(output, ",".join(row["id"] for row in rows))


if __name__ == "__main__":
    raise SystemExit(main())
