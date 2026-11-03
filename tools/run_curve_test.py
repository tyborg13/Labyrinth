#!/usr/bin/env python3
"""Explicit-only focused proof; intentionally outside tests/ and default groups."""
from __future__ import annotations

import argparse
import concurrent.futures
import hashlib
import json
from pathlib import Path
import tempfile

from run_curve import policy_hash, read_records, sha256, worker, write_scores


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output-dir", type=Path, required=True)
    parser.add_argument("--ladder", action="store_true", help="Also prove a full seeded ladder run twice")
    args = parser.parse_args()
    args.output_dir.mkdir(parents=True, exist_ok=True)
    frozen = policy_hash()
    with tempfile.TemporaryDirectory(prefix="run-curve-proof-", dir=args.output_dir) as directory:
        scratch = Path(directory)
        scores = scratch / "scores.json"
        write_scores(scores)
        records = []
        for repeat in (1, 2):
            output = scratch / f"repeat-{repeat}.jsonl"
            log = args.output_dir / f"determinism-{repeat}.log"
            worker("best", 1, 1, scores, output, log)
            result = read_records(output)
            assert len(result) == 1 and result[0]["seed"] == 1
            assert result[0]["entries"][0]["hp"] == 24
            assert result[0]["entries"][0]["max_hp"] == 24
            assert result[0]["fights"] and result[0]["choices"]
            records.append(result[0])
        assert records[0] == records[1], "Whole-run records are not deterministic"
        assert policy_hash() == frozen
        proof = {"result": "PASS", "policy": "best", "seed": 1, "repeat_count": 2,
                 "record_sha256": __import__("hashlib").sha256(json.dumps(records[0], sort_keys=True).encode()).hexdigest(),
                 "policy_sha256": frozen, "end_section": records[0]["end_section"],
                 "fights": len(records[0]["fights"]), "choices": len(records[0]["choices"])}
        (args.output_dir / "determinism.json").write_text(json.dumps(proof, indent=2) + "\n")
    print("RUN_CURVE_DETERMINISM_PASS policy=best seed=1 repeats=2")
    if args.ladder:
        with tempfile.TemporaryDirectory(prefix="run-curve-ladder-proof-", dir=args.output_dir) as directory:
            scratch = Path(directory)
            scores = scratch / "scores.json"
            write_scores(scores)
            with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
                jobs = [pool.submit(worker, "best", 1, 1, scores, scratch / f"repeat-{repeat}.jsonl",
                                    args.output_dir / f"ladder-determinism-{repeat}.log", 0, True)
                        for repeat in (1, 2)]
                for job in jobs: job.result()
            records = [read_records(scratch / f"repeat-{repeat}.jsonl")[0] for repeat in (1, 2)]
            assert records[0] == records[1], "Ladder records are not deterministic"
            row = records[0]
            assert row["completed_ladder"] and row["end_section"] == 5
            assert [e["section"] for e in row["entries"]] == list(range(6))
            assert row["health_resets"] == len(row["fights"])
            assert all(f["hp_before"] == f["max_hp_before"] for f in row["fights"])
            assert row["forced_victories"] == sum(not f["won"] for f in row["fights"])
            assert row["turn_cap_fights"] == sum(f["turn_cap_reached"] for f in row["fights"])
            assert row["card_reward_picks"] == sum(c["kind"] == "card_reward" and bool(c["picked"]) for c in row["choices"])
            old = json.loads((Path(__file__).resolve().parents[1] / "spec/peer_benchmark/encounter_redesign/measurements/run_curve_2026-11/determinism.json").read_text())
            assert proof["record_sha256"] == old["record_sha256"], "Normal mode changed"
            result = {"result": "PASS", "seed": 1, "repeat_count": 2,
                      "record_sha256": hashlib.sha256(json.dumps(row, sort_keys=True).encode()).hexdigest(),
                      "policy_sha256": frozen, "fights": len(row["fights"]),
                      "forced_victories": row["forced_victories"], "sections": 6}
            (args.output_dir / "ladder-determinism.json").write_text(json.dumps(result, indent=2) + "\n")
            (args.output_dir / "ladder-seed-1.json").write_text(json.dumps(row, indent=2) + "\n")
        print("RUN_CURVE_LADDER_DETERMINISM_PASS policy=best seed=1 repeats=2 sections=6")
    assert policy_hash() == frozen
    print(f"RUN_CURVE_POLICY_HASH_PASS sha256={frozen}")


if __name__ == "__main__":
    main()
