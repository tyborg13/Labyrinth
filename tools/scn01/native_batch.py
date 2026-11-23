"""Run isolated shot engines under one visual runner session per resolution."""

from __future__ import annotations

import json
import os
from pathlib import Path
import subprocess
import sys
import time


def validate_batch(active: list[tuple[dict, list[str]]], size: str, out: Path, deadline: float, project: Path) -> tuple[set[Path], dict[str, int], Path]:
    from census import SCRIPT_DIR, TASK, capture_log, write_json

    logs = out / "logs"
    plan = logs / "visual_batch_plan.json"
    proof = logs / "visual_batch_proof.json"
    contract = logs / "visual_batch_contract.json"
    write_json(plan, [
        {"shot": row["shot"], "args": args, "log": row["probe_log"], "png": row["planned_png"]}
        for row, args in active
    ])
    width, height = map(int, size.split("x"))
    write_json(contract, {
        "min_images": len(active),
        "expected_sizes": [size],
        "required_images": [
            {"pattern": Path(row["planned_png"]).name, "width": width, "height": height,
             "regions": [{"rect": [0, 0, width, height], "min_luma_range": 8}]}
            for row, _ in active
        ],
    })
    remaining = deadline - time.monotonic()
    if remaining <= 0:
        raise ValueError("Native census exceeded its shared 29-minute run budget")
    command = [
        sys.executable, "tools/visual_probe_runner.py", str(SCRIPT_DIR / "census.gd"),
        "--project", str(project), "--task-id", TASK, "--no-headless", "--audio-driver", "Dummy",
        "--godot", str(SCRIPT_DIR / "native.sh"), "--timeout", str(remaining),
        "--expect-size", size, "--proof-contract", str(contract), "--result-manifest", str(proof), "--", str(plan),
    ]
    env = dict(os.environ, LABYRINTH_CEL_LOOK="all", LABYRINTH_PROBE_WINDOW="1", SCN01_WINDOWED_BATCH="1")
    try:
        capture_log(command, env, logs / "visual_batch.log", deadline)
    except ValueError:
        # A timed-out batch still has per-shot status and diagnostic logs.
        pass
    status_path = plan.with_name("visual_batch_status.json")
    statuses = json.loads(status_path.read_text()) if status_path.is_file() else {}
    metadata = json.loads(proof.read_text()) if proof.is_file() else {}
    dimensions = tuple(map(int, size.split("x")))
    validated = {
        Path(image["path"]).resolve()
        for image in metadata.get("images", [])
        if (image["width"], image["height"]) == dimensions
    }
    return validated, statuses, proof


def run_engines(engine_args: list[str], plan: Path) -> int:
    from census import ENGINE_TIMEOUT, SCRIPT_DIR, TASK, write_json

    shots = json.loads(plan.read_text())
    statuses: dict[str, int] = {}
    for index, shot in enumerate(shots):
        png = Path(shot["png"])
        png.unlink(missing_ok=True)
        flags = engine_args.copy()
        if "--headless" not in flags:
            size = shot["args"][shot["args"].index("--size") + 1]
            flags.extend(["--resolution", size])
        # The visual runner's startup watchdog watches the first real engine's
        # log. Later shot engines get their own task-runner log and save home.
        if index > 0 and "--log-file" in flags:
            log_index = flags.index("--log-file")
            del flags[log_index:log_index + 2]
        command = [
            sys.executable, str(SCRIPT_DIR.parent / "godot_task_runner.py"), "--task-id", TASK, "--stream",
            "--timeout", str(ENGINE_TIMEOUT), "--", "godot", *flags, "--", *shot["args"],
        ]
        with Path(shot["log"]).open("w", encoding="utf-8") as log:
            result = subprocess.run(command, stdout=log, stderr=subprocess.STDOUT)
        statuses[shot["shot"]] = result.returncode
        write_json(plan.with_name("visual_batch_status.json"), statuses)
        if result.returncode == 0 and png.is_file():
            # The visual runner extracts and validates these paths and writes
            # the result manifest for the whole resolution.
            print(shot["png"], flush=True)
    return 0


if __name__ == "__main__":
    divider = sys.argv.index("--")
    raise SystemExit(run_engines(sys.argv[1:divider], Path(sys.argv[divider + 1])))
