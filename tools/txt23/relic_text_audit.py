#!/usr/bin/env python3
"""Run the TXT-22 rendered-text, markup and overflow checks on Candidate 4."""
from __future__ import annotations

from collections import Counter, defaultdict
import json
from pathlib import Path
import re
from statistics import median
import subprocess
import sys

sys.dont_write_bytecode = True
from copy_review import AREA, SENTENCE, STYLE, WORD, entry, hits, style_flags


HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
RUNNER = (
    "python3", "tools/godot_task_runner.py", "--task-id", "txt-23", "--stream", "--",
    "godot", "--headless", "--path", ".", "--script", "tools/txt23/capture_relics.gd",
)
RESOLUTIONS = ("1920x1080", "1280x800")
TOKEN = re.compile(r"@(?:kw|term|icon|pattern)\([^()]+\)|\{[^{}]+\}")
REPEATING_WHEN = {
    "mirror_shard", "coffin_nails", "frost_prism", "ember_siphon", "cold_mirror", "rimecatcher_vial",
    "overflow_censer", "hollow_die", "hourglass_splinter", "funeral_bell", "bloodmoon_chalice",
    "unclouded_sun", "millstone_fob", "briar_vambrace", "battering_yoke", "martyrs_gorget",
    "changelings_rattle", "ashen_phylactery", "overclock_coil", "breaking_wheel", "siege_ram_totem",
    "echoing_blade",
}


def capture() -> dict:
    with subprocess.Popen(RUNNER, cwd=ROOT, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True) as proc:
        path = ""
        for line in proc.stdout:
            print(line, end="", flush=True)
            if line.startswith("TXT23_CAPTURE_JSON="):
                path = line.removeprefix("TXT23_CAPTURE_JSON=").strip()
        if proc.wait() != 0 or not path:
            raise RuntimeError("Task runner did not produce a successful TXT-23 capture.")
    return json.loads(Path(path).read_text())


def transcribe(rewrite: str, measured: dict, tokens: dict, diagrams: dict) -> dict:
    """Reconstruct image positions and check every other character against Godot."""
    def expand(match: re.Match, mode: str) -> str:
        spelling = match[0]
        if spelling in diagrams:
            if mode == "exact":
                return diagrams[spelling]["text"]
            if diagrams[spelling]["patterns"] > 0:
                return f"[diagram {spelling[9:-1]}]" if mode == "display" else ""
            return diagrams[spelling]["text"]
        token = tokens.get(spelling)
        if token is None:
            return spelling
        word = token["text"].strip()
        if mode == "exact":
            return token["text"]
        if mode == "named":
            return word or token["icon_alt"]
        if token["icon_alt"]:
            return f"[icon {token['icon_alt']}]" + (" " + word if word else "")
        return word

    expected = TOKEN.sub(lambda match: expand(match, "exact"), rewrite)
    assert measured["text"].startswith(expected), (rewrite, expected, measured["text"])
    suffix = measured["text"][len(expected):]
    assert not suffix or suffix.startswith("\n"), repr(suffix)
    return {
        **measured,
        "transcript": (TOKEN.sub(lambda match: expand(match, "display"), rewrite) + suffix).strip(),
        "icon_read_prose": TOKEN.sub(lambda match: expand(match, "named"), rewrite).strip(),
        "printed_prose": re.sub(r"\s+", " ", expected).strip(),
        "state_suffix": suffix.removeprefix("\n"),
    }


def markup_survey(captured: dict, rows: list[dict]) -> dict:
    usages = defaultdict(list)
    replacements = defaultdict(lambda: defaultdict(list))
    for row in rows:
        relic_id = row["id"]
        for spelling in set(TOKEN.findall(row["pattern_rewrite"]) + TOKEN.findall(row["raw_text"])):
            usages[spelling].append(relic_id)
        for spelling, value in captured["relics"][relic_id]["bindings"].items():
            replacements[spelling][value].append(relic_id)

    inline = []
    for spelling, measured in captured["inline_markup"].items():
        inline.append({
            "raw": spelling, "printed_word": measured["text"].strip(),
            "icon": measured["icon_alt"], "glossary_name": measured["glossary_name"],
            "relics": usages[spelling],
        })
    diagrams = [{
        "raw": spelling, "output": f"Inline diagram {spelling[9:-1]}, zero printed words",
        "relics": usages[spelling],
        "offsets": captured["diagrams"][spelling]["offsets"],
        "origin_marker": captured["diagrams"][spelling]["origin_marker"],
    } for spelling in captured["diagrams"]]
    bindings = [{"raw": spelling, "values": values} for spelling, values in sorted(replacements.items())]
    rewrites = [{
        "id": row["id"],
        "raw": row["formatted_markup"],
        "rewritten_markup": row["pattern_rewrite"],
        "output": row["audited_treasure"]["transcript"],
        "source": row["pattern_reference"],
    } for row in rows if row["pattern_reference"]]
    return {"inline": inline, "diagrams": diagrams, "bindings": bindings, "whole_line_rewrites": rewrites}


def pattern_references() -> dict:
    path = "data/pattern_rule_text.json"
    lines = (ROOT / path).read_text().splitlines()
    return {
        json.loads("{" + line.strip().rstrip(",") + "}").popitem()[0]: f"{path}:{index}"
        for index, line in enumerate(lines, 1)
        if line.lstrip().startswith('"') and not line.rstrip().endswith("{")
    }



RELEASE_AUDIT = ROOT / "tools/txt22/relic_text_audit.json"
RAW_MARKUP = re.compile(r"@(?:kw|term|icon|pattern)\(|\{0\.|radius-", re.I)
STRUCTURAL_FLAGS = {"R9", "long_copy", "multiple_sentences", "markup_area", "markup_english"}
SCOPE_SURFACES = ("treasure", "hud", "chronicle", "dragon_reward")


def candidate_rows(captured: dict) -> list[dict]:
    catalog = json.loads((ROOT / "data/relics.json").read_text())
    data_lines = {}
    for number, line in enumerate((ROOT / "data/relics.json").read_text().splitlines(), 1):
        if match := re.fullmatch(r'  "(\w+)": \{', line):
            relic_id = match[1]
        elif line.startswith('    "description":'):
            data_lines[relic_id] = number
    assert catalog.keys() == captured["relics"].keys() == data_lines.keys()
    assert captured["ui_scale"] == 1.0
    tokens, diagrams = captured["inline_markup"], captured["diagrams"]
    pattern_lines = pattern_references()
    rows = []
    for relic_id, relic in catalog.items():
        current = captured["relics"][relic_id]
        resolved = captured["relics"][current["resolved_id"]]
        retired = relic_id != current["resolved_id"]
        assert retired == relic.get("retired", False)
        live = {
            surface: transcribe(resolved["pattern_rewrite"], current[surface], tokens, diagrams)
            for surface in SCOPE_SURFACES if surface in current
        }
        treasure = transcribe(current["pattern_rewrite"], current["historical_treasure"], tokens, diagrams) if retired else live["treasure"]
        hud = transcribe(current["pattern_rewrite"], current["historical_hud"], tokens, diagrams) if retired else live["hud"]
        for collection in ("layouts", "historical_layouts"):
            expected = set(RESOLUTIONS) if collection == "layouts" or retired else set()
            assert set(current[collection]) == expected, (relic_id, collection)
            for size, measurement in current[collection].items():
                assert measurement["logical_viewport"] == list(map(int, size.split("x")))
        leak_rows = [
            {"surface": surface, "text": value["printed_prose"]}
            for surface, value in live.items() if RAW_MARKUP.search(value["text"])
        ]
        for variant, reading in current.get("hud_variants", {}).items():
            if RAW_MARKUP.search(reading["text"]):
                leak_rows.append({"surface": f"hud/{variant}", "text": reading["text"].strip()})
        rows.append({
            "id": relic_id, "name": relic["name"], "retired": retired, "resolved_id": current["resolved_id"],
            "raw_text": relic["description"], "source": f"data/relics.json:{data_lines[relic_id]}",
            "formatted_markup": current["formatted_original"], "pattern_rewrite": current["pattern_rewrite"],
            "pattern_reference": pattern_lines.get(current["formatted_original"]),
            "audited_treasure": treasure, "hud_prose": hud["icon_read_prose"], "leaks": leak_rows,
            "offer_layouts": current["layouts"], "historical_offer_layouts": current["historical_layouts"],
            "word_count": len(WORD.findall(treasure["printed_prose"])),
        })
    return rows


def candidate_flags(rows: list[dict], release: dict) -> dict[str, list[dict]]:
    contextual = defaultdict(list)
    for line in (HERE / "style_review.tsv").read_text().splitlines():
        if line and not line.startswith("#"):
            relic, rule, phrase, reason = (item.strip() for item in line.split("|", 3))
            contextual[relic].append(entry(rule, phrase, reason, STYLE))
    release_by_id = {row["id"]: row for row in release["relics"]}
    midpoint = median(row["word_count"] for row in rows)
    result = {}
    for row in rows:
        relic_id, treasure = row["id"], row["audited_treasure"]
        prose = treasure["icon_read_prose"]
        flags = style_flags(prose, row["hud_prose"], contextual[relic_id])
        if relic_id in REPEATING_WHEN and (when := re.search(r"\bwhen\b[^,]+", prose, re.I)):
            flags.append(entry("R16", when[0], "This repeatable trigger uses the one-off timing word."))
        if row["pattern_reference"]:
            flags.append(entry("markup_area", row["pattern_rewrite"], "Whole-line rewrite emits an area diagram."))
        elif area := hits(prose, AREA):
            flags.append(entry("area_copy", ", ".join(area), "Area wording in the displayed relic prose."))
        previous = release_by_id.get(relic_id, {})
        if row["raw_text"] == previous.get("raw_text") and prose == previous.get("audited_treasure", {}).get("icon_read_prose"):
            flags.extend(flag for flag in previous["flags"] if flag["category"] == "markup_english")
        else:
            shorthand = hits(row["pattern_rewrite"], r"@icon\(\w+\)(?:/@icon\(\w+\))+|@icon\(vision\) @icon\(time\) \d+")
            if shorthand:
                flags.append(entry("markup_english", ", ".join(shorthand), "Icon clusters stand in for prose."))
        num_sentences = len(SENTENCE.findall(treasure["printed_prose"]))
        if num_sentences > 1:
            flags.append(entry("multiple_sentences", str(num_sentences), "The description has more than one sentence."))
        if row["word_count"] >= 1.5 * midpoint:
            flags.append(entry("long_copy", f"{row['word_count']} words vs. median {midpoint:g}", "At least 50% longer than the median."))
        layouts = row["historical_offer_layouts"] if row["retired"] else row["offer_layouts"]
        for size, measurement in layouts.items():
            if measurement["overflow"]:
                flags.append(entry(f"overflow_{size}", str(measurement), "Text or its box exceeds the measured space."))
        result[relic_id] = flags
    return result


def flag_map(grouped: dict[str, list[dict]]) -> dict:
    entries = {}
    for relic, flags in grouped.items():
        for flag in flags:
            category = flag["category"]
            if category == "mechanics":
                continue
            evidence = flag["evidence"]
            if category in STRUCTURAL_FLAGS or category.startswith("overflow_"):
                key = (relic, category, "")
            else:
                key = (relic, category, " ".join(evidence.casefold().split()))
            entries[key] = {"id": relic, "category": category, "evidence": evidence, "detail": flag["detail"]}
    return entries


def changed_keys(before: dict, after: dict) -> dict:
    return {
        "disappeared": [before[key] for key in sorted(before.keys() - after.keys())],
        "new": [after[key] for key in sorted(after.keys() - before.keys())],
    }


def markup_delta(captured: dict, rows: list[dict], release: dict) -> list[dict]:
    current = markup_survey(captured, rows)
    keys = {"inline": "raw", "diagrams": "raw", "bindings": "raw", "whole_line_rewrites": "id"}
    changes = []
    for kind, field in keys.items():
        old = {record[field]: record for record in release["markup_survey"][kind]}
        new = {record[field]: record for record in current[kind]}
        for name in sorted(old.keys() | new.keys()):
            before, after = old.get(name), new.get(name)
            fields = {
                "inline": ("printed_word", "icon", "glossary_name", "relics"),
                "diagrams": ("relics",),
                "bindings": ("values",),
                "whole_line_rewrites": ("raw", "rewritten_markup"),
            }[kind]
            def comparable(record: dict | None) -> dict | None:
                if record is None:
                    return None
                return {key: sorted(record[key]) if key == "relics" else record[key] for key in fields}
            if comparable(before) != comparable(after):
                changes.append({"kind": kind, "key": name, "release": comparable(before), "candidate": comparable(after)})
    return changes


def automated_delta(captured: dict, rows: list[dict], release: dict) -> dict:
    release_flags = {row["id"]: row["flags"] for row in release["relics"]}
    layout_delta = {}
    for size in RESOLUTIONS:
        # Keep archival and resolved offer populations separate, as in TXT-22.
        layout_delta[size] = {}
        for group, key in (("resolved", "offer_layouts"), ("archival", "historical_offer_layouts")):
            before = {row["id"]: row[key][size] for row in release["relics"] if size in row[key]}
            after = {row["id"]: row[key][size] for row in rows if size in row[key]}
            before_overflow = {relic: fit for relic, fit in before.items() if fit["overflow"]}
            after_overflow = {relic: fit for relic, fit in after.items() if fit["overflow"]}
            layout_delta[size][group] = {
                "measurements": len(after),
                "new_overflows": sorted(after_overflow.keys() - before_overflow.keys()),
                "cleared_overflows": sorted(before_overflow.keys() - after_overflow.keys()),
            }
    return {
        "flags": changed_keys(flag_map(release_flags), flag_map(candidate_flags(rows, release))),
        "markup": markup_delta(captured, rows, release),
        "overflow": layout_delta,
        "leaked_markup": [
            {"id": row["id"], **leak}
            for row in rows if not row["retired"] for leak in row["leaks"]
        ],
    }
