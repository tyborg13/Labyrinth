#!/usr/bin/env python3
"""Compare before/after sensitivity to three scratch-only, one-line mutations.

The asset fixture mirrors inventory directories with read-only file symlinks,
then replaces one link with a private broken resource. Tools execute as private
Python modules; repository files, Git metadata and protected pins stay intact.
"""
from __future__ import annotations

import argparse
import importlib.util
import io
import json
from pathlib import Path
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]


def load_source(name, source, filename):
    spec = importlib.util.spec_from_file_location(name, filename)
    module = importlib.util.module_from_spec(spec)
    sys.modules[name] = module
    exec(compile(source, str(filename), 'exec'), module.__dict__)
    return module


def replace_line(source, old, new):
    if source.count(old) != 1:
        raise ValueError('Mutation must match exactly one source line: ' + old)
    return source.replace(old, new)


def scratch_asset(root):
    manifest = json.loads((ROOT / 'tests/approved_asset_pins.json').read_text())
    # Real directories let Path.rglob retain precisely the same inventory.
    # Only file leaves point at the immutable approved originals.
    for base in manifest['approval_source']['inventory_scopes']:
        for source in (ROOT / base).rglob('*'):
            destination = root / source.relative_to(ROOT)
            if source.is_dir():
                destination.mkdir(parents=True, exist_ok=True)
            elif source.is_file():
                destination.parent.mkdir(parents=True, exist_ok=True)
                destination.symlink_to(source)
    relative = Path(manifest['mirror_sole']['root']) / 'front.json'
    destination = root / relative
    broken = replace_line(destination.read_text(), '  "version": 2,', '  "version": -1,')
    destination.unlink()  # Never write through the original-file symlink.
    destination.write_text(broken)
    return str(relative)


def run(before, output):
    sys.path[:0] = [str(ROOT / 'tests'), str(ROOT / 'tools'), str(ROOT)]
    records = []
    with tempfile.TemporaryDirectory(prefix='test07-mutations-') as temporary:
        scratch = Path(temporary)
        for label, source_dir in (('before', before), ('after', ROOT / 'tests')):
            modules = {}
            for name in ('test_approved_content_manifest', 'test_program_suite_runner',
                         'test_python_suite_runner_feedback'):
                modules[name] = load_source(name, (source_dir / (name + '.py')).read_text(),
                                            ROOT / 'tests' / (name + '.py'))
            asset_root = scratch / label / 'assets'
            asset_root.mkdir(parents=True)
            resource = scratch_asset(asset_root)
            content = modules['test_approved_content_manifest']
            original_pins = content.check_pins
            # Keep the complete test and its live native smoke; only redirect
            # the Python pin read to the private resource inventory.
            def pins(test, manifest):
                return original_pins(test, manifest, root=asset_root)
            content.check_pins = pins

            tool_root = scratch / label / 'tools'
            tool_root.mkdir(parents=True)
            # The copied scheduler loads its unchanged registry from here.
            (tool_root.parent / 'tests').symlink_to(ROOT / 'tests', target_is_directory=True)
            scheduler_path = tool_root / 'program_suite_runner.py'
            scheduler = replace_line((ROOT / 'tools/program_suite_runner.py').read_text(),
                'SUPPLEMENTAL_BY_NAME.get(name, {}).get("group") != "perf"',
                'SUPPLEMENTAL_BY_NAME.get(name, {}).get("group") == "perf"')
            scheduler_path.write_text(scheduler)
            modules['test_program_suite_runner'].runner = load_source(
                'test07_mutated_scheduler', scheduler, scheduler_path)
            runner_path = tool_root / 'run_python_suite.py'
            runner = replace_line((ROOT / 'tools/run_python_suite.py').read_text(),
                "if not isinstance(result, dict) or result.get('invocation_id') != invocation_id:",
                'if not isinstance(result, dict):')
            runner_path.write_text(runner)
            modules['test_python_suite_runner_feedback'].runner = load_source(
                'test07_mutated_python_runner', runner, runner_path)

            cases = [content.ApprovedContentManifestTests('test_approved_content'),
                     modules['test_program_suite_runner'].ProgramSuiteRunnerTests(
                         'test_perf_selection_preserves_functional_programs'),
                     modules['test_python_suite_runner_feedback'].RunnerFeedbackTests(
                         'test_mismatched_invocation_is_rejected_with_its_log')]
            expected_markers = [('Changed approved asset: ' + resource,),
                                ('functional', 'speed'), ("KeyError: 'tests'",)]
            for test, markers in zip(cases, expected_markers):
                log = io.StringIO()
                result = unittest.TextTestRunner(stream=log).run(unittest.TestSuite([test]))
                failed = [case.id() for case, _ in result.failures]
                errors = [case.id() for case, _ in result.errors]
                expected_failure = all(marker in log.getvalue() for marker in markers)
                records.append(dict(version=label, id=test.id(), failures=failed,
                                    errors=errors,
                                    expected_failure=expected_failure, log=log.getvalue()))
                print(f'MUTATION {label}: {test.id()}: '
                      f'{"DETECTED" if failed + errors == [test.id()] and expected_failure else "MISSED"}')
        output.parent.mkdir(parents=True, exist_ok=True)
        output.write_text(json.dumps(dict(asset_mutation=resource, results=records), indent=2) + '\n')
    return 0 if all(row['failures'] + row['errors'] == [row['id']] and row['expected_failure']
                    for row in records) else 1


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--before-source-dir', required=True, type=Path)
    parser.add_argument('--output', required=True, type=Path)
    args = parser.parse_args()
    return run(args.before_source_dir, args.output)


if __name__ == '__main__':
    raise SystemExit(main())
