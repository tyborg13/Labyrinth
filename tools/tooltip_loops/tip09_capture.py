#!/usr/bin/env python3
"""Capture the tip-09 keywords or measure cold opens at the native frame clock."""

import argparse
import hashlib
import json
import os
from pathlib import Path
import struct
import subprocess
import sys
import tempfile

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from tooltip_loops.record import FPS, ROOT, movie_clock
from tooltip_loops.recording_checks import check_recording
from txt13.capture_clips import CRF, SECONDS, TIMEOUT, encode_clip

TASK = "tip-09"
PROBE = "tools/tooltip_loops/tip09_capture.gd"
CONTRACT = "tools/tooltip_loops/tip09_capture_contract.json"
OUT = Path("/private/tmp/labyrinth_codex/tip-09/capture")
WITNESSES = {
    "reflect": "return",
    "pierce": "health_hit",
}
# The owner approved these feedback-1 recordings before the shared recorder
# received its Reflect changes.
APPROVED_ASSET_SHA256 = {
    "pierce": "badaefbae047dbb5150e4b3d045a952dee2e563467eeed08707afd3604252fcf",
}
SOURCE_FILES = (
    "tools/tooltip_loops/tip09_fixture.gd",
    "tools/tooltip_loops/tip09_checks.gd",
    "tools/tooltip_loops/tip06_fixture.gd",
    "tools/tooltip_loops/playback.gd",
    "tools/tooltip_loops/record_board.gd",
    "tools/tooltip_loops/record.gd",
    "tools/tooltip_loops/tip09_reflect.gd",
    "scripts/enemy_mechanics/reflect_view.gd",
)
HEADER = struct.Struct("<4s4I")


def recording_receipt(row: dict) -> dict:
    loop_id = row["id"]
    provenance = check_recording(row)
    timing = provenance["motion_timing"]
    frames = int(timing["recording_frames"])
    period = frames / FPS + provenance["hold_seconds"] + provenance["crossfade_seconds"]
    asset = ROOT / row["asset_path"].removeprefix("res://")
    with asset.open("rb") as stream:
        header = HEADER.unpack(stream.read(HEADER.size))
    codec = provenance["compression"]
    selected = codec["selected"]
    visibility = timing["patch_visibility"]
    witness = visibility["rare_keyword_frames"][WITNESSES[loop_id]]
    if loop_id == "reflect":
        pixels = visibility["reflect_pixels"]
        if any(pixels[leg]["max_run"] * 12 < FPS for leg in ("outbound", "return")):
            raise ValueError(f"Reflect flight failed the 12-fps pixel proof: {asset}")
        witness = pixels["return"]["first_frame"]
    proof_frame = int(witness) - int(timing["trim_start_frames"])
    approved = provenance["asset_sha256"] == APPROVED_ASSET_SHA256.get(loop_id)
    if (
        header != (b"TLW2", 282, 168, FPS, frames)
        or not 3 <= period <= 5
        or codec["chunk_frames"] != 16
        or codec["encoder_method"] != 6
        or codec["encoder_quality"] != 100
        or selected["near_lossless"] not in (60, 40, 100)
        or not selected["passes"]
        or selected["file_bytes"] != asset.stat().st_size
        or not 0 <= proof_frame < frames - int(timing["terminal_hold_frames"])
        or (not approved and any(
            provenance["source_sha256"].get(path) != hashlib.sha256((ROOT / path).read_bytes()).hexdigest()
            for path in SOURCE_FILES
        ))
    ):
        raise ValueError(f"Stale recording, invalid witness, timing or tip-02 codec receipt: {asset}")
    size = asset.stat().st_size
    print(f"TIP09 INSTALLED {row['id']}: {size} bytes, {frames} frames, {period:.3f} s", flush=True)
    return {"proof_frame": proof_frame}


def run_capture(
    *, task: str, probe: str, contract_path: str, default_output: Path,
    witnesses: dict, receipt, description: str,
) -> int:
    tag = task.replace("-", "").upper()
    parser = argparse.ArgumentParser(description=description)
    parser.add_argument("--godot", default="godot")
    parser.add_argument("--loops", help="Comma-separated loop IDs; defaults to this task’s recordings")
    parser.add_argument("--output-dir", type=Path, default=default_output)
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--check-only", action="store_true", help="Verify tooltip attachment and lifecycle headlessly")
    mode.add_argument("--performance-only", action="store_true", help="Measure native cold opens without MovieWriter")
    args = parser.parse_args()
    requested = set(args.loops.split(",")) if args.loops else set(witnesses)
    if requested - witnesses.keys():
        parser.error(f"Choose from {', '.join(witnesses)}")
    loops = [loop_id for loop_id in witnesses if loop_id in requested]
    env = dict(os.environ, **{f"{tag}_IDS": ",".join(loops)})
    if args.check_only:
        return subprocess.call([
            "python3", "tools/godot_task_runner.py", "--task-id", task, "--stream", "--",
            args.godot, "--headless", "--path", ".", "--script", probe, "--", "--semantics-only",
        ], cwd=ROOT, env=env)
    rows = {row["id"]: row for row in json.loads((ROOT / "data/tooltip_loops.json").read_text())["loops"]}
    receipts = {}
    for loop_id in loops:
        try:
            row = rows[loop_id]
            receipts[row["asset_path"]] = receipt(row)
        except (OSError, KeyError, ValueError, struct.error) as error:
            parser.error(f"Run the native recorder before capturing {loop_id}: {error}")
    output = args.output_dir.resolve()
    output.mkdir(parents=True, exist_ok=True)
    env.update({f"{tag}_OUT": str(output), f"{tag}_TIMING": json.dumps(receipts), "LABYRINTH_CEL_LOOK": "all"})
    command = [
        "python3", "tools/visual_probe_runner.py", probe, "--task-id", task,
        "--no-headless", "--display-driver", "macos", "--audio-driver", "Dummy", "--timeout", str(TIMEOUT),
        "--result-manifest", str(output / "manifest.json"), "--overwrite-result-manifest",
    ]
    if args.performance_only:
        return subprocess.call([
            *command, "--godot", args.godot, "--min-images", "0", "--", "--performance-only",
        ], cwd=ROOT, env=env)
    with tempfile.TemporaryDirectory(prefix=".capture-", dir=output) as directory:
        scratch = Path(directory)
        expected = {f"{loop_id}_keyword_tooltip_1920x1080.png" for loop_id in loops}
        contract = json.loads((ROOT / contract_path).read_text())
        contract["required_images"] = [image for image in contract["required_images"] if image["pattern"] in expected]
        contract["min_images"] = len(loops)
        subset = scratch / "contract.json"
        subset.write_text(json.dumps(contract))
        result = subprocess.call([
            *command, "--godot", str(movie_clock(scratch, args.godot)),
            "--expect-size", "1920x1080", "--proof-contract", str(subset),
        ], cwd=ROOT, env=dict(env, **{f"{tag}_RAW": str(scratch)}))
        if result:
            return result
        clips = []
        for loop_id in loops:
            name = f"{loop_id}_keyword_tooltip"
            metadata = json.loads((scratch / f"{name}.json").read_text())
            video = scratch / f"{name}.mp4"
            encode_clip(scratch / f"{name}.rgb", video, metadata)
            clips.append(dict(metadata, video=video.name, still=f"{name}_1920x1080.png", crf=CRF))
        for clip in clips:
            (scratch / clip["video"]).replace(output / clip["video"])
            print(output / clip["video"])
        (output / "clips.json").write_text(json.dumps(clips, indent=2) + "\n")
    print(f"{tag} CLIPS RESULT: PASS ({len(clips)} clips, 1920x1080, {FPS} fps, {SECONDS} s)")
    return 0


def main() -> int:
    return run_capture(
        task=TASK, probe=PROBE, contract_path=CONTRACT, default_output=OUT,
        witnesses=WITNESSES, receipt=recording_receipt, description=__doc__,
    )


if __name__ == "__main__":
    raise SystemExit(main())
