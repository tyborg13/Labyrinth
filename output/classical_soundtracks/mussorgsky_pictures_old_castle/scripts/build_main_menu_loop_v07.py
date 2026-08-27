#!/usr/bin/env python3
"""Build the owner-approved v06 music as the promotion-ready v07 loop."""

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


def _load_v06_builder():
    path = TRACK_ROOT / "scripts" / "build_main_menu_loop_v06.py"
    spec = importlib.util.spec_from_file_location("old_castle_main_menu_v06", path)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"Could not load the v06 main-menu builder at {path}")
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


V06 = _load_v06_builder()
V05 = V06.V05
V04 = V06.V04
V03 = V06.V03
FULL = V06.FULL

CONFIG_PATH = TRACK_ROOT / "track.v07.json"
VERSION_DIR = TRACK_ROOT / "versions" / "v07"
NORMALIZED_DIR = VERSION_DIR / "normalized"
ARRANGEMENT_MIDI = VERSION_DIR / "arrangement.mid"
BUILD_REPORT = VERSION_DIR / "BUILD_REPORT.json"

EXPECTED_V06_CONFIG_SHA256 = "ef76aced77b417317693a005c126e884b52be6e02aab30dccd425aad5855b6e5"
EXPECTED_V06_BUILDER_SHA256 = "b6437bfde0011aab2d43f801b055f8bb5fc10d4b7cf7d8866e77b82255d1c4f3"
EXPECTED_V06_VERSION_HASHES = {
    "ARRANGEMENT_NOTES.md": "69082755ade20f59e0fbbdc4347739e0f12da8e8467996f776e06ec060cac6ed",
    "BUILD_REPORT.json": "ca53c5f0af8fcfb136247bf894f8f995ea275f236c4143efe5c1da212224d4cb",
    "arrangement.mid": "87ee823295e323dd8661361180af30ba5969e3c3dbe9413e0d0032681cb1ac5c",
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
    "preview.flac": "0f8c00c99c77e220614f2b1f6a120dbc2e1246938eaa8b4b6900c7040a425030",
    "preview.ogg": "77ef7e0635488a3a44bb9e035b3ed6d6676f3e2f06c75a87631eb91e66908ab8",
    "preview.render.json": "d9e3bb74fdb5fdd259c76c09a0ec25415069c28ca642720a17d1365909454faf",
}


def _verify_preserved_versions() -> dict[str, object]:
    preserved: dict[str, object] = {"v01_v05": V06._verify_preserved_versions()}
    version_dir = TRACK_ROOT / "versions" / "v06"
    actual_files = sorted(
        path.relative_to(version_dir).as_posix()
        for path in version_dir.rglob("*")
        if path.is_file()
    )
    if actual_files != sorted(EXPECTED_V06_VERSION_HASHES):
        raise RuntimeError(f"v07 must not alter the v06 artifact tree: {actual_files}")
    actual_hashes = {}
    for relative, expected in EXPECTED_V06_VERSION_HASHES.items():
        path = version_dir / relative
        actual_hashes[relative] = sha256(path)
        if actual_hashes[relative] != expected:
            raise RuntimeError(f"v07 must not modify approved v06 audition artifact {path}")
    if sha256(TRACK_ROOT / "track.v06.json") != EXPECTED_V06_CONFIG_SHA256:
        raise RuntimeError("The approved v06 audition config drifted before the v07 build")
    if sha256(TRACK_ROOT / "scripts" / "build_main_menu_loop_v06.py") != EXPECTED_V06_BUILDER_SHA256:
        raise RuntimeError("The approved v06 audition builder drifted before the v07 build")
    preserved["v06"] = actual_hashes
    return preserved


def main() -> int:
    previous_hashes = _verify_preserved_versions()
    config = read_json(CONFIG_PATH)
    verify_source_clearance(config, CONFIG_PATH)
    staves, source_report = FULL._load_source()
    full_events = FULL._arrangement_events(staves)
    base_strings, clipped_counts = V03._crop_base_events(full_events)
    veil, veil_mapping = V06._veil_events()
    strings = {**base_strings, V06.VEIL_TRACK: veil}
    percussion = V04._lift_percussion(V03._percussion_events())

    V03.MUSICAL_TRACKS = V06.BASE_TRACKS
    normalized = V06.write_normalized_score(
        V03._normalized_score(base_strings), NORMALIZED_DIR, expand_repeats=False
    )
    FULL._stabilize_normalized_musicxml(normalized)

    V05.MUSICAL_TRACKS = V06.MUSICAL_TRACKS
    counts = V05._write_midi(
        ARRANGEMENT_MIDI, strings, percussion, V03.TOTAL_TICKS, audition=False
    )
    midi_hash = sha256(ARRANGEMENT_MIDI)
    if midi_hash != EXPECTED_V06_VERSION_HASHES["arrangement.mid"]:
        raise RuntimeError("v07 must preserve every approved v06 MIDI event byte-for-byte")

    report = {
        "ok": True,
        "version": "v07",
        "purpose": "Promotion candidate preserving owner-approved v06 music exactly",
        "selection": {
            "source_printed_measures": [V03.SOURCE_START_MEASURE, V03.SOURCE_END_MEASURE_EXCLUSIVE - 1],
            "measure_count": V03.MEASURE_COUNT,
            "intro_measures": 0,
            "ordering": "exact approved v06 contiguous selection",
        },
        "tempo_qpm": V03.TEMPO_QPM,
        "musical_content": {
            "event_for_event_equal_to_v06": True,
            "midi_byte_for_byte_equal_to_v06": True,
            "v06_midi_sha256": EXPECTED_V06_VERSION_HASHES["arrangement.mid"],
            "percussion": "v04 uniform four-hit 6/8 pulse, preserved through v06",
            "umbra_veil": {
                "track": V06.VEIL_TRACK,
                "event_count": len(veil),
                "mapping": veil_mapping,
            },
        },
        "base_source": source_report,
        "boundary_clipped_event_counts": clipped_counts,
        "normalized": normalized,
        "arrangement_midi": str(ARRANGEMENT_MIDI),
        "arrangement_midi_sha256": midi_hash,
        "arrangement_note_counts": counts,
        "previous_version_hashes_unchanged": previous_hashes,
    }
    write_json(BUILD_REPORT, report)
    print(json.dumps(report, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
