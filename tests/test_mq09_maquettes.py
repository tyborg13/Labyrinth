"""Batch C source protection, shoulder/turn rules and sealed native delivery."""
from copy import deepcopy
import json
from pathlib import Path
import tempfile
import unittest
import numpy as np
import subprocess
import sys
import shutil

from spec.art_identity.maquettes.blender.compile_recipe import compile_recipe
from spec.art_identity.maquettes.blender.contract import digest, validate
from spec.art_identity.maquettes.blender.curate_delivery import sha, verify
from spec.art_identity.maquettes.blender.delivery_validation import validate_delivery
from spec.art_identity.maquettes.hollow_mimic.batch_proof import FIGURES, ROOT, pose_gates, inspect
from spec.art_identity.maquettes.hollow_mimic.acceptance import validate as validate_acceptance
from tools.unit_preservation import read_json as revision_json, tracked_paths
from tests.maquette_preservation import foreign_maquette_changes, historical_compiler


HUMANOID = {'head', 'torso', 'pelvis'} | {
    part + '_' + side for part in ('upper', 'fore', 'hand', 'thigh', 'shin', 'foot')
    for side in ('near', 'far')}
EXTRAS = {'hollow_mimic': set(), 'briar_weaver': {'tatters'}, 'slag_mortar': {'mortar', 'apron'}}
TEST_DEFAULTS = {'invalid_levels': [-1, 3, True, 1.5], 'shoulder_mutation_m': .1}
UNIT_HEAD = '2f64d590571a107473cc5423716d68b261b664c7'  # mq-09 signoff
BASELINE_COMMIT = '87bd64903f2a1fde12e4e397492932b36d01b949'
OCCLUSION_FIXTURE = {'label_linear': [.6, .35, .05],
                     'pixels': [[[203, 160, 63, 255], [200, 158, 60, 255]]]}


class RecipeTests(unittest.TestCase):
    def test_head_occlusion_ignores_nearest_colour_antialias_false_positives(self):
        from spec.art_identity.maquettes.slag_mortar.occlusion_pixels import overlap
        report = overlap({'labels': {'mortar': OCCLUSION_FIXTURE['label_linear']}},
                         OCCLUSION_FIXTURE['pixels'], np.array([[True, True]]))
        self.assertEqual(report['genuine_mortar_over_head_pixels'], 1)

    def test_native_thumb_frames_preserve_lengths_and_handedness(self):
        from spec.art_identity.maquettes.blender.thumb_pose import rotation_between
        for before, after in [([1, 0, 0], [0, 1, 0]), ([1, 0, 0], [-1, 0, 0]),
                              ([1, 2, 3], [-2, 3, 1])]:
            rotation = rotation_between(before, after)
            np.testing.assert_allclose(rotation.T @ rotation, np.eye(3), atol=1e-12)
            self.assertAlmostEqual(np.linalg.det(rotation), 1)
            np.testing.assert_allclose(rotation @ (np.array(before) / np.linalg.norm(before)),
                                       np.array(after) / np.linalg.norm(after), atol=1e-12)

    def test_shaped_shell_seating_clears_support_without_changing_its_shape(self):
        from spec.art_identity.maquettes.blender.support_shell import clearance_translation
        points = np.array([[0., 1, 2], [.2, 2, 3], [.5, 3, 4]])
        delta = clearance_translation(points, [[.4, 1, 2], [.3, 2, 3], None], [1, 0, 0], .01)
        moved = points + delta
        self.assertGreaterEqual(moved[0, 0], .41)
        self.assertGreaterEqual(moved[1, 0], .31)
        np.testing.assert_allclose(np.diff(moved, axis=0), np.diff(points, axis=0))
        self.assertEqual(clearance_translation(points, [None] * 3, [1, 0, 0], .01), [0, 0, 0])

    def test_clean_standalone_compiler_supports_the_native_fist_recipe(self):
        recipe = json.loads((ROOT / 'slag_mortar/measurements.json').read_text())
        with tempfile.TemporaryDirectory() as temporary:
            path = Path(temporary) / 'measurements.json'
            path.write_text(json.dumps(recipe))
            result = subprocess.run([sys.executable, '-B', str(ROOT / 'blender/compile_recipe.py'), str(path)],
                                    text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
            self.assertEqual(result.returncode, 0, result.stdout)
            self.assertEqual(json.loads(path.with_name('spec_native.json').read_text()), compile_recipe(recipe))
    def test_rigid_origin_rebase_preserves_world_vertices(self):
        from spec.art_identity.maquettes.blender.rigid_pivot import local_shift
        matrix = np.array([[0, -2, 0, 4], [2, 0, 0, 3], [0, 0, 2, 1], [0, 0, 0, 1.]])
        point, pivot = np.array([1, 2, 3, 1]), [8, 2, 7]
        delta = np.array(local_shift(matrix, pivot))
        new_matrix = matrix.copy()
        new_matrix[:3, 3] = pivot
        np.testing.assert_allclose(new_matrix @ np.r_[point[:3] - delta, 1], matrix @ point)
    def test_curve_seating_preserves_the_measured_tip(self):
        from spec.art_identity.maquettes.blender.curve_root import reroot
        path = [[0, 0, 0], [1, 0, 1], [2, 0, 2]]
        result = reroot(path, [0, 1, 0])
        self.assertEqual(result[0], [0, 1, 0])
        self.assertEqual(result[-1], path[-1])
        self.assertEqual(path[0], [0, 0, 0])
    def test_closed_fingers_keep_palm_and_native_separation(self):
        from spec.art_identity.maquettes.blender.hand_pose import closed_fingers
        points = np.array([[x, y, 0.] for x in np.linspace(0, 1, 21) for y in (-.1, .1)])
        direction, inward = np.array([1., 0, 0]), np.array([0., 0, 1])
        result, report = closed_fingers(points, [0, 0, 0], direction, inward)
        np.testing.assert_array_equal(result[points[:, 0] <= report['knuckle_distance_m']],
                                      points[points[:, 0] <= report['knuckle_distance_m']])
        np.testing.assert_array_equal(result[:, 1], points[:, 1])
        self.assertLess(report['maximum_axial_after_m'], report['maximum_axial_before_m'])
        np.testing.assert_array_equal(direction, [1, 0, 0])
        np.testing.assert_array_equal(inward, [0, 0, 1])
        shifted, _ = closed_fingers(points + [4, 2, 3], [4, 2, 3], direction, inward)
        np.testing.assert_allclose(shifted, result + [4, 2, 3])

    def test_bridge_distinguishes_busy_service_from_idle(self):
        from spec.art_identity.maquettes.blender.bridge_client import running_jobs, idle_since
        with tempfile.TemporaryDirectory() as temporary:
            log = Path(temporary) / 'bridge.log'
            log.write_text('00:00:00 BRIDGE START roots=test\n00:00:01 RUN other: script\n')
            self.assertEqual(running_jobs(temporary), {'other'})
            self.assertIsNone(idle_since(temporary, 0, 150))
            log.write_text(log.read_text() + '00:03:00 DONE other: exit 0\n')
            self.assertFalse(running_jobs(temporary))
            self.assertEqual(idle_since(temporary, None, 180), 180)
            self.assertEqual(idle_since(temporary, 180, 250), 180)
    def test_corrective_relaxation_preserves_native_details_and_components(self):
        from spec.art_identity.maquettes.blender.source_cage import relax_offsets
        faces = [[0, 1, 2], [3, 4, 5]]
        offsets = np.array([[1., 2, 3]] * 3 + [[8., 9, 10]] * 3)
        np.testing.assert_array_equal(relax_offsets(offsets, faces, [True] * 6, 8, .5), offsets)
        changed = offsets.copy()
        changed[1] += [1, 0, 0]
        result = relax_offsets(changed, faces, [False, True, True, True, True, True], 8, .5)
        np.testing.assert_array_equal(result[0], changed[0])
        np.testing.assert_array_equal(result[3:], changed[3:])
        np.testing.assert_array_equal(relax_offsets(changed, faces, [True] * 6, 0, .5), changed)
        self.assertLess(result[1, 0], changed[1, 0])

    def test_exact_labels_protected_art_and_real_anatomy(self):
        for name in FIGURES:
            with self.subTest(figure=name):
                recipe = json.loads((ROOT / name / 'measurements.json').read_text())
                spec = compile_recipe(recipe)
                self.assertEqual(set(spec['labels']), HUMANOID | EXTRAS[name])
                self.assertEqual(spec['base']['asset'], 'realistic_body_male')
                self.assertEqual(spec['base']['object'], 'GEO-body_male_realistic')
                self.assertFalse(recipe['unresolved_design'])
                self.assertNotIn('view_transforms', spec)
                self.assertNotIn('per_view_cloth_pose', spec)
                for view in ('front', 'rear'):
                    self.assertEqual(sha(ROOT.parents[2] / recipe['sources'][view]),
                                     recipe['source_sha256'][view])
                validate(spec)

    def test_level_shoulders_and_planted_true_turn_on_all_three_bodies(self):
        for name in FIGURES:
            with self.subTest(figure=name):
                spec = compile_recipe(json.loads((ROOT / name / 'measurements.json').read_text()))
                report = pose_gates(spec)
                self.assertTrue(report['passed'], report)
                # A wrong 3D shoulder height must fail even if 2D measurements
                # happen to fit inside the allowed front pixel tolerance.
                wrong = deepcopy(spec)
                wrong['joints']['shoulder_far'][2] += TEST_DEFAULTS['shoulder_mutation_m']
                self.assertFalse(pose_gates(wrong)['passed'])

    def test_named_features_and_attachment_ownership(self):
        recipes = {n: json.loads((ROOT / n / 'measurements.json').read_text()) for n in FIGURES}
        mimic = recipes['hollow_mimic']
        self.assertEqual(mimic['features']['violet_crack']['views'], ['front'])
        self.assertEqual(mimic['features']['violet_crack']['part'], 'head')
        self.assertFalse(any('cape' in p['part'] or 'weapon' in p['id'] for p in mimic['surfaces']))
        briar = recipes['briar_weaver']
        self.assertEqual(briar['features']['green_eye']['views'], ['front'])
        self.assertEqual(briar['features']['green_eye']['part'], 'head')
        for piece in briar['surfaces']:
            if piece['id'].startswith('mantle_thorn'):
                self.assertEqual(piece['part'], 'torso')
            if piece['id'].startswith('fore_thorn'):
                self.assertEqual(piece['part'], 'fore_' + piece['id'].split('_')[2])
        mortar = compile_recipe(recipes['slag_mortar'])
        feature = mortar['native_features']['molten_slag']
        self.assertEqual(feature['visibility'], {'front': 'visible', 'rear': 'visible'})
        self.assertEqual(feature['part'], 'mortar')
        self.assertEqual(feature['objects'], ['slag_surface'])
        for piece in mortar['pieces']:
            if piece['part'] == 'mortar':
                self.assertEqual(piece.get('rig_bone'), 'torso', piece['id'])
        self.assertIn('mortar_pivot', mortar['joints'])

    def test_new_sampling_and_attachment_fields_are_opt_in(self):
        project=ROOT.parents[2]
        self.assertEqual(foreign_maquette_changes(project,BASELINE_COMMIT,UNIT_HEAD,FIGURES),[])
        with historical_compiler(project,UNIT_HEAD) as compile_historical:
            for relative in tracked_paths(project,UNIT_HEAD,'spec/art_identity/maquettes/'):
                recipe_path=Path(relative)
                if recipe_path.name!='measurements.json' or len(recipe_path.parts)!=5:
                    continue
                if recipe_path.parent.name in FIGURES:
                    continue
                with self.subTest(figure=recipe_path.parent.name):
                    recipe = revision_json(project,UNIT_HEAD,relative)
                    report = revision_json(project,UNIT_HEAD,(recipe_path.parent/'delivery/build_report.json').as_posix())
                    self.assertEqual(digest(compile_historical(recipe)), report['spec_hash'])
        recipe = json.loads((ROOT / 'hollow_mimic/measurements.json').read_text())
        for level in TEST_DEFAULTS['invalid_levels']:
            wrong = deepcopy(recipe)
            wrong['anatomy_subdivision_level'] = level
            with self.assertRaisesRegex(ValueError, 'subdivision level'):
                compile_recipe(wrong)


class DeliveryTests(unittest.TestCase):
    def test_contact_sheet_uses_current_overlays_and_native_scale_clays(self):
        folder = ROOT / 'hollow_mimic/delivery/review'
        receipt = json.loads((folder / 'contact_sheet.json').read_text())
        self.assertEqual(receipt['native_clay_scale'], '1:1, 1024 px / 2.4 m')
        self.assertEqual(sha(folder / 'contact_sheet.webp'), receipt['output_sha256'])
        for name, expected in receipt['inputs_sha256'].items():
            self.assertEqual(sha(ROOT / name), expected, name)
        for figure in FIGURES:
            for name in ('fit_overlay.png', 'front_clay.png', 'rear_clay.png'):
                self.assertIn(figure + '/delivery/' + name, receipt['inputs_sha256'])

    def test_mutated_passing_fit_cannot_reuse_the_delivery_seal(self):
        with tempfile.TemporaryDirectory() as temporary:
            folder = Path(temporary)
            source = ROOT / 'hollow_mimic'
            shutil.copyfile(source / 'measurements.json', folder / 'measurements.json')
            shutil.copytree(source / 'delivery', folder / 'delivery')
            validate_acceptance(folder)
            path = folder / 'delivery/fit_report.json'
            report = json.loads(path.read_text())
            report['views']['front']['iou'] = 1
            path.write_text(json.dumps(report))
            with self.assertRaisesRegex(ValueError, 'acceptance hash binding'):
                validate_acceptance(folder)

    def test_current_deliveries_pass_hash_bound_fit_pose_and_native_gates(self):
        for name in FIGURES:
            with self.subTest(figure=name):
                folder = ROOT / name
                recipe = json.loads((folder / 'measurements.json').read_text())
                spec = compile_recipe(recipe)
                capture = folder / 'delivery'
                retained = json.loads((capture / 'fit_report.json').read_text())
                report = inspect(folder, capture)
                self.assertEqual(retained, report, 'Retained acceptance report must be reproducible')
                self.assertTrue(report['passed'], report)
                validate_delivery(spec, capture)
                validate_acceptance(folder)
                for view in ('front', 'rear'):
                    coverage = report['views'][view]['per_part_coverage']
                    self.assertEqual(set(coverage), set(spec['labels']))
                    for part, values in coverage.items():
                        self.assertGreater(values['solo_pixels'], 0, (view, part))
                        self.assertTrue(values['pure_owner_pixels'] or values['explicit_occlusion'], (view, part))

    def test_curated_manifests_and_fresh_regeneration(self):
        for name in FIGURES:
            with self.subTest(figure=name):
                folder = ROOT / name
                result = verify(folder)
                self.assertLessEqual(result['bytes'], 6_000_000)
                receipt = json.loads((folder / 'delivery/validation/regeneration/regeneration.json').read_text())
                self.assertTrue(receipt['passed'])
                self.assertFalse(receipt['cache_reused'])
                for view in ('front', 'rear'):
                    for kind in ('clay', 'parts'):
                        self.assertEqual(receipt['views'][view][kind]['sha256'],
                                         receipt['views'][view][kind]['expected_sha256'])


if __name__ == '__main__':
    unittest.main()
