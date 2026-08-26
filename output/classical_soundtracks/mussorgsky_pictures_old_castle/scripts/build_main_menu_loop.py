#!/usr/bin/env python3
"""Build the contiguous, faster v03 Old Castle main-menu loop audition."""

from __future__ import annotations

from collections import defaultdict
from dataclasses import dataclass
import importlib.util
import json
from pathlib import Path
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


def _load_full_builder():
    path = TRACK_ROOT / "scripts" / "build_full_arrangement.py"
    spec = importlib.util.spec_from_file_location("old_castle_full_source", path)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"Could not load the complete-movement builder at {path}")
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


FULL = _load_full_builder()

CONFIG_PATH = TRACK_ROOT / "track.v03.json"
VERSION_DIR = TRACK_ROOT / "versions" / "v03"
NORMALIZED_DIR = VERSION_DIR / "normalized"
ARRANGEMENT_MIDI = VERSION_DIR / "arrangement.mid"
BUILD_REPORT = VERSION_DIR / "BUILD_REPORT.json"

EXPECTED_V02_CONFIG_SHA256 = "1c25ef1e86ed73cc7cea06e228271120cfb858626a3bef4b3de1ac3ab181705c"
EXPECTED_V02_BUILDER_SHA256 = "b1004b070977b8c5e9805065a0c5e507e9aa3d79fbb46688e80e720096a4c498"

EXPECTED_PREVIOUS_VERSION_HASHES = {
    "v01/ARRANGEMENT_NOTES.md": "76660ac5badcd9e70044d43d251030fd895a121a79c96c4d5b37174a67753dc4",
    "v01/BUILD_REPORT.json": "a92c3e51320b3170b8d37d66118799181e4699b25fe44d544b7dbdc455b0250a",
    "v01/VERIFICATION.json": "a27ae236529565eb9734bd2fbce3a9421d3fd64627f7a65e7d13a01b8cedf313",
    "v01/arrangement.mid": "fe2021d054e8179ade63c2d808e2624d8cd9a2e4bdcab5f0420dbe46b91b771b",
    "v01/preview.flac": "cc591f7a64a75b60cdc759d483317d22b820cd1776a872e9b3fbfe03ce028b39",
    "v01/preview.ogg": "6facdf9570066521a7a53a6859972c5476e5da23742b344351df65212fbb3a00",
    "v01/preview.render.json": "1b7e1de1112b51d71e00fbf3a56d79ab33c9a1d6d5bf22796501a204cf233168",
    "v02/ARRANGEMENT_NOTES.md": "d0ed5f25aaa4b74bfb5862784f9e0f429465739d53339ef6a1c440b2e0e87456",
    "v02/BUILD_REPORT.json": "636bc103281a036bc2ecdad83a86870f24a99fe655fcc2ff0deb90b879865355",
    "v02/VERIFICATION.json": "b0904f5f053f539ab4b4b10b6f18a1c26061f3a638c83ce01c1f0be90a84907b",
    "v02/arrangement.mid": "e4fe6d11b0148372cf07c759556e579403f0c7bc0f1b3db51b941b0851a86c94",
    "v02/normalized/full_score.mid": "a713acac2ab6541fbefa25578fcd48edd49ede36447256a05c7718fb5974d75a",
    "v02/normalized/full_score.musicxml": "0fb5eebc1c50f4e4431589fd2d117659c8873bbe7a7fc83b66ec2b431ca0f0a6",
    "v02/normalized/parts/01_veiled_violin_castle_air.mid": "4665f77133774e68620219f598b8ed5147f315711e7bd8945e0aef0dff342a04",
    "v02/normalized/parts/01_veiled_violin_castle_air.musicxml": "e4f997172b8f727638113e8605dfe1c3a640570713a1be19670db4b3c0105fcc",
    "v02/normalized/parts/02_ashen_violin_inner_voice.mid": "93dd3f5997780187e9d9fddef6793652c4eb56b44f834b65f6d04f44b71bd8e5",
    "v02/normalized/parts/02_ashen_violin_inner_voice.musicxml": "ec0ee27399ac8315b089cbed03c826bae7d9d33c0055a41315c2332d13cd9f1d",
    "v02/normalized/parts/03_hollow_viola_lower_harmony.mid": "fd8edd3c061014aec2456aad3a933758af756c397753530cd2d555d230e6f10e",
    "v02/normalized/parts/03_hollow_viola_lower_harmony.musicxml": "d1d3576733bff95c7aafae762a33d3485c12242bec08befc721044b7a38b9a9d",
    "v02/normalized/parts/04_grave_cello_troubadour.mid": "3b9b04cc2b4f8d1526db2089aae96e302c356d0a5f04f293c314f71edd90136d",
    "v02/normalized/parts/04_grave_cello_troubadour.musicxml": "e8813a4d7633e1eb8753235d4435e117317115db96846e4809636383e148efce",
    "v02/normalized/parts/05_undercrypt_bass_g_sharp_pedal.mid": "c37828b254677332688d224004de585bdcf034da1e8d8b07860779cb81ab38e3",
    "v02/normalized/parts/05_undercrypt_bass_g_sharp_pedal.musicxml": "ab8aa9027a2c3421d9d8cc7cca3b3629c063a5373e9abce8a3ab30b66233729b",
    "v02/preview.flac": "ec66910152ba9ca6263d58f95c246f94bbee8a27fc87106a986c90aa7e53fb27",
    "v02/preview.ogg": "39fd132e21a61abc5a30d423c32b5f2b294d64a52d2f9bbf76acb8e4ca483863",
    "v02/preview.render.json": "476d37cedc85a8f1825fd7d19e3b5200d50f80765d2cef41930f7c3bbc686538",
}

TICKS_PER_BEAT = 480
MEASURE_TICKS = 1440
SOURCE_START_MEASURE = 7
SOURCE_END_MEASURE_EXCLUSIVE = 69
SOURCE_START_TICK = (SOURCE_START_MEASURE - 1) * MEASURE_TICKS
SOURCE_END_TICK = (SOURCE_END_MEASURE_EXCLUSIVE - 1) * MEASURE_TICKS
MEASURE_COUNT = SOURCE_END_MEASURE_EXCLUSIVE - SOURCE_START_MEASURE
TOTAL_TICKS = MEASURE_COUNT * MEASURE_TICKS
TEMPO_QPM = 84

BASE_TRACKS = FULL.TRACKS
HIGH_TRACK = "Wraithlight Violin / High Embellishment"
PERCUSSION_TRACK = "Funeral Pulse / Menu Percussion"
MUSICAL_TRACKS = (*BASE_TRACKS, HIGH_TRACK)

# One phrase-highpoint glint every few measures: sparse enough to remain an
# embellishment, but distributed across the entire contiguous selection.
HIGH_EMBELLISHMENT_SOURCE_MEASURES = (
    9, 11, 15, 18, 21, 23, 27, 29, 33, 36,
    40, 43, 47, 50, 53, 56, 61, 62, 66, 68,
)


@dataclass(frozen=True)
class PercussionEvent:
    start: int
    end: int
    pitch: int
    velocity: int
    role: str


def _verify_previous_versions() -> dict[str, str]:
    versions = TRACK_ROOT / "versions"
    actual_files = sorted(
        path.relative_to(versions).as_posix()
        for version in (versions / "v01", versions / "v02")
        for path in version.rglob("*")
        if path.is_file()
    )
    if actual_files != sorted(EXPECTED_PREVIOUS_VERSION_HASHES):
        raise RuntimeError(f"v03 must not alter the v01/v02 artifact trees: {actual_files}")
    actual: dict[str, str] = {}
    for relative, expected in EXPECTED_PREVIOUS_VERSION_HASHES.items():
        path = versions / relative
        actual[relative] = sha256(path)
        if actual[relative] != expected:
            raise RuntimeError(f"v03 must not modify prior audition artifact {path}")
    if sha256(TRACK_ROOT / "track.v02.json") != EXPECTED_V02_CONFIG_SHA256:
        raise RuntimeError("The approved v02 audition config drifted before v03 build")
    if sha256(TRACK_ROOT / "scripts" / "build_full_arrangement.py") != EXPECTED_V02_BUILDER_SHA256:
        raise RuntimeError("The complete v02 builder drifted before v03 build")
    return actual


def _crop_base_events(
    full_events: dict[str, list[object]],
) -> tuple[dict[str, list[object]], dict[str, int]]:
    cropped: dict[str, list[object]] = {}
    clipped_counts: dict[str, int] = {}
    for track_name in BASE_TRACKS:
        values: list[object] = []
        clipped = 0
        for event in full_events[track_name]:
            if event.end <= SOURCE_START_TICK or event.start >= SOURCE_END_TICK:
                continue
            start = max(event.start, SOURCE_START_TICK)
            end = min(event.end, SOURCE_END_TICK)
            if start != event.start or end != event.end:
                clipped += 1
            values.append(FULL.ArrangementNote(
                start=start - SOURCE_START_TICK,
                end=end - SOURCE_START_TICK,
                pitch=event.pitch,
                velocity=event.velocity,
            ))
        cropped[track_name] = values
        clipped_counts[track_name] = clipped
    return cropped, clipped_counts


def _high_embellishments(
    full_events: dict[str, list[object]],
) -> tuple[list[object], list[dict[str, object]]]:
    melody = full_events[BASE_TRACKS[0]]
    output: list[object] = []
    mapping: list[dict[str, object]] = []
    for source_measure in HIGH_EMBELLISHMENT_SOURCE_MEASURES:
        measure_start = (source_measure - 1) * MEASURE_TICKS
        candidates = [
            event
            for event in melody
            if measure_start <= event.start < measure_start + MEASURE_TICKS
            and event.end - event.start >= 120
            and event.pitch <= 84
        ]
        if not candidates:
            raise RuntimeError(f"No safe upper-string source event in measure {source_measure}")
        source = max(candidates, key=lambda event: (event.pitch, event.end - event.start, -event.start))
        duration = min(240, source.end - source.start)
        value = FULL.ArrangementNote(
            start=source.start - SOURCE_START_TICK,
            end=source.start - SOURCE_START_TICK + duration,
            pitch=source.pitch + 12,
            velocity=max(42, min(58, source.velocity + 6)),
        )
        output.append(value)
        mapping.append({
            "source_measure": source_measure,
            "source_offset_ticks": source.start - measure_start,
            "source_pitch": FULL._pitch_name(source.pitch),
            "embellishment_pitch": FULL._pitch_name(value.pitch),
            "duration_ticks": duration,
            "relationship": "simultaneous one-octave doubling of the source melody",
        })
    return output, mapping


def _percussion_events() -> list[PercussionEvent]:
    output: list[PercussionEvent] = []
    for measure_index in range(MEASURE_COUNT):
        start = measure_index * MEASURE_TICKS
        source_measure = SOURCE_START_MEASURE + measure_index
        war_velocity = 58 if measure_index % 8 == 0 else 52
        tom_velocity = 39 if measure_index % 4 == 3 else 35
        tick_velocity = 22 if source_measure in HIGH_EMBELLISHMENT_SOURCE_MEASURES else 19
        output.extend((
            PercussionEvent(start, start + 180, 36, war_velocity, "bar-weight war drum"),
            PercussionEvent(start + 480, start + 540, 42, tick_velocity, "first-group ash tick"),
            PercussionEvent(start + 720, start + 840, 41, tom_velocity, "second dotted-beat tom"),
            PercussionEvent(start + 1200, start + 1260, 42, tick_velocity, "second-group ash tick"),
        ))
    return sorted(output, key=lambda event: (event.start, event.pitch))


def _score_value(event, duration_ticks: int, tie_type: str | None):
    value = note.Note(FULL._pitch_name(event.pitch), quarterLength=duration_ticks / TICKS_PER_BEAT)
    value.volume.velocity = event.velocity
    if tie_type is not None:
        value.tie = tie.Tie(tie_type)
    return value


def _normalized_score(events: dict[str, list[object]]) -> stream.Score:
    score = stream.Score(id="old_castle_main_menu_loop")
    score.metadata = metadata.Metadata()
    score.metadata.title = "Il vecchio castello - contiguous main-menu loop"
    score.metadata.composer = "Modest Mussorgsky"
    for part_index, track_name in enumerate(MUSICAL_TRACKS):
        part = stream.Part(id=f"main_menu_part_{part_index + 1}")
        part.partName = track_name
        if part_index in (3, 4):
            part.insert(0, clef.BassClef())
        elif part_index == 2:
            part.insert(0, clef.AltoClef())
        else:
            part.insert(0, clef.TrebleClef())
        part.insert(0, key.KeySignature(5))
        part.insert(0, meter.TimeSignature("6/8"))
        part.insert(0, tempo.MetronomeMark(number=TEMPO_QPM))
        lanes = FULL._event_lanes(events[track_name])
        for measure_number in range(1, MEASURE_COUNT + 1):
            measure = stream.Measure(number=measure_number)
            measure_start = (measure_number - 1) * MEASURE_TICKS
            measure_end = measure_start + MEASURE_TICKS
            for lane_index, lane in enumerate(lanes):
                voice = stream.Voice(id=f"voice_{lane_index + 1}")
                cursor = 0
                for event in lane:
                    score_start = max(0, FULL._score_tick(event.start))
                    score_end = min(TOTAL_TICKS, max(score_start + 15, FULL._score_tick(event.end)))
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


def _string_midi_track(track_name: str, channel: int, events: list[object]) -> mido.MidiTrack:
    volumes = (82, 74, 76, 90, 80, 62)
    pans = (82, 42, 70, 54, 64, 92)
    track = mido.MidiTrack()
    track.append(mido.MetaMessage("track_name", name=track_name, time=0))
    track.append(mido.Message("control_change", channel=channel, control=7, value=volumes[channel], time=0))
    track.append(mido.Message("control_change", channel=channel, control=10, value=pans[channel], time=0))
    scheduled: list[tuple[int, int, mido.Message]] = []
    for event in events:
        scheduled.append((event.start, 1, mido.Message(
            "note_on", note=event.pitch, velocity=event.velocity, channel=channel, time=0
        )))
        scheduled.append((event.end, 0, mido.Message(
            "note_off", note=event.pitch, velocity=0, channel=channel, time=0
        )))
    scheduled.sort(key=lambda item: (item[0], item[1], item[2].note))
    previous = 0
    for absolute, _, message in scheduled:
        track.append(message.copy(time=absolute - previous))
        previous = absolute
    track.append(mido.MetaMessage("end_of_track", time=max(0, TOTAL_TICKS - previous)))
    return track


def _percussion_midi_track(events: list[PercussionEvent]) -> mido.MidiTrack:
    track = mido.MidiTrack()
    track.append(mido.MetaMessage("track_name", name=PERCUSSION_TRACK, time=0))
    track.append(mido.MetaMessage(
        "instrument_name",
        name="Canonical procedural one-shots; GM percussion notes are fallback mapping only",
        time=0,
    ))
    track.append(mido.Message("control_change", channel=9, control=7, value=78, time=0))
    track.append(mido.Message("control_change", channel=9, control=10, value=64, time=0))
    scheduled: list[tuple[int, int, mido.Message]] = []
    for event in events:
        scheduled.append((event.start, 1, mido.Message(
            "note_on", note=event.pitch, velocity=event.velocity, channel=9, time=0
        )))
        scheduled.append((event.end, 0, mido.Message(
            "note_off", note=event.pitch, velocity=0, channel=9, time=0
        )))
    scheduled.sort(key=lambda item: (item[0], item[1], item[2].note))
    previous = 0
    for absolute, _, message in scheduled:
        track.append(message.copy(time=absolute - previous))
        previous = absolute
    track.append(mido.MetaMessage("end_of_track", time=max(0, TOTAL_TICKS - previous)))
    return track


def _write_midi(
    strings: dict[str, list[object]],
    percussion: list[PercussionEvent],
) -> dict[str, int]:
    VERSION_DIR.mkdir(parents=True, exist_ok=True)
    midi = mido.MidiFile(type=1, ticks_per_beat=TICKS_PER_BEAT)
    conductor = mido.MidiTrack()
    conductor.append(mido.MetaMessage("track_name", name="Conductor / Main Menu Loop Map", time=0))
    conductor.append(mido.MetaMessage(
        "copyright",
        text="Mussorgsky composition: public domain. PDMX source: CC0. Arrangement created for Escape the Umbra.",
        time=0,
    ))
    conductor.append(mido.MetaMessage("time_signature", numerator=6, denominator=8, time=0))
    conductor.append(mido.MetaMessage("key_signature", key="B", time=0))
    conductor.append(mido.MetaMessage("set_tempo", tempo=mido.bpm2tempo(TEMPO_QPM), time=0))
    conductor.append(mido.MetaMessage(
        "marker",
        text="LOOP_START / source printed m7 / v02 0:15",
        time=0,
    ))
    conductor.append(mido.MetaMessage(
        "marker",
        text="LOOP_END / before source printed m69 / v02 2:50",
        time=TOTAL_TICKS,
    ))
    conductor.append(mido.MetaMessage("end_of_track", time=0))
    midi.tracks.append(conductor)
    for channel, track_name in enumerate(MUSICAL_TRACKS):
        midi.tracks.append(_string_midi_track(track_name, channel, strings[track_name]))
    midi.tracks.append(_percussion_midi_track(percussion))
    midi.save(ARRANGEMENT_MIDI)
    return {
        **{track_name: len(strings[track_name]) for track_name in MUSICAL_TRACKS},
        PERCUSSION_TRACK: len(percussion),
    }


def _percussion_report(events: list[PercussionEvent]) -> dict[str, object]:
    counts: dict[str, int] = defaultdict(int)
    for event in events:
        counts[event.role] += 1
    return {
        "channel_zero_based": 9,
        "description": (
            "Restrained four-hit 6/8 pulse: low drum at each bar, quiet ash ticks at the "
            "end of each three-eighth group, and a muted tom on the second dotted beat."
        ),
        "counts_by_role": dict(sorted(counts.items())),
        "total_events": len(events),
    }


def main() -> int:
    previous_hashes = _verify_previous_versions()
    config = read_json(CONFIG_PATH)
    verify_source_clearance(config, CONFIG_PATH)
    staves, source_report = FULL._load_source()
    full_events = FULL._arrangement_events(staves)
    strings, clipped_counts = _crop_base_events(full_events)
    high_events, high_mapping = _high_embellishments(full_events)
    strings[HIGH_TRACK] = high_events
    percussion = _percussion_events()
    normalized = write_normalized_score(
        _normalized_score(strings), NORMALIZED_DIR, expand_repeats=False
    )
    FULL._stabilize_normalized_musicxml(normalized)
    counts = _write_midi(strings, percussion)
    report = {
        "ok": True,
        "version": "v03",
        "purpose": "Faster, lightly driven main-menu loop audition",
        "selection": {
            "source_printed_measure_start": SOURCE_START_MEASURE,
            "source_printed_measure_end_inclusive": SOURCE_END_MEASURE_EXCLUSIVE - 1,
            "measure_count": MEASURE_COUNT,
            "v02_start_seconds": 15.0,
            "v02_end_seconds": 170.0,
            "v02_user_description": "about 0:16 to 2:50",
            "ordering": "single contiguous source span; no cuts, reorder, or inserted repeat",
        },
        "tempo": {
            "v02_qpm": FULL.QPM,
            "v03_qpm": TEMPO_QPM,
            "increase_percent": (TEMPO_QPM / FULL.QPM - 1.0) * 100.0,
        },
        "loop": {
            "structural_duration_seconds": TOTAL_TICKS / TICKS_PER_BEAT * 60.0 / TEMPO_QPM,
            "crossfade_seconds": 60.0 / TEMPO_QPM,
            "rendered_duration_seconds": (TOTAL_TICKS / TICKS_PER_BEAT - 1.0) * 60.0 / TEMPO_QPM,
            "treatment": "one-quarter-note tail/head equal-power blend with loop-point rotation",
        },
        "base_source": source_report,
        "base_event_counts": {name: len(strings[name]) for name in BASE_TRACKS},
        "boundary_clipped_event_counts": clipped_counts,
        "high_embellishment": {
            "track": HIGH_TRACK,
            "event_count": len(high_events),
            "mapping": high_mapping,
            "new_pitch_classes": False,
        },
        "percussion": _percussion_report(percussion),
        "normalized": normalized,
        "arrangement_midi": str(ARRANGEMENT_MIDI),
        "arrangement_midi_sha256": sha256(ARRANGEMENT_MIDI),
        "arrangement_note_counts": counts,
        "previous_version_hashes_unchanged": previous_hashes,
    }
    write_json(BUILD_REPORT, report)
    print(json.dumps(report, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
