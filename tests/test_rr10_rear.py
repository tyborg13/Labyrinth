"""rr-10 rear, shoulder continuation and frozen-front regressions; no GUI."""
import json
from pathlib import Path
import sys
import unittest

import numpy as np
from PIL import Image

PROJECT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(PROJECT/'tools'))
from cutout_pipeline.cases import digest
from humanoid_cutout.gates import structure_errors,source_errors,bone_errors
from humanoid_cutout.seam_proof import fixture_masks,seam_holes
from humanoid_cutout.tucks import TORSO_SHOULDER_TUCK_PX,SLEEVE_INNER_EXTENSION_PX
from maquette_motion.features import source_pixels
from maquette_motion.material_palette import rules,outline_class

CASE=PROJECT/'experiments/cutouts/hoarfrost_seer/rr10'
FIXTURES=PROJECT/'tests/rr10/feedback5'


def read(path):return json.loads(path.read_bytes())


class RearTests(unittest.TestCase):
    def test_both_source_assemblies_and_garment_fields(self):
        build=read(CASE/'proof/build.json')
        for view in ('front','rear'):
            layout=read(CASE/f'layouts/{view}.json')
            self.assertEqual(structure_errors(layout,build),[])
            self.assertEqual(source_errors(CASE,layout,build),[])
            self.assertEqual(build['views'][view]['rest_mismatch_pixels'],0)
            for mesh in layout['joint_meshes']:
                if mesh.get('hidden_material'):
                    garment=next(m for m in layout['joint_meshes'] if m['name']==mesh['garment'])
                    self.assertEqual(mesh['weight_bounds'],garment['bbox'])
            if view=='rear':
                depths={p['name']:p['z_index'] for p in layout['parts'] if not p.get('hidden_material')}
                self.assertGreater(depths['staff'],max(z for name,z in depths.items() if name not in ('staff','hand_far')))
            robe=next(m for m in layout['joint_meshes'] if m['name']=='robe')
            vertices=np.asarray(robe['vertices'])
            bottom=vertices[:,1]==robe['bbox'][3]
            index=np.flatnonzero(bottom)[np.argmin(vertices[bottom,0])]
            # Near is on the left in the true rear and on the right in front.
            self.assertEqual(robe['weights']['hem_near'][index],1 if view=='rear' else 0)

    def test_new_rear_is_hash_bound_and_front_is_frozen(self):
        inputs=read(CASE/'inputs.json')
        record=inputs['rope_masks']['rear']
        self.assertEqual((CASE/record['file']).read_bytes(),(PROJECT/'spec/peer_benchmark/staged/rr-10/rope_mask_rear.png').read_bytes())
        self.assertEqual(digest(CASE/record['file']),record['sha256'])
        self.assertEqual(int((np.asarray(Image.open(CASE/record['file']))[...,3]>0).sum()),242)
        delivery=PROJECT/inputs['rear_delivery']
        current=read(delivery/'joints_px.json')
        old=read(PROJECT/inputs['baseline']/'source/maquette/joints_px.json')
        self.assertEqual(current['front'],old['front'])
        self.assertNotEqual(current['rear'],old['rear'])
        for view in ('front','rear'):
            self.assertEqual((CASE/f'source/{view}/processed.png').read_bytes(),(PROJECT/inputs[view+'_job']/'processed.png').read_bytes())
        previous=read(FIXTURES/'captures.json')['front_motion']
        compiled=read(CASE/'compiled_motion.json')
        for field in ('projection','view_tracks'):
            self.assertEqual(compiled[field]['front'],previous[field]['front'])
        self.assertEqual(compiled['clips'],previous['clips'])
        self.assertEqual(compiled['director_sha256'],previous['director_sha256'])

    def test_requested_shoulder_texels_are_present_without_outline(self):
        self.assertEqual(TORSO_SHOULDER_TUCK_PX,4)
        self.assertEqual(SLEEVE_INNER_EXTENSION_PX,3)
        for view in ('front','rear'):
            layout=read(CASE/f'layouts/{view}.json')
            definition=rules(CASE,view)
            for part in layout['parts']:
                record=layout['proof_layers'][part['name']]
                mask=Image.new('RGBA',(255,255))
                mask.paste(Image.open(CASE/record['mask']),tuple(record['mask_offset']))
                continuation=np.asarray(mask)[...,1]>0
                image=source_pixels(CASE,part)
                self.assertFalse(outline_class(image,definition)[continuation].any())
            torso=next(p for p in layout['parts'] if p['name']=='hidden_torso')
            required=np.asarray(Image.open(CASE/f'tucks/{view}_torso.png'))>0
            self.assertGreater(int(required.sum()),0)
            self.assertTrue((source_pixels(CASE,torso)[required,3]==255).all())

    def test_captured_shoulder_and_belt_openings_close_and_regression_reopens(self):
        layout=read(CASE/'layouts/front.json')
        poses={(r['clip'],r['frame']):r for r in read(CASE/'proof/samples.json')['samples'] if r['view']=='front' and r['kind']=='presented'}
        fixtures=read(FIXTURES/'captures.json')
        for record in fixtures['frames']:
            masks=fixture_masks(FIXTURES,record)
            pose=poses[record['clip'],record['frame']]
            self.assertEqual(seam_holes(CASE,layout,pose,masks,fixtures['rigid_tucks']),[])
            self.assertTrue(seam_holes(CASE,layout,pose,masks,fixtures['rigid_tucks'],{'hidden_torso':masks['regression_tuck']}))


if __name__=='__main__':unittest.main()
