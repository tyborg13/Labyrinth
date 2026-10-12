"""Index approved libraries, or query measured take traits without listening."""
from __future__ import annotations

import argparse
from concurrent.futures import ThreadPoolExecutor
import json
import os
from pathlib import Path
import re
import sys
import time

if __package__ in (None, ""):
    sys.path.insert(0, str(Path(__file__).resolve().parents[2]))

from tools.sfx_lab.common import (AUDIO_EXTENSIONS, SOURCE_LICENSES, SCHEMA_VERSION,
    DESIGNED_SOURCE, LabError, cli, command, designed_licence, read_jsonl, safe_path,
    sha256, source_path, workers, write_json)
import soundfile as sf


MIN_FILE_SECONDS = 0.03
BIT_DEPTHS = {"PCM_S8": 8, "PCM_U8": 8, "PCM_16": 16, "PCM_24": 24,
              "PCM_32": 32, "FLOAT": 32, "DOUBLE": 64}
QUERY_COLUMNS = ["take_id", "duration", "centroid_hz", "low_band_ratio",
                 "attack_seconds", "decay_seconds", "lufs", "source_path"]
QUERY_NUMERIC_FIELDS = {"duration", "centroid_hz", "low_band_ratio", "high_band_ratio",
                        "attack_seconds", "decay_seconds", "lufs", "peak_dbfs", "tonality"}


def _probe(job: tuple[str, str]) -> dict | None:
    root, relative = job
    path = source_path(root, relative)
    try:
        info = sf.info(path)
        duration, rate, channels = info.duration, info.samplerate, info.channels
        bits = BIT_DEPTHS.get(info.subtype, 0)
    except (RuntimeError, sf.LibsndfileError):
        result = json.loads(command(["ffprobe", "-v", "error", "-threads", "2",
                                    "-show_streams", "-show_format", "-of", "json",
                                    str(path)]).stdout)
        stream = next(item for item in result["streams"] if item["codec_type"] == "audio")
        duration = float(stream.get("duration", result["format"]["duration"]))
        rate, channels = int(stream["sample_rate"]), int(stream["channels"])
        bits = int(stream.get("bits_per_raw_sample", "0") or "0")
    if duration < MIN_FILE_SECONDS:
        return None
    source_id = Path(relative).parts[0]
    return {"source_path": relative, "source_id": source_id,
            "licence_id": (designed_licence(path) if source_id == DESIGNED_SOURCE
                           else SOURCE_LICENSES[source_id]), "duration": duration,
            "sample_rate": rate, "channels": channels, "bit_depth": bits,
            "sha256": sha256(path)}


def create_index(sources: Path | list[Path], out: Path, worker_count: int = 4) -> dict:
    roots = [safe_path(root) for root in (sources if isinstance(sources, list) else [sources])]
    out = safe_path(out)
    jobs = []
    seen = set()
    for root in roots:
        root_jobs = []
        for source_id in sorted((*SOURCE_LICENSES, DESIGNED_SOURCE)):
            directory = safe_path(root / source_id)
            if not directory.is_dir():
                continue
            # License evidence is required for every source present in the tree.
            if not safe_path(directory / "LICENSE.txt").is_file():
                raise LabError(f"Missing source licence record: {source_id}/LICENSE.txt")
            for parent, directories, files in os.walk(directory, followlinks=False):
                directories[:] = sorted(name for name in directories if name != "__MACOSX")
                for name in sorted(files):
                    path = Path(parent) / name
                    if name != ".DS_Store" and path.suffix.lower() in AUDIO_EXTENSIONS:
                        relative = path.relative_to(root).as_posix()
                        source_path(root, relative)  # Validate sidecars and forbidden symlinks before probing.
                        if relative in seen:
                            raise LabError(f"Duplicate source path across roots: {relative}")
                        seen.add(relative)
                        root_jobs.append((str(root), relative))
        jobs.extend(sorted(root_jobs))
    if not jobs:
        raise LabError("No audio files in approved source directories")
    with ThreadPoolExecutor(max_workers=workers(worker_count)) as pool:
        rows = [row for row in pool.map(_probe, jobs) if row is not None]
    value = {"schema_version": SCHEMA_VERSION,
             "sources": str(roots[0]) if len(roots) == 1 else [str(root) for root in roots],
             "files": rows}
    write_json(out, value)
    return value


def query(rows: list[dict], filters: dict, substring: str | None = None,
          regex: str | None = None, sort: str = "source_path", descending: bool = False,
          limit: int | None = None) -> list[dict]:
    if sort not in QUERY_NUMERIC_FIELDS | {"take_id", "source_path"}:
        raise LabError(f"Unknown sort key: {sort}")
    try:
        pattern = re.compile(regex) if regex else None
    except re.error as error:
        raise LabError(f"Invalid path regex: {error}") from error
    result = []
    for row in rows:
        if substring and substring.casefold() not in row["source_path"].casefold():
            continue
        if pattern and not pattern.search(row["source_path"]):
            continue
        if any(row.get(key) is None or not bounds[0] <= row[key] <= bounds[1]
               for key, bounds in filters.items()):
            continue
        result.append(row)
    present = [row for row in result if row.get(sort) is not None]
    absent = [row for row in result if row.get(sort) is None]
    present.sort(key=lambda row: (row[sort], row["source_path"], row["take_id"]),
                 reverse=descending)
    return (present + absent)[:limit] if limit is not None else present + absent


def main() -> None:
    if len(sys.argv) > 1 and sys.argv[1] == "query":
        parser = argparse.ArgumentParser(description=__doc__)
        parser.add_argument("query")
        parser.add_argument("--features", type=Path, default=Path("features.jsonl"))
        parser.add_argument("--path", dest="substring")
        parser.add_argument("--regex")
        ranges = {"duration": "duration", "centroid": "centroid_hz", "low-band": "low_band_ratio",
                  "attack": "attack_seconds", "decay": "decay_seconds", "lufs": "lufs"}
        for option in ranges:
            parser.add_argument("--" + option, nargs=2, type=float, metavar=("MIN", "MAX"))
        parser.add_argument("--sort", default="source_path")
        parser.add_argument("--descending", action="store_true")
        parser.add_argument("--limit", type=int)
        args = parser.parse_args()
        filters = {key: getattr(args, option.replace("-", "_")) for option, key in ranges.items()
                   if getattr(args, option.replace("-", "_")) is not None}
        if any(bounds[0] > bounds[1] for bounds in filters.values()) or (args.limit is not None and args.limit < 0):
            raise LabError("Invalid range or limit")
        rows = query(read_jsonl(args.features), filters, args.substring, args.regex,
                     args.sort, args.descending, args.limit)
        print("\t".join(QUERY_COLUMNS))
        for row in rows:
            print("\t".join(f"{row[key]:.3f}" if isinstance(row.get(key), float)
                            else str(row.get(key, "")) for key in QUERY_COLUMNS))
    else:
        parser = argparse.ArgumentParser(description=__doc__)
        parser.add_argument("--sources", type=Path, action="append", required=True)
        parser.add_argument("--out", type=Path, required=True)
        parser.add_argument("--workers", type=workers, default=4)
        args = parser.parse_args()
        started = time.monotonic()
        result = create_index(args.sources, args.out, args.workers)
        print(f"INDEX files={len(result['files'])} elapsed_seconds={time.monotonic() - started:.3f} out={args.out}")


if __name__ == "__main__":
    cli(main)
