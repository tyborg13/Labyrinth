"""Run only rr-16's directed Python proof, with all nested Godot calls isolated."""
import os
from pathlib import Path
import subprocess
import sys
import unittest
from unittest.mock import patch

PROJECT = Path(__file__).resolve().parents[3]
TASK_ID = 'rr-16'
PATTERNS = ('test_rr11*.py', 'test_rr14*.py', 'test_rr15*.py', 'test_rr10*.py',
            'test_rr07_production.py', 'test_rr16*.py', 'test_godot_sidecars.py',
            'test_test_registration_audit.py')


def main():
    os.environ['LABYRINTH_TASK_ID'] = TASK_ID
    sys.path.insert(0, str(PROJECT))
    # The historical rr14 tests use a literal task ID. Redirect only task-runner
    # invocations here; preserve their commands, assertions and fixture inputs.
    original_run = subprocess.run
    def task_run(command, *args, **kwargs):
        if isinstance(command, list) and any(str(arg).endswith('tools/godot_task_runner.py') for arg in command):
            command = list(command)
            index = command.index('--task-id')
            command[index + 1] = TASK_ID
        return original_run(command, *args, **kwargs)
    suite = unittest.TestSuite()
    for pattern in PATTERNS:
        names = ['tests.' + path.stem for path in sorted((PROJECT / 'tests').glob(pattern))]
        suite.addTests(unittest.defaultTestLoader.loadTestsFromNames(names))
    with patch.object(subprocess, 'run', task_run):
        result = unittest.TextTestRunner(verbosity=2).run(suite)
    return int(not result.wasSuccessful())


if __name__ == '__main__':
    raise SystemExit(main())
