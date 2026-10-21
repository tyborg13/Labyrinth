"""Fresh full-sweep joint proof and a construction-disabled source mutation."""
import json
from pathlib import Path
import sys
import unittest
import numpy as np

PROJECT=Path(__file__).resolve().parents[1]
sys.path[:0]=[str(PROJECT/'tools'),str(PROJECT/'experiments/cutouts/slag_mortar')]
import test_rr30_mortar as mortar_tests
from rr30_case import CASE
from rr30_cpu import CpuPose as CoveragePose
from rr30_joint_gate import JointSurfaceGate
from cutout_pipeline.cases import read_json,write_json
from rr30_records import space_summary
from rr30_seams import report


class JointSurfaceTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        mortar_tests.MortarV2Tests.setUpClass.__func__(cls)

    def before_frame(self, frame):
        layout=read_json(PROJECT/'tests/rr30/joint_surface_before.json')
        # The fixture owns its original static arm/leg materials. Do not read
        # current head-only action-fill files through its historical metadata.
        layout.pop('gait_continuations',None)
        fixture=np.load(PROJECT/'tests/rr30/joint_surface_before.npz')
        model=CoveragePose(CASE,layout)
        cropped={};source={}
        for part in layout['parts']:
            image=fixture['front/paint/'+part['name']]
            cropped[part['name']]=image
            full=np.zeros((255,255,4),dtype=np.uint8)
            x,y=part['offset'];full[y:y+image.shape[0],x:x+image.shape[1]]=image
            source[part['name']]=full
            model.images[part['file']]=image
            model.images[layout['proof_layers'][part['name']]['mask']]=fixture['front/check/'+part['name']]
        pose=next(r for r in read_json(PROJECT/'tests/rr30/joint_surface_before_poses.json')['samples'] if r['frame']==frame)
        layers,_=model.layers(pose,source_overrides=cropped)
        return JointSurfaceGate(CASE,layout,source_images=source).frame(pose,layers)

    def test_original_painted_rest_passes(self):
        result=self.before_frame(0)
        self.assertTrue(result['ok'],result)

    def test_dynamic_pelvis_copies_painted_skin_above_its_minimum(self):
        from humanoid_cutout.gait_continuations import texture,nearest_donors
        from maquette_motion.material_palette import luma
        for view in ('front','rear'):
            layout=read_json(CASE/f'layouts/{view}.json')
            part=next(p for p in layout['parts'] if p['name']=='hidden_pelvis')
            floor=max(JointSurfaceGate(CASE,layout).skin.values())
            self.assertEqual(part['continuation_min_luma'],floor)
            recipe=layout.get('gait_continuations',{}).get(part['name'])
            if recipe:
                image=texture(CASE,layout,part,clip='death')
                self.assertTrue(all(luma(image[y,x])>=floor for x,y,_,_ in recipe['texels']))
                generated=nearest_donors(CASE,layout,part,{(x,y) for x,y,_,_ in recipe['texels']})
                from PIL import Image
                donor=next(p for p in layout['parts'] if p['name']==generated['donor'])
                paint=np.asarray(Image.open(CASE/donor['file']).convert('RGBA'))
                self.assertTrue(all(luma(paint[v,u])>=floor for _,_,u,v in generated['texels']))
            with self.assertRaisesRegex(ValueError,'luminance minimum'):
                nearest_donors(CASE,layout,dict(part,continuation_min_luma=float('nan')),{(0,0)})

    def test_disabling_source_fix_fails_both_flagged_frames(self):
        results=[]
        for frame in (16,32):
            with self.subTest(frame=frame):
                result=self.before_frame(frame);results.append(result)
                self.assertFalse(result['ok'])
                self.assertGreater(sum(r['pixels'] for r in result['cover_errors']),0)
                self.assertGreater(sum(r['pixels'] for r in result['dark_errors']),0)
        write_json(CASE/'proof/joint_cleanup/mutation_disabled_fix.json',results)
        print('RR30 JOINT MUTATION: CAUGHT (source fix disabled; lob0016 and lob0032; cover and dark seams)',flush=True)

    def test_fresh_every_presented_frame_in_both_views(self):
        results={}
        for view in ('front','rear'):
            results[view]=report(read_json(CASE/f'layouts/{view}.json'),self.samples)
        write_json(CASE/'proof/logs/feedback3-joint-full-sweep.json',results)
        compact={v:dict({k:x for k,x in r.items() if k not in ('failures','passed_spaces')},
            source_space=space_summary(r['passed_spaces'])) for v,r in results.items()}
        write_json(CASE/'proof/seams.json',compact)
        write_json(CASE/'proof/joint_cleanup/full_sweep.json',dict(
            native_pixels=False,views={v:r['joint_surfaces'] for v,r in results.items()},
            sampled_frames=sum(r['frames'] for r in results.values())))
        for view,result in results.items():
            self.assertEqual(result['frames'],431)
            self.assertEqual(result['errors'],[],view)
            self.assertTrue(result['joint_surfaces']['ok'])
            self.assertLessEqual(result['joint_surfaces']['maximum_visible_cover_distance_px'],3.+1e-9)
            print('RR30 %s CPU COVERAGE AND JOINT GATES: PASS (431 frames; 0 errors)'%view.upper(),flush=True)


if __name__=='__main__':unittest.main()
