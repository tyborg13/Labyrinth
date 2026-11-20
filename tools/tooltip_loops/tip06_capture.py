#!/usr/bin/env python3
"""Capture the four approved tip-06 keyword pop-ups as 5-second clips."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from tooltip_loops.record import FPS, ROOT, movie_clock
from txt13.capture_clips import CRF, SECONDS, TIMEOUT, encode_clip

PROBE = "tools/tooltip_loops/tip06_capture.gd"
CONTRACT = "tools/tooltip_loops/tip06_capture_contract.json"
OUT = Path("/private/tmp/labyrinth_codex/tip-06/feedback1/clips")
IDS = ("detonate_fire", "discharge_network", "swap_landing", "worldspine_pulse")
WORLDSPINE_ID = "worldspine_pulse"
WORLDSPINE_CONTRACT = "tools/tooltip_loops/trn01_capture_contract.json"
RERECORDED_IDS = ("discharge_network", "swap_landing")
FIXTURE_SOURCE = "tools/tooltip_loops/tip06_fixture.gd"
# The other plain-floor recordings were approved against an earlier fixture
# containing only unrelated pre-Worldspine changes.
TIP06_APPROVED_FIXTURE_SHA256 = "edd5eb5ff1be1e99ceaf04d19761fb19285928276502a0ab950471b9610d5722"


def check_recording(row: dict) -> None:
    asset = ROOT / row["asset_path"].removeprefix("res://")
    provenance = json.loads(asset.with_suffix(".tlw.json").read_text())
    renderer = provenance["renderer"]
    content = asset.read_bytes()
    if (
        provenance["id"] != row["id"]
        or provenance["speed"] != row["speed"]
        or provenance["requires_native_rerecord"]
        or renderer["cel_look"] != "all"
        or renderer["viewport"] != [1920, 1080]
        or renderer["ui_scale"] != 1.0
        or len(content) > row["max_asset_bytes"]
        or hashlib.sha256(content).hexdigest() != provenance["asset_sha256"]
    ):
        raise ValueError(f"Recording does not match its native proof contract: {asset}")
    if row["id"] in (*RERECORDED_IDS, WORLDSPINE_ID):
        fixture_sha256 = hashlib.sha256((ROOT / FIXTURE_SOURCE).read_bytes()).hexdigest()
        accepted = {fixture_sha256} if row["id"] == WORLDSPINE_ID else {fixture_sha256, TIP06_APPROVED_FIXTURE_SHA256}
        if provenance["source_sha256"].get(FIXTURE_SOURCE) not in accepted:
            raise ValueError(f"Recording predates the plain-floor fixture: {asset}")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--godot", default="godot")
    parser.add_argument("--task-id", default="tip-06")
    parser.add_argument("--output-dir", type=Path, default=OUT)
    parser.add_argument("--check-only", action="store_true", help="Verify the real tooltip routes headlessly")
    parser.add_argument("--worldspine-only", action="store_true", help="Capture the Worldspine card, post-cast board and loop")
    args = parser.parse_args()
    ids = (WORLDSPINE_ID,) if args.worldspine_only else IDS
    probe_args = ["--worldspine-only"] if args.worldspine_only else []
    if args.check_only:
        return subprocess.call([
            "python3", "tools/godot_task_runner.py", "--task-id", args.task_id, "--stream", "--",
            args.godot, "--headless", "--path", ".", "--script", PROBE, "--", "--semantics-only", *probe_args,
        ], cwd=ROOT)
    rows = json.loads((ROOT / "data/tooltip_loops.json").read_text())["loops"]
    for row in rows:
        if row["id"] not in ids:
            continue
        try:
            check_recording(row)
        except (OSError, KeyError, ValueError) as error:
            parser.error(f"Run the native recorder before capturing {row['id']}: {error}")
    output = args.output_dir.resolve()
    output.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix=".capture-", dir=output) as directory:
        scratch = Path(directory)
        wrapper = movie_clock(scratch, args.godot)
        env = dict(os.environ, TIP06_CLIP_RAW=str(scratch), TIP06_CLIP_OUT=str(output), LABYRINTH_CEL_LOOK="all")
        result = subprocess.call([
            "python3", "tools/visual_probe_runner.py", PROBE, "--task-id", args.task_id, "--godot", str(wrapper),
            "--no-headless", "--display-driver", "macos", "--audio-driver", "Dummy", "--timeout", str(TIMEOUT),
            "--expect-size", "1920x1080", "--proof-contract", WORLDSPINE_CONTRACT if args.worldspine_only else CONTRACT,
            "--result-manifest", str(output / "manifest.json"), "--overwrite-result-manifest",
            *(["--", *probe_args] if probe_args else []),
        ], cwd=ROOT, env=env)
        if result:
            return result
        report = []
        for loop_id in ids:
            name = f"{loop_id}_card_tooltip"
            metadata = json.loads((scratch / f"{name}.json").read_text())
            video = scratch / f"{name}.mp4"
            encode_clip(scratch / f"{name}.rgb", video, metadata)
            report.append(dict(metadata, video=video.name, still=f"{name}_1920x1080.png", crf=CRF))
        for entry in report:
            video = output / entry["video"]
            (scratch / video.name).replace(video)
            print(video)
        (output / "clips.json").write_text(json.dumps(report, indent=2) + "\n")
    print(f"TIP06 CLIPS RESULT: PASS ({len(ids)} clips, 1920x1080, {FPS} fps, {SECONDS} s)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
