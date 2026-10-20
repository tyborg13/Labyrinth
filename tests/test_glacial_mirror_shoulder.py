"""mq-08: a bounded shoulder edit, preserved anatomy, complete capture batches."""
import json
import hashlib
from copy import deepcopy
from pathlib import Path
import shutil
import tempfile
import unittest
from unittest.mock import patch

import numpy as np
from PIL import Image

from spec.art_identity.maquettes.blender.capture_manifest import selected_solos
from spec.art_identity.maquettes.blender.compile_recipe import compile_recipe
from spec.art_identity.maquettes.blender.contract import digest
from spec.art_identity.maquettes.glacial_mirror.shoulder_revision import revise, euler_matrix, matrix_euler
from spec.art_identity.maquettes.raster import project
from spec.art_identity.maquettes.glacial_mirror import guards, shoulder_revision, proof
from spec.art_identity.maquettes.blender import capture_manifest
from spec.art_identity.maquettes.blender.delivery_validation import validate_delivery
from tools.unit_preservation import read_json as revision_json

ROOT = Path(__file__).resolve().parents[1]
FIGURE = ROOT / 'spec/art_identity/maquettes/glacial_mirror'
UNIT_HEAD = '8da12090193678c4705affb590202b0ad286b719'  # mq-08 signoff
TEST_DEFAULTS = {'decimal_places': 12, 'array_tolerance': 1e-12,
                 'euler_cases': [[0, 0, 0], [.2, -.4, .6], [-.5, .3, -1.2]],
                 'selection_labels': ['head', 'torso', 'hand'], 'selection': ['hand', 'head'],
                 'invalid_selections': [[], ['head', 'head'], ['missing']],
                 'cap_lift_px': 80, 'lowered_shoulder_px': 40}
ACCEPTED_DELIVERY = {'front': {'shoulder_near': [722, 308], 'shoulder_far': [280, 241.7]},
                     'rear': {'shoulder_near': [302, 240], 'shoulder_far': [744, 306.3]},
                     'tops': {'upper_near': 159, 'upper_far': 93, 'head': 68},
                     'rear_tops': {'upper_near': 32, 'upper_far': 99, 'head': 58},
                     'cap_centre_front': [280, 205.7]}


def baseline():
    retained = FIGURE / 'delivery/review/mq08_before_recipe.json'
    return json.loads((retained if retained.exists() else FIGURE / 'proof/measurements_before.json').read_text())


def current():
    return json.loads((FIGURE / 'measurements.json').read_text())


def measured():
    joints = json.loads((FIGURE / 'delivery/joints_px.json').read_text())
    tops = {name: proof.mass_top(FIGURE / 'delivery', 'front', name) for name in ACCEPTED_DELIVERY['tops']}
    return joints, tops


class GlacialMirrorShoulderTests(unittest.TestCase):
    def test_migration_reproduces_canonical_recipe_without_modifying_input(self):
        before = baseline()
        original = digest(before)
        actual = json.loads((FIGURE / 'measurements.json').read_text())
        self.assertEqual(revise(before), actual)
        self.assertEqual(digest(before), original)
        self.assertEqual(before['labels'], actual['labels'])
        self.assertEqual(before['sources'], actual['sources'])
        self.assertEqual(before['source_sha256'], actual['source_sha256'])

    def test_shoulders_are_level_in_3d_and_meet_front_projection(self):
        spec = compile_recipe(revise(baseline()))
        a, b = (spec['joints'][n] for n in ('shoulder_near', 'shoulder_far'))
        self.assertAlmostEqual(a[2], b[2], places=TEST_DEFAULTS['decimal_places'])
        near, far = project(spec, [a, b])[:, :2]
        np.testing.assert_allclose(far, [280, near[1] - .15 * abs(near[0] - far[0])], atol=1e-9)

    def test_lengths_minimum_hand_motion_and_unaffected_joints_and_surfaces(self):
        before = baseline()
        old, new = compile_recipe(before), compile_recipe(revise(before))
        changed = {'shoulder_far', 'elbow_far', 'hand_far', 'hand_tip_far'}
        for name, point in old['joints'].items():
            if name not in changed:
                self.assertEqual(point, new['joints'][name], name)
        for bone in old['armature']['bones']:
            distances = [np.linalg.norm(np.subtract(s['joints'][bone['tail']], s['joints'][bone['head']])) for s in (old, new)]
            self.assertAlmostEqual(*distances, places=TEST_DEFAULTS['decimal_places'], msg=bone['name'])
        reach = sum(np.linalg.norm(np.subtract(old['joints'][b], old['joints'][a])) for a, b in
                    [('shoulder_far', 'elbow_far'), ('elbow_far', 'hand_far')])
        distance = np.linalg.norm(np.subtract(old['joints']['hand_far'], new['joints']['shoulder_far']))
        movement = np.linalg.norm(np.subtract(old['joints']['hand_far'], new['joints']['hand_far']))
        self.assertAlmostEqual(movement, max(0, distance - reach), places=TEST_DEFAULTS['decimal_places'])
        changed_pieces = {'upper_far', 'fore_far', 'hand_far', 'elbow_far_bedding', 'shoulder_far_mass'}
        for a, b in zip(old['pieces'], new['pieces']):
            if a['id'] not in changed_pieces:
                self.assertEqual(a, b, a['id'])
        self.assertFalse(any('capture_view' in p for p in new['pieces']))

    def test_far_cap_uses_existing_near_crest_dimensions_and_sculpt(self):
        recipe = revise(baseline())
        surfaces = {p['id']: p for p in recipe['native_solids']['surfaces']}
        for key, value in surfaces['shoulder_near_crest'].items():
            if key not in {'id', 'part', 'rig_bone', 'centre_px'}:
                self.assertEqual(value, surfaces['shoulder_far_mass'][key], key)
        for candidate in (recipe, current()):
            spec = compile_recipe(candidate)
            cap = next(piece for piece in spec['pieces'] if piece['id'] == 'shoulder_far_mass')
            np.testing.assert_allclose(project(spec, [cap['centre']])[0, :2],
                                       ACCEPTED_DELIVERY['cap_centre_front'], atol=TEST_DEFAULTS['array_tolerance'])

    def test_delivery_measurements_and_live_certification(self):
        joints, tops = measured()
        for view in ('front', 'rear'):
            for name, expected in ACCEPTED_DELIVERY[view].items():
                self.assertEqual(joints[view][name], expected)
        near, far = (joints['front']['shoulder_' + side] for side in ('near', 'far'))
        self.assertAlmostEqual(near[1] - far[1], .15 * abs(near[0] - far[0]))
        for name, expected in ACCEPTED_DELIVERY['tops'].items():
            self.assertEqual(tops[name][1], expected)
        for name, expected in ACCEPTED_DELIVERY['rear_tops'].items():
            self.assertEqual(proof.mass_top(FIGURE / 'delivery', 'rear', name)[1], expected)
        spec = compile_recipe(current())
        from spec.art_identity.maquettes.raster import camera
        np.testing.assert_allclose(camera(spec, 'rear')[0] @ np.linalg.inv(camera(spec, 'front')[0]),
                                   np.diag([-1, -1, 1, 1]), atol=TEST_DEFAULTS['array_tolerance'])
        self.assertTrue(all(guards.geometry_checks(spec, joints['front'], tops).values()))
        # Recompute masks, fit, native reports and the live guards. A saved
        # mq08_gates.json summary cannot establish a passing certificate.
        self.assertTrue(proof.evaluate(FIGURE / 'proof/before', FIGURE / 'delivery')['passed'])

    def test_live_shoulder_guard_rejects_lowered_shoulder(self):
        joints, tops = measured()
        spec = compile_recipe(current())
        joints['front']['shoulder_far'][1] += TEST_DEFAULTS['lowered_shoulder_px']
        self.assertFalse(guards.geometry_checks(spec, joints['front'], tops)['front_shoulder_rule'])

    def test_live_pauldron_guard_rejects_cap_lift_in_migration_and_canonical(self):
        recipe = deepcopy(current())
        cap = next(p for p in recipe['native_solids']['surfaces'] if p['id'] == 'shoulder_far_mass')
        for pixel in cap['centre_px']:
            pixel[1] -= TEST_DEFAULTS['cap_lift_px'] / 4
        # Reproducing the same bad recipe is deliberately insufficient.
        with patch.object(shoulder_revision, 'revise', return_value=deepcopy(recipe)):
            self.assertEqual(shoulder_revision.revise(baseline()), recipe)
            joints, tops = measured()
            checks = guards.geometry_checks(compile_recipe(recipe), joints['front'], tops)
            self.assertFalse(checks['pauldron_top'])
        # Also exercise the actual raster-top branch, independently of centre.
        tops['upper_far'][1] -= TEST_DEFAULTS['cap_lift_px']
        self.assertFalse(guards.geometry_checks(compile_recipe(current()), joints['front'], tops)['pauldron_top'])

    def test_live_turn_guard_rejects_mirrored_rear(self):
        from spec.art_identity.maquettes.raster import camera
        spec = compile_recipe(current())
        spec['view_transforms'] = {}
        base = compile_recipe(current())
        for view in ('front', 'rear'):
            matrix, target, _, scale = camera(base, view)
            if view == 'rear':
                matrix = matrix @ np.diag([-1, 1, 1, 1])
            spec['view_transforms'][view] = {'object_to_world': matrix.tolist(), 'target': target.tolist(),
                                           'azimuth_deg': 45, 'elevation_deg': 30, 'ortho_scale': scale}
        joints, tops = measured()
        self.assertFalse(guards.geometry_checks(spec, joints['front'], tops)['same_body_180_turn'])

    def test_partial_capture_never_receives_full_delivery_certification(self):
        spec = compile_recipe(current())
        with tempfile.TemporaryDirectory() as temporary:
            folder = Path(temporary) / 'capture'
            shutil.copytree(FIGURE / 'delivery', folder)
            validate_delivery(spec, folder)
            path = folder / 'capture_manifest.json'
            original = path.read_text()
            # Even complete stale files from an earlier run must not turn an
            # explicitly selected solo batch into a full certificate.
            for selection in (['upper_far'], list(spec['labels'])):
                mode = capture_manifest.capture_mode(solo_parts=selection)
                path.write_text(original.replace('"mode": "full"', '"mode": "' + mode + '"'))
                with self.assertRaisesRegex(ValueError, 'Incompatible Blender capture mode'):
                    validate_delivery(spec, folder)

    def test_euler_round_trip_retains_rigid_lengths(self):
        for angles in TEST_DEFAULTS['euler_cases']:
            rotation = euler_matrix(angles)
            np.testing.assert_allclose(euler_matrix(matrix_euler(rotation)), rotation, atol=TEST_DEFAULTS['array_tolerance'])
            np.testing.assert_allclose(rotation.T @ rotation, np.eye(3), atol=TEST_DEFAULTS['array_tolerance'])

    def test_bounded_solos_retain_default_order_and_reject_incomplete_identity(self):
        labels = dict.fromkeys(TEST_DEFAULTS['selection_labels'])
        self.assertEqual(selected_solos(labels), list(labels))
        self.assertEqual(selected_solos(labels, TEST_DEFAULTS['selection']), TEST_DEFAULTS['selection'])
        for bad in TEST_DEFAULTS['invalid_selections']:
            with self.assertRaises(ValueError):
                selected_solos(labels, bad)

    def test_every_other_compiled_recipe_matches_its_unchanged_delivery(self):
        for name in ('hoarfrost_seer', 'gale_herald', 'arc_thrall', 'gloam_stalker', 'burrow_grub', 'ember_tick'):
            relative = 'spec/art_identity/maquettes/' + name
            spec = compile_recipe(revision_json(ROOT, UNIT_HEAD, relative + '/measurements.json'))
            report = revision_json(ROOT, UNIT_HEAD, relative + '/delivery/build_report.json')
            self.assertEqual(digest(spec), report['spec_hash'], name)
        lancer = revision_json(ROOT, UNIT_HEAD, 'spec/art_identity/maquettes/frostglass_lancer/spec_r3.json')
        reference = 'spec/art_identity/maquettes/burrow_grub/delivery/validation/feedback_2/baselines/frostglass_lancer/regeneration.json'
        self.assertEqual(digest(lancer), revision_json(ROOT, UNIT_HEAD, reference)['compiled_spec_hash'])

    def test_native_sheet_cells_and_historical_clays_match_bound_pixels(self):
        from html.parser import HTMLParser
        from spec.art_identity.maquettes.blender.curate_delivery import sha
        folder = FIGURE / 'delivery/review'
        report = json.loads((folder / 'mq08_gates.json').read_text())
        joints, tops = measured()
        self.assertTrue(all(guards.geometry_checks(compile_recipe(current()), joints['front'], tops).values()))
        self.assertEqual(report['sheet']['file_sha256'], sha(folder / 'mq08_shoulders.html'))
        self.assertEqual(len(report['sheet']['cells']), 6)
        for cell in report['sheet']['cells']:
            path = (folder / cell['path']).resolve()
            self.assertTrue(path.is_relative_to(FIGURE))
            self.assertEqual(sha(path), cell['sha256'])
            with Image.open(path) as image:
                self.assertEqual(image.size, (1024, 1024))
                if cell['state'] == 'before':
                    self.assertEqual(hashlib.sha256(image.convert('RGBA').tobytes()).hexdigest(),
                                     report['baseline_clay_rgba_sha256'][cell['view']])
        class Cells(HTMLParser):
            def __init__(self):
                super().__init__()
                self.images = []
            def handle_starttag(self, tag, attrs):
                if tag == 'img':
                    self.images.append(dict(attrs))
        parsed = Cells()
        parsed.feed((folder / 'mq08_shoulders.html').read_text())
        self.assertEqual(len(parsed.images), 6)
        self.assertTrue(all(c['width'] == '1024' and c['height'] == '1024' for c in parsed.images))


if __name__ == '__main__':
    unittest.main()
