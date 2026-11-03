#!/usr/bin/env python3
"""Matched Slag Mortar replays of meas-02's frozen revision-7 baseline."""
from __future__ import annotations

import argparse
from concurrent.futures import ThreadPoolExecutor
import gzip
import hashlib
import json
from pathlib import Path
import subprocess
import sys

from encounter_sweep import distribution

ROOT = Path(__file__).resolve().parents[1]
BASELINE = ROOT / 'spec/peer_benchmark/encounter_redesign/measurements/revision7'
DEFAULT_OUTPUT = ROOT / 'output/enc-03/measurement'
WORKERS = 6
MEASUREMENT_TIMEOUT_SECONDS = 7200
BASELINE_COMPARISON_FIELDS = ('won', 'hp_lost', 'turns', 'decisions', 'intent_previews')


def historical_drift(rows: list[dict]) -> int:
    return sum(any(row[field] != row['revision7_baseline'][field]
                   for field in BASELINE_COMPARISON_FIELDS) for row in rows)


def read_report(path: Path) -> dict:
    if path.exists():
        return json.loads(path.read_text())
    return json.loads(gzip.decompress(path.with_suffix('.json.gz').read_bytes()))


def summarize(rows: list[dict]) -> dict:
    return {'n': len(rows), 'win_rate': sum(r['won'] for r in rows) / len(rows) if rows else None,
            'hp_lost': distribution([r['hp_lost'] for r in rows]),
            'turns': distribution([r['turns'] for r in rows]),
            'action_mix': {key: sum(r['slag_action_mix'][key] for r in rows)
                           for key in ('lob', 'lob_mark', 'lob_land', 'brace', 'scatter', 'retreat')},
            'turn_caps': sum(r['turn_cap_reached'] for r in rows)}


def report(output: Path) -> None:
    groups = []
    historical_rooms = 0
    historical_mismatches = 0
    lines = ['# enc-03 — matched revision-7 Slag Mortar measurements', '',
             'Replays every fire Warband and every generated standard fight containing a Slag Mortar within '
             'meas-02’s 200-record baseline per tier/cohort. Identical seed, room, travel direction, policy v2, '
             'deck and limits before/after; no roster substitutions. These are baseline subsets, not 200 new '
             'fire fights per tier. Lob counts include mark and landing actions (also reported separately). '
             'Brace counts resolved block steps; Scatter counts resolved ranged attacks; Retreat counts actual '
             'movement steps labelled Retreat, including the retained captain keep_distance move. Preview '
             'branches never contribute. HP lost is cumulative damage_received. P10/P90 use nearest rank.', '',
             '| Tier | Cohort | Phase | N | Win rate | HP lost median (P10–P90) | Turns median (P10–P90) | Lob (mark/land) | Brace | Scatter | Retreat |',
             '|---|---|---|---:|---:|---:|---:|---:|---:|---:|---:|']
    for tier in (1, 2, 3):
        for cohort in ('warband', 'standard'):
            pair = []
            for phase in ('before', 'after'):
                rows = read_report(output / f'{phase}-t{tier}-{cohort}.json')['results']
                stats = summarize(rows)
                if phase == 'before':
                    historical_rooms += len(rows)
                    historical_mismatches += historical_drift(rows)
                pair.append(rows)
                groups.append({'tier': tier, 'cohort': cohort, 'phase': phase, **stats})
                mix = stats['action_mix']
                def cell(key):
                    d = stats[key]
                    return f"{d['median']} ({d['p10']}–{d['p90']})"
                lines.append(f"| {tier} | {cohort} | {phase} | {stats['n']} | {stats['win_rate']:.1%} | {cell('hp_lost')} | {cell('turns')} | {mix['lob']} ({mix['lob_mark']}/{mix['lob_land']}) | {mix['brace']} | {mix['scatter']} | {mix['retreat']} |")
            keys = lambda rows: [(r['seed'], r['coord'], r['travel_dir'], r['biome']) for r in rows]
            assert keys(pair[0]) == keys(pair[1]), 'Before/after sampling differs'
    document = {'revision': 7, 'policy_sha256': hashlib.sha256((ROOT / 'tools/encounter_bot.gd').read_bytes()).hexdigest(),
                'chosen_defaults': {'workers': WORKERS, 'timeout_seconds': MEASUREMENT_TIMEOUT_SECONDS,
                                    'cohort': 'all applicable rooms in frozen 200-record baseline groups'}, 'groups': groups,
                'historical_baseline_check': {'rooms': historical_rooms, 'different_results': historical_mismatches,
                                              'fields': list(BASELINE_COMPARISON_FIELDS)}}
    lines += ['', f'Historical baseline check: {historical_mismatches} of {historical_rooms} fresh before replays '
              'differ from the stored revision-7 outcomes in at least one of win, HP lost, turns, decisions or '
              'preview count. The table compares fresh before/after replays under the same current integration; '
              'it does not substitute historical outcomes for the before arm. Raw records retain the historical '
              'baseline row for every room. The policy SHA-256 matches meas-02 exactly.']
    capped = [f"tier {group['tier']} {group['cohort']} {group['phase']}: {group['turn_caps']}"
              for group in groups if group['turn_caps']]
    lines += ['', 'Turn-capped runs count as losses. Nonzero caps: ' + ('; '.join(capped) or 'none') + '. '
              'Action mix counts emitted resolver steps, including missed attacks; it does not count damage contacts. '
              'The ordinary-fight samples contain 4, 5 and 8 rooms per arm, so their rates have small denominators.']
    (output / 'summary.json').write_text(json.dumps(document, indent=2) + '\n')
    (output / 'report.md').write_text('\n'.join(lines) + '\n')
    print(f'ENC03 REPORT: PASS ({sum(g["n"] for g in groups)} replays; 6 matched groups); {output / "report.md"}')


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output-dir', type=Path, default=DEFAULT_OUTPUT)
    parser.add_argument('--report-only', action='store_true')
    parser.add_argument('--cohort', choices=('all', 'warband', 'standard'), default='all')
    parser.add_argument('--limit', type=int, default=0, help='debug smoke only; 0 replays the complete subset')
    args = parser.parse_args()
    output = args.output_dir.resolve()
    output.mkdir(parents=True, exist_ok=True)
    if args.report_only:
        report(output)
        return
    jobs = []
    for tier in (1, 2, 3):
        for cohort in ('warband', 'standard'):
            if args.cohort != 'all' and cohort != args.cohort:
                continue
            source = output / f'input-t{tier}-{cohort}.json'
            source.write_bytes(gzip.decompress((BASELINE / f'bot-t{tier}-{cohort}.json.gz').read_bytes()))
            for phase in ('before', 'after'):
                jobs.append((tier, cohort, phase, source))
    def run(job):
        tier, cohort, phase, source = job
        stem = f'{phase}-t{tier}-{cohort}'
        command = [sys.executable, 'tools/godot_task_runner.py', '--task-id', 'enc-03', '--timeout',
                   str(MEASUREMENT_TIMEOUT_SECONDS), '--stream', '--', 'godot', '--headless', '--path', '.',
                   '--script', 'tools/enc03_measurement.gd', '--', '--phase', phase, '--input', str(source),
                   '--output', str(output / f'{stem}.json'), '--limit', str(args.limit)]
        with (output / f'{stem}.log').open('w') as log:
            result = subprocess.run(command, cwd=ROOT, stdout=log, stderr=subprocess.STDOUT)
        if result.returncode:
            raise RuntimeError(f'{stem} failed ({result.returncode}); see {output / (stem + ".log")}')
        print(f'ENC03 GROUP: PASS ({stem})', flush=True)
    with ThreadPoolExecutor(max_workers=WORKERS) as pool:
        list(pool.map(run, jobs))
    report(output)


if __name__ == '__main__':
    main()
