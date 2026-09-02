#!/usr/bin/env python3
"""Build v04: one contiguous darkened v01 excerpt with its late motif removed."""

from __future__ import annotations

from collections import defaultdict
import importlib.util
import json
from pathlib import Path
import sys

import mido


TRACK_ROOT = Path(__file__).resolve().parents[1]
REPO_ROOT = TRACK_ROOT.parents[2]
sys.path.insert(0, str(REPO_ROOT))

from tools.classical_soundtrack_pipeline.common import (  # noqa: E402
    read_json,
    sha256,
    verify_source_clearance,
    write_json,
)


CONFIG_PATH = TRACK_ROOT / "track.v04.json"
SOURCE_MIDI = TRACK_ROOT / "source" / "chopin_piano_sonata_no2_op35_pdmx_cc0.mid"
V01_MIDI = TRACK_ROOT / "versions" / "v01" / "arrangement.mid"
V02_BUILDER = TRACK_ROOT / "scripts" / "build_arrangement_v02.py"
VERSION_DIR = TRACK_ROOT / "versions" / "v04"
ARRANGEMENT_MIDI = VERSION_DIR / "arrangement.mid"
BUILD_REPORT = VERSION_DIR / "BUILD_REPORT.json"

EXPECTED_SOURCE_SHA256 = "ec2a476e16556cdffc69d47bf0aebf4093842e9dde8f6c32170c7da6a6149ee3"
EXPECTED_V01_MIDI_SHA256 = "342ae252fdb8012832dce8ae2a2d428f3c4b526d2460ca476c0a6138466b2f0c"
EXPECTED_V02_BUILDER_SHA256 = "0b2a9dc641ccde4b4e11fc2886ab2239a5eae2d0304412b3c4bfab0ec520431c"


def _load_v02_builder():
    spec = importlib.util.spec_from_file_location("_chopin_v02_builder_for_v04", V02_BUILDER)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"Could not load shared Chopin helpers from {V02_BUILDER}")
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


V02 = _load_v02_builder()

TICKS_PER_BEAT = V02.TICKS_PER_BEAT
BAR_TICKS = V02.BAR_TICKS
QPM = V02.QPM
LOOP_CROSSFADE_SECONDS = V02.LOOP_CROSSFADE_SECONDS
VEILED = V02.VEILED
ASHEN = V02.ASHEN
HOLLOW = V02.HOLLOW
GRAVE = V02.GRAVE
BASS = V02.BASS
PERCUSSION = V02.PERCUSSION
TRACKS = V02.TRACKS
CHANNELS = V02.CHANNELS

SOURCE_FIRST_MEASURE = 93
SOURCE_LAST_MEASURE = 100
INITIAL_MELODY_LAST_MEASURE = 98
MOTIF_FIRST_MEASURE = 99
SOURCE_START = (SOURCE_FIRST_MEASURE - 1) * BAR_TICKS
SOURCE_END = SOURCE_LAST_MEASURE * BAR_TICKS
MOTIF_START = (MOTIF_FIRST_MEASURE - 1) * BAR_TICKS
PRE_ROLL_TICKS = TICKS_PER_BEAT
PITCH_SHIFT_SEMITONES = -3
TARGET_KEY = "Gm"


def _transposed_pitch(track_name: str, pitch: int) -> int:
    return pitch if track_name == PERCUSSION else pitch + PITCH_SHIFT_SEMITONES


def _copy_window(
    source: dict[str, list[V02.Event]],
    destination: dict[str, list[V02.Event]],
    source_start: int,
    source_end: int,
    destination_start: int,
    origin: str,
    suppress_late_lead: bool,
) -> dict[str, int]:
    counts: dict[str, int] = {}
    for track_name in TRACKS:
        copied = 0
        for event in source[track_name]:
            if event.end <= source_start or event.start >= source_end:
                continue
            clipped_start = max(event.start, source_start)
            clipped_end = min(event.end, source_end)
            if suppress_late_lead and track_name in {VEILED, GRAVE}:
                if clipped_start >= MOTIF_START:
                    continue
                clipped_end = min(clipped_end, MOTIF_START)
            if clipped_end <= clipped_start:
                continue
            translated_start = destination_start + clipped_start - source_start
            translated_end = destination_start + clipped_end - source_start
            destination[track_name].append(V02.Event(
                translated_start,
                translated_end,
                _transposed_pitch(track_name, event.pitch),
                event.velocity,
                origin,
            ))
            copied += 1
        counts[track_name] = copied
    return counts


def _event_signature(event: V02.Event, offset: int, pitch_shift: int) -> tuple[int, int, int, int]:
    return (
        event.start - offset,
        event.end - offset,
        event.pitch - pitch_shift,
        event.velocity,
    )


def _assert_source_identity(source, destination, actual_start: int, motif_output_start: int) -> dict[str, object]:
    initial_source_start = SOURCE_START
    initial_source_end = INITIAL_MELODY_LAST_MEASURE * BAR_TICKS
    checked_tracks: dict[str, int] = {}
    for track_name in TRACKS:
        source_events = [
            event for event in source[track_name]
            if event.end > initial_source_start and event.start < initial_source_end
        ]
        output_events = [
            event for event in destination[track_name]
            if event.origin == "contiguous:m93-100" and actual_start <= event.start < motif_output_start
        ]
        expected = sorted(
            _event_signature(event, initial_source_start, 0)
            for event in source_events
        )
        actual = sorted(
            _event_signature(
                event,
                actual_start,
                0 if track_name == PERCUSSION else PITCH_SHIFT_SEMITONES,
            )
            for event in output_events
        )
        if actual != expected:
            raise RuntimeError(f"Initial source identity drifted for {track_name}")
        checked_tracks[track_name] = len(actual)

    late_checked: dict[str, int] = {}
    for track_name in (ASHEN, HOLLOW, BASS, PERCUSSION):
        source_events = [
            event for event in source[track_name]
            if event.end > MOTIF_START and event.start < SOURCE_END
        ]
        output_events = [
            event for event in destination[track_name]
            if event.origin == "contiguous:m93-100" and motif_output_start <= event.start
        ]
        expected = sorted(_event_signature(event, MOTIF_START, 0) for event in source_events)
        actual = sorted(
            _event_signature(
                event,
                motif_output_start,
                0 if track_name == PERCUSSION else PITCH_SHIFT_SEMITONES,
            )
            for event in output_events
        )
        if actual != expected:
            raise RuntimeError(f"Late accompaniment identity drifted for {track_name}")
        late_checked[track_name] = len(actual)

    source_grave = [
        event for event in source[GRAVE]
        if event.end > initial_source_start and event.start < initial_source_end
    ]
    output_grave = [
        event for event in destination[GRAVE]
        if event.origin == "contiguous:m93-100" and actual_start <= event.start < motif_output_start
    ]
    source_intervals = [b.pitch - a.pitch for a, b in zip(source_grave, source_grave[1:])]
    output_intervals = [b.pitch - a.pitch for a, b in zip(output_grave, output_grave[1:])]
    if output_intervals != source_intervals:
        raise RuntimeError("Initial Grave melody intervals changed")
    if max(event.pitch for event in output_grave) != max(event.pitch for event in source_grave) + PITCH_SHIFT_SEMITONES:
        raise RuntimeError("Initial melody ceiling did not move down by exactly one minor third")

    return {
        "initial_exact_source_event_counts": checked_tracks,
        "late_exact_accompaniment_event_counts": late_checked,
        "initial_grave_lead_event_count": len(output_grave),
        "initial_grave_interval_steps_verified": len(output_intervals),
        "initial_grave_source_pitch_range": [
            min(event.pitch for event in source_grave),
            max(event.pitch for event in source_grave),
        ],
        "initial_grave_output_pitch_range": [
            min(event.pitch for event in output_grave),
            max(event.pitch for event in output_grave),
        ],
    }


def _transposed_iconic_matches(events: list[V02.Event]) -> list[int]:
    ordered = sorted(events, key=lambda event: (event.start, event.pitch, event.end))
    target_pitches = tuple(pitch + PITCH_SHIFT_SEMITONES for pitch in V02.ICONIC_PITCHES)
    matches: list[int] = []
    window = len(target_pitches)
    for index in range(len(ordered) - window + 1):
        candidate = ordered[index:index + window]
        pitches = tuple(event.pitch for event in candidate)
        deltas = tuple(
            candidate[offset + 1].start - candidate[offset].start
            for offset in range(window - 1)
        )
        if pitches == target_pitches and deltas == V02.ICONIC_ONSET_DELTAS:
            matches.append(candidate[0].start)
    return matches


def _build_events(source):
    destination: dict[str, list[V02.Event]] = defaultdict(list)
    pre_roll_counts = _copy_window(
        source,
        destination,
        SOURCE_START,
        SOURCE_START + PRE_ROLL_TICKS,
        0,
        "loop_overlap:exact_m93_first_beat",
        False,
    )
    actual_start = PRE_ROLL_TICKS
    copied_counts = _copy_window(
        source,
        destination,
        SOURCE_START,
        SOURCE_END,
        actual_start,
        "contiguous:m93-100",
        True,
    )
    total_ticks = actual_start + SOURCE_END - SOURCE_START
    motif_output_start = actual_start + MOTIF_START - SOURCE_START

    for track_name in TRACKS:
        destination[track_name].sort(key=lambda event: (event.start, event.pitch, event.end))
    V02._assert_monophonic(destination)

    if any("bridge" in event.origin for events in destination.values() for event in events):
        raise RuntimeError("Authored bridge material leaked into the contiguous v04 excerpt")

    identity_report = _assert_source_identity(source, destination, actual_start, motif_output_start)

    removed_late_lead_counts = {
        track_name: sum(
            event.end > MOTIF_START and event.start < SOURCE_END
            for event in source[track_name]
        )
        for track_name in (VEILED, GRAVE)
    }
    for track_name in (VEILED, GRAVE):
        leaked = [
            event for event in destination[track_name]
            if event.origin == "contiguous:m93-100" and event.start >= motif_output_start
        ]
        if leaked:
            raise RuntimeError(f"Recognizable late lead leaked into v04: {track_name} {leaked}")
    if removed_late_lead_counts[GRAVE] <= 0:
        raise RuntimeError("Expected recognizable late Grave lead was not found in v01")

    iconic_matches = {
        track_name: _transposed_iconic_matches(destination[track_name])
        for track_name in TRACKS[:-1]
    }
    if any(iconic_matches.values()):
        raise RuntimeError(f"Transposed iconic signature survived v04: {iconic_matches}")

    structure = {
        "pre_roll": {"start_tick": 0, "end_tick": PRE_ROLL_TICKS},
        "contiguous_excerpt": {
            "start_tick": actual_start,
            "end_tick": total_ticks,
            "source_measures_inclusive": [SOURCE_FIRST_MEASURE, SOURCE_LAST_MEASURE],
            "source_ticks": [SOURCE_START, SOURCE_END],
        },
        "late_motif_suppression": {
            "start_tick": motif_output_start,
            "end_tick": total_ticks,
            "source_measures_inclusive": [MOTIF_FIRST_MEASURE, SOURCE_LAST_MEASURE],
            "removed_lead_note_counts": removed_late_lead_counts,
        },
        "pre_roll_exact_source_note_counts": pre_roll_counts,
        "copied_note_counts": copied_counts,
        "iconic_signature_matches_after_transposition": iconic_matches,
        "authored_bridge_note_count": 0,
        **identity_report,
    }
    return destination, structure, total_ticks


def _write_midi(events, structure: dict[str, object], total_ticks: int) -> dict[str, int]:
    VERSION_DIR.mkdir(parents=True, exist_ok=True)
    midi = mido.MidiFile(type=1, ticks_per_beat=TICKS_PER_BEAT)
    conductor = mido.MidiTrack()
    conductor.append(mido.MetaMessage("track_name", name="Conductor", time=0))
    conductor.append(mido.MetaMessage("time_signature", numerator=4, denominator=4, time=0))
    conductor.append(mido.MetaMessage("key_signature", key=TARGET_KEY, time=0))
    conductor.append(mido.MetaMessage("set_tempo", tempo=mido.bpm2tempo(QPM), time=0))
    markers = (
        (0, "Loop overlap: exact transposed m93 first beat"),
        (structure["contiguous_excerpt"]["start_tick"], "Contiguous v01 source m93-100, transposed -3 semitones"),
        (structure["late_motif_suppression"]["start_tick"], "Source m99-100: recognizable lead removed"),
    )
    previous_tick = 0
    for tick, label in markers:
        conductor.append(mido.MetaMessage("marker", text=label, time=tick - previous_tick))
        previous_tick = tick
    conductor.append(mido.MetaMessage("end_of_track", time=total_ticks - previous_tick))
    midi.tracks.append(conductor)

    counts: dict[str, int] = {}
    for track_name, channel in zip(TRACKS, CHANNELS, strict=True):
        track = mido.MidiTrack()
        track.append(mido.MetaMessage("track_name", name=track_name, time=0))
        scheduled = []
        for event in events[track_name]:
            scheduled.append((event.start, 1, mido.Message(
                "note_on", note=event.pitch, velocity=event.velocity, channel=channel, time=0
            )))
            scheduled.append((event.end, 0, mido.Message(
                "note_off", note=event.pitch, velocity=0, channel=channel, time=0
            )))
        scheduled.sort(key=lambda item: (item[0], item[1], item[2].note))
        previous_tick = 0
        for absolute_tick, _, message in scheduled:
            message.time = absolute_tick - previous_tick
            track.append(message)
            previous_tick = absolute_tick
        track.append(mido.MetaMessage("end_of_track", time=total_ticks - previous_tick))
        midi.tracks.append(track)
        counts[track_name] = len(events[track_name])
    midi.save(ARRANGEMENT_MIDI)
    return counts


def main() -> int:
    if sha256(SOURCE_MIDI) != EXPECTED_SOURCE_SHA256:
        raise RuntimeError("Immutable source MIDI hash drifted")
    if sha256(V01_MIDI) != EXPECTED_V01_MIDI_SHA256:
        raise RuntimeError("Frozen v01 arrangement MIDI hash drifted")
    if sha256(V02_BUILDER) != EXPECTED_V02_BUILDER_SHA256:
        raise RuntimeError("Frozen v02 helper builder hash drifted")

    config = read_json(CONFIG_PATH)
    verify_source_clearance(config, CONFIG_PATH)
    if config.get("approval", {}).get("status") != "audition":
        raise RuntimeError("v04 builder is only for an unapproved audition")
    if config.get("arrangement", {}).get("version") != "v04":
        raise RuntimeError("v04 config version drifted")
    if abs(float(config["render"]["crossfade_seconds"]) - LOOP_CROSSFADE_SECONDS) > 1e-12:
        raise RuntimeError("v04 loop crossfade drifted from the one-beat overlap")

    source = V02._read_events(V01_MIDI)
    events, structure, total_ticks = _build_events(source)
    note_counts = _write_midi(events, structure, total_ticks)
    if any(count <= 0 for count in note_counts.values()):
        raise RuntimeError(f"Every v04 track must contain notes: {note_counts}")

    audible_ticks = total_ticks - PRE_ROLL_TICKS
    report = {
        "ok": True,
        "version": "v04",
        "source_midi_sha256": sha256(SOURCE_MIDI),
        "v01_arrangement_midi_sha256": sha256(V01_MIDI),
        "v02_helper_builder_sha256": sha256(V02_BUILDER),
        "arrangement_midi": str(ARRANGEMENT_MIDI),
        "arrangement_midi_sha256": sha256(ARRANGEMENT_MIDI),
        "arrangement_note_counts": note_counts,
        "source_selection": {
            "v01_preview_requested": "approximately 5:30-5:59",
            "v01_preview_snapped_seconds": [330.9174726860, 360.0083817769],
            "source_measures_inclusive": [SOURCE_FIRST_MEASURE, SOURCE_LAST_MEASURE],
            "selection_policy": "eight complete contiguous 4/4 bars; no cuts, reordering, or authored bridges",
        },
        "tempo_qpm": QPM,
        "structural_duration_seconds": total_ticks / TICKS_PER_BEAT * 60.0 / QPM,
        "audible_loop_duration_seconds": audible_ticks / TICKS_PER_BEAT * 60.0 / QPM,
        "loop_crossfade_seconds": LOOP_CROSSFADE_SECONDS,
        "loop_policy": "one exact copied source beat provides the renderer overlap; no composed bridge notes",
        "transpositions": {
            "pitched_tracks": PITCH_SHIFT_SEMITONES,
            "percussion": 0,
            "source_key": "B-flat minor",
            "target_key": "G minor",
            "musical_effect": "all intervals, rhythms, harmony, and voice relationships are unchanged; only absolute register/key is lowered",
        },
        "harmony_changes": "none beyond uniform transposition",
        "structure": structure,
    }
    write_json(BUILD_REPORT, report)
    print(json.dumps(report, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
