#!/usr/bin/env python3
"""Run the product pass in audited shards; authoring checks use --on-demand."""
from __future__ import annotations

import argparse
from concurrent.futures import ThreadPoolExecutor, as_completed
import json
import math
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import threading
import time
import uuid

sys.path.insert(0, str(Path(__file__).resolve().parent))
from python_suite_audit import DEFAULT_PATTERN, audit, audit_table, balance, discover_modules
from python_suite_timings import history_path, read_history, write_history
from python_suite_selection import group_timings, load_groups, select_groups
from godot_task_runner import infer_task_id, terminate_process_tree
from windows_process_job import spawn_owned_process

ROOT = Path(__file__).resolve().parents[1]
SHIPPED_TIMINGS = ROOT / 'spec/peer_benchmark/staged/perf-06/python_suite_timing.json'
DEFAULT_SHARDS = 4
DEFAULT_SHARD_TIMEOUT_SECONDS = 2400.0


def load_timings(shipped, learned=None):
    data = json.loads(Path(shipped).read_text())
    timings = {}
    for test in data.get('tests', []):
        name = test['id'].split('.')[0]
        if name == 'unittest':
            name = test['id'].split('.')[-1]
        timings[name] = timings.get(name, 0.) + test['run_s'] + test.get('setup_s', 0.)
    if learned:
        record = read_history(Path(learned))
        durations = record.get('modules', {}) if isinstance(record, dict) else {}
        if isinstance(durations, dict):
            timings.update({name: value for name, value in durations.items()
                            if isinstance(value, (int, float)) and math.isfinite(value) and value >= 0})
    return timings


def summary(results, elapsed, stream=sys.stdout):
    total = sum(r['tests'] for r in results)
    counts = {name: sum(len(r[name]) for r in results) for name in
              ('failures', 'errors', 'skipped', 'unexpected_successes')}
    counts['expected_failures'] = sum(r['expected_failures'] for r in results)
    for result in results:
        for kind in ('failures', 'errors'):
            for test, traceback in result[kind]:
                print('=' * 70, file=stream)
                print(('FAIL' if kind == 'failures' else 'ERROR') + ': ' + test, file=stream)
                print('-' * 70, file=stream)
                print(traceback, file=stream)
        for test in result['unexpected_successes']:
            print('UNEXPECTED SUCCESS: ' + test, file=stream)
    print('-' * 70, file=stream)
    print(f'Ran {total} tests in {elapsed:.3f}s\n', file=stream)
    failed = counts['failures'] or counts['errors'] or counts['unexpected_successes']
    labels = [('failures', 'failures'), ('errors', 'errors'), ('skipped', 'skipped'),
              ('expected_failures', 'expected failures'), ('unexpected_successes', 'unexpected successes')]
    details = ', '.join(f'{label}={counts[key]}' for key, label in labels if counts[key])
    print(('FAILED' if failed else 'OK') + (f' ({details})' if details else ''), file=stream)
    return not failed


def shard_result(output, invocation_id):
    if not output.exists():
        raise ValueError('missing result')
    result = json.loads(output.read_text())
    if not isinstance(result, dict) or result.get('invocation_id') != invocation_id:
        raise ValueError('mismatched invocation id')
    return result


def run_shards(root, assignments, directory, *, start='tests', pattern=DEFAULT_PATTERN,
               shard_timeout=DEFAULT_SHARD_TIMEOUT_SECONDS, perf=False, suite_modules=None):
    processes, lock, stopping = set(), threading.Lock(), threading.Event()
    task_id = infer_task_id(Path(root))
    inventory = directory / 'suite-modules.json'
    inventory.write_text(json.dumps(suite_modules if suite_modules is not None else
                                         sorted({name for modules in assignments for name in modules})))
    def run(index, modules):
        names, output, log = (directory / f'shard-{index}-{suffix}' for suffix in
                               ('modules.json', 'result.json', 'output.log'))
        output.unlink(missing_ok=True)
        invocation_id = uuid.uuid4().hex
        names.write_text(json.dumps(modules))
        command = [sys.executable, str(ROOT / 'tools/python_suite_worker.py'), '--root', str(root),
                   '--modules', str(names), '--output', str(output), '--start', start, '--pattern', pattern,
                   '--invocation-id', invocation_id, '--suite-modules', str(inventory),
                   '--group', 'perf' if perf else 'behavior']
        environment = dict(os.environ, LABYRINTH_TASK_ID=f'{task_id}-python-{index}',
                           PYTHONDONTWRITEBYTECODE='1',
                           LABYRINTH_PYTHON_SUITE_GROUP='perf' if perf else 'behavior')
        with log.open('w') as stream:
            with lock:
                if stopping.is_set():
                    raise RuntimeError(f'Shard {index} cancelled before launch')
                process = spawn_owned_process(command, cwd=root, env=environment, stdout=stream,
                                              stderr=subprocess.STDOUT, start_new_session=os.name != 'nt')
                processes.add(process)
            try:
                try:
                    code = process.wait(timeout=shard_timeout)
                except subprocess.TimeoutExpired:
                    terminate_process_tree(process)
                    stream.flush()
                    raise RuntimeError(f'Shard {index} timed out after {shard_timeout:g}s; '
                                       f'log: {log}\n{log.read_text()}') from None
            finally:
                # Also close Windows ownership jobs and collect leftover children
                # after normal exit. Godot task runners supervise detached engine
                # groups through their signal handlers and parent-death watchdogs.
                terminate_process_tree(process)
                with lock:
                    processes.discard(process)
        if code:
            raise RuntimeError(f'Shard {index} exited {code}; log: {log}\n{log.read_text()}')
        try:
            result = shard_result(output, invocation_id)
        except (OSError, ValueError) as error:
            raise RuntimeError(f'Shard {index} exited {code} with {error}; log: {log}\n{log.read_text()}') from error
        return index, result, log
    pool = ThreadPoolExecutor(max_workers=len(assignments))
    try:
        futures = [pool.submit(run, index + 1, modules) for index, modules in enumerate(assignments) if modules]
        results = []
        for future in as_completed(futures):
            index, result, log = future.result()
            print(f'SHARD {index} COMPLETE: {result["tests"]} tests; {result["duration"]:.3f}s', flush=True)
            results.append((index, result, log))
        return sorted(results)
    finally:
        stopping.set()
        with lock:
            active = list(processes)
        for process in active:
            terminate_process_tree(process)
        pool.shutdown(wait=True, cancel_futures=True)


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--shards', type=int, default=DEFAULT_SHARDS)
    parser.add_argument('--shard-timeout', type=float, default=DEFAULT_SHARD_TIMEOUT_SECONDS,
                        help='maximum wall seconds per shard (default: 2400)')
    parser.add_argument('--output-dir', type=Path)
    parser.add_argument('--root', type=Path, default=ROOT, help=argparse.SUPPRESS)
    parser.add_argument('--start', default='tests')
    parser.add_argument('--pattern', default=DEFAULT_PATTERN)
    parser.add_argument('--audit-only', action='store_true')
    parser.add_argument('--perf', action='store_true',
                        help='run only wall-clock/speed benchmarks (default suite skips these); use a quiet machine')
    selection_options = parser.add_mutually_exclusive_group()
    selection_options.add_argument('--changed-since', metavar='GIT_REF',
                        help='run default plus groups triggered by changes from this ref to the working tree, '
                             'including untracked files; Git errors run everything')
    selection_options.add_argument('--all-groups', action='store_true',
                        help='explicitly run every input group (also the behavior when neither selection flag is given)')
    selection_options.add_argument('--on-demand', nargs='+', metavar='GROUP',
                        help='run only explicit on-demand groups (or all); excluded from --all-groups')
    parser.add_argument('--timings', type=Path, default=SHIPPED_TIMINGS)
    args = parser.parse_args(argv)
    if args.shards < 1:
        parser.error('--shards must be positive')
    if not math.isfinite(args.shard_timeout) or args.shard_timeout <= 0:
        parser.error('--shard-timeout must be finite and positive')
    directory = (args.output_dir or Path(tempfile.mkdtemp(prefix='labyrinth-python-suite-'))).resolve()
    directory.mkdir(parents=True, exist_ok=True)
    (directory / '.gdignore').touch()
    (directory / 'summary.json').unlink(missing_ok=True)
    try:
        learned = history_path(args.root)
    except (OSError, subprocess.SubprocessError) as error:
        learned = None
        print(f'Cannot resolve learned timing cache; using shipped timings: {error}', file=sys.stderr)
    modules = discover_modules(args.root, args.start, args.pattern)
    if not modules:
        parser.error('No test modules discovered')
    try:
        rows = audit(args.root, modules, args.start)
    except ValueError as error:
        print(f'ISOLATION AUDIT FAILED: {error}', file=sys.stderr)
        return 1
    inventory = list(modules)
    input_groups, _ = load_groups(args.root)
    selection = select_groups(args.root, input_groups, rows, changed_since=args.changed_since,
                              all_groups=args.all_groups, perf=args.perf, on_demand=args.on_demand)
    selected = {name for group in selection['selected_groups'] for name in input_groups[group]['modules']}
    modules = [module for module in modules if module in selected]
    selected_rows = [row for row in rows if row['module'] in selected]
    assignments, loads = balance(modules, load_timings(args.timings, learned), selected_rows, args.shards)
    table = audit_table(rows, assignments)
    (directory / 'isolation-audit.md').write_text(table)
    (directory / 'isolation-audit.json').write_text(json.dumps(rows, indent=2) + '\n')
    (directory / 'plan.json').write_text(json.dumps(dict(shards=assignments, estimated_seconds=loads,
                                                       selection=selection), indent=2) + '\n')
    print(f'ISOLATION AUDIT: {len(rows)} modules; {directory / "isolation-audit.md"}', flush=True)
    for group, reason in selection['reasons'].items():
        print(f'INPUT GROUP {group}: {reason}', flush=True)
    print(f'SELECTED MODULES: {len(modules)} of {len(inventory)}', flush=True)
    for index, names in enumerate(assignments):
        print(f'SHARD {index+1}: {len(names)} modules; estimated {loads[index]:.3f}s', flush=True)
    if args.audit_only:
        print(table)
        return 0
    started = time.monotonic()
    try:
        finished = run_shards(args.root, assignments, directory, start=args.start, pattern=args.pattern,
                              shard_timeout=args.shard_timeout, perf=args.perf, suite_modules=inventory)
    except RuntimeError as error:
        print(str(error), file=sys.stderr)
        return 1
    results = [result for _, result, _ in finished]
    # Include every skip reason and all module timings in the combined log.
    for _, _, log in finished:
        print(log.read_text(), end='')
    elapsed = time.monotonic() - started
    successful = summary(results, elapsed)
    record = dict(group='perf' if args.perf else 'behavior', elapsed_s=elapsed, tests=sum(r['tests'] for r in results),
                  selection=selection, input_groups=group_timings(results, rows),
                  shards=results, modules={name: seconds for r in results for name, seconds in r['modules'].items()})
    for group, timing in record['input_groups'].items():
        print(f'INPUT GROUP TIME {group}: {timing["modules"]} modules; '
              f'{timing["module_seconds"]:.3f} module-seconds; '
              f'{timing["max_shard_seconds"]:.3f}s maximum attributed shard work', flush=True)
    (directory / 'summary.json').write_text(json.dumps(record, indent=2) + '\n')
    if (not args.perf and learned is not None and args.start == 'tests' and
            args.pattern == DEFAULT_PATTERN and args.root.resolve() == ROOT):
        try:
            write_history(learned, dict(timestamp=time.time(), modules=record['modules']))
        except OSError as error:
            print(f'Cannot update untracked timing cache {learned}: {error}', file=sys.stderr)
    print(f'PYTHON SUITE WALL: {elapsed:.3f}s; results: {directory}', flush=True)
    return 0 if successful else 1


if __name__ == '__main__':
    raise SystemExit(main())
