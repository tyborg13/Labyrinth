"""mq7b source, collar, skirt and guard-removal regressions; no GUI."""
from copy import deepcopy
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

import numpy as np
from PIL import Image

PROJECT=Path(__file__).resolve().parents[1]
sys.path[:0]=[str(PROJECT/'tools'),str(PROJECT/'experiments/cutouts/arc_thrall')]
from rr24_build import CASE, RECIPE, BASELINE, read_json, residue, clean_residue, source_pixels
from rr24_check import source_errors, collar_report, hem_report
from rr24_crops import compose
from humanoid_cutout.gates import source_errors as cut_errors

FIXTURE_GREEN=(0,26,7,255)
FIXTURE_OLIVE=(35,51,37,255)  # Approved collar paint; preserved by ratio rule.
FIXTURE_SKIN=(100,70,50,255)
FIXTURE_HEAD_DROP_PX=10
FIXTURE_HEM_SHIFT_PX=10
FIXTURE_FOREIGN_FILL_RGBA=(255,0,255,255)
LANDMARKS={'front':{'torso':[(109,103),(130,85)],'loincloth':[(125,139),(126,175)],
                    'leg_near':[(155,177)]},
           'rear':{'torso':[(145,59)],'loincloth':[(125,128),(125,157)],
                   'leg_far':[(155,177)]}}


class ThrallOwnerFixTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.layouts={v:read_json(CASE/f'layouts/{v}.json') for v in ('front','rear')}
        cls.samples=read_json(CASE/'proof/samples.json')
        cls.build=read_json(CASE/'proof/build.json')

    def test_raw_paint_and_cleaned_rests_are_independently_exact(self):
        for view,layout in self.layouts.items():
            self.assertEqual(source_errors(view,layout),[])
            self.assertEqual(cut_errors(CASE,layout,self.build),[])
            raw=np.asarray(Image.open(CASE/layout['raw_rest_source']).convert('RGBA'))
            expected=np.asarray(Image.open(PROJECT/f'spec/art_identity/jobs/arc_thrall/mq7b_{view}/processed.png').convert('RGBA'))
            np.testing.assert_array_equal(raw,expected)
            self.assertEqual(self.build['views'][view]['raw_rest_mismatch_pixels'],0)

    def test_painted_landmarks_follow_their_required_piece(self):
        for view,groups in LANDMARKS.items():
            layout=self.layouts[view]
            for name,points in groups.items():
                image=source_pixels(CASE,next(p for p in layout['parts'] if p['name']==name))
                for x,y in points:self.assertGreater(image[y,x,3],0,(view,name,x,y))

    def test_reassigning_collar_to_head_is_caught(self):
        for view,original in self.layouts.items():
            mutant=deepcopy(original)
            next(p for p in mutant['parts'] if p['name']=='torso')['bone']='head'
            self.assertIn('collar must remain rigid torso',source_errors(view,mutant))

    def test_reversing_skirt_depth_is_caught_in_both_views(self):
        for view,original in self.layouts.items():
            mutant=deepcopy(original)
            next(p for p in mutant['parts'] if p['name']=='loincloth')['z_index']=-100
            self.assertIn('skirt must cover both thighs',source_errors(view,mutant))

    def test_cloth_chain_and_motion_cannot_be_silently_changed(self):
        for view,original in self.layouts.items():
            mutant=deepcopy(original)
            mesh=next(m for m in mutant['joint_meshes'] if m['name']=='loincloth')
            mesh['weights']={'head':mesh['weights']['pelvis']}
            self.assertIn('skirt chain differs',source_errors(view,mutant))
            self.assertEqual(original['joints'],read_json(BASELINE/f'layouts/{view}.json')['joints'])
        # Director rr-27 feedback 2 authorizes only rear Tether's two channels.
        from rr27_tether_identity import motion_is_exact
        self.assertTrue(motion_is_exact(str((CASE/'compiled_motion.json').relative_to(PROJECT)),
                                       (BASELINE/'compiled_motion.json').read_bytes()))

    def test_green_rule_preserves_olive_and_uses_same_piece_donors(self):
        fixture=np.array([[FIXTURE_GREEN,FIXTURE_OLIVE,FIXTURE_SKIN]],dtype=np.uint8)
        cleaned,records=clean_residue(fixture)
        self.assertEqual(residue(fixture).tolist(),[[True,False,False]])
        self.assertFalse(residue(cleaned).any())
        self.assertEqual(records,[{'target':[0,0],'donor':[1,0]}])
        np.testing.assert_array_equal(cleaned[0,0],FIXTURE_OLIVE)
        np.testing.assert_array_equal(cleaned[0,1:],fixture[0,1:])

    def test_foreign_hidden_thigh_fill_is_rejected(self):
        for view,layout in self.layouts.items():
            def contaminated(case,part):
                image=source_pixels(case,part)
                if part['name']=='hidden_leg_near':
                    y,x=np.argwhere(image[...,3]>0)[0]
                    image[y,x]=FIXTURE_FOREIGN_FILL_RGBA
                return image
            with patch('rr24_check.source_pixels',side_effect=contaminated):
                self.assertIn('hidden fill must use own skin: hidden_leg_near',source_errors(view,layout))

    def test_contact_allowed_but_reversed_head_ownership_is_caught(self):
        for view,layout in self.layouts.items():
            report=collar_report(view,layout,self.samples)
            self.assertTrue(report['ok'])
            self.assertTrue(report['contact_frames'])
            self.assertTrue(all(r['collar_over_head_pixels']==0 for r in report['rows']))
            mutant=deepcopy(layout)
            body=next(p for p in mutant['parts'] if p['name']=='torso')
            next(p for p in mutant['parts'] if p['name']=='head')['z_index']=body['z_index']-1
            self.assertFalse(collar_report(view,mutant,self.samples)['ok'])

    def test_contact_frames_are_reported_and_design_questions_are_resolved(self):
        report=collar_report('front',self.layouts['front'],self.samples)
        self.assertTrue(any(r['clip']=='death'and r['frame']==41 for r in report['contact_frames']))
        for name in ('TODO_DESIGN_COLLAR_DEATH_CLEARANCE','TODO_DESIGN_PRESENTED_NEGATIVE_SPACE'):
            self.assertNotIn(name,read_json(CASE/'inputs.json')['design_placeholders'])

    def test_hem_limit_settling_and_excessive_follow_through_mutation(self):
        for view,layout in self.layouts.items():
            self.assertTrue(hem_report(view,layout,self.samples)['ok'])
            mutant=deepcopy(self.samples)
            row=next(p for p in mutant['samples'] if p['view']==view and p['kind']=='presented' and p['clip']=='move')
            row['bones']['loincloth_tip']['global'][4]+=FIXTURE_HEM_SHIFT_PX
            self.assertFalse(hem_report(view,layout,mutant)['ok'])

    def test_crops_refuse_stale_or_non_native_capture(self):
        with tempfile.TemporaryDirectory(prefix='rr24-crop-fixture-') as folder:
            capture=Path(folder)
            (capture/'frames.json').write_text('{"native_pixels": false, "ok": true, "inputs": {}}')
            with self.assertRaisesRegex(ValueError,'Fresh, complete native capture'):
                compose(capture,capture/'output')


if __name__=='__main__':unittest.main(verbosity=2)
