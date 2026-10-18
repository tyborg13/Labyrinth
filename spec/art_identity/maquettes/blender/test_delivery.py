"""Focused shell topology, spec obstacle ordering and lossless curation tests."""
from collections import Counter
import json
import hashlib
from pathlib import Path
import tempfile
import unittest

import numpy as np
from PIL import Image

from .ridged_shell import relief, layered
from .curate_delivery import canonical_png, sha, discard_evidence
from .compile_recipe import compile_recipe
from .contract import validate

ROOT = Path(__file__).resolve().parents[1]
DELIVERY_TEST_DEFAULTS = {'rim': [[-1,0,0],[0,-1,0],[1,0,0],[0,1,0]],
                          'ridge': [0,0,.5], 'thickness': .02}


class DeliveryTests(unittest.TestCase):
    def test_required_parts_reject_missing_zero_and_negative_solos(self):
        from .ownership import require_solos
        require_solos(['head', 'torso'], {'head': 1, 'torso': 5})
        for counts in ({'head': 1}, {'head': 1, 'torso': 0}, {'head': -1, 'torso': 5}):
            with self.subTest(counts=counts), self.assertRaisesRegex(ValueError, 'Required rig labels'):
                require_solos(['head', 'torso'], counts)

    def test_rigid_clearance_keeps_components_and_encloses_with_a_padding_cube(self):
        from .rigid_clearance import components,padded_points
        self.assertEqual(components(6,[[0,1],[1,2],[2,0],[3,4],[4,5],[5,3]]),[[0,1,2],[3,4,5]])
        points=np.array(padded_points([[0,0,0],[1,2,3]],.015))
        np.testing.assert_allclose(points.min(0),[-.015,-.015,-.015])
        np.testing.assert_allclose(points.max(0),[1.015,2.015,3.015])

    def test_closed_cowl_has_one_hem_boundary_and_no_crown_or_seam_holes(self):
        from .rounded_hood import rest_mesh
        from .sewn_garment import topology_report
        angles=np.linspace(0,2*np.pi,32)
        hem=[[.3*np.cos(a),.3*np.sin(a),.8] for a in angles]
        v,f,p,r=rest_mesh([[-.1,-.1,1],[.1,.1,1.3]],hem,0,.24,.04)
        self.assertEqual(topology_report(v,f),{'connected':True,'nonmanifold_edges':0,'boundary_loops':1})
        self.assertTrue(r['closed_crown_and_seam'])
        self.assertLess(len(p),len(v)/2)

    def test_deferred_cloth_obstacle_pair_rejects_missing_accessory(self):
        spec=compile_recipe(json.loads((ROOT/'arc_thrall/measurements.json').read_text()))
        spec['cloth_obstacles']=[['loincloth','missing']]
        with self.assertRaisesRegex(ValueError,'cloth and a rigid shell'):
            validate(spec)

    def test_discard_records_the_actual_bytes_before_removing_proof(self):
        with tempfile.TemporaryDirectory() as temporary:
            root=Path(temporary); dropped=root/'cold.blend'; kept=root/'recipe.json'
            payload=b'native proof fixture'; dropped.write_bytes(payload); kept.write_text('{}')
            archive=root/'discarded.json'
            discard_evidence(root,[dropped],archive)
            self.assertFalse(dropped.exists()); self.assertTrue(kept.exists())
            entries=json.loads(archive.read_text())['files']
            self.assertEqual(entries,[['cold.blend',len(payload),hashlib.sha256(payload).hexdigest()]])
            with self.assertRaisesRegex(ValueError,'inside its figure'):
                discard_evidence(root,[root.parent/'outside.blend'],archive)

    def test_curved_shell_preserves_rim_ridge_and_is_closed(self):
        s = DELIVERY_TEST_DEFAULTS
        v, f = relief(s['rim'], s['ridge'], s['thickness'])
        np.testing.assert_array_equal(v[:4], s['rim'])
        self.assertIn(s['ridge'], v)
        edges = Counter(tuple(sorted((a,b))) for face in f for a,b in zip(face,face[1:]+face[:1]))
        self.assertTrue(all(n == 2 for n in edges.values()))
        self.assertTrue(np.isfinite(v).all())
        self.assertGreater(len(v), 20)
        with self.assertRaises(ValueError):
            relief(s['rim'], s['ridge'], 0)

    def test_layered_shell_keeps_each_closed_plate_in_one_mesh(self):
        s = DELIVERY_TEST_DEFAULTS
        v, f = layered([s, s])
        edges = Counter(tuple(sorted((a,b))) for face in f for a,b in zip(face,face[1:]+face[:1]))
        self.assertTrue(all(n == 2 for n in edges.values()))
        self.assertEqual(len(v), 2*len(relief(s['rim'],s['ridge'],s['thickness'])[0]))
        with self.assertRaises(ValueError):
            layered([])

    def test_canonical_png_strips_volatile_stamps_without_changing_clay(self):
        from PIL.PngImagePlugin import PngInfo
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            pixels = np.arange(64, dtype=np.uint8).reshape(4,4,4)
            for i in (1,2):
                info = PngInfo(); info.add_text('Date', str(i)); info.add(b'sRGB', b'\x03')
                Image.fromarray(pixels).save(root/f'{i}.png',pnginfo=info)
                canonical_png(root/f'{i}.png',root/f'{i}_packed.png')
            self.assertEqual(sha(root/'1_packed.png'),sha(root/'2_packed.png'))
            np.testing.assert_array_equal(np.array(Image.open(root/'1_packed.png')),pixels)
            with Image.open(root/'1_packed.png') as image:
                self.assertEqual(image.info['srgb'],3)

    def test_mask_packing_preserves_alpha_and_all_visible_samples(self):
        with tempfile.TemporaryDirectory() as temporary:
            root=Path(temporary); pixels=np.arange(64,dtype=np.uint8).reshape(4,4,4);pixels[0,0,3]=0
            Image.fromarray(pixels).save(root/'source.png')
            canonical_png(root/'source.png',root/'packed.png',mask=True)
            actual=np.array(Image.open(root/'packed.png'))
            np.testing.assert_array_equal(actual[:,:,3],pixels[:,:,3])
            np.testing.assert_array_equal(actual[pixels[:,:,3]>0],pixels[pixels[:,:,3]>0])
            np.testing.assert_array_equal(actual[0,0],[0,0,0,0])



if __name__ == '__main__':
    unittest.main()
