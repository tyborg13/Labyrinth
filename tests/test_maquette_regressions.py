"""Review regressions: capture provenance, weighted labels, curves and facing."""
from copy import deepcopy
import json
from pathlib import Path
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import patch

import numpy as np
from PIL import Image

from spec.art_identity.maquettes.blender.backend import load_render
from spec.art_identity.maquettes.blender.capture_manifest import prepare_capture, write_manifest
from spec.art_identity.maquettes.blender.cloth_cache import cache_key, read_cache, topology_hash
from spec.art_identity.maquettes.blender.contract import BUILD_DEFAULTS, digest, label_faces, mesh_hash
from spec.art_identity.maquettes.blender.curve_projection import project_spline
from spec.art_identity.maquettes.blender.facing import axis_report
from spec.art_identity.maquettes.blender.ownership import assign_materials, materials_match, weights_match, cloak_owners, require_solos
from spec.art_identity.maquettes.blender.torso_reflection import asymmetry, passes_asymmetry


class OwnershipTests(unittest.TestCase):
    def test_multiple_weight_winners_and_stable_alphabetical_tie(self):
        faces = [[0, 1, 2], [3, 4, 5], [6, 7, 8]]
        weights = [{'b': .9, 'a': .1}] * 3 + [{'a': .9, 'b': .1}] * 3 + [{'b': .5, 'a': .5}] * 3
        regions = {'a': 'head', 'b': 'torso'}
        expected = ['torso', 'head', 'head']
        actual = label_faces([], faces, weights, regions)
        self.assertEqual(actual, expected)
        self.assertEqual(label_faces([], faces, [dict(reversed(list(w.items()))) for w in weights], regions), expected)
        self.assertTrue(weights_match(faces, weights, regions, actual))
        self.assertFalse(weights_match(faces, weights, regions, ['torso'] * 3))

    def test_material_assignment_and_zero_index_mutation(self):
        obj = SimpleNamespace(data=SimpleNamespace(polygons=[SimpleNamespace(material_index=0) for _ in range(3)]))
        expected = [2, 1, 2]
        assign_materials(obj, expected)
        self.assertEqual([p.material_index for p in obj.data.polygons], expected)
        self.assertTrue(materials_match(obj, expected))
        for p in obj.data.polygons:
            p.material_index = 0
        self.assertFalse(materials_match(obj, expected))

    def test_cloak_body_sides_survive_view_turn_and_ties_are_near(self):
        centres = [[-1, 0, 9], [1, 0, -9], [0, 0, 7]]
        origin, forward, up, near, far = [0, 0, 0], [0, 1, .2], [0, 0, 1], [1, 0, 0], [-1, 0, 0]
        expected = ['cape_far', 'cape_near', 'cape_near']
        self.assertEqual(cloak_owners(centres, origin, forward, up, near, far), expected)
        for rotation in (np.eye(3), np.diag([-1, -1, 1])):
            transform = lambda points: (np.asarray(points) @ rotation.T).tolist()
            self.assertEqual(cloak_owners(transform(centres), transform(origin), transform(forward),
                                          transform(up), transform(near), transform(far)), expected)
        # Shoulder names orient the rule; a camera vector never determines it.
        self.assertEqual(cloak_owners(centres, origin, forward, up, far, near), ['cape_near', 'cape_far', 'cape_near'])
        with self.assertRaisesRegex(ValueError, 'empty solos: cape_far'):
            require_solos(['cape_near', 'cape_far'], {'cape_near': 100, 'cape_far': 0})
        require_solos(['cape_near', 'cape_far'], {'cape_near': 1, 'cape_far': 1})


class CaptureTests(unittest.TestCase):
    def test_bridge_stops_after_120_seconds_even_for_long_job_budget(self):
        from spec.art_identity.maquettes.blender.bridge_client import wait
        with tempfile.TemporaryDirectory() as tmp, patch('time.monotonic', side_effect=[0, 121]):
            with self.assertRaisesRegex(TimeoutError, 'job-unchanged'):
                wait('job-unchanged', timeout_s=1800, root=tmp)

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.folder = Path(self.tmp.name)
        self.spec = {'labels': {'head': [1, 0, 0]}, 'joints': {'head': [0, 0]}, 'fit': {'head_part': 'head'}}
        (self.folder / 'build_report.json').write_text(json.dumps({'spec_hash': digest(self.spec)}))
        (self.folder / 'joints_px.json').write_text(json.dumps({'front': self.spec['joints']}))
        self.current = Image.new('RGBA', (100, 100))
        self.current.paste((255, 255, 255, 255), (20, 10, 60, 60))  # 2,000 pixels
        self.stale = Image.new('RGBA', (100, 100))
        self.stale.paste((255, 255, 255, 255), (30, 10, 40, 60))  # 500 pixels
        for name in ('front_silhouette.png', 'front_solo_head.png'):
            self.current.save(self.folder / name)
        for name in ('front_body.png', 'front_head.png'):
            self.stale.save(self.folder / name)

    def test_full_capture_rejects_stale_500_pixel_fit_mattes(self):
        write_manifest(self.folder, digest(self.spec), 'full', ['front_silhouette.png', 'front_solo_head.png'])
        actual = load_render(self.spec, self.folder)
        self.assertEqual(int(actual.masks['head'].sum()), 2000)
        self.assertNotIn('__body__', actual.masks)
        prepare_capture(self.folder, 'full')
        self.assertFalse((self.folder / 'front_body.png').exists())
        self.assertFalse((self.folder / 'front_head.png').exists())

    def test_fit_inputs_require_names_spec_mode_and_byte_hashes(self):
        files = ['front_silhouette.png', 'front_body.png', 'front_head.png']
        self.current.save(self.folder / 'front_body.png')
        self.current.save(self.folder / 'front_head.png')
        write_manifest(self.folder, digest(self.spec), 'fit', files)
        self.assertEqual(int(load_render(self.spec, self.folder).masks['__body__'].sum()), 2000)
        self.stale.save(self.folder / 'front_body.png')
        with self.assertRaisesRegex(ValueError, 'Stale or corrupt capture image'):
            load_render(self.spec, self.folder)
        write_manifest(self.folder, digest(self.spec), 'fit', ['front_silhouette.png'])
        with self.assertRaisesRegex(ValueError, 'not named'):
            load_render(self.spec, self.folder)
        write_manifest(self.folder, 'old', 'fit', files)
        with self.assertRaisesRegex(ValueError, 'different spec'):
            load_render(self.spec, self.folder)
        write_manifest(self.folder, digest(self.spec), 'ownership', files)
        with self.assertRaisesRegex(ValueError, 'capture mode'):
            load_render(self.spec, self.folder)


class CacheTests(unittest.TestCase):
    def test_cache_protects_native_edge_loop_and_polygon_order(self):
        payload = {'vertices': [[0, 0, 0], [1, 0, 0], [0, 1, 0]], 'faces': [[0, 1, 2]],
                   'edges': [[1, 2], [2, 0], [0, 1]], 'loop_vertices': [0, 1, 2], 'loop_edges': [2, 0, 1],
                   'polygon_starts': [0], 'polygon_totals': [3], 'polygon_smooth': [False]}
        payload['mesh_hash'] = mesh_hash(payload['vertices'], payload['faces'])
        payload['topology_hash'] = topology_hash(payload)
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / 'bake.json'
            path.write_text(json.dumps(payload))
            self.assertEqual(read_cache(path), payload)
            for field in ('edges', 'loop_vertices', 'loop_edges'):
                corrupt = deepcopy(payload)
                corrupt[field].reverse()
                path.write_text(json.dumps(corrupt))
                with self.assertRaisesRegex(ValueError, 'Corrupt cloth cache topology'):
                    read_cache(path)

    def test_context_piece_blender_and_revision_invalidate_cache(self):
        piece = {'id': 'test', 'frames': 4}
        first = cache_key('posed-body-a', piece, '5.2')
        self.assertEqual(first, cache_key('posed-body-a', deepcopy(piece), '5.2'))
        self.assertNotEqual(first, cache_key('posed-body-b', piece, '5.2'))
        self.assertNotEqual(first, cache_key('posed-body-a', {**piece, 'frames': 5}, '5.2'))
        self.assertNotEqual(first, cache_key('posed-body-a', piece, '5.3'))
        with patch.dict(BUILD_DEFAULTS, cache_revision=BUILD_DEFAULTS['cache_revision'] + 1):
            self.assertNotEqual(first, cache_key('posed-body-a', piece, '5.2'))

    def test_corrupt_cached_coordinates_and_topology_are_rejected(self):
        original = {'vertices': [[0, 0, 0], [1, 0, 0], [0, 1, 0]], 'faces': [[0, 1, 2]]}
        original['mesh_hash'] = mesh_hash(original['vertices'], original['faces'])
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / 'bake.json'
            path.write_text(json.dumps(original))
            self.assertEqual(read_cache(path), original)
            for field, changed in [('vertices', [[0, 0, 1], [1, 0, 0], [0, 1, 0]]), ('faces', [[0, 2, 1]])]:
                payload = {**original, field: changed}
                path.write_text(json.dumps(payload))
                with self.assertRaisesRegex(ValueError, 'Corrupt cloth cache'):
                    read_cache(path)


class CurveTests(unittest.TestCase):
    def test_poly_and_bezier_project_each_control_and_both_handles(self):
        for kind in ('POLY', 'BEZIER'):
            points = [SimpleNamespace(co=(i, 0, 0, 1) if kind == 'POLY' else (i, 0, 0),
                                      handle_left=(i - .2, 0, 0), handle_right=(i + .2, 0, 0)) for i in range(2)]
            before = deepcopy(points)
            spline = SimpleNamespace(type=kind, points=points if kind == 'POLY' else [], bezier_points=points if kind == 'BEZIER' else [])
            calls = []
            def project(co, radius):
                calls.append((tuple(co), radius))
                return tuple(np.asarray(co) + [0, 0, 1 + radius])
            project_spline(spline, [1, .5], project)
            self.assertEqual(len(calls), 2 if kind == 'POLY' else 6)
            for old, point, radius in zip(before, points, [1, .5]):
                np.testing.assert_allclose(point.co[:3], np.asarray(old.co[:3]) + [0, 0, 1 + radius])
                if kind == 'BEZIER':
                    for handle in ('handle_left', 'handle_right'):
                        np.testing.assert_allclose(getattr(point, handle), np.asarray(getattr(old, handle)) + [0, 0, 1 + radius])
                    self.assertEqual(point.handle_left_type, 'FREE')


class FacingTests(unittest.TestCase):
    def test_symmetric_frontal_rectangle_has_zero_mirror_difference_and_fails(self):
        mask = np.zeros((80, 80), bool)
        mask[10:70, 30:50] = True
        report = asymmetry(mask, [[40, 0], [40, 80]])
        self.assertEqual(report['mirror_difference'], 0)
        self.assertEqual(report['left_area_px'], report['right_area_px'])
        self.assertFalse(passes_asymmetry(report))
        self.assertFalse(axis_report({'target': [0, 0, 0], 'ortho_scale': 3}, [1, 1, 0])['passed'])

    def test_sloped_centreline_is_sampled_at_row_centres(self):
        mask = np.zeros((8, 20), bool)
        for y in range(1, 7):
            mask[y, 1 + 2 * y:3 + 2 * y] = True
        report = asymmetry(mask, [[1, 0], [17, 8]])
        self.assertEqual(report['mirror_difference'], 0)
        self.assertEqual(report['left_area_px'], report['right_area_px'])


if __name__ == '__main__':
    unittest.main()
