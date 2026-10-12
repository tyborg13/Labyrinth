"""Split construction-kit recordings with the specified RMS gate and tail rule."""
from __future__ import annotations

import argparse
from concurrent.futures import ProcessPoolExecutor
import math
from pathlib import Path
import sys
import time

if __package__ in (None, ""):
    sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from tools.sfx_lab.common import (cli, decode, read_json, safe_path, sha256,
    source_path, workers, write_jsonl, LabError)
import numpy as np


HOP_SECONDS = 0.010
GATE_FLOOR_DBFS = -50
GATE_PEAK_OFFSET_DB = -45
RELEASE_SECONDS = 0.120
TAIL_FLOOR_DBFS = -60
MAX_TAIL_SECONDS = 4.0
MIN_TAKE_SECONDS = 0.040


def rms_envelope(data: np.ndarray, rate: int) -> tuple[np.ndarray, int]:
    hop = max(1, round(rate * HOP_SECONDS))
    power = np.mean(data ** 2, axis=1)
    indices = np.arange(0, len(power), hop)
    counts = np.minimum(hop, len(power) - indices)
    return np.sqrt(np.add.reduceat(power, indices) / counts), hop


def slice_audio(data: np.ndarray, rate: int) -> list[tuple[float, float]]:
    envelope, hop = rms_envelope(data, rate)
    peak = float(np.max(envelope))
    gate = max(10 ** (GATE_FLOOR_DBFS / 20), peak * 10 ** (GATE_PEAK_OFFSET_DB / 20))
    active = envelope > gate
    release = math.ceil(RELEASE_SECONDS * rate / hop)
    cores = []
    start = None
    below = None
    for frame, above in enumerate(active):
        if above:
            if start is None:
                start = frame
            below = None
        elif start is not None:
            if below is None:
                below = frame
            if frame - below + 1 >= release:
                cores.append((start, below, frame + 1))
                start = below = None
    if start is not None:
        cores.append((start, below if below is not None else len(envelope), len(envelope)))
    result = []
    for number, (start, tail_start, released) in enumerate(cores):
        if (min(len(data), tail_start * hop) - start * hop) / rate < MIN_TAKE_SECONDS:
            continue
        next_start = cores[number + 1][0] if number + 1 < len(cores) else len(envelope)
        tail_limit = min(next_start, tail_start + math.ceil(MAX_TAIL_SECONDS * rate / hop))
        end = tail_start
        while end < tail_limit and envelope[end] > 10 ** (TAIL_FLOOR_DBFS / 20):
            end += 1
        # Keep the 120 ms release even when the recording immediately falls silent.
        end = min(next_start, max(end, released))
        result.append((start * hop / rate, min(len(data), end * hop) / rate))
    return result


def _slice_file(job: tuple[str, dict]) -> list[dict]:
    root, row = job
    path = source_path(root, row["source_path"], row["licence_id"])
    if sha256(path) != row["sha256"]:
        raise LabError(f"Source hash changed: {row['source_path']}")
    data, rate = decode(path)
    return [{"take_id": f"{row['sha256'][:12]}#{number}",
             "start_seconds": start, "end_seconds": end,
             "source_path": row["source_path"], "source_id": row["source_id"],
             "licence_id": row["licence_id"], "source_sha256": row["sha256"],
             "sample_rate": rate, "channels": data.shape[1]}
            for number, (start, end) in enumerate(slice_audio(data, rate), start=1)]


def create_slices(index: Path, out: Path, worker_count: int = 4) -> list[dict]:
    catalogue = read_json(index)
    root = str(safe_path(catalogue["sources"]))
    for row in catalogue["files"]:
        source_path(root, row["source_path"], row["licence_id"])
    with ProcessPoolExecutor(max_workers=workers(worker_count)) as pool:
        groups = pool.map(_slice_file, [(root, row) for row in catalogue["files"]])
        result = [row for group in groups for row in group]
    write_jsonl(out, result)
    return result


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--index", type=Path, required=True)
    parser.add_argument("--out", type=Path, required=True)
    parser.add_argument("--workers", type=workers, default=4)
    args = parser.parse_args()
    started = time.monotonic()
    result = create_slices(args.index, args.out, args.workers)
    print(f"SLICE takes={len(result)} elapsed_seconds={time.monotonic() - started:.3f} out={args.out}")


if __name__ == "__main__":
    cli(main)
