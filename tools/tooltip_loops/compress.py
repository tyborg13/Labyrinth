#!/usr/bin/env python3
"""Gate and pack the contiguous recorder window; preserve every retained frame."""
import argparse
import hashlib
import io
import json
from pathlib import Path
import struct
from PIL import Image, ImageChops
from webp_encode import Encoder

ROOT = Path(__file__).resolve().parents[2]
NEAR_LEVELS = (60, 40)
NEAR_CAP_BYTES = 1500000
LOSSLESS_CAP_BYTES = 3000000
MAX_ERROR = 8
MEAN_ERROR = 0.5
HEADER = struct.Struct("<4s4I")
CHUNK_FRAMES = 16  # Storage only; timeline and playback frame rate are unchanged.


def pack(frames, slots=None):
    # Repeated byte-identical frames share a payload; every timeline index remains.
    slots = [0] * len(frames) if slots is None else slots
    payload = bytearray()
    entries, known = [], {}
    start = HEADER.size + 12 * len(frames)
    for frame, slot in zip(frames, slots):
        if frame not in known:
            known[frame] = (start + len(payload), len(frame))
            payload.extend(frame)
        entries.append((*known[frame], slot))
    return (HEADER.pack(b"TLW2", 282, 168, 30, len(frames)) +
            b"".join(struct.pack("<3I", *entry) for entry in entries) + payload)


def candidate(encoder, originals, level):
    encoded, slots, maxima, sums = [], [], [0, 0, 0], [0, 0, 0]
    for start in range(0, len(originals), CHUNK_FRAMES):
        chunk = originals[start:start + CHUNK_FRAMES]
        original = b"".join(chunk)
        buffer = encoder.encode(original, 282, 168 * len(chunk), level)
        decoded = Image.open(io.BytesIO(buffer)).convert("RGB")
        if decoded.size != (282, 168 * len(chunk)):
            raise ValueError("Wrong decoded chunk dimensions")
        histogram = ImageChops.difference(Image.frombytes("RGB", decoded.size, original), decoded).histogram()
        for channel in range(3):
            values = histogram[channel * 256:(channel + 1) * 256]
            maxima[channel] = max(maxima[channel], max(i for i, count in enumerate(values) if count))
            sums[channel] += sum(i * count for i, count in enumerate(values))
        encoded.extend([buffer] * len(chunk))
        slots.extend(range(len(chunk)))
    packed = pack(encoded, slots)
    means = [total / (len(originals) * 282 * 168) for total in sums]
    cap = LOSSLESS_CAP_BYTES if level == 100 else NEAR_CAP_BYTES
    passes = len(packed) <= cap and max(maxima) <= (0 if level == 100 else MAX_ERROR) and max(means) <= (0 if level == 100 else MEAN_ERROR)
    return packed, {"near_lossless": level, "file_bytes": len(packed), "max_per_channel_error": maxima,
                    "mean_per_channel_error": means, "passes": passes, "cap_bytes": cap}


def compress(source, target, encoder):
    raw = source.read_bytes()
    magic, width, height, fps, count = HEADER.unpack_from(raw)
    stride = width * height * 3
    if (magic, width, height, fps) != (b"TLP1", 282, 168, 30) or not 1 <= count <= 900 or len(raw) != HEADER.size + count * stride:
        raise ValueError("Invalid raw recording: " + str(source))
    originals = [raw[HEADER.size + i * stride:HEADER.size + (i + 1) * stride] for i in range(count)]
    results, selected = [], None
    for level in NEAR_LEVELS:
        packed, stats = candidate(encoder, originals, level)
        results.append(stats)
        if stats["passes"] and selected is None:
            selected = packed, stats
    if selected is None:
        packed, stats = candidate(encoder, originals, 100)
        results.append(stats)
        if stats["passes"]:
            selected = packed, stats
    report = {"id": source.stem, "action_frames": count, "action_seconds": count / fps,
              "raw_sha256": hashlib.sha256(raw).hexdigest(), "libwebp_version": encoder.version,
              "encoder_method": 6, "encoder_quality": 100, "chunk_frames": CHUNK_FRAMES,
              "tool_sha256": {name: hashlib.sha256((Path(__file__).parent / name).read_bytes()).hexdigest()
                              for name in ("compress.py", "webp_encode.py")},
              "candidates": results, "selected": selected[1] if selected else None}
    print(json.dumps(report), flush=True)
    if selected is None:
        return report, None
    provenance = json.loads(source.with_suffix(source.suffix + ".json").read_text())
    provenance.update(format="TLW2 indexed WebP", compression=report,
                      asset_sha256=hashlib.sha256(selected[0]).hexdigest())
    return report, (target, selected[0], provenance)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--input-dir", type=Path, required=True)
    parser.add_argument("--report", type=Path, required=True)
    parser.add_argument("--libwebp")
    parser.add_argument("--evaluate-only", action="store_true")
    parser.add_argument("--migrate-existing", action="store_true",
                        help="Convert old approved recordings; mark provenance as requiring native re-record")
    parser.add_argument("--loops", help="Comma-separated registry IDs; default: all recordable loops")
    args = parser.parse_args()
    encoder, reports, outputs = Encoder(args.libwebp), [], []
    registry = json.loads((ROOT / "data/tooltip_loops.json").read_text())
    selected_ids = set(args.loops.split(",")) if args.loops else None
    rows = [row for row in registry["loops"] if not row.get("todo_design") and (selected_ids is None or row["id"] in selected_ids)]
    if selected_ids is not None and selected_ids != {row["id"] for row in rows}:
        raise ValueError("Unknown or TODO_DESIGN loop selected")
    if not rows:
        raise ValueError("No recordable loops selected")
    provenance_valid = True
    for row in rows:
        source = args.input_dir / (row["id"] + ".tlp")
        target = ROOT / "assets/tooltip_loops" / (row["id"] + ".tlw")
        report, output = compress(source, target, encoder)
        provenance = json.loads(source.with_suffix(".tlp.json").read_text())
        speed = row.get("speed", "normal")
        ceiling = min(165 if speed == "fast" else 126, row.get("max_recording_frames", 165))
        report["recorded_speed"] = provenance.get("speed", "normal")
        report["recording_matches_brief"] = (report["recorded_speed"] == speed and
                                              report["action_frames"] <= ceiling and
                                              provenance.get("asset_sha256") == report["raw_sha256"])
        provenance_valid = provenance_valid and report["recording_matches_brief"]
        report["registry_cap_bytes"] = row.get("max_asset_bytes", LOSSLESS_CAP_BYTES)
        report["within_registry_cap"] = output is not None and len(output[1]) <= report["registry_cap_bytes"]
        reports.append(report)
        if report["within_registry_cap"]:
            outputs.append(output)
    args.report.parent.mkdir(parents=True, exist_ok=True)
    args.report.write_text(json.dumps(reports, indent=2) + "\n")
    if len(outputs) != len(rows):
        print("TIP02 COMPRESSION: FAIL (no assets replaced)")
        return 1
    if not args.evaluate_only:
        if not provenance_valid and not args.migrate_existing:
            print("TIP02 COMPRESSION: FAIL (fresh per-speed recordings required; no assets replaced)")
            return 1
        for target, packed, provenance in outputs:
            provenance["speed"] = provenance.get("speed", "normal")
            provenance["requires_native_rerecord"] = args.migrate_existing
            temporary = target.with_suffix(target.suffix + ".partial")
            temporary.write_bytes(packed)
            temporary.replace(target)
            target.with_suffix(target.suffix + ".json").write_text(json.dumps(provenance, indent=2) + "\n")
        # Switch the registry only after all compressed assets/provenance exist.
        for row in rows:
            row["asset_path"] = "res://assets/tooltip_loops/" + row["id"] + ".tlw"
        (ROOT / "data/tooltip_loops.json").write_text(json.dumps(registry, indent=2) + "\n")
        presets = ROOT / "export_presets.cfg"
        presets.write_text(presets.read_text().replace("assets/tooltip_loops/*.tlp,assets/tooltip_loops/*.tlp.json,", ""))
        # Only remove old shipping raw files after every loop has passed.
        for row in rows:
            old = ROOT / "assets/tooltip_loops" / (row["id"] + ".tlp")
            old.unlink(missing_ok=True)
            old.with_suffix(".tlp.json").unlink(missing_ok=True)
    print("TIP02 COMPRESSION: PASS (%d loops)" % len(outputs))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
