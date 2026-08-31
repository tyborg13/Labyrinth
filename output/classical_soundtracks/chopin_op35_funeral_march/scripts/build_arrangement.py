#!/usr/bin/env python3
"""Build the source-faithful Chopin Funeral March v01 retro audition."""

from __future__ import annotations

from collections import defaultdict, deque
from dataclasses import dataclass
import json
from pathlib import Path
import re
import sys

import mido
from music21 import bar, clef, key, metadata, meter, note, stream, tempo


TRACK_ROOT = Path(__file__).resolve().parents[1]
REPO_ROOT = TRACK_ROOT.parents[2]
sys.path.insert(0, str(REPO_ROOT))

from tools.classical_soundtrack_pipeline.common import (  # noqa: E402
    read_json,
    sha256,
    verify_source_clearance,
    write_json,
)
from tools.classical_soundtrack_pipeline.normalization import write_normalized_score  # noqa: E402


SOURCE_MIDI = TRACK_ROOT / "source" / "chopin_piano_sonata_no2_op35_pdmx_cc0.mid"
SOURCE_PDF = TRACK_ROOT / "source" / "chopin_op35_breitkopf_1878_public_domain.pdf"
PDMX_RECORD = TRACK_ROOT / "source" / "PDMX_RECORD.json"
CONFIG_PATH = TRACK_ROOT / "track.json"
NORMALIZED_DIR = TRACK_ROOT / "normalized"
VERSION_DIR = TRACK_ROOT / "versions" / "v01"
ARRANGEMENT_MIDI = VERSION_DIR / "arrangement.mid"
BUILD_REPORT = VERSION_DIR / "BUILD_REPORT.json"

EXPECTED_SOURCE_SHA256 = "ec2a476e16556cdffc69d47bf0aebf4093842e9dde8f6c32170c7da6a6149ee3"
EXPECTED_REFERENCE_SHA256 = "ec325b07ca4a8514681011fcd1265edcfe98c23d4e524a56fd743bc212b02abe"
EXPECTED_INDEX_SHA256 = "fc2187e7e09185f4b28be57b6478a96a1243a037f8fd13624f17de2d8bfd44bd"
EXPECTED_ARCHIVE_SHA256 = "e444f9b466f02c9a054d31478c9886847f39c575a65ec45a0aaa1a5ee088c1d1"

TICKS_PER_BEAT = 480
BAR_TICKS = 4 * TICKS_PER_BEAT
MOVEMENT_START_TICK = 1_124_160
MOVEMENT_END_TICK = 1_331_520
MOVEMENT_TICKS = MOVEMENT_END_TICK - MOVEMENT_START_TICK
MEASURE_COUNT = 108
TRIO_FIRST_MEASURE = 33
REPRISE_FIRST_MEASURE = 79
QPM = 66
SOURCE_FINAL_RITARD_TICK = 1_330_560
NORMALIZED_SCORE_GRID_TICKS = 30  # 1/64 note at 480 PPQ
RENDER_SAMPLE_RATE = 44_100
LOOP_CROSSFADE_SAMPLES = 159_994
LOOP_CROSSFADE_SECONDS = LOOP_CROSSFADE_SAMPLES / RENDER_SAMPLE_RATE

TRACKS = (
    "Veiled Violin / Trio Cantilena",
    "Ashen Violin / Upper Harmony",
    "Hollow Viola / Inner Lament",
    "Grave Cello / Funeral Cantus",
    "Undercrypt Bass / Processional Root",
    "Funeral Pulse / Procedural Percussion",
)

GATE_SCALES = {
    TRACKS[0]: 0.92,
    TRACKS[1]: 0.90,
    TRACKS[2]: 0.94,
    TRACKS[3]: 0.98,
    TRACKS[4]: 0.96,
}

MARCH_GLOW_MEASURES = frozenset(
    list(range(13, 21))
    + list(range(25, 29))
    + list(range(89, 97))
    + list(range(101, 105))
)


@dataclass(frozen=True)
class SourceEvent:
    start: int
    end: int
    pitch: int
    velocity: int
    hand: str


@dataclass(frozen=True)
class ArrangementEvent:
    start: int
    end: int
    pitch: int
    velocity: int
    priority: int = 0


def _extract_source_events(midi: mido.MidiFile, track_index: int, hand: str) -> list[SourceEvent]:
    active: dict[tuple[int, int], deque[tuple[int, int]]] = defaultdict(deque)
    events: list[SourceEvent] = []
    absolute_tick = 0
    for message in midi.tracks[track_index]:
        absolute_tick += message.time
        if message.type == "note_on" and message.velocity > 0:
            active[(message.channel, message.note)].append((absolute_tick, message.velocity))
            continue
        if message.type not in {"note_off", "note_on"}:
            continue
        key_value = (message.channel, message.note)
        if not active[key_value]:
            continue
        source_start, velocity = active[key_value].popleft()
        source_end = absolute_tick
        if source_end <= MOVEMENT_START_TICK or source_start >= MOVEMENT_END_TICK:
            continue
        clipped_start = max(source_start, MOVEMENT_START_TICK)
        clipped_end = min(source_end, MOVEMENT_END_TICK)
        if clipped_end > clipped_start:
            events.append(SourceEvent(
                start=clipped_start - MOVEMENT_START_TICK,
                end=clipped_end - MOVEMENT_START_TICK,
                pitch=message.note,
                velocity=velocity,
                hand=hand,
            ))
    events.sort(key=lambda event: (event.start, event.pitch, event.end, event.velocity))
    return events


def _meta_events(midi: mido.MidiFile) -> list[tuple[int, mido.MetaMessage]]:
    found: list[tuple[int, mido.MetaMessage]] = []
    for track in midi.tracks:
        absolute_tick = 0
        for message in track:
            absolute_tick += message.time
            if message.is_meta:
                found.append((absolute_tick, message))
    return found


def _assert_source_boundaries(midi: mido.MidiFile) -> dict[str, object]:
    if midi.ticks_per_beat != TICKS_PER_BEAT:
        raise RuntimeError(f"Expected {TICKS_PER_BEAT} source ticks per beat, got {midi.ticks_per_beat}")
    found = _meta_events(midi)
    at_start = [message for tick, message in found if tick == MOVEMENT_START_TICK]
    at_end = [message for tick, message in found if tick == MOVEMENT_END_TICK]
    if not any(message.type == "time_signature" and message.numerator == 4 and message.denominator == 4 for message in at_start):
        raise RuntimeError("Movement III start no longer has the expected 4/4 signature")
    if not any(message.type == "key_signature" and message.key == "Db" for message in at_start):
        raise RuntimeError("Movement III start no longer has the expected five-flat key signature")
    if not any(message.type == "set_tempo" and message.tempo == 1_000_000 for message in at_start):
        raise RuntimeError("Movement III start no longer has the expected 60 QPM source tempo")
    if not any(message.type == "time_signature" and message.numerator == 12 and message.denominator == 8 for message in at_end):
        raise RuntimeError("Movement IV boundary no longer has the expected 12/8 signature")
    if MOVEMENT_TICKS != MEASURE_COUNT * BAR_TICKS:
        raise RuntimeError("Movement boundary is not exactly 108 complete 4/4 measures")
    return {
        "start_tick": MOVEMENT_START_TICK,
        "end_tick_exclusive": MOVEMENT_END_TICK,
        "ticks": MOVEMENT_TICKS,
        "quarter_notes": MOVEMENT_TICKS / TICKS_PER_BEAT,
        "measures_4_4": MEASURE_COUNT,
        "source_tempo_qpm": 60,
        "next_movement_time_signature": "12/8",
    }


def _group_by_start(events: list[SourceEvent]) -> dict[int, list[SourceEvent]]:
    grouped: dict[int, dict[int, SourceEvent]] = defaultdict(dict)
    for event in events:
        previous = grouped[event.start].get(event.pitch)
        if previous is None or (event.end, event.velocity) > (previous.end, previous.velocity):
            grouped[event.start][event.pitch] = event
    return {
        start: sorted(by_pitch.values(), key=lambda event: event.pitch, reverse=True)
        for start, by_pitch in grouped.items()
    }


def _measure_signature(events: list[SourceEvent], measure_number: int) -> tuple[tuple[str, int, int], ...]:
    start = (measure_number - 1) * BAR_TICKS
    end = start + BAR_TICKS
    return tuple(
        sorted(
            (event.hand, event.start - start, event.pitch)
            for event in events
            if start <= event.start < end
        )
    )


def _assert_source_events(right: list[SourceEvent], left: list[SourceEvent]) -> dict[str, object]:
    # PDMX also contains 4 right-hand and 40 left-hand zero-duration note-on/
    # note-off pairs in this movement. They have no sounded duration, so the
    # normalized score deliberately omits them and asserts the musical counts.
    if len(right) != 1_058 or len(left) != 1_165:
        raise RuntimeError(f"Source movement note counts drifted: right={len(right)}, left={len(left)}")
    right_range = (min(event.pitch for event in right), max(event.pitch for event in right))
    left_range = (min(event.pitch for event in left), max(event.pitch for event in left))
    if right_range != (49, 89) or left_range != (25, 72):
        raise RuntimeError(f"Source movement pitch ranges drifted: right={right_range}, left={left_range}")
    right_starts = _group_by_start(right)
    left_starts = _group_by_start(left)
    if [event.pitch for event in right_starts[0]] != [58, 53]:
        raise RuntimeError("Opening right-hand sonority drifted")
    if [event.pitch for event in left_starts[0]] != [46, 41, 34]:
        raise RuntimeError("Opening left-hand sonority drifted")
    trio_tick = (TRIO_FIRST_MEASURE - 1) * BAR_TICKS
    if 78 not in {event.pitch for event in right_starts[trio_tick]} or 32 not in {event.pitch for event in left_starts[trio_tick]}:
        raise RuntimeError("Trio-entry anchor drifted")
    combined = right + left
    for offset in range(15):
        if _measure_signature(combined, 1 + offset) != _measure_signature(combined, REPRISE_FIRST_MEASURE + offset):
            raise RuntimeError(f"Expected opening/reprise identity drifted at offset measure {offset + 1}")
    return {
        "right_hand_note_count": len(right),
        "left_hand_note_count": len(left),
        "omitted_zero_duration_source_events": {"right_hand": 4, "left_hand": 40},
        "right_hand_pitch_range": list(right_range),
        "left_hand_pitch_range": list(left_range),
        "opening_right_hand_pitches": [58, 53],
        "opening_left_hand_pitches": [46, 41, 34],
        "trio_first_measure": TRIO_FIRST_MEASURE,
        "reprise_first_measure": REPRISE_FIRST_MEASURE,
        "opening_reprise_exact_measure_count": 15,
        "normalized_score_duration_grid_ticks": NORMALIZED_SCORE_GRID_TICKS,
        "normalized_score_max_duration_snap_error_ticks": NORMALIZED_SCORE_GRID_TICKS // 2,
    }


def _source_part(events: list[SourceEvent], part_id: str, part_name: str, part_clef: clef.Clef, include_tempo: bool) -> stream.Part:
    part = stream.Part(id=part_id)
    part.partName = part_name
    part.insert(0, part_clef)
    part.insert(0, key.KeySignature(-5))
    part.insert(0, meter.TimeSignature("4/4"))
    if include_tempo:
        part.insert(0, tempo.MetronomeMark(number=60))
        part.insert((SOURCE_FINAL_RITARD_TICK - MOVEMENT_START_TICK) / TICKS_PER_BEAT, tempo.MetronomeMark(number=20))
    for event in events:
        # The performed source carries small release offsets (for example 29,
        # 119, or 479 ticks) around a 30-tick notation grid. Snap duration only
        # for the human-readable normalized MusicXML; the arrangement continues
        # to derive from the exact source events above.
        duration_ticks = max(
            NORMALIZED_SCORE_GRID_TICKS,
            int(round((event.end - event.start) / NORMALIZED_SCORE_GRID_TICKS))
            * NORMALIZED_SCORE_GRID_TICKS,
        )
        value = note.Note(event.pitch, quarterLength=duration_ticks / TICKS_PER_BEAT)
        value.volume.velocity = event.velocity
        part.insert(event.start / TICKS_PER_BEAT, value)
    part.makeMeasures(inPlace=True)
    part.makeTies(inPlace=True)
    measures = list(part.getElementsByClass(stream.Measure))
    if len(measures) != MEASURE_COUNT:
        raise RuntimeError(f"Expected {MEASURE_COUNT} normalized measures for {part_name}, got {len(measures)}")
    measures[-1].rightBarline = bar.Barline("final")
    return part


def _normalized_source_score(right: list[SourceEvent], left: list[SourceEvent]) -> stream.Score:
    score = stream.Score(id="chopin_op35_movement_iii_normalized_source")
    score.metadata = metadata.Metadata()
    score.metadata.title = "Piano Sonata No. 2 in B-flat minor, Op. 35 — III. Marche funèbre"
    score.metadata.composer = "Frédéric Chopin"
    score.insert(0, _source_part(
        right,
        "piano_right_hand_source_midi_track",
        "Piano — Right-hand source MIDI track",
        clef.TrebleClef(),
        True,
    ))
    score.insert(0, _source_part(
        left,
        "piano_left_hand_source_midi_track",
        "Piano — Left-hand source MIDI track",
        clef.BassClef(),
        False,
    ))
    return score


def _stabilize_musicxml_ids(report: dict[str, object]) -> None:
    xml_paths = [Path(str(report["full_score_musicxml"]))]
    xml_paths.extend(Path(str(part_report["musicxml_path"])) for part_report in report["parts"])
    for xml_path in xml_paths:
        text = xml_path.read_text(encoding="utf-8")
        generated_ids = re.findall(r'<score-part id="([^"]+)">', text)
        if not generated_ids:
            raise RuntimeError(f"No generated MusicXML part ids found in {xml_path}")
        for index, generated_id in enumerate(generated_ids, start=1):
            text = text.replace(f'id="{generated_id}"', f'id="P{index}"')
        xml_path.write_text(text, encoding="utf-8")
    report["full_score_musicxml_sha256"] = sha256(Path(str(report["full_score_musicxml"])))
    for part_report in report["parts"]:
        part_report["musicxml_sha256"] = sha256(Path(str(part_report["musicxml_path"])))


def _velocity(source_velocity: int, base: int, minimum: int, maximum: int) -> int:
    return max(minimum, min(maximum, int(round(base + (source_velocity - 49) * 0.42))))


def _add_candidate(
    candidates: dict[str, dict[int, ArrangementEvent]],
    track_name: str,
    source: SourceEvent,
    velocity: int,
    priority: int,
) -> None:
    candidate = ArrangementEvent(source.start, source.end, source.pitch, velocity, priority)
    previous = candidates[track_name].get(candidate.start)
    if previous is None or (candidate.priority, candidate.velocity, candidate.pitch) > (previous.priority, previous.velocity, previous.pitch):
        candidates[track_name][candidate.start] = candidate


def _is_trio(measure_number: int) -> bool:
    return TRIO_FIRST_MEASURE <= measure_number < REPRISE_FIRST_MEASURE


def _melodic_candidates(right: list[SourceEvent], left: list[SourceEvent]) -> dict[str, dict[int, ArrangementEvent]]:
    candidates: dict[str, dict[int, ArrangementEvent]] = defaultdict(dict)
    right_by_start = _group_by_start(right)
    left_by_start = _group_by_start(left)

    for start, sounding in right_by_start.items():
        measure_number = start // BAR_TICKS + 1
        top = sounding[0]
        if _is_trio(measure_number):
            _add_candidate(candidates, TRACKS[0], top, _velocity(top.velocity, 68, 50, 90), 4)
        else:
            _add_candidate(candidates, TRACKS[3], top, _velocity(top.velocity, 74, 56, 96), 4)
            beat_tick = start % BAR_TICKS
            if measure_number in MARCH_GLOW_MEASURES and beat_tick in {0, 2 * TICKS_PER_BEAT} and top.pitch >= 70:
                _add_candidate(candidates, TRACKS[0], top, _velocity(top.velocity, 43, 34, 64), 2)
        if len(sounding) >= 2:
            second = sounding[1]
            _add_candidate(candidates, TRACKS[1], second, _velocity(second.velocity, 58, 42, 82), 3)
        if len(sounding) >= 3:
            third = sounding[2]
            _add_candidate(candidates, TRACKS[2], third, _velocity(third.velocity, 52, 38, 76), 3)

    for start, sounding in left_by_start.items():
        measure_number = start // BAR_TICKS + 1
        ascending = list(reversed(sounding))
        lowest = ascending[0]
        if _is_trio(measure_number) and len(ascending) == 1:
            if lowest.pitch <= 43:
                _add_candidate(candidates, TRACKS[4], lowest, _velocity(lowest.velocity, 55, 38, 78), 4)
            else:
                _add_candidate(candidates, TRACKS[3], lowest, _velocity(lowest.velocity, 61, 44, 84), 4)
            continue

        _add_candidate(candidates, TRACKS[4], lowest, _velocity(lowest.velocity, 56, 38, 80), 4)
        if len(ascending) >= 2:
            highest = ascending[-1]
            if _is_trio(measure_number):
                _add_candidate(candidates, TRACKS[3], highest, _velocity(highest.velocity, 61, 44, 84), 3)
                if len(ascending) >= 3:
                    inner = ascending[-2]
                    _add_candidate(candidates, TRACKS[2], inner, _velocity(inner.velocity, 50, 36, 72), 1)
            else:
                _add_candidate(candidates, TRACKS[2], highest, _velocity(highest.velocity, 52, 38, 76), 1)
    return candidates


def _finalize_monophonic(raw: dict[int, ArrangementEvent], gate_scale: float) -> list[ArrangementEvent]:
    ordered = [raw[start] for start in sorted(raw)]
    finalized: list[ArrangementEvent] = []
    for index, event in enumerate(ordered):
        next_start = ordered[index + 1].start if index + 1 < len(ordered) else MOVEMENT_TICKS
        scaled_end = event.start + max(1, int(round((event.end - event.start) * gate_scale)))
        final_end = min(scaled_end, next_start, MOVEMENT_TICKS)
        if final_end <= event.start:
            final_end = min(event.start + 1, MOVEMENT_TICKS)
        finalized.append(ArrangementEvent(event.start, final_end, event.pitch, event.velocity))
    return finalized


def _percussion_events() -> list[ArrangementEvent]:
    events: list[ArrangementEvent] = []

    def add(measure_number: int, beat: float, midi_note: int, velocity: int, gate_beats: float) -> None:
        start = int(round(((measure_number - 1) * 4.0 + beat) * TICKS_PER_BEAT))
        end = min(MOVEMENT_TICKS, start + max(1, int(round(gate_beats * TICKS_PER_BEAT))))
        events.append(ArrangementEvent(start, end, midi_note, velocity))

    for measure_number in range(1, MEASURE_COUNT + 1):
        if _is_trio(measure_number):
            if (measure_number - TRIO_FIRST_MEASURE) % 4 == 0:
                add(measure_number, 0.0, 36, 32, 0.18)
            if (measure_number - TRIO_FIRST_MEASURE) % 2 == 1:
                add(measure_number, 3.0, 42, 25, 0.10)
            if measure_number in {56, 78}:
                add(measure_number, 2.0, 41, 29, 0.14)
            continue
        downbeat_velocity = 50 if (measure_number - 1) % 4 == 0 else 44
        add(measure_number, 0.0, 36, downbeat_velocity, 0.18)
        if measure_number % 2 == 0:
            add(measure_number, 2.0, 41, 34, 0.14)
        if measure_number % 4 == 0:
            add(measure_number, 3.5, 42, 27, 0.10)
    events.sort(key=lambda event: (event.start, event.pitch))
    return events


def _arrangement_events(right: list[SourceEvent], left: list[SourceEvent]) -> dict[str, list[ArrangementEvent]]:
    candidates = _melodic_candidates(right, left)
    events = {
        track_name: _finalize_monophonic(candidates[track_name], GATE_SCALES[track_name])
        for track_name in TRACKS[:-1]
    }
    events[TRACKS[-1]] = _percussion_events()
    return events


def _write_arrangement_midi(events: dict[str, list[ArrangementEvent]]) -> dict[str, int]:
    VERSION_DIR.mkdir(parents=True, exist_ok=True)
    midi = mido.MidiFile(type=1, ticks_per_beat=TICKS_PER_BEAT)
    conductor = mido.MidiTrack()
    conductor.append(mido.MetaMessage("track_name", name="Conductor", time=0))
    conductor.append(mido.MetaMessage("time_signature", numerator=4, denominator=4, time=0))
    conductor.append(mido.MetaMessage("key_signature", key="Bbm", time=0))
    conductor.append(mido.MetaMessage("set_tempo", tempo=mido.bpm2tempo(QPM), time=0))
    conductor.append(mido.MetaMessage("marker", text="Marche funèbre", time=0))
    trio_tick = (TRIO_FIRST_MEASURE - 1) * BAR_TICKS
    reprise_tick = (REPRISE_FIRST_MEASURE - 1) * BAR_TICKS
    conductor.append(mido.MetaMessage("marker", text="Trio", time=trio_tick))
    conductor.append(mido.MetaMessage("marker", text="Marche reprise", time=reprise_tick - trio_tick))
    conductor.append(mido.MetaMessage("end_of_track", time=MOVEMENT_TICKS - reprise_tick))
    midi.tracks.append(conductor)

    channels = (0, 1, 2, 3, 4, 9)
    counts: dict[str, int] = {}
    for track_name, channel in zip(TRACKS, channels, strict=True):
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
        track.append(mido.MetaMessage("end_of_track", time=max(0, MOVEMENT_TICKS - previous_tick)))
        midi.tracks.append(track)
        counts[track_name] = len(events[track_name])
    midi.save(ARRANGEMENT_MIDI)
    return counts


def main() -> int:
    if sha256(SOURCE_MIDI) != EXPECTED_SOURCE_SHA256:
        raise RuntimeError("Immutable PDMX source MIDI hash drifted")
    if sha256(SOURCE_PDF) != EXPECTED_REFERENCE_SHA256:
        raise RuntimeError("Immutable public-domain reference score hash drifted")
    pdmx_record = read_json(PDMX_RECORD)
    if pdmx_record.get("dataset_index_sha256") != EXPECTED_INDEX_SHA256:
        raise RuntimeError("PDMX index evidence hash drifted")
    if pdmx_record.get("archive_sha256") != EXPECTED_ARCHIVE_SHA256:
        raise RuntimeError("PDMX MIDI archive evidence hash drifted")
    if pdmx_record.get("license") != "cc-zero" or pdmx_record.get("license_conflict") is not False:
        raise RuntimeError("PDMX source is no longer recorded as no-conflict CC0")
    if pdmx_record.get("subset_all_valid") is not True or pdmx_record.get("subset_no_license_conflict") is not True:
        raise RuntimeError("PDMX source is outside the required all-valid/no-license-conflict subsets")

    config = read_json(CONFIG_PATH)
    verify_source_clearance(config, CONFIG_PATH)
    configured_crossfade = float(config["render"]["crossfade_seconds"])
    if int(round(configured_crossfade * RENDER_SAMPLE_RATE)) != LOOP_CROSSFADE_SAMPLES:
        raise RuntimeError("Configured audition crossfade drifted from the verified zero-crossing alignment")
    source_midi = mido.MidiFile(SOURCE_MIDI)
    boundary_report = _assert_source_boundaries(source_midi)
    right = _extract_source_events(source_midi, 0, "right")
    left = _extract_source_events(source_midi, 1, "left")
    source_event_report = _assert_source_events(right, left)

    normalized = write_normalized_score(
        _normalized_source_score(right, left),
        NORMALIZED_DIR,
        expand_repeats=False,
    )
    _stabilize_musicxml_ids(normalized)
    arrangement_events = _arrangement_events(right, left)
    note_counts = _write_arrangement_midi(arrangement_events)
    if any(count <= 0 for count in note_counts.values()):
        raise RuntimeError(f"Every configured audition track must contain notes: {note_counts}")

    report = {
        "ok": True,
        "source_midi": str(SOURCE_MIDI),
        "source_midi_sha256": sha256(SOURCE_MIDI),
        "source_reference_pdf": str(SOURCE_PDF),
        "source_reference_pdf_sha256": sha256(SOURCE_PDF),
        "source_reference_pages": "PDF pages 11-13; page 14 confirms the Finale boundary",
        "source_boundary": boundary_report,
        "source_events": source_event_report,
        "sections": {
            "march_first": {"measures": [1, 32]},
            "trio": {"measures": [33, 78]},
            "march_reprise": {"measures": [79, 108]},
        },
        "normalized": normalized,
        "arrangement_midi": str(ARRANGEMENT_MIDI),
        "arrangement_midi_sha256": sha256(ARRANGEMENT_MIDI),
        "arrangement_note_counts": note_counts,
        "tempo_qpm": QPM,
        "structural_duration_seconds": MOVEMENT_TICKS / TICKS_PER_BEAT * 60.0 / QPM,
        "loop_crossfade_seconds": LOOP_CROSSFADE_SECONDS,
        "loop_crossfade_alignment": {
            "sample_rate": RENDER_SAMPLE_RATE,
            "crossfade_samples": LOOP_CROSSFADE_SAMPLES,
            "offset_from_exact_one_measure_seconds": LOOP_CROSSFADE_SECONDS - (4.0 * 60.0 / QPM),
            "reason": "nearby stereo zero crossing avoids a native Vorbis boundary transient",
        },
        "harmony_changes": "none",
        "transpositions": "none",
        "added_doubling": "selective unison Veiled Violin doubling in documented march climax measures",
    }
    write_json(BUILD_REPORT, report)
    print(json.dumps(report, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
