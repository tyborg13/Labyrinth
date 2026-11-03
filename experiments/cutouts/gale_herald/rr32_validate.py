"""Reproduce rr32's focused headless checks; never run the full suites."""
import argparse
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from rr32_case import PROJECT, CASE

FAMILIES = {'herald': ['32'], 'seer': ['10', '13', '14'], 'thrall': ['11', '15', '16', '24', '27'],
            'mirror': ['18'], 'capacitor': ['17', '19'], 'weaver': ['21'],
            'mimic': ['26', '29'], 'mortar': ['22', '25', '30']}


def execute_suite(family):
    sys.path[:0] = [str(PROJECT), str(PROJECT / 'tests'), str(PROJECT / 'tools')]
    paths = sorted({p for prefix in FAMILIES[family] for p in (PROJECT / 'tests').glob('test_rr' + prefix + '_*.py')})
    with tempfile.TemporaryDirectory(prefix='rr32-regression-fixtures-') as folder:
        if family == 'mimic':
            # The rr26 test assumes this ignored folder already exists. Keep
            # its temporary fixture under this task's temp root; no source or
            # assertion changes, and no other figure's files are created.
            import tests.test_rr26_consolidation as consolidation
            consolidation.LOG = Path(folder)
        suite = unittest.defaultTestLoader.loadTestsFromNames(['tests.' + p.stem for p in paths])
        return int(not unittest.TextTestRunner().run(suite).wasSuccessful())


def commands(family):
    if family in FAMILIES:
        return [[sys.executable, str(Path(__file__).resolve()), '--execute-suite', family]]
    if family == 'sfx':
        return [[sys.executable, 'tools/godot_task_runner.py', '--task-id', os.environ.get('LABYRINTH_TASK_ID', 'rr-32'), '--stream', '--',
                 'godot', '--headless', '--path', '.', '--script', f'tests/suites/sfx_sync_{i}_program.gd'] for i in range(3)]
    if family == 'identity':
        return [[sys.executable, 'tests/test_art_identity_gate.py'], [sys.executable, 'tests/test_icon_identity_policy.py']]
    return [[sys.executable, 'tools/test_registration_audit.py', '--json', str(CASE / 'proof/registration_audit.json'),
             '--markdown', str(CASE / 'proof/registration_audit.md')]]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--family', choices=[*FAMILIES, 'sfx', 'identity', 'audit', 'all'], default='herald')
    parser.add_argument('--execute-suite', choices=list(FAMILIES), help=argparse.SUPPRESS)
    args = parser.parse_args()
    if args.execute_suite: return execute_suite(args.execute_suite)
    selected = [*FAMILIES, 'sfx', 'identity', 'audit'] if args.family == 'all' else [args.family]
    results = []
    for family in selected:
        for index, command in enumerate(commands(family)):
            path = CASE / f'proof/logs/validate_{family}_{index}.txt'
            path.parent.mkdir(parents=True, exist_ok=True)
            with path.open('w') as stream:
                result = subprocess.run(command, cwd=PROJECT, stdout=stream, stderr=subprocess.STDOUT,
                    env=dict(os.environ, LABYRINTH_TASK_ID=os.environ.get('LABYRINTH_TASK_ID', 'rr-32')))
            lines = [line for line in path.read_text().splitlines() if line.startswith(('Ran ', 'OK', 'FAILED', 'ERROR: test', 'FAIL: test')) or 'RESULT:' in line or 'AUDIT:' in line]
            results.append({'family': family, 'command': command, 'exit': result.returncode, 'result_lines': lines,
                            'transcript': str(path.relative_to(CASE))})
            print(f'RR32 {family.upper()}: exit {result.returncode}', flush=True)
            for line in lines: print(line, flush=True)
    (CASE / 'proof/validation_run.json').write_text(json.dumps(results, indent=2) + '\n')
    return int(any(row['exit'] for row in results))


if __name__ == '__main__': raise SystemExit(main())
