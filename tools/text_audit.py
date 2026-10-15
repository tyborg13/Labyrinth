#!/usr/bin/env python3
"""Read-only player copy/icon audit. Run with no args to regenerate; --check fails
on drift, unknown sources, invalid icon references or a failed headless export.

No localization or gameplay files are changed. GDScript literals retain their
source expressions; computed card rows/relic descriptions come from the live
production helpers, not a second implementation of gameplay rules.
"""
from __future__ import annotations

import argparse
import collections
import csv
import hashlib
import io
import json
from pathlib import Path
import re
import subprocess
import sys
import unittest
from dataclasses import dataclass

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "spec/peer_benchmark/staged/text"
PROBE = "tests/text_audit_capture_probe.gd"
SCHEMA = 1
# Debug/tool defaults only; no values below alter player-facing content.
EXPORT_TIMEOUT_SECONDS = 180
DIGEST_LENGTH = 12
LONG_TOOLTIP_WORDS = 35  # brief's reporting threshold
LONGEST_PER_SURFACE = 15  # brief's reporting threshold
SURFACES = (
    "card name", "card rules", "card flavour", "card tooltip", "keyword tooltip",
    "relic name", "relic description", "relic tooltip", "status/condition tooltip",
    "intent label/tooltip", "enemy name/tooltip", "event title", "event body", "event choice",
    "map node", "reward screen", "shop", "chronicle", "run-end recap", "menus/settings",
    "HUD labels", "onboarding/tutorial", "confirmation dialogs", "error/empty states",
    "equipment", "skills", "grimoire", "dialogue", "combat log",
)
DATA_TEXT_KEYS = {"name", "label", "description", "title", "body", "summary", "text", "result",
                  "default_dialogue", "flavour", "flavor", "tooltip", "source_name"}
FORMAT = re.compile(r"%(?:\d+\$)?[-+0 #]*\d*(?:\.\d+)?[sdifxXocve]|\{[\w.]+\}|<(?:n|card|damage)>")
ICON = re.compile(r"@icon\(([^)]+)\)")
# A lexical pass, not a regex over lines: comments, escaped quotes, triple
# strings, raw strings and multiple occurrences on one line are distinguished.
LEX = re.compile(r'''(?P<comment>\#[^\n]*)|(?P<string>(?:[rR])?(?:"""[\s\S]*?"""|\x27\x27\x27[\s\S]*?\x27\x27\x27|"(?:\\.|[^"\\])*"|\x27(?:\\.|[^\x27\\])*\x27))''')


@dataclass(frozen=True)
class Literal:
    text: str
    raw: str
    start: int
    end: int
    line: int
    scope: str
    expression: str


def decode_string(raw):
    raw_mode = raw[0] in "rR"
    value = raw[1:] if raw_mode else raw
    quote = 3 if value.startswith(('"""', "'''")) else 1
    value = value[quote:-quote]
    if raw_mode:
        return value
    escapes = {"n": "\n", "r": "\r", "t": "\t", "b": "\b", "f": "\f", "v": "\v", "a": "\a", '"': '"', "'": "'", "\\": "\\"}
    return re.sub(r"\\(u[0-9a-fA-F]{4}|U[0-9a-fA-F]{6}|.)",
                  lambda m: chr(int(m[1][1:], 16)) if m[1][0] in "uU" and len(m[1]) > 1 else escapes.get(m[1], "\\" + m[1]), value)


def literals(source):
    # Scope identifiers deliberately exclude line numbers so ids survive moving
    # code. Source lines/spans still point at the exact current occurrence.
    scopes = []
    for m in re.finditer(r"(?m)^(?:\t*)(?:(?:static )?func|const)\s+([A-Za-z_][A-Za-z_0-9]*)", source):
        scopes.append((m.start(), m[1]))
    scope_i = 0
    for m in LEX.finditer(source):
        if not m.group("string"):
            continue
        while scope_i + 1 < len(scopes) and scopes[scope_i + 1][0] < m.start():
            scope_i += 1
        scope = scopes[scope_i][1] if scopes and scopes[scope_i][0] < m.start() else "top_level"
        begin = source.rfind("\n", 0, m.start()) + 1
        end = source.find("\n", m.end())
        end = len(source) if end == -1 else end
        # Capture multiline format operands, dictionaries and UI calls. The
        # complete owning function is also referenced in every code record.
        expression = source[begin:end].strip()
        if source[m.end():end].rstrip().endswith(("[", "(", "{", "\\")):
            lines = source[end:].splitlines()[1:]
            indent = len(source[begin:m.start()]) - len(source[begin:m.start()].lstrip())
            for line in lines:
                expression += "\n" + line
                if line.strip() and len(line) - len(line.lstrip()) <= indent:
                    break
        yield Literal(decode_string(m.group()), m.group(), m.start(), m.end(), source.count("\n", 0, m.start()) + 1, scope, expression)


def json_leaves(value, path=()):
    if isinstance(value, dict):
        for key, child in value.items():
            yield from json_leaves(child, (*path, str(key)))
    elif isinstance(value, list):
        for i, child in enumerate(value):
            yield from json_leaves(child, (*path, str(i)))
    else:
        yield path, value


def pointer(path):
    return "/" + "/".join(x.replace("~", "~0").replace("/", "~1") for x in path)


def at_pointer(value, key):
    for part in key.lstrip("/").split("/"):
        part = part.replace("~1", "/").replace("~0", "~")
        value = value[int(part)] if isinstance(value, list) else value[part]
    return value


def digest(value):
    return hashlib.sha256(value.encode()).hexdigest()[:DIGEST_LENGTH]


def word_count(text, labels=None):
    # Numbers and format parameters are one word, inline icons count as their
    # visible concept rather than their file paths; BBCode controls count zero.
    text = ICON.sub(lambda m: (labels or {}).get(m[1], m[1].replace("_", " ")), text)
    text = re.sub(r"\[(?:/?(?:b|i|u|s|color|font|font_size|center|left|right|url|img|table|cell|meta|wave|shake|rainbow|outline_size)[^\]]*)\]", "", text)
    text = FORMAT.sub(" VALUE ", text)
    return len(re.findall(r"[\w]+(?:[’'-][\w]+)*", text, re.UNICODE))


def code_surface(path, scope, expression, text):
    context = (Path(path).stem + " " + scope).lower()
    if Path(path).stem == "element_data": return "keyword tooltip"
    if Path(path).stem == "board_surface_presentation": return "status/condition tooltip"
    if Path(path).stem in {"new_descent_panel", "menu_run_transition"}: return "menus/settings"
    if "/enemy_mechanics/" in path:
        return "status/condition tooltip" if re.search(r"badge|tooltip|description", scope) or "\n" in text else "intent label/tooltip"
    if Path(path).stem in {"pre_battle_inspection_view", "pre_battle_threat_tags", "guardian_library"}: return "enemy name/tooltip"
    if Path(path).stem == "game_data" and "upgrade" in scope: return "card tooltip"
    if re.search(r"(?:append|add|set)_log|\[\"log\"\]", expression): return "combat log"
    if re.search(r"confirm|abandon|restore_default", context): return "confirmation dialogs"
    if re.search(r"tutorial|onboard|guided_combat|contextual_combat", context): return "onboarding/tutorial"
    if re.search(r"chronicle", context): return "chronicle"
    if re.search(r"run_end|recap|run_score", context): return "run-end recap"
    if re.search(r"settings|main_menu|pause_|boot_splash", context): return "menus/settings"
    if re.search(r"(?:^|_)(?:empty|unavailable|error|failure|no_results)(?:_|$)", scope) or text.startswith(("No recorded", "No matching", "No active", "Could not save", "Nothing new to", "Requires ")): return "error/empty states"
    if re.search(r"event_|omen", context): return "event choice" if "choice" in context else "event body"
    if re.search(r"dialogue|npc_", context): return "dialogue"
    if re.search(r"shop|merchant|scavenger|graftwright", context): return "shop"
    if re.search(r"relic", context): return "relic tooltip"
    if re.search(r"reward|treasure", context): return "reward screen"
    if re.search(r"section_map|room_|map_|door_", context): return "map node"
    if re.search(r"grimoire", context): return "grimoire"
    if re.search(r"status|condition|badges|terrain_tooltip|surface_tooltip", context): return "status/condition tooltip"
    if re.search(r"intent", context): return "intent label/tooltip"
    if re.search(r"enemy.*(label|tooltip|detail|name)|pre_battle_enemy", context): return "enemy name/tooltip"
    if re.search(r"equipment|loadout|inventory|pack_", context): return "equipment"
    if re.search(r"skill", context): return "skills"
    if re.search(r"action_icon|keyword|token|element_data", context): return "keyword tooltip"
    if re.search(r"card_|spell|magick", context): return "card tooltip"
    if "log" in context: return "combat log"
    return "HUD labels"


def data_surface(path, keys):
    name = Path(path).stem
    key = next((k for k in reversed(keys) if not k.isdigit()), "")
    if name == "cards": return "card name" if key == "name" else "card flavour" if key in ("flavor", "flavour") else "card rules"
    if name == "relics": return "relic name" if key == "name" else "relic description"
    if name == "enemies": return "intent label/tooltip" if "intents" in keys else "enemy name/tooltip"
    if name == "events": return "event title" if key == "title" else "event choice" if "choices" in keys else "event body"
    return {"grimoire": "grimoire", "run_end_text": "run-end recap", "npcs": "dialogue", "depths": "map node",
            "biomes": "map node", "equipment": "equipment", "skills": "skills", "upgrades": "card tooltip"}.get(name, "HUD labels")


def inclusion(lit, source, path):
    """Conservative classification, with a reviewable exclusion ledger. Literals
    that look like prose are retained even if they are conditional fallbacks.
    Never discard a candidate solely because it occurs in a rules script.
    """
    text, expr = lit.text, lit.expression
    before = source[max(0, lit.start - 100):lit.start]
    after = source[lit.end:lit.end + 40]
    # These are infrastructure, serialization, cache keys and rig internals,
    # not sources of UI copy. Keep the reason/occurrence in coverage.json.
    if Path(path).stem in {"asset_loader", "analytics_store", "performance_telemetry", "parallel_runtime", "card_presentation_cache", "cutout_context", "save_pipeline", "attack_sfx_library", "run_sfx_library", "sfx_bank", "original_music", "attack_fx_library", "enemy_strike_points", "enemy_strike_cache", "encounter_tables", "sfx_cue_router", "health_ghost_tracker", "player_turn_analytics", "static_enemy_facing", "unit_shadow_cache_resource", "combat_pacing", "movement_undo_rules"}:
        return "non-display infrastructure"
    if re.search(r"/(?:\w+_cutout)/(?:rig|motion|renderer|pool|bloom_fx)\.gd$", path):
        return "rig/animation internal"
    if Path(path).stem == "rig_data" or lit.scope in {"IGNORED_FIELDS", "validate_data", "_validate_effects", "fit_report", "debug_snapshot", "semantic_snapshot"}:
        return "validation/internal report"
    if Path(path).stem == "combat_pacing" and lit.scope.isupper(): return "debug timing label"
    if Path(path).stem == "cursor_feedback" and "knock" in text or Path(path).stem == "cursor_feedback" and "click" in text: return "sound design metadata"
    if Path(path).stem == "input_router" and lit.scope != "glyph_label_for_family": return "device detection"
    if Path(path).stem == "steam_service" and lit.scope not in {"FALLBACK_PROFILE_NAME", "PROFILE_PREFIX", "profile_label_text"}: return "Steam integration diagnostic"
    if re.search(r"analytics|idempotency|manifest|instance_keys|safe_path|prewarm", lit.scope): return "internal bookkeeping"
    if not text.strip(): return "empty/whitespace"
    if text.startswith(("res://", "user://", "uid://", "http://", "https://")): return "resource/address"
    if re.match(r"^\s*:", after) and not after.startswith("://"): return "dictionary/match key"
    if re.search(r"(?:preload|load|get_node|get_node_or_null|has_method|call|connect|set_meta|get_meta|has_meta|emit_signal)\(\s*$", before): return "code identifier"
    if re.search(r"(?:\.name|\.resource_name)\s*=\s*$", before): return "node identifier"
    if re.search(r"(?:\.find_child|\.find_children|\.is_class|\.tween_property)\([^\n]*$", before): return "node/property identifier"
    if re.search(r"\b(?:push_error|push_warning|printerr|print|assert)\s*\(", expr): return "developer diagnostic"
    if re.search(r"(?:^|\W)(?:debug|benchmark|performance|analytics)(?:_|\W)", lit.scope.lower()) and not re.search(r"text|label|tooltip", lit.scope): return "developer instrumentation"
    if text.lstrip().startswith(("shader_type", "[gd_", "[node ")): return "shader/serialized code"
    if text.startswith("--") or text in {"@icon(", "(.*?)"} or "\\[" in text: return "parser/CLI syntax"
    if re.fullmatch(r"(?:%[-+.\d]*[sdifx]|[|,]){2,}", text): return "packed cache/coordinate key"
    if "|" in text and " " not in text: return "packed internal key"
    if re.fullmatch(r"[a-z_]+_-?\d+", text): return "actor identifier"
    if text.startswith(("attack.elemental.", "spell.")): return "audio cue key"
    if re.fullmatch(r"[A-Za-z_]+_%[sd](?:_%[sd])*", text) or text.endswith(":") and " " not in text and text[0].islower(): return "formatted/internal identifier"
    if re.search(r"cache|signature|hash|fingerprint|serialization|storage_path|profiling|thread", lit.scope) and not re.search(r"tooltip|label|description", lit.scope):
        return "cache/serialization/instrumentation"
    if re.fullmatch(r"[a-z0-9_]+(?:[.:/][a-z0-9_%]+)+", text) or re.fullmatch(r"\.?[a-z]+", text) and text.startswith("."):
        return "property/resource key"
    if re.fullmatch(r"[a-z0-9_:/.-]*%[sdi][a-z0-9_%:/.,-]*", text) and re.search(r"[a-z_:/]", text.replace("%s", "").replace("%d", "").replace("%i", "")):
        return "formatted identifier"
    if re.fullmatch(r"#[0-9a-fA-F]{3,8}|[0-9a-fA-F]{6,8}", text): return "colour"
    if re.fullmatch(r"[a-zA-Z0-9_./:%+-]+\.(?:png|svg|webp|ogg|wav|json|gd|tres|tscn|save|csv)", text): return "file name"
    if re.fullmatch(r"(?:[A-Za-z0-9_]+/)+[A-Za-z0-9_/]+", text): return "node path"
    if re.fullmatch(r"[A-Z][a-z0-9]+(?:[A-Z][A-Za-z0-9]*)+", text) and " " not in text: return "node/class identifier"
    if re.fullmatch(r"[a-z0-9_]+", text):
        if re.search(r'(?:\.text\s*[+=]|draw_string\([^\n]*,|\b(?:text_token|_label|_heading|_set_status)\()\s*$', before) or ("scenes/" in path and re.match(r"(?:text|placeholder_text|tooltip_text)\s*=", expr)):
            return None
        return "data key/enum"
    if re.fullmatch(r"[A-Z_0-9]+", text) and "_" in text: return "constant identifier"
    if re.fullmatch(r"[\W\d]+", text) and not FORMAT.search(text):
        if re.search(r"text|label|draw_string|token|title", expr): return None
        return "syntax/separator"
    # Capitalized display words, prose, format templates and inline tokens.
    return None


def source_files():
    return sorted([*ROOT.glob("data/*.json"), *ROOT.glob("scripts/**/*.gd"), *ROOT.glob("scenes/**/*.tscn"), ROOT / "project.godot"])


class Audit:
    def __init__(self, runtime):
        self.runtime = runtime
        self.records = []
        self.excluded = []
        self.sources = {}
        self.data = {}
        self.literals = {}
        self.occurrences = collections.Counter()

    def ref(self, path, needle):
        source = self.sources.get(path) or (ROOT / path).read_text()
        index = source.find(needle)
        if index < 0: raise ValueError(f"Unknown source anchor: {path}: {needle}")
        return f"{path}:{source.count(chr(10), 0, index) + 1}"

    def record(self, stable_id, surface, text, source, where, display="inline", **extra):
        self.records.append(dict(id=stable_id, surface=surface, source=source, text=text,
                                 word_count=word_count(text, {k: v["label"] for k, v in self.runtime.get("icons", {}).items()}), parameters=FORMAT.findall(text),
                                 numbers="formatted from data/state" if FORMAT.search(text) else "static",
                                 where_shown=where, presentation=display, **extra))

    def extract(self):
        for file in source_files():
            path = str(file.relative_to(ROOT))
            content = file.read_text()
            self.sources[path] = content
            if file.suffix == ".json":
                data = json.loads(content)
                self.data[path] = data
                for keys, text in json_leaves(data):
                    if not isinstance(text, str): continue
                    key = next((k for k in reversed(keys) if not k.isdigit()), "")
                    if key not in DATA_TEXT_KEYS and file.name != "run_end_text.json": continue
                    surface = data_surface(path, keys)
                    source = dict(kind="data", path=path, key=pointer(keys))
                    display = "both" if surface in ("card name", "card rules", "relic name", "relic description", "equipment", "skills", "enemy name/tooltip") else "inline"
                    where = {
                        "cards": ["hand", "card reward", "card inspection", "shop", "grimoire", "chronicle spell list"],
                        "relics": ["relic choice", "owned relic tray", "chronicle relics", "grimoire"],
                        "equipment": ["equipment inspection", "shop", "character menu", "chronicle gear", "grimoire"],
                        "enemies": ["board", "pre-battle", "enemy inspection", "grimoire"],
                    }.get(file.stem, [surface])
                    self.record(f"data:{path}#{pointer(keys)}", surface, text, source, where, display)
                    if file.stem in ("relics", "cards"):
                        owner = data
                        for part in keys[:-1]:
                            owner = owner[int(part)] if isinstance(owner, list) else owner[part]
                            if isinstance(owner, dict) and "replacement_id" in owner:
                                self.records[-1]["availability"] = "legacy definition; runtime redirects to " + owner["replacement_id"]
            else:
                tokens = list(literals(content))
                self.literals[path] = tokens
                for lit in tokens:
                    reason = inclusion(lit, content, path)
                    if file.suffix == ".tscn" or file.name == "project.godot":
                        if not re.match(r"(?:text|tooltip_text|placeholder_text|title|dialog_text|config/name)\s*=", lit.expression):
                            reason = "scene/project non-text property"
                    if reason:
                        self.excluded.append(dict(source=f"{path}:{lit.line}", scope=lit.scope, text=lit.text, reason=reason))
                        continue
                    base_id = f"code:{path}:{lit.scope}:{digest(lit.text)}"
                    self.occurrences[base_id] += 1
                    stable_id = base_id + f":{self.occurrences[base_id]}"
                    surface = code_surface(path, lit.scope, lit.expression, lit.text)
                    presentation = "tooltip" if "tooltip" in (lit.scope + lit.expression).lower() else "both" if path.endswith("action_icon_library.gd") else "inline"
                    self.record(stable_id, surface, lit.text,
                                dict(kind="code", path=path, line=lit.line, location=f"{path}:{lit.line}", scope=lit.scope,
                                     span=[lit.start, lit.end], literal=lit.raw, expression=lit.expression),
                                [surface, f"{path}::{lit.scope}"], presentation)
        self.add_runtime_records()
        self.records.sort(key=lambda r: r["id"])

    def add_runtime_records(self):
        for kind in ("cards", "relics"):
            for id, entry in sorted(self.runtime[kind].items()):
                raw = self.data[f"data/{kind}.json"]
                if kind in raw: raw = raw[kind]
                if id not in raw: raise ValueError(f"Runtime {kind} id has no source: {id}")
                prefix = f"/{kind}/{id}" if kind in self.data[f"data/{kind}.json"] else f"/{id}"
                if kind == "relics":
                    # Resolve legacy redirects as the game does, while retaining
                    # original raw strings in the source inventory.
                    self.record(f"resolved:relic:{id}", "relic tooltip", str(entry.get("name", "")) + "\n" + str(entry.get("description", "")),
                                dict(kind="generated", path=f"data/{kind}.json", key=prefix,
                                     generators=[self.ref("scripts/game_data.gd", "static func relic_def("), self.ref("scripts/game_data.gd", "static func _format_relic_description(")]),
                                ["owned relic tray", "chronicle relics"], "tooltip", resolved_name=entry.get("name", ""))
                    self.records[-1]["numbers"] = "formatted from data"
                    self.records[-1]["parameters"] = FORMAT.findall(str(raw[id].get("description", "")))
                else:
                    self.record(f"resolved:card:{id}:rules", "card rules", entry["rules"],
                                dict(kind="generated", path="data/cards.json", key=prefix,
                                     generators=[self.ref("scripts/game_data.gd", "static func card_def("), self.ref("scripts/action_icon_library.gd", "static func card_rules_text(")]),
                                ["card inspection", "grimoire", "shop"], "both", number_policy="Base card shown; upgrades modify action rows through GameData.card_def_with_card_mods; prose is not rewritten.")
                    for i, tip in enumerate(entry["tooltip_entries"]):
                        self.record(f"resolved:card:{id}:tooltip:{tip['icon']}:{i}", "card tooltip", tip["tooltip"],
                                    dict(kind="generated", path="data/cards.json", key=prefix,
                                         generators=[self.ref("scripts/action_icon_library.gd", "static func tooltip_entries_for_rows(")]),
                                    ["card hover in hand", "card reward hover", "card focus stack"], "tooltip", concept=tip["icon"])
                        self.records[-1]["numbers"] = "formatted from data; upgraded variants follow the same token/tooltip generators"
        # Runtime-generated rows include condition labels, numeric values and
        # role emblems. Keep them as structured rows in runtime.json; do not
        # flatten pictograms into invented prose.

    def verify_sources(self):
        seen = set()
        for row in self.records:
            if row["id"] in seen: raise ValueError("Duplicate id: " + row["id"])
            seen.add(row["id"])
            source = row["source"]
            if source["path"] not in self.sources: raise ValueError("Unknown source: " + source["path"])
            if source["kind"] == "code":
                start, end = source["span"]
                if self.sources[source["path"]][start:end] != source["literal"] or decode_string(source["literal"]) != row["text"]:
                    raise ValueError("Stale code source: " + row["id"])
            else:
                actual = at_pointer(self.data[source["path"]], source["key"])
                if source["kind"] == "data" and actual != row["text"]: raise ValueError("Stale data source: " + row["id"])
                for location in source.get("generators", []):
                    path, line = location.rsplit(":", 1)
                    if not 0 < int(line) <= len(self.sources[path].splitlines()): raise ValueError("Unknown generator: " + location)
            for key in ICON.findall(row["text"]):
                if "%" not in key and "{" not in key and key not in self.runtime.get("icons", {}):
                    raise ValueError("Unknown inline icon source: " + key + " in " + row["id"])
        return len(seen)

    def records_for(self, path=None, text=None, concept=None):
        return [r for r in self.records if (path is None or r["source"]["path"] == path)
                and (text is None or text.lower() in r["text"].lower())
                and (concept is None or r.get("concept") == concept)]


def runtime_export():
    command = [sys.executable, "tools/godot_task_runner.py", "--task-id", "ux-02", "--timeout", str(EXPORT_TIMEOUT_SECONDS),
               "--stream", "--", "godot", "--headless", "--path", ".", "--script", PROBE, "--", "--export-json"]
    result = subprocess.run(command, cwd=ROOT, capture_output=True, text=True, timeout=EXPORT_TIMEOUT_SECONDS + 10)
    lines = [line for line in result.stdout.splitlines() if line.startswith("TEXT_AUDIT_JSON:")]
    if result.returncode or len(lines) != 1:
        raise ValueError("Headless runtime export failed:\n" + result.stdout[-12000:] + result.stderr[-4000:])
    return json.loads(lines[0].partition(":")[2])


def dump(value):
    return json.dumps(value, ensure_ascii=False, indent=2, sort_keys=True) + "\n"


def build_icons(audit):
    runtime = audit.runtime
    icons = {}
    def add(id, path, concept, source, label=""):
        if id not in icons:
            icons[id] = dict(id=id, art_path=path, concept=concept, current_name=label, sources=[source], surfaces=[])
        return icons[id]
    def use(icon, surface, hover, focus, detail, evidence, text="", ids=()):
        item = dict(surface=surface, tooltip="yes" if hover == focus == "yes" else "no" if hover == focus == "no" else "partial",
                    hover=hover, focus=focus, detail=detail, evidence=evidence, tooltip_text=text, inventory_ids=sorted(set(ids)))
        existing = next((x for x in icon["surfaces"] if x["surface"] == surface and x["detail"] == detail), None)
        if existing:
            existing["inventory_ids"] = sorted(set(existing["inventory_ids"] + item["inventory_ids"]))
        else: icon["surfaces"].append(item)
    reg = "scripts/action_icon_library.gd"
    for key, data in runtime["icons"].items():
        icon = add("action:" + key, data["path"], key, audit.ref(reg, '"' + key + '"'), data["label"])
        matching = [r for r in audit.records if key in ICON.findall(r["text"])]
        for row in matching:
            for surface in row["where_shown"]:
                if surface.startswith("scripts/"): continue
                if row["surface"].startswith("relic"):
                    surface = "relic choice inline symbols" if surface == "relic choice" else "owned relic tooltip inline symbols" if surface == "owned relic tray" else surface + " inline symbols"
                    use(icon, surface, "no", "no", "InlineIconText adds images with a label/alt text; mouse-filter-ignored text has no concept tooltip or focus target.",
                        [audit.ref("scripts/inline_icon_text.gd", "static func apply_to("), audit.ref("scripts/run_scene.gd", "description.mouse_filter = Control.MOUSE_FILTER_IGNORE")], "", [row["id"]])
                else:
                    use(icon, surface + " inline symbols", "partial", "no", "Inline image carries its label; no focusable per-concept target. Parent tooltip availability depends on the owning control.",
                        [audit.ref("scripts/inline_icon_text.gd", "static func apply_to(")], data["label"], [row["id"]])
        card_ids = [id for id, card in runtime["cards"].items() if any(t["icon"] == key for t in card["tooltip_entries"])]
        if card_ids:
            ids = [r["id"] for r in audit.records_for(concept=key)]
            for surface, hover, focus in [("card hover in hand", "yes", "yes"), ("card reward", "yes", "no"), ("card inspection", "partial", "no")]:
                use(icon, surface, hover, focus, "Hand focus has a keyword stack. Reward focus only highlights the card; token hover exposes the definition. Inspection previews require an interactive/pinned panel for nested hover. Overrides are listed by card in runtime.json.",
                    [audit.ref(reg, "static func tooltip_entries_for_rows("), audit.ref("scripts/card_focus_tooltip_stack.gd", "func ")], data["tooltip"], ids)
            use(icon, "action step tracker", "no", "no", "Action chips and their child icons ignore the mouse. The stored step tooltip is not an independently reachable hover/focus target.",
                [audit.ref("scripts/run_scene.gd", 'chip.name = "ActionStepChip%d"')], "", ids)
        # Exact source references (including dynamic dispatch sites) are retained
        # separately from the evaluated card/relic surface coverage above.
        refs = []
        for path, tokens in audit.literals.items():
            if path == reg: continue
            for token in tokens:
                if token.text == key:
                    refs.append(dict(source=f"{path}:{token.line}", scope=token.scope, expression=token.expression))
        icon["code_uses"] = refs
        relevant = [x for x in refs if any(k in x["scope"].lower() for k in ["status", "badge", "tooltip"])]
        if relevant and any("combat_board_view" in x["source"] or "/enemy_mechanics/" in x["source"] for x in relevant):
            use(icon, "board status/condition", "yes", "partial", "Pointer regions expose status copy. Tile/controller details do not enumerate all badge definitions.",
                [audit.ref("scripts/combat_board_view.gd", "func _get_tooltip("), audit.ref("scripts/combat_board_view.gd", "func controller_tooltip_for_tile(")], data["tooltip"])
        action_types = {k for k, v in runtime["action_aliases"].items() if v == key} | {key}
        enemy_data = audit.data["data/enemies.json"]
        enemy_actions = {value for keys, value in json_leaves(enemy_data) if keys[-1] == "type" and isinstance(value, str)}
        if action_types & enemy_actions:
            use(icon, "enemy intent", "yes", "partial", "Board token hover; controller detail omits ordinary move/melee/ranged/aoe/range definitions and shows special riders.",
                [audit.ref("scripts/combat_board_view.gd", "func enemy_intent_tooltip(")], data["tooltip"])
        grimoire_ids = [r["id"] for r in audit.records_for("data/grimoire.json") if any(key == k for k in ICON.findall(r["text"]))]
        if f'"{key}"' in audit.sources["data/grimoire.json"]:
            use(icon, "grimoire entry", "partial", "partial", "Definition is inline in the selected entry; no per-icon definition target.",
                [audit.ref("scripts/run_scene.gd", "func _open_grimoire_overlay(")], "", grimoire_ids)
    raw_relics = audit.data["data/relics.json"]
    raw_relics = raw_relics.get("relics", raw_relics)
    for id, data in raw_relics.items():
        icon = add("relic:" + id, data["icon_path"], "relic:" + id, "data/relics.json#" + pointer(("relics", id, "icon_path")) if "relics" in audit.data["data/relics.json"] else "data/relics.json#" + pointer((id, "icon_path")), data["name"])
        resolved = runtime["relics"][id]
        icon["resolved_name"] = resolved.get("name", "")
        icon["resolved_art_path"] = resolved.get("icon_path", "")
        if data.get("replacement_id"):
            icon["redirects_to"] = data["replacement_id"]
        tip = resolved.get("name", "") + "\n" + resolved.get("description", "")
        use(icon, "relic choice", "no", "no", "Name and description are inline; the choice and ignored icon have no tooltip text.",
            [audit.ref("scripts/run_scene.gd", "func _add_relic_choice(")])
        use(icon, "owned relic tray", "yes", "yes", "Parent badge tooltip gives name and description; stored/used state may append lines. Inline symbols still lack individual definitions.",
            [audit.ref("scripts/run_scene.gd", "func _refresh_relic_bar(")], tip, [f"resolved:relic:{id}"])
        use(icon, "chronicle relics", "yes", "yes", "RecordIcon supports pointer and focus tooltips.",
            [audit.ref("scripts/chronicle_panel.gd", "func _build_items("), audit.ref("scripts/chronicle_panel.gd", "func _show_focus_tooltip(")], tip, [f"resolved:relic:{id}"])
    for key, path in runtime["room_icons"].items():
        icon = add("room:" + key, path, "room:" + key, audit.ref("scripts/room_icon_library.gd", "static func icon_id_for_room("), runtime["room_labels"][key])
        for surface in ["section map", "chronicle path"]:
            script = "scripts/section_map_panel.gd" if surface == "section map" else "scripts/chronicle_panel.gd"
            rows = audit.records_for(script)
            use(icon, surface, "yes", "yes", "Room tooltip assembled from node state; exact templates and operands are in the linked inventory records.",
                [audit.ref(script, "func ")], "", [r["id"] for r in rows if "tooltip" in r["source"].get("scope", "") or r["presentation"] == "tooltip"])
        use(icon, "HUD minimap / board exit", "partial", "partial", "Map/door parent describes the destination; no standalone room-icon control.",
            [audit.ref("scripts/run_scene.gd", 'mini_map_overlay.tooltip_text = "Map [M]"')], "Map [M]")
    for key, path in runtime["card_role_icons"].items():
        icon = add("card_role:" + key, path, "card role:" + key, audit.ref(reg, "const CARD_ROLE_EMBLEM_PATHS"))
        use(icon, "card role emblem", "no", "no", "Decorative role emblem is mouse-filter ignored; card keyword stack describes actions rather than this emblem.",
            [audit.ref("scripts/card_widget.gd", "func setup(next_emblem_path")])
    # Skill art is registered centrally, while its actual definitions live in
    # data/skills.json. Inline detail panels are distinguished from tooltips.
    for id, skill in audit.data["data/skills.json"].items():
        icon = icons["action:" + skill["icon"]]
        rows = [r for r in audit.records_for("data/skills.json") if r["source"].get("key", "").startswith("/" + id + "/")]
        use(icon, "skill tree", "no", "partial", "Press/focus selects an inline detail panel; the skill node's tooltip_text is empty.",
            [audit.ref("scripts/skill_tree_view.gd", "func _on_node_focus_entered(")], "", [r["id"] for r in rows])
        use(icon, "HUD ability sigil preview", "no", "no", "Small owned-skill previews ignore pointer/focus. Activating ABILITIES opens the separate palette.",
            [audit.ref("scripts/run_scene.gd", "func _build_skill_sigil(")])
        use(icon, "HUD ability palette", "no", "partial", "Focus/selection updates inline skill detail; tile tooltip_text is empty.",
            [audit.ref("scripts/run_scene.gd", "func _refresh_skill_status_popover(")], "", [r["id"] for r in rows])
        icon["inline_definition"] = skill["name"] + "\n" + skill["description"]
    for key, function, text in [("move", "func _setup_movement_meter(", "Movement remaining"), ("card_play", "func _setup_play_meter(", "Card plays remaining")]:
        # The existing tooltip properties are deliberately reported as stored
        # but unreachable: both meters and their children ignore pointer input.
        use(icons["action:" + key], "HUD resource meter", "no", "no", "Meter and descendants use MOUSE_FILTER_IGNORE and have no focus target. Tooltip property exists but cannot be reached here.",
            [audit.ref("scripts/run_scene.gd", function)], "", [])
        icons["action:" + key]["surfaces"][-1]["unreachable_tooltip_property"] = text
    for key in ("ember", "defiance", "skill_point", "moltshard"):
        if "action:" + key not in icons: continue
        use(icons["action:" + key], "character/menu stat chip", "no", "no", "Stat chip and its socket are noninteractive; meaning is supplied by the adjacent caption.",
            [audit.ref("scripts/ui_stat_chip.gd", "func _init(")])
    use(icons["action:ember"], "shop currency / receipt", "no", "no", "Currency is a noninteractive stat chip; receipt ember is a decorative TextureRect.",
        [audit.ref("scripts/scavenger_shop_view.gd", '_currency_panel.call("setup"'), audit.ref("scripts/ui_stat_chip.gd", "func _init(")])
    defiance_rows = [r for r in audit.records_for("scripts/run_scene.gd") if r["source"].get("scope") == "_build_defiance_badge"]
    use(icons["action:defiance"], "HUD defiance badge", "yes", "partial", "Pointer exposes the full Defiance rule; the badge itself does not set FOCUS_ALL.",
        [audit.ref("scripts/run_scene.gd", "func _build_defiance_badge(")], "\n".join(r["text"] for r in defiance_rows if "Defiance" in r["text"] or "DEFIANCE" in r["text"]), [r["id"] for r in defiance_rows])
    # Procedural glyphs have no art file. Cite their drawing code instead of
    # inventing an asset path or treating them as missing art.
    for key, label in [("book", "Grimoire"), ("loadout", "Character Loadout"), ("gear", "Menu")]:
        icon = add("procedural:header:" + key, "", "header:" + key, audit.ref("scripts/run_scene.gd", "func _header_icon_texture("), label)
        icon["procedural_source"] = audit.ref("scripts/run_scene.gd", "func _draw_header_" + ("book" if key == "book" else key) + "_icon(")
        use(icon, "HUD header", "yes", "partial", "Header button carries the supplied label as tooltip; controller navigation lists its action.",
            [audit.ref("scripts/run_scene.gd", "func _setup_header_icon_button(")], label)
    glyph_rows = [r for r in audit.records_for("scripts/input_router.gd") if r["source"].get("scope") == "glyph_label_for_family"]
    for row in glyph_rows:
        icon = add("procedural:input:" + digest(row["text"]), "", "input glyph:" + row["text"], row["source"]["location"], row["text"])
        icon["procedural_source"] = audit.ref("scripts/input_glyph.gd", "func _draw(")
        use(icon, "controller prompts", "no", "no", "InputGlyph is drawn and mouse-filter ignored; the adjacent action label supplies its meaning.", [icon["procedural_source"]], "", [row["id"]])
    for id, omen in audit.data["data/events.json"].get("omens", {}).items():
        path = f"res://assets/art/icons/omens/{id}.png"
        icon = add("omen:" + id, path, "omen:" + id, audit.ref("scripts/omen_badges.gd", '"' + id + '"'), omen["name"])
        use(icon, "owned omen tray", "yes", "yes", "Production omen badge gives name, blessing/bane, description and remaining fights on hover/focus.",
            [audit.ref("scripts/omen_badges.gd", "func update_entry(")], omen["name"] + "\n" + omen["kind"].capitalize() + "\n" + omen["description"] + "\n%d fights left")
    # Item, equipment and bespoke glyphs outside registries.
    known_paths = {x["art_path"] for x in icons.values()}
    for path, data in audit.data.items():
        for keys, value in json_leaves(data):
            if not isinstance(value, str) or not keys or keys[-1] != "icon_path" or value in known_paths: continue
            parent = at_pointer(data, pointer(keys[:-1]))
            icon = add("asset:" + digest(value), value, "/".join(keys[:-1]), path + "#" + pointer(keys), parent.get("name", ""))
            rows = [r for r in audit.records if r["source"]["path"] == path and r["source"].get("key", "").startswith(pointer(keys[:-1]) + "/")]
            for surface in sorted({s for r in rows for s in r["where_shown"]}):
                use(icon, surface, "yes", "partial", "Parent item/equipment inspection exposes identity and associated cards. Focus support is surface-specific; inspect linked source.",
                    [audit.ref("scripts/run_scene.gd", "func _build_equipment_tooltip_panel(")], "\n".join(r["text"] for r in rows), [r["id"] for r in rows])
            known_paths.add(value)
    for path, tokens in audit.literals.items():
        for lit in tokens:
            value = lit.text
            if not value.startswith("res://assets/") or not re.search(r"\.(png|svg|webp)$", value): continue
            # Concrete room/guardian paths are expanded by RoomIconLibrary.
            # The format expression remains in the source-use ledger.
            if "%" in value: continue
            if not any(s in value.lower() for s in ("icon", "glyph", "emblem", "card_time_watch", "hud_v3/")) and "ICON_PATH" not in lit.scope: continue
            if any(s in value.lower() for s in ("frame", "plate", "scrim", "background", "backing", "glow")): continue
            if value in known_paths: continue
            icon = add("asset:" + digest(value), value, lit.scope, f"{path}:{lit.line}")
            use(icon, code_surface(path, lit.scope, lit.expression, value), "partial", "partial",
                "Bespoke asset: tooltip text is supplied by the consuming control. Source declaration and all call sites require surface inspection; not counted as fully explained.", [f"{path}:{lit.line}"])
            known_paths.add(value)
    for icon in icons.values():
        if icon["id"].startswith("action:element_"):
            room = icons.get("room:" + icon["id"].removeprefix("action:element_"))
            if room:
                icon["surfaces"].extend(json.loads(json.dumps(room["surfaces"])))
            use(icon, "card element crest", "partial", "no", "The element crest sits on the card; elemental token definitions are available only when present in the card's action rows.",
                [audit.ref("scripts/card_widget.gd", "func _apply_configuration_content(")], icon["current_name"])
        path = icon["art_path"].removeprefix("res://")
        icon["asset_exists"] = (ROOT / path).is_file() if path else None
        icon["visibility"] = "legacy alias; use resolved identity" if icon.get("redirects_to") else "source-backed surface uses" if icon["surfaces"] else "registered; no visible consumer identified"
        icon["surfaces"].sort(key=lambda x: x["surface"])
        # Every declared tooltip builder links to its exact templates and
        # operands, including state-specific suffixes and conditional branches.
        for use_record in icon["surfaces"]:
            templates = []
            if use_record["tooltip"] != "no":
                for location in use_record["evidence"]:
                    if not re.match(r"scripts/.+\.gd:\d+$", location): continue
                    script, line = location.rsplit(":", 1)
                    source_line = audit.sources[script].splitlines()[int(line) - 1]
                    match = re.search(r"func (\w+)\(", source_line)
                    if match:
                        templates.extend(r for r in audit.records_for(script) if r["source"].get("scope") == match[1])
            use_record["tooltip_templates"] = [dict(id=r["id"], text=r["text"], source=r["source"]) for r in templates]
        icon["meaning_without_tooltip"] = [x["surface"] for x in icon["surfaces"] if x["tooltip"] != "yes"]
    return sorted(icons.values(), key=lambda x: (0 if x["id"].startswith("relic:") else 1, x["id"]))


def glossary(audit, icons):
    entries = {}
    names = collections.defaultdict(set)
    for icon in icons:
        key = icon["concept"]
        entry = entries.setdefault(key, dict(id=key, categories=["icon concept"], names=[], definitions=[], rules_sources=[]))
        if icon["current_name"]:
            entry["names"].append(dict(text=icon["current_name"], sources=icon["sources"]))
        entry["icon_ids"] = entry.get("icon_ids", []) + [icon["id"]]
    for key, data in audit.runtime["icons"].items():
        entry = entries[key]
        entry["categories"].append("keyword")
        if key in {"bleed", "expose", "freeze", "chilled", "shock", "immobilize", "stoneskin", "block", "petrify", "anchored", "fireproof", "skate", "truesight"}: entry["categories"].append("status")
        if key in {"time", "health", "move", "card_play", "ember", "defiance", "skill_point", "moltshard"}: entry["categories"].append("resource")
        for row in audit.records:
            source = row["source"]
            # Registry definition or exact concept-bound runtime tooltip.
            if row.get("concept") == key or (source["path"] == "scripts/action_icon_library.gd" and row["text"] in [data["description"], data["label"]]):
                target = "names" if row["text"] == data["label"] else "definitions"
                entry[target].append(dict(text=row["text"], sources=[source], inventory_id=row["id"]))
        entry["rules_sources"] = sorted({x["source"] for icon in icons if icon["id"] == "action:" + key for x in icon.get("code_uses", []) if "rules.gd" in x["source"] or "combat_engine.gd" in x["source"]})
        # Definitions also occur in status overrides and mechanic-specific
        # presentation helpers. Retain all verbatim matching definition/use
        # text, with the owning source, instead of silently choosing one copy.
        aliases = [data["label"]]
        aliases += {"truesight": ["True Sight"], "freeze": ["Frozen"], "shock": ["Shocked"], "bramble": ["Bramble"], "petrify": ["Petrified"], "immobilize": ["Rooted"], "frost_armor": ["Crystal Mantle"]}.get(key, [])
        for row in audit.records:
            source = row["source"]
            scope = source.get("scope", "")
            if source["kind"] != "code" or source["path"] == "scripts/action_icon_library.gd": continue
            definition_context = re.search(r"tooltip|badge|description|detail|summary|inspection", scope) or source["path"] == "scripts/board_surface_presentation.gd"
            if not definition_context: continue
            if any(re.search(r"(?<!\w)" + re.escape(name) + r"(?!\w)", row["text"], re.I) for name in aliases if name):
                if word_count(row["text"]) > 3:
                    entry["definitions"].append(dict(text=row["text"], sources=[source], inventory_id=row["id"]))
                elif row["text"] in aliases:
                    entry["names"].append(dict(text=row["text"], sources=[source], inventory_id=row["id"]))
    for id, skill in audit.data["data/skills.json"].items():
        entry = entries[skill["icon"]]
        entry["categories"].append("skill")
        entry["definitions"].append(dict(text=skill["description"], sources=[dict(path="data/skills.json", key=pointer((id, "description")))], inventory_id="data:data/skills.json#" + pointer((id, "description"))))
    for icon in icons:
        if icon["id"].startswith("omen:"):
            id = icon["id"].split(":", 1)[1]
            entry = entries[icon["concept"]]
            entry["categories"].append("status")
            entry["definitions"].append(dict(text=audit.data["data/events.json"]["omens"][id]["description"], sources=[dict(path="data/events.json", key=pointer(("omens", id, "description")))], inventory_id="data:data/events.json#" + pointer(("omens", id, "description"))))
    grimoire = audit.data["data/grimoire.json"]
    for index, row in enumerate(grimoire.get("entries", [])):
        key = row.get("icon", str(row.get("id", "")).split(":")[-1])
        if key not in entries: entries[key] = dict(id=key, categories=[row.get("section", "concept")], names=[], definitions=[], rules_sources=[])
        entry = entries[key]
        for field in ["title", "body"]:
            values = row.get(field, []) if isinstance(row.get(field), list) else [row.get(field, "")]
            for i, value in enumerate(values):
                key_path = pointer(("entries", str(index), field, str(i))) if isinstance(row.get(field), list) else pointer(("entries", str(index), field))
                if value:
                    entry["names" if field == "title" else "definitions"].append(dict(text=value, sources=[dict(path="data/grimoire.json", key=key_path)], inventory_id="data:data/grimoire.json#" + key_path))
        entry["search_aliases"] = row.get("aliases", [])
    for key, data in audit.runtime["elements"].items():
        entries["element:" + key] = dict(id="element:" + key, categories=["element", "damage type"],
            names=[dict(text=data[k], sources=[audit.ref("scripts/element_data.gd", '"' + data[k] + '"')]) for k in ("name", "label", "short_label") if data[k]],
            definitions=[], rules_sources=[audit.ref("scripts/element_data.gd", "const ELEMENTS")])
    for key, entry in entries.items():
        for field in ("names", "definitions"):
            merged = {}
            for row in entry[field]:
                text = row["text"]
                if text not in merged: merged[text] = dict(text=text, sources=[], inventory_ids=[])
                merged[text]["sources"].extend(row.get("sources", []))
                if "inventory_id" in row: merged[text]["inventory_ids"].append(row["inventory_id"])
            entry[field] = list(merged.values())
        for name in entry["names"]: names[name["text"].casefold()].add(key)
    findings = []
    for key, entry in entries.items():
        unique = {x["text"] for x in entry["names"]}
        if len(unique) > 1:
            findings.append(dict(kind="same concept, different names", concept=key, names=sorted(unique), status="review; includes capitalization, abbreviations and broader grimoire chapter titles"))
    for name, concepts in names.items():
        if len(concepts) > 1:
            findings.append(dict(kind="same name, different concepts", name=name, concepts=sorted(concepts), status="review; registry namespaces and related element/surface concepts may intentionally share names"))
    findings.extend([
        dict(kind="definition disagrees with rules", concept="time", definition="Delays your next turn. Each unused play takes 5.",
             definition_source=audit.ref("scripts/action_icon_library.gd", "Each unused play takes 5."),
             evidence="base_plays_waited caps Wait at unused base plays; bonus/banked plays do not increase it. The tooltip says each unused play without that restriction.",
             rules_sources=[audit.ref("scripts/combat_engine.gd", "func base_plays_waited("), audit.ref("scripts/combat_engine.gd", "func pending_wait_time(")]),
        dict(kind="definition disagrees with rules", concept="chilled", definition="Takes +2 damage from attacks while on Ice. An Ice attack applies Freeze and consumes the Ice beneath the target.",
             definition_source="data/grimoire.json#" + next(r["source"]["key"] for r in audit.records_for("data/grimoire.json") if r["text"].startswith("Takes +2 damage from attacks while on Ice.")),
             evidence="Relic-applied Chilled explicitly persists without supporting Ice; direct attack damage checks chilled, not unit_on(ice).",
             rules_sources=[audit.ref("scripts/surface_variety_relic_rules.gd", 'enemy["relic_chilled"] = true'), audit.ref("scripts/board_surface_rules.gd", "static func sync_chilled("), audit.ref("scripts/combat_engine.gd", 'elif bool(enemy.get("chilled", false)):')]),
        dict(kind="same concept, different names", concept="truesight", names=["Truesight", "True Sight"],
             sources=[audit.ref("scripts/action_icon_library.gd", '"label": "Truesight"'), audit.ref("scripts/combat_board_view.gd", '"tooltip": "True Sight')]),
        dict(kind="same concept, different names", concept="bramble", names=["Thornwall", "Bramble"],
             sources=[audit.ref("scripts/action_icon_library.gd", '"label": "Thornwall"'), audit.ref("scripts/combat_board_view.gd", 'if for_text.begins_with("Bramble:")')]),
    ])
    return dict(schema_version=SCHEMA, concepts=sorted(entries.values(), key=lambda x: x["id"]), findings=findings,
                audit_scope="Verbatim definitions, source-linked naming candidates, and verified rule contradictions. No wording recommendations or claim of exhaustive semantic equivalence verification.")


CAPTURE_SPECS = [
    ("01_card_hand", ["card tooltip", "card name", "card rules"], "Live combat hand, first card hovered"),
    ("02_card_reward", ["reward screen", "card name", "card rules"], "Live card reward choices"),
    ("03_relic_choice", ["relic name", "relic description"], "Live choice hovered; absence of tooltip is asserted"),
    ("04_owned_relic", ["relic tooltip"], "Owned badge hovered; production custom tooltip embedded in SubViewport"),
    ("05_status", ["status/condition tooltip"], "Live status badge copy through production tooltip builder"),
    ("06_intent", ["intent label/tooltip", "keyword tooltip"], "Enemy intent tooltip"),
    ("07_map_node", ["map node"], "Section map node hover"),
    ("08_event", ["event title", "event body", "event choice"], "Event fixture hanged_knight"),
    ("09_shop", ["shop", "equipment"], "Scavenger inventory and item inspection"),
    ("10_chronicle", ["chronicle"], "Existing Chronicle seeded profile"),
    ("11_run_end", ["run-end recap"], "Production recap, presentation complete"),
    ("12_settings", ["menus/settings"], "Production Settings panel"),
    ("13_keyword", ["keyword tooltip", "card tooltip"], "Production keyword tooltip panel"),
    ("14_enemy", ["enemy name/tooltip"], "Production enemy inspection panel"),
    ("15_equipment", ["equipment"], "Production equipment inspection"),
    ("16_grimoire", ["grimoire"], "Grimoire definition"),
    ("17_tutorial", ["onboarding/tutorial", "dialogue"], "Initial run tutorial/dialogue"),
    ("18_confirmation", ["confirmation dialogs"], "Settings restore confirmation"),
    ("19_empty_chronicle", ["error/empty states", "chronicle"], "Empty Chronicle"),
    ("20_main_menu", ["menus/settings"], "Main menu"),
    ("21_omen", ["status/condition tooltip", "event body"], "Existing Hunted omen focus tooltip"),
    ("22_event_disabled", ["event choice", "error/empty states"], "Frozen Champion disabled choice requirement"),
    ("23_skill_tree", ["skills"], "Character skill tree and selected skill detail"),
    ("24_character", ["equipment", "HUD labels"], "Character equipment inventory"),
    ("25_campfire", ["reward screen", "HUD labels"], "Ember Hearth choices"),
    ("26_pre_battle", ["enemy name/tooltip", "equipment", "card name"], "Pre-battle report"),
    ("27_pause", ["menus/settings"], "Live pause menu"),
    ("28_item", ["card tooltip", "card rules"], "Item pickup inspection and destination"),
]


def capture_outputs(audit):
    declared_ids = [lit.text for lit in literals((ROOT / PROBE).read_text())
                    if lit.scope == "CAPTURES" and re.fullmatch(r"\d{2}_[a-z_]+", lit.text)]
    if declared_ids != [spec[0] for spec in CAPTURE_SPECS]:
        raise ValueError("Capture probe ids and inventory/proof contract have drifted")
    specs = []
    for id, surfaces, detail in CAPTURE_SPECS:
        ids = [r["id"] for r in audit.records if r["surface"] in surfaces]
        specs.append(dict(id=id, filename=id + ".png", surfaces=surfaces, inventory_ids=ids, detail=detail))
    contract = dict(min_images=len(specs), expected_sizes=["1920x1080"], required_images=[
        dict(pattern="*" + s["filename"], width=1920, height=1080,
             regions=[dict(rect=[0, 0, 1920, 1080], min_luma_range=8, min_luma_stdev=2)]) for s in specs])
    command = "cd /Users/borgerding/workspace/Labyrinth.worktrees/ux-02 && python3 tools/visual_probe_runner.py --no-headless --display-driver macos --audio-driver Dummy --timeout 180 --expect-size 1920x1080 --proof-contract tests/text_audit_capture_probe_contract.json --result-manifest /private/tmp/ux-02-text-captures.json tests/text_audit_capture_probe.gd --task-id ux-02"
    lines = ["# Capture map", "", "Renderer proof is pending the design owner: this sandbox has no window-server access. No PNG in this packet is claimed as captured or inspected.", "", "```bash", command, "```", "", "The 180-second budget covers twenty-eight sequential live scene fixtures and existing opening presentations. All captures use one fixed SubViewport at 1920×1080 and 100% UI scale. No alternate scale is introduced.", "", "Outputs: `user://probes/text_audit/1920x1080/` under the runner's unique HOME (printed by the probe). The result manifest records absolute paths. `observations.json` records visible node text and semantic assertions. The numbered PNGs are the contact set. Unchanged production custom tooltip panels are embedded in the SubViewport for the proof camera; native tooltips use embedded subwindows.", "", "The mapping below is a **surface inventory index**, not a claim that every possible variant is simultaneously visible. `capture_index.json` contains each expanded inventory-id list. Observed node text is written by the probe for exact fixture review. Each text node in `observations.json` includes every verbatim-matching inventory id; repeated copy remains a source-candidate set, and dynamic or transformed text is explicitly marked instead of guessed.", ""]
    for spec in specs:
        lines.extend([f"## {spec['filename']}", "", spec["detail"] + ".", "", "Surfaces: " + ", ".join(spec["surfaces"]) + ".", "", f"Inventory ids ({len(spec['inventory_ids'])}; expanded in `capture_index.json`):", ""])
        lines.extend("- `" + id + "`" for id in spec["inventory_ids"])
        lines.append("")
    lines += ["No inspection_fixture.py command is required by this inventory-only brief; the design owner owns playable fixture preparation.", ""]
    return specs, contract, "\n".join(lines)


def summary(audit, icons, glossary_data):
    rows = audit.records
    lines = ["# Player-facing text and tooltip audit", "", "Inventory only: game text, data, UI, analytics and saves are unchanged.", "", "## Method and coverage", "", f"{len(rows)} source/derived string records. Occurrences remain separate; generated per-card tooltip variants are counted separately from their definition templates. Code ids use file, owning scope, literal digest and duplicate ordinal, so moving a source line does not change its id. Changing copy intentionally changes a code id. Data ids use JSON pointers.", "", "The lexical scanner visits every runtime GDScript, scene, project title and data file. It excludes comments, paths, identifiers, enum keys, colors and developer diagnostics. `coverage.json` retains every exclusion, source hash and dynamic display expression for review; this is an auditable static inventory, not a proof that all branches have been rendered. Exact literal fragments and complete format expressions/operands are preserved. Runtime export invokes production helpers for card token rows, tooltip overrides, relic redirects and formatted descriptions. Unbounded state/upgrade combinations remain parameterized, with the owning code cited.", "", "Word counts ignore BBCode control tags; inline icon concepts, numeric values and format placeholders count as words. Thresholds: top 15 per surface, tooltips over 35 words, rules over 3 shaped lines. Counts are source occurrences/derived variants, not unique prose sentences.", "", "## String counts by surface", "", "| Surface | Source/derived records |", "| --- | ---: |"]
    for surface in SURFACES:
        lines.append(f"| {surface} | {sum(r['surface'] == surface for r in rows)} |")
    lines += ["", "## Owner's relic finding", "", "Relic choice icons and inline symbols have no hover/focus definitions. Owned relic badges do have a name/description tooltip; icons inside that tooltip do not have independent concept definitions. These are distinct gaps. Legacy relic entries may redirect to another relic at runtime; both raw and resolved names/art are retained.", "", "## Icons without complete tooltips by surface", "", "| Surface | No tooltip | Partial pointer/focus coverage |", "| --- | ---: | ---: |"]
    missing = collections.defaultdict(collections.Counter)
    for icon in icons:
        for use in icon["surfaces"]:
            if use["tooltip"] != "yes": missing[use["surface"]][use["tooltip"]] += 1
    for surface in sorted(missing, key=lambda s: (0 if "relic" in s else 1, s)):
        lines.append(f"| {surface} | {missing[surface]['no']} | {missing[surface]['partial']} |")
    lines += ["", "Per-icon details, tooltip text/templates, source evidence, pointer/focus differences and inventory ids are in `inventory_icons.json`. Partial is never counted as yes.", "", "## Cards exceeding three lines", "", "Measured headlessly with Godot TextParagraph and the production text font/CardWidget width and font helpers at 100%. Live RunScene helpers supply hand (3 and 8 cards), three-choice reward and equipment-tooltip sizes at 1920×1080. The base card is included for comparison. Exact sizes, font sizes, widths and all counts are in `runtime.json`. This is font/layout proof, not renderer proof. Most cards draw action-token rows instead of prose; other rows are description-fit diagnostics, not visible overflow claims. Upgrades modify action rows and do not rewrite stored prose.", "", "| Card | Base | Hand 3 | Hand 8 | Reward | Equipment tooltip | Prose on face | Inventory id |", "| --- | ---: | ---: | ---: | ---: | ---: | --- | --- |"]
    profiles = ["base", "hand_3", "hand_8", "reward_three_choices", "equipment_tooltip"]
    for id, card in sorted(audit.runtime["cards"].items(), key=lambda x: (-max(m["line_count"] for m in x[1]["measurements"].values()), x[0])):
        counts = [card["measurements"][p]["line_count"] for p in profiles]
        if max(counts) > 3:
            columns = " | ".join(str(n) for n in counts)
            lines.append(f"| {card['name']} | {columns} | {'yes' if card['face_uses_prose'] else 'no — action rows'} | `resolved:card:{id}:rules` |")
    lines += ["", "## Tooltips over 35 words", "", "| Words | Surface | Id |", "| ---: | --- | --- |"]
    for row in sorted(rows, key=lambda r: (-r["word_count"], r["id"])):
        if row["presentation"] in ("tooltip", "both") and row["word_count"] > LONG_TOOLTIP_WORDS:
            lines.append(f"| {row['word_count']} | {row['surface']} | `{row['id']}` |")
    lines += ["", "## Longest strings per surface", ""]
    for surface in SURFACES:
        lines += ["### " + surface, "", "| Words | Id | Current text |", "| ---: | --- | --- |"]
        for row in sorted([r for r in rows if r["surface"] == surface], key=lambda r: (-r["word_count"], r["id"]))[:LONGEST_PER_SURFACE]:
            text = row["text"].replace("|", "\\|").replace("\n", "<br>")
            lines.append(f"| {row['word_count']} | `{row['id']}` | {text} |")
        lines.append("")
    lines += ["## Glossary findings", "", "`glossary_seed.json` retains verbatim source-linked definitions, aliases and naming candidates. Confirmed rules discrepancies: Time's ‘each unused play’ omits the base-play cap; the Grimoire's Chilled definition requires Ice although relic Chilled persists off Ice. No text has been corrected.", "", "## Proof and limitations", "", "Run `python3 tools/text_audit.py --check` to re-export production data and compare every generated artifact without writing. Run `--self-test` for scanner/source tests. Headless fixture validation and exact windowed command are documented in `captures.md`. Renderer capture and independent visual inspection remain with the design owner.", "", "No TODO_DESIGN placeholders: this audit introduces no player-visible decisions. Chosen defaults are tool-only: export timeout 180 s, 12-character source digests, probe seed 321; shop fixture seed 73491/720 Embers and existing stock; 2 Bleed stacks; the named production hand/relic fixtures; measurement hands of 3/8 cards; disabled-event Embers 0; 600 readiness frames; 5 settling frames; 1.2 s presentation wait; 0.6 s native-tooltip wait; 0.025 s treasure polling; manual tooltip anchor (1200,350), 24 px margin and z-order 4095. No production values change.", ""]
    return "\n".join(lines)


def outputs(audit):
    audit.extract()
    audit.verify_sources()
    icons = build_icons(audit)
    glossary_data = glossary(audit, icons)
    specs, contract, captures = capture_outputs(audit)
    dynamic = []
    for path, source in audit.sources.items():
        if path.endswith(".gd"):
            for n, line in enumerate(source.splitlines(), 1):
                if re.search(r"(?:\.text\s*[+]?=|\.tooltip_text\s*[+]?=|draw_string\(|InlineIconText.apply_to\()", line):
                    dynamic.append(dict(source=f"{path}:{n}", expression=line.strip()))
    coverage = dict(schema_version=SCHEMA, files={p: hashlib.sha256(s.encode()).hexdigest() for p, s in audit.sources.items()},
                    included=len(audit.records), excluded_literals=audit.excluded, dynamic_display_expressions=dynamic,
                    known_limitations=["Static reachability is conservative; source fallbacks and inactive legacy data remain visible for review.",
                                       "Unbounded gameplay and upgrade values are parameterized, not exhaustively enumerated.",
                                       "No windowed captures available in implementation sandbox."])
    stream = io.StringIO(newline="")
    fields = ["id", "surface", "source", "text", "word_count", "parameters", "numbers", "where_shown", "presentation"]
    writer = csv.DictWriter(stream, fieldnames=fields, extrasaction="ignore", lineterminator="\n")
    writer.writeheader()
    for row in audit.records:
        writer.writerow({k: json.dumps(row[k], ensure_ascii=False, sort_keys=True) if isinstance(row[k], (dict, list)) else row[k] for k in fields})
    return {OUT / "inventory.json": dump(dict(schema_version=SCHEMA, strings=audit.records)), OUT / "inventory.csv": stream.getvalue(),
            OUT / "inventory_icons.json": dump(dict(schema_version=SCHEMA, icons=icons)), OUT / "glossary_seed.json": dump(glossary_data),
            OUT / "runtime.json": dump(audit.runtime), OUT / "coverage.json": dump(coverage), OUT / "capture_index.json": dump(specs),
            OUT / "captures.md": captures, OUT / "summary.md": summary(audit, icons, glossary_data),
            ROOT / "tests/text_audit_capture_probe_contract.json": dump(contract)}


class AuditTests(unittest.TestCase):
    def test_lexing_comments_escapes_and_multiline(self):
        source = '# "ignored"\nfunc sample():\n\tvar x = "a\\n\\\"b" # "ignored"\n\tvar y = """two\nlines"""\n'
        actual = list(literals(source))
        self.assertEqual([x.text for x in actual], ['a\n"b', 'two\nlines'])
        self.assertEqual([x.line for x in actual], [3, 4])
        self.assertEqual([x.scope for x in actual], ['sample', 'sample'])
    def test_raw_unicode_and_single_quotes(self):
        self.assertEqual(decode_string('r"a\\n"'), 'a\\n')
        self.assertEqual(decode_string('"a\\u00a0b"'), 'a\u00a0b')
        self.assertEqual(decode_string("'Don\\'t'"), "Don't")
    def test_nested_pointer_roundtrip(self):
        data = {"a/b": {"~x": ["text"]}}
        self.assertEqual(at_pointer(data, pointer(("a/b", "~x", "0"))), "text")
    def test_word_count_preserves_icons_formats_markup(self):
        self.assertEqual(word_count('[b]Gain[/b] %d @icon(block).'), 3)
        self.assertEqual(word_count('Gain {amount} @icon(surface_ice).'), 4)
    def test_classification_keys_vs_copy(self):
        source = 'func f():\n\tvar x = {"name": "Ice Blade", "path": "res://icon.png"}\n'
        values = [(x.text, inclusion(x, source, "scripts/test.gd")) for x in literals(source)]
        self.assertEqual(values, [("name", "dictionary/match key"), ("Ice Blade", None), ("path", "dictionary/match key"), ("res://icon.png", "resource/address")])
    def test_ids_do_not_use_lines(self):
        source = 'func sample():\n\tlabel.text = "Hello"\n'
        a = next(literals(source)); b = next(literals('\n\n' + source))
        self.assertEqual((a.scope, digest(a.text)), (b.scope, digest(b.text)))
        self.assertNotEqual(a.line, b.line)
    def test_surface_precedence(self):
        self.assertEqual(code_surface("scripts/settings_panel.gd", "_restore_confirmation", "", "Restore?"), "confirmation dialogs")
        self.assertEqual(data_surface("data/enemies.json", ("enemies", "bat", "intents", "0", "name")), "intent label/tooltip")
    def test_stale_source_rejected(self):
        audit = Audit({})
        audit.sources = {"data/cards.json": "{}"}; audit.data = {"data/cards.json": {"a": "changed"}}
        audit.record("x", "card name", "old", dict(kind="data", path="data/cards.json", key="/a"), [])
        with self.assertRaisesRegex(ValueError, "Stale data source"): audit.verify_sources()
    def test_internal_formats_are_not_copy(self):
        source = 'func _refresh_hand_panel():\n\tvar key = "card|%s|%d"\n\tlabel.text = "HP %d/%d"\n'
        values = list(literals(source))
        self.assertEqual(inclusion(values[0], source, "scripts/run_scene.gd"), "packed internal key")
        self.assertIsNone(inclusion(values[1], source, "scripts/run_scene.gd"))
    def test_multiline_format_operands_are_preserved(self):
        source = 'func f():\n\tlabel.text = "%s: %d" % [\n\t\tname,\n\t\tcount\n\t]\n'
        value = next(literals(source))
        self.assertIn("name,", value.expression)
        self.assertIn("count", value.expression)
    def test_inline_icon_count_uses_current_display_name(self):
        self.assertEqual(word_count("Gain @icon(surface_ice).", {"surface_ice": "Ice"}), 2)
    def test_unknown_icon_rejected(self):
        audit = Audit({"icons": {}})
        audit.sources = {"data/cards.json": "{}"}
        audit.data = {"data/cards.json": {"a": "Gain @icon(missing)."}}
        audit.record("x", "card rules", "Gain @icon(missing).", dict(kind="data", path="data/cards.json", key="/a"), [])
        with self.assertRaisesRegex(ValueError, "Unknown inline icon"): audit.verify_sources()


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="reconstruct from tree; compare without modifying outputs")
    parser.add_argument("--self-test", action="store_true", help="run focused scanner/source integrity tests")
    args = parser.parse_args(argv)
    if args.self_test:
        result = unittest.TextTestRunner(verbosity=2).run(unittest.defaultTestLoader.loadTestsFromTestCase(AuditTests))
        print("TEXT AUDIT SELF-TEST RESULT: " + ("PASS" if result.wasSuccessful() else "FAIL"))
        return 0 if result.wasSuccessful() else 1
    try:
        audit = Audit(runtime_export())
        artifacts = outputs(audit)
        drift = []
        for path, content in artifacts.items():
            if args.check:
                if not path.is_file() or path.read_text() != content: drift.append(str(path.relative_to(ROOT)))
            else:
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text(content)
        if drift:
            print("TEXT AUDIT CHECK RESULT: FAIL (stale/missing outputs)")
            print("\n".join(drift))
            return 1
        print(f"TEXT AUDIT {'CHECK' if args.check else 'BUILD'} RESULT: PASS ({len(audit.records)} strings; {len(artifacts)} artifacts; unknown sources: 0)")
        return 0
    except (ValueError, KeyError, OSError, subprocess.TimeoutExpired) as exc:
        print("TEXT AUDIT RESULT: FAIL\n" + str(exc), file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
