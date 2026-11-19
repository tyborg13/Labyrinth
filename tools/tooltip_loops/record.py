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


def movie_clock(directory: Path, godot: str) -> Path:
    """Drive the renderer at a fixed rate while the probe reads its own SubViewport."""
    wrapper = directory / "godot-clock.sh"
    wrapper.write_text(
        "#!/bin/sh\nexec " + shlex.quote(godot) + " --write-movie "
        + shlex.quote(str(directory / "clock.avi")) + f' --fixed-fps {FPS} "$@"\n'
    )
    wrapper.chmod(0o755)
    return wrapper


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", default="godot")
    parser.add_argument("--check-only", action="store_true", help="Check the encoder and fixture semantics headlessly")
    parser.add_argument("--loops", help="Comma-separated registry IDs; default: all recordable loops")
    parser.add_argument("--task-id", default="tip-05", help="Task-local runner identity")
    parser.add_argument("--output-dir", type=Path, default=OUTPUT, help="Task-local recording evidence")
    parser.add_argument("--proof-contract", type=Path, help="Optional exact source-image contract")
    args = parser.parse_args()
    registry = json.loads((ROOT / "data/tooltip_loops.json").read_text())["loops"]
    selected_ids = set(args.loops.split(",")) if args.loops else None
    rows = [row for row in registry if not row.get("todo_design") and (selected_ids is None or row["id"] in selected_ids)]
    if selected_ids is not None and selected_ids != {row["id"] for row in rows}:
        parser.error("Unknown or TODO_DESIGN loop selected")
    if args.check_only:
        from webp_encode import Encoder
        Encoder() # Fail before a native recording if the offline encoder ABI is unavailable.
        return subprocess.call(
            ["python3", "tools/godot_task_runner.py", "--task-id", args.task_id, "--stream", "--",
             args.godot, "--headless", "--path", ".", "--script", "tools/tooltip_loops/record.gd", "--", "--semantics-only"],
            cwd=ROOT, env=dict(os.environ, TOOLTIP_LOOP_IDS=args.loops or ""),
        )
    env = os.environ.copy()
    output = args.output_dir.resolve()
    env.update(TIP01_OUT=str(output), LABYRINTH_CEL_LOOK="all")
    env["TOOLTIP_LOOP_IDS"] = args.loops or ""
    env["TIP01_COMMIT"] = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip()
    env["TIP01_DIRTY"] = subprocess.check_output(["git", "status", "--porcelain"], cwd=ROOT, text=True)
    output.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="tip01-clock-") as directory:
        wrapper = movie_clock(Path(directory), args.godot)
        command = ["python3", "tools/visual_probe_runner.py", "tools/tooltip_loops/record.gd", "--task-id", args.task_id, "--godot", str(wrapper), "--no-headless", "--display-driver", "macos", "--audio-driver", "Dummy", "--timeout", str(RECORD_TIMEOUT_SECONDS), "--expect-size", "1920x1080", "--min-images", str(len(rows) * 3), "--result-manifest", str(output / "manifest.json"), "--overwrite-result-manifest"]
        if args.proof_contract:
            command.extend(["--proof-contract", str(args.proof_contract)])
        result = subprocess.call(command, cwd=ROOT, env=env)
        if result:
            return result
    command = ["python3", "tools/tooltip_loops/compress.py", "--input-dir", str(output / "raw"), "--report", str(output / "compression-report.json")]
    if args.loops:
        command.extend(["--loops", args.loops])
    return subprocess.call(command, cwd=ROOT)


if __name__ == "__main__":
    raise SystemExit(main())
