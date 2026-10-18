"""Portable registration regressions for the roster's source-measured recipes."""
import unittest
from unittest.mock import patch
import tempfile
from collections import Counter
from copy import deepcopy
import json
from pathlib import Path

import numpy as np

from spec.art_identity.maquettes.blender.source_recipe import paired_point, plane_point, panel, bounded_hem, path_points
from spec.art_identity.maquettes.raster import project
from spec.art_identity.maquettes.blender.tube import tube_mesh
from spec.art_identity.maquettes.blender.contract import validate, digest
from spec.art_identity.maquettes.blender.compile_recipe import compile_recipe
from spec.art_identity.maquettes.blender.fit_delivery import registered_parts, assemble, determinism_matches
from spec.art_identity.maquettes.blender.source_cage import polygon_bounds, unpose_point, warped_projection, fit_points
from PIL import Image
from spec.art_identity.maquettes.blender.view_states import active_in_view
from spec.art_identity.maquettes.blender.bridge_client import wait, BRIDGE_DEFAULTS
from spec.art_identity.maquettes.blender.cloth_cache import cache_key
from spec.art_identity.maquettes.blender.ownership import uses_body_side_ownership


class SourceRecipeTests(unittest.TestCase):
    def setUp(self):
        self.spec = {'target': [0, 0, 1.12], 'ortho_scale': 2.4}

    def test_two_view_triangulation_round_trip(self):
        for point in [[.3, -.2, 1.5], [-.8, .4, .2], [0, 0, 2]]:
            pixels = [project(self.spec, point, view, 256)[:2] for view in ('front', 'rear')]
            np.testing.assert_allclose(paired_point(self.spec, *pixels), point, atol=1e-12)

    def test_stereo_prop_path_retains_one_common_three_dimensional_model(self):
        points = [[.3, -.2, 1.5], [-.8, .4, .2], [0, 0, 2]]
        item = {'path_px': [project(self.spec, p, 'front', 256)[:2].tolist() for p in points],
                'rear_path_px': [project(self.spec, p, 'rear', 256)[:2].tolist() for p in points]}
        np.testing.assert_allclose(path_points(self.spec, item), points, atol=1e-12)
        item['rear_path_px'].pop()
        with self.assertRaisesRegex(ValueError, 'corresponding front/rear controls'):
            path_points(self.spec, item)

    def test_source_ray_intersects_named_plane(self):
        for axis in (0, 1, 2):
            point = plane_point(self.spec, [37, 109], axis, .2)
            self.assertAlmostEqual(point[axis], .2)
            np.testing.assert_allclose(project(self.spec, point, size=256)[:2], [37, 109])

    def test_rear_source_panel_projects_in_rear_and_retains_body_space(self):
        rows = [[[110, 80], [130, 100]], [[200, 120], [220, 140]]]
        piece = panel(self.spec, 'rear', 'cape_near', 'tabard', rows, 0, -.15, {}, view='rear')
        for row, original in zip(piece['pattern']['rows'], rows):
            np.testing.assert_allclose(project(self.spec, row['points'][0], 'rear', 256)[:2], original[0])
            np.testing.assert_allclose(project(self.spec, row['points'][-1], 'rear', 256)[:2], original[-1])
            self.assertAlmostEqual(row['points'][0][0], -.15)

    def test_compiler_rear_authored_panel_is_still_one_common_mesh(self):
        root = Path(__file__).resolve().parents[1]
        recipe = json.loads((root / 'arc_thrall/measurements.json').read_text())
        item = next(p for p in recipe['surfaces'] if p['id'] == 'loincloth_back')
        item['source_view'] = 'rear'
        item.pop('drape', None)  # Test ray registration independently of tailoring.
        spec = compile_recipe(recipe)
        piece = next(p for p in spec['pieces'] if p['id'] == item['id'])
        self.assertNotIn('capture_view', piece)
        for row, expected in zip(piece['pattern']['rows'], item['rows_px']):
            np.testing.assert_allclose(project(spec, row['points'][0], 'rear', 256)[:2], expected[0])
            np.testing.assert_allclose(project(spec, row['points'][-1], 'rear', 256)[:2], expected[-1])
        item['source_view'] = 'side'
        with self.assertRaisesRegex(ValueError, 'source_view'):
            compile_recipe(recipe)

    def test_gale_view_states_change_only_native_banner_cloth(self):
        path = Path(__file__).resolve().parents[1] / 'gale_herald/measurements.json'
        result = compile_recipe(json.loads(path.read_text()))
        states = [p for p in result['pieces'] if 'capture_view' in p]
        self.assertEqual(len(states), 4)
        self.assertEqual({p['part'] for p in states}, {'cape_near', 'cape_far'})
        for p in states:
            self.assertEqual(p['type'], 'cloth')
            self.assertTrue(active_in_view(p, p['capture_view']))
            self.assertFalse(active_in_view(p, 'rear' if p['capture_view'] == 'front' else 'front'))
        self.assertTrue(active_in_view({'piece_type': 'body'}, 'front'))
        self.assertTrue(active_in_view({'piece_type': 'body'}, 'rear'))
        bad = deepcopy(result)
        next(p for p in bad['pieces'] if p['type'] != 'cloth')['capture_view'] = 'rear'
        with self.assertRaisesRegex(ValueError, 'Only cloth'):
            validate(bad)
        front = next(p for p in states if p['capture_view'] == 'front')
        rear = next(p for p in states if p['part'] == front['part'] and p['capture_view'] == 'rear')
        self.assertNotEqual(cache_key('fixture', front, 'fixture'), cache_key('fixture', rear, 'fixture'))
        changed = deepcopy(rear)
        changed['pattern']['rows'][0]['points'][0][0] += .01
        self.assertNotEqual(cache_key('fixture', rear, 'fixture'), cache_key('fixture', changed, 'fixture'))

    def test_whole_cloth_feature_ownership_does_not_split_glyphs_or_drips(self):
        self.assertTrue(uses_body_side_ownership({'cloth_kind': 'cloak'}))
        self.assertFalse(uses_body_side_ownership({'cloth_kind': 'cloak', 'ownership_mode': 'whole_piece'}))
        self.assertTrue(uses_body_side_ownership({'cloth_kind': 'skirt', 'side_parts': ['skirt_near', 'skirt_far']}))
        root = Path(__file__).resolve().parents[1]
        for name in ('gloam_stalker', 'gale_herald'):
            spec = compile_recipe(json.loads((root / name / 'measurements.json').read_text()))
            for piece in spec['pieces']:
                if piece['id'].startswith('banner_'):
                    self.assertEqual(piece['ownership_mode'], 'whole_piece')
                    self.assertFalse(uses_body_side_ownership({'cloth_kind': piece['kind'], **piece}))

    def test_measured_hood_tip_anchor_changes_only_its_cloth(self):
        root = Path(__file__).resolve().parents[1]
        for name in ('hoarfrost_seer', 'gale_herald', 'gloam_stalker'):
            recipe = json.loads((root / name / 'measurements.json').read_text())
            hood = next(p for p in recipe['surfaces'] if p.get('kind') == 'hood')
            hood['row_centres_px'] = {'0': [[125, 30], [130, 32]]}
            measured = compile_recipe(recipe)
            hood_id = hood['id']
            hood.pop('row_centres_px')
            original = compile_recipe(recipe)
            for key in ('joints', 'armature', 'base'):
                self.assertEqual(measured[key], original[key])
            unchanged = [p for p in measured['pieces'] if p['id'] != hood_id]
            self.assertEqual(unchanged, [p for p in original['pieces'] if p['id'] != hood_id])
            self.assertNotEqual(next(p for p in measured['pieces'] if p['id'] == hood_id)['pattern'],
                                next(p for p in original['pieces'] if p['id'] == hood_id)['pattern'])

    def test_bridge_quick_result_needs_no_run_line(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            (root / 'done').mkdir()
            (root / 'done/quick.json').write_text('{"exit": 0}')
            self.assertEqual(wait('quick', 120, root)['exit'], 0)

    def test_spatial_plate_rejects_unpaired_source_corners(self):
        path = Path(__file__).resolve().parents[1] / 'gloam_stalker/measurements.json'
        recipe = json.loads(path.read_text())
        recipe['surfaces'] = [{'id': 'invalid', 'shape': 'plate', 'part': 'head', 'front_outline_px': [[1, 2]] * 4, 'rear_outline_px': [[1, 2]] * 3}]
        with self.assertRaisesRegex(ValueError, 'corresponding front/rear'):
            compile_recipe(recipe)

    def test_bridge_start_deadline_is_independent_of_execution_budget(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            (root / 'done').mkdir()
            (root / 'bridge.log').write_text('00:00:00 RUN long: -P build.py\n')
            clock = [0]
            def tick(_):
                clock[0] += 60
                if clock[0] == 300:
                    (root / 'done/long.json').write_text('{"exit": 0}')
            with patch('spec.art_identity.maquettes.blender.bridge_client.time.monotonic', side_effect=lambda: clock[0]), \
                    patch('spec.art_identity.maquettes.blender.bridge_client.time.sleep', side_effect=tick):
                self.assertEqual(wait('long', 900, root)['exit'], 0)
            self.assertGreater(clock[0], BRIDGE_DEFAULTS['start_timeout_s'])

    def test_bridge_unstarted_job_stops_at_start_deadline(self):
        with tempfile.TemporaryDirectory() as temporary:
            clock = [0]
            def tick(_):
                clock[0] += 60
            with patch('spec.art_identity.maquettes.blender.bridge_client.time.monotonic', side_effect=lambda: clock[0]), \
                    patch('spec.art_identity.maquettes.blender.bridge_client.time.sleep', side_effect=tick):
                with self.assertRaisesRegex(TimeoutError, 'did not start'):
                    wait('never-started', 900, temporary)
            self.assertEqual(clock[0], BRIDGE_DEFAULTS['start_timeout_s'])

    def test_incompatible_views_leave_observable_residual(self):
        point = paired_point(self.spec, [50, 100], [180, 130])
        front = project(self.spec, point, size=256)
        rear = project(self.spec, point, 'rear', 256)
        self.assertAlmostEqual(front[0] - 50, 13)
        self.assertAlmostEqual(rear[0] - 180, 13)

    def test_panel_preserves_measured_edges(self):
        rows = [[[30, 70], [80, 74]], [[28, 140], [98, 149]]]
        piece = panel(self.spec, 'test', 'tabard', 'tabard', rows, 0, .25, {})
        for row, original in zip(piece['pattern']['rows'], rows):
            np.testing.assert_allclose(project(self.spec, row['points'][0], size=256)[:2], original[0])
            np.testing.assert_allclose(project(self.spec, row['points'][-1], size=256)[:2], original[-1])
        self.assertEqual(len(piece['pattern']['pins']), 32)

    def test_hollow_bell_has_closed_wall_and_open_lumen(self):
        vertices, faces = tube_mesh([[0, 0, 0], [0, 0, 1]], [.1, .4], .02, 16)
        edges = Counter(tuple(sorted((a, b))) for face in faces for a, b in zip(face, face[1:] + face[:1]))
        self.assertTrue(all(count == 2 for count in edges.values()))
        self.assertEqual(len(vertices), 64)
        self.assertAlmostEqual(np.linalg.norm(vertices[16][:2]), .08)
        self.assertAlmostEqual(np.linalg.norm(vertices[48][:2]), .38)
        self.assertTrue(all(len(face) == 4 for face in faces))

    def test_tube_rejects_collapsed_lumen_and_path(self):
        with self.assertRaises(ValueError):
            tube_mesh([[0, 0, 0], [0, 0, 1]], [.1, .4], .1, 16)
        with self.assertRaises(ValueError):
            tube_mesh([[0, 0, 0], [0, 0, 0]], [.1, .4], .02, 16)

    def test_side_labels_require_distinct_registered_parts(self):
        path = Path(__file__).resolve().parents[1] / 'hoarfrost_seer/measurements.json'
        spec = compile_recipe(json.loads(path.read_text()))
        bad = deepcopy(spec)
        bad['pieces'][0]['side_parts'] = ['head', 'head']
        with self.assertRaisesRegex(ValueError, 'side_parts'):
            validate(bad)

    def test_hem_obeys_both_source_lower_contours(self):
        contours = {'front': [[0, 180], [256, 180]], 'rear': [[0, 190], [256, 190]]}
        output = bounded_hem(self.spec, [[.3, .2, 0], [-.2, .1, .1]], contours)
        for point in output:
            self.assertLessEqual(project(self.spec, point, size=256)[1], 180 + 1e-9)
            self.assertLessEqual(project(self.spec, point, 'rear', 256)[1], 190 + 1e-9)

    def test_registered_overlay_uses_fit_frame_not_canvas_size(self):
        image = Image.new('RGBA', (20, 20))
        for x in (10, 11):
            for y in (10, 11):
                image.putpixel((x, y), (100, 100, 100, 255))
        report = {'source_frame': {'head_top': 1, 'sole_bottom': 11, 'ground_x': 5},
                  'maquette_frame': {'head_top': 2, 'sole_bottom': 22, 'ground_x': 10}}
        registered = registered_parts(image, report, (10, 10))
        self.assertEqual(registered.size, (10, 10))
        self.assertEqual(registered.getpixel((5, 5))[3], 255)

    def test_capture_assembly_rejects_stale_checks_after_failed_recapture(self):
        with tempfile.TemporaryDirectory() as temporary:
            folder = Path(temporary)
            (folder / 'spec_native.json').write_text('{"joints":{"root":[0,0,0]}}')
            front = folder / 'proof/front'
            front.mkdir(parents=True)
            (front / 'joints_px.json').write_text('{"front":{"root":[0,0]}}')
            (front / 'solo_coverage.json').write_text('{"front":{}}')
            (front / 'capture_checks.json').write_text('{"spec_hash":"stale"}')
            with patch('spec.art_identity.maquettes.blender.fit_delivery.read_manifest', return_value={'images': []}):
                with self.assertRaisesRegex(ValueError, 'different spec'):
                    assemble(folder)

    def test_raw_replay_proof_is_bound_to_current_spec_and_keeps_quality_separate(self):
        spec = {'id': 'fixture'}
        proof = {'spec_hash': digest(spec), 'passed': False,
                 'checks': {'fresh_and_replay_raw_hashes': True, 'joint_endpoints': True, 'native_geometry': False}}
        self.assertTrue(determinism_matches(spec, proof))
        self.assertFalse(determinism_matches({'id': 'different'}, proof))
        proof['checks']['fresh_and_replay_raw_hashes'] = False
        self.assertFalse(determinism_matches(spec, proof))

    def test_all_recipes_recompile_without_changing_their_protected_sources(self):
        import hashlib
        root = Path(__file__).resolve().parents[1]
        project = Path(__file__).resolve().parents[4]
        for identifier in ('hoarfrost_seer', 'gale_herald', 'arc_thrall', 'gloam_stalker'):
            recipe = json.loads((root / identifier / 'measurements.json').read_text())
            result = compile_recipe(recipe)
            self.assertEqual(result, compile_recipe(recipe))
            self.assertEqual(set(result['labels']), set(recipe['labels']))
            for view, source in recipe['sources'].items():
                self.assertEqual(hashlib.sha256((project / source).read_bytes()).hexdigest(), recipe['source_sha256'][view])

    def test_source_cage_uses_measured_scanline_bounds(self):
        polygon = [[10, 20], [30, 20], [40, 60], [0, 60]]
        self.assertEqual(polygon_bounds(polygon, 40), (5, 35))
        points = [[0, 0], [1, 0], [0, 1], [1, 1], [.5, .5]]
        warped = warped_projection(points, polygon)
        for x, y in warped:
            lo, hi = polygon_bounds(polygon, y)
            self.assertGreaterEqual(x + 1e-6, lo)
            self.assertLessEqual(x - 1e-6, hi)

    def test_occluded_profile_preserves_native_depth_while_fitting_observed_view(self):
        from spec.art_identity.maquettes.raster import camera
        points = np.array([[.1, .2, 1.1], [-.1, .3, .9], [.2, -.1, 1.05], [-.2, -.3, .8]])
        polygon = [[90, 80], [150, 80], [160, 150], [80, 150]]
        for view in ('front', 'rear'):
            result = fit_points(self.spec, points, {view: polygon})
            expected = warped_projection(project(self.spec, points, view, 256)[:, :2], polygon)
            np.testing.assert_allclose(project(self.spec, result, view, 256)[:, :2], expected)
            matrix, _, basis, _ = camera(self.spec, view)
            forward = basis[2] @ matrix[:3, :3]
            np.testing.assert_allclose(result @ forward, points @ forward, atol=1e-12)

    def test_corrective_shape_inverts_blended_native_skinning(self):
        first, second = np.eye(4), np.eye(4)
        first[:3, 3] = [1, 2, 3]
        second[:3, :3] = np.diag([2, 3, 4])
        source = np.array([.1, .2, .3, 1])
        blended = .25 * first + .75 * second
        target = blended @ source
        np.testing.assert_allclose(unpose_point(target[:3], [first, second], [1, 3]), source[:3])


if __name__ == '__main__':
    unittest.main()
