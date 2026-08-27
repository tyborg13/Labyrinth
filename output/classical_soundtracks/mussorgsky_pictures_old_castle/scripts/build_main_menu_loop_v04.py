#!/usr/bin/env python3
"""Build the v04 Old Castle main-menu taste revision."""

from __future__ import annotations

from collections import defaultdict
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


def _load_v03_builder():
    path = TRACK_ROOT / "scripts" / "build_main_menu_loop.py"
    spec = importlib.util.spec_from_file_location("old_castle_main_menu_v03", path)
    if spec is None or spec.loader is None:
        raise RuntimeError(f"Could not load the v03 main-menu builder at {path}")
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


V03 = _load_v03_builder()
FULL = V03.FULL

CONFIG_PATH = TRACK_ROOT / "track.v04.json"
VERSION_DIR = TRACK_ROOT / "versions" / "v04"
NORMALIZED_DIR = VERSION_DIR / "normalized"
ARRANGEMENT_MIDI = VERSION_DIR / "arrangement.mid"
BUILD_REPORT = VERSION_DIR / "BUILD_REPORT.json"

EXPECTED_V03_CONFIG_SHA256 = "3c49063655415400cc9be3dc25685f41c48dc4abc0a83810eae955914666934e"
EXPECTED_V03_BUILDER_SHA256 = "cd984aede968df46e3f5fe627c19218d67f2934f5e81a45ea9605dec244b1fee"
EXPECTED_V03_VERSION_HASHES = {
    "ARRANGEMENT_NOTES.md": "da3cad3c1cd0ed035b3a6f6630587177a8072662ddc99fe08b14b8f918ff4789",
    "BUILD_REPORT.json": "2eabaf338a0c6d13e99f9fec8d37b1a3ac1fbbbbc40da30872dc88ecbb92f08d",
    "arrangement.mid": "3401715f71323a7ed665052d2e61f041ebeebce2c3abc9a009b71ffcacf4d568",
    "normalized/full_score.mid": "fc1064b776e782f6f6310954e281bbadfce71aeafac834bc28786b396a8cf363",
    "normalized/full_score.musicxml": "1d3b4c16ece92a3c767ae644e01a690632ba104468fd82ea607a58b00f5df29e",
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
    "normalized/parts/06_wraithlight_violin_high_embellishment.mid": "a80b221c947d54a333b0c53d1e2560dabf8e4e4b2005a5c66687aa34afca7807",
    "normalized/parts/06_wraithlight_violin_high_embellishment.musicxml": "f3bc4b05a51427206f6418113af12bbac8797fd73a50d5bbbf3194e4c2c73222",
    "preview.flac": "f9f63c22f28cbf690e50139e1398b0c7546a20539de90b75609ea9508d10fa5d",
    "preview.ogg": "e110e3cae1f02d45aa05f3e18527a1b34e257dc285f0954dc983637e158bf01b",
    "preview.render.json": "555e595fc48ee58608e39ef220c4c18fa4d1c3a2e711ec6c532f749fd1a723ad",
}

VELOCITY_LIFTS = {
    36: 6,  # war drum
    41: 5,  # bone tom
    42: 3,  # ash tick
}


def _verify_preserved_versions() -> dict[str, object]:
    preserved: dict[str, object] = {"v01_v02": V03._verify_previous_versions()}
    version_dir = TRACK_ROOT / "versions" / "v03"
    actual_files = sorted(
        path.relative_to(version_dir).as_posix()
        for path in version_dir.rglob("*")
        if path.is_file()
    )
    if actual_files != sorted(EXPECTED_V03_VERSION_HASHES):
        raise RuntimeError(f"v04 must not alter the v03 artifact tree: {actual_files}")
    actual_hashes: dict[str, str] = {}
    for relative, expected in EXPECTED_V03_VERSION_HASHES.items():
        path = version_dir / relative
        actual_hashes[relative] = sha256(path)
        if actual_hashes[relative] != expected:
            raise RuntimeError(f"v04 must not modify v03 audition artifact {path}")
    if sha256(TRACK_ROOT / "track.v03.json") != EXPECTED_V03_CONFIG_SHA256:
        raise RuntimeError("The v03 audition config drifted before the v04 build")
    if sha256(TRACK_ROOT / "scripts" / "build_main_menu_loop.py") != EXPECTED_V03_BUILDER_SHA256:
        raise RuntimeError("The v03 audition builder drifted before the v04 build")
    preserved["v03"] = actual_hashes
    return preserved


def _lift_percussion(events):
    return [
        V03.PercussionEvent(
            start=event.start,
            end=event.end,
            pitch=event.pitch,
            velocity=min(127, event.velocity + VELOCITY_LIFTS[event.pitch]),
            role=event.role,
        )
        for event in events
    ]


def _percussion_report(events) -> dict[str, object]:
    counts: dict[str, int] = defaultdict(int)
    ranges: dict[str, list[int]] = defaultdict(list)
    for event in events:
        counts[event.role] += 1
        ranges[event.role].append(event.velocity)
    return {
        "channel_zero_based": 9,
        "description": (
            "The unchanged v03 four-hit 6/8 pattern, moved slightly forward only by "
            "raising war-drum velocities by 6, tom velocities by 5, and ash ticks by 3."
        ),
        "counts_by_role": dict(sorted(counts.items())),
        "velocity_ranges_by_role": {
            role: [min(values), max(values)] for role, values in sorted(ranges.items())
        },
        "total_events": len(events),
        "pattern_or_density_change_from_v03": False,
    }


def main() -> int:
    previous_hashes = _verify_preserved_versions()
    config = read_json(CONFIG_PATH)
    verify_source_clearance(config, CONFIG_PATH)
    staves, source_report = FULL._load_source()
    full_events = FULL._arrangement_events(staves)
    strings, clipped_counts = V03._crop_base_events(full_events)
    percussion = _lift_percussion(V03._percussion_events())

    # Reuse the stable v03 notation/MIDI writers with v04-local output paths and
    # the original five source-derived voices only. No sixth embellishment voice.
    V03.MUSICAL_TRACKS = V03.BASE_TRACKS
    V03.VERSION_DIR = VERSION_DIR
    V03.NORMALIZED_DIR = NORMALIZED_DIR
    V03.ARRANGEMENT_MIDI = ARRANGEMENT_MIDI
    normalized = write_normalized_score(
        V03._normalized_score(strings), NORMALIZED_DIR, expand_repeats=False
    )
    FULL._stabilize_normalized_musicxml(normalized)
    counts = V03._write_midi(strings, percussion)

    report = {
        "ok": True,
        "version": "v04",
        "purpose": "Taste revision: integrated source strings and slightly clearer percussion",
        "selection": {
            "source_printed_measure_start": V03.SOURCE_START_MEASURE,
            "source_printed_measure_end_inclusive": V03.SOURCE_END_MEASURE_EXCLUSIVE - 1,
            "measure_count": V03.MEASURE_COUNT,
            "v02_start_seconds": 15.0,
            "v02_end_seconds": 170.0,
            "ordering": "single contiguous source span; no cuts, reorder, or inserted repeat",
        },
        "tempo": {
            "v02_qpm": FULL.QPM,
            "v03_qpm": V03.TEMPO_QPM,
            "v04_qpm": V03.TEMPO_QPM,
        },
        "loop": {
            "structural_duration_seconds": (
                V03.TOTAL_TICKS / V03.TICKS_PER_BEAT * 60.0 / V03.TEMPO_QPM
            ),
            "crossfade_seconds": 60.0 / V03.TEMPO_QPM,
            "rendered_duration_seconds": (
                (V03.TOTAL_TICKS / V03.TICKS_PER_BEAT - 1.0) * 60.0 / V03.TEMPO_QPM
            ),
            "treatment": "provisional taste render using the v03 one-quarter-note loop blend",
        },
        "base_source": source_report,
        "base_event_counts": {name: len(strings[name]) for name in V03.BASE_TRACKS},
        "boundary_clipped_event_counts": clipped_counts,
        "upper_string_revision": {
            "added_embellishment_tracks": 0,
            "removed_v03_track": V03.HIGH_TRACK,
            "approach": (
                "Use only the original source-derived upper voices and lift their render gains "
                "modestly, so every high-string gesture remains part of an existing phrase."
            ),
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
