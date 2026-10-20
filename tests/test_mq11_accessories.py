"""mq-11 portable geometry, preservation, measurement and bridge contracts."""
from collections import Counter
from copy import deepcopy
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import textwrap
import unittest
from types import SimpleNamespace
from unittest.mock import patch

import numpy as np
from PIL import Image

from spec.art_identity.maquettes.blender.accessory_geometry.forms import (
    hair_piece, belt_piece, flap_piece, pelvis_frame)
from spec.art_identity.maquettes.blender.compile_recipe import compile_recipe
from spec.art_identity.maquettes.blender.curate_delivery import sha
from spec.art_identity.maquettes.hollow_mimic.owner_review.candidate import (
    ROOT, GATES, FIGURES, compile_document, compile_candidate, assert_preserved)
from spec.art_identity.maquettes.hollow_mimic.owner_review.measurements import (
    depth_image, projected_centre_error, measure)
from spec.art_identity.maquettes.hollow_mimic.owner_review.preservation import check, status, HERE, PROJECT
from spec.art_identity.maquettes.hollow_mimic.owner_review import workflow, proof
from spec.art_identity.maquettes.raster import camera, project
from tests.mq11_preservation import BASELINE_COMMIT, MANIFEST, inherited_inventory, rr20_inventory_context
from tools.unit_preservation import read_bytes as revision_bytes

# All invented dimensions below are synthetic test geometry, never candidates.
FIXTURE = {'skull': {'crown_m': [0., 0, 1.5], 'base_m': [0., 0, .5],
                     'ear_line_m': [0., 0, 1.], 'height_m': 1., 'width_m': 1., 'lateral_axis': [0., 1., 0]},
           'scalp': {'centre_m': [0., 0, 1.1], 'radii_m': [.7, .625, .5]},
           'root_step_m': .02, 'tuft_length_m': .31, 'tuft_length_step_m': .035,
           'tuft_radii_m': [.04, .001],
           'fringe_direction': [1., 0, -1.],
           'mop_directions': [[0., 0, 1.], [-1., 0, 1.], [0., 1., 0], [0., -1., 0], [-1., 0, -1.]],
           'belt': {'forward_radius_m': .2, 'lateral_radius_m': .25, 'height_m': .1, 'hip_width_m': .5},
           'rows': [{'drop_fraction': 0, 'width_fraction': 1., 'forward_offset_m': 0., 'curve_m': 0.},
                    {'drop_fraction': .5, 'width_fraction': .9, 'forward_offset_m': .01, 'curve_m': .02},
                    {'drop_fraction': 1., 'width_fraction': .8, 'forward_offset_m': 0., 'curve_m': .02}],
           'rear_front_length_ratio': .9, 'rotation_degrees': 33.,
           'centre_mask_box': (4, 28, 4, 12), 'centre_line': [[8., 0], [8., 32]],
           'depth_rect_px': [(480, 480), (544, 480), (544, 544), (480, 544)],
           'depth_layers': [0., .1], 'test_joint_px': [512, 512],
           'attachment_camera': {'ortho_scale': 2.4, 'target': [0., 0, 1.]},
           'attachment_joints': {'hip_near': [0., .25, 1.], 'hip_far': [0., -.25, 1.],
                                 'pelvis': [0., 0, 1.]},
           'attachment_flap_size_m': [.08, .35], 'attachment_shift_px': 13.,
           'probe_import_timeout_s': 30}


def base(name):
    return compile_recipe(json.loads((ROOT / name / 'measurements.json').read_text()))


def hair_design():
    result = {k: deepcopy(FIXTURE[k]) for k in ('skull', 'scalp')}
    result['tufts'] = []
    for i in range(GATES['tuft_count']):
        root = [i * FIXTURE['root_step_m'], 0., 1.1]
        direction = np.array(FIXTURE['fringe_direction'] if i < GATES['fringe_count'] else
                             FIXTURE['mop_directions'][(i - GATES['fringe_count']) % len(FIXTURE['mop_directions'])])
        tip = (np.array(root) + direction / np.linalg.norm(direction) *
               (FIXTURE['tuft_length_m'] + i * FIXTURE['tuft_length_step_m'])).tolist()
        result['tufts'].append({'id': 'fixture_' + str(i), 'role': 'fringe' if i < GATES['fringe_count'] else 'mop',
                                'path_m': [root, tip], 'radii_m': deepcopy(FIXTURE['tuft_radii_m'])})
    return result


def mortar_design():
    return {'belt': deepcopy(FIXTURE['belt']), 'front': {'rows': deepcopy(FIXTURE['rows'])},
            'rear': {'rows': deepcopy(FIXTURE['rows']), 'front_length_ratio': FIXTURE['rear_front_length_ratio']}}


def document(name, design):
    return {'schema': 1, 'id': name, 'base_recipe_sha256': sha(ROOT / name / 'measurements.json'), 'design': design}


def unresolved_document(name):
    if name == 'hollow_mimic':
        design = hair_design()
        design['scalp'] = 'TODO_DESIGN_MIMIC_SCALP_PROFILE'
        design['tufts'] = 'TODO_DESIGN_MIMIC_TUFT_LAYOUT'
    else:
        design = mortar_design()
        design['belt'] = 'TODO_DESIGN_MORTAR_BELT_PROFILE'
        design['rear']['front_length_ratio'] = 'TODO_DESIGN_MORTAR_REAR_LENGTH_RATIO'
    return document(name, design)


class AccessoryGeometryTests(unittest.TestCase):
    def test_todos_stop_the_whole_batch_before_writes_or_native_submission(self):
        for unresolved in FIGURES:
            documents = {'hollow_mimic': document('hollow_mimic', hair_design()),
                         'slag_mortar': document('slag_mortar', mortar_design())}
            documents[unresolved] = unresolved_document(unresolved)
            with (self.subTest(unresolved=unresolved),
                  tempfile.TemporaryDirectory(prefix='mq11-no-submission-', dir=PROJECT) as temporary,
                  patch.object(workflow, 'PROJECT', Path(temporary)),
                  patch.object(workflow, 'inputs', return_value={}),
                  patch.object(workflow, 'compile_candidate', side_effect=lambda name: compile_document(name, documents[name])),
                  patch.object(workflow, 'run_job') as bridge, patch.object(workflow, 'write') as write):
                with self.assertRaisesRegex(ValueError, 'TODO_DESIGN_'):
                    workflow.prepare('test_no_submission')
                bridge.assert_not_called()
                write.assert_not_called()
                self.assertFalse(any(Path(temporary).iterdir()))

    def test_each_candidate_reports_every_missing_design_field(self):
        for name in FIGURES:
            data = unresolved_document(name)
            expected = ('TODO_DESIGN_MIMIC_SCALP_PROFILE', 'TODO_DESIGN_MIMIC_TUFT_LAYOUT') if name == 'hollow_mimic' else (
                'TODO_DESIGN_MORTAR_BELT_PROFILE', 'TODO_DESIGN_MORTAR_REAR_LENGTH_RATIO')
            with self.subTest(name=name), self.assertRaises(ValueError) as raised:
                compile_document(name, data)
            for field in expected:
                self.assertIn(field, str(raised.exception))

    def test_director_filled_candidates_compile_and_preserve_the_other_parts(self):
        for name in FIGURES:
            with self.subTest(name=name):
                candidate = compile_candidate(name)
                assert_preserved(base(name), candidate)
                self.assertEqual(candidate['mq11']['gates']['front_thigh_fraction'], 1.25)  # director: flap reaches the knee

    def test_hair_preserves_every_non_hair_piece_and_does_not_mutate_input(self):
        design = hair_design()
        original = deepcopy(design)
        before = base('hollow_mimic')
        after = compile_document('hollow_mimic', document('hollow_mimic', design))
        assert_preserved(before, after)
        self.assertEqual(design, original)
        hair = next(p for p in after['pieces'] if p['id'] == 'hair_crown')
        self.assertEqual(len(hair['swept_sections']), GATES['tuft_count'])
        self.assertEqual(hair['rig_bone'], 'head')
        self.assertEqual(hair['part'], 'head')
        self.assertEqual(before['labels'], after['labels'])

    def test_no_shared_tuft_root_or_zero_length_segment(self):
        template = next(p for p in base('hollow_mimic')['pieces'] if p['id'] == 'hair_crown')
        design = hair_design()
        design['tufts'][1]['path_m'][0] = design['tufts'][0]['path_m'][0]
        with self.assertRaisesRegex(ValueError, 'share a root'):
            hair_piece(template, design, GATES)
        design = hair_design()
        design['tufts'][0]['path_m'][1] = design['tufts'][0]['path_m'][0]
        with self.assertRaisesRegex(ValueError, 'zero-length'):
            hair_piece(template, design, GATES)

    def test_tuft_lengths_fringe_count_and_scalp_width_are_enforced(self):
        template = next(p for p in base('hollow_mimic')['pieces'] if p['id'] == 'hair_crown')
        mutations = [('head-height range', lambda d: d['tufts'][0]['path_m'][1].__setitem__(2, 4)),
                     ('Four measured fringe', lambda d: d['tufts'][0].__setitem__('role', 'mop')),
                     ('1.25 times', lambda d: d['scalp']['radii_m'].__setitem__(1, .8))]
        for error, mutate in mutations:
            design = hair_design()
            mutate(design)
            with self.subTest(error=error), self.assertRaisesRegex(ValueError, error):
                hair_piece(template, design, GATES)

    def test_uniform_fan_and_detached_roots_fail_before_blender(self):
        template = next(p for p in base('hollow_mimic')['pieces'] if p['id'] == 'hair_crown')
        design = hair_design()
        for tuft in design['tufts']:
            tuft['path_m'][1] = (np.array(tuft['path_m'][0]) + [0, 0, .4]).tolist()
        with self.assertRaisesRegex(ValueError, 'lengths must vary'):
            hair_piece(template, design, GATES)
        design = hair_design()
        design['tufts'][0]['path_m'][0] = [10, 0, 0]
        with self.assertRaisesRegex(ValueError, 'join the scalp'):
            hair_piece(template, design, GATES)

    def test_scalp_must_reach_ears_and_fringe_must_fall_forward(self):
        template = next(p for p in base('hollow_mimic')['pieces'] if p['id'] == 'hair_crown')
        design = hair_design()
        design['scalp']['radii_m'][2] = .01
        with self.assertRaisesRegex(ValueError, 'ear height'):
            hair_piece(template, design, GATES)
        design = hair_design()
        root = np.array(design['tufts'][0]['path_m'][0])
        design['tufts'][0]['path_m'][1] = (root + [0, 0, .31]).tolist()
        with self.assertRaisesRegex(ValueError, 'forward and down'):
            hair_piece(template, design, GATES)
        # JSON integer coordinates are valid; normalization must not attempt
        # an in-place float division into an integer array.
        design = hair_design()
        design['skull'].update(crown_m=[0, 0, 2], base_m=[0, 0, 1], ear_line_m=[0, 0, 1])
        design['scalp']['centre_m'] = [0, 0, 1.5]
        self.assertEqual(hair_piece(template, design, GATES)['centre'], [0, 0, 1.5])

    def test_belt_is_closed_and_follows_the_posed_hips(self):
        spec = base('slag_mortar')
        belt = belt_piece(spec, FIXTURE['belt'], 'apron', .012)
        edges = Counter(tuple(sorted((a, b))) for face in belt['faces'] for a, b in zip(face, face[1:] + face[:1]))
        self.assertEqual(set(edges.values()), {2})
        origin, forward, lateral, up, _ = pelvis_frame(spec)
        local = np.array(belt['vertices']) - origin
        self.assertAlmostEqual(np.ptp(local @ up), FIXTURE['belt']['height_m'])
        self.assertAlmostEqual(max(local @ forward), FIXTURE['belt']['forward_radius_m'])
        self.assertAlmostEqual(max(local @ lateral), FIXTURE['belt']['lateral_radius_m'])
        self.assertEqual(belt['rig_bone'], 'pelvis')

    def test_mortar_has_one_body_two_flaps_shared_ownership_and_original_rag(self):
        before = base('slag_mortar')
        after = compile_document('slag_mortar', document('slag_mortar', mortar_design()))
        assert_preserved(before, after)
        pieces = {p['id']: p for p in after['pieces']}
        for identifier in ('leather_apron', 'rear_leather_apron'):
            template = next(p for p in before['pieces'] if p['id'] == identifier)
            flap = pieces[identifier]
            self.assertEqual(flap['rag'], template['rag'])
            self.assertEqual(flap['stiffness'], template['stiffness'])
            self.assertEqual(flap['part'], 'apron')
            self.assertEqual(flap['thick'], template['thick'])
            self.assertEqual(flap['rig_bone'], 'pelvis')
            for key in ('capture_view', 'waist_anchor_px', 'back_rest'):
                self.assertNotIn(key, flap)
                self.assertNotIn(key, flap['drape'])

    def test_flap_roots_are_centred_perpendicular_to_body_forward(self):
        spec = base('slag_mortar')
        design = mortar_design()
        origin, forward, lateral, up, _ = pelvis_frame(spec)
        for side, identifier in (('front', 'leather_apron'), ('rear', 'rear_leather_apron')):
            template = next(p for p in spec['pieces'] if p['id'] == identifier)
            flap = flap_piece(template, spec, design[side], design['belt'], side, GATES)
            row = np.array(flap['pattern']['rows'][0]['points'])
            sign = 1 if side == 'front' else -1
            np.testing.assert_allclose((row - origin) @ forward, sign * design['belt']['forward_radius_m'], atol=1e-12)
            self.assertAlmostEqual(np.ptp(row @ lateral), design['belt']['hip_width_m'] * GATES['flap_hip_width'])
            self.assertAlmostEqual((row.mean(axis=0) - origin) @ lateral, 0)
            self.assertAlmostEqual((row.mean(axis=0) - origin) @ up, design['belt']['height_m'] / 2)

    def test_flap_drafting_rotates_with_the_pelvis_and_has_no_camera_branch(self):
        spec = base('slag_mortar')
        template = next(p for p in spec['pieces'] if p['id'] == 'leather_apron')
        config = mortar_design()
        first = flap_piece(template, spec, config['front'], config['belt'], 'front', GATES)
        angle = np.radians(FIXTURE['rotation_degrees'])
        rotation = np.array([[np.cos(angle), -np.sin(angle), 0], [np.sin(angle), np.cos(angle), 0], [0, 0, 1.]])
        rotated = deepcopy(spec)
        rotated['joints'] = {k: (rotation @ v).tolist() for k, v in spec['joints'].items()}
        second = flap_piece(template, rotated, config['front'], config['belt'], 'front', GATES)
        a = np.array([r['points'] for r in first['pattern']['rows']])
        b = np.array([r['points'] for r in second['pattern']['rows']])
        np.testing.assert_allclose(b, a @ rotation.T, atol=1e-12)

    def test_front_uses_director_thigh_fraction_and_back_is_shorter(self):
        spec = base('slag_mortar')
        config = mortar_design()
        drops = {}
        for side, identifier in (('front', 'leather_apron'), ('rear', 'rear_leather_apron')):
            template = next(p for p in spec['pieces'] if p['id'] == identifier)
            flap = flap_piece(template, spec, config[side], config['belt'], side, GATES)
            rows = np.array([r['points'] for r in flap['pattern']['rows']])
            drops[side] = rows[0, :, 2].mean() - rows[-1, :, 2].mean()
        thigh = np.mean([spec['joints']['hip_' + s][2] - spec['joints']['knee_' + s][2] for s in ('near', 'far')])
        self.assertAlmostEqual(drops['front'], thigh * 1.25 + config['belt']['height_m'] / 2)
        self.assertAlmostEqual(drops['rear'], drops['front'] * FIXTURE['rear_front_length_ratio'])

    def test_invalid_rear_length_and_unowned_mutations_fail(self):
        design = mortar_design()
        design['rear']['front_length_ratio'] = 1.
        with self.assertRaisesRegex(ValueError, 'shorter'):
            compile_document('slag_mortar', document('slag_mortar', design))
        spec = base('hollow_mimic')
        mutated = deepcopy(spec)
        mutated['joints']['pelvis'][0] += 1
        with self.assertRaisesRegex(ValueError, 'joints'):
            assert_preserved(spec, mutated)
        mutated = deepcopy(spec)
        mutated['per_view_cloth_pose'] = {'rear': {}}
        with self.assertRaisesRegex(ValueError, 'true camera turn'):
            assert_preserved(spec, mutated)

    def test_stale_base_and_non_owned_figure_fail(self):
        data = document('hollow_mimic', hair_design())
        data['base_recipe_sha256'] = 'stale'
        with self.assertRaisesRegex(ValueError, 'protected base'):
            compile_document('hollow_mimic', data)
        with self.assertRaisesRegex(ValueError, 'owns only'):
            compile_candidate('briar_weaver')
        with self.assertRaisesRegex(ValueError, 'plain task-local'):
            workflow.output_folder('hollow_mimic', '../escape')


class AccessoryProofTests(unittest.TestCase):
    def test_rr20_inventory_extension_preserves_all_original_lines(self):
        current = MANIFEST.read_bytes()
        original = revision_bytes(PROJECT, BASELINE_COMMIT, str(MANIFEST.relative_to(PROJECT)))
        self.assertEqual(inherited_inventory(current), original)
        for mutant in (current.replace(b'delivery/front_clay.png', b'delivery/changed.png'),
                       current.replace(b'delivery/front_clay.png\n', b''),
                       current + b'owner_review/unapproved_file.py\n'):
            with self.subTest(mutation=mutant[-60:]):
                self.assertNotEqual(inherited_inventory(mutant), original)

    def test_rr20_inventory_adapter_keeps_other_pins_live(self):
        calls = []
        sentinel = 'live-source-pin'
        gates = SimpleNamespace(digest=lambda p: calls.append(p) or sentinel)
        other = ROOT / 'hollow_mimic/measurements.json'
        with rr20_inventory_context(gates):
            self.assertEqual(gates.digest(other), sentinel)
            self.assertNotEqual(gates.digest(MANIFEST), sentinel)
        self.assertEqual(calls, [other])
        self.assertEqual(gates.digest(MANIFEST), sentinel)

    def test_before_iou_and_every_existing_delivery_remain_byte_identical(self):
        report = check()
        self.assertTrue(report['passed'])
        self.assertTrue(report['other_figure_delivery_bytes_unchanged'])
        self.assertEqual(set(report['before_iou']), set(FIGURES))
        self.assertTrue(all(report['before_iou'][name][view] >= GATES['iou'][view] for name in FIGURES for view in ('front', 'rear')))
        self.assertEqual(status()['after_iou'], {name: None for name in FIGURES})
        self.assertTrue(status()['ready_for_native_proof'])
        self.assertIsNone(status()['native_acceptance_passed'])

    def test_unresolved_status_uses_test_owned_design_files(self):
        with tempfile.TemporaryDirectory(prefix='mq11-unresolved-', dir=PROJECT) as temporary:
            paths = {}
            for name in FIGURES:
                paths[name] = Path(temporary) / (name + '.json')
                paths[name].write_text(json.dumps(unresolved_document(name)))
            with patch('spec.art_identity.maquettes.hollow_mimic.owner_review.preservation.design_path', side_effect=paths.__getitem__):
                report = status()
            self.assertFalse(report['ready_for_native_proof'])
            self.assertTrue(all(report['design_todos'].values()))

    def test_native_probe_import_and_entry_point_do_not_require_pil(self):
        code = textwrap.dedent('''
            import hashlib
            from pathlib import Path
            import sys
            import types

            class NoPIL:
                def find_spec(self, fullname, path=None, target=None):
                    if fullname == 'PIL' or fullname.startswith('PIL.'):
                        raise ModuleNotFoundError('PIL deliberately unavailable')

            sys.meta_path.insert(0, NoPIL())
            try:
                __import__('PIL')
            except ModuleNotFoundError:
                pass
            else:
                raise AssertionError('PIL blocker is inactive')
            from spec.art_identity.maquettes.hollow_mimic.owner_review import native_probe
            assert 'spec.art_identity.maquettes.blender.curate_delivery' not in sys.modules
            assert 'spec.art_identity.maquettes.hollow_mimic.batch_proof' not in sys.modules
            sys.modules['bpy'] = types.ModuleType('bpy')
            try:
                native_probe.main(sys.argv[1], sys.argv[1], sys.argv[2])
            except FileNotFoundError:
                pass
            else:
                raise AssertionError('Expected the absent test spec after loading all probe imports')
            native_probe.write(sys.argv[2], {'passed': True})
            assert native_probe.sha(sys.argv[2]) == hashlib.sha256(Path(sys.argv[2]).read_bytes()).hexdigest()
            print('MQ11_PIL_FREE_PROBE: PASS')
        ''')
        with tempfile.TemporaryDirectory(prefix='mq11-pil-free-', dir=PROJECT) as temporary:
            root = Path(temporary)
            output = root / 'capture/mq11_shape.json'
            result = subprocess.run([sys.executable, '-B', '-c', code, str(root / 'absent-spec.json'), str(output)],
                                    cwd=PROJECT, capture_output=True, text=True, timeout=FIXTURE['probe_import_timeout_s'])
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            self.assertIn('MQ11_PIL_FREE_PROBE: PASS', result.stdout)
            self.assertEqual(output.read_bytes(), b'{"passed":true}\n')

    def test_flap_centreline_uses_each_attachment_and_rejects_thirteen_pixel_shift(self):
        spec = {'id': 'slag_mortar', **deepcopy(FIXTURE['attachment_camera']),
                'joints': deepcopy(FIXTURE['attachment_joints']), 'mq11': {'design': mortar_design()}}
        origin, forward, _, up, _ = pelvis_frame(spec)
        matrix, _, basis, scale = camera(spec, 'front')
        right = basis[0] @ matrix[:3, :3]
        width, length = FIXTURE['attachment_flap_size_m']
        meshes = {}
        for name, sign in (('leather_apron', 1), ('rear_leather_apron', -1)):
            anchor = origin + sign * forward * FIXTURE['belt']['forward_radius_m']
            meshes[name] = {'vertices': [(anchor + right * x - up * y).tolist()
                                         for x, y in ((-width / 2, 0), (width / 2, 0),
                                                      (width / 2, length), (-width / 2, length))],
                            'faces': [[0, 1, 2, 3]]}
            for view in ('front', 'rear'):
                points = project(spec, [origin, anchor], view, GATES['native_size'])
                self.assertGreater(abs(points[1, 0] - points[0, 0]), GATES['flap_centre_error_px_max'])
        centred = measure(spec, meshes)
        self.assertTrue(centred['passed'])
        for view in ('front', 'rear'):
            for name in meshes:
                self.assertTrue(centred['views'][view][name]['passed'])
        shift = right * FIXTURE['attachment_shift_px'] * scale / GATES['native_size']
        meshes['leather_apron']['vertices'] = (np.array(meshes['leather_apron']['vertices']) + shift).tolist()
        shifted = measure(spec, meshes)
        self.assertFalse(shifted['passed'])
        for view in ('front', 'rear'):
            self.assertFalse(shifted['views'][view]['leather_apron']['passed'])
            self.assertTrue(shifted['views'][view]['rear_leather_apron']['passed'])

    def test_centreline_gate_is_inclusive_at_twelve_pixels_and_rejects_beyond(self):
        mask = np.zeros((32, 32), bool)
        y0, y1, x0, x1 = FIXTURE['centre_mask_box']
        mask[y0:y1, x0:x1] = True
        line = np.array(FIXTURE['centre_line'])
        self.assertTrue(projected_centre_error(mask, line)['passed'])
        self.assertTrue(projected_centre_error(mask, line + [12, 0])['passed'])
        self.assertFalse(projected_centre_error(mask, line + [12.01, 0])['passed'])
        with self.assertRaisesRegex(ValueError, 'empty'):
            projected_centre_error(np.zeros_like(mask), line)

    def test_native_triangle_projection_keeps_depth_for_fringe_occlusion(self):
        spec = base('hollow_mimic')
        matrix, target, basis, scale = camera(spec, 'front')
        layers = []
        for depth in FIXTURE['depth_layers']:
            vertices = []
            for x, y in FIXTURE['depth_rect_px']:
                world = target + basis[0] * (x / GATES['native_size'] - .5) * scale
                world += basis[1] * (.5 - y / GATES['native_size']) * scale + basis[2] * depth
                vertices.append(np.linalg.solve(matrix[:3, :3], world - matrix[:3, 3]).tolist())
            layers.append(depth_image(spec, {'vertices': vertices, 'faces': [[0, 1, 2, 3]]}, 'front'))
        overlap = np.isfinite(layers[0]) & np.isfinite(layers[1])
        self.assertGreater(int(overlap.sum()), 0)
        self.assertTrue(np.all(layers[1][overlap] > layers[0][overlap]))

    def test_fringe_gate_rejects_hair_behind_the_mask(self):
        spec = base('hollow_mimic')
        spec['mq11'] = {'design': {'skull': deepcopy(FIXTURE['skull'])}}
        matrix, target, basis, scale = camera(spec, 'front')
        meshes = {}
        for name, depth in zip(('cracked_mask', 'hair_crown'), FIXTURE['depth_layers']):
            vertices = []
            for x, y in FIXTURE['depth_rect_px']:
                world = target + basis[0] * (x / GATES['native_size'] - .5) * scale
                world += basis[1] * (.5 - y / GATES['native_size']) * scale + basis[2] * depth
                vertices.append(np.linalg.solve(matrix[:3, :3], world - matrix[:3, 3]).tolist())
            meshes[name] = {'vertices': vertices, 'faces': [[0, 1, 2, 3]]}
        self.assertTrue(measure(spec, meshes)['checks']['fringe_over_mask_top'])
        meshes['hair_crown']['vertices'] = (np.array(meshes['hair_crown']['vertices']) - 2 * FIXTURE['depth_layers'][1] *
                                           (basis[2] @ matrix[:3, :3])).tolist()
        self.assertFalse(measure(spec, meshes)['checks']['fringe_over_mask_top'])

    def test_sheet_keeps_native_cells_marks_joints_and_hashes_inputs(self):
        with tempfile.TemporaryDirectory(prefix='mq11-proof-', dir=PROJECT) as temporary:
            root = Path(temporary)
            old, capture, output = root / 'slag_mortar/delivery', root / 'capture', root / 'review'
            old.mkdir(parents=True)
            capture.mkdir()
            joints = {v: {'pelvis': FIXTURE['test_joint_px']} for v in ('front', 'rear')}
            for path in (old, capture):
                (path / 'joints_px.json').write_text(json.dumps(joints))
                for view in ('front', 'rear'):
                    Image.new('RGBA', (1024, 1024)).save(path / (view + '_clay.png'))
                    Image.new('RGBA', (1024, 1024)).save(path / (view + '_parts.png'))
            with patch.object(proof, 'ROOT', root):
                proof.sheet(base('slag_mortar'), capture, output)
            contract = json.loads((output / 'proof_contract.json').read_text())
            self.assertEqual(contract['cell_scale'], 1)
            self.assertTrue(contract['joints_marked_every_cell'])
            for view in ('front', 'rear'):
                with Image.open(output / (view + '_old_new_parts.png')) as image:
                    self.assertEqual(image.size, (3072, 1052))
                    for column in range(3):
                        self.assertGreater(image.getpixel((column * 1024 + 509, 512 + 28))[3], 0)
            self.assertEqual(len(contract['outputs_sha256']), 2)


if __name__ == '__main__':
    unittest.main()
