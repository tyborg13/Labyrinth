"""Exact sequence/state comparison with ±2 frames and reviewed presentation waits."""
from __future__ import annotations

import copy
import hashlib
import json
from pathlib import Path

MAX_NATIVE_FRAME_OFFSET = 2  # Director-approved per-item lead or lag.
FLOAT_TOLERANCE = 1e-4  # Director: progress floats differ by ~2e-6 between native and headless clocks.


def _same(a, b):
    if isinstance(a, float) or isinstance(b, float):
        return isinstance(a, (int, float)) and isinstance(b, (int, float)) and abs(a - b) <= FLOAT_TOLERANCE
    if isinstance(a, dict) and isinstance(b, dict):
        return a.keys() == b.keys() and all(_same(a[k], b[k]) for k in a)
    if isinstance(a, list) and isinstance(b, list):
        return len(a) == len(b) and all(_same(x, y) for x, y in zip(a, b))
    return a == b


class ComparisonError(ValueError):
    def __init__(self, message, offset_profile=None, timing_exemptions=None):
        super().__init__(message)
        self.offset_profile = offset_profile or []
        self.timing_exemptions = timing_exemptions or []


def payload_hash(report):
    value = copy.deepcopy(report)
    for key in ("headless", "director_sha256", "start_frame", "end_frame"): value.pop(key, None)
    for name in ("events", "frames"):
        for row in value[name]: row.pop("frame")
    return hashlib.sha256(json.dumps(value, sort_keys=True, separators=(",", ":")).encode()).hexdigest()


def presentation_exemptions(reference, points):
    """Exact reviewed frame pairs only; never grant a clip-wide timing range."""
    root = Path(__file__).resolve().parents[2]
    cases = json.loads((Path(__file__).with_name("comparison_exemptions.json")).read_text())["cases"]
    applied = {}
    for case in cases:
        if case["clip"] != reference["clip"]: continue
        if case["reference_payload_sha256"] != payload_hash(reference): continue
        if any(hashlib.sha256((root / name).read_bytes()).hexdigest() != digest
               for name, digest in case["source_sha256"].items()): continue
        reviewed = {point["item"]: point for point in case["points"]}
        for point in points:
            expected = reviewed.get(point["item"])
            if expected and all(point[key] == value for key, value in expected.items()):
                applied[point["item"]] = dict(point, exemption=case["id"], cause=case["cause"],
                                               code_paths=case["code_paths"], evidence=case["evidence"])
    return applied


def format_profile(profile):
    return ", ".join(f"H{point['headless_frame']}/N{point['native_frame']}→{point['offset']:+d}"
                     for point in profile) or "unavailable"


def compare_native(native_path, headless_path):
    native = json.loads(native_path.read_text())
    reference = json.loads(headless_path.read_text())
    prefix = f"DETERMINISM FAIL: {native_path} != {headless_path}"
    if native.get("headless") is not False or reference.get("headless") is not True:
        raise ComparisonError(f"{prefix}: expected one native take and one headless reference")
    for name in ("events", "frames"):
        if len(native[name]) != len(reference[name]):
            raise ComparisonError(f"{prefix}: {name} count differs")
    translated = copy.deepcopy(native)
    points = []

    def pair(item, native_frame, headless_frame):
        points.append({"item": item, "headless_frame": headless_frame,
                       "native_frame": native_frame, "offset": native_frame - headless_frame})

    for field in ("start_frame", "end_frame"):
        pair(field, native[field], reference[field])
        translated[field] = reference[field]
    for name in ("events", "frames"):
        for index, row in enumerate(translated[name]):
            pair(f"{name}[{index}]", row["frame"], reference[name][index]["frame"])
            row["frame"] = reference[name][index]["frame"]
    # Renderer mode is intentionally different. Everything else, including
    # payloads, order and board submissions, must match exactly before timing
    # tolerance applies. Rows are paired by index, never by nearest frame.
    translated.pop("headless")
    expected = dict(reference)
    expected.pop("headless")
    if not _same(translated, expected):
        raise ComparisonError(f"{prefix}: non-frame payload, state, ordering or metadata differs")

    # Merge already-paired streams only to report changes chronologically.
    # Lag may rise or fall; every paired item must independently stay in range.
    timeline = sorted(points, key=lambda point: (point["headless_frame"], point["native_frame"]))
    profile = []
    previous = None
    for point in timeline:
        if point["offset"] != previous:
            profile.append(point)
        previous = point["offset"]
    exemptions = presentation_exemptions(reference, timeline)
    applied = []
    for point in timeline:
        if abs(point["offset"]) > MAX_NATIVE_FRAME_OFFSET:
            if point["item"] in exemptions:
                applied.append(exemptions[point["item"]])
            else:
                raise ComparisonError(f"{prefix}: {point['item']} has offset {point['offset']:+d}, required [-{MAX_NATIVE_FRAME_OFFSET}, +{MAX_NATIVE_FRAME_OFFSET}] or an exact reviewed presentation exemption", profile, applied)
    # Sync/duration always receive the untouched native times and frames.
    return native, profile, applied
