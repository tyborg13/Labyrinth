#!/usr/bin/env python3
"""Render the tile census from one complete dry or renderer observation set."""

import argparse
from collections import Counter, defaultdict
import json
import os
from pathlib import Path
import re
from urllib.parse import quote

CATEGORIES = {
    "A": "Bare surface",
    "B": "Unit on a surface",
    "C": "Object",
    "D": "Marked",
    "E": "Hidden unit",
}
STATUS_ICONS = {"burrowed": "burrow"}
FRAME_SIZE = (1920, 1080)


def read_batch(directory):
    observations = json.loads((directory / "observations.json").read_text())
    mode = observations["mode"]
    if mode not in {"headless", "native"}:
        raise ValueError(f"Invalid observation mode {mode!r}")
    ids = [fixture["id"] for fixture in observations["fixtures"]]
    if len(ids) != 12 or len(set(ids)) != 12:
        raise ValueError("The census requires all 12 different fixtures")
    frames = set()
    for fixture in observations["fixtures"]:
        seen = set()
        for sample in fixture["samples"]:
            category = sample["contents"]["category"]
            if category not in CATEGORIES or category in seen:
                raise ValueError(f"Unexpected or duplicate category {category} in {fixture['id']}")
            seen.add(category)
            frame = sample["frame"]
            if mode == "native":
                if frame != f"{fixture['id']}-{category}-hover.png" or not (directory / frame).is_file():
                    raise ValueError(f"Missing or unexpected frame {frame}")
                frames.add((directory / frame).resolve())
            elif frame:
                raise ValueError("A headless sample reported a PNG")
    if mode == "native":
        manifest = json.loads((directory / "visual-proof.json").read_text())
        validated = {Path(image["path"]).resolve() for image in manifest["images"]
                     if (image["width"], image["height"]) == FRAME_SIZE}
        if not manifest["ok"] or frames != validated:
            raise ValueError("Renderer proof and the observation frames differ")
    return observations


def changes(rest, hover, field):
    return {key: value for key, value in hover[field].items() if rest[field].get(key) != value}


def popup_panels(hover):
    return [panel for popup in hover["tooltips"] for panel in popup["panels"]]


def panel_matches(panel, title):
    if not title:
        return False
    if panel["title"].casefold() == title.casefold():
        return True
    return any(title.casefold() == line.strip().casefold()
               for value in panel["text"] for line in value.splitlines())


def joined_panel(panel):
    return "\n".join(panel["text"])


def quoted(text):
    return f'“{text}”'


def format_mark(mark):
    number = "" if mark["number"] is None else f" {mark['number']}"
    return f"{mark['kind']}{number} [{mark['source']}]"


def format_contents(pick):
    items = []
    for unit in pick["units"]:
        status = ", ".join(f"{key} {value}" for key, value in unit["statuses"].items())
        hp = "" if unit["hp"] is None else f", Health {unit['hp']}/{unit['max_hp']}"
        items.append(f"{unit['name']} [{unit['team']}{hp}, Block {unit['block']}"
                     + (f", {status}]" if status else "]"))
    for item in pick["objects"]:
        raw = item["raw"]
        health = f", Health {raw['hp']}/{raw.get('max_hp', raw['hp'])}" if "hp" in raw else ""
        items.append(f"{item['name']} [{item['kind']}{health}]")
    items.extend(f"Surface {surface['kind']}" for surface in pick["surfaces"])
    items.extend(format_mark(mark) for mark in pick["marks"])
    items.extend(f"Light {source['id']} (radius {source['radius']})" for source in pick["light"])
    items.append(f"Umbra {pick['umbra']['stage']} (visible)")
    items.append(f"Floor {pick['grid']}")
    items.extend(f"{key}: {json.dumps(value, ensure_ascii=False)}" for key, value in pick["other"].items())
    for key, value in pick["covered"].items():
        blockers = ", ".join(f"{blocker['name']} {blocker['tile']}" for blocker in value["blockers"])
        items.append(f"{key} body coverage {value['fraction']:.1%} by {blockers}")
    return items


def coverage(sample):
    """Return coverage receipts and explicit, state-comparable numeric claims."""
    pick, rest, hover = (sample[key] for key in ("contents", "rest", "hover"))
    panels = popup_panels(hover) if hover["tooltip_tile"] == pick["tile"] else []
    plates = changes(rest, hover, "plates")
    rails = changes(rest, hover, "rail")
    rail_actors = {rail["actor"] for rail in rails.values()}
    control_text = list(changes(rest, hover, "controls").values())
    tooltip_lines = [line for panel in panels for value in panel["text"] for line in value.splitlines()]
    receipts = []
    mismatches = []
    off_square = popup_panels(hover) if hover["tooltip_tile"] != pick["tile"] else []
    if off_square:
        text = " / ".join(joined_panel(panel).replace("\n", " / ") for panel in off_square)
        local = " + ".join(format_contents(pick))
        mismatches.append(f"Off-square tooltip from {hover['tooltip_tile']}: hover {quoted(text)} · sampled state {quoted(local)}")

    def record(category, label, where=None):
        receipts.append((category, label, where))

    def compare(label, actual, expected):
        if str(actual) != str(expected):
            mismatches.append(f"{label}: hover {quoted(actual)} · state {quoted(expected)}")

    for unit in pick["units"]:
        key, name = unit["key"], unit["name"]
        plate = plates.get(key, {})
        values = plate.get("statuses", {})
        actor_rail = [rail for rail in rails.values() if rail["actor"] == key]
        rail_text = [text for rail in actor_rail for text in rail["text"]]
        named = "tooltip" if name in tooltip_lines else "rail" if name in rail_text else "label" if name in control_text else None
        record("unit name", f"{name} name", named)
        record("unit team", f"{name} team")
        if unit["hp"] is not None:
            expected = f"{unit['hp']}/{unit['max_hp']}"
            shown = plate.get("health")
            if shown:
                compare(f"{name} Health", shown, expected)
            rail_health = [rail["health"] for rail in actor_rail if rail["health"]]
            if unit["role"] == "player":
                for claim in set(rail_health):
                    compare(f"{name} rail Health", claim, expected)
            # Enemy rail projections can show forecast Health, separately from
            # the committed current Health on the board plate.
            rail_current = expected in rail_health or str(unit["hp"]) in rail_health
            record("unit Health", f"{name} Health", "board plate" if shown else "rail" if rail_current else None)
        block = values.get("block")
        if block:
            compare(f"{name} Block", block, unit["block"])
        record("unit Block", f"{name} Block {unit['block']}", "board plate" if block else None)
        for status, amount in unit["statuses"].items():
            icon = STATUS_ICONS.get(status, status)
            if icon in values and values[icon].isdigit() and type(amount) is int:
                compare(f"{name} {status}", values[icon], amount)
            record(f"status {status}", f"{name} {status}", "board plate" if icon in values else None)
    for item in pick["objects"]:
        kind, name = item["kind"], item["name"]
        title = item["title"]
        panel = next((panel for panel in panels if panel_matches(panel, title)), None)
        record(f"object {kind}", name, "tooltip" if panel else None)
        raw = item["raw"]
        if "hp" in raw:
            claim = re.search(r"\b(\d+/\d+) Health\b", joined_panel(panel)) if panel else None
            if claim:
                compare(f"{name} Health", claim[1], f"{raw['hp']}/{raw.get('max_hp', raw['hp'])}")
            record(f"object {kind} Health", f"{name} Health", "tooltip" if claim else None)
    for surface in pick["surfaces"]:
        kind = surface["kind"]
        found = any(panel_matches(panel, surface["title"]) for panel in panels)
        record(f"surface {kind}", f"Surface {kind}", "tooltip" if found else None)
    for mark in pick["marks"]:
        kind, source, number = (mark[key] for key in ("kind", "source", "number"))
        panel = next((panel for panel in panels if panel_matches(panel, mark["title"])), None)
        if panel and kind == "Lob" and source != hover["lob_tooltip_owner"]:
            panel = None
        if panel and kind == "Icefall" and source != hover["icefall_tooltip_owner"]:
            panel = None
        route = "tooltip" if panel else None
        if kind == "Target or aim" and source in hover["board"]["isolated_enemies"]:
            route = "board threat focus"
        record(f"mark {kind}", format_mark(mark), route)
        record(f"mark {kind} source", f"{kind} source {source}", "rail highlight" if source in rail_actors else None)
        if number is None:
            continue
        claim = None
        if panel and kind in {"Meteorfall", "Icefall", "Erupt"}:
            match = re.search(r"\b(\d+) damage\b", joined_panel(panel))
            if match and sum(entry["kind"] == kind for entry in pick["marks"]) == 1:
                claim = match[1]
        elif panel and kind == "Lob":
            part = "central tile" if mark["raw"].get("center") else "each adjacent tile"
            match = re.search(rf"\b(\d+) damage on the {part}|\b(\d+) damage on {part}", joined_panel(panel))
            if match:
                claim = match[1] or match[2]
        if claim is not None:
            compare(f"{kind} damage", claim, int(number))
        record(f"mark {kind} number", f"{kind} number {number}", "tooltip" if claim is not None else None)
    for source in pick["light"]:
        kind = "Light source" if source["pos"] == pick["tile"] else "Light coverage"
        panel = next((entry for entry in panels if panel_matches(entry, "Light")), None)
        # A Light panel at a source's origin can identify it. Coverage can
        # overlap, so a Light panel does not attribute each covering source.
        record(kind, f"{kind} {source['id']}", "tooltip" if panel and kind == "Light source" else None)
    record("Umbra state", f"Umbra {pick['umbra']['stage']}")
    record("floor material", f"Floor {pick['grid']}")
    for key in pick["other"]:
        record(f"board field {key}", key)
    for key, covered in pick["covered"].items():
        fades = hover["board"]["occluder_fades"]
        lifted = bool({fade["id"] for fade in fades} & {blocker["reveal_id"] for blocker in covered["blockers"]})
        record("covered unit", f"{key} covered body", "occluder fade" if lifted else None)
    return receipts, mismatches


def format_hover(sample):
    rest, hover = sample["rest"], sample["hover"]
    entries = []
    for panel in popup_panels(hover):
        origin = hover["tooltip_tile"]
        label = f"Tooltip from {origin} " if origin != sample["contents"]["tile"] else "Tooltip "
        entries.append(label + " / ".join(quoted(line) for line in panel["text"]))
    for key, intent in changes(rest, hover, "intents").items():
        lines = []
        for line in intent["lines"]:
            if "title" in line:
                lines.append(quoted(line["title"]))
                continue
            tokens = []
            for token in line["tokens"]:
                icon = "[pattern]" if token["pattern"] else f"[{token['icon']}]" if token["icon"] else ""
                tokens.append(" ".join(value for value in (icon, token["text"], token["modifier"]) if value))
            lines.append(" ".join(tokens))
        entries.append(f"Intent {key}: " + " / ".join(lines))
    for key, plate in changes(rest, hover, "plates").items():
        statuses = [f"[{icon}] {label}".rstrip() for icon, label in plate["statuses"].items()]
        entries.append(f"Board plate {key}: {quoted(plate['health'])}" + (" " + " ".join(statuses) if statuses else ""))
    for rail in changes(rest, hover, "rail").values():
        entries.append(f"Rail highlight {rail['actor']}" + (" " + " / ".join(map(quoted, rail["text"])) if rail["text"] else ""))
    entries.extend("Label " + quoted(text) for text in changes(rest, hover, "controls").values())
    board = hover["board"]
    if board["hover_fill_tile"] == sample["contents"]["tile"]:
        entries.append("Tile hover fill")
    if board["threat_outline_tile"] == sample["contents"]["tile"]:
        entries.append("Threat overlay lifted on tile")
    for field, label in (("actor_focus", "Unit focus"), ("inspected_actors", "Inspected unit"),
                         ("isolated_enemies", "Threat isolation"), ("xray", "X-ray")):
        added = [key for key in board[field] if key not in rest["board"][field]]
        if added:
            entries.append(label + " " + ", ".join(added))
    if board["occluder_fades"]:
        entries.append("Occluder fade " + ", ".join(fade["id"] for fade in board["occluder_fades"]))
    return entries


def cell(items):
    return "<br>".join(str(item).replace("|", r"\|").replace("\n", "<br>") for item in items) or "—"


def relative_link(path, report):
    return quote(os.path.relpath(path, report.parent), safe="/._-")


def render(observations, directory, report):
    native = observations["mode"] == "native"
    summaries = defaultdict(Counter)
    rows = defaultdict(list)
    stale = []
    for fixture in observations["fixtures"]:
        for sample in fixture["samples"]:
            pick = sample["contents"]
            category = pick["category"]
            contents, hover = format_contents(pick), format_hover(sample)
            receipts, mismatches = coverage(sample)
            shown = [f"{label} ({where})" for _, label, where in receipts if where]
            missing = []
            for bucket, label, where in receipts:
                if not where:
                    summaries[bucket][category] += 1
                    missing.append(label)
            frame = f"[Frame]({relative_link(directory / sample['frame'], report)})" if native else "Pending"
            rows[category].append([fixture["id"], pick["tile"], cell(contents), cell(hover), cell(shown), cell(missing), frame])
            stale.extend(f"{fixture['id']} · {category} · {pick['tile']} · {entry}" for entry in mismatches)

    output = [
        "# Tile-hover census", "",
        "Native renderer observations at 1920×1080 and 100% UI scale." if native else
        "**Headless dry run.** The square picks, live Controls and board painter inputs are recorded below. "
        "Native pointer delivery, capture links and renderer visibility are pending.",
        "",
        "Each category ranks independently by screen y descending, then screen x ascending. "
        "A square may qualify in multiple categories. Each category starts from pointer rest. "
        "The coverage columns refer to feedback added by hover. Bracketed terms identify icon or diagram inputs.",
        "",
        f"[Raw state, rest and hover observations]({relative_link(directory / 'observations.json', report)})",
        "",
    ]
    for category, title in CATEGORIES.items():
        picks = rows[category]
        picked = {row[0] for row in picks}
        missing = [fixture["id"].split("-")[0] for fixture in observations["fixtures"] if fixture["id"] not in picked]
        output.extend([
            f"## {category}. {title}", "",
            f"{len(picks)}/12 fixtures" + (f" · No qualifying square in {', '.join(missing)}." if missing else "."),
            "",
            "| Fixture | Square | Contents | Hover feedback | Items shown | Items not shown | Frame |",
            "| --- | --- | --- | --- | --- | --- | --- |",
        ])
        output.extend("| " + " | ".join(row) + " |" for row in picks)
        output.append("")
    output.extend([
        "## Items omitted by at least one hover", "",
        "Counts are occurrences within each category. A repeated item on the same square contributes once per sampled category.",
        "", "| Content | A | B | C | D | E |", "| --- | ---: | ---: | ---: | ---: | ---: |",
    ])
    for item, counts in sorted(summaries.items()):
        output.append("| " + " | ".join([item, *(str(counts[category]) for category in CATEGORIES)]) + " |")
    output.extend(["", "## False, stale or off-square claims", ""])
    output.extend(f"- {entry.replace(chr(10), ' / ')}" for entry in stale)
    if not stale:
        output.append("No mismatches detected in the state-comparable claims in this run.")
    return "\n".join(output) + "\n"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("capture_dir", type=Path)
    parser.add_argument("report", type=Path)
    args = parser.parse_args()
    directory, report = args.capture_dir.resolve(), args.report.resolve()
    observations = read_batch(directory)
    text = render(observations, directory, report)
    report.write_text(text, encoding="utf-8")
    print(f"FEL06 REPORT PASS {report}")


if __name__ == "__main__":
    main()
