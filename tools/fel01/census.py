#!/usr/bin/env python3
"""Select and package ranked turn starts from fel-01 run-hunt outputs."""
from __future__ import annotations

import argparse
from collections import Counter, defaultdict
import json
from pathlib import Path
import re
import shutil


TOOL_DIR = Path(__file__).resolve().parent
STATE_COUNT = 12
SECTION_CAP = 3
BOSS_CAP = 3
MIN_NORMAL_OR_OBJECTIVE = 7
COVERED_UNIT_WEIGHT = 3
SECTIONS = tuple(range(6))
KINDS = ("normal", "objective", "guardian", "dragon")
BOSS_KINDS = frozenset(("guardian", "dragon"))
CHECKPOINT_FILES = ("run.save", "progression.json", "combat.witness")
CANDIDATE_PREFIX = "FEL01 CANDIDATE "
PIECE_LABELS = frozenset(("pillar", "door", "scene_prop", "watch_brazier_dark", "watch_brazier_lit"))
PIECE_PREFIXES = ("terrain ", "loot ", "trap ")
UNIT_LABEL = re.compile(r" \[(?:player|(?:enemy|illusion)_-?\d+|npc_[^\]]+)\]$")
FLOOR_PREFIXES = (
    "surface ", "battlefield hazard", "boss area telegraph", "floor telegraph ",
    "intent area ", "Meteorfall mark", "Lob telegraph", "Icefall telegraph",
    "Burrow mark", "Death Burst telegraph",
)


def is_piece(label):
    """Classify a recorded tile label from board_score.gd."""
    if label in PIECE_LABELS or label.startswith(PIECE_PREFIXES) or UNIT_LABEL.search(label):
        return True
    if label.startswith(FLOOR_PREFIXES):
        return False
    raise ValueError(f"unrecognized census tile label {label!r}")


def rescore(row):
    old_score = row.pop("score")
    row["old_stacked"] = row["stacked"]
    stacked = 0
    for tile in row["tiles"]:
        pieces = sum(is_piece(label) for label in tile["contents"])
        tile["stacked"] = len(tile["contents"]) >= 2 and pieces > 0
        stacked += int(tile["stacked"])
    row["stacked"] = stacked
    row["old_score"] = old_score
    row["new_score"] = COVERED_UNIT_WEIGHT * row["covered_units"] + row["covered_tiles"] + stacked
    return row


def read_campaign(roots, campaign=None):
    candidates = []
    coverage = Counter()
    outcomes = {}
    for root in roots:
        summary = json.loads((root / "summary.json").read_text())
        outcomes[summary["seed"]] = summary["outcome"]
        fights = set()
        with (root / "trace.jsonl").open() as trace:
            for line in trace:
                event = json.loads(line)
                if event["event"] != "fel01_turn":
                    continue
                row = event["data"]
                fight = (row["section"], row["kind"], row["fight"])
                if fight not in fights:
                    fights.add(fight)
                    coverage[(row["section"], row["kind"])] += 1
        for path in sorted(root.glob("candidates/*/score.json")):
            row = rescore(json.loads(path.read_text()))
            row["source"] = path.parent
            if campaign:
                row["campaign"] = {"id": campaign, "seed_directory": root.name}
            candidates.append(row)
    return candidates, coverage, outcomes


def apply_candidate_screen(candidates, logs):
    evidence = {}
    for log in logs:
        with log.open() as lines:
            for line in lines:
                if line.startswith(CANDIDATE_PREFIX):
                    entry = json.loads(line[len(CANDIDATE_PREFIX):])
                    source = Path(entry["source"]).resolve()
                    if source in evidence:
                        raise ValueError(f"duplicate candidate evidence for {source}")
                    evidence[source] = entry
    passed = []
    for row in candidates:
        source = row["source"].resolve()
        if source not in evidence:
            raise ValueError(f"missing candidate evidence for {source}")
        entry = evidence[source]
        if entry["eligible"]:
            composition = entry["composition"]
            if not {"enemies_on_board", "visible_pillars", "boss_id"}.issubset(composition):
                raise ValueError(f"missing round-2 composition evidence for {source}")
            if row["kind"] in BOSS_KINDS and not composition["boss_id"]:
                raise ValueError(f"missing boss identity for {source}")
            row["composition"] = composition
            passed.append(row)
    print(f"FEL01 CANDIDATE SCREEN retained={len(passed)} skipped={len(candidates) - len(passed)}")
    return passed


def preference(row):
    composition = row.get("composition", {})
    return (
        -row["new_score"],
        -composition.get("enemies_on_board", 0),
        -composition.get("visible_pillars", 0),
    )


def order(row):
    return (*preference(row), row["section"], row["seed"], row["fight"], row["turn"])


def fight_key(row):
    return row["seed"], row["fight"].split("-", 1)[1]


def select(candidates, *, partial=False):
    # One row per real fight. Do not rely on the order that workers finished.
    fights = {}
    for row in sorted(candidates, key=order):
        fights.setdefault(fight_key(row), row)
    ranked = sorted(fights.values(), key=order)
    sections = defaultdict(list)
    for index, row in enumerate(ranked):
        sections[row["section"]].append(index)

    # Rank by summed score, enemy count, then visible pillars. Carry the boss
    # identities between sections so repeated rooms cannot win on rank alone.
    totals = {(0, frozenset()): (0, 0, 0, ())}
    for section in sorted(sections):
        in_section = {(count, bosses, 0): value for (count, bosses), value in totals.items()}
        for index in sections[section]:
            row = ranked[index]
            score, enemies, pillars = preference(row)
            boss = row["composition"]["boss_id"] if row["kind"] in BOSS_KINDS else ""
            if row["kind"] in BOSS_KINDS and not boss:
                raise ValueError(f"missing boss identity for {fight_key(row)}")
            for (count, bosses, used), (prior_score, prior_enemies, prior_pillars, picks) in tuple(in_section.items()):
                if count == STATE_COUNT or used == SECTION_CAP:
                    continue
                if boss and (boss in bosses or len(bosses) == BOSS_CAP):
                    continue
                next_bosses = bosses | {boss} if boss else bosses
                key = count + 1, next_bosses, used + 1
                offer = (
                    prior_score + score, prior_enemies + enemies, prior_pillars + pillars,
                    tuple(sorted((*picks, index))),
                )
                if key not in in_section or offer < in_section[key]:
                    in_section[key] = offer
        totals = {}
        for (count, bosses, _), value in in_section.items():
            key = count, bosses
            if key not in totals or value < totals[key]:
                totals[key] = value

    chosen = min(
        (value for (count, bosses), value in totals.items()
         if count == STATE_COUNT and count - len(bosses) >= MIN_NORMAL_OR_OBJECTIVE),
        default=None,
    )
    if chosen is None and partial:
        key = min(totals, key=lambda key: (-key[0], totals[key]))
        chosen = totals[key]
    return [ranked[index] for index in chosen[3]] if chosen else []


def fixture_id(index, row):
    return f"{index:02d}-s{row['section']}-seed{row['seed']}-{row['fight']}-t{row['turn']}"


def render(rows, coverage, outcomes, *, partial=False, campaign=None):
    runs = ", ".join(f"{seed} ({outcomes[seed]})" for seed in sorted(outcomes))
    lines = [
        "# Crowded real boards", "", f"Run-hunt seeds and outcomes — {runs}.", "",
        "Partial evidence only. The full coverage and 12-fixture requirements are open." if partial
        else f"The cohort contains {len(rows)} checkpoints. The source campaign reached all four fight kinds.",
        "",
        "Section numbers are zero-based.",
        "Old score = stacked tiles + covered tiles + 2 × covered units.",
        "New score = 3 × covered units + covered tiles + piece stacks.",
        "A piece stack has at least two contents, including a unit or board object.",
        "Tied scores favor more living enemies on the board, then more visible pillars.",
        "Tile coverage uses occ-02's 15% floor-diamond test against production rest-pose sprite masks.",
        "Unit coverage uses the union of later silhouettes in painter order, with a strict 25% threshold.",
    ]
    if campaign:
        lines.append(f"Fixture source campaign — `{campaign}`.")
    counts = Counter(row["kind"] for row in rows)
    bosses = [row["composition"]["boss_id"] for row in rows if row["kind"] in BOSS_KINDS]
    most_in_section = max(Counter(row["section"] for row in rows).values(), default=0)
    unique_fights = len({fight_key(row) for row in rows})
    lines.extend((
        "", "## Selection rules", "",
        f"- At most one state per boss. {len(set(bosses))} distinct bosses among {len(bosses)} boss states.",
        f"- At most {BOSS_CAP} dragon and Guardian states combined. Dragon count {counts['dragon']}, Guardian count {counts['guardian']}.",
        f"- At least {MIN_NORMAL_OR_OBJECTIVE} normal or objective states. Normal count {counts['normal']}, objective count {counts['objective']}.",
        f"- One state per fight, identified by seed and room. Selected {unique_fights} distinct fights.",
        f"- At most {SECTION_CAP} states per section. The largest section contribution is {most_in_section}.",
    ))
    lines.extend(("", "| Section | Normal | Objective | Guardian | Dragon |", "|---:|---:|---:|---:|---:|"))
    for section in SECTIONS:
        lines.append(f"| {section} | " + " | ".join(str(coverage[section, kind]) for kind in KINDS) + " |")
    lines.extend((
        "", "| Fixture | Seed | Section | Fight | Kind | Boss | Turn | Piece stacks | Covered tiles | Covered units | Old score | New score | Enemies | Pillars | Hover |",
        "|---|---:|---:|---|---|---|---:|---:|---:|---:|---:|---:|---:|---:|---|",
    ))
    for index, row in enumerate(rows, 1):
        key = fixture_id(index, row)
        fixture = key if partial else f"[{key}](fixtures/{key}/score.json)"
        focus = tuple(row["focus"]["tile"]) if row["focus"] else "—"
        composition = row.get("composition", {})
        lines.append(
            f"| {fixture} | {row['seed']} | {row['section']} | {row['fight']} | {row['kind']} "
            f"| {composition.get('boss_id') or '—'} | {row['turn']} | {row['stacked']} | {row['covered_tiles']} "
            f"| {row['covered_units']} | {row['old_score']} | {row['new_score']} "
            f"| {composition.get('enemies_on_board', '—')} | {composition.get('visible_pillars', '—')} | {focus} |"
        )
    for index, row in enumerate(rows, 1):
        lines.extend(("", f"## {fixture_id(index, row)}", "",
                      "| Tile | Visible contents | Piece stack | Occluding sprites |",
                      "|---|---|---|---|"))
        for tile in row["tiles"]:
            if not tile["stacked"] and not tile["occluders"]:
                continue
            blockers = ", ".join(
                f"{entry['id']} ({entry['fraction']:.1%})" for entry in tile["occluders"]
            )
            lines.append(
                f"| {tuple(tile['tile'])} | {', '.join(tile['contents'])} "
                f"| {'yes' if tile['stacked'] else '—'} | {blockers or '—'} |"
            )
        if row["units"]:
            lines.append("")
            for unit in row["units"]:
                lines.append(f"- {unit['unit']} at {tuple(unit['tile'])} — {unit['fraction']:.1%} covered.")
    return "\n".join(lines) + "\n"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("runs", nargs="+", type=Path, help="Completed seed directories with trace.jsonl")
    parser.add_argument("--output-dir", type=Path, default=TOOL_DIR)
    parser.add_argument("--campaign", help="Record the source campaign ID in each packaged score.json")
    parser.add_argument("--candidate-log", action="append", type=Path, default=[],
                        help="Include only candidates with passing phase evidence from candidate_probe.gd")
    parser.add_argument("--partial-report", action="store_true",
                        help="Write a provisional census on incomplete coverage without packaging fixtures")
    args = parser.parse_args()

    candidates, coverage, outcomes = read_campaign(args.runs, args.campaign)
    if not args.candidate_log and any(row["kind"] in BOSS_KINDS for row in candidates):
        parser.error("boss identities and ranking tie-breaks require --candidate-log")
    if args.candidate_log:
        try:
            candidates = apply_candidate_screen(candidates, args.candidate_log)
        except ValueError as error:
            parser.error(str(error))
    rows = select(candidates)
    missing_sections = [section for section in SECTIONS if not any(coverage[section, kind] for kind in KINDS)]
    census = args.output_dir / "census.md"
    if not rows or missing_sections:
        provisional = select(candidates, partial=True)
        report = render(provisional, coverage, outcomes, partial=True, campaign=args.campaign)
        print(f"FEL01 CENSUS INCOMPLETE candidates={len(candidates)} "
              f"provisional={len(provisional)} missing_sections={missing_sections}")
        if args.partial_report:
            census.write_text(report)
            print(census.resolve())
        else:
            print(report)
        return 1

    fixtures = args.output_dir / "fixtures"
    fixtures.mkdir(parents=True, exist_ok=False)
    for index, row in enumerate(rows, 1):
        destination = fixtures / fixture_id(index, row)
        destination.mkdir()
        for name in CHECKPOINT_FILES:
            shutil.copyfile(row["source"] / name, destination / name)
        score = {key: value for key, value in row.items() if key != "source"}
        (destination / "score.json").write_text(json.dumps(score, indent=2, ensure_ascii=False) + "\n")
    census.write_text(render(rows, coverage, outcomes, campaign=args.campaign))
    print(f"FEL01 CENSUS PASS seeds={len(outcomes)} fights={sum(coverage.values())} selected={len(rows)}")
    print(census.resolve())
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
