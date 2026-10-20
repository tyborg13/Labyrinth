"""Run the directed Thrall and canonical source/record tests in rr-27."""
import os
from pathlib import Path
import subprocess
import sys
import unittest
from unittest.mock import patch

PROJECT = Path(__file__).resolve().parents[3]
MODULES = ('test_rr11_humanoid', 'test_rr15_shoulder', 'test_rr15_native_cleanup',
    'test_rr15_action_direction', 'test_rr15_reach', 'test_rr15_view_keys',
    'test_rr16_feedback1', 'test_rr16_review_fixes', 'test_gait01', 'test_rr24_thrall',
    'test_arc_thrall_maquette_r2', 'test_arc_thrall_proof_validation',
    'test_rr22_source_space', 'test_rr26_consolidation', 'test_rr27_thrall')


def main():
    os.environ['LABYRINTH_TASK_ID'] = 'rr-27'
    sys.path.insert(0, str(PROJECT))
    original = subprocess.run

    def task_run(command, *args, **kwargs):
        if isinstance(command, list) and any(str(a).endswith('tools/godot_task_runner.py') for a in command):
            command = list(command)
            command[command.index('--task-id') + 1] = 'rr-27'
        return original(command, *args, **kwargs)

    suite = unittest.defaultTestLoader.loadTestsFromNames(['tests.' + name for name in MODULES])
    # The canonical-record test otherwise assumes Mimic's ignored log folder
    # has already been generated. Keep its temporary evidence in this unit.
    record_logs = PROJECT / 'experiments/cutouts/arc_thrall/rr27/record_test_logs'
    record_logs.mkdir(exist_ok=True)
    with patch.object(subprocess, 'run', task_run), patch('tests.test_rr26_consolidation.LOG', record_logs):
        result = unittest.TextTestRunner(verbosity=2).run(suite)
    return int(not result.wasSuccessful())


if __name__ == '__main__':
    raise SystemExit(main())
