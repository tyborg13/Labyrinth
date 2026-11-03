#!/usr/bin/env python3
"""Replay legacy delayed-source rows to recover the originating intent.

The old observer retained the correct owner and HP loss, but looked up that
owner's live intent at contact. Retaliate similarly needs its granting intent.
Win rates and F/G selection are unchanged.
"""
from __future__ import annotations

import argparse
from concurrent.futures import ThreadPoolExecutor
import hashlib
import json
from pathlib import Path

from encounter_bot import compress_report, read_report
from encounter_shadow_dial_measurement import ARTIFACTS, RESULT_PATH, ROOT, policy_hash, run

ATTRIBUTION_VERSION = "source_origin_v1"


def needs_replay(row: dict) -> bool:
    return any(source["kind"] in ("surface_fire", "retaliate") and source["enemy_type"] != "non_enemy"
               for hit in row["damage"]["hits"] for source in hit["sources"])


def reconcile(old: dict, new: dict) -> int:
    for key in old:
        if key != "damage":
            assert old[key] == new[key], (old["tier"], old["biome"], old["seed"], key)
    assert old["damage"]["activations"] == new["damage"]["activations"]
    assert len(old["damage"]["hits"]) == len(new["damage"]["hits"])
    changed = 0
    for before, after in zip(old["damage"]["hits"], new["damage"]["hits"]):
        for key in before:
            if key != "sources": assert before[key] == after[key], (old["seed"], key)
        assert len(before["sources"]) == len(after["sources"])
        for source, corrected in zip(before["sources"], after["sources"]):
            for key in source:
                if key != "intent_id": assert source[key] == corrected[key], (old["seed"], key)
            if source["intent_id"] != corrected["intent_id"]:
                assert source["kind"] in ("surface_fire", "retaliate") and source["enemy_type"] != "non_enemy"
                changed += 1
    return changed


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output-dir", type=Path, default=ARTIFACTS)
    parser.add_argument("--work-dir", type=Path, default=RESULT_PATH.parent / "source-repair")
    parser.add_argument("--workers", type=int, default=4)
    args = parser.parse_args()
    if not 1 <= args.workers <= 4: parser.error("workers must be 1..4")
    args.work_dir.mkdir(parents=True, exist_ok=True)
    catalog = args.work_dir / "catalog.json"
    catalog.write_text(json.dumps(read_report(args.output_dir / "catalog.json.gz"), indent=2) + "\n")
    reports = {}
    for group in ("baseline", *"ABCDEFG"):
        for tier in (1, 2, 3):
            for biome in (("shadow", "earth") if group == "baseline" else ("shadow",)):
                path = args.output_dir / f"{group}-t{tier}-{biome}.json.gz"
                if path.exists(): reports[group, tier, biome] = read_report(path)
    if all(report.get("damage_provenance") == ATTRIBUTION_VERSION for report in reports.values()):
        print("SHADOW SOURCE PROVENANCE: retained (records already use origin attribution)")
        return
    jobs = [(group, tier, biome, index, row, report["selection"]) for (group, tier, biome), report in reports.items()
            if report.get("damage_provenance") != ATTRIBUTION_VERSION
            for index, row in enumerate(report["results"]) if needs_replay(row)]
    source_inputs = {str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest()
                     for p in sorted([*ROOT.glob("scripts/**/*.gd"), *ROOT.glob("data/**/*.json"), *ROOT.glob("tools/encounter*.gd")])}
    inputs = args.work_dir / "inputs.json"
    inputs.write_text(json.dumps({"policy_sha256": policy_hash(), "sources": source_inputs,
                                  "jobs": [{"group": g, "tier": t, "biome": b, "index": i, "seed": r["seed"], "selection": s} for g, t, b, i, r, s in jobs]}, indent=2) + "\n")
    compress_report(inputs, args.output_dir / "source-repair-inputs.json.gz")
    # Preserve the previous observer's records for a full attribution-only diff.
    legacy = args.work_dir / "legacy-results.json"
    if not legacy.exists():
        legacy.write_text(json.dumps({f"{g}/{t}/{b}": r for (g, t, b), r in reports.items()}, indent=2) + "\n")
        compress_report(legacy, args.output_dir / "legacy-results.json.gz")

    def replay(job: tuple) -> tuple:
        group, tier, biome, index, old, selection = job
        name = f'{group}-t{tier}-{biome}-s{int(old["seed"])}'
        path = args.work_dir / f"{name}.json"
        run(["--catalog", str(catalog), "--group", group, "--tier", str(tier), "--biome", biome,
             "--offset", str(index), "--runs", "1", "--selection", json.dumps(selection), "--output", str(path)], args.work_dir / f"{name}.log")
        captured = json.loads(path.read_text())
        assert captured["damage_provenance"] == ATTRIBUTION_VERSION
        row = captured["results"][0]
        changed = reconcile(old, row)
        print(f"SHADOW SOURCE REPLAY: PASS ({name}; {changed} corrected labels; all outcomes/hit amounts/timing identical)", flush=True)
        return group, tier, biome, index, row, changed

    with ThreadPoolExecutor(max_workers=args.workers) as pool:
        corrected = list(pool.map(replay, jobs))
    assert all(hashlib.sha256((ROOT / path).read_bytes()).hexdigest() == digest for path, digest in source_inputs.items())
    for group, tier, biome, index, row, _ in corrected: reports[group, tier, biome]["results"][index] = row
    for (group, tier, biome), report in reports.items():
        report["damage_provenance"] = ATTRIBUTION_VERSION
        path = args.work_dir / f"{group}-t{tier}-{biome}.json"
        path.write_text(json.dumps(report, indent=2) + "\n")
        compress_report(path, args.output_dir / path.with_suffix(".json.gz").name)
    summary = {"replayed_runs": len(corrected), "baseline_replays": sum(row[0] == "baseline" for row in corrected),
               "changed_intent_labels": sum(row[5] for row in corrected),
               "outcomes_hit_amounts_and_timing_unchanged": True, "policy_sha256": policy_hash()}
    (args.output_dir / "source-repair.json").write_text(json.dumps(summary, indent=2) + "\n")
    print(f'SHADOW SOURCE PROVENANCE: PASS ({len(corrected)} replays; {summary["changed_intent_labels"]} corrected labels; all outcomes/hit amounts/timing identical)')


if __name__ == "__main__":
    main()
