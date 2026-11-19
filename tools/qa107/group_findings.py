#!/usr/bin/env python3
"""Group headless layout witnesses for triage. The native capture remains the visual check."""

from __future__ import annotations

import argparse
import json
from collections import Counter, defaultdict
from pathlib import Path


TITLE_LAYERS = {"Title", "TitleFaceBlend", "TitleRim", "TitleShadow"}


def is_title_layer(path: str) -> bool:
    return path.split("/", 1)[0] in TITLE_LAYERS


def is_map_node(path: str) -> bool:
    return "/MapWorld/RoomNodes/" in path


def dismissal(row: dict) -> str | None:
    path = row["path"]
    check = row["check"]
    if check == "overlap":
        other = row["other"]["path"]
        if is_title_layer(path) and is_title_layer(other):
            return "layered title lettering"
        if ("/TitleGlow/GlowRadius" in path or "/TitleGlow/GlowRadius" in other) and row.get("text") == row["other"].get("text"):
            return "run-end title glow copies"
        if is_map_node(path) and is_map_node(other):
            return "rectangular envelopes of circular map nodes"
    if check == "outside_viewport":
        if path.startswith("BoardUnderlay/"):
            return "panned board render layers"
        if "/MapWorld/" in path:
            return "panned map contents"
        if path == "ProfileBlock" and not row.get("text"):
            return "title profile layout host"
    if check == "missing_texture" and path.endswith("/CloseCharacterOverlay/Icon"):
        return "drawn Character close glyph"
    if check == "text_overrun" and path.endswith("/ScoreDetail") and row.get("overrun"):
        return "recap score detail has an authored ellipsis and full tooltip"
    return None


def severity(row: dict) -> str:
    check = row["check"]
    if row.get("text"):
        if check in {"text_overrun", "button_label_overflow", "wrapped_word_overrun", "rich_text_width"}:
            if row["available"][0] < 0.1 * row["width"]:
                return "S1"
        if check in {"outside_viewport", "ancestor_clip"}:
            x, y, w, h = row["rect"]
            left, top, width, height = row["limit"]
            if x + w <= left or x >= left + width or y + h <= top or y >= top + height:
                return "S1"
        if check != "overlap" or row.get("other", {}).get("text"):
            return "S2"
    if check == "missing_texture" and row["texture"] != "null":
        return "S2"
    return "S3"


def group(inputs: list[Path]) -> dict:
    groups: dict[tuple, list[dict]] = defaultdict(list)
    suppressed: Counter[str] = Counter()
    coverage: dict[str, list[dict]] = {}
    for path in inputs:
        coverage_rows: list[dict] = []
        profile = ""
        with path.open(encoding="utf-8") as witness:
            for line in witness:
                record = json.loads(line)
                if record["kind"] == "viewport":
                    profile = record["profile"]
                    coverage_rows.append(record)
                elif record["kind"] in {"hover_coverage", "summary"}:
                    coverage_rows.append(record)
                elif record["kind"] == "snapshot":
                    for row in record["findings"]:
                        reason = dismissal(row)
                        if reason is not None:
                            suppressed[reason] += 1
                            continue
                        paths = tuple(sorted([row["path"], row["other"]["path"]])) if row["check"] == "overlap" else (row["path"],)
                        key = (record["state"], paths, row["check"])
                        groups[key].append({"profile": profile, "hover": record["hover"], "source": record["source"], **row})
        if not coverage_rows or coverage_rows[-1]["kind"] != "summary":
            raise ValueError(f"{path} has no sweep summary")
        coverage.setdefault(profile, []).extend(coverage_rows)
    findings = [
        {"candidate_rank": min(map(severity, witnesses)), "state": state, "paths": paths,
         "check": check, "witnesses": witnesses}
        for (state, paths, check), witnesses in groups.items()
    ]
    findings.sort(key=lambda row: (row["candidate_rank"], row["state"], row["paths"], row["check"]))
    return {
        "coverage": coverage,
        "suppressed_candidate_rows": dict(sorted(suppressed.items())),
        "groups": findings,
    }


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("witness", type=Path, nargs="+")
    args = parser.parse_args()
    print(json.dumps(group(args.witness), indent=2))


if __name__ == "__main__":
    main()
