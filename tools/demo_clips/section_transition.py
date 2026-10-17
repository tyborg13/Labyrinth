#!/usr/bin/env python3
"""Validate/record flow-01 without modifying the protected demo-01 manifest."""
from __future__ import annotations

import argparse
import json
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT))
from tools import visual_probe_runner
from tools.demo_clips import capture_setup, media, pipeline, storage

TASK_ID = "flow-01"
PROCESS_TIMEOUT_S = 180
GUI_LEASE_TIMEOUT_S = 30
SCENE = "res://tools/demo_clips/section_transition.tscn"


def input_hashes() -> dict:
    result = pipeline.hashes()
    for name in ("tests/suites/section_transition_suite.gd", "tests/helpers/section_transition_observer.gd", "tools/dragon_boss_inspection.gd", "tools/guardian_inspection.gd"):
        result[name] = storage.file_hash(ROOT / name)
    return result


def command(directory: Path, recording: bool) -> list[str]:
    project = directory / "capture-project" if recording else ROOT
    result = [sys.executable, str(ROOT / "tools/godot_task_runner.py"), "--task-id", TASK_ID,
              "--timeout", str(PROCESS_TIMEOUT_S), "--stream", "--", "godot", "--path", str(project), "--fixed-fps", "60"]
    if recording:
        result += ["--resolution", "1920x1080", "--windowed", "--write-movie", str(directory / "movie.avi")]
    else:
        result += ["--headless"]
    return result + [SCENE, "--", f"--output={directory}"]


def run(directory: Path, recording: bool) -> dict:
    directory.mkdir(parents=True)
    (directory / ".gdignore").touch()
    if recording:
        capture_setup.prepare_project(directory, ROOT)
    args = argparse.Namespace(headless=not recording, gui_lease=True,
                              gui_lease_path="/private/tmp/labyrinth-gui-render.lock",
                              gui_lease_timeout=GUI_LEASE_TIMEOUT_S)
    with visual_probe_runner.gui_render_lease(args):
        result = subprocess.run(command(directory, recording), cwd=ROOT, capture_output=True, text=True)
    log = result.stdout + result.stderr
    (directory / "godot.log").write_text(log)
    for line in log.splitlines():
        if line.startswith(("DEMO CLIP", "DEMO CAPTURE SETTINGS")):
            print(line, flush=True)
    if result.returncode:
        raise ValueError(f"Clip process failed ({result.returncode}); see {directory / 'godot.log'}")
    report = json.loads((directory / "events.json").read_text())
    if report["errors"]:
        raise ValueError(report["errors"])
    validate_events(report)
    return report


def validate_events(report: dict) -> None:
    events = report["events"]
    required = ["section_i_dragon_alive", "dragon_defeated_reward_granted", "continue",
                "arrival", "transition_finished", "tail_finished"]
    if [row["event"] for row in events] != required:
        raise ValueError("Missing/out-of-order production clip steps")
    if events[-1]["frame"] - events[-2]["frame"] != 120:
        raise ValueError("Entry-room tail must last exactly two seconds at 60 fps")
    if events[2]["frame"] - events[1]["frame"] != 120:
        raise ValueError("Reward screen must hold for exactly two seconds before the pointer clicks CONTINUE")
    if not 192 <= events[4]["frame"] - events[2]["frame"] <= 194:
        raise ValueError("CONTINUE must play the complete 3.20-second transition")


def encode_arguments(directory: Path, report: dict) -> list:
    start, end = report["start_frame"], report["end_frame"]
    graph = (f"[0:v]trim=start_frame={start}:end_frame={end},setpts=PTS-STARTPTS[v];"
             f"[0:a]atrim=start_sample={start*800}:end_sample={end*800},asetpts=PTS-STARTPTS[a]")
    return ["-i", directory / "movie.avi", "-filter_complex", graph, "-map", "[v]", "-map", "[a]",
            "-c:v", "libx264", "-crf", "16", "-preset", "slow", "-pix_fmt", "yuv420p", "-r", "60",
            "-c:a", "aac", "-b:a", "192k", "-ar", "48000", "-threads", "2", directory / "section_transition.mp4"]


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("mode", choices=("validate", "record"))
    parser.add_argument("--output", type=Path, required=True, help="Fresh output directory; never overwrites a take")
    parser.add_argument("--validation", type=Path, help="Validation directory required for recording")
    args = parser.parse_args(argv)
    output = args.output.resolve()
    if output.exists():
        parser.error("Use a fresh --output directory")
    hashes = input_hashes()
    if args.mode == "validate":
        first = run(output / "take-a", False)
        second = run(output / "take-b", False)
        if first != second:
            raise ValueError("Headless section-transition takes differ")
        receipt = {"input_hashes": hashes, "report": first}
        (output / "validation.json").write_text(json.dumps(receipt, indent=2) + "\n")
        print("SECTION TRANSITION DEMO VALIDATION: PASS (two identical headless takes)")
        return 0
    if args.validation is None:
        parser.error("record requires --validation")
    validated = json.loads((args.validation / "validation.json").read_text())
    if validated["input_hashes"] != hashes:
        raise ValueError("Recording inputs changed; validate again")
    storage.require_space(output)
    report = run(output, True)
    renderer = capture_setup.log_proof((output / "godot.log").read_text())
    if report["headless"]:
        raise ValueError("Recording must use the native renderer")
    media.prepare_avi(output, (1920, 1080))
    source = media.duration_info(output, report, (1920, 1080))
    delivered = output / "section_transition.mp4"
    media.ffmpeg(encode_arguments(output, report))
    encoded = media.probe(delivered)
    video = next(stream for stream in encoded["streams"] if stream["codec_type"] == "video")
    audio = next(stream for stream in encoded["streams"] if stream["codec_type"] == "audio")
    if ((int(video["width"]), int(video["height"])) != (1920, 1080)
            or int(video["nb_read_frames"]) != source["frame_count"] or video["r_frame_rate"] != "60/1"
            or audio["codec_name"] != "aac" or int(audio["sample_rate"]) != 48000):
        raise ValueError("Encoded section-transition clip does not match its exact frame/audio contract")
    receipt = {"input_hashes": hashes, "report": report, "renderer": renderer,
               "source": source, "media": encoded, "mp4": str(delivered)}
    (output / "recording.json").write_text(json.dumps(receipt, indent=2) + "\n")
    print("SECTION TRANSITION DEMO RECORDING: PASS " + str(delivered))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
