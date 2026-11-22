#!/usr/bin/env python3
"""Capture Stagger or measure its native cold open."""

import hashlib
from pathlib import Path

from tip09_capture import FPS, HEADER, ROOT, check_recording, run_capture

TASK = "tip-10"
PROBE = "tools/tooltip_loops/tip10_capture.gd"
CONTRACT = "tools/tooltip_loops/tip10_capture_contract.json"
OUT = Path("/private/tmp/labyrinth_codex/tip-10/capture")
WITNESSES = {"stagger": "hero_ahead"}
# The row, media and witness checks below verify Stagger directly. Changes to
# other loops in the shared registry and recorder do not invalidate its receipt.
SOURCE_FILES = (
    "tools/tooltip_loops/tip10_fixture.gd",
    "tools/tooltip_loops/tip10_checks.gd",
    "tools/tooltip_loops/tip10_rail.gd",
    "tools/tooltip_loops/record_board.gd",
    "scripts/combat_engine.gd",
    "scripts/run_scene.gd",
    "data/cards.json",
    "data/enemies.json",
)


def recording_receipt(row: dict, *, witnesses=WITNESSES, source_files=SOURCE_FILES, tag="TIP10") -> dict:
    loop_id = row["id"]
    provenance = check_recording(row)
    timing = provenance["motion_timing"]
    frames = int(timing["recording_frames"])
    period = frames / FPS + provenance["hold_seconds"] + provenance["crossfade_seconds"]
    asset = ROOT / row["asset_path"].removeprefix("res://")
    with asset.open("rb") as stream:
        header = HEADER.unpack(stream.read(HEADER.size))
    codec = provenance["compression"]
    selected = codec["selected"]
    mechanic = timing["patch_visibility"]["keyword_mechanic"]
    witness = mechanic["frames"][witnesses[loop_id]]
    proof_frame = int(witness) - int(timing["trim_start_frames"]) + int(timing.get("opening_hold_frames", 0))
    size = asset.stat().st_size
    if (
        header != (b"TLW2", 282, 168, FPS, frames)
        or not 3 <= period <= 5
        or not row["min_recording_frames"] <= frames <= row["max_recording_frames"]
        or provenance["hold_seconds"] != row.get("hold_seconds", 0.6)
        or provenance["crossfade_seconds"] != 0.25
        or codec["chunk_frames"] != 16
        or codec["encoder_method"] != 6
        or codec["encoder_quality"] != 100
        or selected["near_lossless"] not in (60, 40, 100)
        or not selected["passes"]
        or selected["file_bytes"] != size
        or not 0 <= proof_frame < frames - int(timing["terminal_hold_frames"])
        or any(
            provenance["source_sha256"].get(path) != hashlib.sha256((ROOT / path).read_bytes()).hexdigest()
            for path in source_files
        )
    ):
        raise ValueError(f"Stale recording, invalid witness, timing or tip-02 codec receipt: {asset}")
    if loop_id == "stagger":
        rail = mechanic["frames"]
        if not (
            rail["crawler_ahead"] == 0 < rail["rail_slide"] < rail["hero_ahead"]
            and mechanic["settled_hero_ahead"]
            and int(timing["terminal_hold_frames"]) == 0
            and proof_frame == frames - 1
        ):
            raise ValueError(f"Stagger must show the complete slide and hold on its final frame: {asset}")
    print(f"{tag} INSTALLED {loop_id}: {size} bytes, {frames} frames, {period:.3f} s", flush=True)
    return {"proof_frame": proof_frame}


if __name__ == "__main__":
    raise SystemExit(run_capture(
        task=TASK, probe=PROBE, contract_path=CONTRACT, default_output=OUT,
        witnesses=WITNESSES, receipt=recording_receipt, description=__doc__,
    ))
