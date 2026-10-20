"""mq-07: exact-length arm correction, capped forearm and unchanged roster."""
from collections import Counter
from copy import deepcopy
import json
from pathlib import Path
import tempfile
import unittest

import numpy as np
from PIL import Image

from spec.art_identity.maquettes.blender.capped_cylinder import cylinder_mesh, sheath_mesh
from spec.art_identity.maquettes.blender.compile_recipe import compile_recipe
from spec.art_identity.maquettes.blender.contract import digest, validate
from spec.art_identity.maquettes.blender.pose_adjustment import solve_two_bone
from spec.art_identity.maquettes.blender.source_recipe import path_points
from spec.art_identity.maquettes.blender.socket_tuck import boundary_loop, tuck_mesh
from spec.art_identity.maquettes.blender.view_states import view_parts
from spec.art_identity.maquettes.arc_thrall.r2.proof import joints, pose_gates, review_sheet
from tools.unit_preservation import read_json as revision_json


ROOT = Path(__file__).resolve().parents[1] / 'spec/art_identity/maquettes'
UNIT_HEAD = 'c1ecf9f226f632b3298f29576e967cfa73afa1b1'  # mq-07 signoff
TEST_DEFAULTS = {'cylinder_start': [0, 0, 0], 'cylinder_tip': [0, 0, 3],
                 'cylinder_radius': .5, 'sides': 16, 'cap_rings': 4,
                 'scale_mutation_multiplier': 2,
                 'old_cell_rgba': (40, 50, 60, 255), 'new_cell_rgba': (70, 80, 90, 255)}


class ThrallRevisionTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.original_recipe = json.loads((ROOT / 'arc_thrall/r2/baseline_measurements.json').read_text())
        cls.recipe = json.loads((ROOT / 'arc_thrall/r2/measurements.json').read_text())
        cls.old = compile_recipe(cls.original_recipe)
        cls.new = compile_recipe(cls.recipe)

    def test_shoulder_turn_and_lengths_outside_the_new_leg_plant(self):
        report = pose_gates(self.old, self.new)
        self.assertTrue(report['passed'], report)
        self.assertAlmostEqual(report['joints_px']['front']['shoulder_far'][0], 338)
        self.assertAlmostEqual(report['joints_px']['front']['shoulder_far'][1], 310.3)
        self.assertAlmostEqual(report['joints_px']['rear']['shoulder_far'][1], 385.7)
        self.assertAlmostEqual(report['expected_far_above_near_px'], 41.7)
        self.assertEqual(report['feet']['rear']['lower_anatomical_side'], 'far')

    def test_claw_ends_at_nearest_reachable_point_and_elbow_straightens(self):
        old, new = self.old['joints'], self.new['joints']
        a, b, c = (np.array(old[k]) for k in ['shoulder_far', 'elbow_far', 'hand_far'])
        root, elbow, hand = (np.array(new[k]) for k in ['shoulder_far', 'elbow_far', 'hand_far'])
        reach = np.linalg.norm(b - a) + np.linalg.norm(c - b)
        self.assertAlmostEqual(np.linalg.norm(hand - root), reach)
        self.assertAlmostEqual(np.linalg.norm(hand - c), np.linalg.norm(c - root) - reach)
        self.assertLess(np.linalg.norm(np.cross(elbow - root, hand - elbow)), 1e-8)
        np.testing.assert_allclose(np.subtract(new['hand_tip_far'], new['hand_far']),
                                   np.subtract(old['hand_tip_far'], old['hand_far']))

    def test_unchanged_joints_and_original_source_anatomy_are_preserved(self):
        moved = {'shoulder_far', 'elbow_far', 'hand_far', 'hand_tip_far', 'knee_far', 'ankle_far', 'foot_tip_far'}
        for name in set(self.old['joints']) - moved:
            self.assertEqual(self.old['joints'][name], self.new['joints'][name], name)
        self.assertEqual(self.new['source_fit_joints'], self.old['joints'])
        for key in ('body_source_profiles', 'sources', 'source_sha256', 'bone_scales'):
            self.assertEqual(self.recipe[key], self.original_recipe[key], key)
        self.assertEqual(self.recipe['surfaces'][:-1], self.original_recipe['surfaces'][:-1])

    def test_floor_plant_uses_merged_bone_method_and_keeps_front_projection(self):
        from spec.art_identity.maquettes.blender.floor_contact import spec_contacts
        old, new = self.old['joints'], self.new['joints']
        self.assertAlmostEqual(new['ankle_far'][2], new['ankle_near'][2])
        self.assertEqual(new['hip_far'], old['hip_far'])
        report = spec_contacts(self.new)
        self.assertTrue(report['passed'])
        self.assertEqual(report['excepted_offenders'], [])
        config = self.recipe['planted_leg']
        self.assertEqual(config['leg_bones'], ['hip_far', 'knee_far', 'ankle_far'])
        np.testing.assert_allclose(np.subtract(new['foot_tip_far'], new['ankle_far']),
                                   np.subtract(old['foot_tip_far'], old['ankle_far']))
        from spec.art_identity.maquettes.raster import project
        for name in [*config['joint_chain'], *config['translate_with_ankle']]:
            np.testing.assert_allclose(project(self.old, old[name], 'front')[:2],
                                       project(self.new, new[name], 'front')[:2], atol=1e-10)
        from spec.art_identity.maquettes.blender.delivery_validation import geometry_checks
        self.assertIn('floor_contact_correction', geometry_checks(self.new))
        invalid = deepcopy(self.recipe)
        invalid['planted_leg']['leg_bones'] = ['thigh_far']
        with self.assertRaisesRegex(ValueError, 'not region labels'):
            compile_recipe(invalid)

    def test_canonical_delivery_is_the_planted_r2(self):
        canonical = json.loads((ROOT / 'arc_thrall/measurements.json').read_text())
        self.assertEqual(canonical, self.recipe)
        build = json.loads((ROOT / 'arc_thrall/delivery/build_report.json').read_text())
        self.assertEqual(build['spec_hash'], digest(self.new))
        self.assertTrue(build['geometry_details']['floor_contact']['passed'])
        exceptions = json.loads((ROOT / 'hoarfrost_seer/rear_turn/feedback2/floor_guard_exceptions.json').read_text())
        self.assertEqual(exceptions['figures']['arc_thrall'], [])

    def test_single_body_reader_uses_native_pan_and_rejects_changed_scale(self):
        from spec.art_identity.maquettes.blender.view_delivery import spec_for_view
        from spec.art_identity.maquettes.raster import project
        from spec.art_identity.maquettes.arc_thrall.r2.assemble import ASSEMBLY_DEFAULTS
        folder = ROOT / 'arc_thrall/delivery'
        recorded = json.loads((folder / 'joints_px.json').read_text())
        self.assertEqual(spec_for_view(self.new, folder, 'front'), self.new)
        rear = spec_for_view(self.new, folder, 'rear')
        self.assertEqual(rear['joints'], self.new['joints'])
        self.assertEqual(rear['ortho_scale'], self.new['ortho_scale'])
        for name, point in rear['joints'].items():
            np.testing.assert_allclose(project(rear, point, 'rear')[:2], recorded['rear'][name],
                                       atol=ASSEMBLY_DEFAULTS['joint_tolerance_px'])
        with tempfile.TemporaryDirectory() as temporary:
            target = Path(temporary)
            frame = json.loads((folder / 'capture_frame.json').read_text())
            frame['rear']['ortho_scale'] *= TEST_DEFAULTS['scale_mutation_multiplier']
            (target / 'capture_frame.json').write_text(json.dumps(frame))
            with self.assertRaisesRegex(ValueError, 'pan-only framing'):
                spec_for_view(self.new, target, 'rear')

    def test_only_removed_labels_are_hand_and_club_and_anatomy_is_hidden(self):
        self.assertEqual(set(self.old['labels']) - set(self.new['labels']), {'hand_near', 'club'})
        self.assertEqual(set(self.new['labels']) - set(self.old['labels']), set())
        self.assertEqual(self.new['base']['covered_regions'], ['fore_near', 'hand_near'])
        for view in ('front', 'rear'):
            self.assertEqual(view_parts(self.new, view), set(self.new['labels']))
        piece = next(p for p in self.new['pieces'] if p['id'] == 'forearm_sheath')
        self.assertEqual(piece['part'], 'fore_near')
        self.assertFalse(any(p['part'] in ('hand_near', 'club') for p in self.new['pieces']))
        validate(self.new)
        bad = deepcopy(self.new)
        bad['base']['covered_regions'].remove('hand_near')
        with self.assertRaisesRegex(ValueError, 'Source cage|Unknown bone'):
            validate(bad)

    def test_feedback_decides_all_design_fields_and_cracks_are_paint_only(self):
        self.assertEqual(self.recipe['unresolved_design'], {})
        self.assertFalse(self.recipe['features']['lightning_cracks']['geometry'])
        self.assertEqual(self.new, compile_recipe(self.recipe))

    def test_sheath_uses_the_old_club_tip_and_feedback_dimensions(self):
        old_club = next(p for p in self.original_recipe['surfaces'] if p['id'] == 'club')
        sheath = next(p for p in self.recipe['surfaces'] if p['id'] == 'forearm_sheath')
        points = path_points(self.new, sheath)
        np.testing.assert_allclose(points[0], self.old['joints']['elbow_near'])
        np.testing.assert_allclose(points[-1], path_points(self.old, old_club)[-1])
        self.assertEqual({key: sheath[key] for key in ('diameter_px', 'elbow_offset_px', 'band_height_px',
                         'band_raise_px', 'dome_height_px', 'rivets')},
                         {'diameter_px': 17, 'elbow_offset_px': -2, 'band_height_px': 3,
                          'band_raise_px': 1, 'dome_height_px': .35 * 17, 'rivets': False})
        from spec.art_identity.maquettes.arc_thrall.r2.tube_proof import geometry_dimensions
        report = geometry_dimensions(self.new, self.recipe)
        json.dumps(report)  # Native reports must serialize without NumPy scalar coercion.
        self.assertTrue(report['passed'], report)
        self.assertAlmostEqual(report['dimensions']['mouth_offset_front_px'], -8)
        self.assertAlmostEqual(report['dimensions']['shaft_diameter_front_px'], 68, delta=1)
        self.assertAlmostEqual(report['dimensions']['band_height_front_px'], 12)
        self.assertAlmostEqual(report['dimensions']['dome_height_front_px'], 23.8)

    def test_other_figure_spec_hashes_remain_their_delivered_values(self):
        for name in ('hoarfrost_seer', 'gale_herald', 'gloam_stalker'):
            with self.subTest(name=name):
                relative = 'spec/art_identity/maquettes/' + name
                recipe = revision_json(ROOT.parents[2], UNIT_HEAD, relative + '/measurements.json')
                report = revision_json(ROOT.parents[2], UNIT_HEAD, relative + '/delivery/build_report.json')
                self.assertEqual(digest(compile_recipe(recipe)), report['spec_hash'])

    def test_review_sheet_copies_native_cells_without_resizing(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            old, new = root / 'old', root / 'new'
            old.mkdir(); new.mkdir()
            for view in ('front', 'rear'):
                Image.new('RGBA', (1024, 1024), TEST_DEFAULTS['old_cell_rgba']).save(old / (view + '_clay.png'))
                for kind in ('clay', 'parts'):
                    Image.new('RGBA', (1024, 1024), TEST_DEFAULTS['new_cell_rgba']).save(new / (view + '_' + kind + '.png'))
            output = root / 'sheet.png'
            review_sheet(old, new, joints(self.old), joints(self.new), output)
            with Image.open(output) as image:
                self.assertEqual(image.size, (3072, 2900))
                self.assertEqual(image.getpixel((10, 38)), TEST_DEFAULTS['old_cell_rgba'])
                self.assertEqual(image.getpixel((1034, 38)), TEST_DEFAULTS['new_cell_rgba'])
                self.assertEqual(image.getpixel((384, 2132)), TEST_DEFAULTS['new_cell_rgba'])


class GeometryHelperTests(unittest.TestCase):
    def test_socket_tuck_preserves_the_source_boundary_and_fits_the_authored_bore(self):
        faces = [[0,1,5,4], [1,2,6,5], [2,3,7,6], [3,0,4,7],
                 [4,5,9,8], [5,6,10,9], [6,7,11,10], [7,4,8,11]]
        self.assertEqual(boundary_loop(faces, ['upper']*4 + ['fore']*4, 'upper', 'fore'), [4,7,6,5])
        with self.assertRaises(ValueError):
            boundary_loop(faces, ['upper']*8, 'upper', 'fore')
        border = [[-1,-1,0], [-1,1,0], [1,1,0], [1,-1,0]]
        vertices, polygons = tuck_mesh(border, [0,0,1], [0,0,1], .5)
        np.testing.assert_array_equal(vertices[:4], border)
        np.testing.assert_allclose(np.array(vertices[4:8])[:, 2], 1)
        self.assertTrue(np.all(np.linalg.norm(np.array(vertices[4:8])[:, :2], axis=1) <= .5))
        self.assertEqual(len(polygons), 8)

    def test_reachable_hand_stays_put_and_original_bend_side_is_retained(self):
        elbow, hand = solve_two_bone([0, 0, 0], [1, 1, 0], [2, 0, 0], [0, .2, 0])
        np.testing.assert_allclose(hand, [2, 0, 0])
        self.assertGreater(elbow[1], 0)
        self.assertAlmostEqual(np.linalg.norm(np.subtract(elbow, [0, .2, 0])), np.sqrt(2))
        self.assertAlmostEqual(np.linalg.norm(np.subtract(hand, elbow)), np.sqrt(2))

    def test_unreachable_target_clamps_to_nearest_reach_with_exact_lengths(self):
        elbow, hand = solve_two_bone([0, 0, 0], [1, 0, 0], [2, 0, 0], [-1, 0, 0])
        np.testing.assert_allclose(elbow, [0, 0, 0])
        np.testing.assert_allclose(hand, [1, 0, 0])
        for bad in [([0, 0, 0], [0, 0, 0], [1, 0, 0], [2, 0, 0]),
                    ([0, 0, 0], [1, 0, 0], [2, 0, 0], [2, 0, 0])]:
            with self.assertRaises(ValueError):
                solve_two_bone(*bad)

    def test_cylinder_is_one_watertight_component_with_solid_rounded_tip(self):
        vertices, faces = cylinder_mesh(TEST_DEFAULTS['cylinder_start'], TEST_DEFAULTS['cylinder_tip'],
                                        TEST_DEFAULTS['cylinder_radius'], TEST_DEFAULTS['sides'], TEST_DEFAULTS['cap_rings'])
        edges = Counter(tuple(sorted((a, b))) for face in faces for a, b in zip(face, face[1:] + face[:1]))
        self.assertTrue(all(count == 2 for count in edges.values()))
        self.assertEqual(len(vertices) - len(edges) + len(faces), 2)
        np.testing.assert_allclose(vertices[-1], TEST_DEFAULTS['cylinder_tip'])
        # No inner pipe: each cylinder wall has precisely one radius.
        radii = np.linalg.norm(np.array(vertices)[:32, :2], axis=1)
        np.testing.assert_allclose(radii, TEST_DEFAULTS['cylinder_radius'])
        self.assertEqual(vertices, cylinder_mesh([0, 0, 0], [0, 0, 3], .5, 16, 4)[0])
        with self.assertRaises(ValueError):
            cylinder_mesh([0, 0, 0], [0, 0, .2], .5, 16, 4)

    def test_open_sheath_has_an_annular_mouth_single_band_and_closed_distal_dome(self):
        vertices, faces = sheath_mesh([0, 0, 0], [0, 0, 3], .5, .1, .35, .2, .05, 16, 4)
        points = np.array(vertices)
        edges = Counter(tuple(sorted((a, b))) for face in faces for a, b in zip(face, face[1:] + face[:1]))
        self.assertTrue(all(n == 2 for n in edges.values()))
        self.assertEqual(len(vertices) - len(edges) + len(faces), 2)
        mouth_faces = [face for face in faces if np.all(points[face, 2] == 0)]
        self.assertEqual(len(mouth_faces), 16)
        for face in mouth_faces:
            # Every mouth face lies in one narrow angular sector; none can
            # span or cover the empty centre of the socket.
            centre = points[face, :2].mean(0)
            self.assertTrue(np.all(points[face, :2] @ centre > 0))
        self.assertEqual(set(np.round(np.linalg.norm(points[points[:, 2] == 0, :2], axis=1), 8)), {.4, .55})
        np.testing.assert_allclose(points[points[:, 2].argmax()], [0, 0, 3])
        self.assertEqual(len({round(float(z), 8) for x, y, z in points if abs(np.hypot(x, y) - .55) < 1e-8}), 2)
        with self.assertRaises(ValueError):
            sheath_mesh([0, 0, 0], [0, 0, 3], .5, .5, .35, .2, .05, 16, 4)


if __name__ == '__main__':
    unittest.main()
