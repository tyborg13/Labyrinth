"""Discovery with task isolation, no Git writes, and bounded failure diagnostics.

Only failure formatting is bounded: assertions still fail on the same unequal
values. Huge historical mesh-dictionary diffs otherwise spend minutes in difflib.
"""
import os
from pathlib import Path
import subprocess
import sys
import unittest
from unittest.mock import patch

ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT))
os.environ['LABYRINTH_TASK_ID']='rr-29'
from tests import rr20_regression_runner as inherited
inherited.TASK_ID='rr-29'
inherited.READ_ONLY_GIT=True
PROOF_DEFAULTS={'max_dictionary_diff_repr_chars':4000}
original_run=subprocess.run
original_dict_equal=unittest.TestCase.assertDictEqual
invocations=0


def task_run(command,*args,**kwargs):
    global invocations
    if isinstance(command,(tuple,list)) and 'tools/godot_task_runner.py' in command and 'godot' in command:
        command=list(command)
        command[command.index('--task-id')+1]='rr-29'
        invocations+=1
    # Reuse the established no-Git-write guard, without retagging fake engines
    # used by the runner's own task-ID tests.
    if isinstance(command,(tuple,list)) and command and command[0]=='git' and any(v in inherited.GIT_WRITE_COMMANDS for v in command[1:]):
        raise AssertionError('Director forbids Git writes in verification: '+str(command))
    return original_run(command,*args,**kwargs)


def bounded_dict_equal(self,first,second,msg=None):
    if isinstance(first,dict) and isinstance(second,dict) and first!=second and len(repr(first))+len(repr(second))>PROOF_DEFAULTS['max_dictionary_diff_repr_chars']:
        self.fail(self._formatMessage(msg,'Dictionaries differ (large mesh diff omitted; original equality assertion preserved)'))
    return original_dict_equal(self,first,second,msg)


if __name__=='__main__':
    if len(sys.argv)>1:suite=unittest.defaultTestLoader.loadTestsFromNames(sys.argv[1:])
    else:suite=unittest.defaultTestLoader.discover(str(ROOT/'tests'),pattern='test_*.py')
    inherited.skip_git_write_fixtures(suite)
    with patch('subprocess.run',task_run),patch.object(unittest.TestCase,'assertDictEqual',bounded_dict_equal):
        result=unittest.TextTestRunner(verbosity=2).run(suite)
    print('RR29 PYTHON %s: %s (%d Godot invocations forced to rr-29)' %
          ('FOCUSED' if len(sys.argv)>1 else 'FULL SUITE','PASS' if result.wasSuccessful() else 'FAIL',invocations))
    raise SystemExit(int(not result.wasSuccessful()))
