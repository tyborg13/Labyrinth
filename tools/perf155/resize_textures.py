#!/usr/bin/env python3
"""Rebuild the production map PNGs from the measured and archived masters."""
from __future__ import annotations

import hashlib
import json
import math
from pathlib import Path
import sys

from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from perf153.resize_textures import resample

ROOT = Path(__file__).resolve().parents[2]
ART = ROOT / "assets/art/icons/map"
MASTERS = ROOT / "assets/_masters/perf-155"
PROVENANCE = MASTERS / "provenance.json"


def source_rows() -> dict:
    return json.loads(PROVENANCE.read_text())["files"]


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def target_size(row: dict) -> tuple[int, int]:
    width, height = row["master_size"]
    largest = max(*row["desktop_px"], *row["deck_px"])
    if largest > 600:
        return width, height
    long_edge = max(128, math.ceil(2 * largest / 32) * 32)
    return tuple(round(edge * long_edge / max(width, height)) for edge in (width, height))


def main() -> None:
    rows = source_rows()
    for name, row in rows.items():
        source = MASTERS / name
        if sha256(source) != row["master_sha256"]:
            raise ValueError(f"Master SHA-256 mismatch: {source}")
        with Image.open(source) as image:
            if list(image.size) != row["master_size"]:
                raise ValueError(f"Master dimensions mismatch: {source}")
    for name, row in rows.items():
        if target_size(row) != tuple(row["master_size"]):
            resample(MASTERS / name, ART / name, target_size(row))


if __name__ == "__main__":
    main()
