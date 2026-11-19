"""Collect QA-112 text with current source coordinates and runtime provenance."""
import bisect
import json
from pathlib import Path
import re
import sys

# Reuse the existing audited GDScript lexer and source-classification rules.
sys.dont_write_bytecode = True
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
import text_audit as existing

ROOT = existing.ROOT
DATA_KEYS = {
    "battlefield_rules": {"sentence"},
    "card_panel_text": {"legacy", "diagram_text"},
    "demo": {"end_title", "end_body", "links_line", "wishlist", "discord", "feedback",
             "keystone_tag", "keystone_tooltip"},
    "glossary": {"definition"},
    "opening_boons": {"offer", "taken", "declined", "decline", "heirloom_prompt",
                      "leave_nothing", "heirloom_confirmation", "back"},
    "relics": {"reason"},
    "special_encounters": {"tooltip_line", "break_line", "reward_line", "objective_title",
                           "objective_hud_title", "objective_description", "rule_line",
                           "kicker", "turns_left", "turns_left_one"},
}
DATA_SURFACES = {
    "battlefield_rules": "room rules", "card_panel_text": "card panel", "demo": "run-end recap",
    "glossary": "glossary and shared tooltips", "opening_boons": "opening boons",
    "pattern_rule_text": "room rules and pattern tooltips", "relics": "relics and items",
    "special_encounters": "special encounters",
}
JSON_TOKEN = re.compile(r'"(?:\\.|[^"\\])*"|[{}\[\]:,]|[^\s{}\[\]:,"]+')
DATA_ROLE = {
    "body": "prose", "description": "prose", "definition": "prose", "result": "prose",
    "sentence": "prose", "default_dialogue": "prose", "legacy": "prose", "diagram_text": "prose",
    "end_body": "prose", "objective_description": "prose", "rule_line": "prose",
    "name": "heading", "title": "heading", "objective_title": "heading",
    "objective_hud_title": "heading", "end_title": "heading", "label": "label",
}
DIRECT_TEXT = re.compile(r'(?:(?:\.\b(?:text|tooltip_text|placeholder_text)|^\s*(?:text|tooltip_text|placeholder_text|dialog_text|title))\s*[+]?=|\b(?:draw_string|(?:set|make)_text)\()')
BRACKET_MARKUP = re.compile(r'\[/?(?:b|i|u|s|color|font|font_size|center|left|right|url|img|table|cell|meta|wave|shake|rainbow|outline_size|outline_color|hint|lb|rb|br|indent|p|opentype_features|dropcap|ul|ol|code|kbd|bgcolor|fgcolor)(?:[= ][^\]]*)?\]', re.I)
INLINE_MARKUP = re.compile(r"@(kw|term|icon|pattern)\(([^()]*)\)")


def located_json(source):
    """Yield every string value with its JSON pointer and opening-quote line."""
    tokens = iter(JSON_TOKEN.finditer(source))
    newlines = [m.start() for m in re.finditer("\n", source)]

    def walk(token, path):
        value = token[0]
        if value == "{":
            key = next(tokens)
            while key[0] != "}":
                next(tokens)  # colon
                yield from walk(next(tokens), (*path, json.loads(key[0])))
                key = next(tokens)
                if key[0] == ",":
                    key = next(tokens)
        elif value == "[":
            index = 0
            child = next(tokens)
            while child[0] != "]":
                yield from walk(child, (*path, str(index)))
                index += 1
                child = next(tokens)
                if child[0] == ",":
                    child = next(tokens)
        elif value.startswith('"'):
            yield path, json.loads(value), bisect.bisect(newlines, token.start()) + 1

    json.loads(source)
    yield from walk(next(tokens), ())


def row(kind, surface, location, value, role="", family=""):
    return {"kind": kind, "surface": surface, "location": location, "text": value,
            "role": role, "family": family}


def data_rows(path, source, relative):
    for keys, value, line in located_json(source):
        key = next((part for part in reversed(keys) if not part.isdigit()), "")
        if (key not in existing.DATA_TEXT_KEYS | DATA_KEYS.get(path.stem, set())
                and path.stem not in {"run_end_text", "pattern_rule_text"}):
            continue
        if not value.strip() or value.startswith(("res://", "https://", "http://")):
            continue
        surface = DATA_SURFACES.get(path.stem) or existing.data_surface(relative, keys)
        role = DATA_ROLE.get(key, "prose" if path.stem == "pattern_rule_text" else "")
        if path.stem == "card_panel_text" and key == "text":
            role = "prose"
        pointer = existing.pointer(keys) if path.stem != "pattern_rule_text" else "/copy (replacement value)"
        family = f"{path.name}/{key}" if role == "prose" and path.stem != "pattern_rule_text" else ""
        yield row("data", surface, f"{relative}:{line} {pointer}", value, role, family)


def sources():
    for path in existing.source_files():
        source = path.read_text(encoding="utf-8")
        relative = path.relative_to(ROOT).as_posix()
        if path.suffix == ".json":
            yield from data_rows(path, source, relative)
            continue
        for lit in existing.literals(source):
            direct = DIRECT_TEXT.search(lit.expression) and not re.search(r"\b(?:print|push_error|push_warning|assert)\(", lit.expression)
            if path.suffix != ".gd":
                if not re.match(r"(?:text|tooltip_text|placeholder_text|title|dialog_text|config/name)\s*=", lit.expression):
                    continue
            elif not direct and not lit.text.startswith("ERROR_MISSING_") and existing.inclusion(lit, source, relative):
                continue
            if not lit.text.strip() or lit.text.startswith(("res://", "uid://", "user://")):
                continue
            surface = existing.code_surface(relative, lit.scope, lit.expression, lit.text)
            if path.stem.startswith("combat_objective"):
                surface = "combat objectives"
            elif path.stem in {"turn_clock_hud", "hud_stat_chip", "combat_hud_forecast"}:
                surface = "HUD labels"
            elif path.stem.startswith(("combat_", "board_")) and "rule" in lit.scope:
                surface = "room rules"
            role = "prose" if "tooltip_text" in lit.expression else ""
            yield row("source", surface, f"{relative}:{lit.line} ({lit.scope})", lit.text, role)


CAPTURE_SURFACES = {
    "01": "card panel", "02": "reward screen", "03": "relics and items", "04": "relics and items",
    "05": "status/condition tooltip", "06": "enemy intents and traits", "07": "map node",
    "08": "event body", "09": "shop", "10": "chronicle", "11": "run-end recap",
    "12": "menus/settings", "13": "glossary and shared tooltips", "14": "enemy intents and traits",
    "15": "equipment", "16": "Grimoire", "17": "onboarding/tutorial",
    "18": "confirmation dialogs", "19": "chronicle", "20": "menus/settings",
    "21": "status/condition tooltip", "22": "event choice", "23": "skills", "24": "equipment",
    "25": "campfire", "26": "pre-battle", "27": "menus/settings", "28": "relics and items",
}


def observation_rows(path):
    captures = json.loads(path.read_text(encoding="utf-8"))["captures"]
    if len(captures) != len(CAPTURE_SURFACES) or not all(c["semantic_ok"] for c in captures):
        raise ValueError("Expected all 28 successful UI fixtures")
    for capture in captures:
        surface = CAPTURE_SURFACES[capture["id"].split("_", 1)[0]]
        for record in capture["texts"]:
            node = record["node"].rsplit("/", 1)[-1]
            role = ""
            if re.search(r"button|tab\d*$|choice\d*$", node, re.I):
                role = "button"
            elif re.search(r"title|heading|header", node, re.I):
                role = "heading"
            elif re.search(r"tooltip|description|body", node, re.I):
                role = "prose"
            location = f'{capture["id"]} / {record["node"]}'
            yield row("observed", surface, location, record["text"], role)


def formatted_rows(path):
    prefix = "QA112_JSON:"
    lines = [line[len(prefix):] for line in path.read_text(encoding="utf-8").splitlines()
             if line.startswith(prefix)]
    if len(lines) != 1:
        raise ValueError("Expected one successful QA112 Godot copy export")
    for record in json.loads(lines[0]):
        location = record["location"]
        node = location.rsplit("/", 1)[-1]
        role = ("heading" if re.search(r"title|heading|header", node, re.I) else
                "button" if re.search(r"button|EventContinue", node, re.I) or re.search(r"/Choice\d+/.*/@Label", location) else
                "prose" if re.search(r"description|paragraph|tooltip", node, re.I) else "")
        yield row(record["kind"], record["surface"], location, record["text"], role)



def clean_text(value, glossary):
    """Remove presentation syntax without silently hiding unknown bracket tags."""
    def inline(match):
        kind, argument = match.groups()
        key, separator, label = argument.partition("|")
        if kind in {"icon", "pattern"}:
            # A pictogram has no printed letters. Retain its position for spacing.
            return "¤"
        return label if separator else glossary.get(key, match[0])

    return INLINE_MARKUP.sub(inline, BRACKET_MARKUP.sub("", value))
