#!/usr/bin/env python3
"""Build the user-selected, motif-suppressed Chopin death-loop v02 audition."""

from __future__ import annotations

from collections import defaultdict, deque
from dataclasses import dataclass
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


CONFIG_PATH = TRACK_ROOT / "track.v02.json"
SOURCE_MIDI = TRACK_ROOT / "source" / "chopin_piano_sonata_no2_op35_pdmx_cc0.mid"
V01_MIDI = TRACK_ROOT / "versions" / "v01" / "arrangement.mid"
VERSION_DIR = TRACK_ROOT / "versions" / "v02"
ARRANGEMENT_MIDI = VERSION_DIR / "arrangement.mid"
BUILD_REPORT = VERSION_DIR / "BUILD_REPORT.json"

EXPECTED_SOURCE_SHA256 = "ec2a476e16556cdffc69d47bf0aebf4093842e9dde8f6c32170c7da6a6149ee3"
EXPECTED_V01_MIDI_SHA256 = "342ae252fdb8012832dce8ae2a2d428f3c4b526d2460ca476c0a6138466b2f0c"

TICKS_PER_BEAT = 480
BAR_TICKS = 4 * TICKS_PER_BEAT
QPM = 66
LOOP_CROSSFADE_SECONDS = 60.0 / QPM
V01_PREVIEW_ROTATION_SECONDS = 3.627981859410431

VEILED = "Veiled Violin / Trio Cantilena"
ASHEN = "Ashen Violin / Upper Harmony"
HOLLOW = "Hollow Viola / Inner Lament"
GRAVE = "Grave Cello / Funeral Cantus"
BASS = "Undercrypt Bass / Processional Root"
PERCUSSION = "Funeral Pulse / Procedural Percussion"
TRACKS = (VEILED, ASHEN, HOLLOW, GRAVE, BASS, PERCUSSION)
CHANNELS = (0, 1, 2, 3, 4, 9)

# The familiar opening/reprise contour as realized by the v01 Funeral Cantus.
# v02 must not reproduce this exact onset/pitch sequence on any melodic track.
ICONIC_PITCHES = (58, 58, 58, 58, 54, 58, 58, 58, 58, 54)
ICONIC_ONSET_DELTAS = (480, 360, 120, 480, 480, 480, 360, 120, 480)


@dataclass(frozen=True)
class Event:
    start: int
    end: int
    pitch: int
    velocity: int
    origin: str


@dataclass(frozen=True)
class Slice:
    key: str
    label: str
    first_measure: int
    last_measure: int
    user_preview_start: str
    user_preview_end: str
    snapped_preview_start_seconds: float
    snapped_preview_end_seconds: float
    march_material: bool

    @property
    def source_start(self) -> int:
        return (self.first_measure - 1) * BAR_TICKS

    @property
    def source_end(self) -> int:
        return self.last_measure * BAR_TICKS

    @property
    def length(self) -> int:
        return self.source_end - self.source_start


SLICES = (
    Slice("A", "March reprise, inner descent", 85, 86, "5:01", "5:08", 301.8265635951, 309.0992908679, True),
    Slice("B", "March reprise, harmonic crest and fall", 93, 98, "5:29", "5:52", 330.9174726860, 352.7356545042, True),
    Slice("C", "Trio, veiled cantilena", 49, 53, "2:50", "3:09", 170.9174726860, 189.0992908679, False),
)

PRE_ROLL_TICKS = TICKS_PER_BEAT
BRIDGE_A_B_TICKS = TICKS_PER_BEAT
BRIDGE_B_C_TICKS = 2 * TICKS_PER_BEAT
LOOP_BRIDGE_TICKS = 2 * TICKS_PER_BEAT


def _read_events(path: Path) -> dict[str, list[Event]]:
    midi = mido.MidiFile(path)
    if midi.ticks_per_beat != TICKS_PER_BEAT:
        raise RuntimeError(f"Expected {TICKS_PER_BEAT} PPQ, got {midi.ticks_per_beat}")
    found: dict[str, list[Event]] = {}
    for track in midi.tracks:
        absolute_tick = 0
        track_name = ""
        active: dict[tuple[int, int], deque[tuple[int, int]]] = defaultdict(deque)
        events: list[Event] = []
        for message in track:
            absolute_tick += message.time
            if message.type == "track_name":
                track_name = message.name
            if message.type == "note_on" and message.velocity > 0:
                active[(message.channel, message.note)].append((absolute_tick, message.velocity))
                continue
            if message.type not in {"note_off", "note_on"}:
                continue
            key = (message.channel, message.note)
            if not active[key]:
                continue
            start, velocity = active[key].popleft()
            if absolute_tick > start:
                events.append(Event(start, absolute_tick, message.note, velocity, "v01"))
        if track_name in TRACKS:
            events.sort(key=lambda event: (event.start, event.pitch, event.end))
            found[track_name] = events
    if set(found) != set(TRACKS):
        raise RuntimeError(f"v01 MIDI track set drifted: {sorted(found)}")
    return found


def _source_has_pitch(
    source: dict[str, list[Event]],
    track_name: str,
    pitch: int,
    first_measure: int,
    last_measure: int,
) -> bool:
    start = (first_measure - 1) * BAR_TICKS
    end = last_measure * BAR_TICKS
    return any(event.pitch == pitch and start <= event.start < end for event in source[track_name])


def _add(
    destination: dict[str, list[Event]],
    track_name: str,
    start: int,
    duration: int,
    pitch: int,
    velocity: int,
    origin: str,
) -> None:
    destination[track_name].append(Event(start, start + duration, pitch, velocity, origin))


def _beat(value: float) -> int:
    return int(round(value * TICKS_PER_BEAT))


def _copy_slice(
    source: dict[str, list[Event]],
    destination: dict[str, list[Event]],
    selected: Slice,
    destination_start: int,
) -> dict[str, int]:
    counts: dict[str, int] = {}
    for track_name in TRACKS:
        if track_name == PERCUSSION:
            counts[track_name] = 0
            continue
        if selected.march_material and track_name in {VEILED, GRAVE}:
            counts[track_name] = 0
            continue
        velocity_scale = 0.78 if not selected.march_material else {
            ASHEN: 0.68,
            HOLLOW: 0.72,
            BASS: 0.64,
        }[track_name]
        copied = 0
        for event in source[track_name]:
            if event.end <= selected.source_start or event.start >= selected.source_end:
                continue
            clipped_start = max(event.start, selected.source_start)
            clipped_end = min(event.end, selected.source_end)
            if clipped_end <= clipped_start:
                continue
            translated_start = destination_start + clipped_start - selected.source_start
            translated_end = destination_start + clipped_end - selected.source_start
            destination[track_name].append(Event(
                translated_start,
                translated_end,
                event.pitch,
                max(1, int(round(event.velocity * velocity_scale))),
                f"slice_{selected.key}:m{selected.first_measure}-{selected.last_measure}",
            ))
            copied += 1
        counts[track_name] = copied
    return counts


def _assert_bridge_sources(source: dict[str, list[Event]]) -> None:
    required = (
        (ASHEN, 61, 85, 86), (HOLLOW, 58, 85, 86), (BASS, 34, 85, 86),
        (ASHEN, 58, 85, 86), (HOLLOW, 49, 85, 86), (BASS, 37, 85, 86),
        (ASHEN, 49, 93, 98), (HOLLOW, 56, 93, 98), (BASS, 37, 93, 98),
        (VEILED, 73, 49, 53), (BASS, 34, 49, 53),
        (VEILED, 72, 49, 53), (GRAVE, 64, 49, 53), (BASS, 42, 49, 53),
    )
    missing = [item for item in required if not _source_has_pitch(source, *item)]
    if missing:
        raise RuntimeError(f"Bridge source-pitch anchors drifted: {missing}")


def _add_pre_roll(destination: dict[str, list[Event]]) -> None:
    _add(destination, ASHEN, 0, _beat(0.80), 61, 28, "loop_overlap:incoming_A")
    _add(destination, HOLLOW, 0, _beat(0.80), 58, 26, "loop_overlap:incoming_A")
    _add(destination, BASS, 0, _beat(0.80), 34, 30, "loop_overlap:incoming_A")


def _add_bridge_a_b(destination: dict[str, list[Event]], start: int) -> None:
    _add(destination, ASHEN, start, _beat(0.72), 58, 34, "bridge_A_B:outgoing_inner_voice")
    _add(destination, HOLLOW, start, _beat(0.76), 49, 32, "bridge_A_B:outgoing_inner_voice")
    _add(destination, BASS, start, _beat(0.78), 37, 34, "bridge_A_B:outgoing_bass")
    _add(destination, PERCUSSION, start + _beat(0.75), _beat(0.10), 42, 20, "bridge_A_B:ash_breath")


def _add_bridge_b_c(destination: dict[str, list[Event]], start: int) -> None:
    _add(destination, ASHEN, start, _beat(1.75), 49, 36, "bridge_B_C:D_flat_pivot")
    _add(destination, HOLLOW, start, _beat(0.85), 56, 34, "bridge_B_C:outgoing_fifth")
    _add(destination, BASS, start, _beat(0.85), 37, 36, "bridge_B_C:outgoing_root")
    _add(destination, VEILED, start + TICKS_PER_BEAT, _beat(0.80), 73, 34, "bridge_B_C:incoming_trio_tone")
    _add(destination, BASS, start + TICKS_PER_BEAT, _beat(0.80), 34, 32, "bridge_B_C:incoming_trio_bass")
    _add(destination, PERCUSSION, start, _beat(0.14), 41, 22, "bridge_B_C:bone_pivot")


def _add_loop_bridge(destination: dict[str, list[Event]], start: int) -> None:
    _add(destination, VEILED, start, _beat(0.80), 72, 38, "loop_bridge:outgoing_trio")
    _add(destination, GRAVE, start, _beat(0.80), 64, 34, "loop_bridge:outgoing_trio")
    _add(destination, BASS, start, _beat(0.80), 42, 32, "loop_bridge:outgoing_trio")
    incoming = start + TICKS_PER_BEAT
    _add(destination, ASHEN, incoming, _beat(0.80), 61, 28, "loop_overlap:incoming_A")
    _add(destination, HOLLOW, incoming, _beat(0.80), 58, 26, "loop_overlap:incoming_A")
    _add(destination, BASS, incoming, _beat(0.80), 34, 30, "loop_overlap:incoming_A")
    _add(destination, PERCUSSION, start, _beat(0.14), 41, 20, "loop_bridge:bone_breath")


def _add_sparse_percussion(
    destination: dict[str, list[Event]],
    slice_starts: dict[str, int],
) -> None:
    a = slice_starts["A"]
    b = slice_starts["B"]
    c = slice_starts["C"]
    for start, pitch, velocity, label in (
        (a, 36, 30, "slice_A:distant_downbeat"),
        (a + _beat(7.5), 42, 18, "slice_A:ash_release"),
        (b, 36, 28, "slice_B:distant_downbeat"),
        (b + _beat(7.5), 42, 18, "slice_B:ash_breath_1"),
        (b + _beat(15.5), 42, 18, "slice_B:ash_breath_2"),
        (b + _beat(22.0), 41, 22, "slice_B:bone_cadence"),
        (c, 36, 22, "slice_C:soft_trio_entry"),
        (c + _beat(7.0), 42, 17, "slice_C:ash_breath_1"),
        (c + _beat(15.0), 42, 17, "slice_C:ash_breath_2"),
    ):
        _add(destination, PERCUSSION, start, _beat(0.14 if pitch != 42 else 0.10), pitch, velocity, label)


def _assert_monophonic(events: dict[str, list[Event]]) -> None:
    for track_name in TRACKS[:-1]:
        ordered = sorted(events[track_name], key=lambda event: (event.start, event.end, event.pitch))
        for previous, current in zip(ordered, ordered[1:]):
            if current.start < previous.end:
                raise RuntimeError(
                    f"v02 melodic overlap in {track_name}: {previous} then {current}"
                )


def _iconic_matches(events: list[Event]) -> list[int]:
    ordered = sorted(events, key=lambda event: (event.start, event.pitch, event.end))
    matches: list[int] = []
    window = len(ICONIC_PITCHES)
    for index in range(len(ordered) - window + 1):
        candidate = ordered[index:index + window]
        pitches = tuple(event.pitch for event in candidate)
        deltas = tuple(candidate[offset + 1].start - candidate[offset].start for offset in range(window - 1))
        if pitches == ICONIC_PITCHES and deltas == ICONIC_ONSET_DELTAS:
            matches.append(candidate[0].start)
    return matches


def _build_events(source: dict[str, list[Event]]) -> tuple[dict[str, list[Event]], dict[str, object], int]:
    _assert_bridge_sources(source)
    destination: dict[str, list[Event]] = defaultdict(list)
    _add_pre_roll(destination)
    cursor = PRE_ROLL_TICKS
    slice_starts: dict[str, int] = {}
    copied: dict[str, dict[str, int]] = {}

    slice_starts["A"] = cursor
    copied["A"] = _copy_slice(source, destination, SLICES[0], cursor)
    cursor += SLICES[0].length
    bridge_a_b_start = cursor
    _add_bridge_a_b(destination, cursor)
    cursor += BRIDGE_A_B_TICKS

    slice_starts["B"] = cursor
    copied["B"] = _copy_slice(source, destination, SLICES[1], cursor)
    cursor += SLICES[1].length
    bridge_b_c_start = cursor
    _add_bridge_b_c(destination, cursor)
    cursor += BRIDGE_B_C_TICKS

    slice_starts["C"] = cursor
    copied["C"] = _copy_slice(source, destination, SLICES[2], cursor)
    cursor += SLICES[2].length
    loop_bridge_start = cursor
    _add_loop_bridge(destination, cursor)
    cursor += LOOP_BRIDGE_TICKS
    _add_sparse_percussion(destination, slice_starts)

    for track_name in TRACKS:
        destination[track_name].sort(key=lambda event: (event.start, event.pitch, event.end))
    _assert_monophonic(destination)

    for selected in SLICES[:2]:
        start = slice_starts[selected.key]
        end = start + selected.length
        for track_name in (VEILED, GRAVE):
            leaked = [event for event in destination[track_name] if start <= event.start < end]
            if leaked:
                raise RuntimeError(f"Main melody leaked into march slice {selected.key}: {track_name} {leaked}")

    iconic_matches = {
        track_name: _iconic_matches(destination[track_name])
        for track_name in TRACKS[:-1]
    }
    if any(iconic_matches.values()):
        raise RuntimeError(f"Iconic opening signature survived v02: {iconic_matches}")

    removed_main_melody = {
        selected.key: {
            track_name: sum(
                event.end > selected.source_start and event.start < selected.source_end
                for event in source[track_name]
            )
            for track_name in (VEILED, GRAVE)
        }
        for selected in SLICES[:2]
    }
    structure = {
        "pre_roll": {"start_tick": 0, "end_tick": PRE_ROLL_TICKS},
        "slice_starts": slice_starts,
        "bridge_A_B": {"start_tick": bridge_a_b_start, "end_tick": bridge_a_b_start + BRIDGE_A_B_TICKS},
        "bridge_B_C": {"start_tick": bridge_b_c_start, "end_tick": bridge_b_c_start + BRIDGE_B_C_TICKS},
        "loop_bridge": {"start_tick": loop_bridge_start, "end_tick": loop_bridge_start + LOOP_BRIDGE_TICKS},
        "copied_note_counts": copied,
        "removed_main_melody_note_counts": removed_main_melody,
        "iconic_signature_matches": iconic_matches,
    }
    return destination, structure, cursor


def _write_midi(events: dict[str, list[Event]], structure: dict[str, object], total_ticks: int) -> dict[str, int]:
    VERSION_DIR.mkdir(parents=True, exist_ok=True)
    midi = mido.MidiFile(type=1, ticks_per_beat=TICKS_PER_BEAT)
    conductor = mido.MidiTrack()
    conductor.append(mido.MetaMessage("track_name", name="Conductor", time=0))
    conductor.append(mido.MetaMessage("time_signature", numerator=4, denominator=4, time=0))
    conductor.append(mido.MetaMessage("key_signature", key="Bbm", time=0))
    conductor.append(mido.MetaMessage("set_tempo", tempo=mido.bpm2tempo(QPM), time=0))
    markers = (
        (0, "Loop overlap pre-roll"),
        (structure["slice_starts"]["A"], "A: source m85-86, main melody removed"),
        (structure["bridge_A_B"]["start_tick"], "Bridge A to B"),
        (structure["slice_starts"]["B"], "B: source m93-98, main melody removed"),
        (structure["bridge_B_C"]["start_tick"], "Bridge B to C"),
        (structure["slice_starts"]["C"], "C: source m49-53 Trio"),
        (structure["loop_bridge"]["start_tick"], "Loop bridge C to A"),
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
        scheduled: list[tuple[int, int, mido.Message]] = []
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
    config = read_json(CONFIG_PATH)
    verify_source_clearance(config, CONFIG_PATH)
    if config.get("approval", {}).get("status") != "audition":
        raise RuntimeError("v02 builder is only for an unapproved audition")
    if config.get("arrangement", {}).get("version") != "v02":
        raise RuntimeError("v02 config version drifted")
    configured_crossfade = float(config.get("render", {}).get("crossfade_seconds", -1.0))
    if abs(configured_crossfade - LOOP_CROSSFADE_SECONDS) > 1e-12:
        raise RuntimeError("v02 loop crossfade drifted from the one-beat overlap")

    source = _read_events(V01_MIDI)
    events, structure, total_ticks = _build_events(source)
    note_counts = _write_midi(events, structure, total_ticks)
    if any(count <= 0 for count in note_counts.values()):
        raise RuntimeError(f"Every configured v02 track must contain notes: {note_counts}")

    slices_report = []
    for selected in SLICES:
        slices_report.append({
            "key": selected.key,
            "label": selected.label,
            "user_v01_preview_range": [selected.user_preview_start, selected.user_preview_end],
            "snapped_v01_preview_seconds": [selected.snapped_preview_start_seconds, selected.snapped_preview_end_seconds],
            "source_measures_inclusive": [selected.first_measure, selected.last_measure],
            "source_ticks": [selected.source_start, selected.source_end],
            "march_main_melody_removed": selected.march_material,
        })
    report = {
        "ok": True,
        "version": "v02",
        "source_midi_sha256": sha256(SOURCE_MIDI),
        "v01_arrangement_midi_sha256": sha256(V01_MIDI),
        "v01_preview_rotation_seconds": V01_PREVIEW_ROTATION_SECONDS,
        "slices_in_order": slices_report,
        "structure": structure,
        "bridge_pitch_policy": "Every bridge pitch is asserted in an adjacent selected source window; no pitch is transposed or newly harmonized.",
        "motif_policy": "Veiled Violin and Grave Cello are absent throughout march slices A and B; the exact v01 iconic opening onset/pitch signature is absent from every melodic track.",
        "arrangement_midi": str(ARRANGEMENT_MIDI),
        "arrangement_midi_sha256": sha256(ARRANGEMENT_MIDI),
        "arrangement_note_counts": note_counts,
        "tempo_qpm": QPM,
        "total_ticks": total_ticks,
        "structural_duration_seconds": total_ticks / TICKS_PER_BEAT * 60.0 / QPM,
        "loop_crossfade_seconds": LOOP_CROSSFADE_SECONDS,
        "audible_loop_duration_seconds": total_ticks / TICKS_PER_BEAT * 60.0 / QPM - LOOP_CROSSFADE_SECONDS,
        "harmony_changes": "none",
        "transpositions": "none",
    }
    write_json(BUILD_REPORT, report)
    print(json.dumps(report, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
