#!/usr/bin/env python3
"""Build the screen-flow census and turn closed native spools into MP4s."""

import argparse
from collections import Counter
import json
import os
from pathlib import Path
import re
import subprocess
import time


SIZE = (1920, 1080)
FPS = 60
RGBA_BYTES = SIZE[0] * SIZE[1] * 4
STILL_MS = 150.0
# fel-09: fewer than one changed pixel per thousand, over the full framebuffer.
STILL_PIXELS = SIZE[0] * SIZE[1] / 1000
CHUNK_BYTES = 64 * 1024
PIXEL_BITS = int.from_bytes(b"\x01\x00\x00\x00" * (CHUNK_BYTES // 4), "little")
POLL_SECONDS = 0.25
GROUPS = [
    ("1. Title and Continue", ["title.continue"]),
    ("2. Map door", ["map.prebattle"]),
    ("3. Opening combat", ["prebattle.combat"]),
    ("4. Last kill and rewards", ["kill.reward"]),
    ("5. Reward pick", ["reward.map"]),
    ("6. Events", ["map.event", "event.result", "event.map"]),
    ("7. Scavenger", ["map.shop", "shop.buy", "shop.leave"]),
    ("8. Menus", [
        "character.open", "character.magic", "character.skills", "character.gear", "character.close",
        "grimoire.open", "grimoire.close", "large_map.open", "large_map.close", "pause.open", "pause.close",
    ]),
    ("9. Section change", ["section.change"]),
    ("10. Defeat and return", ["defeat.recap", "recap.title"]),
]


def rows(path):
    return [json.loads(line) for line in path.read_text().splitlines() if line]


def is_still(previous, current):
    if previous == current:
        return True
    changed = 0
    for offset in range(0, RGBA_BYTES, CHUNK_BYTES):
        end = offset + CHUNK_BYTES
        left, right = previous[offset:end], current[offset:end]
        if left == right:
            continue
        bits = int.from_bytes(left, "little") ^ int.from_bytes(right, "little")
        for shift in (16, 8, 4, 2, 1):
            bits |= bits >> shift
        changed += (bits & PIXEL_BITS).to_bytes(len(left), "little").count(b"\x01")
        if changed >= STILL_PIXELS:
            return False
    return True


def still_flags(stills, frames, ready_ms):
    end_of_input_wait = ready_ms if ready_ms >= 0 else frames[-1]["ms"]
    start = None
    end = None
    for still, previous, current in zip(stills, frames, frames[1:]):
        if previous["ms"] >= end_of_input_wait:
            break
        if still:
            if start is None:
                start = previous["ms"]
            end = min(current["ms"], end_of_input_wait)
        else:
            if start is not None and end - start >= STILL_MS:
                yield {"kind": "still run", "ms": start, "duration_ms": end - start, "end_ms": end}
            start = None
    if start is not None and end - start >= STILL_MS:
        yield {"kind": "still run", "ms": start, "duration_ms": end - start, "end_ms": end}


def convert_capture(record_path, output):
    row = json.loads(record_path.read_text())
    source = record_path.parent
    frames = row["frames"]
    action = f"{row['action']:05d}"
    if not re.fullmatch(r"[a-z_]+\.[a-z_]+", row["id"]):
        raise ValueError(f"Invalid transition ID {row['id']!r}")
    name = f"{action}-{row['id']}.mp4"
    mp4 = output / name
    partial = mp4.with_suffix(".partial.mp4")
    stills = []
    video = [
        "ffmpeg", "-hide_banner", "-loglevel", "error", "-nostdin", "-y",
        "-f", "rawvideo", "-pixel_format", "rgba", "-video_size", f"{SIZE[0]}x{SIZE[1]}",
        "-framerate", str(FPS), "-i", "pipe:0", "-i", str(source / "audio.wav"),
        "-map", "0:v", "-map", "1:a", "-af", "apad", "-shortest",
        "-c:v", "libx264", "-preset", "ultrafast", "-threads:v", "2", "-pix_fmt", "yuv420p",
        "-c:a", "aac", "-movflags", "+faststart", str(partial),
    ]
    with (source / "frames.rgba").open("rb") as raw, subprocess.Popen(video, stdin=subprocess.PIPE) as encoder:
        previous = None
        video_frame = 0
        for frame in frames:
            pixels = raw.read(RGBA_BYTES)
            if len(pixels) != RGBA_BYTES:
                raise ValueError(f"{record_path} ended before frame index {len(stills) + 1}")
            if previous is not None:
                stills.append(is_still(previous, pixels))
                until = round(frame["ms"] * FPS / 1000)
                while video_frame < until:
                    encoder.stdin.write(previous)
                    video_frame += 1
            previous = pixels
        if raw.read(1):
            raise ValueError(f"{record_path} has unindexed framebuffer data")
        encoder.stdin.write(previous)
        encoder.stdin.close()
        if encoder.wait():
            raise RuntimeError(f"FFmpeg failed for {name}")
    partial.replace(mp4)
    for flag in still_flags(stills, frames, row["ready_ms"]):
        row["flags"].append(flag)
        print(
            f"FEL20 STILL {action} {row['id']} +{flag['ms']:.3f}..{flag['end_ms']:.3f} ms "
            f"duration {flag['duration_ms']:.3f} ms",
            flush=True,
        )
    row["flags"].sort(key=lambda flag: flag["ms"])
    row["capture"] = str(mp4.resolve())
    row["session"] = os.environ.get("FEL20_RUN_LABEL", "descent")
    (output / f"{action}.json").write_text(json.dumps(row) + "\n")
    (source / "frames.rgba").unlink()
    (source / "audio.wav").unlink()
    print(f"FEL20 MP4 {mp4}", flush=True)


def capture_worker(output):
    completed = set()
    while True:
        for record in sorted(output.glob("spool/*/record.json")):
            if record not in completed:
                convert_capture(record, output)
                completed.add(record)
        if (output / "capture-finished").exists():
            break
        time.sleep(POLL_SECONDS)
    if not completed:
        raise RuntimeError("No native transitions captured")
    captions = [json.loads((output / f"{record.parent.name}.json").read_text()) for record in sorted(completed)]
    (output / "native.jsonl").write_text("".join(json.dumps(row) + "\n" for row in captions))
    print(f"FEL20 NATIVE DONE transitions={sum(row['reached'] for row in captions)} "
          f"flagged={sum(bool(row['flags']) for row in captions if row['reached'])}", flush=True)


def action_label(row):
    return f"{row.get('session', 'descent')}/{row['action']}"


def number(value):
    return f"{value:.1f}" if value >= 0 else "—"


def render(headless, native):
    lines = [
        "# Screen-flow census", "",
        "All times are wall milliseconds from the action listed in the replay transcript. "
        "Headless first response and total use presentation state. Native uses full-frame pixels. "
        "An em dash means no endpoint was observed. See [result.md](result.md) for the method and commands.",
        "",
    ]
    if native is None:
        lines.extend(["Native renderer results are pending the design owner’s run.", ""])
    native_rows = native or []
    coverage = Counter(row["id"] for row in headless if row["reached"])
    gaps = [(identity, coverage[identity]) for _, ids in GROUPS for identity in ids if coverage[identity] < 2]
    if gaps:
        lines.extend(["Headless transitions below two samples: " +
                      ", ".join(f"`{identity}` ({count})" for identity, count in gaps) + ".", ""])
    for title, ids in GROUPS:
        lines.extend([f"## {title}", "",
                      "| Action | Transition | Mode | First | Ready | Total | >33 ms | >50 ms | Flags |",
                      "|---:|---|---|---:|---:|---:|---:|---:|---:|"])
        for identity in ids:
            samples = [row for row in headless if row["id"] == identity]
            rendered = [row for row in native_rows if row["id"] == identity]
            if not samples and not rendered:
                lines.append(f"| — | {identity} | never observed | — | — | — | — | — | — |")
                continue
            for mode, records in [("headless", samples), ("native", rendered)]:
                for row in records:
                    mode_text = mode if row["reached"] else mode + " (destination missed)"
                    if row.get("capture"):
                        mode_text = f"[{mode_text}]({row['capture']})"
                    metrics = " | ".join(number(row[key]) for key in ("first_ms", "ready_ms", "total_ms"))
                    slow = sum(frame["gap_ms"] > 50 for frame in row["hitches"])
                    lines.append(f"| {action_label(row)} | {identity} | {mode_text} | {metrics} | "
                                 f"{len(row['hitches'])} | {slow} | {len(row['flags'])} |")
                if mode == "native" and samples and not records:
                    lines.append(f"| — | {identity} | native pending | — | — | — | — | — | — |")
        lines.append("")
    lines.extend(["## Every flag", "", "| Mode | Action | Transition | At (ms) | Flag | Duration (ms) |",
                  "|---|---:|---|---:|---|---:|"])
    flags = []
    for mode, records in [("headless", headless), ("native", native_rows)]:
        for row in records:
            for flag in sorted(row["flags"], key=lambda item: item["ms"]):
                flags.append(f"| {mode} | {action_label(row)} | {row['id']} | {flag['ms']:.3f} | "
                             f"{flag['kind']} | {flag['duration_ms']:.3f} |")
    lines.extend(flags or ["| — | — | — | — | — | — |"])
    for mode, records in [("headless", headless), ("native", native_rows)]:
        if not records:
            continue
        lines.extend(["", f"## Five slowest {mode} beats", "",
                      "| Action | Transition | Beat | Start (ms) | Duration (ms) | Code |",
                      "|---:|---|---|---:|---:|---|"])
        beats = [(beat, row) for row in records for beat in row["beats"]]
        beats.sort(key=lambda entry: entry[0]["end_ms"] - entry[0]["start_ms"], reverse=True)
        for beat, row in beats[:5]:
            duration = beat["end_ms"] - beat["start_ms"]
            lines.append(f"| {action_label(row)} | {row['id']} | {beat['name']} | {beat['start_ms']:.1f} | "
                         f"{duration:.1f} | `{beat['source']}` |")
    lines.extend(["", "## Beat breakdown", "",
                  "| Mode | Action | Beat | Start (ms) | End (ms) | Code |",
                  "|---|---:|---|---:|---:|---|"])
    for mode, records in [("headless", headless), ("native", native_rows)]:
        for row in records:
            for beat in sorted(row["beats"], key=lambda item: item["start_ms"]):
                lines.append(f"| {mode} | {action_label(row)} | {beat['name']} | {beat['start_ms']:.1f} | "
                             f"{beat['end_ms']:.1f} | `{beat['source']}` |")
    return "\n".join(lines) + "\n"


def check_replay(replay, headless, only_action, capture=None):
    route = rows(replay)
    plan = {i: row["id"] for i, row in enumerate(route, 1) if row["id"]}
    evidence = {row["action"]: row["id"] for row in rows(headless) if row["reached"]}
    if not plan or plan != evidence:
        raise ValueError("Replay transition actions differ from headless evidence")
    if only_action and only_action not in plan:
        raise ValueError(f"Action {only_action} is not a measured transition")
    if any(row["input"]["type"] not in {"click", "key"} for row in route):
        raise ValueError("Replay must contain only viewport clicks and key presses")
    print(f"FEL20 REPLAY PLAN actions={len(route)} transitions={len(plan)}")
    if capture:
        expected = {only_action: plan[only_action]} if only_action else plan
        rendered = rows(capture)
        actual = {row["action"]: row["id"] for row in rendered
                  if row["reached"] and Path(row["capture"]).is_file()}
        if actual != expected or len(rendered) != len(expected):
            raise ValueError("Native transition captures do not match the replay plan")
        print(f"FEL20 NATIVE COVERAGE {len(rendered)}/{len(expected)}")


def package(source, directory, label):
    replay = rows(source / "route.jsonl")
    timings = rows(source / "timings.jsonl")
    if not timings:
        raise ValueError(f"No transitions recorded in {source}")
    replay = replay[:max(row["action"] for row in timings)]
    suffix = "" if label == "descent" else f"-{label}"
    for row in timings:
        row.pop("frames", None)
        row["session"] = label
    for row in replay:
        action = row["input"]
        name = action["label"]
        coord = re.fullmatch(r"(map|tile) \((-?\d+), (-?\d+)\)", name)
        if coord:
            key = "room" if coord[1] == "map" else "tile"
            action[key] = [int(coord[2]), int(coord[3])]
        if action["type"] == "click" and action.get("node") is None and name.isidentifier():
            action["node"] = name
    for path, records in [
        (directory / f"replay{suffix}.jsonl", replay),
        (directory / ("headless-evidence.jsonl" if not suffix else f"headless{suffix}.jsonl"), timings),
    ]:
        path.write_text("".join(json.dumps(row, separators=(",", ":")) + "\n" for row in records))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    pack = commands.add_parser("package")
    pack.add_argument("source", type=Path)
    pack.add_argument("directory", type=Path)
    pack.add_argument("--label", choices=["descent", "defeats"], required=True)
    worker = commands.add_parser("capture-worker")
    worker.add_argument("directory", type=Path)
    check = commands.add_parser("check")
    check.add_argument("replay", type=Path)
    check.add_argument("headless", type=Path)
    check.add_argument("--only-action", type=int, default=0)
    check.add_argument("--capture", type=Path)
    report = commands.add_parser("report")
    report.add_argument("--headless", type=Path, action="append", required=True)
    report.add_argument("--native", type=Path, action="append")
    report.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    if args.command == "package":
        package(args.source, args.directory, args.label)
    elif args.command == "capture-worker":
        try:
            capture_worker(args.directory)
        except Exception as exc:
            (args.directory / "capture-error").write_text(str(exc) + "\n")
            raise
    elif args.command == "check":
        check_replay(args.replay, args.headless, args.only_action, args.capture)
    else:
        headless = [row for path in args.headless for row in rows(path)]
        native = [row for path in args.native for row in rows(path)] if args.native else None
        args.output.write_text(render(headless, native))


if __name__ == "__main__":
    main()
