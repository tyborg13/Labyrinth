"""Discovery with task isolation, protected task Git, and bounded diagnostics.

Only failure formatting is bounded: assertions still fail on the same unequal
values. Huge historical mesh-dictionary diffs otherwise spend minutes in difflib.
"""
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT))
os.environ['LABYRINTH_TASK_ID']='rr-29'
from tests import rr20_regression_runner as inherited
inherited.TASK_ID='rr-29'
PROOF_DEFAULTS={'max_dictionary_diff_repr_chars':4000}
# Existing preserved-mutation test creates a disposable repo in its ignored
# proof tree rather than tempfile's system directory.
PROOF_GIT_FIXTURE={'parent':ROOT/'experiments/cutouts/glacial_mirror/rr18/proof',
    'prefix':'rr23-preservation-'}
original_run=subprocess.run
original_dict_equal=unittest.TestCase.assertDictEqual
invocations=0


def task_run(command,*args,**kwargs):
    global invocations
    if isinstance(command,(tuple,list)) and 'tools/godot_task_runner.py' in command and 'godot' in command:
        command=list(command)
        command[command.index('--task-id')+1]='rr-29'
        invocations+=1
    # Disposable repositories are part of the authorized full suite. Never
    # permit those fixture operations to reach this implementation worktree.
    if isinstance(command,(tuple,list)) and command and command[0]=='git' and any(v in inherited.GIT_WRITE_COMMANDS for v in command[1:]):
        directory=Path(kwargs.get('cwd',Path.cwd())).resolve()
        if '-C' in command:directory=(directory/command[command.index('-C')+1]).resolve()
        if 'init' in command:
            arguments=command[command.index('init')+1:]
            # A bare-remote fixture can name its destination while running
            # from ROOT. Accept only this explicit, simple init syntax.
            if (arguments and not str(arguments[-1]).startswith('-') and
                    all(v in ('-q','--quiet','--bare') for v in arguments[:-1])):
                directory=(directory/arguments[-1]).resolve()
        protected=original_run(['git','rev-parse','--path-format=absolute','--git-common-dir'],cwd=ROOT,capture_output=True,text=True,check=True).stdout.strip()
        actual=(original_run(['git','rev-parse','--path-format=absolute','--git-common-dir'],cwd=directory,capture_output=True,text=True)
            if directory.is_dir() else None)
        isolated=actual is not None and actual.returncode==0 and Path(actual.stdout.strip()).resolve()!=Path(protected).resolve()
        new_fixture=('init' in command and directory!=ROOT and
            (directory.is_relative_to(ROOT/'tests') or directory.is_relative_to(Path('/private/tmp')) or
             directory.is_relative_to(Path(tempfile.gettempdir()).resolve()) or
             (directory.parent==PROOF_GIT_FIXTURE['parent'] and directory.name.startswith(PROOF_GIT_FIXTURE['prefix']))))
        if not isolated and not new_fixture:
            raise AssertionError('Director forbids task-worktree Git writes: '+str(command))
    return original_run(command,*args,**kwargs)


def bounded_dict_equal(self,first,second,msg=None):
    if isinstance(first,dict) and isinstance(second,dict) and first!=second and len(repr(first))+len(repr(second))>PROOF_DEFAULTS['max_dictionary_diff_repr_chars']:
        self.fail(self._formatMessage(msg,'Dictionaries differ (large mesh diff omitted; original equality assertion preserved)'))
    return original_dict_equal(self,first,second,msg)


if __name__=='__main__':
    if len(sys.argv)>1:suite=unittest.defaultTestLoader.loadTestsFromNames(sys.argv[1:])
    else:suite=unittest.defaultTestLoader.discover(str(ROOT/'tests'),pattern='test_*.py')
    with patch('subprocess.run',task_run),patch.object(unittest.TestCase,'assertDictEqual',bounded_dict_equal):
        result=unittest.TextTestRunner(verbosity=2).run(suite)
    print('RR29 PYTHON %s: %s (%d Godot invocations forced to rr-29)' %
          ('FOCUSED' if len(sys.argv)>1 else 'FULL SUITE','PASS' if result.wasSuccessful() else 'FAIL',invocations))
    raise SystemExit(int(not result.wasSuccessful()))
