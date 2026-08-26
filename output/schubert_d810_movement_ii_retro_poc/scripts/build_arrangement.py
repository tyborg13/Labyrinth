#!/usr/bin/env python3
"""Reproducibly extract and arrange Schubert D.810, Movement II.

The immutable input is the CC0 OpenScore String Quartets compressed MusicXML
saved under ../source. This script:

1. verifies that exact source by SHA-256;
2. extracts Movement II without changing the source file;
3. writes a four-part normalized MusicXML score and four separate part files;
4. expands the notated repeats for normalized and arranged MIDI playback;
5. reduces each original staff to one simultaneous retro voice, adds one
   restrained octave-below cello shadow, and writes faithful_retro.mid; and
6. optionally renders a sample-free procedural oscillator preview.

The renderer uses only generated waveforms. It does not load a SoundFont,
sample library, performance, or recording.
"""

from __future__ import annotations

import argparse
import bisect
import copy
import hashlib
import json
import math
import re
import shutil
import subprocess
import sys
import wave
import zipfile
from collections import defaultdict
from dataclasses import asdict, dataclass
from pathlib import Path
import xml.etree.ElementTree as ET

import mido
import music21
from music21 import chord, converter, dynamics, expressions, note, stream, tempo
import numpy as np


POC_ROOT = Path(__file__).resolve().parents[1]
SOURCE_MXL = POC_ROOT / "source" / "openscore_sq7397765.mxl"
EXPECTED_SOURCE_SHA256 = "c1370ff43b2272b88e04d41d3cc31ca6717a982eaa09cc5540a5952b4f3c1bd5"

NORMALIZED_DIR = POC_ROOT / "normalized"
PARTS_DIR = NORMALIZED_DIR / "parts"
NORMALIZED_SCORE_XML = NORMALIZED_DIR / "movement_ii_four_parts.musicxml"
NORMALIZED_SCORE_MIDI = NORMALIZED_DIR / "movement_ii_four_parts.mid"
ARRANGEMENT_MIDI = POC_ROOT / "faithful_retro.mid"
AUDIO_PREVIEW = POC_ROOT / "faithful_retro_preview.ogg"
AUDIO_PREVIEW_LOSSLESS = POC_ROOT / "faithful_retro_preview.flac"
BUILD_REPORT = POC_ROOT / "BUILD_REPORT.json"

TEMPO_QPM = 92
TICKS_PER_BEAT = 480
SAMPLE_RATE = 44_100

EXPECTED_PART_NAMES = ("Violin 1", "Violin 2", "Viola", "Violoncello")
PART_FILE_STEMS = ("violin_i", "violin_ii", "viola", "cello")


@dataclass(frozen=True)
class NoteEvent:
    start_ql: float
    duration_ql: float
    pitch: int
    velocity: int

    @property
    def end_ql(self) -> float:
        return self.start_ql + self.duration_ql


@dataclass(frozen=True)
class TrackSpec:
    name: str
    source_part: str
    program: int
    channel: int
    volume: int
    pan: int
    pitch_strategy: str
    velocity_offset: int
    oscillator: str


TRACK_SPECS = (
    TrackSpec(
        "Pulse I / Violin I",
        "Violin 1",
        80,
        0,
        91,
        78,
        "highest",
        0,
        "pulse_soft",
    ),
    TrackSpec(
        "Pulse II / Violin II",
        "Violin 2",
        80,
        1,
        84,
        50,
        "highest",
        -2,
        "pulse_dark",
    ),
    TrackSpec(
        "Triangle / Viola",
        "Viola",
        79,
        2,
        88,
        69,
        "lowest",
        0,
        "triangle",
    ),
    TrackSpec(
        "Low Triangle / Cello",
        "Violoncello",
        38,
        3,
        101,
        59,
        "lowest",
        5,
        "cello",
    ),
)

BASS_SPEC = TrackSpec(
    "Sub-Bass Shadow / Cello -8ve",
    "Violoncello",
    39,
    4,
    76,
    64,
    "lowest",
    -1,
    "sub",
)

DYNAMIC_VELOCITY = {
    "pppp": 38,
    "ppp": 41,
    "pp": 46,
    "p": 52,
    "mp": 58,
    "mf": 64,
    "f": 70,
    "ff": 76,
    "fff": 78,
    "ffff": 78,
    "sf": 72,
    "sfz": 74,
    "sffz": 76,
    "fz": 72,
    "rfz": 72,
    "fp": 58,
}


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk_bytes in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk_bytes)
    return digest.hexdigest()


def verify_immutable_source() -> str:
    actual = sha256(SOURCE_MXL)
    if actual != EXPECTED_SOURCE_SHA256:
        raise RuntimeError(
            "Refusing to transform an unrecognized source: "
            f"expected {EXPECTED_SOURCE_SHA256}, got {actual}"
        )
    return actual


def read_score_xml_from_mxl() -> ET.Element:
    with zipfile.ZipFile(SOURCE_MXL) as archive:
        score_entries = [
            name
            for name in archive.namelist()
            if name.lower().endswith(".xml") and not name.startswith("META-INF/")
        ]
        if len(score_entries) != 1:
            raise RuntimeError(f"Expected exactly one score XML entry, found {score_entries}")
        return ET.fromstring(archive.read(score_entries[0]))


def measure_words(measure: ET.Element) -> str:
    return " | ".join(
        (element.text or "").strip()
        for element in measure.iter("words")
        if (element.text or "").strip()
    )


def movement_measure_bounds(root: ET.Element) -> tuple[int, int]:
    parts = root.findall("part")
    if len(parts) != 4:
        raise RuntimeError(f"Expected four source parts, found {len(parts)}")
    measures = parts[0].findall("measure")
    start = next(
        (
            index
            for index, measure in enumerate(measures)
            if "II." in measure_words(measure)
            and "Andante con moto" in measure_words(measure)
        ),
        None,
    )
    if start is None:
        raise RuntimeError("Could not locate the Movement II heading")
    end = next(
        (
            index
            for index, measure in enumerate(measures[start + 1 :], start + 1)
            if "III." in measure_words(measure)
            or "III.  Scherzo" in measure_words(measure)
        ),
        None,
    )
    if end is None:
        raise RuntimeError("Could not locate the Movement III boundary")
    if (start, end) != (341, 521):
        raise RuntimeError(f"Unexpected source movement bounds {(start, end)}")
    return start, end


def source_part_names(root: ET.Element) -> tuple[str, ...]:
    part_list = root.find("part-list")
    if part_list is None:
        raise RuntimeError("MusicXML is missing part-list")
    names = tuple(
        (score_part.findtext("part-name") or "").strip()
        for score_part in part_list.findall("score-part")
    )
    if names != EXPECTED_PART_NAMES:
        raise RuntimeError(f"Unexpected source part names {names}")
    return names


def trim_root_to_movement(root: ET.Element, start: int, end: int) -> ET.Element:
    trimmed = copy.deepcopy(root)
    for part in trimmed.findall("part"):
        measures = part.findall("measure")
        if len(measures) < end:
            raise RuntimeError(
                f"Part {part.attrib.get('id')} has only {len(measures)} measures"
            )
        keep = set(measures[start:end])
        for measure in measures:
            if measure not in keep:
                part.remove(measure)
    return trimmed


def write_xml(root: ET.Element, destination: Path) -> None:
    destination.parent.mkdir(parents=True, exist_ok=True)
    tree = ET.ElementTree(root)
    ET.indent(tree, space="  ")
    tree.write(destination, encoding="utf-8", xml_declaration=True)


def write_normalized_musicxml(root: ET.Element) -> dict[str, object]:
    start, end = movement_measure_bounds(root)
    names = source_part_names(root)
    movement_root = trim_root_to_movement(root, start, end)
    write_xml(movement_root, NORMALIZED_SCORE_XML)

    part_list = movement_root.find("part-list")
    if part_list is None:
        raise RuntimeError("Trimmed MusicXML is missing part-list")
    score_parts = part_list.findall("score-part")
    music_parts = movement_root.findall("part")
    if len(score_parts) != 4 or len(music_parts) != 4:
        raise RuntimeError("Trimmed MusicXML did not preserve four parts")

    for index, file_stem in enumerate(PART_FILE_STEMS):
        part_root = copy.deepcopy(movement_root)
        part_list_copy = part_root.find("part-list")
        if part_list_copy is None:
            raise RuntimeError("Part MusicXML is missing part-list")
        for score_part in list(part_list_copy.findall("score-part")):
            if score_part.attrib.get("id") != score_parts[index].attrib.get("id"):
                part_list_copy.remove(score_part)
        for music_part in list(part_root.findall("part")):
            if music_part.attrib.get("id") != music_parts[index].attrib.get("id"):
                part_root.remove(music_part)
        write_xml(part_root, PARTS_DIR / f"{file_stem}.musicxml")

    return {
        "source_measure_start_index": start,
        "source_measure_end_index_exclusive": end,
        "notated_measure_objects_per_part": end - start,
        "source_part_names": list(names),
    }


def parse_normalized_score() -> stream.Score:
    parsed = converter.parse(NORMALIZED_SCORE_XML)
    if not isinstance(parsed, stream.Score) or len(parsed.parts) != 4:
        raise RuntimeError("Normalized MusicXML did not parse as a four-part score")
    return parsed


def expanded_performance_score(score: stream.Score) -> stream.Score:
    performed = stream.Score()
    performed.metadata = copy.deepcopy(score.metadata)
    for part in score.parts:
        expanded = part.expandRepeats()
        if len(list(expanded.getElementsByClass(stream.Measure))) != 300:
            raise RuntimeError(
                f"Unexpected expanded measure count for {part.partName}: "
                f"{len(list(expanded.getElementsByClass(stream.Measure)))}"
            )
        performed.insert(0, expanded)
    return performed


def midi_track_name(track: mido.MidiTrack) -> str:
    for message in track:
        if message.type == "track_name":
            return message.name
    return ""


def absolute_messages(track: mido.MidiTrack) -> list[tuple[int, mido.Message]]:
    absolute = 0
    messages: list[tuple[int, mido.Message]] = []
    for message in track:
        absolute += message.time
        messages.append((absolute, message))
    return messages


def write_single_part_midis(combined_path: Path) -> dict[str, str]:
    combined = mido.MidiFile(combined_path)
    note_tracks = [
        track
        for track in combined.tracks
        if any(message.type == "note_on" and message.velocity > 0 for message in track)
    ]
    if len(note_tracks) != 4:
        raise RuntimeError(f"Expected four note tracks, found {len(note_tracks)}")

    conductor_types = {"set_tempo", "time_signature", "key_signature", "marker"}
    conductor_events: list[tuple[int, mido.MetaMessage]] = []
    seen: set[tuple[object, ...]] = set()
    for track in combined.tracks:
        for absolute, message in absolute_messages(track):
            if not message.is_meta or message.type not in conductor_types:
                continue
            payload = tuple(sorted(message.dict().items()))
            identity = (absolute, message.type, payload)
            if identity not in seen:
                conductor_events.append((absolute, message.copy(time=0)))
                seen.add(identity)
    conductor_events.sort(key=lambda item: (item[0], item[1].type))

    written: dict[str, str] = {}
    for index, (part_name, file_stem) in enumerate(
        zip(EXPECTED_PART_NAMES, PART_FILE_STEMS, strict=True)
    ):
        chosen = next(
            (track for track in note_tracks if part_name.lower() in midi_track_name(track).lower()),
            note_tracks[index],
        )
        output = mido.MidiFile(type=1, ticks_per_beat=combined.ticks_per_beat)
        conductor = mido.MidiTrack()
        conductor.append(mido.MetaMessage("track_name", name="Conductor", time=0))
        previous = 0
        for absolute, message in conductor_events:
            conductor.append(message.copy(time=absolute - previous))
            previous = absolute
        conductor.append(mido.MetaMessage("end_of_track", time=0))
        output.tracks.append(conductor)

        part_track = mido.MidiTrack()
        part_track.append(mido.MetaMessage("track_name", name=part_name, time=0))
        previous = 0
        for absolute, message in absolute_messages(chosen):
            if message.type in {"track_name", "end_of_track"}:
                continue
            if message.is_meta and message.type in conductor_types:
                continue
            part_track.append(message.copy(time=absolute - previous))
            previous = absolute
        part_track.append(mido.MetaMessage("end_of_track", time=0))
        output.tracks.append(part_track)
        destination = PARTS_DIR / f"{file_stem}.mid"
        output.save(destination)
        written[part_name] = str(destination.relative_to(POC_ROOT))
    return written


def full_part_note_events(part: stream.Part) -> list[NoteEvent]:
    """Keep every pitch, while making same-channel note lifetimes unambiguous."""
    stripped = part.stripTies(inPlace=False, matchByPitch=True)
    flattened = stripped.flatten()
    dynamic_marks = sorted(
        (
            (float(mark.offset), (mark.value or "p").lower())
            for mark in flattened.getElementsByClass(dynamics.Dynamic)
        ),
        key=lambda item: item[0],
    )
    dynamic_offsets = [item[0] for item in dynamic_marks]
    dynamic_values = [item[1] for item in dynamic_marks]
    raw: list[NoteEvent] = []
    for element in flattened.notes:
        if not isinstance(element, (note.Note, chord.Chord)):
            continue
        duration = float(element.duration.quarterLength)
        if duration <= 0:
            continue
        start = round(float(element.offset), 8)
        dynamic_name = dynamic_at_offset(dynamic_offsets, dynamic_values, start)
        velocity = DYNAMIC_VELOCITY.get(dynamic_name, 58)
        velocity = max(32, min(108, velocity + articulation_velocity(element)))
        gate = articulation_gate(element)
        gated_duration = max(0.03, duration * gate)
        pitches = (
            [int(element.pitch.midi)]
            if isinstance(element, note.Note)
            else [int(pitch.midi) for pitch in element.pitches]
        )
        for pitch in pitches:
            raw.append(NoteEvent(start, gated_duration, pitch, velocity))

    by_pitch: dict[int, list[NoteEvent]] = defaultdict(list)
    for event in raw:
        by_pitch[event.pitch].append(event)
    merged: list[NoteEvent] = []
    for pitch, events in by_pitch.items():
        for event in sorted(events, key=lambda item: (item.start_ql, item.end_ql)):
            if merged_for_pitch := (
                merged[-1]
                if merged and merged[-1].pitch == pitch
                else None
            ):
                if event.start_ql < merged_for_pitch.end_ql - 1e-8:
                    merged[-1] = NoteEvent(
                        merged_for_pitch.start_ql,
                        max(merged_for_pitch.end_ql, event.end_ql)
                        - merged_for_pitch.start_ql,
                        pitch,
                        max(merged_for_pitch.velocity, event.velocity),
                    )
                    continue
            merged.append(event)
    return sorted(merged, key=lambda item: (item.start_ql, item.pitch, item.end_ql))


def normalized_note_track(
    part_name: str,
    program: int,
    channel: int,
    events: list[NoteEvent],
) -> mido.MidiTrack:
    track = mido.MidiTrack()
    track.append(mido.MetaMessage("track_name", name=part_name, time=0))
    track.append(mido.MetaMessage("instrument_name", name=part_name, time=0))
    track.append(mido.Message("program_change", channel=channel, program=program, time=0))
    timed: list[tuple[int, int, mido.Message]] = []
    for event in events:
        start_tick = ticks(event.start_ql)
        end_tick = max(start_tick + 1, ticks(event.end_ql))
        timed.append(
            (
                start_tick,
                1,
                mido.Message(
                    "note_on",
                    channel=channel,
                    note=event.pitch,
                    velocity=event.velocity,
                    time=0,
                ),
            )
        )
        timed.append(
            (
                end_tick,
                0,
                mido.Message(
                    "note_off",
                    channel=channel,
                    note=event.pitch,
                    velocity=0,
                    time=0,
                ),
            )
        )
    timed.sort(key=lambda item: (item[0], item[1], item[2].note))
    previous = 0
    for absolute, _, message in timed:
        track.append(message.copy(time=absolute - previous))
        previous = absolute
    track.append(mido.MetaMessage("end_of_track", time=0))
    return track


def source_tempo_events(first_part: stream.Part) -> list[tuple[int, int]]:
    by_tick: dict[int, int] = {}
    for mark in first_part.flatten().getElementsByClass(tempo.MetronomeMark):
        quarter_bpm = mark.getQuarterBPM()
        if quarter_bpm is None or quarter_bpm <= 0:
            continue
        by_tick[ticks(float(mark.offset))] = mido.bpm2tempo(float(quarter_bpm))
    by_tick.setdefault(0, mido.bpm2tempo(94))
    return sorted(by_tick.items())


def write_normalized_midis(score: stream.Score) -> dict[str, object]:
    performed = expanded_performance_score(score)
    midi = mido.MidiFile(type=1, ticks_per_beat=TICKS_PER_BEAT)
    conductor = mido.MidiTrack()
    conductor.append(mido.MetaMessage("track_name", name="Conductor", time=0))
    conductor.append(mido.MetaMessage("time_signature", numerator=4, denominator=4, time=0))
    conductor.append(mido.MetaMessage("key_signature", key="Gm", time=0))
    previous = 0
    tempo_events = source_tempo_events(performed.parts[0])
    for absolute, microseconds in tempo_events:
        conductor.append(
            mido.MetaMessage(
                "set_tempo",
                tempo=microseconds,
                time=absolute - previous,
            )
        )
        previous = absolute
    conductor.append(mido.MetaMessage("end_of_track", time=0))
    midi.tracks.append(conductor)

    original_programs = (40, 40, 41, 42)
    normalized_counts: dict[str, int] = {}
    for channel, (part, program) in enumerate(
        zip(performed.parts, original_programs, strict=True)
    ):
        events = full_part_note_events(part)
        normalized_counts[part.partName] = len(events)
        midi.tracks.append(
            normalized_note_track(part.partName, program, channel, events)
        )
    midi.save(NORMALIZED_SCORE_MIDI)
    separate = write_single_part_midis(NORMALIZED_SCORE_MIDI)
    return {
        "expanded_quarter_length": float(performed.highestTime),
        "expanded_measures_per_part": 300,
        "tempo_event_count": len(tempo_events),
        "note_counts": normalized_counts,
        "separate_part_midis": separate,
    }


def dynamic_at_offset(
    dynamic_offsets: list[float], dynamic_values: list[str], offset: float
) -> str:
    index = bisect.bisect_right(dynamic_offsets, offset + 1e-8) - 1
    return dynamic_values[index] if index >= 0 else "p"


def articulation_gate(element: note.Note | chord.Chord) -> float:
    names = {articulation.__class__.__name__.lower() for articulation in element.articulations}
    if "staccatissimo" in names:
        return 0.38
    if "staccato" in names:
        return 0.54
    if "detachedlegato" in names:
        return 0.72
    if "tenuto" in names:
        return 0.98
    return 0.92


def articulation_velocity(element: note.Note | chord.Chord) -> int:
    names = {articulation.__class__.__name__.lower() for articulation in element.articulations}
    if "strongaccent" in names:
        return 6
    if "accent" in names or "marcato" in names:
        return 4
    return 0


def pitch_from_element(element: note.Note | chord.Chord, strategy: str) -> int:
    if isinstance(element, note.Note):
        return int(element.pitch.midi)
    pitches = [int(pitch.midi) for pitch in element.pitches]
    if not pitches:
        raise RuntimeError("Encountered a chord without pitches")
    return max(pitches) if strategy == "highest" else min(pitches)


def part_note_events(part: stream.Part, spec: TrackSpec) -> list[NoteEvent]:
    stripped = part.stripTies(inPlace=False, matchByPitch=True)
    flattened = stripped.flatten()
    dynamic_marks = sorted(
        (
            (float(mark.offset), (mark.value or "p").lower())
            for mark in flattened.getElementsByClass(dynamics.Dynamic)
        ),
        key=lambda item: item[0],
    )
    dynamic_offsets = [item[0] for item in dynamic_marks]
    dynamic_values = [item[1] for item in dynamic_marks]

    candidates: dict[float, list[tuple[int, float, int, float]]] = defaultdict(list)
    for element in flattened.notes:
        if not isinstance(element, (note.Note, chord.Chord)):
            continue
        duration = float(element.duration.quarterLength)
        if duration <= 0:
            continue
        start = round(float(element.offset), 8)
        pitch = pitch_from_element(element, spec.pitch_strategy)
        dynamic_name = dynamic_at_offset(dynamic_offsets, dynamic_values, start)
        velocity = DYNAMIC_VELOCITY.get(dynamic_name, 58)
        velocity += spec.velocity_offset + articulation_velocity(element)
        velocity = max(38, min(78, velocity))
        gate = articulation_gate(element)
        candidates[start].append((pitch, duration, velocity, gate))

    selected: list[NoteEvent] = []
    for start in sorted(candidates):
        entries = candidates[start]
        chooser = max if spec.pitch_strategy == "highest" else min
        chosen = chooser(entries, key=lambda item: item[0])
        pitch, duration, velocity, gate = chosen
        gated_duration = max(0.03, duration * gate)
        selected.append(NoteEvent(start, gated_duration, pitch, velocity))

    monophonic: list[NoteEvent] = []
    for index, event in enumerate(selected):
        duration = event.duration_ql
        if index + 1 < len(selected):
            next_start = selected[index + 1].start_ql
            if event.start_ql + duration >= next_start:
                duration = max(0.03, (next_start - event.start_ql) * 0.98)
        if duration > 0:
            monophonic.append(
                NoteEvent(event.start_ql, duration, event.pitch, event.velocity)
            )
    return monophonic


def bass_shadow_events(cello_events: list[NoteEvent]) -> list[NoteEvent]:
    shadow: list[NoteEvent] = []
    for event in cello_events:
        transposed = event.pitch - 12
        if transposed < 28:
            continue
        shadow.append(
            NoteEvent(
                event.start_ql,
                event.duration_ql,
                transposed,
                max(38, min(72, event.velocity + BASS_SPEC.velocity_offset)),
            )
        )
    return shadow


def ticks(quarter_length: float) -> int:
    return int(round(quarter_length * TICKS_PER_BEAT))


def event_midi_track(spec: TrackSpec, events: list[NoteEvent]) -> mido.MidiTrack:
    track = mido.MidiTrack()
    track.append(mido.MetaMessage("track_name", name=spec.name, time=0))
    track.append(
        mido.MetaMessage(
            "instrument_name",
            name=f"Procedural {spec.oscillator}; GM program is a fallback hint",
            time=0,
        )
    )
    track.append(mido.Message("program_change", channel=spec.channel, program=spec.program, time=0))
    track.append(mido.Message("control_change", channel=spec.channel, control=7, value=spec.volume, time=0))
    track.append(mido.Message("control_change", channel=spec.channel, control=10, value=spec.pan, time=0))

    timed: list[tuple[int, int, mido.Message]] = []
    for event in events:
        start_tick = ticks(event.start_ql)
        end_tick = max(start_tick + 1, ticks(event.end_ql))
        timed.append(
            (
                start_tick,
                1,
                mido.Message(
                    "note_on",
                    channel=spec.channel,
                    note=event.pitch,
                    velocity=event.velocity,
                    time=0,
                ),
            )
        )
        timed.append(
            (
                end_tick,
                0,
                mido.Message(
                    "note_off",
                    channel=spec.channel,
                    note=event.pitch,
                    velocity=0,
                    time=0,
                ),
            )
        )
    timed.sort(key=lambda item: (item[0], item[1], item[2].note))
    previous = 0
    for absolute, _, message in timed:
        track.append(message.copy(time=absolute - previous))
        previous = absolute
    track.append(mido.MetaMessage("end_of_track", time=0))
    return track


def write_arrangement_midi(
    score: stream.Score,
) -> tuple[dict[str, list[NoteEvent]], dict[str, object]]:
    performed = expanded_performance_score(score)
    part_by_name = {part.partName: part for part in performed.parts}
    track_events: dict[str, list[NoteEvent]] = {}
    for spec in TRACK_SPECS:
        part = part_by_name.get(spec.source_part)
        if part is None:
            raise RuntimeError(f"Could not find source part {spec.source_part}")
        track_events[spec.name] = part_note_events(part, spec)
    cello_events = track_events[TRACK_SPECS[-1].name]
    track_events[BASS_SPEC.name] = bass_shadow_events(cello_events)

    midi = mido.MidiFile(type=1, ticks_per_beat=TICKS_PER_BEAT)
    conductor = mido.MidiTrack()
    conductor.append(mido.MetaMessage("track_name", name="Conductor / Provenance", time=0))
    conductor.append(
        mido.MetaMessage(
            "copyright",
            text=(
                "Franz Schubert composition: public domain. OpenScore String "
                "Quartets transcription sq7397765: CC0. POC arrangement and "
                "procedural rendering created for Escape the Umbra."
            ),
            time=0,
        )
    )
    conductor.append(
        mido.MetaMessage(
            "text",
            text="Source SHA-256: " + EXPECTED_SOURCE_SHA256,
            time=0,
        )
    )
    conductor.append(mido.MetaMessage("time_signature", numerator=4, denominator=4, time=0))
    conductor.append(mido.MetaMessage("key_signature", key="Gm", time=0))
    conductor.append(mido.MetaMessage("set_tempo", tempo=mido.bpm2tempo(TEMPO_QPM), time=0))
    conductor.append(mido.MetaMessage("marker", text="II. Andante con moto", time=0))
    conductor.append(mido.MetaMessage("end_of_track", time=0))
    midi.tracks.append(conductor)
    for spec in (*TRACK_SPECS, BASS_SPEC):
        midi.tracks.append(event_midi_track(spec, track_events[spec.name]))
    midi.save(ARRANGEMENT_MIDI)

    note_counts = {name: len(events) for name, events in track_events.items()}
    pitch_ranges = {
        name: [min(event.pitch for event in events), max(event.pitch for event in events)]
        for name, events in track_events.items()
    }
    last_ql = max(event.end_ql for events in track_events.values() for event in events)
    metrics = {
        "tempo_qpm": TEMPO_QPM,
        "ticks_per_beat": TICKS_PER_BEAT,
        "musical_voice_tracks": 5,
        "note_counts": note_counts,
        "pitch_ranges_midi": pitch_ranges,
        "last_note_quarter_length": last_ql,
        "nominal_duration_seconds": last_ql * 60.0 / TEMPO_QPM,
    }
    return track_events, metrics


@dataclass(frozen=True)
class RenderNote:
    start_seconds: float
    end_seconds: float
    pitch: int
    velocity: int


def parse_render_notes(path: Path) -> dict[str, list[RenderNote]]:
    midi = mido.MidiFile(path)
    seconds_per_tick = 60.0 / (TEMPO_QPM * midi.ticks_per_beat)
    rendered: dict[str, list[RenderNote]] = {}
    for track in midi.tracks:
        name = midi_track_name(track)
        if name not in {spec.name for spec in (*TRACK_SPECS, BASS_SPEC)}:
            continue
        active: dict[tuple[int, int], list[tuple[int, int]]] = defaultdict(list)
        absolute = 0
        notes: list[RenderNote] = []
        for message in track:
            absolute += message.time
            if message.type == "note_on" and message.velocity > 0:
                active[(message.channel, message.note)].append((absolute, message.velocity))
            elif message.type in {"note_off", "note_on"}:
                key = (message.channel, message.note)
                if active[key]:
                    start, velocity = active[key].pop(0)
                    notes.append(
                        RenderNote(
                            start * seconds_per_tick,
                            absolute * seconds_per_tick,
                            message.note,
                            velocity,
                        )
                    )
        rendered[name] = sorted(notes, key=lambda item: item.start_seconds)
    return rendered


def triangle_wave(phase: np.ndarray) -> np.ndarray:
    output = np.zeros_like(phase)
    for harmonic in (1, 3, 5, 7):
        sign = -1.0 if ((harmonic - 1) // 2) % 2 else 1.0
        output += sign * np.sin(harmonic * phase) / (harmonic * harmonic)
    return output * (8.0 / (math.pi * math.pi))


def pulse_wave(phase: np.ndarray, duty: float, harmonics: int) -> np.ndarray:
    output = np.zeros_like(phase)
    for harmonic in range(1, harmonics + 1):
        coefficient = 2.0 * math.sin(math.pi * harmonic * duty) / (
            math.pi * harmonic
        )
        output += coefficient * np.cos(harmonic * (phase - math.pi * duty))
    return output


def oscillator(shape: str, phase: np.ndarray) -> np.ndarray:
    if shape == "pulse_soft":
        return 0.82 * pulse_wave(phase, 0.42, 4) + 0.18 * np.sin(phase)
    if shape == "pulse_dark":
        return 0.72 * pulse_wave(phase, 0.34, 4) + 0.28 * triangle_wave(phase)
    if shape == "triangle":
        return triangle_wave(phase)
    if shape == "cello":
        return 0.72 * triangle_wave(phase) + 0.28 * np.sin(phase)
    if shape == "sub":
        return 0.78 * np.sin(phase) + 0.22 * triangle_wave(phase)
    raise ValueError(f"Unknown oscillator shape {shape}")


def render_procedural_preview() -> dict[str, object]:
    if shutil.which("ffmpeg") is None:
        raise RuntimeError(
            "ffmpeg is required to encode the FLAC/Vorbis previews; rerun with --skip-audio"
        )
    notes_by_track = parse_render_notes(ARRANGEMENT_MIDI)
    spec_by_name = {spec.name: spec for spec in (*TRACK_SPECS, BASS_SPEC)}
    final_note = max(
        render_note.end_seconds
        for track_notes in notes_by_track.values()
        for render_note in track_notes
    )
    duration = final_note + 1.0
    total_samples = int(math.ceil(duration * SAMPLE_RATE))
    chunk_size = 32_768
    release_seconds = 0.075
    attack_seconds = 0.010
    temporary_wave = POC_ROOT / "faithful_retro_preview.render.wav"

    positions = {track_name: 0 for track_name in notes_by_track}
    active = {track_name: [] for track_name in notes_by_track}
    peak = 0.0
    sum_squares = 0.0
    counted_samples = 0

    with wave.open(str(temporary_wave), "wb") as wav:
        wav.setnchannels(2)
        wav.setsampwidth(2)
        wav.setframerate(SAMPLE_RATE)

        for chunk_start in range(0, total_samples, chunk_size):
            chunk_end = min(total_samples, chunk_start + chunk_size)
            sample_numbers = np.arange(chunk_start, chunk_end, dtype=np.float64)
            sample_times = sample_numbers / SAMPLE_RATE
            start_seconds = chunk_start / SAMPLE_RATE
            end_seconds = chunk_end / SAMPLE_RATE
            left = np.zeros(chunk_end - chunk_start, dtype=np.float64)
            right = np.zeros(chunk_end - chunk_start, dtype=np.float64)

            for track_name, track_notes in notes_by_track.items():
                position = positions[track_name]
                while (
                    position < len(track_notes)
                    and track_notes[position].start_seconds < end_seconds
                ):
                    active[track_name].append(track_notes[position])
                    position += 1
                positions[track_name] = position
                active[track_name] = [
                    render_note
                    for render_note in active[track_name]
                    if render_note.end_seconds + release_seconds > start_seconds
                ]

                spec = spec_by_name[track_name]
                pan = spec.pan / 127.0
                left_gain = math.cos(pan * math.pi / 2.0)
                right_gain = math.sin(pan * math.pi / 2.0)
                for render_note in active[track_name]:
                    mask = (sample_times >= render_note.start_seconds) & (
                        sample_times < render_note.end_seconds + release_seconds
                    )
                    if not np.any(mask):
                        continue
                    local_times = sample_times[mask] - render_note.start_seconds
                    frequency = 440.0 * (2.0 ** ((render_note.pitch - 69) / 12.0))
                    phase = 2.0 * math.pi * frequency * local_times
                    envelope = np.minimum(1.0, local_times / attack_seconds)
                    release_mask = sample_times[mask] > render_note.end_seconds
                    if np.any(release_mask):
                        envelope[release_mask] *= np.maximum(
                            0.0,
                            1.0
                            - (
                                sample_times[mask][release_mask]
                                - render_note.end_seconds
                            )
                            / release_seconds,
                        )
                    amplitude = 0.50 * (render_note.velocity / 127.0) ** 1.15
                    signal = oscillator(spec.oscillator, phase) * envelope * amplitude
                    left[mask] += signal * left_gain
                    right[mask] += signal * right_gain

            stereo = np.column_stack((left, right))
            stereo = np.tanh(stereo * 0.42) * 0.92
            peak = max(peak, float(np.max(np.abs(stereo))))
            sum_squares += float(np.sum(stereo * stereo))
            counted_samples += stereo.size
            pcm = np.clip(stereo * 32767.0, -32768, 32767).astype("<i2")
            wav.writeframes(pcm.tobytes())

    common_metadata = [
        "-metadata",
        "title=Death and the Maiden, Movement II - Faithful Retro POC",
        "-metadata",
        "artist=Franz Schubert; procedural POC arrangement for Escape the Umbra",
        "-metadata",
        "comment=Public-domain composition; OpenScore sq7397765 CC0 source; sample-free procedural oscillator render",
    ]
    flac_command = [
        "ffmpeg",
        "-hide_banner",
        "-loglevel",
        "error",
        "-y",
        "-i",
        str(temporary_wave),
        "-codec:a",
        "flac",
        "-compression_level",
        "8",
        *common_metadata,
        str(AUDIO_PREVIEW_LOSSLESS),
    ]
    subprocess.run(flac_command, check=True)

    encoder_listing = subprocess.run(
        ["ffmpeg", "-hide_banner", "-encoders"],
        check=True,
        capture_output=True,
        text=True,
    ).stdout
    if re.search(r"^\s*A\S*\s+libvorbis\s", encoder_listing, flags=re.MULTILINE):
        vorbis_encoder = ["-codec:a", "libvorbis", "-qscale:a", "5"]
        vorbis_label = "FFmpeg libvorbis quality 5"
    elif re.search(r"^\s*A\S*\s+vorbis\s", encoder_listing, flags=re.MULTILINE):
        vorbis_encoder = [
            "-codec:a",
            "vorbis",
            "-strict",
            "experimental",
            "-qscale:a",
            "5",
        ]
        vorbis_label = "FFmpeg native Vorbis quality 5 (experimental encoder API)"
    else:
        raise RuntimeError(
            "FFmpeg has neither libvorbis nor its native Vorbis encoder; "
            "the lossless FLAC reference was created"
        )
    vorbis_command = [
        "ffmpeg",
        "-hide_banner",
        "-loglevel",
        "error",
        "-y",
        "-i",
        str(temporary_wave),
        *vorbis_encoder,
        *common_metadata,
        str(AUDIO_PREVIEW),
    ]
    subprocess.run(vorbis_command, check=True)
    temporary_wave.unlink()
    return {
        "path": str(AUDIO_PREVIEW.relative_to(POC_ROOT)),
        "lossless_reference_path": str(AUDIO_PREVIEW_LOSSLESS.relative_to(POC_ROOT)),
        "sample_rate": SAMPLE_RATE,
        "channels": 2,
        "duration_seconds": duration,
        "peak_linear": peak,
        "peak_dbfs": 20.0 * math.log10(max(peak, 1e-12)),
        "rms_linear": math.sqrt(sum_squares / counted_samples),
        "renderer": "sample-free deterministic additive/pulse/triangle oscillator synth",
        "encoder": vorbis_label,
        "lossless_encoder": "FFmpeg FLAC compression level 8",
    }


def build(skip_audio: bool) -> dict[str, object]:
    NORMALIZED_DIR.mkdir(parents=True, exist_ok=True)
    PARTS_DIR.mkdir(parents=True, exist_ok=True)
    source_hash = verify_immutable_source()
    xml_root = read_score_xml_from_mxl()
    extraction = write_normalized_musicxml(xml_root)
    score = parse_normalized_score()
    normalized_midi = write_normalized_midis(score)
    _, arrangement = write_arrangement_midi(score)
    audio = None if skip_audio else render_procedural_preview()

    report = {
        "source": {
            "path": str(SOURCE_MXL.relative_to(POC_ROOT)),
            "sha256": source_hash,
            "format": "compressed MusicXML (.mxl)",
        },
        "extraction": extraction,
        "normalized": normalized_midi,
        "arrangement": arrangement,
        "audio_preview": audio,
        "tools": {
            "python": sys.version.split()[0],
            "music21": music21.__version__,
            "mido": getattr(mido, "__version__", "1.3.3"),
            "numpy": np.__version__,
        },
    }
    BUILD_REPORT.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    return report


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--skip-audio",
        action="store_true",
        help="Build MusicXML and MIDI only; do not render the Ogg preview.",
    )
    args = parser.parse_args()
    report = build(skip_audio=args.skip_audio)
    print(json.dumps(report, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
