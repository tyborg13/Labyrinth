#!/usr/bin/env python3
"""Director-only matched tooltip capture in two independent Godot processes."""
import argparse
import os
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[2]
OUTPUT = Path("/private/tmp/labyrinth_codex/tip-05/capture")
LOOPS = ("burst_ember_tick", "marked_burrow_grub", "chain_card", "splits_cinder_ooze", "collision_push", "retaliate_hollow_mimic", "charge_storm_capacitor", "lightning_strikes", "marked_icefall_seer", "marked_lob_slag", "freeze_status", "rule_gust", "rule_frostbite", "rule_wildfire", "rule_shadowstep", "rule_upheaval")
CAPTURE_TIMEOUT_SECONDS = 180  # Two opens per scene, sixteen loops and the unchanged ten-second expiry.


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", default="godot")
    parser.add_argument("--check-only", action="store_true")
    args = parser.parse_args()
    if args.check_only:
        return subprocess.call(["python3", "tools/godot_task_runner.py", "--task-id", "tip-05", "--stream", "--", args.godot, "--headless", "--path", ".", "--script", "tools/tooltip_loops/capture.gd", "--check-only"], cwd=ROOT)
    codes = []
    for order in ("freeze-first", "freeze-last"):
        destination = OUTPUT / order
        env = os.environ.copy()
        env.update(TOOLTIP_LOOP_IDS=",".join(LOOPS), TOOLTIP_LOOP_ORDER=order, TOOLTIP_LOOP_CAPTURE_OUT=str(destination))
        # Each runner starts a new engine/HOME/cache. No footage is re-recorded.
        command = ["python3", "tools/visual_probe_runner.py", "tools/tooltip_loops/capture.gd", "--task-id", "tip-05", "--godot", args.godot, "--no-headless", "--display-driver", "macos", "--audio-driver", "Dummy", "--timeout", str(CAPTURE_TIMEOUT_SECONDS), "--expect-size", "1920x1080", "--proof-contract", "tools/tooltip_loops/tip05_capture_contract.json", "--result-manifest", str(destination / "capture-manifest.json"), "--overwrite-result-manifest"]
        codes.append(subprocess.call(command, cwd=ROOT, env=env))
    return 1 if any(codes) else 0


if __name__ == "__main__":
    raise SystemExit(main())
