#!/usr/bin/env python3
"""Build v03: restored melodic crest, stripped march valley, then Trio."""

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


CONFIG_PATH = TRACK_ROOT / "track.v03.json"
SOURCE_MIDI = TRACK_ROOT / "source" / "chopin_piano_sonata_no2_op35_pdmx_cc0.mid"
V01_MIDI = TRACK_ROOT / "versions" / "v01" / "arrangement.mid"
V02_BUILDER = TRACK_ROOT / "scripts" / "build_arrangement_v02.py"
VERSION_DIR = TRACK_ROOT / "versions" / "v03"
ARRANGEMENT_MIDI = VERSION_DIR / "arrangement.mid"
BUILD_REPORT = VERSION_DIR / "BUILD_REPORT.json"

EXPECTED_SOURCE_SHA256 = "ec2a476e16556cdffc69d47bf0aebf4093842e9dde8f6c32170c7da6a6149ee3"
EXPECTED_V01_MIDI_SHA256 = "342ae252fdb8012832dce8ae2a2d428f3c4b526d2460ca476c0a6138466b2f0c"
EXPECTED_V02_BUILDER_SHA256 = "0b2a9dc641ccde4b4e11fc2886ab2239a5eae2d0304412b3c4bfab0ec520431c"


def _load_v02_builder():
    spec = importlib.util.spec_from_file_location("_chopin_v02_builder", V02_BUILDER)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"Could not load shared Chopin builder helpers from {V02_BUILDER}")
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


V02 = _load_v02_builder()

TICKS_PER_BEAT = V02.TICKS_PER_BEAT
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
SLICE_A = V02.SLICES[0]  # source measures 85-86
SLICE_B = V02.SLICES[1]  # source measures 93-98
SLICE_C = V02.SLICES[2]  # source measures 49-53

PRE_ROLL_TICKS = TICKS_PER_BEAT
BRIDGE_B_A_TICKS = 2 * TICKS_PER_BEAT
BRIDGE_A_C_TICKS = 2 * TICKS_PER_BEAT
LOOP_BRIDGE_TICKS = 2 * TICKS_PER_BEAT


def _copy_slice(
    source,
    destination,
    selected,
    destination_start: int,
    velocity_scales: dict[str, float],
    suppressed_tracks: set[str],
) -> dict[str, int]:
    counts: dict[str, int] = {}
    for track_name in TRACKS:
        if track_name == PERCUSSION or track_name in suppressed_tracks:
            counts[track_name] = 0
            continue
        scale = velocity_scales.get(track_name, 1.0)
        copied = 0
        for event in source[track_name]:
            if event.end <= selected.source_start or event.start >= selected.source_end:
                continue
            clipped_start = max(event.start, selected.source_start)
            clipped_end = min(event.end, selected.source_end)
            if clipped_end <= clipped_start:
                continue
            destination[track_name].append(V02.Event(
                destination_start + clipped_start - selected.source_start,
                destination_start + clipped_end - selected.source_start,
                event.pitch,
                max(1, int(round(event.velocity * scale))),
                f"slice_{selected.key}:m{selected.first_measure}-{selected.last_measure}",
            ))
            copied += 1
        counts[track_name] = copied
    return counts


def _require_bridge_pitches(source) -> None:
    required = (
        # Restored B opening and outgoing cadence.
        (GRAVE, 73, 93, 98), (ASHEN, 65, 93, 98), (HOLLOW, 61, 93, 98), (BASS, 25, 93, 98),
        (GRAVE, 58, 93, 98), (ASHEN, 49, 93, 98), (HOLLOW, 56, 93, 98), (BASS, 37, 93, 98),
        # Stripped A opening and outgoing inner sonority.
        (ASHEN, 61, 85, 86), (HOLLOW, 58, 85, 86), (BASS, 34, 85, 86),
        (ASHEN, 58, 85, 86), (HOLLOW, 49, 85, 86), (BASS, 37, 85, 86),
        # Trio pickup and loop-out tones.
        (VEILED, 73, 49, 53), (BASS, 34, 49, 53),
        (VEILED, 72, 49, 53), (GRAVE, 64, 49, 53), (BASS, 42, 49, 53),
    )
    missing = [item for item in required if not V02._source_has_pitch(source, *item)]
    if missing:
        raise RuntimeError(f"v03 bridge source-pitch anchors drifted: {missing}")


def _add_pre_roll(destination) -> None:
    V02._add(destination, GRAVE, 0, V02._beat(0.80), 73, 30, "loop_overlap:incoming_B")
    V02._add(destination, ASHEN, 0, V02._beat(0.80), 65, 27, "loop_overlap:incoming_B")
    V02._add(destination, HOLLOW, 0, V02._beat(0.80), 61, 25, "loop_overlap:incoming_B")
    V02._add(destination, BASS, 0, V02._beat(0.80), 25, 28, "loop_overlap:incoming_B")


def _add_bridge_b_a(destination, start: int) -> None:
    # Let the restored B melody complete before the texture thins into A.
    V02._add(destination, GRAVE, start, V02._beat(0.82), 58, 42, "bridge_B_A:lead_release")
    V02._add(destination, ASHEN, start, V02._beat(0.82), 49, 36, "bridge_B_A:outgoing_inner_voice")
    V02._add(destination, HOLLOW, start, V02._beat(0.82), 56, 34, "bridge_B_A:outgoing_inner_voice")
    V02._add(destination, BASS, start, V02._beat(0.82), 37, 35, "bridge_B_A:outgoing_bass")
    incoming = start + TICKS_PER_BEAT
    V02._add(destination, ASHEN, incoming, V02._beat(0.82), 61, 32, "bridge_B_A:incoming_A")
    V02._add(destination, HOLLOW, incoming, V02._beat(0.82), 58, 31, "bridge_B_A:incoming_A")
    V02._add(destination, BASS, incoming, V02._beat(0.82), 34, 33, "bridge_B_A:incoming_A")
    V02._add(destination, PERCUSSION, start + V02._beat(0.75), V02._beat(0.10), 42, 17, "bridge_B_A:ash_breath")


def _add_bridge_a_c(destination, start: int) -> None:
    # Hold A's D-flat inner color, then disclose the Trio melody as a pickup.
    V02._add(destination, ASHEN, start, V02._beat(0.82), 58, 33, "bridge_A_C:outgoing_inner_voice")
    V02._add(destination, HOLLOW, start, V02._beat(1.78), 49, 33, "bridge_A_C:D_flat_common_tone")
    V02._add(destination, BASS, start, V02._beat(0.82), 37, 34, "bridge_A_C:outgoing_bass")
    incoming = start + TICKS_PER_BEAT
    V02._add(destination, VEILED, incoming, V02._beat(0.78), 73, 32, "bridge_A_C:incoming_trio_tone")
    V02._add(destination, BASS, incoming, V02._beat(0.78), 34, 31, "bridge_A_C:incoming_trio_bass")
    V02._add(destination, PERCUSSION, start + V02._beat(1.70), V02._beat(0.10), 42, 16, "bridge_A_C:ash_pickup")


def _add_loop_bridge(destination, start: int) -> None:
    V02._add(destination, VEILED, start, V02._beat(0.80), 72, 36, "loop_bridge:outgoing_trio")
    V02._add(destination, GRAVE, start, V02._beat(0.80), 64, 33, "loop_bridge:outgoing_trio")
    V02._add(destination, BASS, start, V02._beat(0.80), 42, 31, "loop_bridge:outgoing_trio")
    incoming = start + TICKS_PER_BEAT
    V02._add(destination, GRAVE, incoming, V02._beat(0.80), 73, 30, "loop_overlap:incoming_B")
    V02._add(destination, ASHEN, incoming, V02._beat(0.80), 65, 27, "loop_overlap:incoming_B")
    V02._add(destination, HOLLOW, incoming, V02._beat(0.80), 61, 25, "loop_overlap:incoming_B")
    V02._add(destination, BASS, incoming, V02._beat(0.80), 25, 28, "loop_overlap:incoming_B")
    V02._add(destination, PERCUSSION, start, V02._beat(0.14), 41, 18, "loop_bridge:bone_breath")


def _add_sparse_percussion(destination, starts: dict[str, int]) -> None:
    b = starts["B"]
    a = starts["A"]
    c = starts["C"]
    for start, pitch, velocity, label in (
        (b, 36, 24, "slice_B:soft_death_downbeat"),
        (b + V02._beat(7.5), 42, 16, "slice_B:ash_breath_1"),
        (b + V02._beat(15.5), 42, 16, "slice_B:ash_breath_2"),
        (b + V02._beat(22.0), 41, 19, "slice_B:bone_cadence"),
        (a + V02._beat(7.5), 42, 15, "slice_A:ash_release"),
        (c, 36, 19, "slice_C:soft_trio_entry"),
        (c + V02._beat(7.0), 42, 15, "slice_C:ash_breath_1"),
        (c + V02._beat(15.0), 42, 15, "slice_C:ash_breath_2"),
    ):
        duration = V02._beat(0.10 if pitch == 42 else 0.14)
        V02._add(destination, PERCUSSION, start, duration, pitch, velocity, label)


def _build_events(source):
    _require_bridge_pitches(source)
    destination = defaultdict(list)
    _add_pre_roll(destination)
    cursor = PRE_ROLL_TICKS
    starts: dict[str, int] = {}
    copied: dict[str, dict[str, int]] = {}

    starts["B"] = cursor
    copied["B"] = _copy_slice(
        source,
        destination,
        SLICE_B,
        cursor,
        {GRAVE: 0.82, ASHEN: 0.84, HOLLOW: 0.82, BASS: 0.76},
        {VEILED},
    )
    cursor += SLICE_B.length
    bridge_b_a_start = cursor
    _add_bridge_b_a(destination, cursor)
    cursor += BRIDGE_B_A_TICKS

    starts["A"] = cursor
    copied["A"] = _copy_slice(
        source,
        destination,
        SLICE_A,
        cursor,
        {ASHEN: 0.68, HOLLOW: 0.72, BASS: 0.64},
        {VEILED, GRAVE},
    )
    cursor += SLICE_A.length
    bridge_a_c_start = cursor
    _add_bridge_a_c(destination, cursor)
    cursor += BRIDGE_A_C_TICKS

    starts["C"] = cursor
    copied["C"] = _copy_slice(
        source,
        destination,
        SLICE_C,
        cursor,
        {VEILED: 0.78, ASHEN: 0.78, HOLLOW: 0.78, GRAVE: 0.78, BASS: 0.78},
        set(),
    )
    cursor += SLICE_C.length
    loop_bridge_start = cursor
    _add_loop_bridge(destination, cursor)
    cursor += LOOP_BRIDGE_TICKS
    _add_sparse_percussion(destination, starts)

    for track_name in TRACKS:
        destination[track_name].sort(key=lambda event: (event.start, event.pitch, event.end))
    V02._assert_monophonic(destination)

    # B restores every source lead onset but not the doubled top voice.
    b_start = starts["B"]
    b_end = b_start + SLICE_B.length
    source_b_grave = sum(
        event.end > SLICE_B.source_start and event.start < SLICE_B.source_end
        for event in source[GRAVE]
    )
    restored_b_grave = sum(b_start <= event.start < b_end for event in destination[GRAVE])
    if restored_b_grave != source_b_grave or copied["B"][GRAVE] != source_b_grave:
        raise RuntimeError(
            f"B lead restoration drifted: source={source_b_grave}, copied={copied['B'][GRAVE]}, output={restored_b_grave}"
        )
    if any(b_start <= event.start < b_end for event in destination[VEILED]):
        raise RuntimeError("Veiled Violin double leaked into restored B")

    # A remains the deliberately stripped connective march passage.
    a_start = starts["A"]
    a_end = a_start + SLICE_A.length
    for track_name in (VEILED, GRAVE):
        if any(a_start <= event.start < a_end for event in destination[track_name]):
            raise RuntimeError(f"Main melody leaked into stripped A: {track_name}")

    iconic_matches = {
        track_name: V02._iconic_matches(destination[track_name])
        for track_name in TRACKS[:-1]
    }
    if any(iconic_matches.values()):
        raise RuntimeError(f"Iconic opening signature survived v03: {iconic_matches}")

    structure = {
        "pre_roll": {"start_tick": 0, "end_tick": PRE_ROLL_TICKS},
        "slice_starts": starts,
        "bridge_B_A": {"start_tick": bridge_b_a_start, "end_tick": bridge_b_a_start + BRIDGE_B_A_TICKS},
        "bridge_A_C": {"start_tick": bridge_a_c_start, "end_tick": bridge_a_c_start + BRIDGE_A_C_TICKS},
        "loop_bridge": {"start_tick": loop_bridge_start, "end_tick": loop_bridge_start + LOOP_BRIDGE_TICKS},
        "copied_note_counts": copied,
        "restored_B_grave_lead_note_count": restored_b_grave,
        "suppressed_B_veiled_double_note_count": sum(
            event.end > SLICE_B.source_start and event.start < SLICE_B.source_end
            for event in source[VEILED]
        ),
        "suppressed_A_main_melody_note_counts": {
            track_name: sum(
                event.end > SLICE_A.source_start and event.start < SLICE_A.source_end
                for event in source[track_name]
            )
            for track_name in (VEILED, GRAVE)
        },
        "iconic_signature_matches": iconic_matches,
    }
    return destination, structure, cursor


def _write_midi(events, structure: dict[str, object], total_ticks: int) -> dict[str, int]:
    VERSION_DIR.mkdir(parents=True, exist_ok=True)
    midi = mido.MidiFile(type=1, ticks_per_beat=TICKS_PER_BEAT)
    conductor = mido.MidiTrack()
    conductor.append(mido.MetaMessage("track_name", name="Conductor", time=0))
    conductor.append(mido.MetaMessage("time_signature", numerator=4, denominator=4, time=0))
    conductor.append(mido.MetaMessage("key_signature", key="Bbm", time=0))
    conductor.append(mido.MetaMessage("set_tempo", tempo=mido.bpm2tempo(QPM), time=0))
    markers = (
        (0, "Loop overlap pre-roll"),
        (structure["slice_starts"]["B"], "B: source m93-98, Grave melody restored"),
        (structure["bridge_B_A"]["start_tick"], "Bridge B to A"),
        (structure["slice_starts"]["A"], "A: source m85-86, main melody removed"),
        (structure["bridge_A_C"]["start_tick"], "Bridge A to C"),
        (structure["slice_starts"]["C"], "C: source m49-53 Trio"),
        (structure["loop_bridge"]["start_tick"], "Loop bridge C to B"),
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
        raise RuntimeError("v03 builder is only for an unapproved audition")
    if config.get("arrangement", {}).get("version") != "v03":
        raise RuntimeError("v03 config version drifted")
    if abs(float(config["render"]["crossfade_seconds"]) - LOOP_CROSSFADE_SECONDS) > 1e-12:
        raise RuntimeError("v03 loop crossfade drifted from the one-beat overlap")

    source = V02._read_events(V01_MIDI)
    events, structure, total_ticks = _build_events(source)
    note_counts = _write_midi(events, structure, total_ticks)
    if any(count <= 0 for count in note_counts.values()):
        raise RuntimeError(f"Every configured v03 track must contain notes: {note_counts}")

    report = {
        "ok": True,
        "version": "v03",
        "source_midi_sha256": sha256(SOURCE_MIDI),
        "v01_arrangement_midi_sha256": sha256(V01_MIDI),
        "v02_helper_builder_sha256": sha256(V02_BUILDER),
        "slices_in_order": [
            {"key": "B", "source_measures_inclusive": [93, 98], "role": "opening melodic crest", "grave_lead": "restored", "veiled_double": "suppressed"},
            {"key": "A", "source_measures_inclusive": [85, 86], "role": "stripped connective valley", "grave_lead": "suppressed", "veiled_double": "suppressed"},
            {"key": "C", "source_measures_inclusive": [49, 53], "role": "Trio release", "grave_lead": "source Trio arpeggiation retained", "veiled_double": "source Trio melody retained"},
        ],
        "structure": structure,
        "bridge_pitch_policy": "Every bridge pitch is asserted in an adjacent selected source window; B-to-A restores then releases the lead, and A-to-C holds a D-flat common tone before the Trio pickup.",
        "motif_policy": "B restores its non-iconic Grave Cello melody but omits the Veiled double; A omits both lead carriers; the exact v01 iconic opening/reprise signature is absent from every melodic track.",
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
