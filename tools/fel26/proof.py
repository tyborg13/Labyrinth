#!/usr/bin/env python3
"""Check matching fel-16 witnesses and package fel-26 comparisons."""
import json
from pathlib import Path
import re
from statistics import median
import subprocess
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "fel13"))
from proof import (BOARD_SIZE, FPS, MEDIA_ERRORS, MIN_TILE_WIDTH, MOTION_SECONDS,
                   encode_motion_segment, ffmpeg)

VARIANTS = ("off", "window", "always")
SAMPLE_ORDER = ("1-off", "1-always", "2-always", "2-off", "3-off", "3-always")
STILLS = ("P3", "04-s0-seed8-0--3_2-t5", "10-s3-seed12-3-13_-2-t4",
          "crate-loot", "P8-hero-pillar")
MOTIONS = ("M1a", "M2")
FIXTURE_COUNT = 20
P50_BUDGET_MS = 0.15
CROP_SCALE = 2


def check_headless(output):
    baseline = {}
    cases = 0
    for variant in ("release", *VARIANTS):
        log = (output / f"{variant}.log").read_text()
        signatures = dict(re.findall(r"^FEL26 CHECKER SIGNATURE (\S+) (\w+)$", log, re.M))
        if len(signatures) != FIXTURE_COUNT or not re.search(
            rf"^FEL13 WITNESS PASS .*fixtures={FIXTURE_COUNT} .*failures=0$", log, re.M
        ):
            raise ValueError(f"{variant} witness incomplete")
        rows = re.findall(r"^FEL26 EDGE \S+ (\S+) edge_texels=(\d+) PASS$", log, re.M)
        if len(rows) != FIXTURE_COUNT:
            raise ValueError(f"{variant} edge audit incomplete")
        if variant == "release":
            baseline = signatures
            continue
        differences = [fixture for fixture, sha in signatures.items() if baseline.get(fixture) != sha]
        if differences:
            raise ValueError(f"{variant} release checker input mismatch for {', '.join(differences)}")
        if variant == "off" and any(edge != "0" for _, edge in rows):
            raise ValueError("off submitted an edge")
        if variant != "off" and not any(int(edge) for _, edge in rows):
            raise ValueError(f"{variant} did not exercise an exterior edge")
        cases += len(rows)
        print(f"FEL26 RELEASE CHECKER INPUT PARITY PASS {variant} cases={len(rows)}")
    print(f"FEL26 OCCLUDER EDGE PASS cases={cases}")


def timing(output):
    observations = []
    for sample in SAMPLE_ORDER:
        log = (output / sample / "run.log").read_text()
        layout = re.search(r"^FEL13 LAYOUT (\S+) tile_width=([\d.]+).*stable_frames=10$", log, re.M)
        record = re.search(r"^FEL13 PERF fixture=(\S+) side=(\S+) renderer=(\S+) frames=(\d+) "
                           r"p50=([\d.]+) p99=([\d.]+) max=([\d.]+)$", log, re.M)
        layer = re.search(r"^FEL26 PERF LAYER variant=(off|always) edges=(\d+)$", log, re.M)
        if (not layout or not record or not layer or layout[1] != record[1] or float(layout[2]) < MIN_TILE_WIDTH
                or record[2] != sample.split("-")[1] or layer[1] != record[2] or record[4] != "600"
                or (layer[1] == "always") != (int(layer[2]) > 0)):
            raise ValueError(f"{sample} is missing its guarded timing line")
        observations.append((record[3], float(record[5]), float(record[6])))
    renderers = {row[0] for row in observations}
    if len(renderers) != 1:
        raise ValueError("paired renderers differ")
    p50_deltas, p99_deltas = [], []
    for index in range(0, len(observations), 2):
        pair = dict(zip((tag.split("-")[1] for tag in SAMPLE_ORDER[index:index + 2]),
                        observations[index:index + 2]))
        _, off_50, off_99 = pair["off"]
        _, always_50, always_99 = pair["always"]
        p50_deltas.append(round(always_50 - off_50, 3))
        p99_deltas.append(round(always_99 - off_99, 3))
        print(f"FEL26 PERF pair={index // 2 + 1} off_p50={off_50:.3f} always_p50={always_50:.3f}"
              f" off_p99={off_99:.3f} always_p99={always_99:.3f}")
    renderer = observations[0][0]
    passed = median(p50_deltas) <= P50_BUDGET_MS
    stage = "HEADLESS" if renderer == "headless" else ("PASS" if passed else "FAIL")
    print(f"FEL26 PERF {stage} renderer={renderer} p50_deltas_ms={p50_deltas}"
          f" p50_median_ms={median(p50_deltas)} p99_deltas_ms={p99_deltas} p99_median_ms={median(p99_deltas)}")
    return renderer == "headless" or passed


def stack_stills(output):
    x0, y0, x1, y1 = json.loads((output / "always" / "P3-crop.json").read_text())
    x0, y0 = max(0, x0), max(0, y0)
    width, height = min(x1, BOARD_SIZE[0]) - x0, min(y1, BOARD_SIZE[1]) - y0
    if width <= 0 or height <= 0:
        raise ValueError("invalid pillar crop")
    for fixture in STILLS:
        inputs = [arg for variant in VARIANTS for arg in ("-i", output / variant / f"{fixture}.png")]
        dest = output / f"{fixture}-three-up.png"
        ffmpeg(*inputs, "-filter_complex", "hstack=inputs=3", "-frames:v", 1, "-threads", 1, dest)
        print(dest)
        if fixture == "P3":
            crop = f"crop={width}:{height}:{x0}:{y0}:exact=1,scale=iw*{CROP_SCALE}:ih*{CROP_SCALE}:flags=neighbor"
            filters = ";".join(f"[{index}:v]{crop}[c{index}]" for index in range(3))
            dest = output / "P3-busiest-pillar-2x.png"
            ffmpeg(*inputs, "-filter_complex", f"{filters};[c0][c1][c2]hstack=inputs=3",
                   "-frames:v", 1, "-threads", 1, dest)
            print(dest)


def stack_motion(output):
    for case in MOTIONS:
        inputs = []
        for variant in VARIANTS:
            take = output / variant / case
            encode_motion_segment(take, case, MOTION_SECONDS[case], take)
            inputs.extend(("-i", take / f"{case}.mp4"))
        dest = output / f"{case}-three-up.mp4"
        audio = [arg for index, variant in enumerate(VARIANTS) for arg in
                 ("-map", f"{index}:a:0", f"-metadata:s:a:{index}", f"handler_name={variant}",
                  f"-disposition:a:{index}", "default" if variant == "window" else "0")]
        ffmpeg(*inputs, "-filter_complex", "[0:v][1:v][2:v]hstack=inputs=3[v]", "-map", "[v]", *audio,
               "-c:v", "libx264", "-crf", "18", "-pix_fmt", "yuv420p", "-c:a", "copy",
               "-movflags", "+faststart", dest)
        report = json.loads(subprocess.check_output(
            ["ffprobe", "-v", "error", "-show_streams", "-show_format", "-of", "json", dest]))
        video = next(stream for stream in report["streams"] if stream["codec_type"] == "video")
        if (video["width"], video["height"], video["r_frame_rate"]) != (5760, 1080, f"{FPS}/1"):
            raise ValueError(f"{case} unexpected three-up video geometry")
        if sum(stream["codec_type"] == "audio" for stream in report["streams"]) != 3:
            raise ValueError(f"{case} audio takes missing")
        if abs(float(report["format"]["duration"]) - MOTION_SECONDS[case]) > 1 / FPS + 0.01:
            raise ValueError(f"{case} did not retain the planned duration")
        print(dest)


def main():
    command, directory = sys.argv[1:]
    output = Path(directory)
    try:
        if command == "headless":
            check_headless(output)
        elif command == "perf":
            return 0 if timing(output) else 1
        elif command == "native":
            stack_stills(output)
            stack_motion(output)
        else:
            raise ValueError(f"unknown proof command {command}")
    except MEDIA_ERRORS as error:
        print(f"FEL26 {command.upper()} FAIL {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
