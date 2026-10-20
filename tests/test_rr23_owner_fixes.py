"""Regress the approved repaint's terminals, guard priority and air limits."""
import copy
from pathlib import Path
import sys
import unittest

import numpy as np

PROJECT=Path(__file__).resolve().parents[1]
sys.path[:0]=[str(PROJECT/'tools'),str(PROJECT/'experiments/cutouts/glacial_mirror')]
from rr18_case import CASE
from cutout_pipeline.cases import read_json
from rr23_checks import ankle_report, arm_report
from rr23_geometry import front_arm_order
from rr23_preservation import BASELINE_COMMIT

FIXTURE_DISCONNECTED_FOOT_PX=100
FIXTURE_RGBA=(80,90,110,255)


class OwnerFixTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        from tests.test_rr18_humanoid import godot
        import tempfile
        with tempfile.TemporaryDirectory(prefix='rr23-samples-',dir=CASE/'proof') as folder:
            path=Path(folder)/'samples.json'
            godot('tests/rr18/action_direction.gd','--case',CASE,'--output',path)
            cls.samples=read_json(path)
        cls.layouts={v:read_json(CASE/f'layouts/{v}.json') for v in ('front','rear')}

    def test_every_presented_ankle_stays_attached_in_every_clip(self):
        for view,layout in self.layouts.items():
            result=ankle_report(layout,self.samples)
            self.assertEqual(result['errors'],[],view)
            self.assertEqual(set(result['clip_maxima']),set(read_json(CASE/'compiled_motion.json')['clips']))
            self.assertTrue(all(value>0 for value in result['rest_overlap_pixels'].values()))

    def test_both_painted_fists_and_guard_contact_order(self):
        for view,layout in self.layouts.items():
            result=arm_report(layout,self.samples)
            self.assertEqual(result['errors'],[],view)
            for side in ('near','far'):
                self.assertGreater(result['painted_fists'][side]['width_px'],0)
                self.assertGreater(result['painted_fists'][side]['height_px'],0)
            self.assertEqual(read_json(CASE/'proof/build.json')['views']['front']['guard_order']['rest_order_mismatch_pixels'],0)

    def test_disconnected_non_walk_ankle_mutation_is_caught(self):
        samples=copy.deepcopy(self.samples)
        row=next(r for r in samples['samples'] if r['view']=='front' and r['clip']=='death' and r['kind']=='presented')
        for name in ('foot_near','hidden_foot_near'):
            row['parts'][name]['transform'][4]+=FIXTURE_DISCONNECTED_FOOT_PX
        samples['samples']=[row]
        self.assertTrue(any('ankle air' in e for e in ankle_report(self.layouts['front'],samples)['errors']))

    def test_wrong_front_guard_depth_mutation_is_caught(self):
        layout=copy.deepcopy(self.layouts['front'])
        for part in layout['parts']:
            if part['name'] in ('fore_near','fist_near'):part['z_index']=-1
        self.assertIn('fist_near must draw above torso',arm_report(layout,self.samples)['errors'])

    def test_order_change_that_alters_rest_stops_with_design_placeholder(self):
        image=np.zeros((255,255,4),dtype=np.uint8)
        image[0,0]=FIXTURE_RGBA
        front=image.copy();front[0,0,0]+=1
        visible={'head':front,'torso':front,'fore_near':image,'fist_near':image}
        with self.assertRaisesRegex(ValueError,'TODO_DESIGN_near_arm_order'):
            front_arm_order(visible,{}, {'fist_near':0,'fore_near':1,'torso':2,'head':3})

    def test_shared_records_retain_every_other_figure(self):
        import json
        import subprocess
        for relative in ('spec/art_identity/registry.json','spec/assets/board_pixel_density/registry.json',
                         'spec/assets/board_pixel_density/outputs.json'):
            before=json.loads(subprocess.check_output(['git','show',BASELINE_COMMIT+':'+relative],cwd=PROJECT))
            current=read_json(PROJECT/relative)
            if relative.endswith('outputs.json'):
                def protected(data):return {k:v for k,v in data.items() if '/glacial_mirror_cutout/' not in k}
            else:
                def protected(data):
                    data=copy.deepcopy(data)
                    data['entries']=[e for e in data['entries'] if e.get('id') not in ('glacial_mirror','glacial_mirror_cutout')]
                    return data
            self.assertEqual(protected(before),protected(current),relative)

    def test_shadows_retain_every_other_figure_against_pinned_baseline(self):
        import subprocess
        import tempfile
        from tests.test_rr18_humanoid import godot
        with tempfile.TemporaryDirectory(prefix='rr23-shadow-',dir=CASE/'proof') as folder:
            baseline=Path(folder)/'baseline.res'
            baseline.write_bytes(subprocess.check_output(['git','show',BASELINE_COMMIT+':assets/generated/unit_shadow_cache.res'],cwd=PROJECT))
            self.assertIn('RR23 SHADOW PRESERVATION: PASS',godot('tests/rr18/shadow_refresh.gd','--check-baseline',baseline))

    def test_all_mirror_motion_bytes_match_the_pinned_baseline(self):
        import subprocess
        from rr18_case import ASSETS
        for root in (CASE,ASSETS/'humanoid_v2'):
            for name in ('director_motion.json','compiled_motion.json'):
                path=root/name
                relative=str(path.relative_to(PROJECT))
                before=subprocess.check_output(['git','show',BASELINE_COMMIT+':'+relative],cwd=PROJECT)
                self.assertEqual(path.read_bytes(),before,relative)


if __name__=='__main__':unittest.main(verbosity=2)
