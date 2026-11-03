#!/usr/bin/env python3
"""Launch the matched hf-01 fight recording through the visual probe runner."""
from __future__ import annotations

import argparse
from pathlib import Path
import shlex
import subprocess
import sys

PROOF_SEED = 260908
PROOF_TIMEOUT_SECONDS = 120


def command(args: argparse.Namespace) -> list[str]:
    return [sys.executable, "tools/visual_probe_runner.py", "--task-id", args.task_id,
            "--no-headless", "--display-driver", "macos", "--audio-driver", "Dummy",
            "--timeout", str(PROOF_TIMEOUT_SECONDS), "--expect-size", "1920x1080",
            "--proof-contract", "tests/hero_facing_probe_contract.json",
            "--result-manifest", args.result_manifest,
            "tests/hero_facing_gameplay_probe.gd", "--", "--hero-facing", args.hero_facing,
            "--seed", str(args.seed)]


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--hero-facing", choices=("persist", "snap"), default="persist")
    parser.add_argument("--seed", type=int, choices=(PROOF_SEED,), default=PROOF_SEED)
    parser.add_argument("--task-id", default="hf-01")
    parser.add_argument("--result-manifest", required=True)
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args(argv)
    project = Path(__file__).resolve().parents[1]
    cmd = command(args)
    print(f"cd {shlex.quote(str(project))} && {shlex.join(cmd)}", flush=True)
    return 0 if args.dry_run else subprocess.run(cmd, cwd=project).returncode


if __name__ == "__main__":
    raise SystemExit(main())
