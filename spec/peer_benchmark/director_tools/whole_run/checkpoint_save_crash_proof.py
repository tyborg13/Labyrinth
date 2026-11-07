#!/usr/bin/env python3
"""Kill task-runner-owned Godot children at exact save transaction boundaries."""
from __future__ import annotations

import argparse
import json
import os
from pathlib import Path
import selectors
import signal
import subprocess
import sys
import time

ROOT = Path("/Users/borgerding/workspace/Labyrinth.worktrees/perf-65")
CHILD_TIMEOUT_SECONDS = 30
SCRIPT = "tests/perf/run_save_crash_fixture.gd"


def command(stage: str, path: Path, *args: str) -> list[str]:
    return [sys.executable, str(ROOT / "tools/godot_task_runner.py"), "--task-id", "perf-65",
            "--stream", "--", "godot", "--headless", "--path", str(ROOT), "--script", SCRIPT,
            "--", stage, str(path), *args]


def kill_at(stage: str, path: Path, log: Path) -> None:
    # The PID comes only from the child we just launched, never from a process
    # inventory. The runner remains responsible for its process group cleanup.
    with log.open("w") as stream:
        child = subprocess.Popen(command(stage, path), cwd=ROOT, stdout=subprocess.PIPE,
                                 stderr=subprocess.STDOUT)
        assert child.stdout is not None
        selector = selectors.DefaultSelector()
        selector.register(child.stdout, selectors.EVENT_READ)
        deadline = time.monotonic() + CHILD_TIMEOUT_SECONDS
        killed = False
        pending = ""
        try:
            while time.monotonic() < deadline:
                if not selector.select(timeout=0.25):
                    if child.poll() is not None:
                        break
                    continue
                chunk = os.read(child.stdout.fileno(), 65536)
                if not chunk:
                    break
                decoded = chunk.decode("utf-8", errors="replace")
                stream.write(decoded)
                stream.flush()
                pending += decoded
                lines = pending.split("\n")
                pending = lines.pop()
                for line in lines:
                    if line.startswith("PERF65_CRASH_READY "):
                        ready = json.loads(line.split(" ", 1)[1])
                        assert ready["stage"] == stage
                        os.kill(int(ready["pid"]), signal.SIGKILL)
                        killed = True
                        break
                if killed:
                    break
            if not killed:
                raise RuntimeError(f"No crash barrier reached: {log}")
            tail, _ = child.communicate(timeout=CHILD_TIMEOUT_SECONDS)
            stream.write(tail.decode("utf-8", errors="replace"))
            if child.returncode == 0:
                raise RuntimeError("Killed child unexpectedly succeeded")
        finally:
            selector.close()
            if child.poll() is None:
                child.terminate()
                child.communicate(timeout=CHILD_TIMEOUT_SECONDS)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output-dir", type=Path, required=True)
    args = parser.parse_args()
    directory = args.output_dir.resolve()
    directory.mkdir(parents=True, exist_ok=True)
    results = []
    for stage, expected in [("temporary_validated", 0), ("recovery_ready", 0), ("between_queued", 1)]:
        path = directory / f"{stage}.save"
        kill_at(stage, path, directory / f"{stage}-kill.log")
        check = subprocess.run(command("verify", path, str(expected)), cwd=ROOT,
                               text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                               timeout=CHILD_TIMEOUT_SECONDS)
        (directory / f"{stage}-recovery.log").write_text(check.stdout)
        if check.returncode or "PERF65 PROCESS-KILL RECOVERY: PASS" not in check.stdout:
            raise RuntimeError(check.stdout)
        results.append(dict(stage=stage, expected_checkpoint=expected, result="PASS"))
        print(f"PERF65 SIGKILL {stage}: PASS (checkpoint {expected})", flush=True)
    (directory / "result.json").write_text(json.dumps(results, indent=2) + "\n")
    print("PERF65 PROCESS-KILL RESULT: PASS (3 boundaries)")


if __name__ == "__main__":
    main()
