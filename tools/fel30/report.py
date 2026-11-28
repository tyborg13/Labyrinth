"""Aggregate the real descent census and select reproducible native frames."""

from argparse import ArgumentParser
from collections import Counter, defaultdict
import json
from pathlib import Path

OUT = Path("/private/tmp/labyrinth_codex/fel-30")
COPY = Path(__file__).with_name("census.md")
CATEGORIES = ("tile_content", "unit", "unit_ui", "text", "clip")
ENCOUNTERS = ("normal", "objective", "Warband", "Guardian", "dragon")
RARE = ENCOUNTERS[2:]
TOP_LIMIT = 24
TEXT_KINDS = {"intent_label", "name_label", "floating_number", "status_chip", "tag_chip", "tile_number"}
INTENT_NON_TEXT = {"expanded intent", "intent callout"}


def read_rows(path):
    with path.open() as stream:
        return [json.loads(line) for line in stream if line.strip()]


def write_rows(path, rows):
    with path.open("w") as stream:
        for row in rows:
            stream.write(json.dumps(row, ensure_ascii=False) + "\n")


def cite(moment):
    suffix = f", enemy action {moment['enemy_action']}" if moment["moment"] == "enemy_action" else ", player turn"
    return f"{moment['seed']} · C{moment['combat']} · T{moment['turn']} · {moment['encounter']}{suffix}"


def describe(flag):
    causes = ", ".join(c["what"] + (f" ({c['actor']})" if c.get("actor") else "") for c in flag["by"])
    tile = f" at {tuple(flag['tile'])}" if flag["tile"][0] >= 0 else ""
    return f"{flag['kind']} {flag['what']}{tile} ({flag['covered_fraction']:.1%}, {causes})"


def rank(rows):
    return sorted(rows, key=lambda row: (-row["severity"], row["seed"], row["id"]))


def summaries(runs):
    return [row for row in runs if "end" in row]


def encounter_totals(moments):
    moments_by_kind = Counter(m["encounter"] for m in moments)
    flagged_by_kind = Counter(m["encounter"] for m in moments if m["flags"])
    counts = {kind: Counter() for kind in ENCOUNTERS}
    for moment in moments:
        counts[moment["encounter"]].update(flag["category"] for flag in moment["flags"])
    return moments_by_kind, flagged_by_kind, counts



def measured_intent_overlaps(moment):
    pairs = []
    for flag in moment["flags"]:
        if flag["category"] != "text":
            continue
        for cause in flag["by"]:
            if cause["kind"] not in TEXT_KINDS or not cause.get("is_text", infer_text_cause(cause)):
                continue
            if "intent_label" not in (flag["kind"], cause["kind"]):
                continue
            intent_is_behind = flag["kind"] == "intent_label"
            intent, other = (flag, cause) if intent_is_behind else (cause, flag)
            pairs.append({"intent": intent["what"], "intent_actor": intent.get("actor", ""),
                          "other": other["what"], "other_actor": other.get("actor", ""), "other_kind": other["kind"],
                          "foreground": cause["what"], "covered": flag["what"], "fraction": cause["fraction"]})
    return pairs


def infer_text_cause(cause):
    return cause["kind"] == "intent_label" and cause["what"] not in INTENT_NON_TEXT

def fel25(moments):
    counts = defaultdict(Counter)
    examples = []
    for row in moments:
        kind = row["encounter"]
        counts[kind]["intent labels drawn"] += row["intent_labels"]
        pairs = row.get("intent_overlaps", [])
        if pairs:
            counts[kind]["moments with intent text overlap"] += 1
        for pair in pairs:
            type_ = "intent–intent" if pair["other_kind"] == "intent_label" else "intent–other text"
            counts[kind][type_] += 1
            examples.append((pair["fraction"], row, pair))
    return counts, sorted(examples, key=lambda entry: -entry[0])


def report(moments, runs, selection, has_frames):
    lines = ["# fel-30 Crowded-board census", "", "## Hidden information needed now", ""]
    urgent = [(row, [f for f in row["flags"] if f["urgent"]]) for row in rank(moments)]
    urgent = [(row, flags) for row, flags in urgent if flags]
    lines.append(f"{len(urgent)} moments showed a hidden telegraph, reachable pickup, or intent.")
    lines.append("")
    for row, flags in urgent:
        lines.append(f"- **{cite(row)}.** " + " · ".join(map(describe, flags)))
    lines += ["", "## Totals", ""]
    counts = Counter(f["category"] for row in moments for f in row["flags"])
    flagged = sum(bool(row["flags"]) for row in moments)
    lines += [f"{len(moments)} moments · {flagged} flagged · {sum(counts.values())} flags.", ""]
    by_kind, flagged_by_kind, detail = encounter_totals(moments)
    headings = ["Encounter", "Combats", "Moments", "Flagged", "Tile content", "Unit", "Unit HUD", "Text", "Clipping"]
    lines += ["| " + " | ".join(headings) + " |", "|" + " --- |" * len(headings)]
    encounter_counts = Counter(row["encounter"] for row in runs if "combat" in row)
    for kind in ENCOUNTERS:
        values = [kind, encounter_counts[kind], by_kind[kind], flagged_by_kind[kind], *(detail[kind][c] for c in CATEGORIES)]
        lines.append("| " + " | ".join(map(str, values)) + " |")
    values = ["**All**", sum(encounter_counts.values()), len(moments), flagged, *(counts[c] for c in CATEGORIES)]
    lines.append("| " + " | ".join(map(str, values)) + " |")
    lines += ["", "## What covers what", ""]
    causes = Counter()
    victims = defaultdict(Counter)
    for row in moments:
        for flag in row["flags"]:
            seen = set()
            for actor in flag["by"]:
                key = (actor["kind"], actor["what"])
                if key in seen:
                    continue
                seen.add(key)
                causes[key] += 1
                victims[key][flag["kind"]] += 1
    lines += ["| Cause | Flags contributed to | Covered subjects |", "| --- | ---: | --- |"]
    for (kind, what), count in causes.most_common():
        subject = ", ".join(f"{target} ({n})" for target, n in victims[(kind, what)].most_common())
        lines.append(f"| {kind} · {what} | {count} | {subject} |")
    lines += ["", "## Intent label overlap for fel-25", ""]
    lines.append("Pairs count sampled text that visibly covered other text in paint order. Both labels in an intent–intent pair are intent text.")
    lines += ["", "| Encounter | Intent labels drawn | Intent–intent pairs | Intent–other text pairs | Moments with overlap |", "| --- | ---: | ---: | ---: | ---: |"]
    overlap_counts, examples = fel25(moments)
    for kind in ENCOUNTERS:
        keys = ("intent labels drawn", "intent–intent", "intent–other text", "moments with intent text overlap")
        lines.append("| " + " | ".join([kind, *(str(overlap_counts[kind][k]) for k in keys)]) + " |")
    lines.append("")
    if not examples:
        lines.append("No intent text was observed covering or covered by other text.")
    for fraction, row, pair in examples[:10]:
        lines.append(f"- **{cite(row)}.** {pair['intent']} with {pair['other']} ({fraction:.1%} of {pair['covered']!r} covered by {pair['foreground']!r}).")
    lines += ["", "## Descents", ""]
    for summary in summaries(runs):
        seed = summary["seed"]
        lines.append(f"- **{seed}.** Section index {summary['section']}, depth {summary['depth']}, {summary['combats']} combats. Ended at {summary['end']}.")
        for row in (r for r in runs if r["seed"] == seed and "combat" in r):
            lines.append(f"  - C{row['combat']} · depth {row['depth']} · {row['encounter']} · room {row['room']} · {row['definition'] or row['room_type']}")
    missing = [kind for kind in RARE if not encounter_counts[kind]]
    lines.append("")
    lines.append("Encounter kinds missed were " + ", ".join(missing) + "." if missing else "Every encounter kind was observed.")
    lines += ["", "## Highest-severity moments", ""]
    if has_frames:
        lines.append("[Contact sheet](sheet.png)")
    else:
        lines.append("The frames, flagged-area crops and contact sheet are pending the native replay.")
    lines += ["", "| Rank | Moment | Severity | Leading flag |", "| ---: | --- | ---: | --- |"]
    for row in selection:
        flag = describe(row["flags"][0]) if row["flags"] else "—"
        location = cite(row)
        if has_frames:
            stem = f"{row['rank']:02d}-{row['key']}"
            location += f" · [frame](top/{stem}.png) · [crop](top/{stem}-crop.png)"
        lines.append(f"| {row['rank']} | {location} | {row['severity']} | {flag} |")
    lines += ["", "## Measurement", "",
              "The probe records the ready player-turn frame and the completed enemy-action frame when at least four enemies were alive as the action began. The diagnostic pack adds observers to copies of production scripts. Original files and game saves are untouched.",
              "",
              "The coverage pass samples screen pixel centers in draw order. It uses submitted texture alpha, texture regions, live cutout transforms and polygon UVs. Tile surfaces and attack telegraphs use their tile diamonds. Text uses measured font rectangles. Occluder rims and the show-through checker use the production parameters.",
              "",
              "Tile content flags at 40% coverage. Bodies flag below 60% visible. Health and intent UI flag at 25% coverage. A visible text or clip intersection flags on the first sampled pixel. Severity assigns 3 to text, 2 to a tile, and 1 each to a body, its unit HUD, or a clip.",
              "",
              "The headless geometry pass models the drawing commands in its instrumented paths. It samples texture alpha without renderer filtering and uses rectangles for UI and text. The native replay supplies the real 1920×1080 frames.",
              ""]
    return "\n".join(lines)


def collect(out, seed_dirs):
    moments, runs, inputs = [], [], []
    for folder in seed_dirs:
        run = read_rows(folder / "runs.jsonl")
        summary = summaries(run)
        if not summary or any(row["end"] not in {"recap", "combat cap"} for row in summary):
            raise ValueError(f"Descent incomplete in {folder}")
        moments.extend(read_rows(folder / "moments.jsonl"))
        runs.extend(run)
        inputs.extend(read_rows(folder / "inputs.jsonl"))
    if len({row["key"] for row in moments}) != len(moments):
        raise ValueError("Duplicate moment keys")
    if not moments:
        raise ValueError("No measured moments")
    moments.sort(key=lambda row: (row["seed"], row["id"]))
    for index, row in enumerate(moments, 1):
        row["id"] = index
        row["intent_overlaps"] = measured_intent_overlaps(row)
        row["intent_labels"] = sum(
            item["kind"] == "intent_label" and item.get("is_text", item["what"] not in INTENT_NON_TEXT)
            for item in row.get("subjects", [])
        )
    selection = [{**row, "rank": rank} for rank, row in enumerate(rank(moments)[:TOP_LIMIT], 1)]
    out.mkdir(parents=True, exist_ok=True)
    for name, data in (("moments", moments), ("runs", runs), ("inputs", inputs)):
        write_rows(out / f"{name}.jsonl", data)
    (out / "selection.json").write_text(json.dumps(selection, ensure_ascii=False, indent=2) + "\n")
    save_report(out, moments, runs, selection, False)
    print(f"FEL30 CENSUS moments={len(moments)} flagged={sum(bool(row['flags']) for row in moments)}")
    categories = Counter(flag["category"] for row in moments for flag in row["flags"])
    for category in CATEGORIES:
        print(f"FEL30 CATEGORY {category}={categories[category]}")


def save_report(out, moments, runs, selection, got_frames):
    value = report(moments, runs, selection, got_frames)
    (out / "census.md").write_text(value)
    if out.resolve() == OUT:
        repo_value = value.replace("](sheet.png)", f"]({out / 'sheet.png'})")
        repo_value = repo_value.replace("](top/", f"]({out / 'top'}/")
        COPY.write_text(repo_value)


def verify(out, native=False):
    moments = read_rows(out / "moments.jsonl")
    runs = read_rows(out / "runs.jsonl")
    inputs = read_rows(out / "inputs.jsonl")
    selection = json.loads((out / "selection.json").read_text())
    seeds = [row["seed"] for row in summaries(runs)]
    if seeds != list(range(30001, 30001 + len(seeds))) or not 3 <= len(seeds) <= 6:
        raise ValueError(f"Invalid completed seed roster: {seeds}")
    if {row["seed"] for row in moments} != set(seeds) or {row["seed"] for row in inputs} != set(seeds):
        raise ValueError("Census or input transcript does not cover every seed")
    if [row["key"] for row in selection] != [row["key"] for row in rank(moments)[:TOP_LIMIT]]:
        raise ValueError("Native selection does not match the ranked headless rows")
    rare = {row["encounter"] for row in runs if "combat" in row}.intersection(RARE)
    if len(seeds) != 6 and rare != set(RARE):
        raise ValueError(f"Additional seeds required. Still missing {set(RARE) - rare}")
    if native:
        for row in selection:
            stem = f"{row['rank']:02d}-{row['key']}"
            if not (out / "top" / f"{stem}.png").exists() or not (out / "top" / f"{stem}-crop.png").exists():
                raise ValueError(f"Missing proof for {stem}")
        if not (out / "sheet.png").exists():
            raise ValueError("Missing contact sheet")
        save_report(out, moments, runs, selection, True)
    print(f"FEL30 {'NATIVE' if native else 'REPLAY'} CHECK seeds={len(seeds)} moments={len(moments)} selected={len(selection)}")


def main():
    parser = ArgumentParser(description=__doc__)
    parser.add_argument("mode", choices=("collect", "check", "native"))
    parser.add_argument("seed_dirs", type=Path, nargs="*")
    parser.add_argument("--output", type=Path, default=OUT)
    args = parser.parse_args()
    if args.mode == "collect":
        collect(args.output, args.seed_dirs)
    else:
        verify(args.output, args.mode == "native")


if __name__ == "__main__":
    main()
