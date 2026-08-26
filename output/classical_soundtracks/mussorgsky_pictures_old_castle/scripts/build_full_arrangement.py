#!/usr/bin/env python3
"""Build the complete, score-faithful v02 Old Castle audition."""

from __future__ import annotations

from collections import defaultdict, deque
from dataclasses import dataclass
import json
from pathlib import Path
import re
import sys

import mido
from music21 import bar, clef, key, metadata, meter, note, stream, tempo, tie


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


SOURCE_MIDI = TRACK_ROOT / "source" / "mussorgsky_pictures_at_an_exhibition_pdmx_cc0.mid"
EXPECTED_SOURCE_MIDI_SHA256 = "e8c7fe31e8ff267a8fa4f4ca5edd076955e49cd89548d7367a588e163079cc34"
SOURCE_RECORD = TRACK_ROOT / "source" / "PDMX_RECORD.json"
EXPECTED_SOURCE_RECORD_SHA256 = "0e749f0673c5962aac59378c57028fa38fb2a26c8690c3945b5e004144b7e99d"
REFERENCE_PDF = TRACK_ROOT / "source" / "mussorgsky_pictures_at_an_exhibition_breitkopf_1918_reprint.pdf"
EXPECTED_REFERENCE_PDF_SHA256 = "0a73559cd865083558f6e5923dddae4390069883dad795725c19f18646e58b71"

EXPECTED_V01_HASHES = {
    "ARRANGEMENT_NOTES.md": "76660ac5badcd9e70044d43d251030fd895a121a79c96c4d5b37174a67753dc4",
    "BUILD_REPORT.json": "a92c3e51320b3170b8d37d66118799181e4699b25fe44d544b7dbdc455b0250a",
    "VERIFICATION.json": "a27ae236529565eb9734bd2fbce3a9421d3fd64627f7a65e7d13a01b8cedf313",
    "arrangement.mid": "fe2021d054e8179ade63c2d808e2624d8cd9a2e4bdcab5f0420dbe46b91b771b",
    "preview.flac": "cc591f7a64a75b60cdc759d483317d22b820cd1776a872e9b3fbfe03ce028b39",
    "preview.ogg": "6facdf9570066521a7a53a6859972c5476e5da23742b344351df65212fbb3a00",
    "preview.render.json": "1b7e1de1112b51d71e00fbf3a56d79ab33c9a1d6d5bf22796501a204cf233168",
}

CONFIG_PATH = TRACK_ROOT / "track.v02.json"
VERSION_DIR = TRACK_ROOT / "versions" / "v02"
NORMALIZED_DIR = VERSION_DIR / "normalized"
ARRANGEMENT_MIDI = VERSION_DIR / "arrangement.mid"
BUILD_REPORT = VERSION_DIR / "BUILD_REPORT.json"

TICKS_PER_BEAT = 480
MEASURE_TICKS = 1440
MEASURE_QUARTERS = 3.0
MEASURE_COUNT = 107
SOURCE_START_TICK = 274080
SOURCE_END_TICK = SOURCE_START_TICK + MEASURE_COUNT * MEASURE_TICKS
NEXT_MOVEMENT_TICK = 430560
QPM = 72

TRACKS = (
    "Veiled Violin / Castle Air",
    "Ashen Violin / Inner Voice",
    "Hollow Viola / Lower Harmony",
    "Grave Cello / Troubadour",
    "Undercrypt Bass / G-sharp Pedal",
)

# One pitch/onset anchor at every printed system start. These were checked
# against PDF pages 8-10 (printed pages 7-9). Staff 0 is treble, 1 is bass.
SYSTEM_ANCHORS = (
    (1, 1, 0, (44, 51)),
    (7, 0, 1200, (63,)),
    (13, 0, 0, (56,)),
    (19, 0, 0, (68,)),
    (25, 0, 0, (56, 64)),
    (31, 0, 0, (64, 69, 73, 76)),
    (38, 0, 0, (64, 69, 73, 76)),
    (44, 0, 0, (63, 67, 70, 75)),
    (50, 0, 0, (80,)),
    (57, 0, 0, (63, 66, 72)),
    (63, 0, 0, (63, 68, 75)),
    (70, 0, 0, (68,)),
    (76, 0, 0, (63, 66, 72)),
    (82, 0, 0, (63, 68, 75)),
    (89, 0, 0, (64, 69, 73, 76)),
    (96, 0, 0, (68,)),
    (102, 0, 0, (56, 58, 61, 64)),
)

# The iconic first lament, including the printed two-note ornament in m9.
OPENING_MELODY_ANCHORS = (
    (7, 1200, (63,)),
    (8, 0, (68,)),
    (9, 240, (71,)),
    (9, 480, (70,)),
    (9, 720, (68,)),
    (9, 767, (70,)),
    (9, 815, (68,)),
    (9, 960, (64,)),
    (9, 1200, (68,)),
    (10, 0, (68,)),
    (10, 480, (63,)),
    (10, 720, (66,)),
    (11, 240, (64,)),
    (11, 480, (63,)),
    (11, 720, (63,)),
    (11, 767, (64,)),
    (11, 960, (63,)),
    (11, 1200, (61,)),
    (12, 0, (63,)),
    (12, 240, (56,)),
)


@dataclass(frozen=True)
class MidiNote:
    start: int
    end: int
    pitch: int
    velocity: int
    staff: int


@dataclass
class ArrangementNote:
    start: int
    end: int
    pitch: int
    velocity: int


def _pitch_name(midi_pitch: int) -> str:
    names = ("C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B")
    return f"{names[midi_pitch % 12]}{midi_pitch // 12 - 1}"


def _track_notes(track: mido.MidiTrack, staff: int) -> list[MidiNote]:
    absolute = 0
    active: dict[tuple[int, int], deque[tuple[int, int]]] = defaultdict(deque)
    notes: list[MidiNote] = []
    for message in track:
        absolute += message.time
        if message.type == "note_on" and message.velocity > 0:
            active[(message.channel, message.note)].append((absolute, message.velocity))
            continue
        is_note_end = message.type == "note_off" or (
            message.type == "note_on" and message.velocity == 0
        )
        key_value = (getattr(message, "channel", -1), getattr(message, "note", -1))
        if not is_note_end or not active[key_value]:
            continue
        start, velocity = active[key_value].popleft()
        if start < SOURCE_START_TICK or start >= SOURCE_END_TICK or absolute <= start:
            continue
        notes.append(MidiNote(
            start=start - SOURCE_START_TICK,
            end=min(absolute, SOURCE_END_TICK) - SOURCE_START_TICK,
            pitch=message.note,
            velocity=velocity,
            staff=staff,
        ))
    return sorted(notes, key=lambda event: (event.start, event.pitch, event.end))


def _meta_events(track: mido.MidiTrack) -> list[tuple[int, mido.MetaMessage]]:
    absolute = 0
    events: list[tuple[int, mido.MetaMessage]] = []
    for message in track:
        absolute += message.time
        if message.is_meta:
            events.append((absolute, message))
    return events


def _pitches_at(notes: list[MidiNote], measure: int, offset: int) -> tuple[int, ...]:
    tick = (measure - 1) * MEASURE_TICKS + offset
    return tuple(sorted({event.pitch for event in notes if event.start == tick}))


def _verify_anchors(staves: tuple[list[MidiNote], list[MidiNote]]) -> dict[str, object]:
    checked: list[dict[str, object]] = []
    for measure, staff, offset, expected in SYSTEM_ANCHORS:
        actual = _pitches_at(staves[staff], measure, offset)
        if actual != expected:
            raise RuntimeError(
                f"Printed-system anchor drift at m{measure} staff {staff} offset {offset}: "
                f"expected {expected}, found {actual}"
            )
        checked.append({
            "measure": measure,
            "staff": "treble" if staff == 0 else "bass",
            "offset_ticks": offset,
            "pitches": [_pitch_name(value) for value in expected],
        })

    opening: list[dict[str, object]] = []
    for measure, offset, expected in OPENING_MELODY_ANCHORS:
        actual = _pitches_at(staves[0], measure, offset)
        if actual != expected:
            raise RuntimeError(
                f"Opening-melody anchor drift at m{measure} offset {offset}: "
                f"expected {expected}, found {actual}"
            )
        opening.append({
            "measure": measure,
            "offset_ticks": offset,
            "pitches": [_pitch_name(value) for value in expected],
        })

    final_treble = _pitches_at(staves[0], 106, 0)
    final_bass = _pitches_at(staves[1], 106, 0)
    if final_treble != (68, 80) or final_bass != (44, 51, 59):
        raise RuntimeError("Final G-sharp-minor cadence anchor drifted")
    if any(event.start >= 106 * MEASURE_TICKS for staff in staves for event in staff):
        raise RuntimeError("Expected printed m107 to contain no new note onset")
    return {
        "printed_system_anchors": checked,
        "opening_melody_anchors": opening,
        "final_cadence": {
            "measure": 106,
            "treble_pitches": [_pitch_name(value) for value in final_treble],
            "bass_pitches": [_pitch_name(value) for value in final_bass],
        },
        "final_fermata_rest_measure": 107,
    }


def _load_source() -> tuple[tuple[list[MidiNote], list[MidiNote]], dict[str, object]]:
    if sha256(SOURCE_MIDI) != EXPECTED_SOURCE_MIDI_SHA256:
        raise RuntimeError("Immutable CC0 PDMX source MIDI hash drifted")
    if sha256(SOURCE_RECORD) != EXPECTED_SOURCE_RECORD_SHA256:
        raise RuntimeError("PDMX provenance record hash drifted")
    if sha256(REFERENCE_PDF) != EXPECTED_REFERENCE_PDF_SHA256:
        raise RuntimeError("Immutable public-domain reference scan hash drifted")

    source = mido.MidiFile(SOURCE_MIDI)
    if source.type != 1 or source.ticks_per_beat != TICKS_PER_BEAT or len(source.tracks) != 2:
        raise RuntimeError("Unexpected PDMX source MIDI structure")
    meta = _meta_events(source.tracks[0])
    at_start = [message for tick, message in meta if tick == SOURCE_START_TICK]
    if not any(message.type == "time_signature" and message.numerator == 6 and message.denominator == 8 for message in at_start):
        raise RuntimeError("Old Castle source boundary lacks its 6/8 meter")
    if not any(message.type == "key_signature" and message.key == "B" for message in at_start):
        raise RuntimeError("Old Castle source boundary lacks its five-sharp key signature")
    if not any(message.type == "set_tempo" and message.tempo == 652175 for message in at_start):
        raise RuntimeError("Old Castle source boundary tempo marker drifted")
    if not any(tick == NEXT_MOVEMENT_TICK and message.type == "time_signature" for tick, message in meta):
        raise RuntimeError("Next-movement boundary marker drifted")

    staves = (_track_notes(source.tracks[0], 0), _track_notes(source.tracks[1], 1))
    expected_counts = (575, 593)
    actual_counts = tuple(len(staff) for staff in staves)
    if actual_counts != expected_counts:
        raise RuntimeError(f"Expected source staff counts {expected_counts}, found {actual_counts}")
    anchors = _verify_anchors(staves)
    report = {
        "source_midi": str(SOURCE_MIDI),
        "source_midi_sha256": sha256(SOURCE_MIDI),
        "source_record": str(SOURCE_RECORD),
        "source_record_sha256": sha256(SOURCE_RECORD),
        "reference_pdf": str(REFERENCE_PDF),
        "reference_pdf_sha256": sha256(REFERENCE_PDF),
        "movement_start_tick": SOURCE_START_TICK,
        "movement_end_tick": SOURCE_END_TICK,
        "next_movement_tick": NEXT_MOVEMENT_TICK,
        "ticks_per_beat": TICKS_PER_BEAT,
        "measure_count": MEASURE_COUNT,
        "source_staff_note_counts": {"treble": len(staves[0]), "bass": len(staves[1])},
        "anchors": anchors,
    }
    return staves, report


def _in_range(value: int, low: int, high: int) -> int:
    while value < low:
        value += 12
    while value > high:
        value -= 12
    return max(low, min(high, value))


def _arranged_velocity(source_velocity: int, offset: int) -> int:
    return max(34, min(92, int(round(38 + source_velocity * 0.45 + offset))))


def _onset_groups(notes: list[MidiNote]) -> list[list[MidiNote]]:
    groups: dict[int, dict[int, MidiNote]] = defaultdict(dict)
    for event in notes:
        previous = groups[event.start].get(event.pitch)
        if previous is None or event.end > previous.end:
            groups[event.start][event.pitch] = event
    return [
        [by_pitch[value] for value in sorted(by_pitch)]
        for _, by_pitch in sorted(groups.items())
    ]


def _arrangement_events(
    staves: tuple[list[MidiNote], list[MidiNote]],
) -> dict[str, list[ArrangementNote]]:
    events: dict[str, list[ArrangementNote]] = defaultdict(list)

    def add(track: str, source: MidiNote, midi_pitch: int, velocity_offset: int) -> None:
        events[track].append(ArrangementNote(
            start=source.start,
            end=source.end,
            pitch=midi_pitch,
            velocity=_arranged_velocity(source.velocity, velocity_offset),
        ))

    for group in _onset_groups(staves[0]):
        lowest = group[0]
        highest = group[-1]
        add(TRACKS[0], highest, _in_range(highest.pitch, 60, 88), -6)
        add(TRACKS[3], highest, _in_range(highest.pitch - 12, 36, 67), 7)
        if lowest.pitch != highest.pitch:
            add(TRACKS[1], lowest, _in_range(lowest.pitch, 55, 83), -10)

    for group in _onset_groups(staves[1]):
        lowest = group[0]
        highest = group[-1]
        add(TRACKS[2], highest, _in_range(highest.pitch, 48, 76), -11)
        add(TRACKS[4], lowest, _in_range(lowest.pitch, 28, 55), -7)

    for track_name in TRACKS:
        events[track_name].sort(key=lambda event: (event.start, event.pitch, event.end))
        cleaned: list[ArrangementNote] = []
        previous_by_pitch: dict[int, ArrangementNote] = {}
        for event in events[track_name]:
            previous = previous_by_pitch.get(event.pitch)
            if previous is not None and event.start - previous.start < 15:
                previous.end = max(previous.end, event.end)
                previous.velocity = max(previous.velocity, event.velocity)
                continue
            if previous is not None and previous.end >= event.start:
                previous.end = event.start
            cleaned.append(event)
            previous_by_pitch[event.pitch] = event
        events[track_name] = cleaned
    return events


def _event_lanes(events: list[ArrangementNote]) -> list[list[ArrangementNote]]:
    lanes: list[list[ArrangementNote]] = []
    lane_ends: list[int] = []
    for event in events:
        for index, lane_end in enumerate(lane_ends):
            if lane_end <= event.start:
                lanes[index].append(event)
                lane_ends[index] = event.end
                break
        else:
            lanes.append([event])
            lane_ends.append(event.end)
    return lanes


def _score_value(event: ArrangementNote, duration_ticks: int, tie_type: str | None):
    value = note.Note(_pitch_name(event.pitch), quarterLength=duration_ticks / TICKS_PER_BEAT)
    value.volume.velocity = event.velocity
    if tie_type is not None:
        value.tie = tie.Tie(tie_type)
    return value


def _score_tick(value: int) -> int:
    """Quantize MuseScore playback gates to the smallest portable MusicXML grid."""
    return int(round(value / 15.0)) * 15


def _normalized_score(events: dict[str, list[ArrangementNote]]) -> stream.Score:
    score = stream.Score(id="old_castle_complete_reduction")
    score.metadata = metadata.Metadata()
    score.metadata.title = "Il vecchio castello - complete five-voice source reduction"
    score.metadata.composer = "Modest Mussorgsky"

    for part_index, track_name in enumerate(TRACKS):
        part = stream.Part(id=f"reduction_part_{part_index + 1}")
        part.partName = track_name
        part.insert(0, clef.BassClef() if part_index >= 2 else clef.TrebleClef())
        part.insert(0, key.KeySignature(5))
        part.insert(0, meter.TimeSignature("6/8"))
        part.insert(0, tempo.MetronomeMark(number=QPM))
        lanes = _event_lanes(events[track_name])
        for measure_number in range(1, MEASURE_COUNT + 1):
            measure = stream.Measure(number=measure_number)
            measure_start = (measure_number - 1) * MEASURE_TICKS
            measure_end = measure_start + MEASURE_TICKS
            for lane_index, lane in enumerate(lanes):
                voice = stream.Voice(id=f"voice_{lane_index + 1}")
                cursor = 0
                for event in lane:
                    score_start = max(0, _score_tick(event.start))
                    score_end = min(
                        MEASURE_COUNT * MEASURE_TICKS,
                        max(score_start + 15, _score_tick(event.end)),
                    )
                    if score_end <= measure_start or score_start >= measure_end:
                        continue
                    local_start = max(score_start, measure_start) - measure_start
                    local_end = min(score_end, measure_end) - measure_start
                    local_start = max(local_start, cursor)
                    if local_end <= local_start:
                        continue
                    if local_start > cursor:
                        voice.append(note.Rest(quarterLength=(local_start - cursor) / TICKS_PER_BEAT))
                    tie_type = None
                    if score_start < measure_start and score_end > measure_end:
                        tie_type = "continue"
                    elif score_start < measure_start:
                        tie_type = "stop"
                    elif score_end > measure_end:
                        tie_type = "start"
                    voice.append(_score_value(event, local_end - local_start, tie_type))
                    cursor = local_end
                if cursor < MEASURE_TICKS:
                    voice.append(note.Rest(quarterLength=(MEASURE_TICKS - cursor) / TICKS_PER_BEAT))
                measure.insert(0, voice)
            if measure_number == MEASURE_COUNT:
                measure.rightBarline = bar.Barline("final")
            part.append(measure)
        score.insert(0, part)
    return score


def _stabilize_musicxml_file(path: Path) -> None:
    text = path.read_text(encoding="utf-8")
    text, date_count = re.subn(
        r"<encoding-date>[^<]+</encoding-date>",
        "<encoding-date>2026-08-26</encoding-date>",
        text,
    )
    if date_count != 1:
        raise RuntimeError(f"Expected one generated MusicXML encoding date in {path}")
    ids = re.findall(r'<score-part id="(P[^"]+)">', text)
    if not ids:
        raise RuntimeError(f"Expected generated MusicXML part ids in {path}")
    for index, old_id in enumerate(ids, 1):
        text = text.replace(f'id="{old_id}"', f'id="P{index}"')
    path.write_text(text, encoding="utf-8")


def _stabilize_normalized_musicxml(report: dict[str, object]) -> None:
    full_path = Path(str(report["full_score_musicxml"]))
    _stabilize_musicxml_file(full_path)
    report["full_score_musicxml_sha256"] = sha256(full_path)
    for part_report in report["parts"]:
        part_path = Path(str(part_report["musicxml_path"]))
        _stabilize_musicxml_file(part_path)
        part_report["musicxml_sha256"] = sha256(part_path)


def _write_arrangement_midi(events: dict[str, list[ArrangementNote]]) -> dict[str, int]:
    VERSION_DIR.mkdir(parents=True, exist_ok=True)
    midi = mido.MidiFile(type=1, ticks_per_beat=TICKS_PER_BEAT)
    total_ticks = MEASURE_COUNT * MEASURE_TICKS
    conductor = mido.MidiTrack()
    conductor.append(mido.MetaMessage("track_name", name="Conductor", time=0))
    conductor.append(mido.MetaMessage("time_signature", numerator=6, denominator=8, time=0))
    conductor.append(mido.MetaMessage("set_tempo", tempo=mido.bpm2tempo(QPM), time=0))
    conductor.append(mido.MetaMessage("end_of_track", time=total_ticks))
    midi.tracks.append(conductor)

    counts: dict[str, int] = {}
    for channel, track_name in enumerate(TRACKS):
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
        track.append(mido.MetaMessage("end_of_track", time=max(0, total_ticks - previous_tick)))
        midi.tracks.append(track)
        counts[track_name] = len(events[track_name])
    midi.save(ARRANGEMENT_MIDI)
    return counts


def _verify_v01_unchanged() -> dict[str, str]:
    version = TRACK_ROOT / "versions" / "v01"
    actual_files = sorted(path.name for path in version.iterdir() if path.is_file())
    if actual_files != sorted(EXPECTED_V01_HASHES):
        raise RuntimeError(f"v01 artifact tree drifted: found {actual_files}")
    actual: dict[str, str] = {}
    for name, expected_hash in EXPECTED_V01_HASHES.items():
        path = version / name
        actual[name] = sha256(path)
        if actual[name] != expected_hash:
            raise RuntimeError(f"v02 must not modify v01 artifact {path}")
    return actual


def main() -> int:
    v01_hashes = _verify_v01_unchanged()
    config = read_json(CONFIG_PATH)
    verify_source_clearance(config, CONFIG_PATH)
    staves, source_report = _load_source()
    events = _arrangement_events(staves)
    normalized = write_normalized_score(
        _normalized_score(events), NORMALIZED_DIR, expand_repeats=False
    )
    _stabilize_normalized_musicxml(normalized)
    counts = _write_arrangement_midi(events)
    report = {
        "ok": True,
        "selection": (
            "Complete 107-measure movement in printed order, including the final fermata-rest "
            "measure; no cuts, repeats, or constructed cadence"
        ),
        "source": source_report,
        "source_score_pages": "PDF pages 8-10 (printed pages 7-9)",
        "page_measure_spans": {
            "PDF 8 / printed 7": [1, 30],
            "PDF 9 / printed 8": [31, 69],
            "PDF 10 / printed 9": [70, 107],
        },
        "normalized": normalized,
        "arrangement_midi": str(ARRANGEMENT_MIDI),
        "arrangement_midi_sha256": sha256(ARRANGEMENT_MIDI),
        "arrangement_note_counts": counts,
        "tempo_qpm": QPM,
        "structural_duration_seconds": MEASURE_COUNT * MEASURE_QUARTERS * 60.0 / QPM,
        "v01_artifact_hashes_unchanged": v01_hashes,
    }
    write_json(BUILD_REPORT, report)
    print(json.dumps(report, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
