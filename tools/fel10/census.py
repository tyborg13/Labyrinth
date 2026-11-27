#!/usr/bin/env python3
"""Build the inventory and select the first retained witness for each effect."""
from __future__ import annotations

import argparse
import json
from pathlib import Path
import re
import shutil

from inventory import ROOT, catalog

CHECKPOINT_FILES = ("run.save", "progression.json", "combat.witness")
# The first detector treated the shared summon atlas as hero summoning.
# Its summon row is a transit. The current detector requires the Illusion row.
LEGACY_SUMMON_ID = "player_summon"
WITNESS_LINE = re.compile(r"^FEL10 WITNESS (PASS|FAIL) ([a-z0-9_]+) (\S+) ")


def json_write(path: Path, value: object) -> None:
    path.write_text(json.dumps(value, indent=2, ensure_ascii=False) + "\n")


def read_lines(path: Path) -> list[dict]:
    with path.open() as stream:
        # A live campaign may still be completing its last line.
        return [json.loads(line) for line in stream if line.endswith("\n")]


def checkpoint_key(campaign: str, row: dict) -> str:
    return f"{campaign}-seed-{row['seed']:06d}-{row['checkpoint']}"


def witness_lines(paths: list[Path]) -> dict[tuple[str, str], str]:
    result = {}
    for path in paths:
        for line in path.read_text().splitlines():
            match = WITNESS_LINE.match(line)
            if match:
                result[match[2], match[3]] = line
    return result


def campaign_rows(campaigns: list[Path], known: set[str], excluded: set[tuple[str, str]],
                  passed: set[tuple[str, str]] | None = None) -> tuple[list[dict], dict, set[str]]:
    volumes = []
    first = {}
    observed = set()
    for campaign in campaigns:
        for seed in sorted(campaign.glob("seed-*")):
            ledger = seed / "fel10-turns.jsonl"
            trace = seed / "trace.jsonl"
            if not ledger.is_file() or not trace.is_file():
                continue
            events = read_lines(ledger)
            turns = [event["data"] for event in events if event["event"] == "turn"]
            decisions = sum(event["event"] == "decision" for event in read_lines(trace))
            encounters = {(row["section"], row["room"], row["room_kind"]) for row in turns}
            summary = seed / "summary.json"
            result = json.loads(summary.read_text()) if summary.is_file() else {}
            evidence = seed / "evidence.json"
            runtime = json.loads(evidence.read_text()) if evidence.is_file() else {}
            volumes.append({
                "campaign": campaign.name, "seed": int(seed.name.removeprefix("seed-")),
                "decisions": decisions, "turns": len(turns), "fights": len(encounters),
                "sections": sorted({encounter[0] for encounter in encounters}),
                "outcome": result.get("outcome", "watchdog timeout" if runtime.get("returncode") == 124 else "partial"),
                "wall_seconds": runtime.get("wall_seconds"), "returncode": runtime.get("returncode"),
            })
            for event in events:
                if event["event"] != "first":
                    continue
                row = event["data"]
                id = row["id"]
                if id == LEGACY_SUMMON_ID and row["source"] == "summon_front":
                    continue
                if id not in known:
                    raise ValueError(f"unknown observed effect {id} in {ledger}")
                observed.add(id)
                key = id, checkpoint_key(campaign.name, row)
                if key in excluded or (passed is not None and key not in passed):
                    continue
                old = first.get(id)
                if old is not None and old["observed_at"] <= row["observed_at"]:
                    continue
                first[id] = {**row, "_seed_folder": seed, "_campaign": campaign.name}
    return volumes, first, observed


def capture_plan(inventory: list[dict], first: dict) -> list[dict]:
    plan = []
    for entry in inventory:
        row = first.get(entry["id"])
        if row is None:
            continue
        plan.append({**{k: value for k, value in row.items() if not k.startswith("_")},
                     "checkpoint": checkpoint_key(row["_campaign"], row),
                     "family": entry["family"], "path": entry["path"]})
    return plan


def make_bundle(directory: Path, inventory: list[dict], first: dict) -> list[dict]:
    directory.mkdir(parents=True)
    (directory / ".gdignore").touch()
    plan = capture_plan(inventory, first)
    for entry in plan:
        id = entry["id"]
        row = first[id]
        dest = directory / entry["checkpoint"]
        source = row["_seed_folder"] / "witnesses" / row["checkpoint"]
        if not dest.exists():
            dest.mkdir()
            for name in CHECKPOINT_FILES:
                shutil.copyfile(source / name, dest / name)
        shutil.copyfile(source / f"{id}.inputs", dest / f"{id}.inputs")
    json_write(directory / "manifest.json", plan)
    return plan


def cell(value: object) -> str:
    return str(value).replace("|", "\\|").replace("\n", " ")


def table(headings: list[str], rows) -> list[str]:
    return [
        "| " + " | ".join(headings) + " |",
        "| " + " | ".join("---" for _ in headings) + " |",
        *("| " + " | ".join(map(cell, row)) + " |" for row in rows),
    ]


def markdown(volume: list[dict], inventory: list[dict], plan: list[dict],
             witness: dict[tuple[str, str], str], rejected: dict[tuple[str, str], str], observed: set[str]) -> str:
    evidence = {row["id"]: row for row in plan}
    verified = {row["id"]: WITNESS_LINE.match(line)[1] for row in plan
                if (line := witness.get((row["id"], row["checkpoint"])))}
    runtime = [row for row in inventory if row["evidence"] == "runtime"]
    audit = [row["id"] for row in inventory if row["evidence"] == "audit-only"]
    dormant = [row["id"] for row in inventory if row["evidence"] == "dormant"]
    missing = [row["id"] for row in runtime if row["id"] not in observed]
    unresolved = [row["id"] for row in runtime if row["id"] in observed and row["id"] not in evidence]
    sections = sorted({section + 1 for row in volume for section in row["sections"]})
    lines = [
        "# fel-10 combat effects census", "",
        f"{len(inventory)} inventory rows. The hunt observed {len(observed)} IDs and packaged {len(plan)} witnesses.",
        "", "## Draw paths", "",
        "The audit covers live combat board effects, persistent effects and targeting telegraphs. Action rows describe a production route. The atlas rows enumerate authored variants of shared routes, so a single frame can satisfy more than one ID.",
        "",
        "The procedural composite uses the screen-anchored 2 px grid at 1080p, Bayer alpha thresholds and the configured element ramp. Baked atlases have separate palettes and physical cell fits. Animation clocks can hold or repeat an authored cell across consecutive rendered frames.",
        "",
        *table(["ID", "Family", "Spawn or draw site", "Draw path", "Grid", "Blend", "Alpha", "Colour source", "Visible geometry", "Cost", "Evidence"], (
            [row["id"], row["family"], ", ".join(f"`{site}`" for site in row["sites"]),
             row["path"], row["grid"], row["blend"], row["alpha"], row["colors"], row["shape"], row["cost"],
             verified.get(row["id"], "kept") if row["id"] in evidence else "replay unresolved" if row["id"] in observed else "never observed" if row["evidence"] == "runtime" else row["evidence"]]
            for row in inventory
        )),
        "", "## Hunt coverage", "",
        f"Volume is {sum(row['turns'] for row in volume)} checkpointed turn starts over {sum(row['fights'] for row in volume)} seeded fights and {sum(row['decisions'] for row in volume)} production hunt decisions. Sections reached in combat are {', '.join(map(str, sections)) or 'none'}. Counts include finished ledger entries. In-game Section I corresponds to ledger section 0.",
        "",
        *table(["Campaign", "Seed", "Fights", "Turns", "Decisions", "Sections (1-based)", "Outcome", "Wall seconds", "Exit"], (
            [row["campaign"], row["seed"], row["fights"], row["turns"], row["decisions"],
             ", ".join(str(n + 1) for n in row["sections"]), row["outcome"],
             f"{row['wall_seconds']:.3f}" if row["wall_seconds"] is not None else "pending", row["returncode"]]
            for row in volume
        )),
        "", f"**Observed with packaged checkpoints ({len(plan)})**", "",
        *table(["ID", "Seed", "Section", "Room", "Turn", "Inputs", "Runtime source"], (
            [row["id"], row["seed"], row["section"] + 1, row["room"], row["turn"], row["inputs"], row["source"]]
            for row in plan
        )),
        "", f"**Observed without a packaged replay ({len(unresolved)})**", "", ", ".join(f"`{id}`" for id in unresolved) or "None.",
        "", f"**Never observed ({len(missing)})**", "", ", ".join(f"`{id}`" for id in missing) + ".",
        "", f"**Audit-only ({len(audit)})**", "",
        "The audit-only rows have inline painters without an individually attributable activation in the sampled inputs, or cover steady state and hover outside the recorded action prefix. An independent painter hook or interaction probe would be needed to witness those paths separately.",
        "", ", ".join(f"`{id}`" for id in audit) + ".",
        "", f"**Dormant ({len(dormant)})**", "", ", ".join(f"`{id}`" for id in dormant) + ".",
        "", "## Replay witness", "",
    ]
    if witness:
        lines += ["```text", *[witness[row["id"], row["checkpoint"]] for row in plan
                              if (row["id"], row["checkpoint"]) in witness], "```"]
    else:
        lines += ["Replay verification pending."]
    if rejected:
        lines += ["", "Earlier candidates below remain in their raw hunt directories. Their recorded input prefix did not reproduce the effect on Continue, so the bundle uses the next eligible observation when available.", "",
                  "```text", *rejected.values(), "```"]
    lines += [
        "", "## Proof for the design owner", "", "```sh",
        f"cd {ROOT} && tools/fel10/native.sh",
        f"cd {ROOT} && tools/fel10/native.sh --only player_melee_trail,player_block",
        "```", "",
        "Native output is written under `tools/fel10/captures/native.*/`. Open `index.md` for family sheets, full-size strips, the 25-frame sequences and the full-frame peaks. Windowed proof is pending.", "",
    ]
    return "\n".join(lines)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--campaign", type=Path, action="append", default=[])
    parser.add_argument("--inventory", type=Path)
    parser.add_argument("--bundle", type=Path)
    parser.add_argument("--report", type=Path)
    parser.add_argument("--witness-log", type=Path, action="append", default=[])
    parser.add_argument("--require-witness", action="store_true",
                        help="Package only exact candidates which have replayed successfully")
    parser.add_argument("--reject-witness-log", type=Path, action="append", default=[],
                        help="Skip exact candidates with a recorded FAIL in these logs")
    args = parser.parse_args()
    inventory = catalog()
    if args.inventory:
        json_write(args.inventory, inventory)
    known = {row["id"] for row in inventory if row["evidence"] == "runtime"}
    witness = witness_lines(args.witness_log)
    rejected = {key: line for key, line in witness_lines(args.reject_witness_log).items()
                if line.startswith("FEL10 WITNESS FAIL ") and not witness.get(key, "").startswith("FEL10 WITNESS PASS ")}
    if args.require_witness and not args.witness_log:
        parser.error("--require-witness needs at least one --witness-log")
    passed = {key for key, line in witness.items() if line.startswith("FEL10 WITNESS PASS ")}
    volume, first, observed = campaign_rows(args.campaign, known, set(rejected),
                                           passed if args.require_witness else None)
    if args.bundle:
        plan = make_bundle(args.bundle, inventory, first)
    else:
        plan = capture_plan(inventory, first)
    if args.report:
        args.report.write_text(markdown(volume, inventory, plan, witness, rejected, observed))
    print(f"FEL10 CENSUS rows={len(inventory)} observed={len(observed)} kept={len(plan)} never_observed={len(known) - len(observed)} "
          f"audit_only={sum(row['evidence'] == 'audit-only' for row in inventory)} "
          f"dormant={sum(row['evidence'] == 'dormant' for row in inventory)} "
          f"turns={sum(row['turns'] for row in volume)}")


if __name__ == "__main__":
    main()
