#!/usr/bin/env python3

import importlib.util
import datetime as dt
import io
import json
import urllib.parse
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
MODULE_PATH = ROOT / "tools" / "steam_performance_stats.py"
SPEC = importlib.util.spec_from_file_location("steam_performance_stats", MODULE_PATH)
assert SPEC is not None and SPEC.loader is not None
MODULE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(MODULE)


def main() -> None:
    manifest = MODULE.load_manifest(ROOT / "steam" / "performance_stats_manifest.json")
    names = MODULE.expanded_stat_names(manifest)
    assert 500 <= len(names) <= 750, len(names)
    assert len(names) == len(set(names))
    assert all(len(name.encode("utf-8")) < 128 for name in names)
    assert "perf_v1_linux_steamdeck_cohort_combat_animation_over_33_33_ms" in names
    assert "perf_v1_windows_desktop_section_engine_movement_tenths_ms" in names
    rendered = json.loads(MODULE.render_schema(manifest, "json"))
    assert rendered["stat_count"] == len(names)

    requested_urls = []

    class FakeResponse:
        def __init__(self, payload):
            self._payload = payload

        def __enter__(self):
            return io.BytesIO(json.dumps(self._payload).encode("utf-8"))

        def __exit__(self, _exception_type, _exception, _traceback):
            return False

    def fake_urlopen(request, timeout):
        assert timeout == 30
        requested_urls.append(request.full_url)
        query = urllib.parse.parse_qs(urllib.parse.urlparse(request.full_url).query)
        requested_names = [
            query[f"name[{index}]"][0]
            for index in range(int(query["count"][0]))
        ]
        return FakeResponse({
            "response": {
                "result": 1,
                "globalstats": {name: {"total": "0"} for name in requested_names},
            }
        })

    original_urlopen = MODULE.urllib.request.urlopen
    MODULE.urllib.request.urlopen = fake_urlopen
    try:
        MODULE.fetch_global_stats(
            4531660,
            names[:201],
            "publisher-key",
            dt.date(2026, 8, 19),
            dt.date(2026, 8, 25),
        )
    finally:
        MODULE.urllib.request.urlopen = original_urlopen
    assert len(requested_urls) == 3
    first_query = urllib.parse.parse_qs(urllib.parse.urlparse(requested_urls[0]).query)
    assert first_query["count"] == ["100"]
    assert first_query["startdate"][0].isdigit()
    assert first_query["enddate"][0].isdigit()

    def expect_fetch_error(payload, expected_fragment):
        def error_urlopen(_request, timeout):
            assert timeout == 30
            return FakeResponse(payload)

        MODULE.urllib.request.urlopen = error_urlopen
        try:
            MODULE.fetch_global_stats(
                4531660,
                names[:2],
                "publisher-key",
                dt.date(2026, 8, 19),
                dt.date(2026, 8, 25),
            )
        except ValueError as error:
            assert expected_fragment in str(error), str(error)
        else:
            raise AssertionError(f"expected report failure containing {expected_fragment!r}")
        finally:
            MODULE.urllib.request.urlopen = original_urlopen

    expect_fetch_error(
        {"response": {"result": 2, "globalstats": {}}},
        "failed with result 2",
    )
    expect_fetch_error(
        {"response": {"result": 1, "globalstats": {names[0]: {"total": "0"}}}},
        "omitted requested keys",
    )
    print(f"STEAM PERFORMANCE STATS SCHEMA TEST RESULT: PASS ({len(names)} stats)")


if __name__ == "__main__":
    main()
