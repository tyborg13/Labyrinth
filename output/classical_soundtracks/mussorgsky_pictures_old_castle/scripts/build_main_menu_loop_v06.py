#!/usr/bin/env python3
"""Build v06 as v04 plus one isolated, audible low-mid Umbra veil."""

from __future__ import annotations

import importlib.util
import json
from pathlib import Path
import sys

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


def _load_v05_builder():
    path = TRACK_ROOT / "scripts" / "build_main_menu_loop_v05.py"
    spec = importlib.util.spec_from_file_location("old_castle_main_menu_v05", path)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"Could not load the v05 main-menu builder at {path}")
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


V05 = _load_v05_builder()
V04 = V05.V04
V03 = V05.V03
FULL = V05.FULL

CONFIG_PATH = TRACK_ROOT / "track.v06.json"
VERSION_DIR = TRACK_ROOT / "versions" / "v06"
NORMALIZED_DIR = VERSION_DIR / "normalized"
ARRANGEMENT_MIDI = VERSION_DIR / "arrangement.mid"
BUILD_REPORT = VERSION_DIR / "BUILD_REPORT.json"

EXPECTED_V05_CONFIG_SHA256 = "494964527a03f631eef7d5ca1e4bbff12498f345eb1fdae2579f48a828e88bd5"
EXPECTED_V05_BUILDER_SHA256 = "a66333d67d11b6838b7924c950e8bbdf34dac0c72b532d011e10c03e82d14c4b"
EXPECTED_V05_VERSION_HASHES = {
    "ARRANGEMENT_NOTES.md": "a3349b506345f08a831dbc768abbfa83caff56428404d3af26ff64a2795b4006",
    "BUILD_REPORT.json": "87e3114704ca2e444ab0b37a3be131fbdbd961c9ee0d6c409e24e59ad9877171",
    "arrangement.mid": "e772c933d9a0f293324b8c4fd804210747ec03ba0c09a947abf42ba3f9810aa8",
    "loop.mid": "587085504605c3e4ec7d9d1713041d77ea775b116d407a3de3bbee24473e730a",
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
    "preview.flac": "c36044262dd466cc75eef562d95ce3fc391f000789a47ecfa4cff087937d9862",
    "preview.ogg": "c504497ec1bf124504f6dc38c8da460009a7ea2213041d1a3371e568d326f824",
    "preview.render.json": "d70526b339820244ffa6bbfda0cca017c4f53d58aa14a41b2ff2d5228f8fe926",
}

BASE_TRACKS = V03.BASE_TRACKS
VEIL_TRACK = "Umbra Veil / Low-Mid G-sharp-D-sharp Breath"
MUSICAL_TRACKS = (*BASE_TRACKS, VEIL_TRACK)

BASE_VELOCITIES = (34, 32, 38, 36, 33, 37, 40)
FIFTH_VELOCITIES = (26, 24, 30, 28, 25, 29, 32)


def _verify_preserved_versions() -> dict[str, object]:
    preserved: dict[str, object] = {"v01_v04": V05._verify_preserved_versions()}
    version_dir = TRACK_ROOT / "versions" / "v05"
    actual_files = sorted(
        path.relative_to(version_dir).as_posix()
        for path in version_dir.rglob("*")
        if path.is_file()
    )
    if actual_files != sorted(EXPECTED_V05_VERSION_HASHES):
        raise RuntimeError(f"v06 must not alter the v05 artifact tree: {actual_files}")
    actual_hashes = {}
    for relative, expected in EXPECTED_V05_VERSION_HASHES.items():
        path = version_dir / relative
        actual_hashes[relative] = sha256(path)
        if actual_hashes[relative] != expected:
            raise RuntimeError(f"v06 must not modify v05 audition artifact {path}")
    if sha256(TRACK_ROOT / "track.v05.json") != EXPECTED_V05_CONFIG_SHA256:
        raise RuntimeError("The v05 audition config drifted before the v06 build")
    if sha256(TRACK_ROOT / "scripts" / "build_main_menu_loop_v05.py") != EXPECTED_V05_BUILDER_SHA256:
        raise RuntimeError("The v05 audition builder drifted before the v06 build")
    preserved["v05"] = actual_hashes
    return preserved


def _veil_events():
    source_events, source_mapping = V05._veil_events()
    events = []
    mapping = []
    phrase_index_by_start = {
        (start_measure - V03.SOURCE_START_MEASURE) * V03.MEASURE_TICKS: index
        for index, (start_measure, _) in enumerate(V05.PHRASES)
    }
    fifth_index_by_start = {
        entry["d_sharp_3_ticks"][0]: index for index, entry in enumerate(source_mapping)
    }
    for event in source_events:
        if event.pitch == 44:
            phrase_index = phrase_index_by_start[event.start]
            pitch = 56  # G-sharp3
            velocity = BASE_VELOCITIES[phrase_index]
            role = "G-sharp3 phrase pedal"
        else:
            phrase_index = fifth_index_by_start[event.start]
            pitch = 63  # D-sharp4
            velocity = FIFTH_VELOCITIES[phrase_index]
            role = "D-sharp4 later-entering dominant"
        events.append(FULL.ArrangementNote(
            start=event.start,
            end=event.end,
            pitch=pitch,
            velocity=velocity,
        ))
        mapping.append({
            "phrase": phrase_index + 1,
            "source_printed_measures": source_mapping[phrase_index]["source_printed_measures"],
            "start_tick": event.start,
            "end_tick": event.end,
            "pitch": FULL._pitch_name(pitch),
            "velocity": velocity,
            "role": role,
        })
    return sorted(events, key=lambda event: (event.start, event.pitch)), mapping


def _signature(events):
    return [(event.start, event.end, event.pitch, event.velocity) for event in events]


def main() -> int:
    previous_hashes = _verify_preserved_versions()
    config = read_json(CONFIG_PATH)
    verify_source_clearance(config, CONFIG_PATH)
    staves, source_report = FULL._load_source()
    full_events = FULL._arrangement_events(staves)
    base_strings, clipped_counts = V03._crop_base_events(full_events)
    veil, veil_mapping = _veil_events()
    strings = {**base_strings, VEIL_TRACK: veil}
    percussion = V04._lift_percussion(V03._percussion_events())

    V03.MUSICAL_TRACKS = BASE_TRACKS
    normalized = write_normalized_score(
        V03._normalized_score(base_strings), NORMALIZED_DIR, expand_repeats=False
    )
    FULL._stabilize_normalized_musicxml(normalized)

    V05.MUSICAL_TRACKS = MUSICAL_TRACKS
    counts = V05._write_midi(
        ARRANGEMENT_MIDI, strings, percussion, V03.TOTAL_TICKS, audition=False
    )

    v04_percussion = V04._lift_percussion(V03._percussion_events())
    percussion_equal = _signature(percussion) == _signature(v04_percussion)
    if not percussion_equal:
        raise RuntimeError("v06 percussion drifted from v04")
    melody_checks = {}
    for track_name in BASE_TRACKS:
        expected = V03._crop_base_events(full_events)[0][track_name]
        equal = _signature(base_strings[track_name]) == _signature(expected)
        melody_checks[track_name] = {
            "event_count": len(base_strings[track_name]),
            "event_for_event_equal_to_v04": equal,
        }
        if not equal:
            raise RuntimeError(f"v06 changed v04 source events for {track_name}")

    report = {
        "ok": True,
        "version": "v06",
        "purpose": "Controlled v04 A/B with only an audible slow low-mid Umbra veil added",
        "selection": {
            "source_printed_measures": [V03.SOURCE_START_MEASURE, V03.SOURCE_END_MEASURE_EXCLUSIVE - 1],
            "measure_count": V03.MEASURE_COUNT,
            "intro_measures": 0,
            "ordering": "exact v04 contiguous selection",
        },
        "tempo_qpm": V03.TEMPO_QPM,
        "melody_preservation": melody_checks,
        "percussion": {
            "event_count": len(percussion),
            "event_for_event_equal_to_v04": percussion_equal,
            "pattern": "v04 uniform four-hit 6/8 pulse restored exactly",
        },
        "umbra_veil": {
            "track": VEIL_TRACK,
            "event_count": len(veil),
            "pitches": ["G#3", "D#4"],
            "change_from_v05": "one octave higher, substantially stronger velocities, hollow-viola timbre and higher render gain",
            "mapping": veil_mapping,
        },
        "base_source": source_report,
        "boundary_clipped_event_counts": clipped_counts,
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
