#!/usr/bin/env python3
"""Focused artifact/protocol checks; does not launch Godot or modify tests."""
from __future__ import annotations

import base64
from collections import Counter
import gzip
import hashlib
import json
from pathlib import Path
import sys

from report import wilson, median, write_report


def read(path: Path) -> list[dict]:
    with gzip.open(path, "rt") as stream:
        return [json.loads(line) for line in stream]


def verify(output: Path, allow_incomplete: bool = False) -> None:
    root = Path(__file__).resolve().parents[2]
    contract = json.loads((output / "contract.json").read_text())
    if not allow_incomplete:
        assert contract["complete"], "Budget-limited incomplete sample"
    assert contract["max_workers"] <= 4
    assert contract["elapsed_seconds"] < 90 * 60
    assert contract["selected_n"] in (48, 64)
    assert contract["source_head"] == contract["release_head"]
    for path, digest in contract["source_sha256"].items():
        assert hashlib.sha256((root / path).read_bytes()).hexdigest() == digest, path
    for path, digest in contract["measurement_tool_sha256"].items():
        assert hashlib.sha256((root / path).read_bytes()).hexdigest() == digest, path
    for name, digest in contract["artifact_sha256"].items():
        assert hashlib.sha256((output / name).read_bytes()).hexdigest() == digest, name
    raw_rows = read(output / "runs.jsonl.gz")
    assert len(raw_rows) == contract["completed_fights"]
    assert len({(r["cell"], r["ladder_seed"], r["repeat"]) for r in raw_rows}) == len(raw_rows)
    report_n = contract["reported_n_per_cohort"] if allow_incomplete else contract["selected_n"]
    assert report_n > 0 and report_n % 8 == 0
    report_repeats = report_n // 8
    rows = [r for r in raw_rows if r["repeat"] < report_repeats]
    inputs = read(output / "inputs.jsonl.gz")
    indexed = {(r["cell"], r["ladder_seed"]): r for r in inputs}
    assert len(indexed) == len(inputs) == 192
    for row in inputs:
        assert hashlib.sha256(base64.b64decode(row["typed_payload_base64"])).hexdigest() == row["input_sha256"]
    cells = Counter(r["cell"] for r in rows)
    assert len(cells) == 24 and set(cells.values()) == {report_n}
    keys = {(r["cell"], r["ladder_seed"], r["repeat"]) for r in rows}
    assert len(keys) == len(rows) == 24 * report_n
    for cell in cells:
        assert {(seed, repeat) for name, seed, repeat in keys if name == cell} == {
            (seed, repeat) for seed in range(1, 9) for repeat in range(report_repeats)}
    paired = {(r["cell"], r["ladder_seed"], r["repeat"]): r for r in rows}
    for row in raw_rows:
        assert row["hp_before"] == row["max_hp"] and row["policy_sha256"] == contract["policy_sha256"]
        assert row["combat_seed_input"] == row["ladder_seed"] + row["repeat"] * 1000003
        assert row["input_sha256"] == indexed[(row["cell"], row["ladder_seed"])]["input_sha256"]
        assert row["won"] is bool(row["won"]) and 1 <= row["turns"] <= 30
        if row["boss_hp_at_hero_death"] is not None:
            assert row["hp_after"] <= 0 and row["kind"] != "combat"
            assert row["boss_hp_at_hero_death"] >= 0
        if row["kind"] != "combat" and row["repeat"] < report_repeats:
            control = paired[("standard_for_" + row["identity"], row["ladder_seed"], row["repeat"])]
            assert all(row[k] == control[k] for k in ("section", "tier", "map_seed", "max_hp"))
    ladders = read(output / "ladders.jsonl.gz")
    assert len(ladders) == 8 and all(r["completed_ladder"] for r in ladders)
    entries = read(output / "entry_loadouts.jsonl.gz")
    assert len(entries) == 48
    for row in entries:
        assert hashlib.sha256(base64.b64decode(row["typed_payload_base64"])).hexdigest() == row["sha256"]
    assert abs(wilson(0, 64)[1] - 0.05662405979280534) < 1e-12
    assert (wilson(32, 64)[1] - wilson(32, 64)[0]) / 2 < .12
    assert (wilson(24, 48)[1] - wilson(24, 48)[0]) / 2 > .12
    assert median([2, 4]) == "3" and median([]) == "—"
    before = (output / "report.md").read_bytes()
    write_report(output)
    assert before == (output / "report.md").read_bytes(), "Report is not reproducible"
    print(f"MEAS07_ARTIFACT_VALIDITY_PASS target_complete={str(contract['complete']).lower()} cohorts=24 n={report_n} reported_fights={len(rows)} raw_fights={len(raw_rows)} inputs=192 entries=48 ladders=8 paired=true")
    print("MEAS07_STATISTICS_PASS Wilson_endpoints=true half_width_threshold=true medians=true report_reproducible=true")


if __name__ == "__main__":
    import argparse
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("output", type=Path)
    parser.add_argument("--allow-incomplete", action="store_true", help="Check data validity without claiming target sample completion")
    args = parser.parse_args()
    verify(args.output, args.allow_incomplete)
