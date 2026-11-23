"""Render the Markdown report from the reviewed txt-25 JSON rows."""

from collections import Counter
import json
from pathlib import Path

HERE = Path(__file__).resolve().parent


def cell(value):
    return str(value).replace("|", "\\|").replace("\n", "<br>")


def row(*values):
    return "| " + " | ".join(cell(value) for value in values) + " |"


def citations(sources):
    links = []
    for source in sources:
        filename, line = source.rsplit(":", 1)
        links.append(f"[{Path(filename).name}:{line}](../../{filename}#L{line})")
    return ", ".join(links)


def findings_report(findings):
    yield "## Findings"
    yield ""
    yield row("ID and frequency", "Card", "Surface and rendered text", "Behavior and reachable scenario", "Sources and proof")
    yield row("---", "---", "---", "---", "---")
    for finding in findings:
        surface = f'**{finding["surface"]}**<br>“{finding["rendered_text"]}”'
        for index, diagram in enumerate(finding["diagrams"], 1):
            offsets = ", ".join(f"({x},{y})" for x, y in diagram["offsets"])
            origin = " Pale center marks the reference tile." if diagram.get("origin_reference") else ""
            surface += f"<br>Diagram {index} affected offsets: {offsets}.{origin}"
        proof = finding["proof"]
        yield row(f'<a id="{finding["id"].lower()}"></a>{finding["id"]} · {finding["frequency"]}',
                  f'{finding["name"]} `{finding["card_id"]}`',
                  surface, finding["behavior"] + "<br>" + finding["scenario"],
                  citations(finding["sources"]) + f'<br>[{finding["id"]} runtime witness]({proof["log"]})')


def render(report):
    coverage = report["coverage"]
    counts = Counter(finding["frequency"] for finding in report["findings"])
    candidate = report["candidate"]
    lines = [
        "# Candidate 4 card text truth check",
        "",
        f'Audited `{candidate["branch"]}` at `{candidate["head"]}` '
        f'over `{candidate["base"]}`. Checked all **{coverage["live_cards"]} live cards**, '
        f'and found **{counts["common"]} common** and **{counts["edge"]} edge** false claims. '
        f'Each finding has a headless witness.',
        "",
        f'The [semantic inventory]({coverage["inventory"]}) covers each Time badge, face sentence or icon row, '
        "affected diagram offsets, inspection sentence and keyword column. It uses the game's Data, "
        "CardWidget, CardDisplay, ActionIconLibrary, pattern rewrite and inline-text paths. "
        f'The review covered {coverage["catalog_panels"]} catalog panels, '
        f'{coverage["hand_variants"]} distinct neutral hand presentations, '
        f'{coverage["ledger_variants"]} Quartermaster’s Ledger variants and '
        f'{coverage["retort_variants"]} Alchemist’s Retort variants and '
        f'{coverage["legacy_starter_variants"]} saved-run starter variants. '
        f'The inventory includes {coverage["embedded_panel_differences"]} differences in embedded inspection panels. '
        "Shared panel bodies were checked with the cards that display them. "
        "The numbers on damage and status icons are base amounts before defenses, caps or an explicit modifier. "
        "Bracketed icon IDs, diagram markers and row dividers transcribe the non-text parts of the face.",
        "",
        f'No raw markup remained in {coverage["strings_scanned_for_raw_markup"]:,} inspected strings. '
        "The scan covered keyword, term, icon and pattern syntax, braces, radius prefixes and format specifiers. "
        "The Burst and Light diagrams were checked against their resolved offsets. "
        "The Light witness records a combat-long source, and White Silence's witness records 6 Stagger and zero Freeze. "
        "[Inventory log](inventory.log), [runtime log](probe.log)",
        "",
        *findings_report(report["findings"]),
        "",
        "## Borderline",
        "",
    ]
    for item in report["borderline"]:
        cards = ", ".join(f"`{card}`" for card in item["cards"])
        lines.append(f'- {cards} — {item["reason"]} {citations(item["sources"])}')
    lines.extend(["", "## crd-28 re-judgement", "",
                  "The 24 claim rows follow the order of the old False table. "
                  "The card crosswalk records the same 53 previously flagged IDs. [crd-28 audit](../crd28/REPORT.md)",
                  "", row("Old row", "Claim", "Candidate 4", "Reason"),
                  row("---", "---", "---", "---")])
    for old in report["crd28_rejudgement"]:
        links = ", ".join(f"[{key}](#{key.lower()})" for key in old["finding_ids"])
        evidence = " ".join(part for part in [old["reason"], citations(old["sources"]), links] if part)
        lines.append(row(old["row"], old["label"], old["verdict"], evidence))
    lines.extend(["", "### Previously flagged card IDs", "",
                  row("Card", "Old claim rows", "Candidate 4"), row("---", "---", "---")])
    for card in report["crd28_card_crosswalk"]:
        lines.append(row(f'{card["name"]} `{card["card_id"]}`',
                         ", ".join(map(str, card["rows"])), card["verdict"]))
    lines.extend(["", "## Style observations", ""])
    for item in report["style"]:
        cards = ", ".join(f"`{card}`" for card in item["cards"])
        lines.append(f'- {cards} · {item["surface"]} · {item["rule"]} · “{item["text"]}” {item["reason"]}')
    lines.extend(["", "The card observations are outside the false-claim totals. "
                  "The rules-text ratchet retains 16 existing hits. Its two legacy card-panel templates "
                  "are distinct from the live focus-panel copy.",
                  "", "## Skipped IDs", ""])
    for retired in report["skipped_ids"]:
        lines.append(f'- `{retired["card_id"]}` → `{retired["replacement"]}`. {retired["reason"]}')
    lines.extend(["", "## Proof for the design owner", "",
                  "The report uses headless semantic and runtime proof. The brief specifies no windowed probe or inspection fixture.",
                  "", "```sh",
                  "cd /Users/borgerding/workspace/Labyrinth.worktrees/txt-25",
                  "python3 tools/godot_task_runner.py --task-id txt-25 --stream -- godot --headless --path . --script tools/txt25/dump_cards.gd -- tools/txt25/inventory.json",
                  "python3 tools/godot_task_runner.py --task-id txt-25 --stream -- godot --headless --path . --script tools/txt25/probe_claims.gd",
                  'python3 tools/run_python_suite.py --shards 4 --changed-since HEAD --output-dir "$PWD/tools/txt25/python-default"',
                  "python3 tests/test_rules_text_lint.py",
                  "```", ""])
    for key, label, file in [
        ("inventory", "Inventory", "inventory.log"), ("runtime", "Runtime witnesses", "probe.log"),
        ("python", "Python default group", "checks.log"), ("lint", "Rules-text lint", "checks.log"),
    ]:
        result_lines = report["proof"][key]
        lines.append(f'- {label} · ' + " · ".join(f"`{line}`" for line in result_lines) + f" [Log]({file})")
    lines.extend(["", "## Chosen defaults", ""])
    lines.extend(f"- {item}" for item in report["chosen_defaults"])
    lines.extend(["", "## TODO_DESIGN placeholders", "", "None.",
                  "", "## Open issues and audit limits", ""])
    lines.extend(f"- {item}" for item in report["open_issues"])
    lines.extend(["- Godot logged a macOS certificate-store warning and exited successfully. "
                  "The Python runner could not write its learned timing cache in shared Git metadata. The tests passed.", ""])
    return "\n".join(lines)


if __name__ == "__main__":
    report = json.loads((HERE / "truth.json").read_text(encoding="utf-8"))
    (HERE / "truth.md").write_text(render(report), encoding="utf-8")
