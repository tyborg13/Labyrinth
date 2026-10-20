"""Real committed mutations exercise the superseded Mimic assertions.

All Git writes are confined to disposable test repositories. The implementation
worktree is never staged, committed, or switched by these tests.
"""
import hashlib
import json
from pathlib import Path
import subprocess
import tempfile
import unittest
from unittest.mock import patch

from tests import rr29_historical_mimic as history
from tests import test_rr28_continuations as rr28
from tests.test_rr20_cutout import rr20
from rr20_preservation import own_input_errors

ROOT=history.PROJECT
FIXTURE={'input':'spec/rr29_historical_fixture.json','bytes':b'approved input\n',
    'mutation':b'changed inside unit range\n', 'position_delta_px':1}


class HistoricalRangeTests(unittest.TestCase):
    def setUp(self):
        self.temporary=tempfile.TemporaryDirectory(prefix='rr29-range-',dir=ROOT/'tests')
        self.addCleanup(self.temporary.cleanup)
        self.project=Path(self.temporary.name).resolve()
        self.git('init','-q');self.git('config','user.name','Preservation fixture')
        self.git('config','user.email','fixture@example.invalid');self.git('config','commit.gpgsign','false')

    def git(self,*args):
        return subprocess.check_output(['git',*args],cwd=self.project).decode().strip()

    def commit(self):
        self.git('add','.');self.git('commit','-qm','rr29 disposable range fixture')
        return self.git('rev-parse','HEAD')

    def write(self,name,raw):
        path=self.project/name;path.parent.mkdir(parents=True,exist_ok=True);path.write_bytes(raw)

    def test_rr20_own_input_pin_catches_in_range_change_and_ignores_later_tree(self):
        inventory='experiments/cutouts/hollow_mimic/rr20/protected_inputs.json'
        self.write(FIXTURE['input'],FIXTURE['bytes'])
        self.write(inventory,json.dumps({FIXTURE['input']:hashlib.sha256(FIXTURE['bytes']).hexdigest()}).encode())
        unit=self.commit()
        self.assertEqual(own_input_errors(self.project,unit),[])
        self.write(FIXTURE['input'],FIXTURE['mutation']);mutant=self.commit()
        expected=['Protected/baseline bytes changed: '+FIXTURE['input']]
        self.assertEqual(own_input_errors(self.project,mutant),expected)
        self.write(FIXTURE['input'],FIXTURE['bytes']);self.commit()
        self.assertEqual(own_input_errors(self.project,mutant),expected)
        self.write(FIXTURE['input'],FIXTURE['mutation'])
        self.assertEqual(own_input_errors(self.project,unit),[])
        print('RR29 RR20 RANGE MUTATION: PASS (in-range input caught; later commits and working bytes ignored)')

    def test_rr28_actual_layout_assertion_catches_own_range_mutation_after_repair(self):
        prefixes=['assets/units/hollow_mimic_cutout','experiments/cutouts/hollow_mimic/rr20',
            'experiments/cutouts/hollow_mimic/rr28']
        from io import BytesIO
        import tarfile
        from rr28_build import BASE_REVISION
        def copy_revision(revision):
            existing=prefixes[:2] if revision==BASE_REVISION else prefixes
            blob=subprocess.check_output(['git','archive',revision,'--',*existing],cwd=ROOT)
            with tarfile.open(fileobj=BytesIO(blob)) as files:
                for member in files:
                    if member.isfile():self.write(member.name,files.extractfile(member).read())
        copy_revision(BASE_REVISION);baseline=self.commit()
        copy_revision(history.UNIT_ENDS['rr28']);unit=self.commit()
        case=self.project/prefixes[1];assets=self.project/prefixes[0];recipe=self.project/prefixes[2]
        def assert_original(end):
            with patch.object(history,'PROJECT',self.project), \
                    patch.dict(history.UNIT_ENDS,{'rr28':end}), \
                    patch.object(rr28,'RIGS',{'mimic':('hollow_mimic','rr20')}), \
                    patch.object(rr28,'paths',return_value=(case,assets,recipe)), \
                    patch.object(rr28,'committed',side_effect=lambda p:subprocess.check_output(
                        ['git','show',baseline+':'+str(p.relative_to(self.project))],cwd=self.project)):
                rr28.JointContinuationTests('test_replay_is_idempotent_and_only_recipes_change_in_all_layout_copies').test_replay_is_idempotent_and_only_recipes_change_in_all_layout_copies()
        assert_original(unit)
        path=assets/'front.json';original=path.read_bytes();changed=json.loads(original)
        changed['joints']['head']['position'][0]+=FIXTURE['position_delta_px'];path.write_text(json.dumps(changed))
        mutant=self.commit()
        with self.assertRaises(AssertionError):assert_original(mutant)
        path.write_bytes(original);self.commit()
        with self.assertRaises(AssertionError):assert_original(mutant)
        path.write_text(json.dumps(changed));assert_original(unit)
        print('RR29 RR28 RANGE MUTATION: PASS (actual layout assertion rejects in-range edit; later repair cannot hide it)')


if __name__=='__main__':unittest.main()
