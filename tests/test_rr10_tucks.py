"""Feedback 4 source contracts, all-pose attachments and native seam mutations."""
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

import numpy as np
from PIL import Image

PROJECT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(PROJECT/'tools'))
from cutout_pipeline.cases import digest
from humanoid_cutout.gates import source_errors,EPSILON,matrix
from humanoid_cutout.mesh import CUFF_FORE_ROWS_PX
from humanoid_cutout.seam_proof import fixture_masks,seam_holes
from humanoid_cutout.tucks import TUCK_DEPTHS_PX

CASE=PROJECT/'experiments/cutouts/hoarfrost_seer/rr10'
FIXTURES=PROJECT/'tests/rr10/feedback4'
PROOF_TIMEOUT_SECONDS=180


def read(path):return json.loads(path.read_bytes())


class TuckTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.layout=read(CASE/'layouts/front.json')
        cls.build=read(CASE/'proof/build.json')
        cls.fixtures=read(FIXTURES/'captures.json')
        with tempfile.TemporaryDirectory(prefix='rr10-tuck-bones-') as folder:
            output=Path(folder)/'samples.json'
            process=subprocess.run([sys.executable,'tools/godot_task_runner.py','--task-id','rr-10','--stream','--',
                'godot','--headless','--path','.','--script','tests/rr10/samples.gd','--','--output',str(output)],
                cwd=PROJECT,capture_output=True,text=True,timeout=PROOF_TIMEOUT_SECONDS)
            if process.returncode:raise AssertionError(process.stdout+process.stderr)
            cls.samples=[r for r in read(output)['samples'] if r['view']=='front']
        cls.poses={(r['clip'],r['frame']):r for r in cls.samples if r['kind']=='presented'}

    def test_requested_depths_real_texels_and_unchanged_motion(self):
        expected={'hand_near':5,'hand_far':5,'foot_near':4,'foot_far':4,'robe':5}
        for name,depth in expected.items():
            self.assertEqual(TUCK_DEPTHS_PX[name],depth)
            tuck=next(t for t in self.build['tucks'] if t['piece']==name)
            self.assertEqual(tuck['minimum_px'],depth)
            self.assertEqual(tuck['missing_pixels'],0)
            self.assertGreater(tuck['required_pixels'],0)
        self.assertEqual(source_errors(CASE,self.layout,self.build),[])
        # Adding the approved rear does not change the protected front tracks.
        from humanoid_cutout.compiler import compile_motion
        current=read(CASE/'compiled_motion.json')
        front=compile_motion(CASE/'director_motion.json','hoarfrost_seer',{'front':self.layout},{'front':current['projection']['front']})
        import hashlib
        self.assertEqual(hashlib.sha256((json.dumps(front,indent=2)+'\n').encode()).hexdigest(), self.fixtures['compiled_motion_sha256'])

    def test_cuff_rows_are_entirely_forearm_weighted_on_both_sides(self):
        self.assertEqual(CUFF_FORE_ROWS_PX,4)
        for side in ('near','far'):
            mesh=next(m for m in self.layout['joint_meshes'] if m['name']=='sleeve_'+side)
            elbow,wrist=[np.asarray(self.layout['joints'][name+side]['position']) for name in ('fore_','hand_')]
            direction=(wrist-elbow)/np.linalg.norm(wrist-elbow)
            rows=np.sum((np.asarray(mesh['vertices'])-wrist)*direction,axis=1)>=-CUFF_FORE_ROWS_PX
            self.assertTrue(rows.any())
            self.assertTrue(np.all(np.asarray(mesh['weights']['fore_'+side])[rows]==1))
            self.assertTrue(np.all(np.asarray(mesh['weights']['upper_'+side])[rows]==0))

    def test_cuff_hand_and_hem_foot_attachments_at_every_sampled_pose(self):
        self.assertEqual(len(self.samples),629)
        maximum=0.
        for row in self.samples:
            for side in ('near','far'):
                fore,hand=[matrix(row['bones'][name+side]['global']) for name in ('fore_','hand_')]
                self.assertTrue(np.allclose(fore[:2,:2],hand[:2,:2],atol=EPSILON,rtol=0))
                wrist=np.asarray(self.layout['joints']['hand_'+side]['position'])
                elbow=np.asarray(self.layout['joints']['fore_'+side]['position'])
                displacement=(fore@[*list(wrist-elbow),1])[:2]-hand[:2,2]
                maximum=max(maximum,float(np.linalg.norm(displacement)))
                self.assertLess(np.linalg.norm(displacement),TUCK_DEPTHS_PX['hand_'+side])
                hem,foot=[matrix(row['bones'][name+side]['global']) for name in ('hem_','foot_')]
                self.assertTrue(np.allclose(hem[:2,:2],foot[:2,:2],atol=EPSILON,rtol=0))
        print('RR10 ATTACHMENT TRANSFORMS: PASS (%d poses; max wrist snap separation %.6f px)'%(len(self.samples),maximum))

    def check_fixture(self,record,replacement=None):
        masks=fixture_masks(FIXTURES,record)
        return seam_holes(CASE,self.layout,self.poses[record['clip'],record['frame']],masks,
                          self.fixtures['rigid_tucks'],replacement)

    def test_new_rigid_tucks_close_the_captured_wrist_and_foot_openings(self):
        for record in self.fixtures['frames']:
            with self.subTest(clip=record['clip'],frame=record['frame']):
                self.assertEqual(self.check_fixture(record),[])

    def test_wrist_mutation_reopens_mark_and_death_seams(self):
        for record in self.fixtures['frames']:
            if record['target']!='hidden_hand_far':continue
            masks=fixture_masks(FIXTURES,record)
            self.assertTrue(self.check_fixture(record,{record['target']:masks['regression_tuck']}))

    def test_foot_mutation_reopens_move_nine_seam(self):
        record=next(r for r in self.fixtures['frames'] if r['target']=='hidden_foot_near')
        masks=fixture_masks(FIXTURES,record)
        self.assertTrue(self.check_fixture(record,{record['target']:masks['regression_tuck']}))


if __name__=='__main__':unittest.main()
