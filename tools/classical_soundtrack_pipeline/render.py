from __future__ import annotations

from collections import defaultdict
from dataclasses import dataclass
import math
from pathlib import Path
import subprocess
import tempfile

import mido
import numpy as np

from .bank import midi_frequency
from .common import (
    PipelineError,
    assert_publishable,
    load_mono_wave,
    normalize_ogg_serial,
    publish_immutable,
    read_json,
    require_executable,
    resolve_from,
    sha256,
    verify_source_clearance,
    write_json,
    write_stereo_wave,
)


@dataclass(frozen=True)
class RenderNote:
    start_seconds: float
    end_seconds: float
    pitch: int
    velocity: int


def _track_name(track: mido.MidiTrack) -> str:
    for message in track:
        if message.type == "track_name":
            return message.name
    return ""


def _seconds_per_tick(config: dict[str, object], midi: mido.MidiFile) -> float:
    render = config["render"]
    if not isinstance(render, dict):
        raise PipelineError("render must be an object")
    if render.get("tempo_mode", "fixed_qpm") != "fixed_qpm":
        raise PipelineError(
            "This renderer currently requires render.tempo_mode=fixed_qpm. "
            "Flatten expressive tempo changes in the versioned arrangement build before rendering."
        )
    qpm = float(render.get("tempo_qpm", 0.0))
    if qpm <= 0:
        raise PipelineError("render.tempo_qpm must be positive")
    return 60.0 / (qpm * midi.ticks_per_beat)


def read_midi_notes(config: dict[str, object], config_path: Path) -> tuple[dict[str, list[RenderNote]], float, dict[str, int]]:
    arrangement = config.get("arrangement")
    render = config.get("render")
    if not isinstance(arrangement, dict) or not isinstance(render, dict):
        raise PipelineError("track config requires arrangement and render objects")
    midi_path = resolve_from(config_path, str(arrangement.get("midi_path", "")))
    if not midi_path.is_file():
        raise PipelineError(f"Missing arrangement MIDI: {midi_path}")
    expected_midi_hash = str(arrangement.get("midi_sha256", ""))
    actual_midi_hash = sha256(midi_path)
    if expected_midi_hash and actual_midi_hash != expected_midi_hash:
        raise PipelineError(f"Arrangement MIDI hash mismatch: expected {expected_midi_hash}, got {actual_midi_hash}")
    midi = mido.MidiFile(midi_path)
    seconds_per_tick = _seconds_per_tick(config, midi)
    string_tracks = render.get("tracks", [])
    percussion = render.get("percussion", {})
    if not isinstance(string_tracks, list) or not isinstance(percussion, dict):
        raise PipelineError("render.tracks and render.percussion have invalid types")
    known = {str(item["midi_track"]) for item in string_tracks if isinstance(item, dict)}
    percussion_name = str(percussion.get("midi_track", ""))
    if percussion_name:
        known.add(percussion_name)
    output: dict[str, list[RenderNote]] = {}
    counts: dict[str, int] = {}
    maximum_tick = 0
    for track in midi.tracks:
        name = _track_name(track)
        absolute = 0
        active_notes: dict[tuple[int, int], list[tuple[int, int]]] = defaultdict(list)
        notes: list[RenderNote] = []
        for message in track:
            absolute += message.time
            maximum_tick = max(maximum_tick, absolute)
            if name not in known:
                continue
            if message.type == "note_on" and message.velocity > 0:
                active_notes[(message.channel, message.note)].append((absolute, message.velocity))
            elif message.type == "note_off" or (message.type == "note_on" and message.velocity == 0):
                key = (message.channel, message.note)
                if not active_notes[key]:
                    raise PipelineError(f"Unmatched note-off in {name}: {message.note}")
                start, velocity = active_notes[key].pop(0)
                notes.append(RenderNote(start * seconds_per_tick, absolute * seconds_per_tick, message.note, velocity))
        if name in known:
            if any(active_notes.values()):
                raise PipelineError(f"Hanging MIDI notes in {name}")
            output[name] = sorted(notes, key=lambda note: (note.start_seconds, note.pitch))
            counts[name] = len(notes)
    missing = sorted(known - output.keys())
    if missing:
        raise PipelineError(f"Configured MIDI tracks are absent: {missing}")
    return output, maximum_tick * seconds_per_tick, counts


def _sampled_note(note: RenderNote, track: dict[str, object], sample: dict[str, object], data: np.ndarray, output_rate: int) -> np.ndarray:
    note_seconds = max(1.0 / output_rate, note.end_seconds - note.start_seconds)
    release_seconds = float(track["release_seconds"])
    total_samples = max(1, int(round((note_seconds + release_seconds) * output_rate)))
    time = np.arange(total_samples, dtype=np.float64) / output_rate
    vibrato = float(track["vibrato_cents"]) * np.sin(2.0 * math.pi * float(track["vibrato_hz"]) * time)
    step = (
        int(sample["sample_rate"])
        / output_rate
        * midi_frequency(note.pitch)
        / float(sample["stored_effective_frequency_hz"])
        * np.power(2.0, vibrato / 1200.0)
    )
    positions = np.cumsum(step) - step[0]
    loop_start = int(sample["loop_start_sample"])
    loop_end = int(sample["loop_end_sample_exclusive"])
    mapped = np.where(positions < loop_start, positions, loop_start + np.mod(positions - loop_start, loop_end - loop_start))
    index0 = np.floor(mapped).astype(np.int64)
    fraction = mapped - index0
    index1 = index0 + 1
    index1[(index0 >= loop_start) & (index1 >= loop_end)] = loop_start
    index1 = np.minimum(index1, len(data) - 1)
    signal = data[index0] * (1.0 - fraction) + data[index1] * fraction
    release_start = max(1, int(round(note_seconds * output_rate)))
    envelope = np.ones(total_samples, dtype=np.float64)
    if release_start < total_samples:
        progress = np.linspace(0.0, 1.0, total_samples - release_start, endpoint=True)
        envelope[release_start:] = np.cos(progress * math.pi / 2.0) ** 2
    attack_seconds = float(track.get("attack_seconds", 0.012))
    if attack_seconds < 0.0:
        raise PipelineError("String track attack_seconds must be non-negative")
    attack = min(total_samples, max(8, int(round(attack_seconds * output_rate))))
    envelope[:attack] *= np.sin(np.linspace(0.0, math.pi / 2.0, attack, endpoint=True)) ** 2
    velocity_gain = (note.velocity / 88.0) ** 1.45
    return signal * envelope * velocity_gain * float(track["render_gain"])


def _moving_average(signal: np.ndarray, width: int) -> np.ndarray:
    return np.convolve(signal, np.ones(width, dtype=np.float64) / width, mode="same")


def _add_panned(destination: np.ndarray, start: int, voice: np.ndarray, pan: int) -> None:
    end = min(len(destination), start + len(voice))
    if end <= start:
        return
    audible = voice[: end - start]
    normalized = pan / 127.0
    destination[start:end, 0] += audible * math.cos(normalized * math.pi / 2.0)
    destination[start:end, 1] += audible * math.sin(normalized * math.pi / 2.0)


def _resample_one_shot(signal: np.ndarray, source_rate: int, output_rate: int) -> np.ndarray:
    count = max(1, int(round(len(signal) * output_rate / source_rate)))
    positions = np.linspace(0.0, len(signal) - 1, count, endpoint=True)
    return np.interp(positions, np.arange(len(signal)), signal)


def _echo(mix: np.ndarray, render: dict[str, object], sample_rate: int) -> tuple[np.ndarray, dict[str, object]]:
    echo = render.get("echo", {})
    if not isinstance(echo, dict):
        raise PipelineError("render.echo must be an object")
    width = int(echo.get("darkening_filter_width", 9))
    dark = np.empty_like(mix)
    dark[:, 0] = _moving_average(mix[:, 0], width)
    dark[:, 1] = _moving_average(mix[:, 1], width)
    wet = np.zeros_like(mix)
    taps = echo.get("taps", [])
    if not isinstance(taps, list):
        raise PipelineError("render.echo.taps must be an array")
    normalized_taps: list[dict[str, float]] = []
    for item in taps:
        if not isinstance(item, dict):
            raise PipelineError("Each echo tap must be an object")
        seconds = float(item["delay_seconds"])
        gain = float(item["gain"])
        delayed = np.roll(dark, int(round(seconds * sample_rate)), axis=0)
        wet[:, 0] += delayed[:, 1] * gain
        wet[:, 1] += delayed[:, 0] * gain
        normalized_taps.append({"delay_ms": seconds * 1000.0, "gain": gain})
    return mix + wet, {
        "model": "finite circular cross-stereo dark echo",
        "taps": normalized_taps,
        "darkening_filter": f"{width}-sample moving average before echo taps",
        "circular": True,
    }


def _crossfade(audio: np.ndarray, seconds: float, sample_rate: int) -> tuple[np.ndarray, dict[str, object]]:
    overlap = int(round(seconds * sample_rate))
    if overlap <= 0:
        return audio, {"crossfade_seconds": 0.0, "crossfade_samples": 0, "method": "none"}
    if len(audio) <= overlap * 2:
        raise PipelineError("Audio is too short for the configured loop crossfade")
    angle = np.linspace(0.0, math.pi / 2.0, overlap, endpoint=True)
    transition = audio[-overlap:] * np.cos(angle)[:, None] + audio[:overlap] * np.sin(angle)[:, None]
    looped = np.concatenate((audio[overlap:-overlap], transition), axis=0)
    return looped, {
        "crossfade_seconds": seconds,
        "crossfade_samples": overlap,
        "first_last_sample_delta": np.abs(looped[0] - looped[-1]).tolist(),
        "p99_9_adjacent_sample_delta": np.percentile(np.abs(np.diff(looped, axis=0)), 99.9, axis=0).tolist(),
        "method": "equal-power tail-to-head overlap with loop-point rotation",
    }


def _vorbis_command(input_wave: Path, output: Path, preference: str) -> tuple[list[str], str]:
    encoders = subprocess.run(["ffmpeg", "-hide_banner", "-encoders"], check=True, capture_output=True, text=True).stdout
    base = ["ffmpeg", "-hide_banner", "-loglevel", "error", "-y", "-i", str(input_wave)]
    if preference not in {"auto", "libvorbis", "native"}:
        raise PipelineError("render.vorbis_encoder must be auto, libvorbis, or native")
    if preference in {"auto", "libvorbis"} and "libvorbis" in encoders:
        return [*base, "-c:a", "libvorbis", "-q:a", "5", str(output)], "FFmpeg libvorbis quality 5"
    if preference in {"auto", "native"} and " vorbis " in encoders:
        return [*base, "-c:a", "vorbis", "-strict", "experimental", "-q:a", "5", str(output)], "FFmpeg native Vorbis quality 5 (experimental encoder API)"
    raise PipelineError(f"Requested Vorbis encoder is unavailable: {preference}")


def render_track(config_path: Path, output_dir: Path | None = None) -> dict[str, object]:
    config_path = config_path.resolve()
    config = read_json(config_path)
    verify_source_clearance(config, config_path)
    require_executable("ffmpeg")
    render = config.get("render")
    if not isinstance(render, dict):
        raise PipelineError("track config requires render")
    bank_path = resolve_from(config_path, str(render.get("bank_manifest", "")))
    bank = read_json(bank_path)
    samples = bank.get("samples")
    if not isinstance(samples, list):
        raise PipelineError("bank manifest requires a samples array")
    bank_by_id: dict[str, dict[str, object]] = {}
    waves: dict[str, tuple[np.ndarray, int]] = {}
    for raw in samples:
        if not isinstance(raw, dict):
            raise PipelineError("bank sample entries must be objects")
        bank_id = str(raw["bank_id"])
        sample_path = resolve_from(bank_path, str(raw["path"]))
        if sha256(sample_path) != str(raw["sha256"]):
            raise PipelineError(f"Procedural bank sample drifted: {sample_path}")
        bank_by_id[bank_id] = raw
        waves[bank_id] = load_mono_wave(sample_path)
    notes, structural_seconds, counts = read_midi_notes(config, config_path)
    sample_rate = int(render.get("sample_rate", 44_100))
    structural_samples = int(round(structural_seconds * sample_rate))
    strings = np.zeros((structural_samples, 2), dtype=np.float64)
    upper_stem = np.zeros_like(strings)
    low_stem = np.zeros_like(strings)
    percussion_mix = np.zeros_like(strings)
    track_configs = render.get("tracks", [])
    if not isinstance(track_configs, list) or not track_configs:
        raise PipelineError("render.tracks must contain at least one string track")
    for index, raw_track in enumerate(track_configs):
        if not isinstance(raw_track, dict):
            raise PipelineError("String track config must be an object")
        bank_id = str(raw_track["bank_id"])
        sample = bank_by_id.get(bank_id)
        if sample is None or sample.get("kind") != "looped_string":
            raise PipelineError(f"Missing looped string bank id: {bank_id}")
        bank_wave, _ = waves[bank_id]
        track_name = str(raw_track["midi_track"])
        for note in notes[track_name]:
            voice = _sampled_note(note, raw_track, sample, bank_wave, sample_rate)
            start = int(round(note.start_seconds * sample_rate))
            pan = int(raw_track["pan"])
            _add_panned(strings, start, voice, pan)
            if str(raw_track.get("stem", "middle")) == "upper":
                _add_panned(upper_stem, start, voice, pan)
            if str(raw_track.get("stem", "middle")) == "low":
                _add_panned(low_stem, start, voice, pan)
    percussion = render.get("percussion", {})
    if not isinstance(percussion, dict):
        raise PipelineError("render.percussion must be an object")
    percussion_track = str(percussion.get("midi_track", ""))
    note_map = percussion.get("notes", {})
    if percussion_track:
        if not isinstance(note_map, dict):
            raise PipelineError("render.percussion.notes must be an object")
        for note in notes[percussion_track]:
            bank_id = str(note_map.get(str(note.pitch), ""))
            sample = bank_by_id.get(bank_id)
            if sample is None or sample.get("kind") != "one_shot_percussion":
                raise PipelineError(f"No procedural percussion mapping for MIDI note {note.pitch}")
            source, source_rate = waves[bank_id]
            voice = _resample_one_shot(source, source_rate, sample_rate)
            voice = voice * float(sample["render_gain"]) * (note.velocity / 88.0) ** 1.25
            _add_panned(percussion_mix, int(round(note.start_seconds * sample_rate)), voice, int(sample["pan"]))
    string_filter = int(render.get("string_reconstruction_filter_width", 5))
    reconstructed = np.empty_like(strings)
    reconstructed[:, 0] = _moving_average(strings[:, 0], string_filter)
    reconstructed[:, 1] = _moving_average(strings[:, 1], string_filter)
    echoed, echo_report = _echo(reconstructed, render, sample_rate)
    drum_filter = int(render.get("percussion_reconstruction_filter_width", 3))
    dry_drums = np.empty_like(percussion_mix)
    dry_drums[:, 0] = _moving_average(percussion_mix[:, 0], drum_filter)
    dry_drums[:, 1] = _moving_average(percussion_mix[:, 1], drum_filter)
    drive = float(render.get("saturation_drive", 1.08))
    saturated = np.tanh((echoed + dry_drums) * drive) / math.tanh(drive)
    raw_peak = float(np.max(np.abs(saturated)))
    target_db = float(render.get("target_peak_dbfs", -7.5))
    master_gain = 10.0 ** (target_db / 20.0) / max(raw_peak, 1e-12)
    mastered = saturated * master_gain
    crossfade_seconds = float(render.get("crossfade_seconds", 0.0))
    looped, crossfade_report = _crossfade(mastered, crossfade_seconds, sample_rate)
    quantization_bits = int(render.get("output_signal_quantization_bits", 15))
    maximum = float((1 << (quantization_bits - 1)) - 1)
    looped = np.round(looped * maximum) / maximum
    destination = output_dir.resolve() if output_dir else config_path.parent
    destination.mkdir(parents=True, exist_ok=True)
    basename = str(render.get("output_basename", "preview"))
    ogg_path = destination / f"{basename}.ogg"
    flac_path = destination / f"{basename}.flac"
    report_path = destination / f"{basename}.render.json"
    ogg_path.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="labyrinth-classical-render-") as temporary:
        staging = Path(temporary)
        wave_path = staging / "render.wav"
        candidate_ogg = staging / "preview.ogg"
        candidate_flac = staging / "preview.flac"
        candidate_report = staging / "preview.render.json"
        write_stereo_wave(wave_path, looped, sample_rate)
        subprocess.run(["ffmpeg", "-hide_banner", "-loglevel", "error", "-y", "-i", str(wave_path), "-c:a", "flac", "-compression_level", "8", str(candidate_flac)], check=True)
        vorbis_command, vorbis_label = _vorbis_command(
            wave_path,
            candidate_ogg,
            str(render.get("vorbis_encoder", "auto")),
        )
        subprocess.run(vorbis_command, check=True)
        serial_value = render.get("ogg_stream_serial", "0x45545531")
        serial = int(str(serial_value), 0) if isinstance(serial_value, str) else int(serial_value)
        normalize_ogg_serial(candidate_ogg, serial)
        candidate_hashes = {
            "ogg_sha256": sha256(candidate_ogg),
            "flac_sha256": sha256(candidate_flac),
        }
        expected_outputs = config.get("expected_outputs", {})
        if not isinstance(expected_outputs, dict):
            raise PipelineError("expected_outputs must be an object")
        for key, actual in candidate_hashes.items():
            expected_hash = str(expected_outputs.get(key, ""))
            if expected_hash and expected_hash != actual:
                raise PipelineError(
                    f"Candidate {key} drifted before publication: expected {expected_hash}, got {actual}"
                )
        peak = float(np.max(np.abs(looped)))
        report = {
            "schema_version": 1,
            "track_id": config.get("track_id"),
            "config_path": str(config_path),
            "config_sha256": sha256(config_path),
            "bank_manifest": str(bank_path),
            "bank_manifest_sha256": sha256(bank_path),
            "midi_note_counts": counts,
            "audio": {
                "ogg_path": str(ogg_path),
                "ogg_sha256": candidate_hashes["ogg_sha256"],
                "flac_path": str(flac_path),
                "flac_sha256": candidate_hashes["flac_sha256"],
                "sample_rate": sample_rate,
                "channels": 2,
                "structural_duration_seconds": structural_seconds,
                "duration_seconds": len(looped) / sample_rate,
                "peak_linear": peak,
                "peak_dbfs": 20.0 * math.log10(max(peak, 1e-12)),
                "rms_linear": float(np.sqrt(np.mean(np.square(looped)))),
                "master_gain": master_gain,
                "pre_master_stem_rms": {
                    "upper_strings": float(np.sqrt(np.mean(np.square(upper_stem)))),
                    "low_strings": float(np.sqrt(np.mean(np.square(low_stem)))),
                    "percussion": float(np.sqrt(np.mean(np.square(percussion_mix)))),
                },
                "encoder": vorbis_label,
                "ffmpeg_version": subprocess.run(
                    ["ffmpeg", "-version"], check=True, capture_output=True, text=True
                ).stdout.splitlines()[0],
                "ogg_stream_serial": f"0x{serial:08x}",
                "echo": echo_report,
                "loop_crossfade": crossfade_report,
            },
        }
        write_json(candidate_report, report)
        publications = (
            (candidate_ogg, ogg_path),
            (candidate_flac, flac_path),
            (candidate_report, report_path),
        )
        for candidate, final_path in publications:
            assert_publishable(candidate, final_path, "audition artifact")
        for candidate, final_path in publications:
            publish_immutable(candidate, final_path, "audition artifact")
    return report
