#!/usr/bin/env python3
"""Capture native tip-07 keyword pop-ups and encode five-second clips."""

import argparse
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from godot_import_cache import ensure_imported
from tooltip_loops.record import FPS, ROOT, movie_clock
from tooltip_loops.recording_checks import check_recording
from txt13.capture_clips import CRF, SECONDS, TIMEOUT, encode_clip

TASK = "tip-07"
PROBE = "tools/tooltip_loops/tip07_capture.gd"
CONTRACT = "tools/tooltip_loops/tip07_capture_contract.json"
GRIMOIRE_CONTRACT = "tools/tooltip_loops/tip08_grimoire_contract.json"
OUT = Path("/private/tmp/labyrinth_codex/tip-07/clips")
FORCE_IDS = ("push_card", "pull_card")
COLLISION_ID = "collision_push"
IDS = (*FORCE_IDS, COLLISION_ID)
YANK_RANGE = 4
YANK_TRAVEL = 3
YANK_DAMAGE = 3


def check_force_recording(row: dict) -> None:
    provenance = check_recording(row)
    asset = ROOT / row["asset_path"].removeprefix("res://")
    receipt = provenance["motion_timing"]["patch_visibility"]["forced_movement"]
    collision = row["id"] == COLLISION_ID
    if (
        provenance["hold_seconds"] != 0.6
        or provenance["crossfade_seconds"] != 0.25
        or receipt["slide_frame"] < 0
        or receipt["collisions"] != int(collision)
        or (collision and receipt["impact_frame"] <= receipt["slide_frame"])
    ):
        raise ValueError(f"Missing force playback evidence in {asset}")
    if row["id"] == "pull_card":
        hero_x, hero_y = receipt["hero_tile"]
        targets = receipt["targets"]
        if (
            receipt["card"] != "yank"
            or len(targets) != 1
            or targets[0]["from"] != [hero_x + YANK_RANGE, hero_y]
            or targets[0]["to"] != [hero_x + YANK_RANGE - YANK_TRAVEL, hero_y]
            or targets[0]["health_before"] - targets[0]["health_after"] != YANK_DAMAGE
        ):
            raise ValueError(f"Yank must pull one Crawler three tiles from range four and deal three damage: {asset}")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", default="godot")
    parser.add_argument("--task-id", default=TASK)
    parser.add_argument("--output-dir", type=Path, default=OUT)
    parser.add_argument("--collision-only", action="store_true", help="Exercise only the Grimoire Collision hover")
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--check-only", action="store_true", help="Verify tooltip routes headlessly")
    mode.add_argument("--grimoire-stills", action="store_true", help="Capture Push and Pull on their Grimoire keyword tabs")
    args = parser.parse_args()
    if args.collision_only and args.grimoire_stills:
        parser.error("--collision-only excludes --grimoire-stills")
    ids = (COLLISION_ID,) if args.collision_only else FORCE_IDS if args.grimoire_stills else IDS
    env = dict(os.environ, TIP07_COLLISION_ONLY=str(int(args.collision_only)))
    rows = {row["id"]: row for row in json.loads((ROOT / "data/tooltip_loops.json").read_text())["loops"]}
    for loop_id in ids:
        try:
            check_force_recording(rows[loop_id])
        except (OSError, KeyError, ValueError) as error:
            parser.error(f"Run the native recorder before capturing {loop_id}: {error}")
    if args.check_only:
        # A prepared worktree can run the production scene directly. Avoid
        # rescanning unrelated experiment assets for this focused probe.
        if not (ROOT / ".godot/global_script_class_cache.cfg").is_file():
            imported = ensure_imported(ROOT, args.godot, args.task_id)
            if imported:
                return imported
        return subprocess.call([
            "python3", "tools/godot_task_runner.py", "--task-id", args.task_id, "--stream", "--",
            args.godot, "--headless", "--path", ".", "--script", PROBE, "--", "--semantics-only",
        ], cwd=ROOT, env=env)
    output = args.output_dir.resolve()
    output.mkdir(parents=True, exist_ok=True)
    env.update(TIP07_CLIP_OUT=str(output), LABYRINTH_CEL_LOOK="all")
    if args.grimoire_stills:
        return subprocess.call([
            "python3", "tools/visual_probe_runner.py", PROBE, "--task-id", args.task_id, "--godot", args.godot,
            "--no-headless", "--display-driver", "macos", "--audio-driver", "Dummy",
            "--expect-size", "1920x1080", "--proof-contract", GRIMOIRE_CONTRACT,
            "--result-manifest", str(output / "manifest.json"), "--overwrite-result-manifest",
            "--", "--grimoire-stills",
        ], cwd=ROOT, env=env)
    with tempfile.TemporaryDirectory(prefix=".capture-", dir=output) as directory:
        scratch = Path(directory)
        wrapper = movie_clock(scratch, args.godot)
        env["TIP07_CLIP_RAW"] = str(scratch)
        contract = ROOT / CONTRACT
        if args.collision_only:
            selected = json.loads(contract.read_text())
            pattern = f"{COLLISION_ID}_tooltip_1920x1080.png"
            selected["required_images"] = [image for image in selected["required_images"] if image["pattern"] == pattern]
            selected["min_images"] = len(selected["required_images"])
            contract = scratch / "collision-contract.json"
            contract.write_text(json.dumps(selected))
        result = subprocess.call([
            "python3", "tools/visual_probe_runner.py", PROBE, "--task-id", args.task_id, "--godot", str(wrapper),
            "--no-headless", "--display-driver", "macos", "--audio-driver", "Dummy", "--timeout", str(TIMEOUT),
            "--expect-size", "1920x1080", "--proof-contract", str(contract),
            "--result-manifest", str(output / "manifest.json"), "--overwrite-result-manifest",
        ], cwd=ROOT, env=env)
        if result:
            return result
        report = []
        for loop_id in ids:
            name = f"{loop_id}_tooltip"
            metadata = json.loads((scratch / f"{name}.json").read_text())
            video = scratch / f"{name}.mp4"
            encode_clip(scratch / f"{name}.rgb", video, metadata)
            report.append(dict(metadata, video=video.name, still=f"{name}_1920x1080.png", crf=CRF))
        for entry in report:
            video = output / entry["video"]
            (scratch / video.name).replace(video)
            print(video)
        (output / "clips.json").write_text(json.dumps(report, indent=2) + "\n")
    print(f"TIP07 CLIPS RESULT: PASS ({len(ids)} clips, 1920x1080, {FPS} fps, {SECONDS} s)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
