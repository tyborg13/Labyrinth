#!/usr/bin/env python3
"""Director-only deterministic recorder. No artwork is generated or substituted."""
import argparse
import os
from pathlib import Path
import shlex
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[2]
OUTPUT = Path("/private/tmp/labyrinth_codex/tip-02/record")
RECORD_TIMEOUT_SECONDS = 240  # Three GPU-backed recordings plus production asset warmup.


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", default="godot")
    parser.add_argument("--check-only", action="store_true", help="Parse the recorder headlessly; do not record")
    args = parser.parse_args()
    if args.check_only:
        from webp_encode import Encoder
        Encoder() # Fail before a native recording if the offline encoder ABI is unavailable.
        return subprocess.call(["python3", "tools/godot_task_runner.py", "--task-id", "tip-02", "--stream", "--", args.godot, "--headless", "--path", ".", "--script", "tools/tooltip_loops/record.gd", "--check-only"], cwd=ROOT)
    env = os.environ.copy()
    env.update(TIP01_OUT=str(OUTPUT), LABYRINTH_CEL_LOOK="all")
    env["TIP01_COMMIT"] = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip()
    env["TIP01_DIRTY"] = subprocess.check_output(["git", "status", "--porcelain"], cwd=ROOT, text=True)
    OUTPUT.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="tip01-clock-") as directory:
        wrapper = Path(directory) / "godot-clock"
        wrapper.write_text("#!/bin/sh\nexec " + shlex.quote(args.godot) + " --write-movie " + shlex.quote(str(Path(directory) / "clock.avi")) + ' --fixed-fps 30 "$@"\n')
        wrapper.chmod(0o755)
        command = ["python3", "tools/visual_probe_runner.py", "tools/tooltip_loops/record.gd", "--task-id", "tip-02", "--godot", str(wrapper), "--no-headless", "--display-driver", "macos", "--audio-driver", "Dummy", "--timeout", str(RECORD_TIMEOUT_SECONDS), "--expect-size", "1920x1080", "--min-images", "9", "--result-manifest", str(OUTPUT / "manifest.json"), "--overwrite-result-manifest"]
        result = subprocess.call(command, cwd=ROOT, env=env)
        if result:
            return result
    return subprocess.call(["python3", "tools/tooltip_loops/compress.py", "--input-dir", str(OUTPUT / "raw"), "--report", str(OUTPUT / "compression-report.json")], cwd=ROOT)


if __name__ == "__main__":
    raise SystemExit(main())
