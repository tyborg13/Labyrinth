#!/usr/bin/env python3
"""Compare the same run fixture across release and ux-18."""
import json
from pathlib import Path
import sys

directory = Path(sys.argv[1])
before, after = (
    json.loads((directory / label / "measurements.json").read_text())
    for label in ("before", "after")
)
states = {"sections", "entry_loop", "search_results", "search_empty", "controller_entry"}
if any(not report["ok"] or set(report["run_states"]) != states for report in (before, after)):
    sys.exit("FAIL: incomplete Grimoire proof")
for state in sorted(states):
    if before["run_states"][state] != after["run_states"][state]:
        for label, report in (("before", before), ("after", after)):
            (directory / label / (state + "-controls.json")).write_text(
                json.dumps(report["run_states"][state], indent=2) + "\n"
            )
        sys.exit(f"FAIL: run control state differs for {state}")
print("UX18 RUN STATE COMPARISON: PASS (5 states)")
for fixture, title in sorted(after["title_open_us"].items()):
    run = after["run_open_us"][fixture]
    release = before["run_open_us"][fixture]
    print(f"UX18 FIRST OPEN {fixture}: title {title} us, extracted run {run} us, release run {release} us")
    if title > run:
        print(f"UX18 FIRST OPEN {fixture}: title exceeded extracted run in this sample")
