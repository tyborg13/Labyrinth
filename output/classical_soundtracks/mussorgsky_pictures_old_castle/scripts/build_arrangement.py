#!/usr/bin/env python3
"""Build the score-derived v01 Old Castle reduction and retro arrangement."""

from __future__ import annotations

from collections import defaultdict
import json
from pathlib import Path
import re
import sys

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


SOURCE_PDF = TRACK_ROOT / "source" / "mussorgsky_pictures_at_an_exhibition_bessel_1886.pdf"
EXPECTED_SOURCE_SHA256 = "0a73559cd865083558f6e5923dddae4390069883dad795725c19f18646e58b71"
CONFIG_PATH = TRACK_ROOT / "track.json"
NORMALIZED_DIR = TRACK_ROOT / "normalized"
VERSION_DIR = TRACK_ROOT / "versions" / "v01"
ARRANGEMENT_MIDI = VERSION_DIR / "arrangement.mid"
BUILD_REPORT = VERSION_DIR / "BUILD_REPORT.json"

MEASURE_QUARTERS = 3.0
MEASURE_COUNT = 32
TICKS_PER_BEAT = 480
QPM = 72

# A score-derived manual reduction of the opening lament and its first broad
# response from the public-domain 1886 piano score, PDF pages 8-9 (printed
# pages 7-8). Each tuple is (offset in quarter notes, duration, concert pitch).
# Dense keyboard sonorities are deliberately reduced; the melodic contour,
# G-sharp drone, modal inflections, and tonic/dominant cadence are retained.
MELODY: dict[int, list[tuple[float, float, str]]] = {
    5: [(2.5, 0.5, "D#4")],
    6: [(0.0, 3.0, "G#4")],
    7: [(0.0, 0.5, "G#4"), (0.5, 0.5, "B4"), (1.0, 0.5, "A#4"), (1.5, 0.5, "G#4"), (2.0, 0.5, "F#4"), (2.5, 0.5, "G#4")],
    8: [(0.0, 1.0, "F#4"), (1.0, 0.5, "D#4"), (1.5, 1.5, "D#4")],
    9: [(0.0, 0.5, "B3"), (0.5, 0.5, "C#4"), (1.0, 0.5, "D#4"), (1.5, 0.5, "E4"), (2.0, 0.5, "D#4"), (2.5, 0.5, "C#4")],
    10: [(0.0, 0.5, "D#4"), (0.5, 1.0, "B3"), (1.5, 1.5, "B3")],
    11: [(0.0, 0.5, "G#3"), (0.5, 0.5, "A#3"), (1.0, 0.5, "B3"), (1.5, 0.5, "C#4"), (2.0, 0.5, "B3"), (2.5, 0.5, "A#3")],
    12: [(0.0, 1.5, "G#3"), (1.5, 1.0, "G#3"), (2.5, 0.5, "D#4")],
    13: [(0.0, 3.0, "G#4")],
    14: [(0.0, 3.0, "B4")],
    15: [(0.0, 3.0, "C#5")],
    16: [(0.0, 1.5, "D#5"), (1.5, 0.5, "C#5"), (2.0, 0.5, "B4"), (2.5, 0.5, "A#4")],
    17: [(0.0, 1.5, "G#4"), (1.5, 1.5, "D#4")],
    18: [(0.0, 0.5, "E4"), (0.5, 0.5, "F#4"), (1.0, 0.5, "G#4"), (1.5, 0.5, "A#4"), (2.0, 0.5, "G#4"), (2.5, 0.5, "F#4")],
    19: [(0.0, 0.5, "D#4"), (0.5, 0.5, "E4"), (1.0, 0.5, "F#4"), (1.5, 0.5, "G#4"), (2.0, 0.5, "F#4"), (2.5, 0.5, "E4")],
    20: [(0.0, 1.5, "D#4"), (1.5, 1.5, "B3")],
    21: [(2.5, 0.5, "D#4")],
    22: [(0.0, 3.0, "G#4")],
    23: [(0.0, 0.5, "G#4"), (0.5, 0.5, "B4"), (1.0, 0.5, "A#4"), (1.5, 0.5, "G#4"), (2.0, 0.5, "F#4"), (2.5, 0.5, "G#4")],
    24: [(0.0, 0.5, "B4"), (0.5, 0.5, "C#5"), (1.0, 0.5, "D#5"), (1.5, 0.5, "C#5"), (2.0, 0.5, "B4"), (2.5, 0.5, "A#4")],
    25: [(0.0, 1.5, "G#4"), (1.5, 1.5, "E4")],
    26: [(0.0, 0.5, "F#4"), (0.5, 0.5, "G#4"), (1.0, 0.5, "A#4"), (1.5, 0.5, "G#4"), (2.0, 0.5, "F#4"), (2.5, 0.5, "E4")],
    27: [(0.0, 0.5, "D#4"), (0.5, 0.5, "E4"), (1.0, 0.5, "F#4"), (1.5, 0.5, "D#4"), (2.0, 0.5, "B3"), (2.5, 0.5, "C#4")],
    28: [(0.0, 1.5, "D#4"), (1.5, 1.5, "B3")],
    29: [(0.0, 0.5, "G#3"), (0.5, 0.5, "A#3"), (1.0, 0.5, "B3"), (1.5, 0.5, "D#4"), (2.0, 0.5, "C#4"), (2.5, 0.5, "B3")],
    30: [(0.0, 2.5, "G#3"), (2.5, 0.5, "D#4")],
    31: [(0.0, 1.5, "G#4"), (1.5, 1.5, "D#4")],
    32: [(0.0, 3.0, "G#3")],
}

# Essential harmony only; each tuple is (root, third, fifth/seventh).
HARMONY: list[tuple[str, str, str]] = [
    ("G#2", "B2", "D#3"), ("G#2", "B2", "D#3"), ("G#2", "B2", "D#3"), ("D#3", "G3", "A#3"),
    ("G#2", "B2", "D#3"), ("G#2", "B2", "D#3"), ("B2", "D#3", "F#3"), ("D#3", "G3", "A#3"),
    ("E3", "G#3", "B3"), ("C#3", "E3", "G#3"), ("D#3", "G3", "A#3"), ("G#2", "B2", "D#3"),
    ("G#2", "B2", "D#3"), ("B2", "D#3", "F#3"), ("C#3", "E3", "G#3"), ("D#3", "G3", "A#3"),
    ("G#2", "B2", "D#3"), ("E3", "G#3", "B3"), ("C#3", "E3", "G#3"), ("D#3", "G3", "A#3"),
    ("G#2", "B2", "D#3"), ("G#2", "B2", "D#3"), ("B2", "D#3", "F#3"), ("E3", "G#3", "B3"),
    ("C#3", "E3", "G#3"), ("F#2", "A#2", "C#3"), ("E3", "G#3", "B3"), ("D#3", "G3", "A#3"),
    ("G#2", "B2", "D#3"), ("C#3", "E3", "G#3"), ("D#3", "G3", "A#3"), ("G#2", "B2", "D#3"),
]

TRACKS = (
    "Veiled Violin / Castle Air",
    "Ashen Violin / Lute Ostinato",
    "Hollow Viola / Stone Harmony",
    "Grave Cello / Troubadour",
    "Undercrypt Bass / G-sharp Drone",
    "Funeral Pulse / Procedural Percussion",
)


def _source_score() -> stream.Score:
    score = stream.Score(id="old_castle_source_reduction")
    score.metadata = metadata.Metadata()
    score.metadata.title = "Il vecchio castello - public-domain score-derived opening reduction"
    score.metadata.composer = "Modest Mussorgsky"
    piano = stream.Part(id="piano_source_reduction")
    piano.partName = "Piano (score-derived source reduction)"
    piano.insert(0, clef.TrebleClef())
    piano.insert(0, key.KeySignature(5))
    piano.insert(0, meter.TimeSignature("6/8"))
    piano.insert(0, tempo.MetronomeMark(number=72))

    for measure_number in range(1, MEASURE_COUNT + 1):
        measure = stream.Measure(number=measure_number)
        melody_voice = stream.Voice(id="printed_melody_reduction")
        cursor = 0.0
        for offset, duration, name in MELODY.get(measure_number, []):
            if offset > cursor:
                melody_voice.append(note.Rest(quarterLength=offset - cursor))
            value = note.Note(name, quarterLength=duration)
            value.volume.velocity = 68
            melody_voice.append(value)
            cursor = offset + duration
        if cursor < MEASURE_QUARTERS:
            melody_voice.append(note.Rest(quarterLength=MEASURE_QUARTERS - cursor))

        harmony_voice = stream.Voice(id="essential_harmony_reduction")
        harmony = chord.Chord(HARMONY[measure_number - 1], quarterLength=MEASURE_QUARTERS)
        harmony.volume.velocity = 42
        harmony_voice.append(harmony)

        drone_voice = stream.Voice(id="g_sharp_ostinato_reduction")
        pattern = ("G#2", "D#3", "G#2", "B2", "G#2", "D#3")
        for name in pattern:
            pulse = note.Note(name, quarterLength=0.5)
            pulse.volume.velocity = 36
            drone_voice.append(pulse)

        measure.insert(0, melody_voice)
        measure.insert(0, harmony_voice)
        measure.insert(0, drone_voice)
        if measure_number == MEASURE_COUNT:
            measure.rightBarline = bar.Barline("final")
        piano.append(measure)
    score.insert(0, piano)
    return score


def _midi_number(name: str, transpose: int = 0) -> int:
    return int(pitch.Pitch(name).midi) + transpose


def _arrangement_events() -> dict[str, list[tuple[int, int, int, int]]]:
    events: dict[str, list[tuple[int, int, int, int]]] = defaultdict(list)

    def add(track: str, measure_number: int, offset: float, duration: float, midi_note: int, velocity: int) -> None:
        start = int(round(((measure_number - 1) * MEASURE_QUARTERS + offset) * TICKS_PER_BEAT))
        length = max(1, int(round(duration * TICKS_PER_BEAT)))
        events[track].append((start, start + length, midi_note, velocity))

    for measure_number in range(1, MEASURE_COUNT + 1):
        root, third, fifth = HARMONY[measure_number - 1]
        chord_midis = [_midi_number(value) for value in (root, third, fifth)]

        # The printed G-sharp drone becomes the loop's low anchor. The second
        # dotted-quarter lightly acknowledges each essential harmony.
        add(TRACKS[4], measure_number, 0.0, 1.36, _midi_number("G#1"), 47)
        add(TRACKS[4], measure_number, 1.5, 1.36, chord_midis[0] - 12, 43)

        # One restrained inner voice keeps the piano harmony legible without
        # rebuilding every keyboard doubling.
        add(TRACKS[2], measure_number, 0.0, 2.78, chord_midis[1], 44)

        # Six dry, lute-like bowed pulses translate the source ostinato.
        ostinato = (chord_midis[2] + 12, chord_midis[1] + 12, chord_midis[2] + 12, chord_midis[0] + 24, chord_midis[1] + 12, chord_midis[2] + 12)
        for index, midi_note in enumerate(ostinato):
            add(TRACKS[1], measure_number, index * 0.5, 0.38, midi_note, 38 if index else 43)

        source_events = MELODY.get(measure_number, [])
        for offset, duration, name in source_events:
            gate = max(0.18, duration * 0.91)
            add(TRACKS[3], measure_number, offset, gate, _midi_number(name, -12), 66 if duration < 2.0 else 61)

        # Violin I either sustains a high castle-air tone or takes a selective
        # octave echo during the middle response, leaving the cello foremost.
        if 13 <= measure_number <= 20 and source_events:
            for offset, duration, name in source_events:
                add(TRACKS[0], measure_number, offset, max(0.18, duration * 0.88), _midi_number(name, 12), 43)
        else:
            add(TRACKS[0], measure_number, 0.0, 2.70, chord_midis[2] + 24, 34)

        # Sparse two-bar funeral pulse; no cymbal wash or busy kit pattern.
        if measure_number % 2 == 1:
            add(TRACKS[5], measure_number, 0.0, 0.18, 36, 42)
        if measure_number % 4 == 0:
            add(TRACKS[5], measure_number, 1.5, 0.14, 41, 35)
        if measure_number in {8, 16, 24, 32}:
            add(TRACKS[5], measure_number, 2.5, 0.10, 42, 30)

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
    for channel, name in enumerate(TRACKS):
        track = mido.MidiTrack()
        track.append(mido.MetaMessage("track_name", name=name, time=0))
        scheduled: list[tuple[int, int, mido.Message]] = []
        for start, end, midi_note, velocity in events[name]:
            scheduled.append((start, 1, mido.Message("note_on", note=midi_note, velocity=velocity, channel=min(channel, 15), time=0)))
            scheduled.append((end, 0, mido.Message("note_off", note=midi_note, velocity=0, channel=min(channel, 15), time=0)))
        scheduled.sort(key=lambda item: (item[0], item[1], item[2].note))
        previous_tick = 0
        for absolute_tick, _, message in scheduled:
            message.time = absolute_tick - previous_tick
            track.append(message)
            previous_tick = absolute_tick
        track.append(mido.MetaMessage("end_of_track", time=max(0, total_ticks - previous_tick)))
        midi.tracks.append(track)
        counts[name] = len(events[name])
    midi.save(ARRANGEMENT_MIDI)
    return counts


def _stabilize_normalized_musicxml(report: dict[str, object]) -> None:
    """Replace music21's random single-part XML ids and refresh report hashes."""
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


def main() -> int:
    if sha256(SOURCE_PDF) != EXPECTED_SOURCE_SHA256:
        raise RuntimeError("Immutable public-domain source PDF hash drifted")
    config = read_json(CONFIG_PATH)
    verify_source_clearance(config, CONFIG_PATH)
    normalized = write_normalized_score(_source_score(), NORMALIZED_DIR, expand_repeats=False)
    _stabilize_normalized_musicxml(normalized)
    counts = _write_arrangement_midi(_arrangement_events())
    report = {
        "ok": True,
        "source_pdf": str(SOURCE_PDF),
        "source_pdf_sha256": sha256(SOURCE_PDF),
        "source_score_pages": "PDF pages 8-9 (printed pages 7-8)",
        "selection": "32-measure opening-lament reduction and tonic-cadence loop",
        "normalized": normalized,
        "arrangement_midi": str(ARRANGEMENT_MIDI),
        "arrangement_midi_sha256": sha256(ARRANGEMENT_MIDI),
        "arrangement_note_counts": counts,
        "tempo_qpm": QPM,
        "structural_duration_seconds": MEASURE_COUNT * MEASURE_QUARTERS * 60.0 / QPM,
    }
    write_json(BUILD_REPORT, report)
    print(json.dumps(report, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
