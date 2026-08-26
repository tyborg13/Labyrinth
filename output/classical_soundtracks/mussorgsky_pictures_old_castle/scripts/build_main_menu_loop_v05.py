#!/usr/bin/env python3
"""Build the v05 Old Castle intro-plus-loop taste audition."""

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
from tools.classical_soundtrack_pipeline.normalization import write_normalized_score  # noqa: E402


def _load_v04_builder():
    path = TRACK_ROOT / "scripts" / "build_main_menu_loop_v04.py"
    spec = importlib.util.spec_from_file_location("old_castle_main_menu_v04", path)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"Could not load the v04 main-menu builder at {path}")
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


V04 = _load_v04_builder()
V03 = V04.V03
FULL = V04.FULL

CONFIG_PATH = TRACK_ROOT / "track.v05.json"
VERSION_DIR = TRACK_ROOT / "versions" / "v05"
NORMALIZED_DIR = VERSION_DIR / "normalized"
ARRANGEMENT_MIDI = VERSION_DIR / "arrangement.mid"
LOOP_MIDI = VERSION_DIR / "loop.mid"
BUILD_REPORT = VERSION_DIR / "BUILD_REPORT.json"

EXPECTED_V04_CONFIG_SHA256 = "7a7ea03106a0504961af7818abf57605c559c79dc6ca9434e26326c56c11ed27"
EXPECTED_V04_BUILDER_SHA256 = "61b178eea878d1e277a1d2745aa57d34618288cbcfcc22b8dfd9d5dcd82c316b"
EXPECTED_V04_VERSION_HASHES = {
    "ARRANGEMENT_NOTES.md": "2eef717c6b6b832e1fded843e02be22adac780ca8ad59ef1dcd134d6fef2ce48",
    "BUILD_REPORT.json": "e75ea544c9ebebd5a474067ecf15f7c1db496d054e6efc610940aef39ec5eb58",
    "arrangement.mid": "50327866f27925c5e1c54c6994003a6c20f550c1e892d1f0956393ae9177c54e",
    "normalized/full_score.mid": "4a3b7fc174b4c9ac2cd78e4343e8e3bd53b53796e63aeebd98af2e9b975582b2",
    "normalized/full_score.musicxml": "a9ee362794489611660b9d370a66d42d56eb6895232043917d064caf2ec032a2",
    "normalized/parts/01_veiled_violin_castle_air.mid": "a05163e503978f5c256d679b7c4743116900b1fbfbd7d3e82b5dc0b2623df4c8",
    "normalized/parts/01_veiled_violin_castle_air.musicxml": "48dedcfec69df8b642107dca98fd13d5e47538af9df36b15165f6727e89d640f",
    "normalized/parts/02_ashen_violin_inner_voice.mid": "d8454a8e3ae22e96ebfc7149cfbe00c8fcaa4dfc3fbb8a85b36520a4dd5028fc",
    "normalized/parts/02_ashen_violin_inner_voice.musicxml": "584b7a55b720e7d2918fcb5b3a4bf2681d759eae393e12162af4043d7cf9bafe",
    "normalized/parts/03_hollow_viola_lower_harmony.mid": "cb302f5f2de25933531316308d5617baba25955ca71e61334680fe208c30d605",
    "normalized/parts/03_hollow_viola_lower_harmony.musicxml": "1444d740630054693ca697f6a89ce6b1bad4c696c020dac247ce8ed337c64aff",
    "normalized/parts/04_grave_cello_troubadour.mid": "e583dace8e7ffbcc087c5abf8dd2ae500d72422d937e94657670cb8439410774",
    "normalized/parts/04_grave_cello_troubadour.musicxml": "4c7e3f8c9afb59d58440c110c5b38893e94613f54a2e52acab540fea7618b7ab",
    "normalized/parts/05_undercrypt_bass_g_sharp_pedal.mid": "3ce2055e2ab67703df056e33140b77304c1092114813c496d8b9d64be334d4e6",
    "normalized/parts/05_undercrypt_bass_g_sharp_pedal.musicxml": "46b4de510095e6197f84cb37aa575674c70d60bd68ef24961b329f4cb7b596de",
    "preview.flac": "98cacc34510f885b2f27f5850f806c057f8ac863a082ac0e1861b106cafe4797",
    "preview.ogg": "425441d26f8106f323fbf35325ab204fb6e2477be159d63dce1f639400e8c22e",
    "preview.render.json": "82fecf5c396d4da357ede2b0b9d25bdd9bacfadcee14657ec0f35fc52471e9df",
}

TICKS_PER_BEAT = V03.TICKS_PER_BEAT
MEASURE_TICKS = V03.MEASURE_TICKS
LOOP_TICKS = V03.TOTAL_TICKS
TEMPO_QPM = V03.TEMPO_QPM
INTRO_MEASURES = 4
INTRO_TICKS = INTRO_MEASURES * MEASURE_TICKS
AUDITION_TICKS = INTRO_TICKS + LOOP_TICKS

BASE_TRACKS = V03.BASE_TRACKS
VEIL_TRACK = "Umbra Veil / G-sharp-D-sharp Breath"
PERCUSSION_TRACK = V03.PERCUSSION_TRACK
MUSICAL_TRACKS = (*BASE_TRACKS, VEIL_TRACK)

# Phrase boundaries follow the melodic rests, sustained arrivals, and returns in
# the selected printed measures rather than an arbitrary fixed bar grid.
PHRASES = (
    (7, 18),
    (19, 28),
    (29, 37),
    (38, 46),
    (47, 50),
    (51, 60),
    (61, 68),
)


def _verify_preserved_versions() -> dict[str, object]:
    preserved: dict[str, object] = {"v01_v03": V04._verify_preserved_versions()}
    version_dir = TRACK_ROOT / "versions" / "v04"
    actual_files = sorted(
        path.relative_to(version_dir).as_posix()
        for path in version_dir.rglob("*")
        if path.is_file()
    )
    if actual_files != sorted(EXPECTED_V04_VERSION_HASHES):
        raise RuntimeError(f"v05 must not alter the v04 artifact tree: {actual_files}")
    actual_hashes: dict[str, str] = {}
    for relative, expected in EXPECTED_V04_VERSION_HASHES.items():
        path = version_dir / relative
        actual_hashes[relative] = sha256(path)
        if actual_hashes[relative] != expected:
            raise RuntimeError(f"v05 must not modify v04 audition artifact {path}")
    if sha256(TRACK_ROOT / "track.v04.json") != EXPECTED_V04_CONFIG_SHA256:
        raise RuntimeError("The v04 audition config drifted before the v05 build")
    if sha256(TRACK_ROOT / "scripts" / "build_main_menu_loop_v04.py") != EXPECTED_V04_BUILDER_SHA256:
        raise RuntimeError("The v04 audition builder drifted before the v05 build")
    preserved["v04"] = actual_hashes
    return preserved


def _note(start: int, end: int, pitch: int, velocity: int):
    return FULL.ArrangementNote(start=start, end=end, pitch=pitch, velocity=velocity)


def _shift(events, ticks: int):
    return [
        _note(event.start + ticks, event.end + ticks, event.pitch, event.velocity)
        for event in events
    ]


def _veil_events():
    output = []
    base_velocities = (21, 19, 24, 22, 20, 23, 25)
    fifth_velocities = (15, 14, 17, 16, 14, 16, 18)
    mapping = []
    for index, (start_measure, end_measure) in enumerate(PHRASES):
        start = (start_measure - V03.SOURCE_START_MEASURE) * MEASURE_TICKS
        end = (end_measure - V03.SOURCE_START_MEASURE + 1) * MEASURE_TICKS
        fifth_start_measure = min(start_measure + 2, end_measure - 1)
        fifth_end_measure = max(fifth_start_measure + 1, end_measure)
        fifth_start = (fifth_start_measure - V03.SOURCE_START_MEASURE) * MEASURE_TICKS
        fifth_end = (fifth_end_measure - V03.SOURCE_START_MEASURE) * MEASURE_TICKS
        output.extend((
            _note(start, end, 44, base_velocities[index]),  # G-sharp2
            _note(fifth_start, fifth_end, 51, fifth_velocities[index]),  # D-sharp3
        ))
        mapping.append({
            "source_printed_measures": [start_measure, end_measure],
            "g_sharp_2_ticks": [start, end],
            "d_sharp_3_ticks": [fifth_start, fifth_end],
            "function": "tonic pedal with a later-entering dominant breath",
        })
    return sorted(output, key=lambda event: (event.start, event.pitch)), mapping


def _phrase_percussion():
    starts = {start for start, _ in PHRASES}
    approaches = {end - 1 for _, end in PHRASES}
    cadences = {end for _, end in PHRASES}
    output = []
    measure_map = []
    for source_measure in range(V03.SOURCE_START_MEASURE, V03.SOURCE_END_MEASURE_EXCLUSIVE):
        start = (source_measure - V03.SOURCE_START_MEASURE) * MEASURE_TICKS
        if source_measure in starts:
            role = "phrase opening"
            pattern = ((0, 180, 36, 66, "opening war drum"),
                       (480, 540, 42, 23, "opening first-group ash tick"),
                       (720, 840, 41, 46, "opening dotted-beat tom"),
                       (1200, 1260, 42, 25, "opening second-group ash tick"))
        elif source_measure in approaches:
            role = "cadence approach"
            pattern = ((0, 180, 36, 63, "approach war drum"),
                       (480, 540, 42, 25, "approach first-group ash tick"),
                       (720, 840, 41, 45, "approach dotted-beat tom"),
                       (1200, 1260, 42, 27, "approach second-group ash tick"))
        elif source_measure in cadences:
            role = "cadence breath"
            pattern = ((0, 180, 36, 54, "cadence war drum"),)
        else:
            role = "phrase motion"
            tick_offset = 480 if source_measure % 2 == 0 else 1200
            tick_group = "first" if tick_offset == 480 else "second"
            pattern = ((0, 180, 36, 60, "motion war drum"),
                       (720, 840, 41, 42, "motion dotted-beat tom"),
                       (tick_offset, tick_offset + 60, 42, 23, f"motion {tick_group}-group ash tick"))
        for offset, end_offset, pitch, velocity, event_role in pattern:
            output.append(V03.PercussionEvent(
                start=start + offset,
                end=start + end_offset,
                pitch=pitch,
                velocity=velocity,
                role=event_role,
            ))
        measure_map.append({
            "source_measure": source_measure,
            "phrase_role": role,
            "event_count": len(pattern),
        })
    return sorted(output, key=lambda event: (event.start, event.pitch)), measure_map


def _audition_strings(loop_strings, veil):
    output = {name: _shift(loop_strings[name], INTRO_TICKS) for name in BASE_TRACKS}
    opening = sorted(loop_strings[BASE_TRACKS[0]], key=lambda event: (event.start, event.pitch))[:2]
    intro_cello = [
        _note(
            event.start + 2 * MEASURE_TICKS,
            event.end + 2 * MEASURE_TICKS,
            event.pitch - 12,
            38 + index * 3,
        )
        for index, event in enumerate(opening)
    ]
    output[BASE_TRACKS[3]] = sorted(
        [*intro_cello, *output[BASE_TRACKS[3]]], key=lambda event: (event.start, event.pitch)
    )

    shifted_veil = _shift(veil, INTRO_TICKS)
    first_g_sharp = shifted_veil[0]
    shifted_veil[0] = _note(0, first_g_sharp.end, first_g_sharp.pitch, first_g_sharp.velocity)
    intro_d_sharp = _note(MEASURE_TICKS, 3 * MEASURE_TICKS, 51, 13)
    output[VEIL_TRACK] = sorted(
        [intro_d_sharp, *shifted_veil], key=lambda event: (event.start, event.pitch)
    )
    return output, intro_cello


def _intro_percussion():
    return [
        V03.PercussionEvent(2 * MEASURE_TICKS, 2 * MEASURE_TICKS + 180, 36, 34, "intro distant war drum"),
        V03.PercussionEvent(3 * MEASURE_TICKS, 3 * MEASURE_TICKS + 180, 36, 44, "intro entering war drum"),
        V03.PercussionEvent(3 * MEASURE_TICKS + 720, 3 * MEASURE_TICKS + 840, 41, 30, "intro entering tom"),
        V03.PercussionEvent(3 * MEASURE_TICKS + 1200, 3 * MEASURE_TICKS + 1260, 42, 18, "intro final ash tick"),
    ]


def _midi_track(track_name: str, channel: int, events, total_ticks: int):
    volumes = (82, 74, 76, 90, 80, 62)
    pans = (82, 42, 70, 54, 64, 64)
    track = mido.MidiTrack()
    track.append(mido.MetaMessage("track_name", name=track_name, time=0))
    track.append(mido.Message("control_change", channel=channel, control=7, value=volumes[channel], time=0))
    track.append(mido.Message("control_change", channel=channel, control=10, value=pans[channel], time=0))
    scheduled = []
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
    track.append(mido.MetaMessage("end_of_track", time=max(0, total_ticks - previous)))
    return track


def _percussion_track(events, total_ticks: int):
    track = mido.MidiTrack()
    track.append(mido.MetaMessage("track_name", name=PERCUSSION_TRACK, time=0))
    track.append(mido.MetaMessage(
        "instrument_name",
        name="Canonical procedural one-shots; GM percussion notes are fallback mapping only",
        time=0,
    ))
    scheduled = []
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
    track.append(mido.MetaMessage("end_of_track", time=max(0, total_ticks - previous)))
    return track


def _write_midi(path: Path, strings, percussion, total_ticks: int, audition: bool):
    path.parent.mkdir(parents=True, exist_ok=True)
    midi = mido.MidiFile(type=1, ticks_per_beat=TICKS_PER_BEAT)
    conductor = mido.MidiTrack()
    conductor.append(mido.MetaMessage(
        "track_name", name="Conductor / Intro and Main Menu Loop" if audition else "Conductor / Main Menu Loop", time=0
    ))
    conductor.append(mido.MetaMessage(
        "copyright",
        text="Mussorgsky composition: public domain. PDMX source: CC0. Arrangement created for Escape the Umbra.",
        time=0,
    ))
    conductor.append(mido.MetaMessage("time_signature", numerator=6, denominator=8, time=0))
    conductor.append(mido.MetaMessage("key_signature", key="B", time=0))
    conductor.append(mido.MetaMessage("set_tempo", tempo=mido.bpm2tempo(TEMPO_QPM), time=0))
    if audition:
        conductor.append(mido.MetaMessage("marker", text="INTRO_START", time=0))
        conductor.append(mido.MetaMessage("marker", text="LOOP_START / source printed m7", time=INTRO_TICKS))
        conductor.append(mido.MetaMessage("marker", text="AUDITION_END / source printed m68", time=LOOP_TICKS))
    else:
        conductor.append(mido.MetaMessage("marker", text="LOOP_START / source printed m7", time=0))
        conductor.append(mido.MetaMessage("marker", text="LOOP_END / after source printed m68", time=LOOP_TICKS))
    conductor.append(mido.MetaMessage("end_of_track", time=0))
    midi.tracks.append(conductor)
    for channel, track_name in enumerate(MUSICAL_TRACKS):
        midi.tracks.append(_midi_track(track_name, channel, strings[track_name], total_ticks))
    midi.tracks.append(_percussion_track(percussion, total_ticks))
    midi.save(path)
    return {
        **{name: len(strings[name]) for name in MUSICAL_TRACKS},
        PERCUSSION_TRACK: len(percussion),
    }


def _event_signature(events):
    return [(event.start, event.end, event.pitch, event.velocity) for event in events]


def main() -> int:
    previous_hashes = _verify_preserved_versions()
    config = read_json(CONFIG_PATH)
    verify_source_clearance(config, CONFIG_PATH)
    staves, source_report = FULL._load_source()
    full_events = FULL._arrangement_events(staves)
    base_strings, clipped_counts = V03._crop_base_events(full_events)
    veil, veil_mapping = _veil_events()
    loop_strings = {**base_strings, VEIL_TRACK: veil}
    percussion, percussion_map = _phrase_percussion()

    V03.MUSICAL_TRACKS = BASE_TRACKS
    normalized = write_normalized_score(
        V03._normalized_score(base_strings), NORMALIZED_DIR, expand_repeats=False
    )
    FULL._stabilize_normalized_musicxml(normalized)
    loop_counts = _write_midi(LOOP_MIDI, loop_strings, percussion, LOOP_TICKS, audition=False)

    audition_strings, intro_cello = _audition_strings(base_strings, veil)
    audition_percussion = sorted(
        [*_intro_percussion(), *_shift(percussion, INTRO_TICKS)],
        key=lambda event: (event.start, event.pitch),
    )
    audition_counts = _write_midi(
        ARRANGEMENT_MIDI, audition_strings, audition_percussion, AUDITION_TICKS, audition=True
    )

    melody_checks = {}
    for track_name in BASE_TRACKS:
        loop_signature = _event_signature(base_strings[track_name])
        shifted_audition = [
            event for event in audition_strings[track_name]
            if event.start >= INTRO_TICKS and event not in intro_cello
        ]
        shifted_signature = [
            (event.start - INTRO_TICKS, event.end - INTRO_TICKS, event.pitch, event.velocity)
            for event in shifted_audition
        ]
        melody_checks[track_name] = {
            "loop_event_count": len(loop_signature),
            "audition_loop_event_count": len(shifted_signature),
            "event_for_event_equal_after_intro_shift": shifted_signature == loop_signature,
        }
        if shifted_signature != loop_signature:
            raise RuntimeError(f"v05 changed v04 loop events for {track_name}")

    percussion_counts = defaultdict(int)
    for event in percussion:
        percussion_counts[event.role] += 1
    report = {
        "ok": True,
        "version": "v05",
        "purpose": "Main-menu identity pass with one-time intro, phrase-aware pulse, and Umbra veil",
        "selection": {
            "loop_source_printed_measures": [V03.SOURCE_START_MEASURE, V03.SOURCE_END_MEASURE_EXCLUSIVE - 1],
            "loop_measure_count": V03.MEASURE_COUNT,
            "ordering": "unchanged contiguous v04 loop following a new four-measure intro",
        },
        "tempo_qpm": TEMPO_QPM,
        "durations": {
            "intro_seconds": INTRO_TICKS / TICKS_PER_BEAT * 60.0 / TEMPO_QPM,
            "loop_structural_seconds": LOOP_TICKS / TICKS_PER_BEAT * 60.0 / TEMPO_QPM,
            "combined_audition_seconds": AUDITION_TICKS / TICKS_PER_BEAT * 60.0 / TEMPO_QPM,
        },
        "intro": {
            "measure_count": INTRO_MEASURES,
            "cello_note_count": len(intro_cello),
            "cello_derivation": "first two Castle Air notes, exact relative rhythm, one octave lower",
            "veil": "G-sharp2 begins immediately; D-sharp3 enters in measure 2",
            "percussion_event_count": len(_intro_percussion()),
        },
        "melody_preservation": melody_checks,
        "base_event_counts": {name: len(base_strings[name]) for name in BASE_TRACKS},
        "boundary_clipped_event_counts": clipped_counts,
        "umbra_veil": {
            "track": VEIL_TRACK,
            "event_count": len(veil),
            "pitches": ["G#2", "D#3"],
            "pitch_classes_already_present_in_source": True,
            "phrase_mapping": veil_mapping,
        },
        "percussion": {
            "track": PERCUSSION_TRACK,
            "loop_event_count": len(percussion),
            "v04_loop_event_count": 248,
            "counts_by_role": dict(sorted(percussion_counts.items())),
            "measure_map": percussion_map,
            "design": "opening lift, alternating three-hit motion, four-hit cadence approach, one-hit cadence breath",
        },
        "base_source": source_report,
        "normalized": normalized,
        "loop_midi": str(LOOP_MIDI),
        "loop_midi_sha256": sha256(LOOP_MIDI),
        "loop_note_counts": loop_counts,
        "arrangement_midi": str(ARRANGEMENT_MIDI),
        "arrangement_midi_sha256": sha256(ARRANGEMENT_MIDI),
        "arrangement_note_counts": audition_counts,
        "previous_version_hashes_unchanged": previous_hashes,
    }
    write_json(BUILD_REPORT, report)
    print(json.dumps(report, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
