"""Real resolver -> RunScene playback for both views and all copied attack kinds."""
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
import subprocess
import sys
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path[:0] = [str(ROOT/'tools'), str(ROOT/'experiments/cutouts/hollow_mimic')]
from case import CASE, read_json
import production as rr20_production

PROOF_TIMEOUT_SECONDS = 180
PROOF_WORKERS = 2
PROOF_CARDS = ('whirlwind_slash', 'quick_stab', 'hurl_spear')
PROOF_VIEWS = ('front', 'rear')
EPSILON = 0.000001


def capture(pair):
    view, card = pair
    output = CASE/'proof/production_logic'/view/card
    result = subprocess.run([sys.executable,'tools/godot_task_runner.py','--task-id','rr-20','--stream','--',
        'godot','--headless','--path','.','--script','tests/rr20/production_capture.gd','--','--type','hollow_mimic',
        '--view',view,'--mirror-card',card,'--output',str(output),'--logic-only'],
        cwd=ROOT,capture_output=True,text=True,timeout=PROOF_TIMEOUT_SECONDS)
    (CASE/f'proof/logs/production_{view}_{card}.log').write_text(result.stdout+result.stderr)
    if result.returncode: raise AssertionError(result.stdout+result.stderr)
    report = read_json(output/'logic_frames.json')
    failures = rr20_production.errors(report)
    if failures: raise AssertionError(str(pair)+': '+str(failures))
    return pair, report


class ProductionTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        (CASE/'proof/logs').mkdir(parents=True,exist_ok=True)
        with ThreadPoolExecutor(max_workers=PROOF_WORKERS) as pool:
            cls.reports = dict(pool.map(capture, [(v,c) for v in PROOF_VIEWS for c in PROOF_CARDS]))

    def test_every_real_production_clip_contact_outcome_and_recovery(self):
        for pair, report in self.reports.items():
            self.assertTrue(report['ok'],pair)
            self.assertFalse(report['native_pixels'])
            self.assertEqual(rr20_production.errors(report),[],pair)
            for clip in ('idle','bolt','mirror','block','hit','death'):
                rows = [r for r in report['frames'] if r['stage']==clip]
                self.assertEqual({r['snapshot']['facing'] for r in rows},{pair[0]},(pair,clip))
            # Retreat faces away; both commands together cover both move views.
            move = [r for r in report['frames'] if r['stage']=='move']
            self.assertEqual({r['snapshot']['facing'] for r in move},{'rear' if pair[0]=='front' else 'front'})

    def test_existing_shade_bolt_and_block_cues_are_requested_once_at_contact(self):
        for pair, report in self.reports.items():
            for clip, at, cue in [('bolt',.45,'spell.shadow'),('block',.4,'block.gain')]:
                contact = next(r for r in report['frames'] if r['stage']==clip and abs(r['snapshot']['phase']-at)<EPSILON)
                self.assertEqual(sum(c['cue']==cue for c in contact['sfx_cues']),1,(pair,clip))
                self.assertNotIn('shot.bow',[c['cue'] for c in contact['sfx_cues']],pair)

    def test_mirror_contact_preserves_the_copied_effect_kind(self):
        expected = {'whirlwind_slash':'aoe','quick_stab':'melee','hurl_spear':'ranged'}
        for (view, card), report in self.reports.items():
            contact = next(r for r in report['frames'] if r['stage']=='mirror' and abs(r['snapshot']['phase']-.5)<EPSILON)
            self.assertEqual(contact['effect']['kind'],expected[card],(view,card))
            self.assertTrue(contact['effect']['en06_mirror'])
            self.assertEqual(contact['snapshot']['clip'],'mirror')

    def test_missing_cue_early_vfx_and_missing_contact_mutations_fail(self):
        import copy
        source = self.reports[('front','hurl_spear')]
        mutant = copy.deepcopy(source)
        for row in mutant['frames']:
            if row['stage']=='bolt':row['sfx_cues']=[]
        self.assertIn('bolt: missing existing cue at contact',rr20_production.errors(mutant))
        mutant = copy.deepcopy(source)
        next(r for r in mutant['frames'] if r['stage']=='mirror' and r['snapshot']['phase']<.5)['effect']={'kind':'ranged'}
        self.assertIn('mirror: VFX before contact',rr20_production.errors(mutant))
        mutant = copy.deepcopy(source)
        mutant['frames']=[r for r in mutant['frames'] if not (r['stage']=='mirror' and abs(r['snapshot']['phase']-.5)<EPSILON)]
        self.assertIn('mirror: missing real contact frame',rr20_production.errors(mutant))


if __name__ == '__main__': unittest.main()
