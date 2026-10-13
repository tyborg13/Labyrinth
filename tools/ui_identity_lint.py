#!/usr/bin/env python3
"""Count UI construction drift without requiring a GDScript parser or renderer."""
from __future__ import annotations

import argparse
import ast
import bisect
import colorsys
import json
import math
import re
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Iterator, Optional


REPO_ROOT = Path(__file__).resolve().parents[1]
BASELINE_PATH = Path("spec/ui_identity/baseline.json")
EXCEPTIONS_PATH = Path("spec/ui_identity/exceptions.json")
TOP_FILE_LIMIT = 15
RULES = {
    "R1": ("raw box", "UiSkin / UiComponentSurface.draw_plate"),
    "R2": ("colour literal", "Palette token"),
    "R3": ("outline box", "GildedFrame.draw_panel or a painted frame"),
    "R4": ("bare bar", "the painted frame overlay used by unit bars"),
    "R5": ("ad-hoc font", "UiTypography"),
    "R6": ("tiny caption", "the type scale in ui_typography.gd"),
}
RULE_ALLOWLISTS = {
    "R1": frozenset({
        "scripts/ui_skin.gd",  # Shared skin owns the raw engine styles.
        "scripts/ui_tooltip_panel.gd",  # Shared tooltip material owns its backing.
        "scripts/ui_component_surface.gd",  # Shared plates own their construction.
        "scripts/ui_socket.gd",  # Shared sockets own their engine styles.
        "scripts/ui_card_strip.gd",  # Shared strips own their finish styles.
    }),
    "R2": frozenset({
        "scripts/ui_palette.gd",  # The palette defines the authored colour tokens.
    }),
    "R3": frozenset({
        "scripts/ui_gilded_frame.gd",  # Gilded frames own the shared hairlines.
        "scripts/ui_component_surface.gd",  # Shared surfaces own their borders.
    }),
    "R4": frozenset({
        "scripts/segmented_health_bar.gd",  # The shared bar owns its implementation.
    }),
    "R5": frozenset({
        "scripts/ui_typography.gd",  # Typography owns font loading and variations.
        "scripts/asset_loader.gd",  # The resource loader owns loading fallbacks.
    }),
    "R6": frozenset(),  # The caption floor has no file exemptions.
}

# Mask comments/strings before searching code, preserving offsets and newlines.
# String arguments are inspected only by the Color and font-load call rules.
LEXEMES = re.compile(
    r'"""(?:\\.|(?!""").)*"""|\'\'\'(?:\\.|(?!\'\'\').)*\'\'\''
    r'|"(?:\\.|[^"\\])*"|\'(?:\\.|[^\'\\])*\'|#[^\n]*',
    re.DOTALL,
)
RESOURCE_LEXEMES = re.compile(LEXEMES.pattern + r"|;[^\n]*", re.DOTALL)
NUMBER = re.compile(
    r"[+-]?(?:0[xX][0-9a-fA-F_]+|0[bB][01_]+|"
    r"(?:\d[\d_]*(?:\.[\d_]*)?|\.[\d_]+)(?:[eE][+-]?\d[\d_]*)?)\Z"
)
INTEGER = re.compile(r"[+-]?(?:0[xX][0-9a-fA-F_]+|0[bB][01_]+|\d[\d_]*)\Z")
FONT_ASSIGNMENT = re.compile(
    r"(?<!\w)(?:font_size|[A-Za-z_]\w*_font_size)\s*"
    r"(?::\s*[A-Za-z_][\w.\[\]]*\s*)?(?::=|=(?!=))\s*"
    r"(?P<size>[+-]?(?:0[xX][0-9a-fA-F_]+|0[bB][01_]+|\d[\d_]*))"
    r"[ \t]*(?=;|$)",
    re.MULTILINE | re.IGNORECASE,
)


@dataclass(frozen=True)
class Argument:
    text: str


@dataclass(frozen=True)
class Call:
    name: str
    offset: int
    arguments: list[Argument]


class Source:
    def __init__(self, text: str, resource: bool = False) -> None:
        self.text = text
        self.newlines = [i for i, char in enumerate(text) if char == "\n"]
        clean = list(text)
        code = list(text)
        lexemes = RESOURCE_LEXEMES if resource else LEXEMES
        for match in lexemes.finditer(text):
            is_comment = match.group().startswith(("#", ";"))
            for i in range(match.start(), match.end()):
                if text[i] != "\n":
                    code[i] = " " if is_comment else "~"
                    if is_comment:
                        clean[i] = " "
        self.clean = "".join(clean)
        self.code = "".join(code)

    def line(self, offset: int) -> int:
        return bisect.bisect_left(self.newlines, offset) + 1

    def calls(self, names: str) -> Iterator[Call]:
        pattern = re.compile(r"(?<!\w)(?P<name>" + names + r")\s*\(")
        for match in pattern.finditer(self.code):
            line_start = self.code.rfind("\n", 0, match.start()) + 1
            if re.search(r"\bfunc\s+$", self.code[line_start:match.start()]):
                continue
            start = match.end()
            depth = 1
            end = start
            while end < len(self.code) and depth:
                if self.code[end] == "(":
                    depth += 1
                elif self.code[end] == ")":
                    depth -= 1
                end += 1
            if depth:
                continue  # An incomplete call must not prevent scanning later code.
            yield Call(match.group("name"), match.start(), self._arguments(start, end - 1))

    def _arguments(self, start: int, end: int) -> list[Argument]:
        result = []
        depth = 0
        argument_start = start
        for offset in range(start, end):
            char = self.code[offset]
            if char in "([{":
                depth += 1
            elif char in ")]}":
                depth -= 1
            elif char == "," and depth == 0:
                result.append(Argument(self.clean[argument_start:offset].strip()))
                argument_start = offset + 1
        tail = self.clean[argument_start:end].strip()
        if tail:
            result.append(Argument(tail))
        return result


def _string(text: str) -> Optional[str]:
    if not text.startswith(('"', "'")):
        return None
    try:
        value = ast.literal_eval(text)
    except (ValueError, SyntaxError):
        return None
    return value if isinstance(value, str) else None


def _number(text: str) -> Optional[float]:
    if not NUMBER.fullmatch(text):
        return None
    text = text.replace("_", "")
    if text.lstrip("+-").lower().startswith(("0x", "0b")):
        return float(int(text, 0))
    return float(text)


def _integer(text: str) -> Optional[int]:
    if not INTEGER.fullmatch(text):
        return None
    text = text.replace("_", "")
    base = 0 if text.lstrip("+-").lower().startswith(("0x", "0b")) else 10
    return int(text, base)


def _hex_rgba(text: str) -> Optional[str]:
    value = text.lstrip("#").lower()
    if not re.fullmatch(r"[0-9a-f]{3}|[0-9a-f]{4}|[0-9a-f]{6}|[0-9a-f]{8}", value):
        return None
    if len(value) in (3, 4):
        value = "".join(char * 2 for char in value)
    return value + "ff" if len(value) == 6 else value


def _colour(call: Call) -> tuple[bool, Optional[str]]:
    args = [arg.text for arg in call.arguments]
    name = re.sub(r"\s", "", call.name)
    if name == "Color" and len(args) == 1:
        value = _string(args[0])
        return (True, _hex_rgba(value)) if value is not None else (False, None)
    if len(args) not in (3, 4):
        return False, None
    values = [_number(arg) for arg in args]
    # Any alpha expression is allowed for the two neutral modulates; nested
    # colour literals in that expression still get their own sites.
    if name == "Color" and len(args) == 4 and values[:3] in ([1.0] * 3, [0.0] * 3):
        return False, None
    if any(value is None for value in values):
        return False, None
    channels = [float(value) for value in values if value is not None]
    if name == "Color8":
        channels = [value / 255.0 for value in channels]
    elif name == "Color.from_hsv":
        channels[:3] = colorsys.hsv_to_rgb(*channels[:3])
    elif name == "Color.from_hsl":
        channels[:3] = colorsys.hls_to_rgb(channels[0], channels[2], channels[1])
    if len(channels) == 3:
        channels.append(1.0)
    if any(not math.isfinite(value) or not 0.0 <= value <= 1.0 for value in channels):
        return True, None
    return True, "".join(f"{int(value * 255.0 + 0.5):02x}" for value in channels)


def palette_tokens(root: Path) -> dict[str, list[str]]:
    path = root / "scripts/ui_palette.gd"
    if not path.is_file():
        return {}
    source = Source(path.read_text(encoding="utf-8"))
    tokens: dict[str, list[str]] = {}
    for call in source.calls(r"Color"):
        line_start = source.code.rfind("\n", 0, call.offset) + 1
        declaration = re.search(r"\bconst\s+(\w+)\s*(?::\s*Color\s*)?(?::=|=)\s*$",
                                source.code[line_start:call.offset])
        _, value = _colour(call)
        if declaration and value:
            tokens.setdefault(value, []).append(declaration.group(1))
    return {value: sorted(names) for value, names in sorted(tokens.items())}


def scan_source(path: str, text: str, tokens: Optional[dict[str, list[str]]] = None) -> dict:
    source = Source(text, resource=not path.endswith(".gd"))
    sites: list[dict] = []
    matches: list[dict] = []

    def add(rule: str, offset: int) -> None:
        if path not in RULE_ALLOWLISTS[rule]:
            sites.append({"file": path, "line": source.line(offset), "rule": rule})

    for call in source.calls(r"StyleBoxFlat\s*\.\s*new"):
        if not call.arguments:
            add("R1", call.offset)
    if not path.endswith(".gd"):
        # Serialized StyleBoxFlat definitions are the resource equivalent of
        # .new(). External references and resource IDs do not construct a box.
        for header in re.finditer(r"^[ \t]*\[(?:sub_resource|gd_resource)\b[^\]]*\]",
                                  source.code, re.MULTILINE):
            for attribute in re.finditer(r"\btype\s*=\s*(?P<value>~+)", header.group()):
                start = header.start() + attribute.start("value")
                end = header.start() + attribute.end("value")
                if _string(source.clean[start:end]) == "StyleBoxFlat":
                    add("R1", header.start())
                    break
        sites.sort(key=lambda site: (site["line"], site["rule"]))
        return {"sites": sites, "palette_matches": matches}
    for call in source.calls(r"Color\s*\.\s*from_h(?:sv|sl)|Color8|Color"):
        literal, value = _colour(call)
        if literal and path not in RULE_ALLOWLISTS["R2"]:
            add("R2", call.offset)
            if tokens and value in tokens:
                matches.append({"file": path, "hex": value, "line": source.line(call.offset),
                                "tokens": tokens[value]})
    for call in source.calls(r"draw_rect"):
        if len(call.arguments) >= 3 and call.arguments[2].text == "false":
            add("R3", call.offset)
    for call in source.calls(r"SegmentedHealthBar\s*\.\s*draw_bar"):
        add("R4", call.offset)
    for call in source.calls(r"FontVariation\s*\.\s*new|get_theme_default_font|preload|load"):
        name = re.sub(r"\s", "", call.name)
        if name in ("load", "preload"):
            resource = _string(call.arguments[0].text) if call.arguments else None
            if not resource or not resource.startswith("res://fonts/"):
                continue
        add("R5", call.offset)
    for call in source.calls(r"draw_multiline_string|draw_string|add_theme_font_size_override"):
        index = 1 if call.name == "add_theme_font_size_override" else 5
        if len(call.arguments) > index:
            size = _integer(call.arguments[index].text)
            if size is not None and size < 14:
                add("R6", call.offset)
    for match in FONT_ASSIGNMENT.finditer(source.code):
        size = _integer(match.group("size"))
        if size is not None and size < 14:
            add("R6", match.start())
    return {"sites": sorted(sites, key=lambda site: (site["line"], site["rule"])),
            "palette_matches": matches}


def scan(root: Path) -> dict:
    tokens = palette_tokens(root)
    paths = set((root / "scripts").rglob("*.gd"))
    paths.update((root / "scenes").rglob("*.tscn"))
    paths.update((root / "themes").rglob("*.tres"))
    sites = []
    matches = []
    counts: dict[str, dict[str, int]] = {}
    for path in sorted(paths):
        relative = path.relative_to(root).as_posix()
        result = scan_source(relative, path.read_text(encoding="utf-8"), tokens)
        sites.extend(result["sites"])
        matches.extend(result["palette_matches"])
        for site in result["sites"]:
            rules = counts.setdefault(relative, {})
            rules[site["rule"]] = rules.get(site["rule"], 0) + 1
    totals = {rule: sum(rules.get(rule, 0) for rules in counts.values()) for rule in RULES}
    top_files = {
        rule: [{"file": path, "count": rules[rule]} for path, rules in
               sorted(counts.items(), key=lambda item: (-item[1].get(rule, 0), item[0]))
               if rules.get(rule, 0)][:TOP_FILE_LIMIT]
        for rule in RULES
    }
    return {"counts": counts, "palette_matches": matches, "sites": sites,
            "top_files": top_files, "totals": totals}


def _valid_path(path: object) -> bool:
    return (isinstance(path, str) and bool(path) and not Path(path).is_absolute()
            and ".." not in Path(path).parts and "\\" not in path)


def read_baseline(path: Path) -> dict[str, dict[str, int]]:
    payload = json.loads(path.read_text(encoding="utf-8"))
    if (not isinstance(payload, dict) or type(payload.get("version")) is not int
            or payload["version"] != 1 or not isinstance(payload.get("counts"), dict)):
        raise ValueError("baseline must contain version 1 and a counts object")
    counts = payload["counts"]
    for file, rules in counts.items():
        if not _valid_path(file) or not isinstance(rules, dict):
            raise ValueError("invalid baseline file: " + str(file))
        for rule, count in rules.items():
            if rule not in RULES or type(count) is not int or count < 0:
                raise ValueError(f"invalid baseline count: {file} {rule}")
    return counts


def read_exceptions(path: Path) -> dict[str, dict[str, int]]:
    payload = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(payload, list):
        raise ValueError("exceptions must be a list of director-signed entries")
    counts: dict[str, dict[str, int]] = {}
    for entry in payload:
        if not isinstance(entry, dict):
            raise ValueError("exception must be an object")
        file, rule, count, reason = (entry.get(key) for key in ("file", "rule", "count", "reason"))
        if (not _valid_path(file) or not isinstance(rule, str) or rule not in RULES
                or type(count) is not int or count <= 0 or not isinstance(reason, str) or not reason.strip()):
            raise ValueError("exception requires file, rule, positive count and director reason")
        rules = counts.setdefault(file, {})
        rules[rule] = rules.get(rule, 0) + count
    return counts


def write_baseline(path: Path, counts: dict[str, dict[str, int]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps({"counts": counts, "version": 1}, indent=2, sort_keys=True) + "\n",
                    encoding="utf-8")


def tighten(baseline: dict[str, dict[str, int]], counts: dict[str, dict[str, int]]) -> dict[str, dict[str, int]]:
    result = {}
    for file, rules in sorted(baseline.items()):
        lowered = {rule: min(count, counts.get(file, {}).get(rule, 0))
                   for rule, count in sorted(rules.items())}
        lowered = {rule: count for rule, count in lowered.items() if count > 0}
        if lowered:
            result[file] = lowered
    return result


def check(result: dict, baseline: dict[str, dict[str, int]], exceptions: dict[str, dict[str, int]]) -> bool:
    increases = {}
    for file, rules in sorted(result["counts"].items()):
        for rule, count in sorted(rules.items()):
            original = baseline.get(file, {}).get(rule, 0)
            allowed = exceptions.get(file, {}).get(rule, 0)
            if count > original + allowed:
                increases[(file, rule)] = (count, original, allowed)
    if increases:
        print(f"FAIL: UI identity lint ({len(increases)} file/rule counts above baseline + exceptions)")
        # Counts alone cannot identify which site was added, so show every
        # current site in the offending pair, including insertions at its start.
        for site in result["sites"]:
            key = (site["file"], site["rule"])
            if key in increases:
                count, original, allowed = increases[key]
                name, helper = RULES[site["rule"]]
                print(f"{site['file']}:{site['line']}: {site['rule']} {name} "
                      f"({count} > baseline {original} + exceptions {allowed}); use {helper}")
        return False
    print(f"PASS: UI identity lint ({len(result['sites'])} sites within baseline + exceptions)")
    if tighten(baseline, result["counts"]) != baseline:
        print("Counts dropped; run python3 tools/ui_identity_lint.py --tighten")
    return True


def main(argv: Optional[list[str]] = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("command", nargs="?", choices=("scan", "check"), default="scan")
    parser.add_argument("--root", type=Path, default=REPO_ROOT, help="repository root (also supports temporary copies)")
    parser.add_argument("--json", action="store_true", help="emit the scan, all sites, totals and top 15 files per rule")
    actions = parser.add_mutually_exclusive_group()
    actions.add_argument("--write-baseline", action="store_true")
    actions.add_argument("--tighten", action="store_true")
    parser.add_argument("--force", action="store_true", help="replace an existing baseline with --write-baseline")
    args = parser.parse_args(argv)
    if args.force and not args.write_baseline:
        parser.error("--force requires --write-baseline")
    if args.command == "check" and (args.write_baseline or args.tighten or args.json):
        parser.error("check cannot be combined with baseline actions or --json")
    if args.json and (args.write_baseline or args.tighten):
        parser.error("--json is for scan only")
    try:
        baseline_path = args.root / BASELINE_PATH
        if args.write_baseline and baseline_path.exists() and not args.force:
            raise ValueError(f"baseline exists: {BASELINE_PATH}; use --force only for an authorized reset")
        result = scan(args.root)
        if args.write_baseline:
            write_baseline(baseline_path, result["counts"])
            print(f"WROTE: {BASELINE_PATH} ({len(result['sites'])} sites)")
        elif args.tighten:
            baseline = read_baseline(baseline_path)
            lowered = tighten(baseline, result["counts"])
            write_baseline(baseline_path, lowered)
            print(f"TIGHTENED: {BASELINE_PATH} (counts never raised)")
        elif args.command == "check":
            return 0 if check(result, read_baseline(baseline_path), read_exceptions(args.root / EXCEPTIONS_PATH)) else 1
        elif args.json:
            print(json.dumps(result, indent=2, sort_keys=True))
        else:
            for rule, total in result["totals"].items():
                print(f"{rule} {RULES[rule][0]}: {total}")
            for site in result["sites"]:
                print(f"{site['file']}:{site['line']}: {site['rule']} {RULES[site['rule']][0]}")
            for match in result["palette_matches"]:
                print(f"{match['file']}:{match['line']}: INFO palette #{match['hex']} = "
                      + ", ".join("Palette." + token for token in match["tokens"]))
        return 0
    except (OSError, ValueError) as error:
        print(f"ERROR: UI identity lint: {error}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main())
