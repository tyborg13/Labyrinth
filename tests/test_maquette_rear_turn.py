"""Inspect delivered pixels: a rear turn exchanges camera-near body sides.

Labels remain anatomical (named from the front). Determine camera proximity
from the foot solos, independently of those names and the facing certificate.
Use genuine flat label colours over the unoccluded torso to test depth order.
"""
import json
from pathlib import Path
import tempfile
import unittest

import numpy as np
from PIL import Image

from spec.art_identity.maquettes.blender.floor_contact import (
    along_front_ray, harmonic_heights, contact_guard, projection_error, require_leg_bones)
from spec.art_identity.maquettes.blender.front_gate import compare as compare_front
from spec.art_identity.maquettes.blender.capture_frame import minimum_pan, target_for_pan
from spec.art_identity.maquettes.raster import project
from spec.art_identity.maquettes.blender.ray_search import first_clear


MAQUETTES = Path(__file__).resolve().parents[1] / 'spec/art_identity/maquettes'
REQUIRED_FIGURES = {'hoarfrost_seer', 'frostglass_lancer', 'arc_thrall',
                    'gale_herald', 'gloam_stalker'}
PROOF_DEFAULTS = {'alpha_threshold': 128, 'srgb_channel_tolerance': 1,
                  'registration_joint_tolerance_px': .02}
GATE_FIXTURE = {'size': 8, 'start': 2, 'stop': 6, 'before_rgb': 10, 'after_rgb': 200}


def rgba(path):
    with Image.open(path) as image:
        return np.array(image.convert('RGBA')).astype(int)


def mask(path):
    return rgba(path)[..., 3] >= PROOF_DEFAULTS['alpha_threshold']


def deliveries():
    # Includes the committed Lancer proof_r2 capture: its complete matching
    # solos remain available; the curated r3 clay reference has no solo maps.
    # Newly delivered figures are picked up without editing a fixed roster.
    current = [path.parent for path in MAQUETTES.glob('*/delivery/front_clay.png')
               if (path.parent / 'rear_clay.png').is_file()]
    complete_archives = [path.parent for path in MAQUETTES.glob('*/proof_*/front_parts.png')
                         if (path.parent / 'rear_parts.png').is_file()]
    return sorted(set(current + complete_archives))


def labels_for(folder):
    figure = folder.relative_to(MAQUETTES).parts[0]
    recipe = MAQUETTES / figure / 'measurements.json'
    if not recipe.exists():
        recipe = MAQUETTES / figure / ('spec_' + folder.name.removeprefix('proof_') + '.json')
    return json.loads(recipe.read_text())['labels']


def observations(folder, front_folder=None):
    labels = labels_for(folder)
    result = {}
    for view in ('front', 'rear'):
        source = front_folder if view == 'front' and front_folder is not None else folder
        feet = {}
        for side in ('near', 'far'):
            pixels = np.argwhere(mask(source / f'{view}_solo_foot_{side}.png'))
            if not len(pixels):
                raise ValueError(f'{folder.name}/{view}: empty foot_{side} solo')
            feet[side] = pixels.mean(axis=0)[::-1].tolist()
        lower, higher = sorted(feet, key=lambda side: feet[side][1], reverse=True)
        parts = rgba(source / f'{view}_parts.png')
        torso = mask(source / f'{view}_solo_torso.png')
        coverage = dict(near=0, far=0)
        for name, linear in labels.items():
            side = name.rsplit('_', 1)[-1]
            if side not in coverage:
                continue
            linear = np.asarray(linear)
            colour = np.rint(np.where(linear <= .0031308, linear * 12.92,
                                      1.055 * linear ** (1 / 2.4) - .055) * 255)
            genuine = ((abs(parts[..., :3] - colour).max(axis=-1) <=
                        PROOF_DEFAULTS['srgb_channel_tolerance']) &
                       (parts[..., 3] >= PROOF_DEFAULTS['alpha_threshold']))
            coverage[side] += int((genuine & torso).sum())
        result[view] = {'feet': feet, 'lower_foot': lower,
                        'lower_foot_right': feet[lower][0] > feet[higher][0],
                        'body_side_pixels_over_torso': coverage}
    return result


class RearTurnTests(unittest.TestCase):
    def test_view_sources_project_actual_staged_joints_without_changing_front(self):
        from spec.art_identity.maquettes.blender.compile_recipe import compile_recipe
        from spec.art_identity.maquettes.blender.view_delivery import spec_for_view
        figure = MAQUETTES / 'hoarfrost_seer'
        base = compile_recipe(json.loads((figure / 'measurements.json').read_text()))
        joints = json.loads((figure / 'delivery/joints_px.json').read_text())
        self.assertEqual(spec_for_view(base, figure / 'delivery', 'front'), base)
        for view in ('front', 'rear'):
            spec = spec_for_view(base, figure / 'delivery', view)
            for name, point in spec['joints'].items():
                error = np.linalg.norm(project(spec, point, view)[:2] - joints[view][name])
                self.assertLessEqual(error, PROOF_DEFAULTS['registration_joint_tolerance_px'], (view, name, error))

    def test_staged_rear_turn_and_native_floor_contacts(self):
        figure = MAQUETTES / 'hoarfrost_seer'
        proof = figure / 'rear_turn/feedback4'
        result = observations(figure / 'delivery')
        for view in ('front', 'rear'):
            self.assertTrue(result[view]['lower_foot_right'], result[view])
        front = result['front']['body_side_pixels_over_torso']
        rear = result['rear']['body_side_pixels_over_torso']
        self.assertGreater(front['near'], front['far'])
        self.assertGreater(rear['far'], rear['near'])
        build = json.loads((figure / 'delivery/rear_native/build_report.json').read_text())
        self.assertTrue(build['passed'])
        floor = build['geometry_details']['floor_contact']
        self.assertTrue(floor['passed'])
        self.assertTrue(floor['hem_on_or_above_floor'])
        self.assertEqual(floor['excepted_offenders'], [])
        for row in build['cloth'].values():
            self.assertEqual(row['samples_below_margin'], 0)
            self.assertEqual(row['intersecting_face_pairs'], 0)
        self.assertEqual(floor['pose']['corrective_shapes'], ['CC0_original', 'source_outline_fit'])
        proof = json.loads((figure / 'delivery/rear_native/recipe_proof.json').read_text())
        self.assertTrue(proof['passed'])
        self.assertEqual(set(proof['combined_mesh_hashes'].values()), {build['combined_mesh_hash']})

    def test_per_view_native_proofs_reject_stale_or_failed_reports(self):
        from shutil import copyfile
        from spec.art_identity.maquettes.blender.curate_delivery import stage
        from spec.art_identity.maquettes.blender.compile_recipe import compile_recipe
        from spec.art_identity.maquettes.blender.delivery_validation import validate_delivery
        figure = MAQUETTES / 'hoarfrost_seer'
        with tempfile.TemporaryDirectory() as directory:
            destination = Path(directory)
            copyfile(figure / 'measurements.json', destination / 'measurements.json')
            stage(destination, figure / 'delivery')
            delivery = destination / 'delivery'
            spec = compile_recipe(json.loads((destination / 'measurements.json').read_text()))
            cases = [
                ('build_report.json', lambda d: d.update(geometry_scope=['rear'])),
                ('rear_native/build_report.json', lambda d: d['checks'].update(cloth_collision_margin=False)),
                ('rear_native/build_report.json', lambda d: d['cloth']['robe_skirt'].update(intersecting_face_pairs=1)),
                ('rear_native/recipe_proof.json', lambda d: d.pop('delivery_binding')),
                ('rear_native/exact_native_replay.json', lambda d: d.update(passed=False)),
                ('capture_frame.json', lambda d: d['rear'].update(camera_rotation_unchanged=False)),
                ('rear_proportion_report.json', lambda d: d.update(iou=.59)),
                ('rear_proportion_report.json', lambda d: d.pop('dynamic_iou')),
                ('rear_proportion_report.json', lambda d: d.update(fixed_original_iou=.70)),
                ('rear_proportion_report.json', lambda d: d['per_part_coverage']['head'].update(pure_owner_pixels=1)),
                ('view_sources.json', lambda d: d['overrides']['rear'].update(recipe='../outside.json')),
            ]
            for name, mutate in cases:
                with self.subTest(file=name):
                    path = delivery / name
                    before = path.read_bytes()
                    data = json.loads(before)
                    mutate(data)
                    path.write_text(json.dumps(data))
                    try:
                        with self.assertRaises(ValueError):
                            validate_delivery(spec, delivery, require_binding=False)
                    finally:
                        path.write_bytes(before)
            for name in ('view_sources.json', 'front_proportion_report.json'):
                path = delivery / name
                before = path.read_bytes()
                path.unlink()
                try:
                    with self.assertRaises(ValueError):
                        validate_delivery(spec, delivery, require_binding=False)
                finally:
                    path.write_bytes(before)
            validate_delivery(spec, delivery)

    def test_rear_only_pose_keeps_frozen_front_and_uses_real_leg_bones(self):
        from spec.art_identity.maquettes.blender.compile_recipe import compile_recipe
        from spec.art_identity.maquettes.blender.curate_delivery import sha
        figure = MAQUETTES / 'hoarfrost_seer'
        proof = figure / 'rear_turn/feedback4'
        frozen = json.loads((proof / 'front_freeze.json').read_text())
        self.assertEqual({p.name: sha(p) for p in (figure / 'delivery').glob('front_*')}, frozen['files'])
        self.assertEqual(json.loads((figure / 'delivery/joints_px.json').read_text())['front'], frozen['joints'])
        original = json.loads((figure / 'measurements.json').read_text())
        recipe = json.loads((proof / 'rear_recipe.json').read_text())
        self.assertEqual({key: recipe[key] for key in original}, original)
        self.assertNotIn('floor_contact_correction', recipe)
        spec = compile_recipe(recipe)
        config = spec['rear_body']
        self.assertEqual(config['exceptions'], [])
        self.assertEqual(require_leg_bones(spec, config), {'hip_far', 'knee_far', 'ankle_far'})
        self.assertAlmostEqual(spec['joints']['ankle_far'][2], spec['joints']['ankle_near'][2])
        expected = along_front_ray(spec, [config['fitted_joints']['ankle_far']],
            [spec['joints']['ankle_near'][2] - config['fitted_joints']['ankle_far'][2]])[0]
        np.testing.assert_allclose(spec['joints']['ankle_far'], expected)

    def test_packed_delivery_reseals_without_changing_visible_pixels(self):
        from shutil import copyfile
        from spec.art_identity.maquettes.blender.curate_delivery import stage
        from spec.art_identity.maquettes.blender.delivery_validation import validate_delivery
        from spec.art_identity.maquettes.blender.compile_recipe import compile_recipe
        figure = MAQUETTES / 'hoarfrost_seer'
        with tempfile.TemporaryDirectory() as directory:
            destination = Path(directory)
            copyfile(figure / 'measurements.json', destination / 'measurements.json')
            stage(destination, figure / 'delivery', pack_pngs=True)
            spec = compile_recipe(json.loads((destination / 'measurements.json').read_text()))
            validate_delivery(spec, destination / 'delivery')
            for source in (figure / 'delivery').glob('*.png'):
                packed = destination / 'delivery' / source.name
                if not packed.exists():
                    continue
                before, after = rgba(source), rgba(packed)
                np.testing.assert_equal(before[..., 3], after[..., 3])
                np.testing.assert_equal(before[before[..., 3] > 0], after[before[..., 3] > 0])
                if source.name.endswith('_clay.png'):
                    np.testing.assert_equal(before, after)

    def test_minimum_ray_exit_uses_both_sides_and_reports_no_clear_interval(self):
        fixture = {'centre': .001, 'radius': .005, 'margin': .003, 'bound': 1.}
        def distance(length):
            return abs(length - fixture['centre']) - fixture['radius']
        plus = first_clear(distance, fixture['margin'], fixture['bound'])
        minus = first_clear(lambda length: distance(-length), fixture['margin'], fixture['bound'])
        self.assertAlmostEqual(plus, .009, places=7)
        self.assertAlmostEqual(minus, .007, places=7)
        self.assertLess(minus, plus)
        self.assertIsNone(first_clear(lambda length: -.005, fixture['margin'], fixture['bound']))

    def test_rear_pan_preserves_scale_direction_and_margin(self):
        fixture = {'bounds': [[200, 190], [850, 1170]], 'size': 1024, 'margin': 8,
                   'spec': {'ortho_scale': 2.4, 'target': [0, 0, 1.12]}, 'point': [[0, 0, 0]]}
        pan = minimum_pan(fixture['bounds'], fixture['size'], fixture['margin'])
        np.testing.assert_equal(pan, [0, -155])
        moved = dict(fixture['spec'], target=target_for_pan(fixture['spec'], 'rear', pan, fixture['size']))
        before = project(fixture['spec'], fixture['point'], 'rear')
        after = project(moved, fixture['point'], 'rear')
        np.testing.assert_allclose(after[0, :2] - before[0, :2], pan, atol=1e-10)
        with self.assertRaisesRegex(ValueError, 'pan only'):
            minimum_pan([[0, 0], [1024, 1024]], fixture['size'], fixture['margin'])

    def test_floor_binding_requires_bone_names_not_region_labels(self):
        spec = {'armature': {'bones': [{'name': 'hip_far', 'region': 'skirt_far'},
                                       {'name': 'knee_far', 'region': 'skirt_far'},
                                       {'name': 'ankle_far', 'region': 'foot_far'}]}}
        self.assertEqual(require_leg_bones(spec, {'leg_bones': ['hip_far', 'knee_far', 'ankle_far']}),
                         {'hip_far', 'knee_far', 'ankle_far'})
        with self.assertRaisesRegex(ValueError, 'not region labels'):
            require_leg_bones(spec, {'leg_bones': ['thigh_far', 'shin_far', 'foot_far']})

    def test_documented_floor_exceptions_are_scoped_and_do_not_hide_heights(self):
        exception = {'point': 'ankle_far', 'reason': 'Deferred to the owning unit', 'authority': 'test fixture'}
        actual = contact_guard({'ankle_far': .18}, .02, [exception])
        self.assertTrue(actual['passed'])
        self.assertFalse(actual['points']['ankle_far']['within_floor_limit'])
        self.assertEqual(actual['excepted_offenders'], ['ankle_far'])
        for invalid in ([dict(exception, reason='')], [dict(exception, point='typo')], [exception, exception]):
            with self.assertRaises(ValueError):
                contact_guard({'ankle_far': .18}, .02, invalid)
        self.assertFalse(contact_guard({'ankle_far': .18}, .02, [])['passed'])

    def test_v2_union_gate_accepts_boundary_change_and_only_records_clay(self):
        fixture = GATE_FIXTURE
        contract = {'pieces': {'robe': ['skirt_near', 'skirt_far']}, 'whole_alpha_changed_pixels': 0,
                    'piece_displacement_px': 2, 'piece_changed_fraction': .005, 'joint_displacement_px': 1}
        with tempfile.TemporaryDirectory() as directory:
            folders = [Path(directory) / name for name in ('before', 'after')]
            for index, folder in enumerate(folders):
                folder.mkdir()
                pixels = np.zeros((fixture['size'], fixture['size'], 4), np.uint8)
                pixels[fixture['start']:fixture['stop'], fixture['start']:fixture['stop']] = 255
                Image.fromarray(pixels).save(folder / 'front_silhouette.png')
                Image.fromarray(pixels).save(folder / ('front_solo_skirt_near.png' if index else 'front_solo_skirt_far.png'))
                Image.fromarray(np.zeros_like(pixels)).save(folder / ('front_solo_skirt_far.png' if index else 'front_solo_skirt_near.png'))
                pixels[pixels[..., 3] > 0, :3] = fixture['after_rgb'] if index else fixture['before_rgb']
                Image.fromarray(pixels).save(folder / 'front_clay.png')
                (folder / 'joints_px.json').write_text(json.dumps({'front': {'root': [0, 0]}}))
            result = compare_front(*folders, contract)
            self.assertTrue(result['passed'])
            self.assertEqual(result['pieces']['robe']['changed_pixels'], 0)
            self.assertEqual(result['clay']['max_abs_channel_delta'], fixture['after_rgb'] - fixture['before_rgb'])
            changed = rgba(folders[1] / 'front_silhouette.png').astype(np.uint8)
            changed[fixture['start'], fixture['start'], 3] = 0
            Image.fromarray(changed).save(folders[1] / 'front_silhouette.png')
            self.assertFalse(compare_front(*folders, contract)['passed'])

    def test_floor_correction_preserves_projection_and_guard_detects_lift(self):
        spec = {'ortho_scale': 2.4, 'target': [0, 0, 1.12]}
        points = np.array([[0, 0, .02], [.1, -.2, .18], [0, 0, 1.]])
        corrected = along_front_ray(spec, points, [0, -.16, 0])
        self.assertLess(projection_error(spec, points, corrected), 1e-9)
        np.testing.assert_allclose(corrected[:, 2], [.02, .02, 1.])
        self.assertEqual(contact_guard({'ankle': .18, 'hem': .02}, .02)['offenders'], ['ankle'])
        self.assertTrue(contact_guard({'ankle': .02, 'hem': .02}, .02)['passed'])

    def test_hem_dependency_interpolation_obeys_fixed_boundary(self):
        points = np.array([[0, 0, 1], [1, 0, 1], [0, 0, .5], [1, 0, .5], [0, 0, 0], [1, 0, 0]])
        faces = [[0, 1, 3, 2], [2, 3, 5, 4]]
        change = harmonic_heights(points, faces, {0: 0, 1: 0, 4: -.2, 5: -.2})
        np.testing.assert_allclose(change, [0, 0, -.1, -.1, -.2, -.2], atol=1e-9)

    def test_all_committed_deliveries_turn_feet_and_depth_order(self):
        folders = deliveries()
        found = {folder.relative_to(MAQUETTES).parts[0] for folder in folders}
        self.assertTrue(REQUIRED_FIGURES <= found, REQUIRED_FIGURES - found)
        for folder in folders:
            name = str(folder.relative_to(MAQUETTES))
            with self.subTest(delivery=name):
                actual = observations(folder)
                print('MAQUETTE_REAR_TURN: ' + name + '; ' + json.dumps(actual, sort_keys=True))
                for view in ('front', 'rear'):
                    self.assertTrue(actual[view]['lower_foot_right'],
                                    f'{name}/{view}: lower foot must be screen-right; {actual[view]["feet"]}')
                    coverage = actual[view]['body_side_pixels_over_torso']
                    camera_near, camera_far = ('near', 'far') if view == 'front' else ('far', 'near')
                    self.assertGreater(coverage[camera_near], coverage[camera_far],
                                       f'{name}/{view}: body-side depth order did not turn: {coverage}')


if __name__ == '__main__':
    unittest.main()
