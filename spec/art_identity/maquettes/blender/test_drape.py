"""Tailoring regressions, including the rejected all-pinned/one-frame path."""
from copy import deepcopy
import unittest

import numpy as np

from spec.art_identity.maquettes.blender.drape import tailor, simulation_contract, path_bands
from spec.art_identity.maquettes.blender.source_recipe import cloth


class DrapeTests(unittest.TestCase):
    def setUp(self):
        self.piece = cloth('fixture', 'cloth', 'tabard',
            [[[0, 0, 1], [1, 0, 1], [2, 0, 1], [3, 0, 1]],
             [[0, 0, 0], [1, 0, 0], [2, 0, 0], [3, 0, 0]]], False,
            {'frames': 1})
        self.settings = {'row_subdivisions': 4, 'pin_rows': [0], 'frames': 24}

    def test_only_attachment_row_is_pinned_and_free_fabric_is_refined(self):
        result = tailor(self.piece, self.settings)
        self.assertEqual(result['pattern']['pins'], [0, 1, 2, 3])
        self.assertEqual(len(result['pattern']['rows']), 5)
        np.testing.assert_allclose(result['pattern']['rows'][2]['points'][0], [0, 0, .5])
        self.assertTrue(simulation_contract(result))
        self.assertEqual(self.piece['frames'], 1)
        self.assertEqual(len(self.piece['pattern']['rows']), 2)

    def test_round_two_specs_match_their_current_recipes(self):
        import json
        from pathlib import Path
        from spec.art_identity.maquettes.blender.compile_recipe import compile_recipe
        root = Path(__file__).resolve().parents[1]
        for name in ('hoarfrost_seer', 'arc_thrall'):
            recipe = json.loads((root / name / 'measurements.json').read_text())
            from spec.art_identity.maquettes.blender.contract import digest
            provenance=json.loads((root/name/'delivery/provenance.json').read_text())
            self.assertEqual(digest(compile_recipe(recipe)),provenance['spec_hash'])

    def test_rejected_rigid_pin_and_single_frame_mutations_fail_contract(self):
        result = tailor(self.piece, self.settings)
        all_pinned = deepcopy(result)
        all_pinned['pattern']['pins'] = list(range(20))
        self.assertFalse(simulation_contract(all_pinned))
        result['frames'] = 1
        self.assertFalse(simulation_contract(result))
        with self.assertRaisesRegex(ValueError, 'free fabric'):
            tailor(self.piece, {**self.settings, 'frames': 1})

    def test_regional_contact_rejects_missing_anatomy_and_invalid_resolution(self):
        import json
        from pathlib import Path
        from spec.art_identity.maquettes.blender.contract import validate
        root = Path(__file__).resolve().parents[1]
        from spec.art_identity.maquettes.blender.compile_recipe import compile_recipe
        spec = compile_recipe(json.loads((root / 'hoarfrost_seer/measurements.json').read_text()))
        validate(spec)
        sleeve = next(p for p in spec['pieces'] if p['id'] == 'robe_torso')
        for settings in ({'regions': [], 'refine_levels': 1},
                         {'regions': ['missing'], 'refine_levels': 1},
                         {'regions': ['upper_far'], 'refine_levels': 0},
                         {'regions': ['upper_far'], 'refine_levels': 1.5},
                         {'regions': ['upper_far'], 'refine_levels': 1, 'union_regions': 'yes'}):
            sleeve['drape']['regional_contact'] = settings
            with self.assertRaisesRegex(ValueError, 'Regional cloth contact'):
                validate(spec)

    def test_native_report_rejects_exploding_fabric_and_unconstrained_pins(self):
        from spec.art_identity.maquettes.blender.drape import simulation_valid
        piece = tailor(self.piece, self.settings)
        report = {'maximum_solver_displacement': .2, 'maximum_free_solver_displacement': .2,
                  'maximum_pin_error': 1e-7, 'free_vertices': 16}
        self.assertTrue(simulation_valid(piece, report, 2.4))
        self.assertFalse(simulation_valid(piece, {**report, 'maximum_solver_displacement': 695}, 2.4))
        self.assertFalse(simulation_valid(piece, {**report, 'maximum_pin_error': .02}, 2.4))
        self.assertFalse(simulation_valid(piece, {**report, 'maximum_solver_displacement': 0}, 2.4))
        self.assertFalse(simulation_valid(piece, {**report, 'maximum_free_solver_displacement': 0}, 2.4))

    def test_measured_pleats_leave_attachment_and_retain_fabric_allowance(self):
        result = tailor(self.piece, {**self.settings,
            'pleat_profile': [0, .1, -.1, 0], 'pleat_direction': [0, 1, 0]})
        np.testing.assert_allclose(result['pattern']['rows'][0]['points'], self.piece['pattern']['rows'][0]['points'])
        self.assertAlmostEqual(result['pattern']['rows'][-1]['points'][1][1], .1)

    def test_sewn_crown_span_keeps_interpolated_attachment_fabric_pinned(self):
        piece = deepcopy(self.piece)
        piece['pattern']['rows'].append({'points': [[0, 0, -1], [1, 0, -1], [2, 0, -1], [3, 0, -1]]})
        result = tailor(piece, {**self.settings, 'pin_rows': [0, 1], 'pin_filled_spans': [[0, 1]]})
        self.assertEqual(result['pattern']['pins'], list(range(20)))
        self.assertTrue(simulation_contract(result))

    def test_cloth_resolution_preserves_authored_fold_control_points(self):
        from spec.art_identity.maquettes.blender.drape import gathered_rows
        angles = np.linspace(0, 2 * np.pi, 8, endpoint=False)
        source = [[[np.cos(a), np.sin(a), z] for a in angles] for z in [1, 0]]
        dense = [[[np.cos(a), np.sin(a), z] for a in np.linspace(0, 2 * np.pi, 16, endpoint=False)] for z in [1, 0]]
        profile = [0, .1, 0, -.1, 0, .1, 0, -.1]
        low = gathered_rows(source, True, profile, 1)
        high = gathered_rows(dense, True, profile, 1)
        np.testing.assert_allclose(np.array(high)[:, ::2], low, atol=1e-12)

    def test_bands_follow_bent_path_and_keep_prop_ownership(self):
        bands = path_bands('prop', 'club', [[0, 0, 0], [0, 0, 1], [1, 0, 1]],
            [.2, .3, .4], [{'at': .25, 'thickness': .03}, {'at': .75, 'thickness': .04}], 16)
        self.assertTrue(all(p['part'] == 'club' and p['closed'] for p in bands))
        np.testing.assert_allclose(np.array(bands[0]['path']).mean(axis=0), [0, 0, .5], atol=1e-12)
        np.testing.assert_allclose(np.array(bands[1]['path']).mean(axis=0), [.5, 0, 1], atol=1e-12)

    def test_adjacent_cloth_sleeves_share_the_elbow_ring(self):
        from spec.art_identity.maquettes.blender.source_recipe import sleeve
        seam = [0, 1, -1]
        upper = sleeve({}, 'upper', 'upper_near', [[0, 0, 1], [0, 1, 0]], [.1, .12], {}, seam, 'end')
        fore = sleeve({}, 'fore', 'fore_near', [[0, 1, 0], [0, 2, 0]], [.12, .2], {}, seam, 'start')
        np.testing.assert_allclose(upper['pattern']['rows'][-1]['points'], fore['pattern']['rows'][0]['points'])
        self.assertEqual(len(upper['pattern']['rows']), 2)

    def test_gnarled_pipe_preserves_wall_and_rejects_collapsed_lumen(self):
        from spec.art_identity.maquettes.blender.tube import tube_mesh
        profile = [[1, 1.2, 1, .9], [.9, 1, 1.2, 1]]
        vertices, faces = tube_mesh([[0, 0, 0], [0, 0, 1]], [.2, .3], .03, 4, profile)
        self.assertEqual(len(faces), 16)
        for start in (0, 8):
            for j in range(4):
                self.assertAlmostEqual(np.linalg.norm(np.subtract(vertices[start + j], vertices[start + 4 + j])), .03)
        with self.assertRaisesRegex(ValueError, 'wall-safe'):
            tube_mesh([[0, 0, 0], [0, 0, 1]], [.2, .3], .03, 4, [[.01] * 4] * 2)

    def test_armhole_cut_pins_new_seam_without_pinning_all_fabric(self):
        from spec.art_identity.maquettes.blender.cloth_cutouts import cut_pattern
        faces = [[r * 4 + c, r * 4 + c + 1, (r + 1) * 4 + c + 1, (r + 1) * 4 + c]
                 for r in range(3) for c in range(3)]
        selected, pins = cut_pattern(faces, {0}, [0, 1, 2, 3])
        self.assertEqual(len(selected), 8)
        self.assertNotIn(0, pins)
        self.assertTrue({1, 4, 5} <= set(pins))
        self.assertNotIn(10, pins)

    def test_both_skirt_labels_are_owned_by_real_cloth_faces(self):
        from types import SimpleNamespace
        from spec.art_identity.maquettes.blender.ownership import expected_materials, materials_match, assign_materials
        class Identity:
            def __matmul__(self, value):
                return value
        class MeshObject(dict):
            pass
        obj = MeshObject(part='skirt_near', side_parts=['skirt_near', 'skirt_far'])
        obj.matrix_world = Identity()
        obj.data = SimpleNamespace(vertices=[SimpleNamespace(co=np.array(v)) for v in
            [[0, 1, 0], [1, 1, 0], [0, 1, 1], [0, -1, 0], [1, -1, 0], [0, -1, 1]]],
            polygons=[SimpleNamespace(vertices=[0, 1, 2], material_index=0),
                      SimpleNamespace(vertices=[3, 4, 5], material_index=0)])
        spec = {'labels': {'skirt_near': [], 'skirt_far': []},
                'joints': {'shoulder_near': [0, 1, 0], 'shoulder_far': [0, -1, 0]}}
        expected = expected_materials(obj, spec, [1, 0, 0])
        self.assertEqual(expected, [0, 1])
        self.assertFalse(materials_match(obj, expected))
        assign_materials(obj, expected)
        self.assertTrue(materials_match(obj, expected))

    def test_continuous_sleeve_has_independent_upper_and_fore_face_owners(self):
        from types import SimpleNamespace
        from spec.art_identity.maquettes.blender.ownership import expected_materials, materials_match
        class Identity:
            def __matmul__(self, value):
                return value
        class MeshObject(dict):
            pass
        obj = MeshObject(part='upper_far', joint_parts=['upper_far', 'fore_far'],
                         joint_chain=['shoulder', 'elbow', 'wrist'])
        obj.matrix_world = Identity()
        obj.data = SimpleNamespace(vertices=[SimpleNamespace(co=np.array(p)) for p in
            [[0, 0, 1.5], [1, 0, 1.5], [0, 1, 1.5], [0, 0, .5], [1, 0, .5], [0, 1, .5]]],
            polygons=[SimpleNamespace(vertices=[0, 1, 2], material_index=0),
                      SimpleNamespace(vertices=[3, 4, 5], material_index=0)])
        spec = {'labels': {'upper_far': [], 'fore_far': []}, 'joints':
            {'shoulder': [0, 0, 2], 'elbow': [0, 0, 1], 'wrist': [0, 0, 0]}}
        self.assertEqual(expected_materials(obj, spec, [1, 0, 0]), [0, 1])
        self.assertFalse(materials_match(obj, [0, 1]))


if __name__ == '__main__':
    unittest.main()
