#!/usr/bin/env python3
"""Print the Steamworks play-stat schema or a Markdown report."""

from __future__ import annotations

import argparse
import csv
import datetime as dt
import io
import json
import os
import subprocess
import sys
from pathlib import Path

from steam_performance_stats import PUBLISHER_KEY_ENV, REPO_ROOT, fetch_global_stats, write_or_print

MANIFEST = REPO_ROOT / "steam" / "play_stats_manifest.json"
KEYCHAIN_ITEM = "labyrinth-steamworks-publisher-key"
PREFIX = "play_v1_"
SCHEMA_COLUMNS = (
    "api_name", "display_name", "type", "set_by", "increment_only", "min", "max",
    "default", "aggregated",
)


def render_schema(definitions: list[dict]) -> str:
    output = io.StringIO()
    writer = csv.writer(output, lineterminator="\n")
    writer.writerow(SCHEMA_COLUMNS)
    for stat in definitions:
        writer.writerow((
            stat["name"], stat["display"], "INT", "client", "yes", 0,
            stat.get("max", ""), 0, "yes" if stat["aggregated"] else "no",
        ))
    return output.getvalue()


def publisher_key() -> str:
    key = os.environ.get(PUBLISHER_KEY_ENV, "").strip()
    if key:
        return key
    if sys.platform == "darwin":
        result = subprocess.run(
            ["security", "find-generic-password", "-a", os.environ.get("USER", ""),
             "-s", KEYCHAIN_ITEM, "-w"],
            capture_output=True, text=True, check=False, timeout=10,
        )
        if result.returncode == 0 and result.stdout.strip():
            return result.stdout.strip()
    raise ValueError(f"Set {PUBLISHER_KEY_ENV} or use the {KEYCHAIN_ITEM} Login Keychain item")


def totals_for_window(stats: dict, keys: list[str]) -> dict[str, int]:
    """Sum the daily values returned for the requested UTC window."""
    totals = {}
    for name in keys:
        if name not in stats:
            raise ValueError(f"Missing aggregated stat {name}")
        row = stats[name]
        if not isinstance(row, dict):
            # A fixture may provide the daily-window sum directly.
            totals[name] = int(row)
            continue
        daily = row.get("daily")
        if daily is None:
            raise ValueError(f"Steam omitted daily values for {name}; daily data is required for a windowed report")
        values = daily.values() if isinstance(daily, dict) else daily
        totals[name] = sum(int(point["value"] if isinstance(point, dict) else point) for point in values)
    return totals


def render_report(appid: int, start: dt.date, end: dt.date, totals: dict[str, int]) -> str:
    lines = [f"# Steam play stats for {appid}", "", f"UTC window **{start} to {end}** (inclusive).", ""]

    def count(suffix: str) -> int:
        return totals[PREFIX + suffix]

    def section(title: str, rows: list[tuple[str, str]]) -> None:
        lines.extend((f"## {title}", "", "| Metric | Count |", "| --- | ---: |"))
        lines.extend(f"| {label} | {count(key):,} |" for label, key in rows)
        lines.append("")

    section("Player funnel", [
        ("Launched", "p_launched"), ("Started a run", "p_run_started"),
        ("Won a fight", "p_fight_won"), ("Reached fight 3", "p_fight3"),
        ("Reached fight 5", "p_fight5"), ("Reached a Guardian", "p_guardian"),
        ("Reached the dragon", "p_boss"), ("Beat the dragon", "p_boss_won"),
        ("Started a second run", "p_run2"), ("Came back another day", "p_day2"),
        ("Played on after a win", "p_run_after_win"), ("Came back a week later", "p_day7"),
    ])
    lines.extend((
        "## Per-run funnel", "", "| Fight | Started | Run deaths |", "| --- | ---: | ---: |",
    ))
    for fight in range(1, 8):
        label = "7+" if fight == 7 else str(fight)
        lines.append(f"| {label} | {count(f'fights_started_{fight}'):,} | {count(f'died_fight_{fight}'):,} |")
    lines.append("")
    section("Run and fight totals", [
        ("Runs started", "runs_started"), ("Runs resumed", "runs_resumed"),
        ("Runs reached the dragon", "runs_reached_boss"), ("Runs won", "runs_won"),
        ("Runs lost", "runs_died"), ("Runs withdrawn", "runs_withdrew"),
        ("Saved runs abandoned", "runs_abandoned"), ("Fights won", "fights_won"),
        ("Tutorials started", "tutorial_started"), ("Tutorials left early", "tutorial_left_early"),
    ])
    section("Deaths by room", [
        ("Normal fight", "died_combat"), ("Special fight", "died_special"),
        ("Guardian", "died_guardian"), ("Dragon", "died_boss"), ("Outside a fight", "died_other"),
    ])
    section("Clean quits by screen", [(label, f"quit_{key}") for label, key in (
        ("Menu", "menu"), ("Map or travel", "map"), ("Fight", "fight"), ("Reward", "reward"),
        ("Event, dialogue or rest", "event"), ("Shop", "shop"), ("Run end", "run_end"), ("Other", "other"),
    )])
    section("Mid-run quit depth", [(label, f"quit_midrun_{key}") for label, key in (
        ("0–1 fights", "f0_1"), ("2–3 fights", "f2_3"), ("4–5 fights", "f4_5"), ("6+ fights", "f6p"),
    )])
    session_buckets = [
        ("Under 5 min", "sess_lt5"), ("5–14 min", "sess_5_15"), ("15–29 min", "sess_15_30"),
        ("30–59 min", "sess_30_60"), ("60+ min", "sess_60p"),
    ]
    section("Session length", session_buckets)

    def ratio(numerator: int, denominator: int, format_spec: str) -> str:
        return format(numerator / denominator, format_spec) if denominator else "—"

    lines.extend((
        "## Averages and unclean exits", "",
        f"- Focused minutes per session: {ratio(count('play_minutes'), count('sessions'), '.2f')}",
        f"- Run minutes per new run: {ratio(count('run_minutes'), count('runs_started'), '.2f')}",
        f"- Unclean exits: {count('unclean_exits'):,} ({ratio(count('unclean_exits'), sum(count(key) for _, key in session_buckets), '.1%')} of recorded session endings)",
        "",
    ))
    section("Load and save errors", [("Load-error covers", "load_errors"), ("Failed saves", "save_errors")])
    section("Buttons", [
        ("Wishlist on menu or settings", "wishlist_menu"), ("Wishlist on end panel", "wishlist_end"),
        ("Discord on menu or settings", "discord_menu"), ("Discord or Feedback on end panel", "discord_end"),
        ("Rise Again", "rise_again"), ("Players who pressed Wishlist", "p_wishlist"),
        ("Players who pressed Discord or Feedback", "p_discord"), ("Players who used a controller", "p_gamepad"),
    ])
    section("Platforms", [
        ("Windows", "p_os_windows"), ("macOS", "p_os_macos"), ("Linux", "p_os_linux"),
        ("Steam Deck", "p_os_steamdeck"),
    ])
    return "\n".join(lines)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    schema = commands.add_parser("schema")
    schema.add_argument("--output", type=Path)
    report = commands.add_parser("report")
    report.add_argument("--appid", type=int)
    report.add_argument("--days", type=int, default=7)
    report.add_argument("--fixture", type=Path)
    report.add_argument("--output", type=Path)
    args = parser.parse_args()
    key = ""
    try:
        manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
        definitions = manifest["stats"]
        if args.command == "schema":
            write_or_print(render_schema(definitions), args.output)
            return 0
        if args.days <= 0:
            parser.error("--days must be positive")
        appid = args.appid or manifest["app_ids"]["demo"]
        names = [stat["name"] for stat in definitions if stat["aggregated"]]
        end = dt.datetime.now(dt.timezone.utc).date()
        start = end - dt.timedelta(days=args.days - 1)
        if args.fixture:
            fixture = json.loads(args.fixture.read_text(encoding="utf-8"))
            stats = fixture["stats"]
            start = dt.date.fromisoformat(fixture.get("start_date", start.isoformat()))
            end = dt.date.fromisoformat(fixture.get("end_date", end.isoformat()))
        else:
            key = publisher_key()
            stats = fetch_global_stats(appid, names, key, start, end)
        write_or_print(render_report(appid, start, end, totals_for_window(stats, names)), args.output)
        return 0
    except (OSError, ValueError, TypeError, KeyError, subprocess.SubprocessError) as error:
        message = str(error)
        if key:
            message = message.replace(key, "[redacted]")
        print(f"steam_play_stats: {message}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
