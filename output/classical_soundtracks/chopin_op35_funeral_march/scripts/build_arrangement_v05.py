#!/usr/bin/env python3
"""Freeze the owner-approved v04 music as the promotion-ready v05 loop."""

from __future__ import annotations

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


CONFIG_PATH = TRACK_ROOT / "track.v05.json"
V04_CONFIG = TRACK_ROOT / "track.v04.json"
V04_BUILDER = TRACK_ROOT / "scripts" / "build_arrangement_v04.py"
V04_VERSION_DIR = TRACK_ROOT / "versions" / "v04"
V04_MIDI = V04_VERSION_DIR / "arrangement.mid"
VERSION_DIR = TRACK_ROOT / "versions" / "v05"
ARRANGEMENT_MIDI = VERSION_DIR / "arrangement.mid"
BUILD_REPORT = VERSION_DIR / "BUILD_REPORT.json"

EXPECTED_V04_CONFIG_SHA256 = "139b39dca71b99fcf530f92facad717179f4d253ad4b4dd7302d8277665f65cf"
EXPECTED_V04_BUILDER_SHA256 = "00c594a9cc72f3211b6139c0f95e64fa887253c600aa98372d7eebb18216b15e"
EXPECTED_V04_VERSION_HASHES = {
    "ARRANGEMENT_NOTES.md": "427acea8216ddcb4eacad59ffb977fd7505f4e5bc611c559906ba29a1985b218",
    "BUILD_REPORT.json": "b9c8c6003ada5435a32f41499e966c62c9fb3819d867d677e61e41ac1d7074c9",
    "VERIFICATION.json": "d91a7d0f8bac8c713012f0850a7ea05888ced75c8f2c7032f8ac940934456e57",
    "arrangement.mid": "97ffdb5431fc643d1a6250e3a20c9ae54c9314a320afc878acaf0f93919720ca",
    "preview.flac": "00895a5616fea071e73fd22681747a6adc154db1196a74b650341ea9b4d7e16e",
    "preview.ogg": "f005bda46c395579b32f0afeb749b5e16775efa2ecee5203e2a4bacd872b2569",
    "preview.render.json": "19d2370432da2d9acc03ce2291d0c29a110cd38243572cedf71501bf075d683d",
}


def _verify_v04_is_untouched() -> dict[str, str]:
    if sha256(V04_CONFIG) != EXPECTED_V04_CONFIG_SHA256:
        raise RuntimeError("The owner-approved v04 audition config drifted")
    if sha256(V04_BUILDER) != EXPECTED_V04_BUILDER_SHA256:
        raise RuntimeError("The owner-approved v04 audition builder drifted")
    actual_files = sorted(
        path.relative_to(V04_VERSION_DIR).as_posix()
        for path in V04_VERSION_DIR.rglob("*")
        if path.is_file()
    )
    if actual_files != sorted(EXPECTED_V04_VERSION_HASHES):
        raise RuntimeError(f"v05 must not alter the v04 artifact tree: {actual_files}")
    actual_hashes: dict[str, str] = {}
    for relative, expected in EXPECTED_V04_VERSION_HASHES.items():
        actual_hashes[relative] = sha256(V04_VERSION_DIR / relative)
        if actual_hashes[relative] != expected:
            raise RuntimeError(f"v05 must preserve owner-approved v04 artifact {relative}")
    return actual_hashes


def main() -> int:
    preserved_hashes = _verify_v04_is_untouched()
    config = read_json(CONFIG_PATH)
    verify_source_clearance(config, CONFIG_PATH)
    if config.get("approval", {}).get("status") != "approved":
        raise RuntimeError("v05 must remain an approved integration package")
    if config.get("arrangement", {}).get("version") != "v05":
        raise RuntimeError("v05 config version drifted")

    VERSION_DIR.mkdir(parents=True, exist_ok=True)
    ARRANGEMENT_MIDI.write_bytes(V04_MIDI.read_bytes())
    midi_hash = sha256(ARRANGEMENT_MIDI)
    if midi_hash != EXPECTED_V04_VERSION_HASHES["arrangement.mid"]:
        raise RuntimeError("v05 must preserve every owner-approved v04 MIDI byte")

    report = {
        "ok": True,
        "version": "v05",
        "purpose": "Promotion package preserving owner-approved v04 music exactly",
        "arrangement_midi": str(ARRANGEMENT_MIDI),
        "arrangement_midi_sha256": midi_hash,
        "musical_content": {
            "midi_byte_for_byte_equal_to_v04": True,
            "v04_midi_sha256": EXPECTED_V04_VERSION_HASHES["arrangement.mid"],
            "musical_changes_from_v04": "none",
            "selection": "v04 contiguous source measures 93-100, uniformly transposed down three semitones",
            "late_motif_policy": "v04 recognizable late Grave and Veiled lead remains suppressed",
        },
        "v04_config_sha256": EXPECTED_V04_CONFIG_SHA256,
        "v04_builder_sha256": EXPECTED_V04_BUILDER_SHA256,
        "v04_version_hashes_unchanged": preserved_hashes,
    }
    write_json(BUILD_REPORT, report)
    print(json.dumps(report, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
