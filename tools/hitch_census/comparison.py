"""Compare catalog cells by stable hitch identity and capture conditions."""
from __future__ import annotations

import json


def read_catalog(path):
    return json.loads((path / 'report.json' if path.is_dir() else path).read_text())


def compare_catalogs(old, current):
    def metrics(row):
        if row is None:
            return None
        return dict(count_over_50_ms=row['over_ms']['50.0'], count_over_100_ms=row['over_ms']['100.0'],
                    p99_ms=row['p99'], max_ms=row['max'])

    def index(rows):
        return {(row['hitch_id'], row['profile'], row['cache']): row for row in rows}

    rows = []
    for section in ('named_hitch_catalog', 'loading'):
        then, now = (index(catalog.get(section, [])) for catalog in (old, current))
        old_baseline, new_baseline = (
            index(catalog.get('below_hitch_threshold', [])) if section == 'named_hitch_catalog' else {}
            for catalog in (old, current)
        )
        for name, profile, cache in sorted(then.keys() | now.keys()):
            key = (name, profile, cache)
            rows.append(dict(section=section, hitch_id=name, profile=profile, cache=cache,
                             then=metrics(then.get(key, old_baseline.get(key))),
                             now=metrics(now.get(key, new_baseline.get(key)))))
    return dict(
        caveat="Load, route coverage and capture length can differ. Counts and timings are descriptive. "
               "A cell marked unlisted has no comparable row in that catalog.",
        then_load_condition=old.get('load_condition', 'load unknown'),
        now_load_condition=current.get('load_condition', 'load unknown'),
        then_timing_basis=old.get('timing_basis', 'native draw intervals'),
        now_timing_basis=current.get('timing_basis', 'native draw intervals'),
        rows=rows,
    )


def comparison_markdown(comparison):
    def cell(metrics):
        if metrics is None:
            return 'unlisted'
        return (f"{metrics['count_over_50_ms']} / {metrics['count_over_100_ms']} / "
                f"{metrics['p99_ms']:.3f} / {metrics['max_ms']:.3f}")

    then = f"{comparison['then_load_condition']}; {comparison['then_timing_basis']}"
    now = f"{comparison['now_load_condition']}; {comparison['now_timing_basis']}"
    lines = ['', '## Then vs now by named hitch', '', comparison['caveat'], '',
             f"| Section / hitch / QoS / cache | Then >50 / >100 / p99 ms / max ms ({then}) | Now >50 / >100 / p99 ms / max ms ({now}) |",
             '|---|---:|---:|']
    for row in comparison['rows']:
        section = 'gameplay' if row['section'] == 'named_hitch_catalog' else 'loading'
        lines.append(f"| {section} / {row['hitch_id']} / {row['profile']} / {row['cache']} | {cell(row['then'])} | {cell(row['now'])} |")
    return lines
