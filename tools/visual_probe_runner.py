#!/usr/bin/env python3
"""Run Godot visual probes with isolated user:// storage and screenshot validation."""

from __future__ import annotations

import argparse
import math
import os
from pathlib import Path
import re
import struct
import subprocess
import sys
import time
from typing import Any
import zlib


PNG_SIGNATURE = b"\x89PNG\r\n\x1a\n"
BRANCH_PREFIX = "codex/"


class ProbeError(RuntimeError):
    pass


def slugify(value: str) -> str:
    slug = re.sub(r"[^A-Za-z0-9._-]+", "-", value.strip().lower())
    slug = re.sub(r"-{2,}", "-", slug).strip("-._")
    return (slug or "probe")[:80]


def infer_task_id(project: Path) -> str:
    env_task = os.environ.get("LABYRINTH_TASK_ID", "").strip()
    if env_task:
        return slugify(env_task)
    result = subprocess.run(
        ["git", "-C", str(project), "branch", "--show-current"],
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.DEVNULL,
    )
    branch = result.stdout.strip()
    if branch.startswith(BRANCH_PREFIX):
        return slugify(branch[len(BRANCH_PREFIX):])
    return "manual"


def build_command(args: argparse.Namespace, rendering_driver: str, log_file: Path | None) -> list[str]:
    cmd = [args.godot]
    if log_file is not None:
        cmd.extend(["--log-file", str(log_file)])
    if args.headless:
        cmd.append("--headless")
    if args.display_driver:
        cmd.extend(["--display-driver", args.display_driver])
    if args.audio_driver:
        cmd.extend(["--audio-driver", args.audio_driver])
    if rendering_driver:
        cmd.extend(["--rendering-driver", rendering_driver])
    cmd.extend(["--path", str(Path(args.project).resolve()), "--script", args.script])
    if args.probe_args:
        cmd.append("--")
        cmd.extend(args.probe_args)
    return cmd


def run_probe(args: argparse.Namespace, namespace: str, rendering_driver: str) -> tuple[subprocess.CompletedProcess[str], Path | None]:
    env = os.environ.copy()
    home_dir: Path | None = None
    log_file: Path | None = None
    if args.isolated_home:
        home_dir = Path(args.godot_home_root).expanduser().resolve() / namespace
        home_dir.mkdir(parents=True, exist_ok=True)
        env["HOME"] = str(home_dir)
        log_file = home_dir / "godot.log"
    env["LABYRINTH_TASK_ID"] = namespace
    env["LABYRINTH_USER_DIR_NAME"] = "Labyrinth of Ash Parallel %s" % namespace
    cmd = build_command(args, rendering_driver, log_file)
    print("Running visual probe:")
    print("  namespace: %s" % namespace)
    if home_dir is not None:
        print("  HOME: %s" % home_dir)
    print("  command: %s" % " ".join(shell_quote(part) for part in cmd))
    result = subprocess.run(
        cmd,
        cwd=str(Path(args.project).resolve()),
        env=env,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        timeout=args.timeout,
    )
    if result.stdout:
        print(result.stdout, end="" if result.stdout.endswith("\n") else "\n")
    if result.stderr:
        print(result.stderr, file=sys.stderr, end="" if result.stderr.endswith("\n") else "\n")
    return result, home_dir


def shell_quote(value: str) -> str:
    if re.fullmatch(r"[A-Za-z0-9_./:=+-]+", value):
        return value
    return "'" + value.replace("'", "'\"'\"'") + "'"


def collect_pngs(output: str, user_dir_name: str, home_dir: Path | None) -> list[Path]:
    roots: list[Path] = []
    for raw_line in output.splitlines():
        line = raw_line.strip()
        if not line.startswith("/"):
            continue
        path = Path(line)
        if path.exists():
            roots.append(path)
    base_home = home_dir if home_dir is not None else Path.home()
    mac_user_dir = base_home / "Library" / "Application Support" / user_dir_name
    if mac_user_dir.exists():
        roots.append(mac_user_dir)

    pngs: list[Path] = []
    seen: set[Path] = set()
    for root in roots:
        candidates = [root] if root.is_file() else list(root.rglob("*.png"))
        for candidate in candidates:
            if candidate.suffix.lower() != ".png":
                continue
            resolved = candidate.resolve()
            if resolved in seen:
                continue
            seen.add(resolved)
            pngs.append(resolved)
    pngs.sort()
    return pngs


def validate_pngs(paths: list[Path], min_images: int) -> list[dict[str, Any]]:
    if len(paths) < min_images:
        raise ProbeError("Expected at least %d PNG(s), found %d." % (min_images, len(paths)))
    stats: list[dict[str, Any]] = []
    invalid: list[str] = []
    for path in paths:
        item = png_stats(path)
        stats.append(item)
        if item["width"] < 32 or item["height"] < 32:
            invalid.append("%s is too small: %sx%s" % (path, item["width"], item["height"]))
        elif item["luma_max"] <= 2.0:
            invalid.append("%s is effectively black" % path)
        elif item["luma_range"] < 3.0 or item["luma_stdev"] < 0.75:
            invalid.append("%s has too little pixel variation" % path)
    if invalid:
        raise ProbeError("\n".join(invalid))
    return stats


def png_stats(path: Path) -> dict[str, Any]:
    data = path.read_bytes()
    if not data.startswith(PNG_SIGNATURE):
        raise ProbeError("%s is not a PNG file" % path)
    pos = len(PNG_SIGNATURE)
    width = height = bit_depth = color_type = interlace = 0
    idat = bytearray()
    while pos + 8 <= len(data):
        length = struct.unpack(">I", data[pos:pos + 4])[0]
        chunk_type = data[pos + 4:pos + 8]
        chunk_data = data[pos + 8:pos + 8 + length]
        pos += 12 + length
        if chunk_type == b"IHDR":
            width, height, bit_depth, color_type, _compression, _filter, interlace = struct.unpack(">IIBBBBB", chunk_data)
        elif chunk_type == b"IDAT":
            idat.extend(chunk_data)
        elif chunk_type == b"IEND":
            break
    if interlace != 0:
        raise ProbeError("%s uses interlaced PNG encoding, which this validator does not support" % path)
    if bit_depth != 8:
        raise ProbeError("%s uses unsupported PNG bit depth %s" % (path, bit_depth))
    channels = {0: 1, 2: 3, 3: 1, 4: 2, 6: 4}.get(color_type)
    if channels is None:
        raise ProbeError("%s uses unsupported PNG color type %s" % (path, color_type))
    bpp = channels
    row_bytes = width * channels
    raw = zlib.decompress(bytes(idat))
    rows: list[bytearray] = []
    source = 0
    previous = bytearray(row_bytes)
    for _row_index in range(height):
        filter_type = raw[source]
        source += 1
        row = bytearray(raw[source:source + row_bytes])
        source += row_bytes
        unfilter(row, previous, bpp, filter_type)
        rows.append(row)
        previous = row

    values: list[float] = []
    total_pixels = max(1, width * height)
    step = max(1, total_pixels // 50000)
    pixel_index = 0
    for row in rows:
        for x in range(0, row_bytes, channels):
            if pixel_index % step == 0:
                values.append(luma_for_pixel(row, x, color_type))
            pixel_index += 1
    mean = sum(values) / len(values)
    variance = sum((value - mean) ** 2 for value in values) / len(values)
    return {
        "path": str(path),
        "width": width,
        "height": height,
        "luma_min": min(values),
        "luma_max": max(values),
        "luma_range": max(values) - min(values),
        "luma_mean": mean,
        "luma_stdev": math.sqrt(variance),
    }


def unfilter(row: bytearray, previous: bytearray, bpp: int, filter_type: int) -> None:
    for index in range(len(row)):
        left = row[index - bpp] if index >= bpp else 0
        up = previous[index]
        up_left = previous[index - bpp] if index >= bpp else 0
        if filter_type == 0:
            value = row[index]
        elif filter_type == 1:
            value = row[index] + left
        elif filter_type == 2:
            value = row[index] + up
        elif filter_type == 3:
            value = row[index] + ((left + up) // 2)
        elif filter_type == 4:
            value = row[index] + paeth(left, up, up_left)
        else:
            raise ProbeError("Unsupported PNG row filter %s" % filter_type)
        row[index] = value & 0xFF


def paeth(left: int, up: int, up_left: int) -> int:
    p = left + up - up_left
    pa = abs(p - left)
    pb = abs(p - up)
    pc = abs(p - up_left)
    if pa <= pb and pa <= pc:
        return left
    if pb <= pc:
        return up
    return up_left


def luma_for_pixel(row: bytearray, offset: int, color_type: int) -> float:
    if color_type in (0, 3):
        return float(row[offset])
    if color_type == 4:
        return float(row[offset])
    red = row[offset]
    green = row[offset + 1]
    blue = row[offset + 2]
    return 0.2126 * red + 0.7152 * green + 0.0722 * blue


def command_run(args: argparse.Namespace) -> int:
    project = Path(args.project).resolve()
    task_id = slugify(args.task_id or infer_task_id(project))
    script_stem = slugify(Path(args.script).stem)
    drivers = [args.rendering_driver] + args.fallback_rendering_driver
    last_error = ""
    for driver in drivers:
        for attempt in range(1, args.attempts + 1):
            namespace = "%s-%s-%d-%d" % (task_id, script_stem, int(time.time()), attempt)
            try:
                result, home_dir = run_probe(args, namespace, driver)
            except subprocess.TimeoutExpired:
                last_error = "Godot probe timed out after %d seconds" % args.timeout
                print("visual probe attempt failed: %s" % last_error, file=sys.stderr)
                continue
            combined_output = result.stdout + "\n" + result.stderr
            user_dir_name = "Labyrinth of Ash Parallel %s" % namespace
            pngs = collect_pngs(combined_output, user_dir_name, home_dir)
            try:
                if result.returncode != 0:
                    raise ProbeError("Godot exited with code %d" % result.returncode)
                stats = validate_pngs(pngs, args.min_images)
            except ProbeError as exc:
                last_error = str(exc)
                print("visual probe attempt failed: %s" % last_error, file=sys.stderr)
                continue
            print("Validated %d screenshot(s):" % len(stats))
            for item in stats:
                print("  {path} {width}x{height} luma={luma_mean:.1f} range={luma_range:.1f} stdev={luma_stdev:.1f}".format(**item))
            return 0
    raise ProbeError(last_error or "visual probe failed")


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("script", help="Godot probe script, e.g. tests/ui_probe.gd")
    parser.add_argument("--project", default=".", help="Godot project directory.")
    parser.add_argument("--task-id", default="", help="Stable task id for user:// namespacing.")
    parser.add_argument("--godot", default="godot")
    parser.add_argument("--timeout", type=int, default=180)
    parser.add_argument("--attempts", type=int, default=2)
    parser.add_argument("--min-images", type=int, default=1)
    parser.add_argument("--headless", dest="headless", action="store_true", default=True)
    parser.add_argument("--no-headless", dest="headless", action="store_false")
    parser.add_argument("--display-driver", default="")
    parser.add_argument("--audio-driver", default="")
    parser.add_argument("--rendering-driver", default="")
    parser.add_argument("--fallback-rendering-driver", action="append", default=[])
    parser.add_argument("--isolated-home", dest="isolated_home", action="store_true", default=True)
    parser.add_argument("--no-isolated-home", dest="isolated_home", action="store_false")
    parser.add_argument("--godot-home-root", default="/private/tmp/labyrinth-godot-home")
    parser.set_defaults(func=command_run)
    return parser


def main(argv: list[str] | None = None) -> int:
    raw_args = list(sys.argv[1:] if argv is None else argv)
    probe_args: list[str] = []
    if "--" in raw_args:
        separator = raw_args.index("--")
        probe_args = raw_args[separator + 1:]
        raw_args = raw_args[:separator]
    args = build_parser().parse_args(raw_args)
    args.probe_args = probe_args
    try:
        return int(args.func(args) or 0)
    except (ProbeError, KeyboardInterrupt) as exc:
        print("error: %s" % exc, file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
