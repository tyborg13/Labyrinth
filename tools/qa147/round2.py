#!/usr/bin/env python3
"""Verify the round-2 baseline and candidate witnesses from the task runner logs."""
import argparse
import json
from pathlib import Path

EVENTS = ["combat_ended", "reward_offered"]
MARKER = "QA147R2 RESULT "


def read_result(directory, case):
    path = directory / (case + ".log")
    results = [json.loads(line.removeprefix(MARKER))
               for line in path.read_text().splitlines() if line.startswith(MARKER)]
    if len(results) != 1 or results[0]["finding"] != case:
        raise ValueError(f"Expected a single {case} result in {path}")
    return results[0]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--before", required=True, type=Path)
    parser.add_argument("--after", required=True, type=Path)
    args = parser.parse_args()

    stale = "STALE_CHECKPOINT"
    before = read_result(args.before, stale)
    after = read_result(args.after, stale)
    stale_passed = (not before["passed"] and before["title_rows"] == before["rows_after"] == 0
                    and after["passed"] and after["title_rows"] == 2 and after["rows"] == EVENTS
                    and after["rows_before"] == after["duplicates"] == 0)
    print(f'QA147R2 {stale} rows_before={before["rows_after"]} rows_after={after["rows_after"]} '
          f'duplicates={after["duplicates"]} {"PASS" if stale_passed else "FAIL"}')

    departure = "DEPARTING_DEFEAT"
    before = read_result(args.before, departure)
    after = read_result(args.after, departure)
    departure_passed = (not before["passed"] and before["live_writes"] == 1
                        and before["replayed_on_continue"] == 0 and after["passed"]
                        and after["live_writes"] == 0 and after["staged_kept"]
                        and after["replayed_on_continue"] == 1 and after["rows"] == EVENTS)
    print(f'QA147R2 {departure} live_writes={after["live_writes"]} '
          f'staged_kept={str(after["staged_kept"]).lower()} '
          f'replayed_on_continue={after["replayed_on_continue"]} '
          f'{"PASS" if departure_passed else "FAIL"}')
    passed = stale_passed and departure_passed
    print(f"QA147R2 {'PASS' if passed else 'FAIL'} findings=2")
    return 0 if passed else 1


if __name__ == "__main__":
    raise SystemExit(main())
