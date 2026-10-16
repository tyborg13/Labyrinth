"""Output-volume guards and bounded-memory artifact accounting."""
from __future__ import annotations

import hashlib
import json
from pathlib import Path
import shutil

MIN_FREE_BYTES = 8_000_000_000  # Director requirement: decimal GB, as on macOS.
HASH_CHUNK_BYTES = 1024 * 1024


class DiskSpaceError(ValueError):
    pass


def free_bytes(output):
    volume = Path(output).resolve()
    while not volume.exists(): volume = volume.parent
    return shutil.disk_usage(volume).free


def require_space(output):
    free = free_bytes(output)
    if free < MIN_FREE_BYTES:
        raise DiskSpaceError(f"Recording stopped before writing: {free / 1e9:.3f} GB free on {output}; at least 8 GB required")
    return free


def print_free(output, stage):
    free = free_bytes(output)
    print(f"DEMO DISK {stage}: {free} bytes free ({free / 1e9:.3f} GB)", flush=True)
    return free


def output_size(output):
    return sum(p.stat().st_size for p in output.rglob("*") if p.is_file() and not p.is_symlink())


def print_size(output):
    size = output_size(output)
    print(f"DEMO OUTPUT SIZE: {size} bytes ({size / 1e9:.3f} GB) — {output}", flush=True)
    return size


def write_result(output, name, report):
    """Include this result file itself in the total, without retaining media in RAM."""
    path = output / name
    report["output_size_bytes"] = output_size(output)
    for _ in range(5):
        path.write_text(json.dumps(report, indent=2) + "\n")
        size = output_size(output)
        if size == report["output_size_bytes"]: return
        report["output_size_bytes"] = size
    raise ValueError("Output size changed while writing the result")


def file_hash(path):
    digest = hashlib.sha256()
    with path.open("rb") as source:
        for chunk in iter(lambda: source.read(HASH_CHUNK_BYTES), b""): digest.update(chunk)
    return digest.hexdigest()


def capture_hashes(directory):
    # The audit receipt carries these hashes, so it cannot hash itself.
    paths = [p for p in directory.iterdir()
             if p.is_file() and p.name != "audit.json" and p.suffix in {".avi", ".mkv", ".wav", ".json", ".log"}]
    paths += [p for p in (directory / "capture-project/project.godot", directory / "capture-project/override.cfg") if p.is_file()]
    return {str(p.relative_to(directory)): file_hash(p) for p in sorted(paths)}
