#!/usr/bin/env python3
"""Measure one Python suite invocation, its descendant memory and module timeline.

Uses the existing test-only macOS process accountant. The parent runner's logs
are sampled, never imported as tests. Module-end observation precision is the
sample interval; module starts subtract the worker's reported duration.
"""
from __future__ import annotations

import argparse
from collections import Counter
import json
import os
from pathlib import Path
import resource
import signal
import subprocess
import sys
import time

from pool_width_benchmark import MacSuiteMemory
from godot_task_runner import terminate_process_tree

ROOT = Path(__file__).resolve().parents[2]
SAMPLE_SECONDS = 0.1
MEMORY_LIMIT_BYTES = 13_000_000_000
STOP_GRACE_SECONDS = 10


def run_frozen_plan(path, options):
    # Other worktrees update the common timing cache. Replay the already
    # audited baseline plan for a matched comparison, with a fresh audit and
    # the normal worker import guard. This affects scheduling only.
    import run_python_suite as runner
    plan = json.loads(path.read_text())

    def frozen_balance(modules, timings, rows, shards):
        assignments = plan['shards']
        if len(assignments) != shards or Counter(name for group in assignments for name in group) != Counter(modules):
            raise ValueError('Frozen plan must retain the complete selected module inventory and shard count')
        owners = {name: index for index, group in enumerate(assignments) for name in group}
        resources = {}
        for row in rows:
            owner = owners[row['module']]
            dependencies = row.get('imports', []) + [row['module'].rpartition('.')[0]]
            if any(owners[name] != owner for name in dependencies if name in owners):
                raise ValueError('Frozen plan splits a test import/package dependency')
            for resource_name in row['resources']:
                if resources.setdefault(resource_name, owner) != owner:
                    raise ValueError('Frozen plan splits a shared written resource')
        return assignments, plan['estimated_seconds']

    runner.balance = frozen_balance
    return runner.main(options)


def run(output, options, frozen_plan=None):
    output.mkdir(parents=True, exist_ok=True)
    if (output / 'measurement.json').exists():
        raise ValueError('Refusing to overwrite a completed measurement')
    memory = MacSuiteMemory()
    memory.sample(os.getpid())  # Capability check before launching the suite.
    memory.owned.clear()
    suite = output / 'suite'
    command = [sys.executable, str(ROOT / 'tools/run_python_suite.py'),
               '--output-dir', str(suite), *options]
    if frozen_plan:
        command = [sys.executable, str(Path(__file__).resolve()), '--run-plan', str(frozen_plan),
                   '--output-dir', str(suite), *options]
    samples, ends = [], {}
    started, stopped_at = time.monotonic(), None
    guard = ''
    with (output / 'output.log').open('w') as log:
        process = subprocess.Popen(command, cwd=ROOT, stdout=log, stderr=subprocess.STDOUT)
        while True:
            try:
                usage = memory.sample(process.pid)
                usage.update(seconds=time.monotonic() - started, load=os.getloadavg())
                samples.append(usage)
                if max(usage['rss_bytes'], usage['footprint_bytes']) >= MEMORY_LIMIT_BYTES:
                    guard = 'suite reached 13 GB'
            except OSError as error:
                guard = 'memory accounting failed: ' + str(error)
            for path in suite.glob('shard-*-output.log'):
                for line in path.read_text().splitlines():
                    if line.startswith('MODULE ') and line.endswith('s'):
                        name = line.split(':', 1)[0].removeprefix('MODULE ')
                        ends.setdefault((path.name, name), time.monotonic() - started)
            if process.poll() is not None:
                break
            if guard:
                if stopped_at is None:
                    process.send_signal(signal.SIGINT)
                    stopped_at = time.monotonic()
                elif time.monotonic() - stopped_at > STOP_GRACE_SECONDS:
                    terminate_process_tree(process)
            time.sleep(SAMPLE_SECONDS)
    wall = time.monotonic() - started
    summary_path = suite / 'summary.json'
    summary = json.loads(summary_path.read_text()) if summary_path.exists() else {}
    timelines = []
    for index, shard in enumerate(summary.get('shards', []), 1):
        modules = []
        for name, seconds in shard['modules'].items():
            end = ends.get((f'shard-{index}-output.log', name))
            modules.append(dict(module=name, duration_s=seconds, observed_end_s=end,
                                estimated_start_s=end - seconds if end is not None else None))
        timelines.append(dict(shard=index, duration_s=shard['duration'], modules=modules))
    result = dict(command=command, returncode=process.returncode, wall_s=wall, guard=guard,
                  frozen_plan=str(frozen_plan) if frozen_plan else None,
                  sample_seconds=SAMPLE_SECONDS,
                  peak_rss_bytes=max((row['rss_bytes'] for row in samples), default=0),
                  peak_footprint_bytes=max((row['footprint_bytes'] for row in samples), default=0),
                  child_maxrss_bytes=resource.getrusage(resource.RUSAGE_CHILDREN).ru_maxrss,
                  host_load_1m_min=min(row['load'][0] for row in samples),
                  host_load_1m_max=max(row['load'][0] for row in samples), shards=timelines)
    (output / 'measurement.json').write_text(json.dumps(result, indent=2) + '\n')
    (output / 'memory.json').write_text(json.dumps(samples) + '\n')
    print(f'PYTHON MEASUREMENT: exit={process.returncode}; wall={wall:.3f}s; '
          f'peak RSS={result["peak_rss_bytes"] / 1e9:.3f} GB; '
          f'peak footprint={result["peak_footprint_bytes"] / 1e9:.3f} GB; {guard}')
    return process.returncode or int(bool(guard))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output-dir', type=Path, required=True)
    parser.add_argument('--frozen-plan', type=Path, help='replay an audited plan for a matched benchmark')
    parser.add_argument('--run-plan', type=Path, help=argparse.SUPPRESS)
    args, options = parser.parse_known_args()
    if args.run_plan:
        return run_frozen_plan(args.run_plan, ['--output-dir', str(args.output_dir), *options])
    return run(args.output_dir.resolve(), options, args.frozen_plan)


if __name__ == '__main__':
    raise SystemExit(main())
