"""Render the layout observations from one or more scn-01 manifests."""

from __future__ import annotations

from collections import Counter
import json
from pathlib import Path


REPORT_DIR = Path(__file__).resolve().parent
COMBAT_STATES = {
    "default", "hover", "keyword", "aim", "enemy_turn",
    "enemy_hover", "rail_hover", "pass_hover", "details", "push",
}


def hit_key(row: dict) -> str:
    return json.dumps({key: value for key, value in row.items() if key != "shot"}, sort_keys=True)


def sorted_hits(rows: list[dict]) -> list[dict]:
    return sorted(rows, key=lambda row: (-row["severity"], row["kind"], row["node"], hit_key(row)))


def manifest_report(path: Path) -> dict:
    manifest = json.loads(path.read_text(encoding="utf-8"))
    shots = [
        {
            **{key: row.get(key) for key in (
                "shot", "scenario", "state", "mode", "ok", "error", "capped", "capture", "planned_png",
            )},
            "layout_hits": sorted_hits(row["layout_hits"]),
        }
        for row in manifest["shots"]
    ]
    counts = Counter(hit["kind"] for row in shots for hit in row["layout_hits"])
    combat = [
        row for row in shots
        if row["state"] in COMBAT_STATES and (
            row["mode"] == "combat" or (row["mode"] is None and row["scenario"] == "combat")
        )
    ]
    shared: list[dict] = []
    if len(combat) >= 2 and all(row["ok"] for row in combat):
        common = set.intersection(*(set(map(hit_key, row["layout_hits"])) for row in combat))
        shared = sorted_hits([{
            **json.loads(key), "shots": [row["shot"] for row in combat],
        } for key in common])
        for row in combat:
            row["layout_hits"] = [hit for hit in row["layout_hits"] if hit_key(hit) not in common]
    return {
        **{key: manifest.get(key) for key in ("size", "dry_run", "elapsed_seconds", "error")},
        "manifest": str(path),
        "layout_hit_counts": dict(sorted(counts.items())),
        "shared_combat_hits": shared,
        "shots": shots,
        "unreached": [{"shot": row["shot"], "reason": row["error"]} for row in shots if not row["ok"]],
    }


def inline(value: object) -> str:
    return json.dumps(value, ensure_ascii=False, separators=(", ", ": "))


def hits_table(lines: list[str], hits: list[dict]) -> None:
    if not hits:
        lines.extend(["No layout hits.", ""])
        return
    lines.extend([
        "| Check | Node path | Rect | Size | Measurement |",
        "| --- | --- | --- | --- | --- |",
    ])
    for hit in hits:
        measurement = inline(hit["measured"]).replace("|", "&#124;")
        lines.append(
            f'| {hit["kind"]} | `{hit["node"]}` | `{inline(hit["rect"])}` | '
            f'`{inline(hit["size"])}` | `{measurement}` |'
        )
    lines.append("")


def render_markdown(runs: list[dict]) -> str:
    lines = [
        "# Candidate 4 screen census",
        "",
        "The probe measures Controls at 100% UI scale. Rectangles are `[x, y, width, height]` "
        "in capture pixels. Edge distances are left, top, right, bottom. Text measurements "
        "marked `local_px` are in the control’s coordinate space. Overlap is measured "
        "between visible Control regions after viewport and parent clipping. Popup coverage "
        "is exempt. Partially clipped scroll content can appear in the results.",
        "",
    ]
    for run in runs:
        shots = run["shots"]
        passed = sum(row["ok"] for row in shots)
        elapsed = f' in {run["elapsed_seconds"]:.1f} s' if run["elapsed_seconds"] is not None else ""
        mode = "headless" if run["dry_run"] else "native"
        lines.extend([
            f'## {run["size"]} · {mode}', "",
            f'{passed}/{len(shots)} shots reached{elapsed}. '
            f'{sum(bool(row["capped"]) for row in shots)} settle caps. '
            f'[Run manifest]({run["manifest"]})', "",
        ])
        if run["error"]:
            lines.extend([run["error"], ""])
            continue
        counts = run["layout_hit_counts"]
        if counts:
            lines.extend(["Layout hits by check", "", *[f"- `{kind}` · {count}" for kind, count in counts.items()], ""])
        lines.extend(["### Layout hits shared by every combat shot", ""])
        hits_table(lines, run["shared_combat_hits"])
        for row in shots:
            lines.extend([f'### `{row["shot"]}`', ""])
            if not row["ok"]:
                lines.extend(["See the unreached list below.", ""])
                continue
            if row["capture"]:
                path = Path(row["capture"])
                lines.extend([f'[{path.name}]({path})', ""])
            else:
                lines.extend([f'Planned capture `{Path(row["planned_png"]).name}`.', ""])
            hits_table(lines, row["layout_hits"])
        lines.extend(["### Unreached", ""])
        for row in run["unreached"]:
            lines.append(f'- `{row["shot"]}` · {row["reason"]}')
        if not run["unreached"]:
            lines.append("All selected states were reached.")
        lines.append("")
    return "\n".join(lines)


def write_reports(manifests: list[Path], out: Path = REPORT_DIR) -> None:
    runs = [manifest_report(path.resolve()) for path in manifests]
    out.mkdir(parents=True, exist_ok=True)
    (out / "census.json").write_text(json.dumps({"runs": runs}, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    (out / "census.md").write_text(render_markdown(runs), encoding="utf-8")
    print(f"Layout reports: {out / 'census.md'} and {out / 'census.json'}")
