#!/usr/bin/env python3
"""Focused timing/parity proof without changing unittest discovery or test IDs.

Run each trial in a fresh interpreter. Assertion counts include every call to
TestCase.assert* (including their delegates), with the same counter on both
sides. Snapshots execute with the original module filename and repository ROOT.
Only the caller's output directory is written; no Git state is updated.
"""
from __future__ import annotations

import argparse
import ast
from collections import Counter
from contextlib import ExitStack
import cProfile
import importlib.util
import json
from pathlib import Path
import statistics
import subprocess
import sys
import threading
import time
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
DEFAULT_REPEATS = 3
TRIAL_TIMEOUT_SECONDS = 180


def assertion_sites(source):
    # Extraction into a helper may rename its TestCase argument. Normalize
    # that spelling only; preserve every assertion expression and argument.
    class NormalizeCase(ast.NodeTransformer):
        def visit_Name(self, node):
            return ast.Name(id='test' if node.id == 'self' else node.id, ctx=node.ctx)
    tree = NormalizeCase().visit(ast.parse(source))
    return sorted(ast.dump(node, include_attributes=False) for node in ast.walk(tree)
                  if isinstance(node, ast.Assert) or isinstance(node, ast.Call)
                  and isinstance(node.func, ast.Attribute) and node.func.attr.startswith('assert'))


def flatten(suite):
    for item in suite:
        if isinstance(item, unittest.TestSuite):
            yield from flatten(item)
        else:
            yield item


def trial(name, source, output, *, reverse=False, profile=None):
    sys.path[:0] = [str(ROOT / 'tests'), str(ROOT)]
    path = ROOT / 'tests' / (name + '.py')
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    sys.modules[name] = module
    exec(compile(source.read_text(), str(path), 'exec'), module.__dict__)
    tests = list(flatten(unittest.defaultTestLoader.loadTestsFromModule(module)))
    if reverse:
        tests.reverse()
    calls, durations, assertion_lock = Counter(), {}, threading.Lock()

    def counted(key, original):
        def call(self, *args, **kwargs):
            with assertion_lock:
                calls[key] += 1
            return original(self, *args, **kwargs)
        return call

    class TimedResult(unittest.TextTestResult):
        def startTest(self, test):
            self.started = time.monotonic()
            super().startTest(test)

        def stopTest(self, test):
            durations[test.id()] = time.monotonic() - self.started
            super().stopTest(test)

    assertions = {key: value for key, value in unittest.TestCase.__dict__.items()
                  if key.startswith('assert') and callable(value)}
    profiler = cProfile.Profile() if profile else None
    with ExitStack() as stack:
        for key, original in assertions.items():
            stack.enter_context(patch.object(unittest.TestCase, key, counted(key, original)))
        started = time.monotonic()
        if profiler:
            profiler.enable()
        result = unittest.TextTestRunner(resultclass=TimedResult).run(unittest.TestSuite(tests))
        if profiler:
            profiler.disable()
            profiler.dump_stats(profile)
        elapsed = time.monotonic() - started
    record = dict(module=name, wall_s=elapsed, tests=result.testsRun,
                  ids=[test.id() for test in tests], assertions=dict(calls),
                  assertion_sites=assertion_sites(source.read_text()),
                  test_seconds=durations, successful=result.wasSuccessful(),
                  failures=[test.id() for test, _ in result.failures],
                  errors=[str(test) for test, _ in result.errors],
                  skipped=[test.id() for test, _ in result.skipped])
    output.write_text(json.dumps(record, indent=2) + '\n')
    return 0 if result.wasSuccessful() else 1


def measure(args):
    args.output_dir.mkdir(parents=True, exist_ok=True)
    records = {}
    for name in args.modules:
        source = (args.source_dir or ROOT / 'tests') / (name + '.py')
        snapshot = args.output_dir / (name + '.source.py')
        snapshot.write_text(source.read_text())
        rows = []
        for index in range(args.repeats):
            output = args.output_dir / f'{name}-{index + 1}.json'
            command = [sys.executable, str(Path(__file__).resolve()), '--once', name,
                       '--source', str(snapshot), '--output', str(output)]
            if args.reverse:
                command.append('--reverse')
            if args.profile:
                command += ['--profile', str(args.output_dir / (name + '.pstats'))]
            with output.with_suffix('.log').open('w') as log:
                subprocess.run(command, cwd=ROOT, stdout=log, stderr=subprocess.STDOUT,
                               timeout=TRIAL_TIMEOUT_SECONDS, check=False)
            rows.append(json.loads(output.read_text()))
        records[name] = dict(median_s=statistics.median(row['wall_s'] for row in rows), runs=rows)
        print(f'{name}: median={records[name]["median_s"]:.3f}s; '
              f'tests={rows[0]["tests"]}; assertions={sum(rows[0]["assertions"].values())}; '
              f'passed={all(row["successful"] for row in rows)}', flush=True)
    (args.output_dir / 'modules.json').write_text(json.dumps(records, indent=2) + '\n')
    return 0 if all(row['successful'] for group in records.values() for row in group['runs']) else 1


def compare(before, after):
    left, right = (json.loads((directory / 'modules.json').read_text()) for directory in (before, after))
    if left.keys() != right.keys():
        raise ValueError('Module inventories differ')
    passed = True
    for name in left:
        reference = left[name]['runs'][0]
        rows = left[name]['runs'] + right[name]['runs']
        equal = all(Counter(row['ids']) == Counter(reference['ids']) and
                    row['assertions'] == reference['assertions'] and row['tests'] == reference['tests'] and
                    row['assertion_sites'] == reference['assertion_sites'] and
                    row['successful'] for row in rows)
        passed = passed and equal
        print(f'{name}: IDs/assertion calls {"MATCH" if equal else "DIFFER"}; '
              f'{left[name]["median_s"]:.3f}s -> {right[name]["median_s"]:.3f}s')
    return 0 if passed else 1


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('modules', nargs='*')
    parser.add_argument('--output-dir', type=Path)
    parser.add_argument('--source-dir', type=Path)
    parser.add_argument('--repeats', type=int, default=DEFAULT_REPEATS)
    parser.add_argument('--reverse', action='store_true')
    parser.add_argument('--profile', type=Path, help='write cProfile data (not a timing trial)')
    parser.add_argument('--compare', nargs=2, type=Path, metavar=('BEFORE', 'AFTER'))
    parser.add_argument('--once', help=argparse.SUPPRESS)
    parser.add_argument('--source', type=Path, help=argparse.SUPPRESS)
    parser.add_argument('--output', type=Path, help=argparse.SUPPRESS)
    args = parser.parse_args()
    if args.once:
        return trial(args.once, args.source, args.output, reverse=args.reverse, profile=args.profile)
    if args.compare:
        return compare(*args.compare)
    if not args.output_dir or not args.modules or args.repeats < 1:
        parser.error('Provide modules, --output-dir and a positive --repeats')
    return measure(args)


if __name__ == '__main__':
    raise SystemExit(main())
