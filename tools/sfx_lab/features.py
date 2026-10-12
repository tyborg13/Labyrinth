"""Measure take traits; file-grouped analysis decodes each recording only once."""
from __future__ import annotations

import argparse
from collections import defaultdict
from concurrent.futures import ProcessPoolExecutor
from pathlib import Path
import sys
import time

if __package__ in (None, ""):
    sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from tools.sfx_lab.common import (LabError, cli, db, decode, loudness, read_json,
    read_jsonl, sha256, source_path, workers, write_jsonl)
from tools.sfx_lab.slice import rms_envelope
import numpy as np
from scipy import signal


SPECTRAL_WINDOW_SAMPLES = 4096
SPECTRAL_BATCH_FRAMES = 128
ENVELOPE_POINTS = 64
NUMERICAL_EPSILON = 1e-20


def measure(data: np.ndarray, rate: int) -> dict:
    envelope, hop = rms_envelope(data, rate)
    peak_frame = int(np.argmax(envelope))
    peak_rms = float(envelope[peak_frame])
    above_attack = np.flatnonzero(envelope[:peak_frame + 1] >= peak_rms * 0.1)
    below_decay = np.flatnonzero(envelope[peak_frame:] <= peak_rms * 10 ** (-30 / 20))
    attack = (peak_frame - int(above_attack[0])) * hop / rate if len(above_attack) else 0
    decay = (int(below_decay[0]) * hop / rate) if len(below_decay) else None
    # Average channel power spectra; never cancel anti-phase stereo by downmixing.
    size = min(SPECTRAL_WINDOW_SAMPLES, len(data))
    stride = max(1, size // 2)
    starts = np.arange(0, max(1, len(data) - size + 1), stride)
    window = signal.windows.hann(size, sym=False)
    frequencies = np.fft.rfftfreq(size, 1 / rate)
    centroid_sum = flatness_sum = 0.0
    valid_frames = 0
    total_power = np.zeros(len(frequencies))
    for offset in range(0, len(starts), SPECTRAL_BATCH_FRAMES):
        batch_starts = starts[offset:offset + SPECTRAL_BATCH_FRAMES]
        frames = data[batch_starts[:, None] + np.arange(size)[None, :]]
        power = np.mean(np.abs(np.fft.rfft(frames * window[None, :, None], axis=1)) ** 2, axis=2)
        energy = power.sum(axis=1)
        valid = energy > NUMERICAL_EPSILON
        if valid.any():
            selected = power[valid]
            centroid_sum += float(((selected @ frequencies) / energy[valid]).sum())
            flatness = np.exp(np.mean(np.log(np.maximum(selected, NUMERICAL_EPSILON)), axis=1)) / np.mean(selected, axis=1)
            flatness_sum += float(flatness.sum())
            valid_frames += int(valid.sum())
        total_power += power.sum(axis=0)
    total = float(total_power.sum())
    level, method = loudness(data, rate)
    # Literal inverse spectral flatness; cap only the numerical denominator.
    normalized = envelope / peak_rms if peak_rms else np.zeros_like(envelope)
    sampled = np.interp(np.linspace(0, len(normalized) - 1, ENVELOPE_POINTS),
                        np.arange(len(normalized)), normalized)
    return {"duration": len(data) / rate, "peak_dbfs": db(float(np.max(np.abs(data)))),
            "lufs": level, "loudness_method": method, "attack_seconds": attack,
            "decay_seconds": decay, "centroid_hz": centroid_sum / valid_frames if valid_frames else 0,
            "low_band_ratio": float(total_power[frequencies < 200].sum() / total) if total else 0,
            "high_band_ratio": float(total_power[frequencies > 5000].sum() / total) if total else 0,
            "tonality": 1 / max(flatness_sum / valid_frames, NUMERICAL_EPSILON) if valid_frames else 0,
            "envelope": sampled.tolist()}


def _measure_file(job: tuple[str, list[dict]]) -> list[dict]:
    root, rows = job
    path = source_path(root, rows[0]["source_path"], rows[0]["licence_id"])
    if sha256(path) != rows[0]["source_sha256"]:
        raise LabError(f"Source hash changed: {rows[0]['source_path']}")
    data, rate = decode(path)
    result = []
    for row in rows:
        if row["source_sha256"] != rows[0]["source_sha256"] or row["licence_id"] != rows[0]["licence_id"]:
            raise LabError("Inconsistent take provenance")
        start, end = round(row["start_seconds"] * rate), round(row["end_seconds"] * rate)
        if not 0 <= start < end <= len(data):
            raise LabError(f"Take range outside source: {row['take_id']}")
        result.append({**row, **measure(data[start:end], rate)})
    return result


def create_features(index: Path, takes: Path, out: Path, worker_count: int = 4) -> list[dict]:
    root = read_json(index)["sources"]
    groups = defaultdict(list)
    for row in read_jsonl(takes):
        source_path(root, row["source_path"], row["licence_id"])
        groups[row["source_path"]].append(row)
    with ProcessPoolExecutor(max_workers=workers(worker_count)) as pool:
        result = [row for group in pool.map(_measure_file, [(root, groups[key]) for key in sorted(groups)])
                  for row in group]
    write_jsonl(out, result)
    return result


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--index", type=Path, required=True)
    parser.add_argument("--takes", type=Path, required=True)
    parser.add_argument("--out", type=Path, required=True)
    parser.add_argument("--workers", type=workers, default=4)
    args = parser.parse_args()
    started = time.monotonic()
    result = create_features(args.index, args.takes, args.out, args.workers)
    print(f"FEATURES takes={len(result)} elapsed_seconds={time.monotonic() - started:.3f} out={args.out}")


if __name__ == "__main__":
    cli(main)
