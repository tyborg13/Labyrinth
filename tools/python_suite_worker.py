"""Structured unittest discovery worker; also used for serial timing proof."""
from __future__ import annotations

import argparse
from collections import defaultdict
import json
import os
from pathlib import Path
import sys
import time
import unittest
from python_suite_audit import DEFAULT_PATTERN
from python_suite_guard import SuiteImportGuard
from python_suite_groups import test_group
from contextlib import nullcontext


def flatten(suite):
    for item in suite:
        if isinstance(item, unittest.TestSuite):
            yield from flatten(item)
        else:
            yield item


def module_name(test):
    if isinstance(test, unittest.loader._FailedTest):
        return test._testMethodName
    return test.__class__.__module__


class OwnedSuite(unittest.TestSuite):
    def __init__(self, owner, suite):
        super().__init__([suite])
        self.owner = owner


class ModuleLoader(unittest.TestLoader):
    def __init__(self, modules=None, guard=None):
        super().__init__()
        self.modules = None if modules is None else set(modules)
        self.guard = guard

    def _find_test_path(self, full_path, pattern, *args, **kwargs):
        name = self._get_name_from_path(full_path)
        if self.modules is not None and name not in self.modules:
            # Check before unittest imports the file or invokes load_tests.
            # Ancestor packages are needed for selected descendants; scheduling
            # keeps their entire discovery tree in this same worker.
            if not Path(full_path).is_dir() or not any(
                    module.startswith(name + '.') for module in self.modules):
                return None, False
        with self.guard.loading(name) if self.guard else nullcontext():
            suite, recurse = super()._find_test_path(full_path, pattern, *args, **kwargs)
        if self.guard:
            self.guard.require_clean()
        # Import errors and SkipTest (including package skips) bypass
        # loadTestsFromModule. Retain their discovery path as the owner too.
        if suite is not None:
            suite = OwnedSuite(name, suite)
        return suite, recurse

    def loadTestsFromModule(self, module, *, pattern=None):
        # Discovery ownership differs from test.__class__.__module__ when a
        # module imports fixture TestCases. Serial discovery executes those too,
        # including duplicate identities imported by more than one module.
        return OwnedSuite(module.__name__, super().loadTestsFromModule(module, pattern=pattern))


def owned_tests(suite, owner=None):
    if isinstance(suite, OwnedSuite) and owner is None:
        owner = suite.owner
    for item in suite:
        if isinstance(item, unittest.TestSuite):
            yield from owned_tests(item, owner)
        else:
            yield owner or module_name(item), item


class Result(unittest.TestResult):
    def addSkip(self, test, reason):
        super().addSkip(test, reason)
        print(f'{test.id()} ... skipped: {reason}', flush=True)

    def addFailure(self, test, err):
        super().addFailure(test, err)
        print(f'FAIL: {test.id()}', flush=True)

    def addError(self, test, err):
        super().addError(test, err)
        print(f'ERROR: {test.id()}', flush=True)


def run_worker(root, modules, output, pattern=DEFAULT_PATTERN, start='tests', invocation_id=None,
               suite_modules=None, group='behavior'):
    if suite_modules is None:
        raise ValueError('The full audited suite module inventory is required')
    os.environ['LABYRINTH_PYTHON_SUITE_GROUP'] = group
    root = Path(root).resolve()
    # Match `python -m unittest discover -s tests`: tests first, project second.
    sys.path[:0] = [str(root / start), str(root)]
    with SuiteImportGuard(root, start, suite_modules, set(modules)) as guard:
        return guarded_worker(root, modules, output, pattern, start, invocation_id, guard, group)


def guarded_worker(root, modules, output, pattern, start, invocation_id, guard, group):
    suite = ModuleLoader(modules, guard).discover(str(root / start), pattern=pattern)
    guard.require_clean()
    grouped = defaultdict(list)
    selected = set(modules)
    for name, test in owned_tests(suite):
        if name in selected and (test_group(test) == group or isinstance(test, unittest.loader._FailedTest)):
            grouped[name].append(test)
    result, durations, identities = Result(), {}, []
    started = time.monotonic()
    for name in modules:
        before = time.monotonic()
        tests = grouped[name]
        identities.extend(test.id() for test in tests)
        with guard.loading(name):
            unittest.TestSuite(tests).run(result)
        guard.require_clean()
        durations[name] = time.monotonic() - before
        print(f'MODULE {name}: {durations[name]:.3f}s', flush=True)
    record = dict(invocation_id=invocation_id, import_guard_violations=len(guard.violations),
        tests=result.testsRun, ids=identities, duration=time.monotonic() - started,
        failures=[(str(test), details) for test, details in result.failures],
        errors=[(str(test), details) for test, details in result.errors],
        skipped=[(str(test), reason) for test, reason in result.skipped],
        expected_failures=len(result.expectedFailures),
        unexpected_successes=[str(test) for test in result.unexpectedSuccesses], modules=durations)
    Path(output).write_text(json.dumps(record, indent=2) + '\n')
    return record


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', type=Path, required=True)
    parser.add_argument('--modules', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--start', default='tests')
    parser.add_argument('--pattern', default=DEFAULT_PATTERN)
    parser.add_argument('--invocation-id', required=True)
    parser.add_argument('--suite-modules', type=Path, required=True)
    parser.add_argument('--group', choices=('behavior', 'perf'), default='behavior')
    args = parser.parse_args()
    run_worker(args.root, json.loads(args.modules.read_text()), args.output,
               args.pattern, args.start, args.invocation_id, json.loads(args.suite_modules.read_text()), args.group)


if __name__ == '__main__':
    main()
