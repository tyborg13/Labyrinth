"""Feedback-3 filled seams, unchanged garment fields and exact source rest."""
import hashlib
import json
from pathlib import Path
import sys
import unittest

import numpy as np
from PIL import Image

PROJECT = Path(__file__).resolve().parents[1]
sys.path[:0] = [str(PROJECT / 'tools'), str(PROJECT / 'experiments/cutouts/hoarfrost_seer')]
from humanoid_cutout.cpu_pose import CpuPose
from humanoid_cutout.silhouette_gates import posed_owners, joint_holes
from maquette_motion.pixels import rest_identity, PROOF_DEFAULTS
from rr13_cpu_proof import frame_state

CASE = PROJECT / 'experiments/cutouts/hoarfrost_seer/rr10'
from humanoid_cutout.anatomy import load, owner_ids
ANATOMY = load(CASE)

FIXTURES = PROJECT / 'tests/rr10/rr13_f3'
FIXED_FRAMES = [('front', 'mark', frame, 'hidden_torso') for frame in (18, 22, 48, 49)] + [
    ('rear', 'mark', frame, 'hidden_torso') for frame in (20, 21, 22)] + [
    ('front', 'death', 68, 'sleeve_near')]
GEOMETRY_FIELDS = ('bbox', 'vertices', 'uvs', 'triangles', 'weights', 'weight_bounds')


def read(path):
    return json.loads(path.read_bytes())


class ContinuationTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.poses = {(r['view'], r['clip'], r['frame']): r for r in read(CASE / 'proof/samples.json')['samples']
                     if r['kind'] == 'presented'}

    def test_director_shoulder_and_top_edge_pinholes_close_and_fill_removal_reopens(self):
        for view, clip, frame, target in FIXED_FRAMES:
            with self.subTest(view=view, clip=clip, frame=frame):
                layout = read(CASE / f'layouts/{view}.json')
                model = CpuPose(CASE, layout)
                pose = self.poses[view, clip, frame]
                self.assertEqual(frame_state(model, pose)[-1], [])
                overrides = {p['name']: model.image(p['file']).copy() for p in layout['parts']}
                # The front/rear donor masks are immutable pre-fix alpha, not
                # a manually painted posed hole or a gate exemption.
                path = FIXTURES / (view + '_' + target + '_before_alpha.png')
                with Image.open(path) as image:
                    before = np.asarray(image) > 0
                part = next(p for p in layout['parts'] if p['name'] == target)
                x, y, right, bottom = part['bbox']
                overrides[target][~before[y:bottom, x:right]] = 0
                layers, maps = model.layers(pose, overrides)
                seam = np.logical_or.reduce(model.masks(pose, layout['proof_joint_seams'], maps))
                refs = model.masks(pose, layout['proof_rest_holes'], maps)
                owners = posed_owners(layers, layout['parts'], pose['bones'], PROOF_DEFAULTS['source_offset'], ANATOMY['ownership'])
                self.assertTrue(joint_holes(owners > 0, seam, owners, refs))

    def test_both_rest_composites_and_all_garment_deformation_fields_are_unchanged(self):
        self.assertTrue(rest_identity(CASE)['ok'])
        before = read(FIXTURES / 'geometry_before.json')
        for view in ('front', 'rear'):
            for mesh in read(CASE / f'layouts/{view}.json')['joint_meshes']:
                fields = {k: mesh[k] for k in GEOMETRY_FIELDS if k in mesh}
                actual = hashlib.sha256(json.dumps(fields, sort_keys=True).encode()).hexdigest()
                self.assertEqual(actual, before[view + '/' + mesh['name']])


if __name__ == '__main__':
    unittest.main()
