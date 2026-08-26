from __future__ import annotations

import math
from pathlib import Path
import re
import subprocess

import numpy as np

from .common import (
    PipelineError,
    read_json,
    require_executable,
    resolve_from,
    run_json,
    sha256,
    verify_source_clearance,
    verify_reproducibility,
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


def _decoded_metrics(path: Path, sample_rate: int) -> dict[str, object]:
    result = subprocess.run(
        ["ffmpeg", "-v", "error", "-xerror", "-i", str(path), "-f", "f32le", "-acodec", "pcm_f32le", "-ac", "2", "-"],
        check=True,
        capture_output=True,
    )
    pcm = np.frombuffer(result.stdout, dtype="<f4")
    if len(pcm) < 4 or len(pcm) % 2:
        raise PipelineError(f"Decoded audio has an invalid stereo frame count: {path}")
    frames = pcm.reshape((-1, 2))
    adjacent = np.abs(np.diff(frames, axis=0))
    seam = np.abs(frames[0] - frames[-1])
    typical = np.percentile(adjacent, 99.9, axis=0)
    peak = float(np.max(np.abs(frames)))
    return {
        "decoded_frames": len(frames),
        "duration_seconds": len(frames) / sample_rate,
        "first_frame": frames[0].astype(float).tolist(),
        "last_frame": frames[-1].astype(float).tolist(),
        "first_last_sample_delta": seam.astype(float).tolist(),
        "p99_9_adjacent_sample_delta": typical.astype(float).tolist(),
        "peak_dbfs": 20.0 * math.log10(max(peak, 1e-12)),
    }


def _validate_loop_seam(metrics: dict[str, object], maximum_ratio: float, label: str) -> None:
    seam = metrics.get("first_last_sample_delta")
    typical = metrics.get("p99_9_adjacent_sample_delta")
    if not isinstance(seam, list) or not isinstance(typical, list) or len(seam) != 2 or len(typical) != 2:
        raise PipelineError(f"Invalid decoded loop metrics for {label}")
    floor = 1.0 / 32768.0
    ratios = [float(seam[index]) / max(float(typical[index]), floor) for index in range(2)]
    metrics["seam_to_p99_9_ratio"] = ratios
    if max(ratios) > maximum_ratio:
        raise PipelineError(
            f"Decoded loop seam for {label} exceeds the configured ratio {maximum_ratio}: {ratios}"
        )


def _long_silences(path: Path, threshold_seconds: float) -> list[str]:
    result = subprocess.run(
        ["ffmpeg", "-hide_banner", "-i", str(path), "-af", f"silencedetect=n=-60dB:d={threshold_seconds}", "-f", "null", "-"],
        capture_output=True,
        text=True,
    )
    return [line.strip() for line in result.stderr.splitlines() if "silence_duration:" in line]


def _required_track_names(config: dict[str, object]) -> set[str]:
    render = config.get("render")
    if not isinstance(render, dict):
        raise PipelineError("render must be an object")
    tracks = render.get("tracks")
    percussion = render.get("percussion", {})
    if not isinstance(tracks, list) or not isinstance(percussion, dict):
        raise PipelineError("render tracks/percussion are invalid")
    names = {str(track.get("midi_track", "")) for track in tracks if isinstance(track, dict)}
    percussion_name = str(percussion.get("midi_track", ""))
    if percussion_name:
        names.add(percussion_name)
    if not names or "" in names:
        raise PipelineError("Every configured render track must have a MIDI track name")
    return names


def require_promotion_ready(config: dict[str, object], config_path: Path) -> dict[str, object]:
    approval = config.get("approval")
    arrangement = config.get("arrangement")
    render = config.get("render")
    expected = config.get("expected_outputs")
    if not isinstance(approval, dict) or approval.get("status") != "approved":
        raise PipelineError("Promotion requires approval.status=approved")
    if not isinstance(arrangement, dict) or not isinstance(render, dict) or not isinstance(expected, dict):
        raise PipelineError("Promotion requires arrangement, render, and expected_outputs objects")
    if approval.get("version") != arrangement.get("version"):
        raise PipelineError("Approved version must match arrangement.version")
    for key in ("approved_by", "approved_on"):
        if not str(approval.get(key, "")).strip():
            raise PipelineError(f"Promotion requires approval.{key}")
    if not re.fullmatch(r"\d{4}-\d{2}-\d{2}", str(approval["approved_on"])):
        raise PipelineError("approval.approved_on must use YYYY-MM-DD")
    if str(render.get("vorbis_encoder", "")) not in {"native", "libvorbis"}:
        raise PipelineError("Promotion requires a frozen native or libvorbis encoder, not auto")
    for key in ("midi_sha256",):
        if not re.fullmatch(r"[0-9a-f]{64}", str(arrangement.get(key, ""))):
            raise PipelineError(f"Promotion requires arrangement.{key}")
    for key in ("ogg_sha256", "flac_sha256"):
        if not re.fullmatch(r"[0-9a-f]{64}", str(expected.get(key, ""))):
            raise PipelineError(f"Promotion requires frozen expected_outputs.{key}")
    counts = arrangement.get("expected_note_counts")
    required_tracks = _required_track_names(config)
    if not isinstance(counts, dict) or set(map(str, counts)) != required_tracks:
        raise PipelineError("Promotion requires complete expected note counts for every configured track")
    if any(int(value) <= 0 for value in counts.values()):
        raise PipelineError("Promotion note counts must be positive")
    return {
        "approval": dict(approval),
        "required_tracks": sorted(required_tracks),
        "reproducibility": verify_reproducibility(config, config_path),
    }


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
    if not re.fullmatch(r"[0-9a-f]{64}", str(arrangement.get("midi_sha256", ""))):
        raise PipelineError("Verification requires arrangement.midi_sha256")
    reproducibility_report = verify_reproducibility(config, config_path)
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
    required_tracks = _required_track_names(config)
    if not isinstance(expected_counts, dict) or set(map(str, expected_counts)) != required_tracks:
        raise PipelineError("arrangement.expected_note_counts must cover every configured track exactly")
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
    sample_rate = int(render.get("sample_rate", 44_100))
    decoded = {
        "ogg": _decoded_metrics(ogg_path, sample_rate),
        "flac": _decoded_metrics(flac_path, sample_rate),
    }
    seam_limit = float(rules.get("max_loop_seam_to_p99_9_ratio", 1.0))
    for label, probe, metrics in (
        ("ogg", ogg_probe, decoded["ogg"]),
        ("flac", flac_probe, decoded["flac"]),
    ):
        container_duration = _duration(probe)
        decoded_duration = float(metrics["duration_seconds"])
        if abs(container_duration - expected_duration) > tolerance or abs(decoded_duration - expected_duration) > tolerance:
            raise PipelineError(
                f"{label} duration differs from expected {expected_duration:.6f}s: container={container_duration:.6f}, decoded={decoded_duration:.6f}"
            )
        _validate_loop_seam(metrics, seam_limit, label)
    peak = float(decoded["flac"]["peak_dbfs"])
    target_peak = float(render.get("target_peak_dbfs", -7.5))
    if abs(peak - target_peak) > float(rules.get("peak_tolerance_db", 0.05)):
        raise PipelineError(f"Rendered peak {peak:.3f} dBFS differs from target {target_peak:.3f} dBFS")
    max_silence = rules.get("max_silence_seconds")
    silences = {
        "ogg": [] if max_silence is None else _long_silences(ogg_path, float(max_silence)),
        "flac": [] if max_silence is None else _long_silences(flac_path, float(max_silence)),
    }
    if silences["ogg"] or silences["flac"]:
        raise PipelineError(f"Unexpected long silences: {silences}")
    report = {
        "ok": True,
        "track_id": config.get("track_id"),
        "config_sha256": sha256(config_path),
        "source": source_report,
        "reproducibility": reproducibility_report,
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
            "decoded_loop_metrics": decoded,
            "long_silence_events": silences,
        },
    }
    if report_path:
        write_json(report_path, report)
    return report
