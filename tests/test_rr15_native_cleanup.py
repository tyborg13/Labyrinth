"""Native failure fixtures and CPU regressions for Thrall source cleanup."""
import hashlib
import json
from pathlib import Path
import sys
import unittest

import numpy as np
from PIL import Image

PROJECT = Path(__file__).resolve().parents[1]
sys.path[:0] = [str(PROJECT / 'tools'), str(PROJECT / 'experiments/cutouts/arc_thrall')]
from cutout_pipeline.cases import read_json
from humanoid_cutout.cpu_pose import CpuPose
from humanoid_cutout.silhouette_gates import detached_metrics, joint_holes, JOINT_NEIGHBOURHOOD_PX
from humanoid_cutout.underlays import native_order
from maquette_motion.pixels import render, unpack, changed, rest_identity, native_frame_matches
from maquette_motion.native_ties import select
from maquette_motion.features import source_pixels
from maquette_motion.silhouette import components, dilate
from rr15_cpu_proof import CASE, frame_state
from rr24_baseline import BASELINE_FILE, GEOMETRY_FIELDS, canonical, assert_preserved as assert_repaint_preserved
from rr24_build import RECIPE, clean_residue
from rr24_seams import frame_report as repaint_frame_report

FIXTURES = PROJECT / 'tests/rr11/rr15'
DETACHED_POSES = [('front', 'jab', 5), ('rear', 'tether', 15)]
SEAM_POSES = [('front', 'jab', 5), ('rear', 'move', 6)]
GEOMETRY_FIELDS = ('bbox', 'vertices', 'uvs', 'triangles', 'weights', 'weight_bounds')
INVALID_TIE_COLOR = [255, 0, 255, 255]


class NativeCleanupTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.models = {view: CpuPose(CASE, read_json(CASE / f'layouts/{view}.json')) for view in ('front', 'rear')}
        cls.poses = {(r['view'], r['clip'], r['frame']): r for r in read_json(CASE / 'proof/samples.json')['samples']
                     if r['kind'] == 'presented'}

    def test_front_idle6_native_overlap_and_distinct_underlay_priority(self):
        # Captured native pixels, not a self-generated expected composite.
        native = np.asarray(Image.open(FIXTURES / 'front_idle6_native.png').convert('RGBA'))
        rows = read_json(FIXTURES / 'overlap_before.json')
        def composite(order):
            result = Image.new('RGBA', (native.shape[1], native.shape[0]))
            for row in order:
                result.alpha_composite(Image.open(FIXTURES / f'front_idle6_{row["name"]}.png').convert('RGBA'))
            return result
        wrong = composite(sorted(rows, key=lambda r: r['z_index']))
        self.assertEqual(int(changed(native, np.asarray(wrong)).sum()), 7)
        depths = {p['name']: p['z_index'] for p in self.models['front'].layout['parts']}
        correct = composite(sorted(rows, key=lambda r: depths[r['name']]))
        self.assertEqual(int(changed(native, np.asarray(correct)).sum()), 0)
        for model in self.models.values():
            parts = {p['name']: p for p in model.layout['parts']}
            depths = [parts[n]['z_index'] for n in native_order(model.layout) if parts[n].get('hidden_material')]
            self.assertEqual(depths, sorted(set(depths)))
            self.assertLess(max(depths), min(p['z_index'] for p in parts.values() if not p.get('hidden_material')))
            self.assertLess(parts['hidden_upper_near']['z_index'], parts['hidden_torso']['z_index'])

    def test_detached_source_edges_attach_to_their_actual_pieces(self):
        for key in DETACHED_POSES:
            view, clip, frame = key
            before = np.asarray(Image.open(FIXTURES / f'{view}_{clip}{frame}_native.png').convert('RGBA'))
            self.assertGreater(detached_metrics(before)['stray_components'], 0)
            layers = frame_state(self.models[view], self.poses[key])[0]
            composite = Image.new('RGBA', (512, 512))
            for part, image, _ in sorted(layers, key=lambda item: item[0]['z_index']):
                composite.alpha_composite(Image.fromarray(image))
            self.assertEqual(detached_metrics(np.asarray(composite))['stray_components'], 0)

    def test_every_visible_source_texel_retains_its_exact_color_and_correct_owner(self):
        for view,model in self.models.items():
            for part in model.layout['parts']:
                if part.get('hidden_material'): continue
                raw = RECIPE/'raw'/view/(part['name']+'.png')
                assert_repaint_preserved(self,str(raw.relative_to(PROJECT)))
                expected,_ = clean_residue(np.asarray(Image.open(raw).convert('RGBA')))
                actual = source_pixels(CASE,part)
                record = model.layout['proof_layers'][part['name']]
                mask = model.image(record['mask'])
                x,y = record['mask_offset']
                actual[y:y+mask.shape[0],x:x+mask.shape[1]][mask[...,1]>0] = 0
                np.testing.assert_array_equal(actual,expected,err_msg=view+'/'+part['name'])

    def test_joint_continuations_close_holes_and_removal_reopens_them(self):
        # Re-pinned to the mq7b nape continuation, rather than the superseded
        # mq7 armpit/crop fixture. Removing exactly its source points reopens
        # all five independently identified rear death defects.
        model = self.models['rear']
        points = read_json(RECIPE/'joint_continuations.json')['rear']['head']['source_points']
        overrides = {p['name']:model.image(p['file']).copy() for p in model.layout['parts']}
        for part in model.layout['parts']:
            if part['logical_part']!='head' or not part.get('hidden_material'): continue
            x,y,right,bottom=part['bbox']
            for u,v in points:
                if x<=u<right and y<=v<bottom: overrides[part['name']][v-y,u-x]=0
        for fixture in read_json(BASELINE_FILE)['nape_removal_frames']:
            frame=fixture['frame']
            pose=self.poses['rear','death',frame]
            self.assertEqual(repaint_frame_report(model,pose)[-1]['failures'],[])
            defects=repaint_frame_report(model,pose,source_overrides=overrides)[-1]['failures']
            self.assertEqual([{k:d[k]for k in ('bbox','pixel_count')}for d in defects],fixture['pockets'])

    def test_hidden_tube_native_ties_are_exact_real_source_candidates(self):
        source = Image.open(FIXTURES / 'rear_hidden_tube_before.png').convert('RGBA')
        for row in read_json(FIXTURES / 'rigid_before.json'):
            key = f'rear_{row["clip"]}{row["frame"]}_hidden_tube_native.png'
            actual = np.asarray(Image.open(FIXTURES / key).convert('RGBA'))
            samples = render(source, unpack(row['transform']), with_ties=True)
            self.assertEqual(int(changed(actual, samples.default).sum()), 4)
            matched, invalid = select(actual, samples)
            self.assertFalse(invalid.any())
            self.assertFalse(changed(actual, matched).any())
            self.assertTrue(native_frame_matches(actual, samples.default, samples))
            broken = actual.copy()
            broken[samples.ties] = INVALID_TIE_COLOR
            self.assertFalse(native_frame_matches(broken, samples.default, samples))

    def test_mq7b_torso_continuation_matches_repaint_baseline(self):
        # mq7b reassigns the full belt/skirt; freeze its new torso source
        # instead of requiring exactly the old two-pixel mq7 alpha delta.
        model=self.models['rear']
        for part in model.layout['parts']:
            if part['logical_part']=='torso':
                assert_repaint_preserved(self,str((CASE/part['file']).relative_to(PROJECT)))
        part=next(p for p in model.layout['parts'] if p['name']=='hidden_torso')
        image=source_pixels(CASE,part)
        for x,y in ((100,138),(104,142)): self.assertEqual(image[y,x,3],0)

    def test_paint_motion_rest_and_visible_mesh_fields_are_unchanged(self):
        self.assertTrue(rest_identity(CASE)['ok'])
        for path in read_json(FIXTURES/'protected.json'):
            assert_repaint_preserved(self,path)
        geometry=read_json(BASELINE_FILE)['geometry']
        for view,model in self.models.items():
            for mesh in model.layout['joint_meshes']:
                fields={k:mesh[k] for k in GEOMETRY_FIELDS if k in mesh}
                self.assertEqual(canonical(fields),geometry[view+'/'+mesh['name']])



if __name__ == '__main__':
    unittest.main()
