#!/usr/bin/env python3
"""Run one owner-only native proof profile with validated PNG receipts."""

import argparse
import json
import os
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
WORK = ROOT / "tools/qa113"


def contract(out, pattern, width, height, count, required):
    path = out / "proof-contract.json"
    region = {"rect": [0, 0, width, height], "min_luma_range": 8, "min_luma_stdev": 2}

    def image_rule(glob):
        return {"pattern": glob, "width": width, "height": height, "regions": [region]}

    path.write_text(json.dumps({"min_images": count, "expected_sizes": [f"{width}x{height}"],
                               "required_images": [image_rule(glob) for glob in (pattern, *required)]}, indent=2))
    return path


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("probe", choices=("rules", "undo", "held-undo", "hands", "loops", "focus", "text"))
    parser.add_argument("--profile", choices=("desktop", "deck"), default="desktop")
    parser.add_argument("--out", type=Path, required=True)
    args = parser.parse_args()
    out = args.out.resolve()
    out.mkdir(parents=True, exist_ok=True)
    width, height = (1280, 800) if args.profile == "deck" else (1920, 1080)
    if args.probe in ("loops", "focus", "text") and args.profile != "desktop":
        parser.error(f"{args.probe} uses the desktop profile")
    environment = {"QA107_PROFILE": args.profile, "QA107_OUTPUT": str(out),
                   "UI33_CASE": "", "TOOLTIP_LOOP_CAPTURE_OUT": str(out)}
    user_args = []
    script = WORK / f"{args.probe}.gd"
    count = 1
    required = ()
    pattern = f"qa107-{args.profile}-*.png"
    if args.probe == "rules":
        count = 35
        required = tuple(f"qa107-{args.profile}-{name}.png" for name in ("reach_exit-undo", "thornmother", "craghide", "tharokh", "tharokh-leader"))
    elif args.probe in ("undo", "held-undo"):
        script = WORK / "rules.gd"
        variant = "undo" if args.probe == "undo" else "held_undo"
        environment["UI33_CASE"] = f"reach_exit/{variant}"
        pattern = f"qa107-{args.profile}-reach_exit-{variant}.png"
    elif args.probe == "hands":
        count = 20
        required = tuple(f"qa107-{args.profile}-hand-{room}-{phase}.png"
                         for room in ("tharokh", "zekarion", "guardian", "warband")
                         for phase in ("resting", "selected", "cancelled", "played", "drawn"))
    elif args.probe == "loops":
        pattern = "qa113_loop_*_1920x1080.png"
        rows = json.loads((ROOT / "data/tooltip_loops.json").read_text())["loops"]
        labels = [label for row in rows if "todo_design" not in row
                  for label in (row["id"], *(row["id"] + "_" + entry.replace(":", "-") for entry in row.get("grimoire_entries", [])))]
        labels.extend(f"{name}_grimoire-card" for name in (
            "chain_card", "push_card", "pull_card", "detonate_fire", "discharge_network",
            "swap_landing", "worldspine_pulse"))
        required = tuple(f"qa113_loop_{label}_1920x1080.png" for label in labels)
        count = len(required)
    elif args.probe == "focus":
        script = ROOT / "tools/qa110/interruptions.gd"
        user_args = [f"--out={out}", "--case=normal-mouse-focus_loss_drag", "--native-focus-loss"]
        pattern = "*focus_loss_drag*.png"
        print("When a card is held, switch away from the game window, then return.", flush=True)
    else:
        script = ROOT / "tests/text_audit_capture_probe.gd"
    proof = {"text": ROOT / "tests/text_audit_capture_probe_contract.json",
             "focus": ROOT / "tools/qa110/visual_contract.json"}.get(args.probe)
    if proof is None:
        proof = contract(out, pattern, width, height, count, required)
    command = [sys.executable, "tools/visual_probe_runner.py", "--no-headless", "--display-driver", "macos",
               "--audio-driver", "Dummy", "--attempts", "1", "--timeout", "420", "--task-id", "qa-113",
               "--expect-size", f"{width}x{height}", "--proof-contract", str(proof), "--result-manifest",
               str(out / "result.json"), str(script.relative_to(ROOT))]
    if user_args:
        command.extend(("--", *user_args))
    return subprocess.run(command, cwd=ROOT, env={**os.environ, **environment}, check=False).returncode


if __name__ == "__main__":
    raise SystemExit(main())
