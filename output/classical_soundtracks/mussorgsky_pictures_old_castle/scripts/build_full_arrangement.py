#!/usr/bin/env python3
"""Build the complete, score-faithful v02 Old Castle audition."""

from __future__ import annotations

from collections import defaultdict
from dataclasses import dataclass
import json
from pathlib import Path
import re
import sys
import xml.etree.ElementTree as ET

import mido
from music21 import bar, chord, clef, key, metadata, meter, note, pitch, stream, tempo


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


SOURCE_PDF = TRACK_ROOT / "source" / "mussorgsky_pictures_at_an_exhibition_breitkopf_1918_reprint.pdf"
EXPECTED_SOURCE_SHA256 = "0a73559cd865083558f6e5923dddae4390069883dad795725c19f18646e58b71"
TRANSCRIPTION_ROOT = TRACK_ROOT / "transcription" / "omr_raw"
TRANSCRIPTION_PAGES = (
    (TRANSCRIPTION_ROOT / "score_page_07.musicxml", "c6c8db0e8fb9160670e9b22fc83c2a41267ad95aaf99d0277c68fa8445c6eb49", 30),
    (TRANSCRIPTION_ROOT / "score_page_08.musicxml", "b5bea01cb8e4b2651bc6c9f4daca7c075733b4b6ed0ac122dd9477de544be61e", 39),
    (TRANSCRIPTION_ROOT / "score_page_09.musicxml", "86fa0442eed797c90448e0bd0e46191ae51528fb2fed326fa5932358908aa6b3", 37),
)
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

MEASURE_QUARTERS = 3.0
MEASURE_COUNT = 106
TICKS_PER_BEAT = 480
QPM = 72

# homr identifies the four principal voices consistently across the scan.
# Rare auxiliary voices are engraving artifacts or doublings and are not needed
# for this five-voice game reduction.
SOURCE_VOICES = (("1", "1"), ("1", "2"), ("2", "5"), ("2", "6"))
VOICE_IDS = {
    ("1", "1"): "upper_primary",
    ("1", "2"): "upper_secondary",
    ("2", "5"): "lower_primary",
    ("2", "6"): "lower_pedal",
}

TRACKS = (
    "Veiled Violin / Castle Air",
    "Ashen Violin / Inner Voice",
    "Hollow Viola / Lower Harmony",
    "Grave Cello / Troubadour",
    "Undercrypt Bass / G-sharp Pedal",
)


@dataclass
class Group:
    duration: float
    pitches: list[str]
    rest: bool = False
    grace: bool = False


def _pitch_name(element: ET.Element) -> str | None:
    raw = element.find("pitch")
    if raw is None:
        return None
    alter = int(raw.findtext("alter", "0"))
    accidental = {-2: "bb", -1: "b", 0: "", 1: "#", 2: "##"}.get(alter)
    if accidental is None:
        raise RuntimeError(f"Unsupported OMR accidental alteration: {alter}")
    return f"{raw.findtext('step')}{accidental}{raw.findtext('octave')}"


def _raw_measure_voices(measure: ET.Element, divisions: int) -> dict[tuple[str, str], list[Group]]:
    voices: dict[tuple[str, str], list[Group]] = defaultdict(list)
    for element in measure.findall("note"):
        key_value = (element.findtext("staff", "1"), element.findtext("voice", "1"))
        if key_value not in SOURCE_VOICES:
            continue
        duration = int(element.findtext("duration", "0")) / divisions
        value = _pitch_name(element)
        is_rest = element.find("rest") is not None
        is_grace = element.find("grace") is not None or duration == 0.0
        if element.find("chord") is not None and voices[key_value]:
            group = voices[key_value][-1]
            if value is not None and value not in group.pitches:
                group.pitches.append(value)
            if value is not None:
                group.rest = False
            group.grace = group.grace and is_grace
            continue
        voices[key_value].append(Group(duration, [value] if value else [], is_rest, is_grace))
    return voices


def _normalize_groups(groups: list[Group]) -> tuple[list[Group], dict[str, object]]:
    raw_total = sum(value.duration for value in groups if not value.grace)
    sounding = any(value.pitches for value in groups)
    if not sounding:
        return [Group(MEASURE_QUARTERS, [], rest=True)], {
            "raw_quarters": raw_total,
            "normalized_quarters": MEASURE_QUARTERS,
            "action": "whole-measure rest normalized to 6/8",
        }

    normalized: list[Group] = []
    cursor = 0.0
    trimmed = False
    for raw in groups:
        if raw.grace:
            if raw.pitches:
                normalized.append(Group(0.0, list(raw.pitches), grace=True))
            continue
        remaining = MEASURE_QUARTERS - cursor
        if remaining <= 1e-9:
            trimmed = True
            break
        duration = min(raw.duration, remaining)
        if duration <= 1e-9:
            continue
        if duration < raw.duration - 1e-9:
            trimmed = True
        normalized.append(Group(duration, list(raw.pitches), raw.rest and not raw.pitches))
        cursor += duration
    if cursor < MEASURE_QUARTERS - 1e-9:
        normalized.append(Group(MEASURE_QUARTERS - cursor, [], rest=True))
    action = "unchanged"
    if trimmed:
        action = "trimmed OMR overflow at the printed barline"
    elif abs(raw_total - MEASURE_QUARTERS) > 1e-9:
        action = "padded OMR underfill to the printed barline"
    return normalized, {
        "raw_quarters": raw_total,
        "normalized_quarters": MEASURE_QUARTERS,
        "action": action,
    }


def _load_transcription() -> tuple[list[dict[tuple[str, str], list[Group]]], dict[str, object]]:
    measures: list[dict[tuple[str, str], list[Group]]] = []
    repair_events: dict[str, list[dict[str, object]]] = defaultdict(list)
    page_reports: list[dict[str, object]] = []
    for page_path, expected_hash, expected_measures in TRANSCRIPTION_PAGES:
        actual_hash = sha256(page_path)
        if actual_hash != expected_hash:
            raise RuntimeError(f"Frozen OMR input drifted: {page_path}")
        root = ET.parse(page_path).getroot()
        page_measures = root.findall(".//part/measure")
        if len(page_measures) != expected_measures:
            raise RuntimeError(
                f"Expected {expected_measures} measures in {page_path}, found {len(page_measures)}"
            )
        divisions = 4
        page_start = len(measures) + 1
        for raw_measure in page_measures:
            attributes = raw_measure.find("attributes")
            raw_divisions = attributes.findtext("divisions") if attributes is not None else None
            if raw_divisions:
                divisions = int(raw_divisions)
            raw_voices = _raw_measure_voices(raw_measure, divisions)
            clean: dict[tuple[str, str], list[Group]] = {}
            global_measure = len(measures) + 1
            for voice_key in SOURCE_VOICES:
                groups, repair = _normalize_groups(raw_voices.get(voice_key, []))
                clean[voice_key] = groups
                if repair["action"] != "unchanged":
                    repair_events[repair["action"]].append({
                        "measure": global_measure,
                        "voice": VOICE_IDS[voice_key],
                        "raw_quarters": repair["raw_quarters"],
                    })
            measures.append(clean)
        page_reports.append({
            "path": str(page_path),
            "sha256": actual_hash,
            "global_measure_span": [page_start, len(measures)],
            "measure_count": len(page_measures),
        })
    if len(measures) != MEASURE_COUNT:
        raise RuntimeError(f"Expected {MEASURE_COUNT} complete-movement measures, found {len(measures)}")
    return measures, {
        "omr_tool": "homr 0.7.0",
        "pages": page_reports,
        "measure_count": len(measures),
        "repairs": {key_value: values for key_value, values in sorted(repair_events.items())},
    }


def _music21_value(group: Group):
    unique = sorted(set(group.pitches), key=lambda name: int(pitch.Pitch(name).midi))
    if group.rest or not unique:
        return note.Rest(quarterLength=group.duration)
    if len(unique) == 1:
        value = note.Note(unique[0], quarterLength=group.duration)
    else:
        value = chord.Chord(unique, quarterLength=group.duration)
    value.volume.velocity = 60
    return value


def _source_score(measures: list[dict[tuple[str, str], list[Group]]]) -> stream.Score:
    score = stream.Score(id="old_castle_complete_transcription")
    score.metadata = metadata.Metadata()
    score.metadata.title = "Il vecchio castello - complete project-authored scan transcription"
    score.metadata.composer = "Modest Mussorgsky"
    piano = stream.Part(id="piano_full_movement_transcription")
    piano.partName = "Piano (full movement scan transcription)"
    piano.insert(0, clef.TrebleClef())
    piano.insert(0, key.KeySignature(5))
    piano.insert(0, meter.TimeSignature("6/8"))
    piano.insert(0, tempo.MetronomeMark(number=QPM))

    for measure_number, voice_groups in enumerate(measures, 1):
        measure = stream.Measure(number=measure_number)
        for voice_key in SOURCE_VOICES:
            voice = stream.Voice(id=VOICE_IDS[voice_key])
            for group in voice_groups[voice_key]:
                if group.grace:
                    for name in group.pitches:
                        voice.append(note.Note(name).getGrace())
                    continue
                voice.append(_music21_value(group))
            measure.insert(0, voice)
        if measure_number == MEASURE_COUNT:
            measure.rightBarline = bar.Barline("final")
        piano.append(measure)
    score.insert(0, piano)
    return score


def _stabilize_normalized_musicxml(report: dict[str, object]) -> None:
    xml_paths = [Path(str(report["full_score_musicxml"]))]
    for part_report in report["parts"]:
        xml_paths.append(Path(str(part_report["musicxml_path"])))
    for xml_path in xml_paths:
        text = xml_path.read_text(encoding="utf-8")
        text, score_part_count = re.subn(r'<score-part id="P[^"]+">', '<score-part id="P1">', text)
        text, part_count = re.subn(r'<part id="P[^"]+">', '<part id="P1">', text)
        if score_part_count != 1 or part_count != 1:
            raise RuntimeError(f"Expected one generated MusicXML part id in {xml_path}")
        xml_path.write_text(text, encoding="utf-8")
    report["full_score_musicxml_sha256"] = sha256(Path(str(report["full_score_musicxml"])))
    for part_report in report["parts"]:
        part_report["musicxml_sha256"] = sha256(Path(str(part_report["musicxml_path"])))


def _timeline(groups: list[Group]) -> list[tuple[float, float, list[int]]]:
    events: list[tuple[float, float, list[int]]] = []
    cursor = 0.0
    pending_graces: list[int] = []
    for group in groups:
        values = sorted({int(pitch.Pitch(name).midi) for name in group.pitches})
        if group.grace:
            pending_graces.extend(values)
            continue
        duration = group.duration
        if values:
            grace_slot = min(0.125 * len(pending_graces), duration * 0.35)
            if pending_graces and grace_slot > 0:
                grace_duration = grace_slot / len(pending_graces)
                for index, midi_note in enumerate(pending_graces):
                    events.append((cursor + index * grace_duration, grace_duration * 0.82, [midi_note]))
            main_duration = duration - grace_slot
            if main_duration > 0:
                events.append((cursor + grace_slot, main_duration, values))
        pending_graces.clear()
        cursor += duration
    return events


def _in_range(value: int, low: int, high: int) -> int:
    while value < low:
        value += 12
    while value > high:
        value -= 12
    return max(low, min(high, value))


def _section_velocity(measure_number: int) -> int:
    if measure_number <= 28:
        return 58
    if measure_number <= 46:
        return 64
    if measure_number <= 54:
        return 57
    if measure_number <= 68:
        return 63
    if measure_number <= 86:
        return 59
    if measure_number <= 94:
        return 65
    if measure_number <= 101:
        return 56
    return max(46, 60 - (measure_number - 102) * 3)


def _arrangement_events(
    measures: list[dict[tuple[str, str], list[Group]]],
) -> dict[str, list[tuple[int, int, int, int]]]:
    events: dict[str, list[tuple[int, int, int, int]]] = defaultdict(list)

    def add(track: str, measure_number: int, offset: float, duration: float, midi_note: int, velocity: int) -> None:
        start = int(round(((measure_number - 1) * MEASURE_QUARTERS + offset) * TICKS_PER_BEAT))
        gate = max(1, int(round(max(0.04, duration * 0.92) * TICKS_PER_BEAT)))
        events[track].append((start, start + gate, midi_note, velocity))

    doubled_sections = ((29, 46), (55, 68), (74, 94), (102, 105))
    for measure_number, voices in enumerate(measures, 1):
        base_velocity = _section_velocity(measure_number)
        primary_timeline = _timeline(voices[("1", "1")])
        for offset, duration, values in primary_timeline:
            if not values:
                continue
            add(TRACKS[3], measure_number, offset, duration, _in_range(max(values) - 12, 36, 67), base_velocity + 4)
            chord_tone = sorted(values)[-2] if len(values) > 1 else max(values)
            if len(values) > 1 or any(start <= measure_number <= end for start, end in doubled_sections):
                add(TRACKS[0], measure_number, offset, duration, _in_range(chord_tone, 60, 88), base_velocity - 10)

        for offset, duration, values in _timeline(voices[("1", "2")]):
            if values:
                add(TRACKS[1], measure_number, offset, duration, _in_range(max(values), 55, 83), base_velocity - 13)

        for offset, duration, values in _timeline(voices[("2", "5")]):
            if values:
                add(TRACKS[2], measure_number, offset, duration, _in_range(max(values), 48, 76), base_velocity - 15)

        pedal_timeline = _timeline(voices[("2", "6")])
        if not any(values for _, _, values in pedal_timeline):
            pedal_timeline = _timeline(voices[("2", "5")])
        for offset, duration, values in pedal_timeline:
            if values:
                add(TRACKS[4], measure_number, offset, duration, _in_range(min(values), 28, 55), base_velocity - 12)

    return events


def _write_arrangement_midi(events: dict[str, list[tuple[int, int, int, int]]]) -> dict[str, int]:
    VERSION_DIR.mkdir(parents=True, exist_ok=True)
    midi = mido.MidiFile(type=1, ticks_per_beat=TICKS_PER_BEAT)
    total_ticks = int(MEASURE_COUNT * MEASURE_QUARTERS * TICKS_PER_BEAT)
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
        for start, end, midi_note, velocity in events[track_name]:
            scheduled.append((start, 1, mido.Message("note_on", note=midi_note, velocity=velocity, channel=channel, time=0)))
            scheduled.append((end, 0, mido.Message("note_off", note=midi_note, velocity=0, channel=channel, time=0)))
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
    actual: dict[str, str] = {}
    for name, expected_hash in EXPECTED_V01_HASHES.items():
        path = version / name
        actual[name] = sha256(path)
        if actual[name] != expected_hash:
            raise RuntimeError(f"v02 must not modify v01 artifact {path}")
    return actual


def main() -> int:
    if sha256(SOURCE_PDF) != EXPECTED_SOURCE_SHA256:
        raise RuntimeError("Immutable public-domain source PDF hash drifted")
    v01_hashes = _verify_v01_unchanged()
    config = read_json(CONFIG_PATH)
    verify_source_clearance(config, CONFIG_PATH)
    measures, transcription_report = _load_transcription()
    normalized = write_normalized_score(_source_score(measures), NORMALIZED_DIR, expand_repeats=False)
    _stabilize_normalized_musicxml(normalized)
    counts = _write_arrangement_midi(_arrangement_events(measures))
    report = {
        "ok": True,
        "source_pdf": str(SOURCE_PDF),
        "source_pdf_sha256": sha256(SOURCE_PDF),
        "source_score_pages": "PDF pages 8-10 (printed pages 7-9)",
        "selection": "Complete 106-measure movement in printed order; no cuts, repeats, or constructed cadence",
        "transcription": transcription_report,
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
