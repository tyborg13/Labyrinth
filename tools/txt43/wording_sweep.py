"""List remaining style findings separately from truth verdicts."""

from collections import defaultdict
import json
import re


MARKUP = re.compile(r"@(?:icon|kw|term|pattern)\([^()]*\)|\[/?[a-z_]+(?:=[^\]]*)?\]")
SENTENCE_BREAK = re.compile(r"(?<=[.!?])\s+")
BARE_START = re.compile(r"^(?:it|its|they|their)\b", re.IGNORECASE)
PLAYER_ADDRESS = re.compile(r"\b(?:you|your|yourself)\b", re.IGNORECASE)
PLACEMENT_RIDER = "Leaves this ground in the affected area."

# Second person names the actual hero in these proven effects. Keep unknown
# references visible for review instead of counting them as automatically true.
PLAYER_BODY_LINES = {
    "You can't choose a Burrowed enemy as a target, and Gust doesn't move a Burrowed enemy.",
    "This enemy damages you and your Illusions on Marked tiles, then Pushes you 1 tile away.",
    "This enemy Blinks behind you, or to an empty tile adjacent to you, "
    "then Ambushes on this enemy's next turn.",
    "This enemy starts Eclipse for your next 2 turns, then hits you and your Illusions on Marked tiles.",
    "When you hit this enemy from an adjacent tile, you take 3 damage.",
    "You gain +1 Card Play next turn.",
    "On this enemy's next turn, this enemy hits each Marked tile around you and leaves Fire.",
}


def avoid_terms(root):
    section = (root / "spec/card_text_style.md").read_text().partition("## Fixed vocabulary")[2]
    terms = set()
    for row in section.splitlines():
        if not row.startswith("|") or row.startswith(("| Idea", "|---")):
            continue
        for phrase in row.strip("|").split("|")[-1].split(","):
            phrase = re.sub(r"\s+\([^)]*\)\s*$", "", phrase).strip(' "`')
            if phrase and phrase != "the card's own name":
                terms.add(phrase)
    return sorted(terms, key=lambda term: (-len(term), term))


def term_pattern(term):
    if term == "radius-N":
        part = r"radius[- ]\d+"
    elif term == "is Exposed 2":
        part = r"is Exposed \d+"
    else:
        forms = {
            "clear": r"clear(?:s|ed|ing)?",
            "expend": r"expend(?:s|ed|ing)?",
            "grant": r"grant(?:s|ed|ing)?",
            "receive": r"receiv(?:e|es|ed|ing)",
            "suffer": r"suffer(?:s|ed|ing)?",
            "strike": r"strik(?:e|es|ing)",
        }
        part = forms.get(term, re.escape(term))
    return re.compile(rf"(?<!\w){part}(?!\w)", re.IGNORECASE)


def plain_body(text):
    return MARKUP.sub("", text).strip()


def collect_tooltips(export, live):
    sources = defaultdict(set)
    standard_ground = defaultdict(set)

    def add(key, surface, text):
        if text:
            sources[key, text].add(surface)

    def add_tokens(key, surface, tokens):
        for token in tokens:
            for field in ("tooltip", "display_tooltip"):
                text = token.get(field, "")
                if token["icon"].startswith("surface_") and text.endswith(PLACEMENT_RIDER):
                    standard_ground[key].add(text)
                    continue
                add(key, surface, text)

    for key, row in export["pages"].items():
        add_tokens(key, "Grimoire row chip", row["tokens"])
    for key, row in live.items():
        add_tokens(key, "combat row chip", row["combat_tokens"])
    for key, row in export["live"].items():
        add_tokens(key, "focused live chip", row["combat_tokens"])

    for key, row in live.items():
        add(key, "Known Moves", row["known"]["tooltip"])
        add(key, "combat intent", row["combat_tooltip"])
    for key, row in export["live"].items():
        add(key, "focused Known Moves", row["known_moves_tooltip"])
        add(key, "focused combat intent", row["combat_tooltip"])
    assert export["swept_path"]["impact"]
    return sources, standard_ground


def wording_report(root, export, live):
    terms = [(term, term_pattern(term)) for term in avoid_terms(root)]
    enemies = json.loads((root / "data/enemies.json").read_text())
    name_matches = [
        re.compile(rf"\b{re.escape(name)}\b", re.IGNORECASE)
        for name in {enemy["name"] for enemy in enemies.values()}
        | {intent["name"] for enemy in enemies.values() for intent in enemy.get("intents", [])}
        if any(pattern.search(name) for _, pattern in terms)
    ]
    tooltips, standard_ground = collect_tooltips(export, live)
    findings = []
    addressed_rows = set()
    suspect_rows = set()
    for (key, text), sources in sorted(tooltips.items()):
        reasons = set()
        # Ignore the standard placement rider inside joined tooltips too,
        # while retaining the unedited source tooltip for the report.
        scanned = text
        for ground in sorted(standard_ground[key], key=len, reverse=True):
            scanned = scanned.replace(ground, "")
        for raw_line in scanned.splitlines():
            line = plain_body(raw_line)
            sentence_parts = [sentence for sentence in SENTENCE_BREAK.split(line) if sentence]
            if any(BARE_START.match(sentence) for sentence in sentence_parts):
                reasons.add("bare opening pronoun")
            if len(sentence_parts) > 1:
                reasons.add("multiple sentences on one body line")
            if ";" in line:
                reasons.add("semicolon")
            if PLAYER_ADDRESS.search(line):
                addressed_rows.add(key)
                if line not in PLAYER_BODY_LINES:
                    suspect_rows.add(key)
                    reasons.add("review second-person referent")
            names = [match.span() for pattern in name_matches for match in pattern.finditer(line)]
            for term, pattern in terms:
                for match in pattern.finditer(line):
                    if any(start <= match.start() and match.end() <= end for start, end in names):
                        continue
                    if term.casefold() == "expend" and match.group() == "Expend":
                        continue
                    if term == "strike" and line.lstrip().startswith("Strike "):
                        continue
                    reasons.add(f"avoid `{term}`")
        if reasons:
            tag = "TODO_DESIGN_" + key.replace("/", "_")
            findings.append((tag, text, sorted(sources), sorted(reasons)))
    lines = [
        "## Report-only wording sweep", "",
        f"Scanned {len(export['pages'])} catalog and {len(live)} live rows, "
        f"including the {len(export['live'])} focused controls and the swept-path receipt.",
        f"Reviewed explicit player address in {len(addressed_rows)} distinct moves. "
        f"{len(suspect_rows)} rows need second-person referent review.", "",
        "| Row | Rule | Surfaces | Current tooltip |", "| --- | --- | --- | --- |",
    ]
    for tag, text, sources, reasons in findings:
        shown = "<br>".join(f"`{line.replace('|', '&#124;')}`" for line in text.splitlines())
        lines.append(f"| `{tag}` | {', '.join(reasons)} | {', '.join(sources)} | {shown} |")
    print(f"TXT43 WORDING SWEEP: {len(findings)} tooltip findings on "
          f"{len({row[0] for row in findings})} moves, {len(suspect_rows)} second-person findings")
    return lines
