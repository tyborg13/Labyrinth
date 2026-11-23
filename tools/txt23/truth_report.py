#!/usr/bin/env python3
"""Build the TXT-23 truth report from the treasure capture and combat probe."""
from __future__ import annotations

import argparse
import json
from pathlib import Path
import re
import sys

sys.dont_write_bytecode = True

from relic_text_audit import HERE, RELEASE_AUDIT, RESOLUTIONS, ROOT, automated_delta, candidate_rows, capture


RELEASE = "060674b1a"
CANDIDATE = "1333bc4e2"
PROBE_RESULT = HERE / "probe_results.txt"
CASE = re.compile(r"TXT23_CASE (\S+) PASS (.+)")
SUMMARY = re.compile(r"TXT23 truth probe PASS: (\d+) counterexamples reproduced, 0 failed")


def load_probe(path: Path) -> dict:
    cases = {}
    count = None
    for line in path.read_text().splitlines():
        if line.startswith("TXT23_CASE "):
            match = CASE.fullmatch(line)
            assert match, line
            key, payload = match.groups()
            assert key not in cases, key
            cases[key] = json.loads(payload)
        elif match := SUMMARY.fullmatch(line):
            count = int(match[1])
    assert count == len(cases) and cases, path
    return cases


def require_reference(reference: str) -> str:
    path, numbers = reference.rsplit(":", 1)
    bounds = [int(number) for number in numbers.split("-")]
    assert 0 < bounds[0] <= bounds[-1] <= len((ROOT / path).read_text().splitlines()), reference
    return reference


def load_review() -> dict:
    review = {}
    for line in (HERE / "review.tsv").read_text().splitlines():
        if not line or line.startswith("#"):
            continue
        relic, short_refs, description = (part.strip() for part in line.split("|", 2))
        assert relic not in review, relic
        references = []
        for short in short_refs.split():
            path, bounds = short.split(":")
            references.append(require_reference(f"scripts/{path}.gd:{bounds}"))
        review[relic] = {"actual": description, "references": references}
    return review


def changed_text(rows: list[dict], release: dict) -> list[dict]:
    prior = {row["id"]: row for row in release["relics"]}
    changes = []
    for row in rows:
        previous = prior.get(row["id"])
        before = previous["audited_treasure"]["transcript"] if previous else None
        old_raw = previous["raw_text"] if previous else None
        after = row["audited_treasure"]["transcript"]
        if not row["retired"] and (before != after or old_raw != row["raw_text"]):
            changes.append({
                "id": row["id"], "name": row["name"], "release": before, "candidate": after,
                "release_source_text": old_raw, "candidate_source_text": row["raw_text"],
                "rendered_change": before != after,
            })
    return changes


def report(captured: dict, cases: dict) -> dict:
    release = json.loads(RELEASE_AUDIT.read_text())
    rows = candidate_rows(captured)
    active = {row["id"]: row for row in rows if not row["retired"]}
    review = load_review()
    assert active.keys() == review.keys(), "Candidate review must enumerate every live relic."
    delta = automated_delta(captured, rows, release)
    notes = json.loads((HERE / "findings.json").read_text())
    coverage = []
    for relic, row in active.items():
        treasure = row["audited_treasure"]
        coverage.append({
            "id": relic, "name": row["name"], "treasure_text": treasure["transcript"],
            "source": row["source"], **review[relic],
        })
    findings = []
    assigned_cases = set()
    for note in notes["findings"]:
        row = active[note["id"]]
        assert note["frequency"] in {"common", "edge"}, note
        assert note["sentence"] in row["audited_treasure"]["printed_prose"], note
        if diagram := note.get("diagram"):
            assert f"[diagram {diagram}]" in row["audited_treasure"]["transcript"], note
            rendered_diagram = captured["diagrams"][f"@pattern({diagram})"]
            assert rendered_diagram["patterns"] == 1, note
            note["diagram_offsets"] = rendered_diagram["offsets"]
        probe = note.get("probe")
        if probe:
            proof = {"status": "headless", "case": probe, "observed": cases[probe]}
            assigned_cases.add(probe)
        else:
            assert note["frequency"] == "edge", note
            proof = {"status": "unproven", "reason": note["unproven_reason"]}
        findings.append({
            **note, "name": row["name"], "text_source": row["source"], "proof": proof,
            "references": [require_reference(ref) for ref in note["references"]],
        })
    assert assigned_cases == cases.keys()
    for leak in delta["leaked_markup"]:
        row = active[leak["id"]]
        findings.append({
            "id": row["id"], "name": row["name"], "frequency": "common",
            "sentence": leak["text"], "text_source": row["source"],
            "actual": "The production label prints the markup characters.",
            "scenario": f"Read this relic on the {leak['surface']} surface.",
            "references": ["scripts/inline_icon_text.gd:82"],
            "proof": {"status": "headless capture", "surface": leak["surface"], "observed": leak["text"]},
        })
    findings.sort(key=lambda row: row["frequency"] != "common")
    borderline = [{
        **note, "name": active[note["id"]]["name"],
        "references": [require_reference(ref) for ref in note["references"]],
    } for note in notes["borderline"]]
    return {
        "release": RELEASE, "candidate": CANDIDATE,
        "catalog_ids": len(rows), "live_ids": len(active), "findings": findings,
        "borderline": borderline,
        "retired": [{"id": row["id"], "name": row["name"], "replacement": row["resolved_id"]}
                    for row in rows if row["retired"]],
        "changed_text": changed_text(rows, release),
        "automated_layer_delta": delta, "coverage": coverage,
    }


def escape(value: str) -> str:
    return str(value).replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;").replace("|", "&#124;").replace("\n", "<br>")


def table(columns: tuple[str, ...], rows) -> list[str]:
    return [
        "| " + " | ".join(columns) + " |",
        "| " + " | ".join("---" for _ in columns) + " |",
        *("| " + " | ".join(escape(value) for value in row) + " |" for row in rows),
    ]


def refs(references: list[str]) -> str:
    links = []
    for reference in references:
        path, bounds = reference.rsplit(":", 1)
        links.append(f"[{reference}](../../{path}#L{bounds.partition('-')[0]})")
    return ", ".join(links)


def proof_text(row: dict) -> str:
    proof = row["proof"]
    if proof["status"] == "headless":
        return f"`{proof['case']}` in [probe results](probe_results.txt)"
    if proof["status"] == "headless capture":
        return f"Headless {proof['surface']} label capture"
    return f"Unproven. {proof['reason']}"


def relic_label(row: dict) -> str:
    return f"{row['name']} · `{row['id']}`"


def describe_markup(record: dict | None) -> str:
    if record is None:
        return "—"
    return json.dumps(record, ensure_ascii=False, sort_keys=True)


def markdown(result: dict) -> str:
    findings = result["findings"]
    delta = result["automated_layer_delta"]
    common = sum(row["frequency"] == "common" for row in findings)
    out = [
        "# TXT-23 relic text truth check", "",
        f"Candidate 4 at `{CANDIDATE}` has {len(findings)} false claims in the live relic text "
        f"({common} common, {len(findings) - common} edge). The audit covered all {result['live_ids']} live IDs "
        f"and enumerated all {len(result['retired'])} retired IDs. The release comparison uses the TXT-22 capture "
        f"at `{RELEASE}`.", "",
        "Common means a regular play path for the relic. Edge means a particular card, interaction, board state or enemy is required. "
        "Frequency is a qualitative assessment based on when the rule can be encountered.", "",
        "The quoted words come from the treasure label after substitutions. Bracketed icon names and diagrams in the coverage and release tables "
        "transcribe embedded graphics. Both sizes used the production offer builder at 100% UI scale.", "",
        "## Findings", "",
    ]
    out += table(("Frequency", "Relic", "Exact treasure sentence", "What the code does", "Reachable scenario", "Proof"), (
        (row["frequency"], relic_label(row), row["sentence"] + (f"\n[diagram {row['diagram']}]" if "diagram" in row else ""),
         row["actual"] + "\n" + refs([row["text_source"], *row["references"]]), row["scenario"], proof_text(row))
        for row in findings
    ))
    out += ["", "## Borderline", ""]
    out += [f"- **{relic_label(row)}.** {row['reason']} {refs(row['references'])}" for row in result["borderline"]]
    out += ["", "## Retired IDs", ""]
    out += table(("Retired ID", "Catalog name", "Live replacement"), (
        (f"`{row['id']}`", row["name"], f"`{row['replacement']}`") for row in result["retired"]
    ))
    changed = result["changed_text"]
    out += ["", "## Treasure text changed since release", "",
            f"{len(changed)} live IDs changed in the rendered description or its source. "
            "Rows with identical displayed text have a markup-only source edit. "
            "The JSON contains both source descriptions.", ""]
    out += table(("Relic", "Release", "Candidate 4"), (
        (relic_label(row), row["release"] or "—", row["candidate"]) for row in changed
    ))
    out += ["", "## Automated-layer delta", "",
            "The TXT-22 checks ran against candidate prose and markup, including archived text for the retired IDs. "
            "Diffs match contextual flags by wording and structural flags by condition. "
            "Baseline mechanics flags were manually assessed in the truth audit.", ""]
    for heading, key in (("Flags that disappeared", "disappeared"), ("New flags", "new")):
        flags = delta["flags"][key]
        out += [f"### {heading} ({len(flags)})", ""]
        if flags:
            out += table(("Relic ID", "Check", "Flagged wording"), (
                (f"`{row['id']}`", row["category"], row["evidence"]) for row in flags
            ))
        else:
            out.append("None.")
        out.append("")
    out += ["### Markup survey changes", ""]
    out += table(("Kind", "Spelling or relic ID", "Release", "Candidate 4"), (
        (row["kind"], f"`{row['key']}`", describe_markup(row["release"]), describe_markup(row["candidate"]))
        for row in delta["markup"]
    ))
    out += ["", "### Overflow changes", ""]
    out += table(("Size", "Offer population", "Measurements", "New overflows", "Cleared overflows"), (
        (size, group, fit["measurements"], ", ".join(fit["new_overflows"]) or "None",
         ", ".join(fit["cleared_overflows"]) or "None")
        for size in RESOLUTIONS for group, fit in delta["overflow"][size].items()
    ))
    out += ["", f"The live labels and tooltip variants contain {len(delta['leaked_markup'])} raw markup leaks.", "",
            "## Live relic coverage", ""]
    out += table(("Relic", "Candidate treasure transcription", "Reviewed rule path"), (
        (relic_label(row), row["treasure_text"] + "\n" + refs([row["source"]]),
         row["actual"] + "\n" + refs(row["references"]))
        for row in result["coverage"]
    ))
    return "\n".join(out) + "\n"


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--capture-json", type=Path, help="Reuse an existing candidate treasure capture.")
    parser.add_argument("--probe-log", type=Path, default=PROBE_RESULT)
    parser.add_argument("--check", action="store_true", help="Verify the Markdown and JSON match.")
    args = parser.parse_args()
    captured = json.loads(args.capture_json.read_text()) if args.capture_json else capture()
    result = report(captured, load_probe(args.probe_log))
    content = {"truth.md": markdown(result), "truth.json": json.dumps(result, ensure_ascii=False, indent=2) + "\n"}
    for name, body in content.items():
        output = HERE / name
        if args.check:
            assert output.read_text() == body, name
        else:
            output.write_text(body)
    print(f"TXT23 report {'verified' if args.check else 'written'}: {result['live_ids']} live, "
          f"{len(result['retired'])} retired, {len(result['findings'])} findings, "
          f"{len(result['borderline'])} borderline, {len(result['changed_text'])} text changes")


if __name__ == "__main__":
    main()
