#!/usr/bin/env python3
"""Verify provenance, source mapping, loop structure, bank, and version-2 audio."""

from __future__ import annotations

from collections import defaultdict
import json
from pathlib import Path
import re
import subprocess
import sys
import wave

if sys.version_info < (3, 12):
    raise SystemExit(
        "This verification requires Python 3.12 or newer; "
        f"found {sys.version.split()[0]}"
    )

import mido
import numpy as np

import build_active_tactical_loop as loop
import build_arrangement as base


POC_ROOT = Path(__file__).resolve().parents[1]
VERIFICATION_REPORT = POC_ROOT / "ACTIVE_TACTICAL_LOOP_VERIFICATION.json"

VERSION_ONE_HASHES = {
    "faithful_retro.mid": "2c9a7303ef50cb244bb94b95cc367d730590ab15e4ce77ffa806e8b70269fd66",
    "faithful_retro_preview.ogg": "93ff01b2b6ef31e52965fdbf240c7b64a692871301370c517a7cafcda7a65a0f",
    "faithful_retro_preview.flac": "ecd02002cff366f1152febe588713a5dd870a840bed44a1c5b7c7bb0f04c6409",
    "normalized/movement_ii_four_parts.musicxml": "03eae6073fab5f208829746631b87740b041383c893529349875f346900ba5a6",
    "normalized/movement_ii_four_parts.mid": "874d96d94e256126c0a569516c6f678d29b8638d5bf8f5fe27147d177fa509cf",
}


def verify_version_one_unchanged() -> dict[str, str]:
    actual: dict[str, str] = {}
    for relative, expected in VERSION_ONE_HASHES.items():
        path = POC_ROOT / relative
        digest = loop.sha256(path)
        assert digest == expected, f"Version-1 artifact changed: {relative}"
        actual[relative] = digest
    return actual


def absolute_track_end(track: mido.MidiTrack) -> int:
    return sum(message.time for message in track)


def midi_note_signatures(
    track: mido.MidiTrack,
) -> list[tuple[int, int, int, int]]:
    absolute_tick = 0
    active: dict[tuple[int, int], list[tuple[int, int]]] = defaultdict(list)
    notes: list[tuple[int, int, int, int]] = []
    for message in track:
        absolute_tick += message.time
        if message.type == "note_on" and message.velocity > 0:
            active[(message.channel, message.note)].append(
                (absolute_tick, message.velocity)
            )
        elif message.type == "note_off" or (
            message.type == "note_on" and message.velocity == 0
        ):
            key = (message.channel, message.note)
            assert active[key], f"Unmatched note-off for MIDI note {message.note}"
            start_tick, velocity = active[key].pop(0)
            notes.append((start_tick, absolute_tick, message.note, velocity))
    assert not any(active.values()), "Hanging MIDI note"
    return sorted(notes)


def expected_signatures(
    events: list[loop.ArrangedEvent],
) -> list[tuple[int, int, int, int]]:
    return sorted(
        (
            loop.ticks(event.start_ql),
            max(loop.ticks(event.start_ql) + 1, loop.ticks(event.end_ql)),
            event.pitch,
            event.velocity,
        )
        for event in events
    )


def max_global_polyphony(
    signatures_by_track: dict[str, list[tuple[int, int, int, int]]]
) -> int:
    changes: list[tuple[int, int]] = []
    for signatures in signatures_by_track.values():
        for start, end, _, _ in signatures:
            changes.append((start, 1))
            changes.append((end, -1))
    changes.sort(key=lambda item: (item[0], item[1]))
    active = 0
    maximum = 0
    for _, change in changes:
        active += change
        maximum = max(maximum, active)
    return maximum


def verify_source_mapping(
    events_by_track: dict[str, list[loop.ArrangedEvent]],
) -> dict[str, object]:
    originals = loop.source_events()
    mapped_count = 0
    octave_count = 0
    section_counts: dict[str, int] = defaultdict(int)
    for spec in loop.LOOP_TRACKS:
        for event in events_by_track[spec.name]:
            candidates = originals[event.source_track]
            assert any(
                candidate.pitch == event.source_pitch
                and candidate.start_ql <= event.source_start_ql + 1e-8
                and candidate.end_ql >= event.source_end_ql - 1e-8
                for candidate in candidates
            ), f"No source event for {spec.name} at {event.start_ql}"
            if spec is loop.LOOP_TRACKS[-1]:
                assert event.pitch == event.source_pitch - 12
                octave_count += 1
            else:
                assert event.pitch == event.source_pitch
            section = next(
                item for item in loop.FORM_SECTIONS if item.label == event.section_label
            )
            segment = loop.SOURCE_SEGMENTS[section.segment_key]
            assert segment.source_start_ql <= event.source_start_ql
            assert event.source_end_ql <= segment.source_end_ql + 1e-8
            mapped_count += 1
            section_counts[event.section_label] += 1
    return {
        "mapped_events": mapped_count,
        "exact_octave_below_cello_events": octave_count,
        "section_event_counts": dict(sorted(section_counts.items())),
        "all_non_bass_pitches_exact_source_pitches": True,
        "new_pitch_classes": False,
    }


def verify_midi() -> dict[str, object]:
    midi = mido.MidiFile(loop.ARRANGEMENT_MIDI)
    assert midi.type == 1
    assert midi.ticks_per_beat == loop.TICKS_PER_BEAT
    track_by_name = {loop.midi_track_name(track): track for track in midi.tracks}
    expected_names = [spec.name for spec in loop.LOOP_TRACKS]
    assert [name for name in expected_names if name in track_by_name] == expected_names
    assert len([name for name in track_by_name if name in expected_names]) == 5

    built_events, transformation = loop.build_track_events()
    actual_signatures: dict[str, list[tuple[int, int, int, int]]] = {}
    per_track_max: dict[str, int] = {}
    for spec in loop.LOOP_TRACKS:
        track = track_by_name[spec.name]
        signatures = midi_note_signatures(track)
        assert signatures == expected_signatures(built_events[spec.name])
        assert absolute_track_end(track) == loop.ticks(loop.LOOP_QUARTERS)
        active_end = -1
        maximum = 0
        for start, end, _, _ in signatures:
            assert start >= active_end, f"Polyphony in monophonic track {spec.name}"
            active_end = end
            maximum = max(maximum, 1)
        per_track_max[spec.name] = maximum
        actual_signatures[spec.name] = signatures

    conductor = track_by_name["Conductor / Loop Map"]
    markers = [message.text for message in conductor if message.type == "marker"]
    for section in loop.FORM_SECTIONS:
        assert any(marker.startswith(section.label + ":") for marker in markers)
    assert any(marker.startswith("LOOP_START") for marker in markers)
    assert any(marker.startswith("LOOP_END") for marker in markers)
    assert absolute_track_end(conductor) == loop.ticks(loop.LOOP_QUARTERS)

    global_polyphony = max_global_polyphony(actual_signatures)
    assert global_polyphony == 5
    source_mapping = verify_source_mapping(built_events)
    return {
        "sha256": loop.sha256(loop.ARRANGEMENT_MIDI),
        "track_names": expected_names,
        "note_counts": {
            name: len(signatures) for name, signatures in actual_signatures.items()
        },
        "per_track_max_polyphony": per_track_max,
        "global_max_simultaneous_voices": global_polyphony,
        "duration_quarters": loop.LOOP_QUARTERS,
        "duration_seconds": loop.seconds_for_quarters(loop.LOOP_QUARTERS),
        "form": "-".join(loop.FORM),
        "markers": markers,
        "source_mapping": source_mapping,
        "thinning": transformation["thinning"],
    }


def read_bank_samples(path: Path) -> tuple[np.ndarray, dict[str, int]]:
    with wave.open(str(path), "rb") as handle:
        metadata = {
            "channels": handle.getnchannels(),
            "sample_width": handle.getsampwidth(),
            "sample_rate": handle.getframerate(),
            "frames": handle.getnframes(),
        }
        frames = handle.readframes(handle.getnframes())
    samples = np.frombuffer(frames, dtype="<i2").astype(np.float64) / 32768.0
    return samples, metadata


def verify_bank() -> dict[str, object]:
    report = json.loads(loop.BUILD_REPORT.read_text(encoding="utf-8"))
    bank_report = report["procedural_bank"]
    manifest_bytes = loop.BANK_MANIFEST.read_bytes()
    assert hashlib_sha256(manifest_bytes) == bank_report["manifest_sha256"]
    manifest = json.loads(manifest_bytes)
    assert "No recording" in manifest["provenance"]
    assert "third-party audio" in manifest["provenance"]
    verified: list[dict[str, object]] = []
    for sample in manifest["samples"]:
        path = loop.POC_ROOT / sample["path"]
        assert loop.sha256(path) == sample["sha256"]
        data, wave_info = read_bank_samples(path)
        assert wave_info["channels"] == 1
        assert wave_info["sample_width"] == 2
        assert wave_info["sample_rate"] == loop.BANK_SAMPLE_RATE
        assert wave_info["frames"] == sample["loop_end_sample_exclusive"]
        start = sample["loop_start_sample"]
        end = sample["loop_end_sample_exclusive"]
        assert 0 < start < end == len(data)
        seam_delta = abs(float(data[start] - data[end - 1]))
        typical_delta = float(np.percentile(np.abs(np.diff(data[start:end])), 99.9))
        assert seam_delta <= max(0.2, typical_delta * 1.5)
        assert np.max(np.abs(data)) < 0.83
        verified.append(
            {
                "bank_id": sample["bank_id"],
                "sha256": sample["sha256"],
                **wave_info,
                "loop_seam_sample_delta": seam_delta,
                "p99_9_adjacent_sample_delta": typical_delta,
            }
        )
    return {
        "manifest_sha256": bank_report["manifest_sha256"],
        "provenance": manifest["provenance"],
        "commercial_use_status": manifest["commercial_use_status"],
        "samples": verified,
    }


def hashlib_sha256(data: bytes) -> str:
    import hashlib

    return hashlib.sha256(data).hexdigest()


def ffprobe(path: Path) -> dict[str, object]:
    result = subprocess.run(
        [
            "ffprobe",
            "-v",
            "error",
            "-show_entries",
            "stream=codec_name,sample_rate,channels:format=duration,size,bit_rate",
            "-of",
            "json",
            str(path),
        ],
        check=True,
        capture_output=True,
        text=True,
    )
    return json.loads(result.stdout)


def strict_decode(path: Path) -> None:
    subprocess.run(
        [
            "ffmpeg",
            "-hide_banner",
            "-loglevel",
            "error",
            "-xerror",
            "-i",
            str(path),
            "-f",
            "null",
            "-",
        ],
        check=True,
        capture_output=True,
    )


def max_volume_db(path: Path) -> float:
    result = subprocess.run(
        [
            "ffmpeg",
            "-hide_banner",
            "-i",
            str(path),
            "-af",
            "volumedetect",
            "-f",
            "null",
            "-",
        ],
        check=True,
        capture_output=True,
        text=True,
    )
    match = re.search(r"max_volume:\s*(-?[0-9.]+) dB", result.stderr)
    assert match, "FFmpeg did not report max_volume"
    return float(match.group(1))


def long_silence_events(path: Path) -> list[str]:
    result = subprocess.run(
        [
            "ffmpeg",
            "-hide_banner",
            "-i",
            str(path),
            "-af",
            "silencedetect=noise=-60dB:d=0.75",
            "-f",
            "null",
            "-",
        ],
        check=True,
        capture_output=True,
        text=True,
    )
    return [
        line.strip()
        for line in result.stderr.splitlines()
        if "silence_start" in line or "silence_end" in line
    ]


def ogg_serials(path: Path) -> set[int]:
    data = path.read_bytes()
    offset = 0
    serials: set[int] = set()
    while offset < len(data):
        assert data[offset : offset + 4] == b"OggS"
        segment_count = data[offset + 26]
        header_end = offset + 27 + segment_count
        page_end = header_end + sum(data[offset + 27 : header_end])
        assert page_end <= len(data)
        serials.add(int.from_bytes(data[offset + 14 : offset + 18], "little"))
        offset = page_end
    assert offset == len(data)
    return serials


def verify_audio() -> dict[str, object]:
    report = json.loads(loop.BUILD_REPORT.read_text(encoding="utf-8"))
    audio_report = report["audio"]
    assert audio_report is not None
    ogg_hash = loop.sha256(loop.AUDIO_OGG)
    flac_hash = loop.sha256(loop.AUDIO_FLAC)
    assert ogg_hash == audio_report["ogg_sha256"]
    assert flac_hash == audio_report["flac_sha256"]
    assert ogg_serials(loop.AUDIO_OGG) == {loop.OGG_SERIAL}

    ogg_probe = ffprobe(loop.AUDIO_OGG)
    flac_probe = ffprobe(loop.AUDIO_FLAC)
    for probe, codec in ((ogg_probe, "vorbis"), (flac_probe, "flac")):
        assert probe["streams"][0]["codec_name"] == codec
        assert int(probe["streams"][0]["sample_rate"]) == loop.OUTPUT_SAMPLE_RATE
        assert probe["streams"][0]["channels"] == 2
        duration = float(probe["format"]["duration"])
        assert 240.0 <= duration <= 360.0
        assert abs(duration - audio_report["duration_seconds"]) < 0.02
    strict_decode(loop.AUDIO_OGG)
    strict_decode(loop.AUDIO_FLAC)

    independent_peak = max_volume_db(loop.AUDIO_FLAC)
    assert independent_peak < -0.1
    assert abs(independent_peak - audio_report["peak_dbfs"]) < 0.15
    silence_events = long_silence_events(loop.AUDIO_FLAC)
    assert not silence_events
    seam = audio_report["loop_crossfade"]
    for channel_delta, channel_typical in zip(
        seam["first_last_sample_delta"], seam["p99_9_adjacent_sample_delta"]
    ):
        assert channel_delta <= channel_typical
    assert audio_report["echo"]["circular"] is True
    assert audio_report["echo"]["taps"][-1]["gain"] <= 0.022
    assert audio_report["reconstruction_filter"].startswith("5-sample")
    return {
        "ogg": ogg_probe,
        "flac": flac_probe,
        "ogg_sha256": ogg_hash,
        "flac_sha256": flac_hash,
        "ogg_serial": f"0x{loop.OGG_SERIAL:08x}",
        "strict_decode": True,
        "independent_peak_dbfs": independent_peak,
        "reported_peak_dbfs": audio_report["peak_dbfs"],
        "silence_events_at_minus_60_dbfs_over_750ms": silence_events,
        "duration_seconds": audio_report["duration_seconds"],
        "loop_crossfade": seam,
        "echo": audio_report["echo"],
        "reconstruction_filter": audio_report["reconstruction_filter"],
    }


def verify_selection() -> dict[str, object]:
    expected = {
        "A": (192.0, 256.0, "2:05-2:45"),
        "B": (384.0, 480.0, "4:10-5:10"),
        "C": (576.0, 672.0, "6:15-7:17"),
    }
    assert tuple(loop.FORM) == ("A", "B", "C", "B", "A")
    assert loop.LOOP_QUARTERS == 416.0
    assert 240.0 <= loop.seconds_for_quarters(loop.LOOP_QUARTERS) <= 360.0
    for key, (start, end, requested) in expected.items():
        segment = loop.SOURCE_SEGMENTS[key]
        assert segment.source_start_ql == start
        assert segment.source_end_ql == end
        assert segment.requested_window == requested
        assert start % 4 == 0 and end % 4 == 0
    return {
        "form": "-".join(loop.FORM),
        "source_segments": {
            key: {
                "source_quarters": [segment.source_start_ql, segment.source_end_ql],
                "source_preview_seconds": [
                    loop.source_timestamp(segment.source_start_ql),
                    loop.source_timestamp(segment.source_end_ql),
                ],
                "performed_measures": [
                    segment.performed_measure_start,
                    segment.performed_measure_end,
                ],
                "requested_window": segment.requested_window,
            }
            for key, segment in loop.SOURCE_SEGMENTS.items()
        },
        "midi_duration_seconds": loop.seconds_for_quarters(loop.LOOP_QUARTERS),
        "audio_duration_seconds": loop.seconds_for_quarters(
            loop.LOOP_QUARTERS - loop.CROSSFADE_QUARTERS
        ),
    }


def verify() -> dict[str, object]:
    assert base.verify_immutable_source() == base.EXPECTED_SOURCE_SHA256
    report = {
        "ok": True,
        "source_sha256": base.EXPECTED_SOURCE_SHA256,
        "version_one_unchanged": verify_version_one_unchanged(),
        "selection": verify_selection(),
        "midi": verify_midi(),
        "procedural_bank": verify_bank(),
        "audio": verify_audio(),
    }
    VERIFICATION_REPORT.write_text(
        json.dumps(report, indent=2, sort_keys=True) + "\n", encoding="utf-8"
    )
    return report


def main() -> int:
    report = verify()
    print(json.dumps(report, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
