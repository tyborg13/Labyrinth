from __future__ import annotations

import json
import math
from pathlib import Path
import re
import subprocess

from .common import (
    PipelineError,
    read_json,
    require_executable,
    resolve_from,
    run_json,
    sha256,
    verify_source_clearance,
    write_json,
)
from .render import read_midi_notes


def _probe(path: Path) -> dict[str, object]:
    return run_json([
        "ffprobe", "-v", "error", "-show_entries",
        "format=duration,size:stream=codec_name,sample_rate,channels",
        "-of", "json", str(path),
    ])


def _duration(probe: dict[str, object]) -> float:
    fmt = probe.get("format")
    if not isinstance(fmt, dict):
        raise PipelineError("ffprobe did not return a format object")
    return float(fmt["duration"])


def _strict_decode(path: Path) -> None:
    try:
        subprocess.run(
            ["ffmpeg", "-v", "error", "-xerror", "-i", str(path), "-f", "null", "-"],
            check=True,
            capture_output=True,
        )
    except subprocess.CalledProcessError as exc:
        raise PipelineError(f"Strict decode failed for {path}: {exc.stderr.decode(errors='replace')}") from exc


def _peak_dbfs(path: Path) -> float:
    result = subprocess.run(
        ["ffmpeg", "-hide_banner", "-i", str(path), "-af", "volumedetect", "-f", "null", "-"],
        capture_output=True,
        text=True,
    )
    match = re.search(r"max_volume:\s+(-?[0-9.]+) dB", result.stderr)
    if not match:
        raise PipelineError(f"Could not measure peak for {path}")
    return float(match.group(1))


def _long_silences(path: Path, threshold_seconds: float) -> list[str]:
    result = subprocess.run(
        ["ffmpeg", "-hide_banner", "-i", str(path), "-af", f"silencedetect=n=-60dB:d={threshold_seconds}", "-f", "null", "-"],
        capture_output=True,
        text=True,
    )
    return [line.strip() for line in result.stderr.splitlines() if "silence_duration:" in line]


def verify_track(config_path: Path, output_dir: Path | None = None, report_path: Path | None = None) -> dict[str, object]:
    require_executable("ffmpeg")
    require_executable("ffprobe")
    config_path = config_path.resolve()
    config = read_json(config_path)
    source_report = verify_source_clearance(config, config_path)
    render = config.get("render")
    arrangement = config.get("arrangement")
    expected = config.get("expected_outputs", {})
    rules = config.get("verification", {})
    if not isinstance(render, dict) or not isinstance(arrangement, dict) or not isinstance(expected, dict) or not isinstance(rules, dict):
        raise PipelineError("Invalid render, arrangement, expected_outputs, or verification object")
    bank_path = resolve_from(config_path, str(render.get("bank_manifest", "")))
    bank = read_json(bank_path)
    bank_results: dict[str, str] = {}
    for raw in bank.get("samples", []):
        if not isinstance(raw, dict):
            raise PipelineError("Invalid bank sample entry")
        sample_path = resolve_from(bank_path, str(raw["path"]))
        actual = sha256(sample_path)
        if actual != str(raw["sha256"]):
            raise PipelineError(f"Bank hash mismatch for {sample_path}")
        bank_results[str(raw["bank_id"])] = actual
    notes, structural_seconds, counts = read_midi_notes(config, config_path)
    expected_counts = arrangement.get("expected_note_counts", {})
    if not isinstance(expected_counts, dict):
        raise PipelineError("arrangement.expected_note_counts must be an object")
    for name, count in expected_counts.items():
        if counts.get(str(name)) != int(count):
            raise PipelineError(f"MIDI note-count mismatch for {name}: expected {count}, got {counts.get(str(name))}")
    destination = output_dir.resolve() if output_dir else config_path.parent
    basename = str(render.get("output_basename", "preview"))
    # output_basename may itself contain version directories for a scaffold.
    ogg_path = destination / f"{basename}.ogg"
    flac_path = destination / f"{basename}.flac"
    for path in (ogg_path, flac_path):
        if not path.is_file():
            raise PipelineError(f"Missing rendered preview: {path}")
        _strict_decode(path)
    actual_hashes = {"ogg_sha256": sha256(ogg_path), "flac_sha256": sha256(flac_path)}
    for key, actual in actual_hashes.items():
        configured = str(expected.get(key, ""))
        if configured and configured != actual:
            raise PipelineError(f"Expected {key} {configured}, got {actual}")
    ogg_probe = _probe(ogg_path)
    flac_probe = _probe(flac_path)
    crossfade_seconds = float(render.get("crossfade_seconds", 0.0))
    expected_duration = structural_seconds - crossfade_seconds
    tolerance = float(rules.get("duration_tolerance_seconds", 0.02))
    flac_duration = _duration(flac_probe)
    if abs(flac_duration - expected_duration) > tolerance:
        raise PipelineError(f"Rendered duration {flac_duration:.6f}s differs from expected {expected_duration:.6f}s")
    peak = _peak_dbfs(flac_path)
    target_peak = float(render.get("target_peak_dbfs", -7.5))
    if abs(peak - target_peak) > float(rules.get("peak_tolerance_db", 0.05)):
        raise PipelineError(f"Rendered peak {peak:.3f} dBFS differs from target {target_peak:.3f} dBFS")
    max_silence = rules.get("max_silence_seconds")
    silences = [] if max_silence is None else _long_silences(flac_path, float(max_silence))
    if silences:
        raise PipelineError(f"Unexpected long silences: {silences}")
    report = {
        "ok": True,
        "track_id": config.get("track_id"),
        "config_sha256": sha256(config_path),
        "source": source_report,
        "bank_manifest_sha256": sha256(bank_path),
        "bank_sample_hashes": bank_results,
        "midi": {
            "path": str(resolve_from(config_path, str(arrangement["midi_path"]))),
            "sha256": sha256(resolve_from(config_path, str(arrangement["midi_path"]))),
            "note_counts": counts,
            "configured_tracks": sorted(notes),
            "structural_duration_seconds": structural_seconds,
        },
        "audio": {
            **actual_hashes,
            "ogg": ogg_probe,
            "flac": flac_probe,
            "strict_decode": True,
            "peak_dbfs": peak,
            "long_silence_events": silences,
        },
    }
    if report_path:
        write_json(report_path, report)
    return report
