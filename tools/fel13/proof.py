#!/usr/bin/env python3
"""Package each available native capture and compare the matched timing pairs."""
import json
from pathlib import Path
import re
from statistics import median
import subprocess
import sys

FPS = 30
MOTION_SECONDS = {"M1a": 10, "M1b": 10, "M2": 20, "M3": 20}
P99_MEDIAN_BUDGET_MS = 0.5
P99_PAIR_BUDGET_MS = 1.5
MIN_TILE_WIDTH = 40.0
SAMPLE_ORDER = ["release", "branch", "branch", "release", "release", "branch"]
MEDIA_ERRORS = (OSError, ValueError, KeyError, StopIteration, subprocess.CalledProcessError)
BOARD_SIZE = (1920, 1080)
ZOOM_CROP_SIZE = (144, 120)
ZOOM_SCALE = 4


def ffmpeg(*args):
    subprocess.run(["ffmpeg", "-nostdin", "-v", "error", *map(str, args)], check=True)


def fail(case, message):
    print(f"FEL13 FAIL {case} {message}", file=sys.stderr)


def contacts(output):
    target = output / "contacts"
    target.mkdir()
    fixtures = sorted(path.name for path in Path(__file__).with_name("fixtures").iterdir() if path.is_dir())
    failed = False
    for fixture in fixtures:
        inputs = [output / side / f"{fixture}-{phase}.png"
                  for side in ("release", "branch") for phase in ("rest", "hover")]
        missing = [str(path.relative_to(output)) for path in inputs if not path.is_file()]
        if missing:
            fail(fixture, "contact sheet missing " + ", ".join(missing))
            failed = True
            continue
        output_file = target / f"{fixture}-contact.png"
        try:
            ffmpeg(*(arg for path in inputs for arg in ("-i", path)),
                   "-filter_complex", "xstack=inputs=4:layout=0_0|w0_0|0_h0|w0_h0",
                   "-frames:v", 1, "-threads", 1, output_file)
        except MEDIA_ERRORS as error:
            fail(fixture, f"could not produce contact sheet: {error}")
            failed = True
            continue
        print(output_file)
    return int(failed)


def zoom_filter(center):
    width, height = ZOOM_CROP_SIZE
    x, y = (max(0, min(extent - span, round(middle - span / 2)))
            for middle, span, extent in zip(center, ZOOM_CROP_SIZE, BOARD_SIZE))
    return f"crop={width}:{height}:{x}:{y}:exact=1,scale=iw*{ZOOM_SCALE}:ih*{ZOOM_SCALE}:flags=neighbor"


def zooms(output):
    target = output / "zooms"
    target.mkdir()
    failed = False
    for case in (f"P{number}" for number in range(1, 9)):
        release, branch = (output / side for side in ("release", "branch"))
        try:
            base_centers = json.loads((release / f"{case}-crops.json").read_text())
            branch_centers = json.loads((branch / f"{case}-crops.json").read_text())
            if not isinstance(base_centers, dict) or not isinstance(branch_centers, dict):
                raise ValueError("expected a subject-to-centre mapping")
            if not branch_centers:
                raise ValueError("no hidden subjects in branch mask")
        except MEDIA_ERRORS as error:
            fail(case, f"could not read hidden-subject crops: {error}")
            failed = True
            continue
        for index, (key, center) in enumerate(sorted(branch_centers.items()), 1):
            label = re.sub(r"[^a-zA-Z0-9_-]+", "-", key).strip("-")
            path = target / f"{case}-{index:02d}-{label}-4x.png"
            try:
                base = zoom_filter(base_centers.get(key, center))
                changed = zoom_filter(center)
                ffmpeg("-i", release / f"{case}-rest.png", "-i", branch / f"{case}-rest.png",
                       "-filter_complex", f"[0:v]{base}[l];[1:v]{changed}[r];[l][r]hstack",
                       "-frames:v", 1, "-threads", 1, path)
            except (*MEDIA_ERRORS, TypeError) as error:
                fail(case, f"could not produce zoom for {key}: {error}")
                failed = True
                continue
            print(path)
    return int(failed)


def encode_motion_segment(path, case, seconds, output):
    log = (path / "run.log").read_text()
    marker = re.search(rf"FEL13 MOTION START {case} (\d+)", log)
    if not marker or f"FEL13 MOTION CAPTURE PASS {case}" not in log:
        raise ValueError("capture did not complete")
    ffmpeg("-ss", max(0, int(marker[1]) - 1) / FPS, "-i", path / "game.avi",
           "-t", seconds, "-map", "0:v:0", "-map", "0:a:0", "-r", FPS,
           "-c:v", "libx264", "-pix_fmt", "yuv420p", "-c:a", "aac",
           "-movflags", "+faststart", output / f"{case}.mp4")


def validate_motion(video):
    raw = subprocess.check_output(["ffprobe", "-v", "error", "-show_streams",
                                   "-show_format", "-of", "json", video])
    report = json.loads(raw)
    stream = next(x for x in report["streams"] if x["codec_type"] == "video")
    actual = stream["codec_name"], stream["width"], stream["height"], stream["r_frame_rate"]
    if actual != ("h264", 1920, 1080, "30/1"):
        raise ValueError(f"unexpected video stream {actual}")
    if not any(x["codec_type"] == "audio" for x in report["streams"]):
        raise ValueError("missing game audio")
    if not 15 <= float(report["format"]["duration"]) <= 25:
        raise ValueError("duration outside 15–25 seconds")


def motion(output):
    encoded = set()
    failed = False
    for case, seconds in MOTION_SECONDS.items():
        try:
            encode_motion_segment(output / case, case, seconds, output)
        except MEDIA_ERRORS as error:
            fail(case, f"could not encode motion: {error}")
            failed = True
            continue
        encoded.add(case)
    try:
        if not {"M1a", "M1b"} <= encoded:
            raise ValueError("capture segments are incomplete")
        playlist = output / "m1.txt"
        playlist.write_text("file 'M1a.mp4'\nfile 'M1b.mp4'\n")
        ffmpeg("-f", "concat", "-safe", "1", "-i", playlist, "-c", "copy", output / "M1.mp4")
        encoded.add("M1")
    except MEDIA_ERRORS as error:
        fail("M1", f"could not join motion: {error}")
        failed = True
    for case in ("M1", "M2", "M3"):
        if case not in encoded:
            continue
        video = output / f"{case}.mp4"
        try:
            validate_motion(video)
        except MEDIA_ERRORS as error:
            fail(case, f"motion proof failed: {error}")
            failed = True
            continue
        print(video)
    return int(failed)


def perf(logs):
    if len(logs) != len(SAMPLE_ORDER):
        fail("perf", f"expected {len(SAMPLE_ORDER)} sample logs, got {len(logs)}")
        return 1
    measurements = []
    for log, side in zip(logs, SAMPLE_ORDER):
        text = Path(log).read_text() if Path(log).is_file() else ""
        layout = re.search(r"^FEL13 LAYOUT (\S+) tile_width=([\d.]+).*stable_frames=10$", text, re.MULTILINE)
        match = re.search(r"FEL13 PERF fixture=(\S+) side=(release|branch).*p50=([\d.]+) p99=([\d.]+) max=([\d.]+)", text)
        if not layout or not match or float(layout[2]) < MIN_TILE_WIDTH or layout[1] != match[1] or match[2] != side:
            fail(Path(log).parent.name, "missing guarded timing sample")
            measurements.append(None)
            continue
        print(match[0])
        measurements.append((side, float(match[4])))
    deltas = []
    for index in range(0, len(SAMPLE_ORDER), 2):
        entries = measurements[index:index + 2]
        if None in entries:
            deltas.append(None)
            continue
        pair = dict(entries)
        deltas.append(round(pair["branch"] - pair["release"], 3))
    median_delta = median(deltas) if None not in deltas else None
    passed = (
        median_delta is not None
        and median_delta <= P99_MEDIAN_BUDGET_MS
        and max(deltas) <= P99_PAIR_BUDGET_MS
    )
    print(f"FEL16 PERF {'PASS' if passed else 'FAIL'} p99_deltas_ms={deltas} p99_median_ms={median_delta}")
    return int(not passed)


if __name__ == "__main__":
    command, *paths = sys.argv[1:]
    if command == "perf":
        sys.exit(perf(paths))
    sys.exit({"contacts": contacts, "motion": motion, "zooms": zooms}[command](Path(paths[0])))
