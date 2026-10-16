"""One native take at a time, with no retained Movie Maker frame sequences."""
from __future__ import annotations

import argparse
import json
from pathlib import Path
import re
import shutil
import subprocess
import sys
import time

from tools.demo_clips import capture_setup, comparison, media, pipeline, storage, sync

CAPTURE_SIZE = (1920, 1080)


def prepare_take(directory):
    """Replace this clip's generated outputs, preserving unrelated files."""
    if directory.is_symlink(): raise ValueError(f"Take directory is a symlink: {directory}")
    directory.mkdir(parents=True, exist_ok=True)
    names = {"movie.avi", "movie.wav", "movie.mkv", "movie.partial.mkv", "events.json", "godot.log", "audit.json"}
    for path in directory.iterdir():
        if path.name in names or re.fullmatch(r"(?:movie\d+\.png|cue-\d+\.wav)", path.name):
            path.unlink()
    project = directory / "capture-project"
    if project.is_symlink(): project.unlink()
    elif project.exists(): shutil.rmtree(project)
    capture_setup.prepare_project(directory, pipeline.ROOT)


def validation_rows(output, provenance):
    validation = json.loads((output / "validate-report.json").read_text())
    if validation["failures"]: raise ValueError("Headless validation failed; recording refused")
    if validation["input_hashes"] != provenance:
        raise ValueError("Validation inputs changed; validate the current recording inputs first")
    rows = {row["clip"]: row for row in validation["results"]}
    for row in rows.values():
        if not row.get("fixture_valid") or not row.get("deterministic") or row.get("errors"):
            raise ValueError(f"{row['clip']}: headless fixture/action validation failed")
        report = pipeline.compare(*(Path(path) for path in row["logs"]))
        if not report["headless"]: raise ValueError("Expected the headless double-run validation")
    return rows


def capture(clip_id, directory):
    sys.path.insert(0, str(pipeline.ROOT / "tools"))
    import visual_probe_runner
    lease = visual_probe_runner.gui_render_lease(argparse.Namespace(
        headless=False, gui_lease=True, gui_lease_path="/private/tmp/labyrinth-gui-render.lock",
        gui_lease_timeout=pipeline.GUI_LEASE_TIMEOUT_S))
    cmd = pipeline.command(clip_id, directory, True)
    print("RUN", " ".join(cmd), flush=True)
    with lease:
        # The task runner owns its watchdog and child-process termination.
        # Do not kill that supervisor from an outer subprocess timeout.
        result = subprocess.run(cmd, cwd=pipeline.ROOT, capture_output=True, text=True)
    (directory / "godot.log").write_text(result.stdout + result.stderr)
    for line in result.stdout.splitlines():
        if line.startswith(("DEMO CLIP", "DEMO ERROR", "DEMO CAPTURE SETTINGS")): print(line, flush=True)
    if result.returncode: raise ValueError(f"Native capture process exit {result.returncode}")


def record_clip(clip_id, directory, validated, rules):
    started = time.perf_counter()
    reference = Path(validated["logs"][0])
    row = {"clip": clip_id, "deterministic": False, "fixture_valid": False,
           "errors": [], "sync_table": [], "sync_flags": [], "native_frame_offset_profile": [], "timing_exemptions": [], "validation_log": str(reference),
           "logs": [str(directory / "events.json"), str(reference)]}
    try:
        row["validation_sha256"] = storage.file_hash(reference)
        capture_started = time.perf_counter()
        try:
            capture(clip_id, directory)
        finally:
            row["capture_wall_s"] = time.perf_counter() - capture_started
        row.update(capture_setup.log_proof((directory / "godot.log").read_text()))
        avi = media.prepare_avi(directory, CAPTURE_SIZE)
        row.update(intermediate=avi["path"], raw_frame_count=avi["frame_count"], audio_codec=avi["audio_codec"])
        report, profile, exemptions = comparison.compare_native(directory / "events.json", reference)
        row.update(deterministic=True, fixture_valid=report["fixture_valid"], native_frame_offset_profile=profile,
                   timing_exemptions=exemptions)
        if report["errors"] or not report["fixture_valid"]:
            raise ValueError("Native fixture/action validation failed")
        row.update(media.duration_info(directory, report, CAPTURE_SIZE))
        row["sync_table"], row["sync_flags"] = sync.audit(directory, report, rules)
    except (OSError, ValueError, KeyError, subprocess.SubprocessError) as exc:
        row["errors"].append(str(exc))
        if isinstance(exc, comparison.ComparisonError):
            row["native_frame_offset_profile"] = exc.offset_profile
            row["timing_exemptions"] = exc.timing_exemptions
    finally:
        # Legacy files only: current Movie Maker capture writes no PNGs.
        row["deleted_frame_count"] = media.remove_frames(directory)
        row["clip_wall_s"] = time.perf_counter() - started
        row["seconds_per_frame"] = (row["capture_wall_s"] / row["raw_frame_count"]
                                    if row.get("raw_frame_count") and "capture_wall_s" in row else None)
    row["capture_hashes"] = storage.capture_hashes(directory)
    (directory / "audit.json").write_text(json.dumps(row, indent=2) + "\n")
    return row


def checked_take(output, clip_id, recorded):
    indexed = {row["clip"]: row for row in recorded["results"]}
    if clip_id not in indexed: raise ValueError(f"{clip_id}: take is missing")
    row = indexed[clip_id]
    if row["errors"] or not row["deterministic"] or not row["fixture_valid"]:
        raise ValueError(f"{clip_id}: take failed validation: {'; '.join(row['errors'])}")
    directory = output / "raw" / clip_id
    receipt = json.loads((directory / "audit.json").read_text())
    if receipt != row or row["errors"] or not row["deterministic"] or not row["fixture_valid"]:
        raise ValueError(f"{clip_id}: recording audit failed or changed")
    if list(directory.glob("movie*.png")):
        raise ValueError(f"{clip_id}: unexpected retained movie frame sequence")
    if storage.capture_hashes(directory) != row["capture_hashes"]:
        raise ValueError(f"{clip_id}: recorded media/logs changed after audit")
    proof = capture_setup.log_proof((directory / "godot.log").read_text())
    if any(row.get(key) != value for key, value in proof.items()):
        raise ValueError(f"{clip_id}: renderer/quality proof changed")
    reference = Path(row["validation_log"])
    if storage.file_hash(reference) != row["validation_sha256"]:
        raise ValueError(f"{clip_id}: headless reference changed after capture")
    report, profile, exemptions = comparison.compare_native(directory / "events.json", reference)
    if report["errors"] or not report["fixture_valid"]: raise ValueError(f"{clip_id}: native fixture/action validation failed")
    if profile != row["native_frame_offset_profile"]: raise ValueError(f"{clip_id}: recorded frame offset profile changed")
    if exemptions != row.get("timing_exemptions", []): raise ValueError(f"{clip_id}: recorded timing exemptions changed")
    return directory, report, row


def compare_all(selected, output):
    recorded = json.loads((output / "record-report.json").read_text())
    if recorded["input_hashes"] != pipeline.hashes(): raise ValueError("Recording inputs changed")
    indexed = {row["clip"]: row for row in recorded["results"]}
    result = {"mode": "compare", "results": [], "failures": [], "input_hashes": recorded["input_hashes"]}
    for clip in selected:
        clip_id = clip["id"]
        row = {"clip": clip_id, "deterministic": False, "errors": [],
               "native_frame_offset_profile": indexed.get(clip_id, {}).get("native_frame_offset_profile", []),
               "timing_exemptions": indexed.get(clip_id, {}).get("timing_exemptions", [])}
        try:
            _, _, checked = checked_take(output, clip_id, recorded)
            row.update(deterministic=True, native_frame_offset_profile=checked["native_frame_offset_profile"],
                       timing_exemptions=checked.get("timing_exemptions", []))
        except (OSError, ValueError, KeyError) as exc:
            row["errors"].append(str(exc))
            if isinstance(exc, comparison.ComparisonError):
                row["native_frame_offset_profile"] = exc.offset_profile
                row["timing_exemptions"] = exc.timing_exemptions
            result["failures"].append(f"{clip_id}: {exc}")
        result["results"].append(row)
        print(f"DEMO NATIVE VS HEADLESS {clip_id}: {'FAIL' if row['errors'] else 'PASS'} "
              f"(native lag profile {comparison.format_profile(row['native_frame_offset_profile'])})", flush=True)
        print_exemptions(row)
    storage.write_result(output, "compare-report.json", result)
    print(f"DEMO COMPARE RESULT: {'FAIL' if result['failures'] else 'PASS'} ({len(selected)} clips, {len(result['failures'])} failures)", flush=True)
    return bool(result["failures"])


def print_timings(rows):
    print("DEMO CAPTURE TIMING", flush=True)
    print("clip | capture wall s | raw frames | seconds/frame | total clip wall s", flush=True)
    def seconds(value): return f"{value:.6f}" if value is not None else "—"
    for row in rows:
        print(f"{row['clip']} | {seconds(row.get('capture_wall_s'))} | {row.get('raw_frame_count', '—')} | "
              f"{seconds(row.get('seconds_per_frame'))} | {seconds(row.get('clip_wall_s'))}", flush=True)


def print_exemptions(row):
    for item in row.get("timing_exemptions", []):
        print(f"DEMO TIMING EXEMPTION {row['clip']} {item['item']}: "
              f"H{item['headless_frame']}/N{item['native_frame']} {item['offset']:+d}; {item['cause']}", flush=True)


def run(selected, output):
    storage.print_free(output, "START")
    result = {"mode": "record", "results": [], "failures": [], "complete": False,
              "requested_clips": [c["id"] for c in selected], "input_hashes": pipeline.hashes()}
    try:
        # Before markers, report writes or any per-clip directory creation.
        storage.require_space(output)
        validated = validation_rows(output, result["input_hashes"])
        # Clear legacy interrupted PNG sequences before any AVI capture.
        for clip in selected:
            directory = output / "raw" / clip["id"]
            if directory.is_symlink(): raise ValueError(f"Take directory is a symlink: {directory}")
            media.remove_frames(directory)
        pending = [p for p in (output / "raw").rglob("movie*.png") if re.fullmatch(r"movie\d+\.png", p.name)]
        if pending: raise ValueError(f"Unprocessed Movie Maker frames already exist: {pending[0]}; no new capture started")
        rules = json.loads((pipeline.ROOT / "data/sfx_cues.json").read_text())["rules"]["sync"]
        for clip in selected:
            storage.require_space(output)
            directory = output / "raw" / clip["id"]
            output.mkdir(parents=True, exist_ok=True)
            (output / ".gitignore").write_text("*\n")
            (output / ".gdignore").touch()
            try:
                prepare_take(directory)
                row = record_clip(clip["id"], directory, validated[clip["id"]], rules)
            except (OSError, ValueError, KeyError, subprocess.SubprocessError) as exc:
                row = {"clip": clip["id"], "deterministic": False, "fixture_valid": False,
                       "errors": [str(exc)], "sync_table": [], "sync_flags": [],
                       "native_frame_offset_profile": [], "deleted_frame_count": 0}
            result["results"].append(row)
            result["failures"].extend(f"{clip['id']}: {error}" for error in row["errors"])
            storage.write_result(output, "record-report.json", result)
            print(f"DEMO NATIVE VS HEADLESS {clip['id']}: {'FAIL' if row['errors'] else 'PASS'} "
                  f"(native lag profile {comparison.format_profile(row['native_frame_offset_profile'])})", flush=True)
            print_exemptions(row)
        if pipeline.hashes() != result["input_hashes"]:
            result["failures"].append("Inputs changed during capture; this report cannot authorize encoding")
        result["complete"] = not result["failures"] and len(result["results"]) == len(selected)
        result["sync_summary"] = sync.summary(result["results"])
        storage.write_result(output, "record-report.json", result)
    except (OSError, ValueError, KeyError, subprocess.SubprocessError) as exc:
        # A disk-guard failure writes nothing, including no new error report.
        result["failures"].append(str(exc))
        print(f"DEMO RECORD ERROR: {exc}", flush=True)
    finally:
        storage.print_free(output, "END")
        storage.print_size(output)
    failed = bool(result["failures"]) or not result["complete"]
    print_timings(result["results"])
    sync.print_summary(sync.summary(result["results"]))
    for failure in result["failures"]: print("DEMO TAKE FAILURE: " + failure, flush=True)
    print(f"DEMO RECORD RESULT: {'FAIL' if failed else 'PASS'} ({len(result['results'])}/{len(selected)} clips, {len(result['failures'])} failures)", flush=True)
    return failed
