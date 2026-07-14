#!/usr/bin/env python3
"""Run Godot visual probes with isolated user:// storage and screenshot validation."""

from __future__ import annotations

import argparse
from contextlib import contextmanager
import fnmatch
import hashlib
import json
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

try:
    import fcntl
except ImportError:  # pragma: no cover - Windows probes do not use the macOS GUI lease.
    fcntl = None


PNG_SIGNATURE = b"\x89PNG\r\n\x1a\n"
BRANCH_PREFIX = "codex/"
FAILURE_MARKERS = (
    "SCRIPT ERROR:",
    "Parse Error:",
    "ERROR: Failed to load script",
    "TEST RESULT: FAIL",
)


class ProbeError(RuntimeError):
    pass


def slugify(value: str) -> str:
    slug = re.sub(r"[^A-Za-z0-9._-]+", "-", value.strip().lower())
    slug = re.sub(r"-{2,}", "-", slug).strip("-._")
    return (slug or "probe")[:80]


def make_probe_namespace(task_id: str, script_stem: str, attempt: int) -> str:
    task_part = task_id[:36].strip("-._") or "task"
    script_part = script_stem[:24].strip("-._") or "probe"
    unique = "%d-%d" % (time.time_ns(), os.getpid())
    return "%s-%s-%s-%d" % (task_part, unique, script_part, attempt)


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
    env["LABYRINTH_DISABLE_STEAM"] = "1"
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


def validate_pngs(
    paths: list[Path],
    min_images: int,
    expected_sizes: list[tuple[int, int]] | None = None,
    proof_contract: dict[str, Any] | None = None,
) -> list[dict[str, Any]]:
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
    for width, height in expected_sizes or []:
        if not any(item["width"] == width and item["height"] == height for item in stats):
            raise ProbeError("Expected a %dx%d screenshot, but no emitted image had that exact size." % (width, height))
    if proof_contract:
        validate_proof_contract(paths, stats, proof_contract)
    return stats


def png_stats(path: Path) -> dict[str, Any]:
    decoded = decode_png(path)
    stats = luma_stats(decoded)
    return {
        "path": str(path),
        "width": decoded["width"],
        "height": decoded["height"],
        **stats,
    }


def decode_png(path: Path) -> dict[str, Any]:
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

    return {
        "path": path,
        "width": width,
        "height": height,
        "color_type": color_type,
        "channels": channels,
        "rows": rows,
    }


def luma_stats(decoded: dict[str, Any], rect: tuple[int, int, int, int] | None = None) -> dict[str, float]:
    width = int(decoded["width"])
    height = int(decoded["height"])
    channels = int(decoded["channels"])
    color_type = int(decoded["color_type"])
    rows = decoded["rows"]
    left, top, region_width, region_height = rect or (0, 0, width, height)
    if left < 0 or top < 0 or region_width <= 0 or region_height <= 0 or left + region_width > width or top + region_height > height:
        raise ProbeError("Semantic proof region %s is outside %dx%d image bounds" % (rect, width, height))
    values: list[float] = []
    total_pixels = max(1, region_width * region_height)
    step = max(1, total_pixels // 50000)
    pixel_index = 0
    for y in range(top, top + region_height):
        row = rows[y]
        for pixel_x in range(left, left + region_width):
            if pixel_index % step == 0:
                values.append(luma_for_pixel(row, pixel_x * channels, color_type))
            pixel_index += 1
    mean = sum(values) / len(values)
    variance = sum((value - mean) ** 2 for value in values) / len(values)
    return {
        "luma_min": min(values),
        "luma_max": max(values),
        "luma_range": max(values) - min(values),
        "luma_mean": mean,
        "luma_stdev": math.sqrt(variance),
    }


def validate_proof_contract(paths: list[Path], stats: list[dict[str, Any]], contract: dict[str, Any]) -> None:
    required_images = contract.get("required_images", [])
    if not isinstance(required_images, list):
        raise ProbeError("proof contract required_images must be a list")
    decoded_cache: dict[Path, dict[str, Any]] = {}
    for index, requirement in enumerate(required_images):
        if not isinstance(requirement, dict):
            raise ProbeError("proof contract required_images[%d] must be an object" % index)
        pattern = str(requirement.get("pattern", "*")).strip() or "*"
        matches = [path for path in paths if fnmatch.fnmatch(path.name, pattern) or fnmatch.fnmatch(str(path), pattern)]
        min_count = int(requirement.get("min_count", 1))
        if len(matches) < min_count:
            raise ProbeError("Semantic proof requires %d image(s) matching %r; found %d." % (min_count, pattern, len(matches)))
        if ("width" in requirement) != ("height" in requirement):
            raise ProbeError("Semantic proof image %r must specify width and height together." % pattern)
        if "width" in requirement and "height" in requirement:
            width = int(requirement.get("width", -1))
            height = int(requirement.get("height", -1))
            if not any(item["path"] in {str(path) for path in matches} and item["width"] == width and item["height"] == height for item in stats):
                raise ProbeError("Semantic proof image %r did not include exact size %dx%d." % (pattern, width, height))
        regions = requirement.get("regions", [])
        if not isinstance(regions, list):
            raise ProbeError("Semantic proof regions for %r must be a list" % pattern)
        for region_index, region in enumerate(regions):
            if not isinstance(region, dict) or not isinstance(region.get("rect"), list) or len(region["rect"]) != 4:
                raise ProbeError("Semantic proof region %d for %r needs rect [x,y,width,height]" % (region_index, pattern))
            rect = tuple(int(value) for value in region["rect"])
            minimum_range = float(region.get("min_luma_range", 3.0))
            minimum_stdev = float(region.get("min_luma_stdev", 0.75))
            region_valid = False
            for path in matches:
                decoded = decoded_cache.get(path)
                if decoded is None:
                    decoded = decode_png(path)
                    decoded_cache[path] = decoded
                try:
                    item = luma_stats(decoded, rect)
                except ProbeError:
                    continue
                if item["luma_range"] >= minimum_range and item["luma_stdev"] >= minimum_stdev:
                    region_valid = True
                    break
            if not region_valid:
                raise ProbeError(
                    "Semantic proof region %s for %r lacks required variation (range >= %.2f, stdev >= %.2f)."
                    % (rect, pattern, minimum_range, minimum_stdev)
                )


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


def parse_size(value: str) -> tuple[int, int]:
    match = re.fullmatch(r"(\d+)[xX](\d+)", value.strip())
    if match is None:
        raise argparse.ArgumentTypeError("expected WIDTHxHEIGHT, got %r" % value)
    width, height = int(match.group(1)), int(match.group(2))
    if width <= 0 or height <= 0:
        raise argparse.ArgumentTypeError("screenshot dimensions must be positive")
    return width, height


def rendering_driver_candidates(args: argparse.Namespace) -> list[str]:
    if args.rendering_driver:
        requested = [args.rendering_driver, *args.fallback_rendering_driver]
    elif not args.headless and args.display_driver == "macos":
        # ANGLE has been the most reliable capture path on macOS; retain the
        # native default as an automatic fallback for host-specific failures.
        requested = ["opengl3_angle", "", *args.fallback_rendering_driver]
    else:
        requested = ["", *args.fallback_rendering_driver]
    return list(dict.fromkeys(requested))


def generated_metadata_snapshot(project: Path) -> dict[str, str]:
    result = subprocess.run(
        ["git", "-C", str(project), "ls-files", "-co", "--exclude-standard", "-z", "--", "*.import", "*.uid"],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    if result.returncode != 0:
        return {}
    snapshot: dict[str, str] = {}
    for raw_path in result.stdout.split(b"\0"):
        if not raw_path:
            continue
        relative = os.fsdecode(raw_path)
        path = project / relative
        if path.is_file():
            snapshot[relative] = hashlib.sha256(path.read_bytes()).hexdigest()
    return snapshot


def generated_metadata_changes(before: dict[str, str], after: dict[str, str]) -> list[str]:
    return sorted(path for path in set(before) | set(after) if before.get(path) != after.get(path))


@contextmanager
def gui_render_lease(args: argparse.Namespace):
    if args.headless or not args.gui_lease or fcntl is None:
        yield
        return
    lock_path = Path(args.gui_lease_path).expanduser().resolve()
    lock_path.parent.mkdir(parents=True, exist_ok=True)
    deadline = time.monotonic() + args.gui_lease_timeout
    with lock_path.open("a+", encoding="utf-8") as handle:
        while True:
            try:
                fcntl.flock(handle.fileno(), fcntl.LOCK_EX | fcntl.LOCK_NB)
                break
            except BlockingIOError:
                if time.monotonic() >= deadline:
                    raise ProbeError("Timed out waiting %.1f seconds for GUI render lease %s" % (args.gui_lease_timeout, lock_path))
                time.sleep(0.1)
        print("Acquired GUI render lease: %s" % lock_path)
        try:
            yield
        finally:
            fcntl.flock(handle.fileno(), fcntl.LOCK_UN)


def load_proof_contract(path_value: str) -> dict[str, Any]:
    if not path_value:
        return {}
    path = Path(path_value).expanduser().resolve()
    try:
        payload = json.loads(path.read_text())
    except (OSError, json.JSONDecodeError) as exc:
        raise ProbeError("Could not read proof contract %s: %s" % (path, exc)) from exc
    if not isinstance(payload, dict):
        raise ProbeError("Proof contract %s must contain a JSON object" % path)
    return payload


def write_result_manifest(path_value: str, payload: dict[str, Any], *, overwrite: bool = False) -> None:
    if not path_value:
        return
    path = Path(path_value).expanduser().resolve()
    if path.exists() and not overwrite:
        raise ProbeError("Refusing to overwrite existing visual proof manifest %s; use a fresh path or --overwrite-result-manifest." % path)
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n")
    print("Visual proof result manifest: %s" % path)


def command_run(args: argparse.Namespace) -> int:
    project = Path(args.project).resolve()
    if args.result_manifest and Path(args.result_manifest).expanduser().resolve().exists() and not args.overwrite_result_manifest:
        raise ProbeError("Refusing to overwrite existing visual proof manifest %s; use a fresh path or --overwrite-result-manifest." % Path(args.result_manifest).expanduser().resolve())
    task_id = slugify(args.task_id or infer_task_id(project))
    script_stem = slugify(Path(args.script).stem)
    drivers = rendering_driver_candidates(args)
    proof_contract = load_proof_contract(args.proof_contract)
    raw_contract_sizes = proof_contract.get("expected_sizes", [])
    if not isinstance(raw_contract_sizes, list):
        raise ProbeError("proof contract expected_sizes must be a list")
    try:
        contract_sizes = [parse_size(str(value)) for value in raw_contract_sizes]
    except argparse.ArgumentTypeError as exc:
        raise ProbeError("Invalid proof contract expected_sizes: %s" % exc) from exc
    expected_sizes = list(dict.fromkeys([*args.expect_size, *contract_sizes]))
    min_images = max(args.min_images, int(proof_contract.get("min_images", 0)))
    metadata_before = generated_metadata_snapshot(project)
    attempt_records: list[dict[str, Any]] = []
    last_error = ""
    for driver in drivers:
        for attempt in range(1, args.attempts + 1):
            namespace = make_probe_namespace(task_id, script_stem, attempt)
            try:
                with gui_render_lease(args):
                    result, home_dir = run_probe(args, namespace, driver)
            except subprocess.TimeoutExpired:
                last_error = "Godot probe timed out after %d seconds" % args.timeout
                attempt_records.append({"namespace": namespace, "driver": driver, "attempt": attempt, "accepted": False, "error": last_error, "images": []})
                print("visual probe attempt failed: %s" % last_error, file=sys.stderr)
                continue
            combined_output = result.stdout + "\n" + result.stderr
            if not args.allow_generated_metadata:
                metadata_changed = generated_metadata_changes(metadata_before, generated_metadata_snapshot(project))
                if metadata_changed:
                    raise ProbeError(
                        "Visual probe changed generated .import/.uid metadata; remove or intentionally allow these paths:\n%s"
                        % "\n".join("  %s" % path for path in metadata_changed)
                    )
            user_dir_name = "Labyrinth of Ash Parallel %s" % namespace
            pngs = collect_pngs(combined_output, user_dir_name, home_dir)
            try:
                if result.returncode != 0:
                    raise ProbeError("Godot exited with code %d" % result.returncode)
                if godot_output_has_failure(combined_output):
                    raise ProbeError("Godot reported script or test failures despite exit code 0.")
                stats = validate_pngs(pngs, min_images, expected_sizes, proof_contract)
            except ProbeError as exc:
                last_error = str(exc)
                attempt_records.append(
                    {
                        "namespace": namespace,
                        "driver": driver,
                        "attempt": attempt,
                        "returncode": result.returncode,
                        "accepted": False,
                        "error": last_error,
                        "images": [str(path) for path in pngs],
                    }
                )
                print("visual probe attempt failed: %s" % last_error, file=sys.stderr)
                continue
            attempt_records.append(
                {
                    "namespace": namespace,
                    "driver": driver,
                    "attempt": attempt,
                    "returncode": result.returncode,
                    "accepted": True,
                    "error": "",
                    "images": stats,
                }
            )
            print("Validated %d screenshot(s):" % len(stats))
            for item in stats:
                print("  {path} {width}x{height} luma={luma_mean:.1f} range={luma_range:.1f} stdev={luma_stdev:.1f}".format(**item))
            write_result_manifest(
                args.result_manifest,
                {
                    "ok": True,
                    "namespace": namespace,
                    "script": args.script,
                    "command": build_command(args, driver, None),
                    "rendering_driver": driver,
                    "expected_sizes": [list(size) for size in expected_sizes],
                    "proof_contract": str(Path(args.proof_contract).resolve()) if args.proof_contract else "",
                    "images": stats,
                    "attempts": attempt_records,
                },
                overwrite=args.overwrite_result_manifest,
            )
            return 0
    if args.result_manifest:
        write_result_manifest(
            args.result_manifest,
            {
                "ok": False,
                "script": args.script,
                "expected_sizes": [list(size) for size in expected_sizes],
                "proof_contract": str(Path(args.proof_contract).resolve()) if args.proof_contract else "",
                "error": last_error or "visual probe failed",
                "attempts": attempt_records,
                "images": [],
            },
            overwrite=args.overwrite_result_manifest,
        )
    raise ProbeError(last_error or "visual probe failed")


def godot_output_has_failure(output: str) -> bool:
    return any(marker in output for marker in FAILURE_MARKERS)


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("script", help="Godot probe script, e.g. tests/ui_probe.gd")
    parser.add_argument("--project", default=".", help="Godot project directory.")
    parser.add_argument("--task-id", default="", help="Stable task id for user:// namespacing.")
    parser.add_argument("--godot", default="godot")
    parser.add_argument("--timeout", type=int, default=180)
    parser.add_argument("--attempts", type=int, default=2)
    parser.add_argument("--min-images", type=int, default=1)
    parser.add_argument("--expect-size", action="append", type=parse_size, default=[], help="Require an emitted screenshot at exact WIDTHxHEIGHT; repeatable.")
    parser.add_argument("--proof-contract", default="", help="JSON contract with expected_sizes and semantic required_images/regions.")
    parser.add_argument("--result-manifest", "--report-json", dest="result_manifest", default="", help="Write validated proof and attempt metadata to a fresh JSON path.")
    parser.add_argument("--overwrite-result-manifest", action="store_true")
    parser.add_argument("--headless", dest="headless", action="store_true", default=True)
    parser.add_argument("--no-headless", dest="headless", action="store_false")
    parser.add_argument("--display-driver", default="")
    parser.add_argument("--audio-driver", default="")
    parser.add_argument("--rendering-driver", default="")
    parser.add_argument("--fallback-rendering-driver", action="append", default=[])
    parser.add_argument("--isolated-home", dest="isolated_home", action="store_true", default=True)
    parser.add_argument("--no-isolated-home", dest="isolated_home", action="store_false")
    parser.add_argument("--godot-home-root", default="/private/tmp/labyrinth-godot-home")
    parser.add_argument("--gui-lease", dest="gui_lease", action="store_true", default=True, help="Serialize non-headless renderer access.")
    parser.add_argument("--no-gui-lease", dest="gui_lease", action="store_false")
    parser.add_argument("--gui-lease-path", default="/private/tmp/labyrinth-gui-render.lock")
    parser.add_argument("--gui-lease-timeout", type=float, default=120.0)
    parser.add_argument("--allow-generated-metadata", action="store_true", help="Allow probe-created .import/.uid changes in the worktree.")
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
