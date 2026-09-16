#!/usr/bin/env python3
"""Generate or launch verified, resettable Guardian inspection saves."""
from __future__ import annotations

import argparse
import json
from pathlib import Path
import subprocess
import sys

ROOT = Path(__file__).resolve().parents[1]
TASK = "implement-guardian-combats-and-animated-encounters"
NAMES = {
    "ashen_reaver": "Ashen Reaver",
    "rimejaw": "Rimejaw",
    "storm_cantor": "Storm Cantor",
    "gallows_roc": "Gallows Roc",
    "craghide": "Craghide",
    "last_lamplighter": "Last Lamplighter",
}
STUDIES = {
    "encounter": "Begin combat with a prepared ordinary deck and full health",
    "pre_battle": "Inspect the named objective, enemies and loadout before entering",
    "relic": "Try the exclusive trophy on a small staged board",
    "map_entry": "Inspect the Guardian landmark from the section entrance",
    "map_choice": "Choose the Guardian route or its bypass",
    "reward": "Claim the trophy after defeating the Guardian",
    "outage": "Play after one brazier goes dark and its Shade appears",
    "outcrops": "Begin before Groundsplit with Craghide’s outcrops present",
    "summon": "Begin with Storm Cantor’s replacement-Wisp intent declared",
    "reinforcements": "Begin with a missing helper’s replacement intent declared",
    "ground_targeting": "Try Detonate on empty Fire ground within normal range, without a trophy",
    "network": "Play against the Cantor cohort after its opening electrical setup",
    "telegraph": "Inspect the Guardian's third intent and its current threats",
    "occupied_summon": "Stand on the reserved helper square and inspect its valid replacement",
    "displaced_pattern": "Inspect an announced pattern after displacing its caster",
    "sweep": "Play Low Sweep against a replacement Wisp sharing a defeated Wisp's square",
    "occlusion": "Inspect cover with the player standing behind it",
    "relight": "Begin with a dark brazier before Last Procession restores it",
}


def generate(actor: str, case: str, launch: bool = False) -> dict:
    key = actor + "-" + case
    manifest = ROOT / "output/guardian-revision-04/fixtures" / (key + ".json")
    manifest.parent.mkdir(parents=True, exist_ok=True)
    command = [sys.executable, str(ROOT / "tools/inspection_fixture.py"),
               "--project", str(ROOT), "--task-id", TASK,
               "--run-id", "guardian-" + key, "--manifest", str(manifest),
               "--scenario", "guardian", "--guardian-id", actor,
               "--guardian-case", case, "--seed", "7262026",
               "--summary", NAMES[actor] + ": " + STUDIES[case]]
    if launch:
        command.append("--launch")
    subprocess.run(command, cwd=ROOT, check=True)
    result = json.loads(manifest.read_text())
    if not result.get("verified"):
        raise RuntimeError("Standard persisted-save verifier did not pass: " + key)
    return {"key": key, "name": NAMES[actor], "case": case,
            "description": STUDIES[case], "manifest": str(manifest.relative_to(ROOT)),
            "launch_command": result["launch_command"]}


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("actor", nargs="?", default="ashen_reaver", choices=NAMES)
    parser.add_argument("--case", default="encounter", choices=STUDIES)
    parser.add_argument("--launch", action="store_true", help="Regenerate, verify, then open the game")
    parser.add_argument("--all", action="store_true", help="Verify the complete inspection catalog without opening windows")
    args = parser.parse_args()
    if args.all and args.launch:
        parser.error("--all generates saves; use --launch with a single actor and case")
    cases = [(args.actor, args.case)]
    if args.all:
        cases = [(actor, case) for actor in NAMES for case in ["pre_battle", "encounter", "relic", "reinforcements", "map_choice"]]
        cases += [("last_lamplighter", "map_entry"),
                  ("ashen_reaver", "reward"), ("ashen_reaver", "ground_targeting"), ("last_lamplighter", "outage"),
                  ("craghide", "outcrops"), ("storm_cantor", "summon"), ("storm_cantor", "network")]
        cases += [("craghide", "occupied_summon"), ("craghide", "occlusion"), ("storm_cantor", "sweep"), ("last_lamplighter", "relight"), ("last_lamplighter", "displaced_pattern"), ("gallows_roc", "displaced_pattern")]
        cases += [(actor, "telegraph") for actor in ["ashen_reaver", "rimejaw", "gallows_roc"]]
    results = [generate(actor, case, args.launch) for actor, case in cases]
    if args.all:
        head = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip()
        dest = ROOT / "output/guardian-revision-04/fixtures/catalog.json"
        dest.write_text(json.dumps({"head": head, "fixtures": results}, indent=2) + "\n")
        print(f"Verified {len(results)} Guardian fixtures: {dest}")


if __name__ == "__main__":
    main()
