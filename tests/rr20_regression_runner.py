"""Run inherited focused tests through this worktree's mandated task runner ID."""
import os
from pathlib import Path
import subprocess
import sys
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
TASK_ID = 'rr-20'
MODULES = ('tests.test_rr14_anatomy', 'tests.test_rr14_bone_guards', 'tests.test_rr14_foundations')
original_run = subprocess.run
runner_invocations = 0


def task_run(command, *args, **kwargs):
    global runner_invocations
    if isinstance(command, (list, tuple)) and 'tools/godot_task_runner.py' in command:
        command = list(command)
        command[command.index('--task-id') + 1] = TASK_ID
        runner_invocations += 1
    return original_run(command, *args, **kwargs)


if __name__ == '__main__':
    os.environ['LABYRINTH_TASK_ID'] = TASK_ID
    suite = unittest.defaultTestLoader.loadTestsFromNames(sys.argv[1:] or MODULES)
    with patch('subprocess.run', task_run):
        result = unittest.TextTestRunner().run(suite)
    print('RR20 INHERITED RUNNERS: %s (%d Godot invocations forced to rr-20)' %
          ('PASS' if result.wasSuccessful() else 'FAIL', runner_invocations))
    raise SystemExit(int(not result.wasSuccessful()))
