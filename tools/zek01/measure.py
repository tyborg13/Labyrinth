"""Matched first-section dragon repeats from run_curve_dragons archived inputs."""
from __future__ import annotations
import argparse
import base64
from concurrent.futures import ThreadPoolExecutor
import gzip
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import time

ROOT = Path(__file__).resolve().parents[2]
ARCHIVE = ROOT / "spec/peer_benchmark/encounter_redesign/measurements/run_curve_2026-11/dragons_loadouts.jsonl.gz"

def main():
    parser = argparse.ArgumentParser(__doc__)
    parser.add_argument("--output-dir", type=Path, required=True)
    parser.add_argument("--samples", type=int, default=64)
    parser.add_argument("--workers", type=int, default=6)
    parser.add_argument("--resume", action="store_true")
    args = parser.parse_args()
    out = args.output_dir.resolve()
    out.mkdir(parents=True, exist_ok=True)
    existing = [json.loads(line) for p in out.glob("fights-*.jsonl") for line in p.read_text().splitlines()]
    if existing and not args.resume:
        raise ValueError("Preserve completed measurements: use --resume or a fresh directory")
    if not 1 <= args.workers <= 6:
        raise ValueError("Use 1–6 isolated headless workers")
    generation = str(time.time_ns())
    completed = out / f"completed-{generation}.json"
    completed.write_text(json.dumps([f"{r['sample']}|{r['variant']}|{r['dragon']}" for r in existing]))
    inputs = out / "inputs"
    inputs.mkdir(exist_ok=True)
    records = [json.loads(line) for line in gzip.open(ARCHIVE, "rt")]
    for row in records:
        if row["section"] != 0 or row["ladder_seed"] > 8: continue
        payload = base64.b64decode(row["typed_payload_base64"])
        assert hashlib.sha256(payload).hexdigest() == row["input_sha256"]
        (inputs / f"input-{row['ladder_seed']}.bin").write_bytes(payload)
    contract = {"archive_sha256": hashlib.sha256(ARCHIVE.read_bytes()).hexdigest(), "section": 0, "samples": args.samples,
                "loadouts": 8, "stride": 1000003, "policy_sha256": hashlib.sha256((ROOT / "tools/encounter_bot.gd").read_bytes()).hexdigest(),
                "source_sha256": {str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest() for p in [*sorted((ROOT / "scripts").rglob("*.gd")), ROOT / "data/enemies.json", *sorted((ROOT / "tools/zek01").glob("*.gd"))]}}
    previous = out / "contract.json"
    if previous.exists():
        (out / f"contract-before-{generation}.json").write_bytes(previous.read_bytes())
    contract["workers"] = args.workers
    contract["retained_completed_cells"] = len(existing)
    contract["retained_cells_note"] = "Initial batch used the same new-combat rules and policy. Subsequent production edit only freezes a missing legacy fight seed; new combats already have that seed. Audit/fixture/skip controls do not change sweep decisions."
    (out / "contract.json").write_text(json.dumps(contract, indent=2) + "\n")
    def worker(index):
        first, last = args.samples * index // args.workers, args.samples * (index + 1) // args.workers
        log = out / f"worker-{generation}-{index}.log"
        command = [sys.executable, "tools/godot_task_runner.py", "--task-id", "zek-01", "--timeout", "0", "--stream", "--", "godot", "--headless", "--path", ".", "--script", "tools/zek01/measure.gd", "--", "--inputs", str(inputs), "--output", str(out / f"fights-{generation}-{index}.jsonl"), "--first", str(first), "--last", str(last), "--completed", str(completed)]
        with log.open("w") as stream:
            result = subprocess.run(command, cwd=ROOT, stdout=stream, stderr=subprocess.STDOUT)
        if result.returncode or f"ZEK01 MEASUREMENT PASS first={first} last={last}" not in log.read_text():
            raise RuntimeError(f"Measurement failed: {log}")
    with ThreadPoolExecutor(max_workers=args.workers) as pool:
        list(pool.map(worker, range(args.workers)))
    print(f"ZEK01 COLLECTION PASS N={args.samples}")

if __name__ == "__main__": main()
