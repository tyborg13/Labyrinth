#!/usr/bin/env python3
"""Verify provenance, score structure, MIDI fidelity, and audio outputs."""

from __future__ import annotations

from collections import defaultdict
import json
from pathlib import Path
import subprocess
import xml.etree.ElementTree as ET

import mido

import build_arrangement as build


SOURCE_LICENSE = build.POC_ROOT / "source" / "OpenScore_LICENSE_CC0-1.0.txt"
REFERENCE_PDF = (
    build.POC_ROOT
    / "source"
    / "reference"
    / "IMSLP04047-SchubertStringQuartetNo14.pdf"
)
EXPECTED_LICENSE_SHA256 = "a2010f343487d3f7618affe54f789f5487602331c0a8d03f49e9a7c547cf0499"
EXPECTED_REFERENCE_SHA256 = "55db640f6b3ec6715a0bd5527ed3f26cca181036a4e848a32027dd7d29bef48e"
VERIFICATION_REPORT = build.POC_ROOT / "VERIFICATION_REPORT.json"


def note_tracks(midi: mido.MidiFile) -> list[mido.MidiTrack]:
    return [
        track
        for track in midi.tracks
        if any(message.type == "note_on" and message.velocity > 0 for message in track)
    ]


def track_intervals(
    track: mido.MidiTrack,
) -> list[tuple[int, int, int, int]]:
    absolute = 0
    active: dict[tuple[int, int], list[tuple[int, int]]] = defaultdict(list)
    intervals: list[tuple[int, int, int, int]] = []
    for message in track:
        absolute += message.time
        if message.type == "note_on" and message.velocity > 0:
            active[(message.channel, message.note)].append((absolute, message.velocity))
        elif message.type in {"note_off", "note_on"}:
            key = (message.channel, message.note)
            if active[key]:
                start, velocity = active[key].pop(0)
                intervals.append((start, absolute, message.note, velocity))
    if any(active.values()):
        raise AssertionError(f"Unclosed MIDI notes in {build.midi_track_name(track)}")
    return sorted(intervals)


def max_polyphony(intervals: list[tuple[int, int, int, int]]) -> int:
    changes: list[tuple[int, int]] = []
    for start, end, _, _ in intervals:
        changes.append((start, 1))
        changes.append((end, -1))
    current = 0
    maximum = 0
    for _, change in sorted(changes, key=lambda item: (item[0], item[1])):
        current += change
        maximum = max(maximum, current)
    return maximum


def verify_musicxml() -> dict[str, object]:
    root = ET.parse(build.NORMALIZED_SCORE_XML).getroot()
    part_list = root.find("part-list")
    assert part_list is not None
    names = [
        (score_part.findtext("part-name") or "").strip()
        for score_part in part_list.findall("score-part")
    ]
    assert tuple(names) == build.EXPECTED_PART_NAMES
    music_parts = root.findall("part")
    assert len(music_parts) == 4
    measure_counts = [len(part.findall("measure")) for part in music_parts]
    assert measure_counts == [180, 180, 180, 180]
    first_words = build.measure_words(music_parts[0].findall("measure")[0])
    assert "II." in first_words and "Andante con moto" in first_words
    assert not any("III." in build.measure_words(m) for m in music_parts[0].findall("measure"))

    separate: dict[str, int] = {}
    for name, stem in zip(build.EXPECTED_PART_NAMES, build.PART_FILE_STEMS, strict=True):
        part_root = ET.parse(build.PARTS_DIR / f"{stem}.musicxml").getroot()
        assert len(part_root.findall("part")) == 1
        count = len(part_root.find("part").findall("measure"))  # type: ignore[union-attr]
        assert count == 180
        separate[name] = count
    return {
        "part_names": names,
        "measure_objects_per_part": measure_counts,
        "separate_part_measure_objects": separate,
        "opening_heading": first_words,
    }


def verify_normalized_midi() -> dict[str, object]:
    midi = mido.MidiFile(build.NORMALIZED_SCORE_MIDI)
    tracks = note_tracks(midi)
    assert len(tracks) == 4
    names = [build.midi_track_name(track) for track in tracks]
    for expected in build.EXPECTED_PART_NAMES:
        assert any(expected.lower() in name.lower() for name in names)
    counts = {build.midi_track_name(track): len(track_intervals(track)) for track in tracks}
    for stem in build.PART_FILE_STEMS:
        part_midi = mido.MidiFile(build.PARTS_DIR / f"{stem}.mid")
        assert len(note_tracks(part_midi)) == 1
        assert len(track_intervals(note_tracks(part_midi)[0])) > 0
    return {"note_track_names": names, "note_counts": counts}


def expected_arrangement_intervals() -> dict[str, list[tuple[int, int, int, int]]]:
    score = build.parse_normalized_score()
    performed = build.expanded_performance_score(score)
    parts = {part.partName: part for part in performed.parts}
    events: dict[str, list[build.NoteEvent]] = {}
    for spec in build.TRACK_SPECS:
        events[spec.name] = build.part_note_events(parts[spec.source_part], spec)
    events[build.BASS_SPEC.name] = build.bass_shadow_events(
        events[build.TRACK_SPECS[-1].name]
    )
    return {
        name: [
            (
                build.ticks(event.start_ql),
                max(build.ticks(event.start_ql) + 1, build.ticks(event.end_ql)),
                event.pitch,
                event.velocity,
            )
            for event in values
        ]
        for name, values in events.items()
    }


def verify_arrangement_midi() -> dict[str, object]:
    midi = mido.MidiFile(build.ARRANGEMENT_MIDI)
    assert midi.type == 1
    assert midi.ticks_per_beat == build.TICKS_PER_BEAT
    tracks = note_tracks(midi)
    assert len(tracks) == 5
    expected_names = [spec.name for spec in (*build.TRACK_SPECS, build.BASS_SPEC)]
    actual_names = [build.midi_track_name(track) for track in tracks]
    assert actual_names == expected_names

    tempos = [
        message.tempo
        for track in midi.tracks
        for message in track
        if message.type == "set_tempo"
    ]
    assert tempos == [mido.bpm2tempo(build.TEMPO_QPM)]

    expected = expected_arrangement_intervals()
    actual = {build.midi_track_name(track): track_intervals(track) for track in tracks}
    assert actual == expected
    per_track_polyphony = {name: max_polyphony(values) for name, values in actual.items()}
    assert all(value <= 1 for value in per_track_polyphony.values())
    global_intervals = [interval for values in actual.values() for interval in values]
    global_polyphony = max_polyphony(global_intervals)
    assert global_polyphony <= 5

    original_names = expected_names[:4]
    bass_name = expected_names[4]
    cello_name = expected_names[3]
    cello_starts = {(start, pitch - 12) for start, _, pitch, _ in actual[cello_name] if pitch - 12 >= 28}
    bass_starts = {(start, pitch) for start, _, pitch, _ in actual[bass_name]}
    assert bass_starts == cello_starts

    return {
        "tempo_qpm": build.TEMPO_QPM,
        "note_track_names": actual_names,
        "per_track_note_counts": {name: len(values) for name, values in actual.items()},
        "per_track_max_polyphony": per_track_polyphony,
        "global_max_simultaneous_musical_voices": global_polyphony,
        "source_derived_tracks_exact_match": original_names,
        "bass_shadow_exact_cello_octave_derivation": True,
    }


def ffprobe(path: Path) -> dict[str, object]:
    process = subprocess.run(
        [
            "ffprobe",
            "-v",
            "error",
            "-show_entries",
            "format=duration,size,bit_rate:stream=codec_name,sample_rate,channels",
            "-of",
            "json",
            str(path),
        ],
        check=True,
        capture_output=True,
        text=True,
    )
    return json.loads(process.stdout)


def verify_audio() -> dict[str, object]:
    ogg = ffprobe(build.AUDIO_PREVIEW)
    flac = ffprobe(build.AUDIO_PREVIEW_LOSSLESS)
    for data, codec in ((ogg, "vorbis"), (flac, "flac")):
        streams = data["streams"]
        assert len(streams) == 1
        assert streams[0]["codec_name"] == codec
        assert streams[0]["sample_rate"] == str(build.SAMPLE_RATE)
        assert streams[0]["channels"] == 2
        assert 783.35 < float(data["format"]["duration"]) < 783.45
        assert int(data["format"]["size"]) > 1_000_000
    build_report = json.loads(build.BUILD_REPORT.read_text(encoding="utf-8"))
    audio_report = build_report["audio_preview"]
    assert audio_report["peak_linear"] < 0.99
    assert audio_report["peak_dbfs"] < -0.1
    return {
        "ogg_vorbis": ogg,
        "lossless_flac": flac,
        "render_peak_dbfs": audio_report["peak_dbfs"],
        "render_rms_linear": audio_report["rms_linear"],
    }


def main() -> int:
    provenance = {
        "openscore_mxl_sha256": build.sha256(build.SOURCE_MXL),
        "openscore_license_sha256": build.sha256(SOURCE_LICENSE),
        "imslp_reference_pdf_sha256": build.sha256(REFERENCE_PDF),
    }
    assert provenance["openscore_mxl_sha256"] == build.EXPECTED_SOURCE_SHA256
    assert provenance["openscore_license_sha256"] == EXPECTED_LICENSE_SHA256
    assert provenance["imslp_reference_pdf_sha256"] == EXPECTED_REFERENCE_SHA256

    report = {
        "ok": True,
        "provenance": provenance,
        "musicxml": verify_musicxml(),
        "normalized_midi": verify_normalized_midi(),
        "arrangement_midi": verify_arrangement_midi(),
        "audio": verify_audio(),
    }
    VERIFICATION_REPORT.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(report, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
