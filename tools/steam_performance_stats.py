#!/usr/bin/env python3
"""Expand and report Escape the Umbra's Steam performance-stat schema."""

from __future__ import annotations

import argparse
import csv
import datetime as dt
import io
import json
import os
import sys
import urllib.parse
import urllib.request
from pathlib import Path
from typing import Any, Iterable


REPO_ROOT = Path(__file__).resolve().parents[1]
DEFAULT_MANIFEST = REPO_ROOT / "steam" / "performance_stats_manifest.json"
STEAM_GLOBAL_STATS_URL = (
    "https://partner.steam-api.com/ISteamUserStats/GetGlobalStatsForGame/v1/"
)
PUBLISHER_KEY_ENV = "STEAMWORKS_PUBLISHER_KEY"
REPORT_BATCH_SIZE = 100


def load_manifest(path: Path) -> dict[str, Any]:
    with path.open("r", encoding="utf-8") as handle:
        manifest = json.load(handle)
    if int(manifest.get("schema_version", 0)) <= 0:
        raise ValueError("manifest schema_version must be positive")
    return manifest


def expanded_stat_names(manifest: dict[str, Any]) -> list[str]:
    suffixes = list(manifest["global_metrics"])
    suffixes.extend(
        f"cohort_{cohort}_{metric}"
        for cohort in manifest["frame_cohorts"]
        for metric in manifest["frame_cohort_metrics"]
    )
    suffixes.extend(
        f"section_{section}_{metric}"
        for section in manifest["section_groups"]
        for metric in manifest["section_metrics"]
    )
    names = [
        f"{prefix}_{suffix}"
        for prefix in manifest["platform_prefixes"]
        for suffix in suffixes
    ]
    if len(names) != len(set(names)):
        raise ValueError("manifest expands to duplicate stat API names")
    invalid = [name for name in names if len(name.encode("utf-8")) >= 128]
    if invalid:
        raise ValueError(f"stat API names exceed Steam's 127-byte payload limit: {invalid[:3]}")
    return names


def schema_rows(manifest: dict[str, Any]) -> Iterable[dict[str, Any]]:
    defaults = manifest["steamworks_defaults"]
    for name in expanded_stat_names(manifest):
        yield {
            "api_name": name,
            "type": defaults["type"],
            "aggregated": str(bool(defaults["aggregated"])).lower(),
            "increment_only": str(bool(defaults["increment_only"])).lower(),
            "set_by": defaults["set_by"],
        }


def render_schema(manifest: dict[str, Any], output_format: str) -> str:
    rows = list(schema_rows(manifest))
    if output_format == "json":
        return json.dumps({"stat_count": len(rows), "stats": rows}, indent=2) + "\n"
    destination = io.StringIO()
    writer = csv.DictWriter(
        destination,
        fieldnames=["api_name", "type", "aggregated", "increment_only", "set_by"],
    )
    writer.writeheader()
    writer.writerows(rows)
    return destination.getvalue()


def chunks(values: list[str], size: int) -> Iterable[list[str]]:
    for index in range(0, len(values), size):
        yield values[index : index + size]


def fetch_global_stats(
    app_id: int,
    stat_names: list[str],
    publisher_key: str,
    start_date: dt.date,
    end_date: dt.date,
) -> dict[str, Any]:
    combined: dict[str, Any] = {}
    for batch in chunks(stat_names, REPORT_BATCH_SIZE):
        params: list[tuple[str, str]] = [
            ("key", publisher_key),
            ("appid", str(app_id)),
            ("count", str(len(batch))),
            (
                "startdate",
                str(int(dt.datetime.combine(start_date, dt.time.min, tzinfo=dt.timezone.utc).timestamp())),
            ),
            (
                "enddate",
                str(int(dt.datetime.combine(end_date, dt.time.max, tzinfo=dt.timezone.utc).timestamp())),
            ),
        ]
        params.extend((f"name[{index}]", name) for index, name in enumerate(batch))
        url = f"{STEAM_GLOBAL_STATS_URL}?{urllib.parse.urlencode(params)}"
        request = urllib.request.Request(url, headers={"User-Agent": "EscapeTheUmbraSteamStats/1"})
        with urllib.request.urlopen(request, timeout=30) as response:
            payload = json.load(response)
        response_data = payload.get("response", payload)
        result = response_data.get("result")
        try:
            result_code = int(result)
        except (TypeError, ValueError) as error:
            raise ValueError("Steam global-stats response omitted a valid result code") from error
        if result_code != 1:
            raise ValueError(f"Steam global-stats request failed with result {result_code}")
        global_stats = response_data.get("globalstats", {})
        if not isinstance(global_stats, dict):
            raise ValueError("Steam global-stats response did not contain an object")
        missing = sorted(set(batch) - set(global_stats))
        if missing:
            raise ValueError(
                "Steam global-stats response omitted requested keys; "
                f"verify that the App Admin schema is published: {missing[:3]}"
            )
        for name, value in global_stats.items():
            combined[name] = value
    return combined


def write_or_print(content: str, output: Path | None) -> None:
    if output is None:
        sys.stdout.write(content)
        return
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(content, encoding="utf-8")
    print(f"Wrote {output}", file=sys.stderr)


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--manifest", type=Path, default=DEFAULT_MANIFEST)
    subparsers = parser.add_subparsers(dest="command", required=True)

    schema = subparsers.add_parser("schema", help="expand App Admin stat definitions")
    schema.add_argument("--format", choices=["csv", "json"], default="csv")
    schema.add_argument("--output", type=Path)

    report = subparsers.add_parser("report", help="download aggregated Steam global stats")
    report.add_argument("--appid", type=int, required=True)
    report.add_argument("--days", type=int, default=7)
    report.add_argument("--output", type=Path)
    return parser


def main() -> int:
    args = build_parser().parse_args()
    try:
        manifest = load_manifest(args.manifest)
        if args.command == "schema":
            write_or_print(render_schema(manifest, args.format), args.output)
            return 0
        publisher_key = os.environ.get(PUBLISHER_KEY_ENV, "").strip()
        if not publisher_key:
            raise ValueError(f"{PUBLISHER_KEY_ENV} must contain a Steamworks publisher Web API key")
        end_date = dt.datetime.now(dt.timezone.utc).date()
        start_date = end_date - dt.timedelta(days=max(1, args.days) - 1)
        stats = fetch_global_stats(
            args.appid,
            expanded_stat_names(manifest),
            publisher_key,
            start_date,
            end_date,
        )
        report = {
            "appid": args.appid,
            "start_date": start_date.isoformat(),
            "end_date": end_date.isoformat(),
            "schema_version": manifest["schema_version"],
            "stats": stats,
        }
        write_or_print(json.dumps(report, indent=2, sort_keys=True) + "\n", args.output)
        return 0
    except (OSError, ValueError, KeyError, json.JSONDecodeError) as error:
        print(f"steam_performance_stats: {error}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
