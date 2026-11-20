"""Capture and compare the movie-clock Pass control and panel frames."""
import json
from pathlib import Path
import struct
import sys
from tempfile import TemporaryDirectory
import zlib

ENCOUNTERS = ("normal", "tharokh")
ACTIONS = ("select", "retarget", "cancel")
SELECTION_ACTIONS = ("select", "retarget")
INDICES = tuple(range(9))
FULL_FRAME = 4
PASS_CROP_MARGIN = 4
VIEWPORT = (1920, 1080)
CAPTURE_TIMEOUT_SECONDS = 120
CAPTURE_FPS = 60
STRIP = Path(__file__).with_name("frame_strip.gd")


def run(args, strict, env_by_side, root, tools, task):
    sys.path.insert(0, str(tools))
    from visual_probe_runner import decode_png

    output = args.output
    report = {}
    stale_count = 0
    settled_mismatches = []
    retarget_mismatches = {}
    for encounter in ENCOUNTERS:
        with TemporaryDirectory(prefix=f"{encounter}-sources-", dir=output) as scratch:
            arms = {}
            for side in "AB":
                source = Path(scratch) / side
                source.mkdir()
                destination = output / encounter / side
                destination.mkdir(parents=True, exist_ok=False)
                cmd_args = [
                    f"--output={source.resolve()}",
                    f"--encounter={encounter}", f"--fixtures={args.fixtures}",
                ]
                if args.native:
                    command = [
                        sys.executable, str(tools / "visual_probe_runner.py"), str(STRIP),
                        "--task-id", task, "--no-headless", "--display-driver", "macos",
                        "--rendering-driver", "metal", "--rendering-method", "mobile",
                        "--audio-driver", "Dummy", "--godot", str(tools / "perf134/capture_godot.sh"),
                        "--timeout", str(CAPTURE_TIMEOUT_SECONDS),
                        "--min-images", "3", "--expect-size", "1920x1080",
                        "--proof-contract", str(STRIP.with_name("frame_strip_contract.json")),
                        "--result-manifest", str(destination / "runner.json"),
                        "--", *cmd_args, f"--representatives={destination}",
                    ]
                else:
                    command = [
                        sys.executable, str(tools / "godot_task_runner.py"), "--task-id", task,
                        "--stream", "--", "godot", "--headless", "--fixed-fps", str(CAPTURE_FPS),
                        "--path", str(root), "--script", str(STRIP), "--",
                        "--headless-check", *cmd_args,
                    ]
                strict.run(command, root, {
                    **env_by_side[side], "PERF134_CAPTURE_MOVIE": str(source / "clock.avi"),
                })
                witness = (source / "frames.json").read_text()
                (destination / "frames.json").write_text(witness)
                arms[side] = (source, destination, json.loads(witness))
            report[encounter] = compare(arms, args.native, decode_png)
            for action, row in report[encounter].items():
                stale_frames = row.get("stale_row_frames", {})
                stale_count += sum(len(frames) for frames in stale_frames.values())
                if row.get("settled_rows_match") is False:
                    settled_mismatches.append(f"{encounter}/{action}")
                if action == "retarget":
                    differing = sorted(set(row["face_differences"]) | set(row["panel_differences"]))
                    if differing:
                        retarget_mismatches[encounter] = differing
                print(f"PERF-154 STRIP {encounter}/{action}: "
                      f"face frames {row['face_differences']}, panel frames {row['panel_differences']}, "
                      f"stale row frames {stale_frames}", flush=True)
    (output / "summary.json").write_text(json.dumps({
        "native_pixels": args.native, "representative_frame": FULL_FRAME, "encounters": report,
        "stale_row_frame_count": stale_count, "settled_row_mismatches": settled_mismatches,
        "retarget_frame_mismatches": retarget_mismatches,
    }, indent=2) + "\n")
    print(f"PERF-154 STRIP ROW TRUTH: {'FAIL' if stale_count or settled_mismatches else 'PASS'} "
          f"({stale_count} stale frames, {len(settled_mismatches)} settled row mismatches)")
    print(f"PERF-154 STRIP RETARGET: {'FAIL' if retarget_mismatches else 'PASS'} "
          f"({sum(map(len, retarget_mismatches.values()))} differing face/panel frames)")
    print(f"PERF-154 STRIP REPORT: {output / 'summary.json'}")
    return int(bool(stale_count or settled_mismatches or retarget_mismatches))


def compare(arms, native, decode_png):
    a, b = (arms[side][2] for side in "AB")
    for witness in (a, b):
        if witness["movie"] != native or tuple(witness["size"]) != VIEWPORT or witness["fps"] != CAPTURE_FPS:
            raise ValueError("Invalid strip renderer or frame clock")
        if witness["ui_scale"] != 1.0 or set(witness["actions"]) != set(ACTIONS):
            raise ValueError("Incomplete strip action or scale witness")
        if set(witness["settled_panels"]) != set(SELECTION_ACTIONS):
            raise ValueError("Missing settled selection panel witness")
    for field in ("fixture_sha256", "encounter"):
        if a[field] != b[field]:
            raise ValueError(f"Arms used different {field}")
    report = {}
    for action in ACTIONS:
        frame_rows = {side: arms[side][2]["actions"][action] for side in "AB"}
        for rows in frame_rows.values():
            if tuple(row["index"] for row in rows) != INDICES:
                raise ValueError(f"Incomplete frame strip for {action}")
        fields = ("selected", "aim", "movie_frame")
        if native:
            fields += ("clock_usec",)
        for left, right in zip(frame_rows["A"], frame_rows["B"]):
            if any(left[field] != right[field] for field in fields):
                raise ValueError(f"Route or movie phase mismatch for {action} frame {left['index']}")
        report[action] = compare_action(arms, action, frame_rows, native, decode_png)
    return report


def compare_action(arms, action, frame_rows, native, decode_png):
    regions = ("face", "panel")
    boxes = {
        region: crop_box(row[region]["box"] for rows in frame_rows.values() for row in rows if row[region]["box"])
        for region in regions
    }
    result = {"crop_xyxy": boxes, "frames": {}}
    if action in SELECTION_ACTIONS:
        settled = {side: arms[side][2]["settled_panels"][action] for side in "AB"}
        if any(not panel["visible"] or panel["alpha"] != 1.0 or not panel["rows"] for panel in settled.values()):
            raise ValueError(f"Expected a fully painted settled panel after {action}")
        result["settled_rows"] = {side: panel["rows"] for side, panel in settled.items()}
        result["settled_rows_match"] = settled["A"]["rows"] == settled["B"]["rows"]
        result["stale_row_frames"] = {side: [] for side in "AB"}
    images = {region: {side: [] for side in "AB"} for region in regions}
    for index in INDICES:
        a, b = (frame_rows[side][index] for side in "AB")
        frame_report = {
            "face_paint_inputs": different_fields(a["face"], b["face"]),
            "panel_paint_inputs": different_fields(painted_panel(a), painted_panel(b)),
        }
        if action in SELECTION_ACTIONS:
            stale_arms = []
            for side, frame in zip("AB", (a, b)):
                painted = painted_panel(frame)
                if painted["painted"] and painted["rows"] != result["settled_rows"][side]:
                    stale_arms.append(side)
                    result["stale_row_frames"][side].append(index)
            frame_report["stale_row_arms"] = stale_arms
        if native:
            shot = {}
            for side in "AB":
                source = arms[side][0]
                shot[side] = decode_png(source / f"{action}-{index:02d}.png")
                if (shot[side]["width"], shot[side]["height"], shot[side]["color_type"]) != (*VIEWPORT, 6):
                    raise ValueError("Expected 1920×1080 RGBA movie frames")
            for region, box in boxes.items():
                crops = {side: crop(shot[side], box) for side in "AB"}
                for side, pixels in crops.items():
                    images[region][side].append(pixels)
                    png(arms[side][1] / f"{action}-{region}-{index:02d}.png", pixels)
                frame_report[f"{region}_pixels"] = pixel_difference(crops["A"], crops["B"])
            if index == FULL_FRAME:
                frame_report["full_pixels"] = pixel_difference(shot["A"]["rows"], shot["B"]["rows"])
        result["frames"][index] = frame_report
    for region in regions:
        result[f"{region}_differences"] = [
            index for index, row in result["frames"].items()
            if (row[f"{region}_pixels"]["different_pixels"] if native else row[f"{region}_paint_inputs"])
        ]
        if native:
            # The first row is release A, the second candidate B, frames left to right.
            montage = []
            for side in "AB":
                montage.extend(b"".join(parts) for parts in zip(*images[region][side]))
            png(arms["A"][1].parent / f"{action}-{region}-strip.png", montage)
    return result


def crop_box(boxes):
    boxes = list(boxes)
    if not boxes:
        raise ValueError("Could not locate a crop region across the two arms")
    x0 = max(0, min(row[0] for row in boxes) - PASS_CROP_MARGIN)
    y0 = max(0, min(row[1] for row in boxes) - PASS_CROP_MARGIN)
    x1 = min(VIEWPORT[0], max(row[2] for row in boxes) + PASS_CROP_MARGIN)
    y1 = min(VIEWPORT[1], max(row[3] for row in boxes) + PASS_CROP_MARGIN)
    if x1 <= x0 or y1 <= y0:
        raise ValueError(f"Unusable crop region {(x0, y0, x1, y1)}")
    return x0, y0, x1, y1


def painted_panel(frame):
    panel = frame["panel"]
    if not panel["visible"] or panel["alpha"] <= 0.0:
        return {"painted": False}
    return {"painted": True, "box": panel["box"], "alpha": panel["alpha"], "rows": panel["rows"]}


def different_fields(a, b):
    return sorted(key for key in a.keys() | b.keys() if a.get(key) != b.get(key))


def crop(image, box):
    x0, y0, x1, y1 = box
    return [bytes(row[x0 * 4:x1 * 4]) for row in image["rows"][y0:y1]]


def pixel_difference(left, right):
    count = 0
    min_x, min_y, max_x, max_y = len(left[0]) // 4, len(left), -1, -1
    for y, (a, b) in enumerate(zip(left, right)):
        if a == b:
            continue
        for col in range(0, len(a), 4):
            if a[col:col + 4] != b[col:col + 4]:
                x = col // 4
                count += 1
                min_x, min_y = min(min_x, x), min(min_y, y)
                max_x, max_y = max(max_x, x), max(max_y, y)
    return {"different_pixels": count, "bbox": [min_x, min_y, max_x + 1, max_y + 1] if count else None}


def png(path, rows):
    def chunk(kind, payload):
        return struct.pack(">I", len(payload)) + kind + payload + struct.pack(">I", zlib.crc32(kind + payload))

    header = struct.pack(">IIBBBBB", len(rows[0]) // 4, len(rows), 8, 6, 0, 0, 0)
    raster = zlib.compress(b"".join(b"\x00" + row for row in rows))
    path.write_bytes(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", header) + chunk(b"IDAT", raster) + chunk(b"IEND", b""))
