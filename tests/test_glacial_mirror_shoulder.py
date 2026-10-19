"""mq-08: a bounded shoulder edit, preserved anatomy, complete capture batches."""
import json
import hashlib
from pathlib import Path
import unittest

import numpy as np
from PIL import Image

from spec.art_identity.maquettes.blender.capture_manifest import selected_solos
from spec.art_identity.maquettes.blender.compile_recipe import compile_recipe
from spec.art_identity.maquettes.blender.contract import digest
from spec.art_identity.maquettes.glacial_mirror.shoulder_revision import revise, euler_matrix, matrix_euler
from spec.art_identity.maquettes.raster import project

ROOT = Path(__file__).resolve().parents[1]
FIGURE = ROOT / 'spec/art_identity/maquettes/glacial_mirror'
TEST_DEFAULTS = {'decimal_places': 12, 'array_tolerance': 1e-12,
                 'euler_cases': [[0, 0, 0], [.2, -.4, .6], [-.5, .3, -1.2]],
                 'selection_labels': ['head', 'torso', 'hand'], 'selection': ['hand', 'head'],
                 'invalid_selections': [[], ['head', 'head'], ['missing']]}


def baseline():
    retained = FIGURE / 'delivery/review/mq08_before_recipe.json'
    return json.loads((retained if retained.exists() else FIGURE / 'proof/measurements_before.json').read_text())


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
            folder = FIGURE.parent / name
            spec = compile_recipe(json.loads((folder / 'measurements.json').read_text()))
            report = json.loads((folder / 'delivery/build_report.json').read_text())
            self.assertEqual(digest(spec), report['spec_hash'], name)
        lancer = json.loads((FIGURE.parent / 'frostglass_lancer/spec_r3.json').read_text())
        reference = FIGURE.parent / 'burrow_grub/delivery/validation/feedback_2/baselines/frostglass_lancer/regeneration.json'
        self.assertEqual(digest(lancer), json.loads(reference.read_text())['compiled_spec_hash'])

    def test_native_sheet_cells_and_historical_clays_match_bound_pixels(self):
        from html.parser import HTMLParser
        from spec.art_identity.maquettes.blender.curate_delivery import sha
        folder = FIGURE / 'delivery/review'
        report = json.loads((folder / 'mq08_gates.json').read_text())
        self.assertTrue(report['passed'])
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
