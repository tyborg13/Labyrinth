#!/usr/bin/env python3
"""Preserve every campaign error, comparison and analytics receipt in one index."""

import argparse
import importlib.util
import json
from pathlib import Path
import sys

from setup_harness import OUTPUT


def load_audit():
    spec = importlib.util.spec_from_file_location("qa129_evidence", OUTPUT / "harness/evidence.py")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def make_index(audit, paths):
    result = []
    for path in paths:
        for log in sorted(path.rglob("godot.log")):
            if not log.with_name("trace.jsonl").exists():
                continue
            audit_row = audit.analyze(log)
            audit_row["growth"] = [
                row["data"] for row in audit.read_rows(log.with_name("trace.jsonl"))
                if row["event"] == "qa131_growth"
            ]
            summary = log.with_name("evidence.json")
            if summary.exists():
                audit_row["runner_status"] = json.loads(summary.read_text())["returncode"]
            result.append(audit_row)
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("directories", type=Path, nargs="+")
    args = parser.parse_args()
    index = make_index(load_audit(), args.directories)
    json.dump(index, sys.stdout, indent=2)
    print()


if __name__ == "__main__":
    main()
