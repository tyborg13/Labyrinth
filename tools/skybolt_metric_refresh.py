#!/usr/bin/env python3
"""Refresh completed Skybolt checkpoints with caster-origin counters and parity guards."""
from __future__ import annotations

import argparse
from concurrent.futures import ThreadPoolExecutor, wait, FIRST_COMPLETED
import json
from pathlib import Path
import time

from encounter_bot import compress_report
from encounter_sweep import run_engine
from skybolt_measurement import ARMS, GROUPS, RUNS, FIRST_SEED, TASK_ID, OUTPUT

DEFAULT_WORKERS = 9
POLL_SECONDS = 1
ORIGIN_VERSION = 'caster_v1'


def ready(path: Path, arm: str) -> dict | None:
    try:
        report = json.loads(path.read_text())
    except (FileNotFoundError, json.JSONDecodeError):
        return None
    rows = report['results']
    if len(rows) != RUNS or (arm in ('V1', 'V5') and not all(r.get('primary_only_shock_adapter') for r in rows)):
        return None
    if report.get('deck_override', {}) != ARMS[arm]:
        raise ValueError('Checkpoint override mismatch: ' + str(path))
    return report


def replay_count(report: dict) -> int:
    return sum(r['card_usage'].get('origin_metric') != ORIGIN_VERSION
               and r['card_usage']['casts'].get('skybolt', 0) > 0 for r in report['results'])


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--checkpoint-dir', required=True, type=Path)
    parser.add_argument('--output-dir', type=Path, default=OUTPUT)
    parser.add_argument('--workers', type=int, default=DEFAULT_WORKERS)
    args = parser.parse_args()
    if args.workers < 1: parser.error('workers must be positive')
    work = args.checkpoint_dir.resolve()
    refreshed = work / 'metric-refresh'
    refreshed.mkdir(exist_ok=True)
    data = args.output_dir.resolve() / 'data'
    data.mkdir(parents=True, exist_ok=True)
    pending = [(tier, cohort, arm) for tier, cohort in GROUPS for arm, addition in ARMS.items()
               if addition.get('card') == 'skybolt']

    def refresh(job: tuple) -> int:
        tier, cohort, arm = job
        stem = f't{tier}-{cohort}-{arm}'
        canonical = work / f'{stem}.json'
        lock = Path(str(canonical) + '.metric-lock')
        while True:
            try:
                lock.mkdir()
                break
            except FileExistsError:
                time.sleep(POLL_SECONDS)
        try:
            report = ready(canonical, arm)
            if report is None: raise ValueError('Completed checkpoint disappeared: ' + stem)
            count = replay_count(report)
            if not all(r['card_usage'].get('origin_metric') == ORIGIN_VERSION for r in report['results']):
                path = refreshed / f'{stem}.json'
                # Preserve already-refreshed rows if a previous refresh stopped.
                checkpoint = ready(path, arm)
                if checkpoint is None: path.write_text(json.dumps(report))
                addition = ARMS[arm]
                arguments = ['--revision', '7', '--tier', str(tier), '--cohort', cohort,
                             '--seed', str(FIRST_SEED), '--runs', str(RUNS), '--output', str(path),
                             '--resume-report', str(path), '--measure-usage', '--refresh-skybolt-metrics',
                             '--add-card', addition['card'], '--card-overrides', json.dumps(addition['fields'])]
                run_engine('tools/encounter_measurement_bot.gd', arguments, refreshed / f'{stem}.log', task_id=TASK_ID)
                report = json.loads(path.read_text())
                if len(report['results']) != RUNS or not all(r['card_usage'].get('origin_metric') == ORIGIN_VERSION for r in report['results']):
                    raise ValueError('Incomplete caster-origin refresh: ' + stem)
                path.replace(canonical)
            compress_report(canonical, data / f'{stem}.json.gz')
            print(f'SKYBOLT METRIC PARITY: PASS ({stem}; {count} nonzero-cast fights refreshed)', flush=True)
            return count
        finally:
            lock.rmdir()

    completed = 0
    replays = 0
    with ThreadPoolExecutor(max_workers=args.workers) as pool:
        running = {}
        while pending or running:
            available = []
            for job in pending:
                tier, cohort, arm = job
                report = ready(work / f't{tier}-{cohort}-{arm}.json', arm)
                if report is not None: available.append((replay_count(report), job))
            # Start only complete, adapter-aware cohorts. Long replays go first;
            # not-yet-complete original arms never occupy a worker slot.
            for _, job in sorted(available, reverse=True):
                if len(running) == args.workers: break
                pending.remove(job)
                running[pool.submit(refresh, job)] = job
            if not running:
                time.sleep(POLL_SECONDS)
                continue
            done, _ = wait(running, timeout=POLL_SECONDS, return_when=FIRST_COMPLETED)
            for future in done:
                replays += future.result()
                running.pop(future)
                completed += 1
    print(f'SKYBOLT METRIC REFRESH: PASS ({completed} arm/cohort checkpoints; {replays} nonzero-cast fights refreshed)')


if __name__ == '__main__':
    main()
