"""Run inherited focused tests through this worktree's mandated task runner ID."""
import os
from pathlib import Path
import subprocess
import sys
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
TASK_ID = os.environ.get('LABYRINTH_TASK_ID', 'rr-26')
MODULES = ('tests.test_rr14_anatomy', 'tests.test_rr14_bone_guards', 'tests.test_rr14_foundations')
original_run = subprocess.run
runner_invocations = 0
READ_ONLY_GIT = '--read-only-git' in sys.argv
GIT_WRITE_FIXTURES = {
    'tests.test_rr18_humanoid.MirrorTests.test_committed_protected_mutation_is_caught',
}
GIT_WRITE_COMMANDS = {'init', 'add', 'commit', 'merge', 'checkout', 'switch', 'stash', 'reset', 'rebase', 'push', 'update-index'}


def task_run(command, *args, **kwargs):
    global runner_invocations
    if (READ_ONLY_GIT and isinstance(command, (list, tuple)) and command and command[0] == 'git'
            and any(value in GIT_WRITE_COMMANDS for value in command[1:])):
        raise AssertionError('Director forbids Git writes in this verification run: ' + str(command))
    if isinstance(command, (list, tuple)) and 'tools/godot_task_runner.py' in command:
        command = list(command)
        command[command.index('--task-id') + 1] = TASK_ID
        runner_invocations += 1
    return original_run(command, *args, **kwargs)


def skip_git_write_fixtures(suite):
    for test in suite:
        if isinstance(test, unittest.TestSuite):
            skip_git_write_fixtures(test)
        elif test.id() in GIT_WRITE_FIXTURES:
            name = test._testMethodName
            method = getattr(type(test), name)
            setattr(type(test), name, unittest.skip('Director forbids Git writes, including disposable fixture commits')(method))


if __name__ == '__main__':
    os.environ['LABYRINTH_TASK_ID'] = TASK_ID
    modules = [value for value in sys.argv[1:] if value != '--read-only-git']
    suite = unittest.defaultTestLoader.loadTestsFromNames(modules or MODULES)
    if READ_ONLY_GIT: skip_git_write_fixtures(suite)
    with patch('subprocess.run', task_run):
        result = unittest.TextTestRunner().run(suite)
    print('RR20 INHERITED RUNNERS: %s (%d Godot invocations forced to %s)' %
          ('PASS' if result.wasSuccessful() else 'FAIL', runner_invocations, TASK_ID))
    raise SystemExit(int(not result.wasSuccessful()))
