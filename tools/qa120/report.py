#!/usr/bin/env python3
"""Render each mismatch with its input window and full evidence location."""

from argparse import ArgumentParser
from collections import Counter, defaultdict
from pathlib import Path
import json
import subprocess

PROJECT = Path(__file__).resolve().parents[2]
CONTROL_NAMES = {
    "gfix23_mouse": "gfix-23 A-select then empty-tile click",
    "gfix23_rotate": "gfix-23 fresh aim then RB",
    "gfix23_details": "gfix-23 lethal aim then Details",
}
BASE = "e47343f2caacf5cfce5c1eef8d4b866964774f78"


def read_records(path):
    with path.open() as stream:
        for number, line in enumerate(stream, 1):
            yield number, json.loads(line)


def classify(row, field, samples, verdict):
    case = row.get("case", "")
    actions = row.get("sequence", [])
    first = actions[0] if actions else {}
    second = actions[1] if len(actions) > 1 else {}
    persistent = verdict.startswith("persistent")
    if case == "gfix23_mouse" and field.startswith("pass."):
        return CONTROL_NAMES[case]
    if case == "gfix23_rotate" and field.startswith("rail."):
        return CONTROL_NAMES[case]
    if case == "gfix23_details" and field in {"details.intents", "board.intent_plates", "board.red"}:
        return CONTROL_NAMES[case]
    if persistent and first.get("worker_pending") and second.get("changed"):
        if second.get("kind") in {"mouse_board_click", "mouse_retarget"} and field.startswith("pass."):
            return CONTROL_NAMES["gfix23_mouse"]
        if second.get("kind") == "controller_rotate_rb" and field.startswith("rail."):
            return CONTROL_NAMES["gfix23_rotate"]
    if field.startswith("resolved.") or verdict.startswith("at Pass"):
        return "Pass dispatch and enemy-round outcome"
    if field.startswith("pass.") and not persistent:
        if any(sample.get("pending", {}).get("owns_selection") for sample in samples):
            return "Selected forecast publication window"
    if field.startswith("rail."):
        return "Rail publication after focus or aim"
    if field == "board.intent_plates":
        return "Intent-plate damage, danger and repetitions"
    if field == "board.red":
        return "Red floor coverage"
    if field == "details.intents":
        return "Details intent paths and targets"
    if field.startswith("card."):
        return "Card face or board preview values"
    return "Pass panel, rows and dock"


def difference(expected, shown):
    """Keep the source evidence complete and make the index easy to scan."""
    if isinstance(expected, dict) and isinstance(shown, dict):
        keys = sorted(key for key in expected.keys() | shown.keys() if expected.get(key) != shown.get(key))
        return ({key: expected[key] for key in keys if key in expected},
                {key: shown[key] for key in keys if key in shown})
    if isinstance(expected, list) and isinstance(shown, list):
        if all(isinstance(item, str) for item in [*expected, *shown]):
            return ([item for item in expected if item not in shown],
                    [item for item in shown if item not in expected])
        return ({index: item for index, item in enumerate(expected) if index >= len(shown) or item != shown[index]},
                {index: item for index, item in enumerate(shown) if index >= len(expected) or item != expected[index]})
    return expected, shown


def frame_ranges(samples):
    groups = []
    for sample in samples:
        frame = sample["frame"]
        if not groups or frame != groups[-1][-1] + 1:
            groups.append([frame])
        else:
            groups[-1].append(frame)
    return ", ".join(str(group[0]) if len(group) == 1 else f"{group[0]}…{group[-1]}" for group in groups)


def action_text(sequence):
    parts = []
    for action in sequence:
        details = [str(action[key]) for key in ("card", "target", "tile", "args") if action.get(key)]
        parts.append(action["kind"] + (" " + " ".join(details) if details else ""))
    return " → ".join(parts)


def report_code(value):
    return "`" + json.dumps(value, ensure_ascii=False, separators=(",", ":")).replace("|", "\\|").replace("`", "'") + "`"


def source_link(path, line=None):
    name = path.name if line is None else f"{path.parent.name} trace line {line}"
    anchor = "" if line is None else f":{line}"
    return f"[{name}]({path}{anchor})"


def action_losses(events):
    losses = Counter()
    for event in events:
        for loss in event.get("target_losses", []):
            if loss.get("kind") == "player":
                for field in ("hp", "block", "stoneskin"):
                    losses[field] += loss.get(field + "_loss", 0)
    return losses


def findings(campaign):
    groups = defaultdict(list)
    started = defaultdict(list)
    passed = Counter()
    for directory in campaign:
        path = Path(directory) / "trace.jsonl"
        if not path.exists():
            continue
        for line, row in read_records(path):
            if row["event"] == "start":
                started[row["encounter"]].append((row["seed"], row["section"], row["room_name"], row["enemies"], row.get("case")))
            if row["event"] == "pass":
                passed.update(row["checks"])
                passed["passes"] += 1
                outcome = row["outcome"]
                terminal = outcome.get("live_terminal", {})
                if terminal:
                    passed["pass_terminal_action_receipts"] += 1
                    expected = action_losses(outcome["action_receipts"])
                    actual = Counter(terminal["losses"])
                    if expected != actual:
                        row["issues"]["resolved.terminal_action_losses"] = {"expected": dict(expected), "shown": dict(actual)}
                for field, values in row["pre_pass_issues"].items():
                    group = classify(row, field, [], "at Pass dispatch")
                    groups[group].append((row, field, [{"values": values}], "at Pass dispatch", path, line))
            for field, samples in row.get("issues", {}).items():
                if row["event"] == "pass":
                    samples = [{"values": samples}]
                    verdict = "resolved outcome"
                else:
                    verdict = row.get("verdicts", {}).get(field, "unclassified")
                group = classify(row, field, samples, verdict)
                groups[group].append((row, field, samples, verdict, path, line))
    return groups, started, passed


def append_findings(lines, groups):
    lines.extend(["## Mismatch index", "",
                  "Frame 0 is the immediate read after the second input. Negative frames precede it. "
                  "The last differing sample is printed for each field. Trace lines contain complete values and every frame. "
                  "The index omits fields common to expected and shown. Red lists display only differing tiles. "
                  "A gap of `—` indicates one ordinary legal dispatch."])
    for group, rows in groups.items():
        lines.extend(["", f"### {group}", "",
                      "| Seed / step / section | Inputs | Gap | Field | Frames and resolution | Expected | Shown | Evidence |",
                      "| --- | --- | ---: | --- | --- | --- | --- | --- |"])
        for row, field, samples, verdict, path, line in rows:
            values = samples[-1]["values"]
            expected, shown = difference(values.get("expected"), values.get("shown"))
            frames = frame_ranges(samples) + ", " if "frame" in samples[0] else ""
            gap = row.get("gap", -1)
            cells = [
                f"{row['seed']} / {row['step']} / {row['section']}",
                action_text(row.get("sequence", [])),
                str(gap) if gap >= 0 else "—",
                f"`{field}`", frames + verdict,
                report_code(expected), report_code(shown), source_link(path, line),
            ]
            lines.append("| " + " | ".join(cells) + " |")


def build(campaign_path, report_path):
    summary = json.loads(campaign_path.read_text())
    coverage = summary["coverage"]
    runs = [summary["controls"], *summary["shards"]]
    if "input_matrix" in summary:
        runs.append(summary["input_matrix"])
    groups, started, passed = findings([run["directory"] for run in runs])
    all_rows = [entry for rows in groups.values() for entry in rows]
    persistent = [entry for entry in all_rows if entry[3].startswith("persistent")]
    terminal = passed["pass_terminal_live_receipt"]
    lines = [
        "# qa-120 | Forecast truth soak", "",
        f"Baseline `{BASE}` on `codex/release`, with perf-154b and before gfix-23. "
        "Headless Godot 4.6.1 sampled the production RunScene at 1920×1080 and 100% UI scale. "
        "The soak changes only diagnostic tools.", "",
        "## Result", "",
        f"- {coverage['seeds']} seeds across sections I–III "
        f"({coverage.get('section-1', 0)} / {coverage.get('section-2', 0)} / {coverage.get('section-3', 0)}). "
        f"{coverage.get('guardian', 0)} Guardian fights and {coverage.get('boss', 0)} dragon fights. "
        f"{coverage.get('ordinary_speed_seed', 0)} seeds used normal combat pacing.",
        f"- {passed['passes']} Pass receipts. {passed['pass_exact_total']} had a fully numeric horizon and "
        f"{passed['pass_disclosed_minimum']} used the known-minimum comparison. "
        f"{passed['pass_replay_vs_live']} were verified against the complete live state and {terminal} against live terminal analytics. "
        f"The report reconciled damaging action receipts for {passed['pass_terminal_action_receipts']} terminal Passes.",
        f"- {len(all_rows)} differing field/window pairs, of which {len(persistent)} still differed after the "
        "24-frame window with no observed pending owner. One underlying mismatch can affect several fields.",
        f"- Coverage gaps {summary['coverage_gaps'] or 'none'}. Failed runs {summary['failed_runs'] or 'none'}. "
        + source_link(campaign_path),
        "", "## Known gfix-23 controls", "",
    ]
    for label in CONTROL_NAMES.values():
        rows = groups.get(label, [])
        finding_text = ", ".join(f"`{row[1]}` ({row[3]})" for row in rows if row[0].get("case") in CONTROL_NAMES)
        lines.append(f"- **{label}**. {finding_text or 'No matching mismatch was observed.'}")
    lines.extend(["", "## Persistent and outcome findings", ""])
    if persistent:
        for group, count in Counter(classify(row, field, samples, verdict)
                                    for row, field, samples, verdict, _, _ in persistent).most_common():
            lines.append(f"- {group} appeared in {count} field/window pairs. See the matching index below.")
    else:
        lines.append("- Every assessed difference cleared before the last sample or still had a pending owner.")
    if any(row[1] == "board.intent_plates" for row in persistent):
        lines.append("- Some persistent plate differences are repeat pips. The same target can retain a schedule-derived "
                     "repeat when the exact selected forecast was never adopted by the board. "
                     "Compare the corresponding plate and Pass rows in the trace. "
                     "[Stage refresh](/Users/borgerding/workspace/Labyrinth.worktrees/qa-120/scripts/stage_hover_refresh.gd:45)")
    if any(row[1] == "pass.rows" for row in persistent):
        lines.append("- The repeat portrait rows can lag the remainder of the Pass panel. "
                     "The panel builds portraits using the rail available at publication time. "
                     "[Pass presentation](/Users/borgerding/workspace/Labyrinth.worktrees/qa-120/scripts/pass_forecast_presentation.gd:104)")
    lines.extend([
        "",
        "The pending selection worker intentionally conceals the previous rows before publication. "
        "The index keeps these gaps alongside incorrect concrete values and records the worker phase. "
        "The oracle compares repeat pips starting at two activations, where the painter first displays a number.",
    ])
    outcome_issues = [row for row in all_rows if row[1].startswith("resolved.")]
    lines.extend(["", f"{len(outcome_issues)} resolved outcome differences. Each Pass record includes positions, "
                  "Health, Block, Stoneskin, status gains and the terminal result."])
    lines.extend([
        "", "## Campaign and oracle", "",
        "- Seeded fights start from a production-generated room save in the designated section. The run-hunt "
        "policy chooses legal combat moves and cards. Timed inputs enter through the real viewport. Actions used "
        "to advance the fight can use production handlers via the run-hunt policy. Normal-speed seeds keep "
        "the ordinary animation rate and use the 24-frame input gap.",
        "- The observer reads the dock and forecast row nodes, rail numerals and tooltips, board paint inputs, "
        "Details threat records and hand widgets. It compares them to a synchronous forecast source and "
        "fresh selected resolution with private scratch caches, plus a fresh rail and intent projection.",
        "- For Pass, the second resolver uses the full committed enemy phase. The loss tally uses qa-99's "
        "step accounting, including turn-end damage and excluding ordinary Block expiry. It is checked "
        "against the live arrived board, or against the live combat-ended event and its action and death receipts "
        "when the terminal transition has released the board. Under an undisclosed horizon, only an overclaim "
        "against the resolved loss is flagged.",
        "- Headless uses synthetic post-draw boundaries, so the frame ranges measure publication order "
        "inside the scene tree. Native inspection is needed for timing, paint, occlusion, and text legibility.",
        "", "### Input gap coverage", "",
        "| Gap in process frames | Accepted first inputs |", "| ---: | ---: |",
    ])
    for gap in [*range(7), 24]:
        lines.append(f"| {gap} | {coverage.get(f'accepted-gap-{gap}', 0)} |")
    lines.extend(["", "### Input paths that changed state", "",
                  "| Input | First | Second |", "| --- | ---: | ---: |"])
    kinds = sorted({key.split(":", 1)[1] for key in coverage if key.startswith(("accepted-first:", "accepted-second:"))})
    for kind in kinds:
        lines.append(f"| {kind} | {coverage.get('accepted-first:' + kind, 0)} | "
                     f"{coverage.get('accepted-second:' + kind, 0)} |")
    lines.extend(["", "### Encounter anchors", ""])
    for kind in ("guardian", "boss"):
        for seed, section, room, units, case in sorted(started[kind]):
            if not case:
                lines.append(f"- Seed {seed}, section {section}, {room}. {', '.join(units)}.")
    lines.extend(["", "### Verification receipts", ""])
    for run in runs:
        file = Path(run["directory"]) / "runner.log"
        result = next((line for line in file.read_text().splitlines() if line.startswith("QA120 RESULT ")),
                      f"Runner exited {run['returncode']} before emitting a result.")
        lines.append(f"- {file.parent.name} · `{result}` · {source_link(file)}")
    lines.extend(["", "### Runner diagnostics", ""])
    for run in runs:
        log = Path(run["directory"]) / "runner.log"
        diagnostics = [line for line in log.read_text().splitlines() if line.startswith(("ERROR:", "WARNING:"))]
        if diagnostics:
            lines.append(f"- {log.parent.name} · " + " · ".join(f"`{item}`" for item in dict.fromkeys(diagnostics))
                         + " · " + source_link(log))
    lines.extend(["", "Native 1920×1080 follow-ups and reproduction commands are in the "
                  "[qa-120 README](/Users/borgerding/workspace/Labyrinth.worktrees/qa-120/tools/qa120/README.md).", ""])
    append_findings(lines, groups)
    expected_head = subprocess.check_output(["git", "rev-parse", "HEAD"], text=True, cwd=PROJECT).strip()
    if expected_head != BASE:
        raise SystemExit(f"Report is bound to {BASE}, current HEAD is {expected_head}")
    report_path.write_text("\n".join(lines) + "\n")
    print(f"QA120 REPORT: {passed['passes']} Pass receipts, {len(all_rows)} differences, {len(persistent)} persistent "
          f"at {report_path}")


def main():
    parser = ArgumentParser(description=__doc__)
    parser.add_argument("campaign", type=Path)
    parser.add_argument("report", type=Path)
    args = parser.parse_args()
    build(args.campaign.resolve(strict=True), args.report.resolve())


if __name__ == "__main__":
    main()
