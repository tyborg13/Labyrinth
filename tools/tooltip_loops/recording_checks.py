"""Validate the provenance of an installed native tooltip recording."""

import hashlib
import json

from tooltip_loops.record import ROOT


def check_recording(row: dict) -> dict:
    asset = ROOT / row["asset_path"].removeprefix("res://")
    provenance = json.loads(asset.with_suffix(".tlw.json").read_text())
    renderer = provenance["renderer"]
    content = asset.read_bytes()
    if (
        provenance["id"] != row["id"]
        or provenance["speed"] != row["speed"]
        or provenance["requires_native_rerecord"]
        or renderer["cel_look"] != "all"
        or renderer["viewport"] != [1920, 1080]
        or renderer["ui_scale"] != 1.0
        or len(content) > row["max_asset_bytes"]
        or hashlib.sha256(content).hexdigest() != provenance["asset_sha256"]
    ):
        raise ValueError(f"Recording does not match its native proof contract: {asset}")
    return provenance
