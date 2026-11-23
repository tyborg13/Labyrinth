"""Render the audit and check that each common finding has a reproduced witness."""

from pathlib import Path
import json
import re

ROOT = Path(__file__).resolve().parent
LEFTOVER = re.compile(r"@(?:kw|term|icon|pattern)\(|\{0\.|radius-|%[sdif]|\{[A-Za-z_][\w.]*\}|<(?:Count|Element|Item|Starter count|Relic(?: effect)?|starter piece)>")


def strings(value, prefix=""):
    if isinstance(value, dict):
        for key, child in value.items():
            location = f"{prefix}/{key}"
            yield location, key
            yield from strings(child, location)
    elif isinstance(value, list):
        for index, child in enumerate(value):
            yield from strings(child, f"{prefix}/{index}")
    elif isinstance(value, str):
        yield prefix, value


def cell(value):
    return str(value).replace("|", "&#124;").replace("\n", "<br>")


def source_links(citations):
    links = []
    for citation in citations:
        path, line = citation.rsplit(":", 1)
        links.append(f"[{citation}](../../{path}#L{line})")
    return ", ".join(links)


def main():
    report = json.loads((ROOT / "truth.json").read_text())
    inventory = json.loads((ROOT / "rendered_inventory.json").read_text())
    log = (ROOT / "probe.log").read_text()
    witnesses = set(re.findall(r"^TXT24 REPRODUCED (\S+) \|", log, re.MULTILINE))
    raw = [(path, value) for path, value in strings(inventory) if LEFTOVER.search(value)]
    assert raw == [(row["id"], row["rendered"]) for row in report["findings"]
                   if row.get("kind") == "raw_markup"], raw
    findings = report["findings"]
    for row in findings:
        proof = row.get("witness")
        if row["frequency"] == "common" or proof:
            assert proof in witnesses, row["id"]
        if not proof:
            assert row.get("unproven_reason"), row["id"]
        for citation in row["sources"]:
            path, line = citation.rsplit(":", 1)
            assert 0 < int(line) <= len((ROOT.parent.parent / path).read_text().splitlines()), citation

    common = sum(row["frequency"] == "common" for row in findings)
    lines = [
        "# txt-24 — Candidate 4 text truth audit",
        "",
        f"Base `{report['base']}` (`codex/mrg-14`). {len(findings)} findings ({common} common, "
        f"{len(findings) - common} edge). {len(raw)} surviving raw markup findings.",
        "",
        "\n\n".join(report["method"]),
        "",
        "## Coverage",
        "",
        "| Surface | Entries checked and rule paths |",
        "| --- | --- |",
    ]
    for surface, description in report["coverage"].items():
        lines.append(f"| {cell(surface)} | {cell(description)} |")
    for surface in report["coverage"]:
        lines.extend(["", f"## {surface}", ""])
        rows = sorted((row for row in findings if row["surface"] == surface),
                      key=lambda row: row["frequency"] != "common")
        if not rows:
            lines.append("No false claims found.")
            continue
        lines.extend([
            "| Frequency | ID and name | Rendered text | Engine behavior and reachable example | Evidence |",
            "| --- | --- | --- | --- | --- |",
        ])
        for row in rows:
            witness = row.get("witness")
            proof = f"[{witness}](probe.log)" if witness else row["unproven_reason"]
            columns = [row["frequency"], f"`{row['id']}` · {row['name']}", f"“{row['rendered']}”",
                       f"{row['behavior']}  {row['scenario']}",
                       f"{source_links(row['sources'])}. {proof}"]
            lines.append("| " + " | ".join(map(cell, columns)) + " |")
    lines.extend(["", "## Borderline", ""])
    for entry in report["borderline"]:
        lines.append(f"- **{entry['id']}**. {entry['reason']} {source_links(entry['sources'])}")
    lines.extend(["", "## Skipped or retired IDs", ""])
    for entry in report["skipped"]:
        ids = ", ".join(f"`{item}`" for item in entry["ids"])
        lines.append(f"- {ids}. {entry['reason']} {source_links(entry['sources'])}")
    lines.extend(["", "## Proof", ""])
    lines.extend(f"- {item}" for item in report["proof"])
    lines.extend(["", "## Chosen defaults", ""])
    lines.extend(f"- {item}" for item in report["chosen_defaults"])
    lines.extend(["", "## Open issues", ""])
    lines.extend(f"- {item}" for item in report["open_issues"])
    lines.append("")
    (ROOT / "truth.md").write_text("\n".join(lines))
    print(f"TXT24 REPORT: {len(findings)} findings ({common} common), "
          f"{len(witnesses)} reproduced witnesses, {len(raw)} raw markup matches")


if __name__ == "__main__":
    main()
