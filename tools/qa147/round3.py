#!/usr/bin/env python3
"""Compare round-3 choice outcomes and carry warnings from the task runner logs."""
import argparse
from pathlib import Path

OUTCOMES = {
    "CONTINUE": ("UNAVAILABLE", "PLAYABLE_BACKUP"),
    "NEW_RUN": ("UNAVAILABLE", "REPLACED"),
    "RISE_AGAIN": ("UNAVAILABLE", "REPLACED"),
    "NEW_RUN_DEPTH_SAVE_FAILURE": ("INSTALL_FAILED", "REPLACED_WITH_RECEIPTS"),
}
PROMOTION_ERROR = "Failed to promote the selected run backup."
CARRY_WARNING = "WARNING: Could not carry 2 win analytics receipts for run qa147r3_outgoing."


def read_result(directory, case):
    path = directory / f"{case}.log"
    log = path.read_text()
    marker = f"QA147R3 RESULT {case} "
    statuses = [line.removeprefix(marker) for line in log.splitlines() if line.startswith(marker)]
    if len(statuses) != 1 or "SCRIPT ERROR:" in log:
        raise ValueError(f"Expected one completed {case} probe in {path}")
    return statuses[0], log


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--before", required=True, type=Path)
    parser.add_argument("--after", required=True, type=Path)
    args = parser.parse_args()
    passed = True
    for case, expected in OUTCOMES.items():
        before, before_log = read_result(args.before, case)
        after, after_log = read_result(args.after, case)
        promotes = expected[0] == "UNAVAILABLE"
        warnings = [line.strip() for line in after_log.splitlines()
                    if "WARNING: Could not carry" in line]
        case_passed = ((before, after) == expected
                       and before_log.count(PROMOTION_ERROR) == int(promotes)
                       and PROMOTION_ERROR not in after_log
                       and warnings == ([CARRY_WARNING] if promotes else []))
        print(f"QA147R3 {case} before={before} after={after} {'PASS' if case_passed else 'FAIL'}")
        passed &= case_passed
    print(f"QA147R3 {'PASS' if passed else 'FAIL'} cases={len(OUTCOMES)}")
    return 0 if passed else 1


if __name__ == "__main__":
    raise SystemExit(main())
