"""Behavioral guards for the director's mq-11 review findings."""
from copy import deepcopy
import unittest
from unittest.mock import patch

import numpy as np

from spec.art_identity.maquettes.blender.accessory_geometry.forms import GEOMETRY_DEFAULTS
from spec.art_identity.maquettes.hollow_mimic.owner_review import measurements
from spec.art_identity.maquettes.hollow_mimic.owner_review import candidate
from spec.art_identity.maquettes.hollow_mimic.owner_review.candidate import (
    GATES, compile_candidate, compile_document)
from tests.test_mq11_accessories import FIXTURE, base, document, hair_design, mortar_design

VALIDATION_FIXTURE = {'detachment_distance_m': 10., 'mask_size': 100, 'passing_rear_ratio': .4,
                      'rounding_fraction': .5, 'outside_epsilon_factor': 2.,
                      'flap_width_px': 8, 'flap_rows': 20, 'gap_row': 10,
                      'extreme_error_px': 100}


def measured_mask(hair, rear_ratio=None):
    """Isolate depth visibility and numerical thresholds from triangle sampling."""
    size = VALIDATION_FIXTURE['mask_size']
    mask = np.zeros((size, size))
    ratio = VALIDATION_FIXTURE['passing_rear_ratio'] if rear_ratio is None else rear_ratio
    spec = {'id': 'hollow_mimic', 'mq11': {'design': {'skull': deepcopy(FIXTURE['skull'])}}}
    meshes = {name: {'vertices': [[0., 0, 0]]} for name in ('hair_crown', 'cracked_mask')}
    with (patch.object(measurements, 'depth_image', side_effect=[hair, mask]),
          patch.object(measurements, 'project', side_effect=[np.array([[0., -ratio, 0]]),
                                                          np.array([[0., 0, 0], [0., 1, 0]])])):
        return measurements.measure(spec, meshes)


def fringe_depth():
    size = VALIDATION_FIXTURE['mask_size']
    hair = np.full((size, size), -np.inf)
    hair[:int(size * GATES['fringe_mask_top_fraction'])] = 1.
    return hair


class GeometryReviewTests(unittest.TestCase):
    def test_detached_scalp_and_all_its_tufts_cannot_compile(self):
        design = deepcopy(compile_candidate('hollow_mimic')['mq11']['design'])
        shift = np.array(design['skull']['lateral_axis']) * VALIDATION_FIXTURE['detachment_distance_m']
        design['scalp']['centre_m'] = (np.array(design['scalp']['centre_m']) + shift).tolist()
        for tuft in design['tufts']:
            tuft['path_m'] = (np.array(tuft['path_m']) + shift).tolist()
        with self.assertRaisesRegex(ValueError, 'skull axis'):
            compile_document('hollow_mimic', document('hollow_mimic', design))

    def test_tuft_length_boundaries_allow_relative_roundoff_but_reject_outside_epsilon(self):
        epsilon = GEOMETRY_DEFAULTS['relative_epsilon']
        for bound, direction in zip(GATES['tuft_length_head_height'], (-1, 1)):
            for delta, accepted in ((0., True), (VALIDATION_FIXTURE['rounding_fraction'], True),
                                    (VALIDATION_FIXTURE['outside_epsilon_factor'], False)):
                design = hair_design()
                tuft = design['tufts'][0]
                root, tip = np.array(tuft['path_m'])
                length = bound * (1 + direction * epsilon * delta)
                tuft['path_m'][1] = (root + (tip - root) / np.linalg.norm(tip - root) * length).tolist()
                with self.subTest(bound=bound, delta=delta):
                    if accepted:
                        compile_document('hollow_mimic', document('hollow_mimic', design))
                    else:
                        with self.assertRaisesRegex(ValueError, 'head-height range'):
                            compile_document('hollow_mimic', document('hollow_mimic', design))

    def test_reversed_or_duplicate_internal_flap_rows_fail(self):
        for fractions in ((0., .8, .4, 1.), (0., .5, .5, 1.)):
            for side in ('front', 'rear'):
                design = mortar_design()
                design[side]['rows'] = [dict(deepcopy(FIXTURE['rows'][0]), drop_fraction=f) for f in fractions]
                with self.subTest(side=side, fractions=fractions), self.assertRaisesRegex(ValueError, 'monotonically'):
                    compile_document('slag_mortar', document('slag_mortar', design))

    def test_mutated_unowned_accessory_is_rejected_independently_of_body_fields(self):
        for figure in ('hollow_mimic', 'slag_mortar'):
            before = base(figure)
            after = compile_candidate(figure)
            changed = next(p for p in after['pieces'] if p['id'] == 'cracked_mask') if figure == 'hollow_mimic' else next(
                p for p in after['pieces'] if p['id'] not in ('leather_belt', 'leather_apron', 'rear_leather_apron'))
            changed['part'] = 'pelvis' if changed['part'] != 'pelvis' else 'head'
            with self.subTest(figure=figure), self.assertRaisesRegex(ValueError, 'unowned accessory'):
                candidate.assert_preserved(before, after)


class MeasurementReviewTests(unittest.TestCase):
    def test_near_total_occlusion_rejects_the_old_one_visible_row_case(self):
        hair = fringe_depth()
        hair[:-1] = 1.
        report = measured_mask(hair)
        self.assertTrue(report['checks']['rear_height'])
        self.assertTrue(report['checks']['fringe_over_mask_top'])
        self.assertFalse(report['checks']['lower_mask_remains_visible'])
        self.assertFalse(report['passed'])

    def test_sixty_percent_of_lower_band_is_inclusive_and_less_fails(self):
        hair = fringe_depth()
        size = len(hair)
        top = int(size * GATES['fringe_mask_top_fraction'])
        visible = int((size - top) * measurements.VALIDATION_LIMITS['lower_mask_visible_fraction_min'])
        hair[top + visible:] = 1.
        report = measured_mask(hair)
        self.assertEqual(report['visible_lower_mask_fraction'], .6)
        self.assertTrue(report['passed'])
        hair[top + visible - 1] = 1.
        report = measured_mask(hair)
        self.assertTrue(report['checks']['crack_band_remains_visible'])
        self.assertFalse(report['checks']['lower_mask_remains_visible'])

    def test_crack_centre_must_remain_visible_on_every_middle_third_row(self):
        hair = fringe_depth()
        size = len(hair)
        hair[size // 2, size // 2] = 1.
        report = measured_mask(hair)
        self.assertGreater(report['visible_lower_mask_fraction'], .6)
        self.assertTrue(report['checks']['lower_mask_remains_visible'])
        self.assertFalse(report['checks']['crack_band_remains_visible'])
        self.assertFalse(report['passed'])

    def test_rear_height_boundary_allows_relative_roundoff_but_rejects_outside_epsilon(self):
        maximum = GATES['rear_height_head_height_max']
        epsilon = measurements.MEASURE_DEFAULTS['epsilon']
        for ratio, accepted in ((maximum, True), (np.nextafter(maximum, np.inf), True),
                                (maximum * (1 + epsilon * VALIDATION_FIXTURE['rounding_fraction']), True),
                                (maximum * (1 + epsilon * VALIDATION_FIXTURE['outside_epsilon_factor']), False)):
            with self.subTest(ratio=ratio):
                report = measured_mask(fringe_depth(), ratio)
                self.assertEqual(report['checks']['rear_height'], accepted)
                self.assertEqual(report['passed'], accepted)

    def test_flaps_need_twelve_contiguous_central_rows(self):
        width, rows = VALIDATION_FIXTURE['flap_width_px'], VALIDATION_FIXTURE['flap_rows']
        mask = np.ones((rows, width), bool)
        line = np.array([[width / 2, 0], [width / 2, rows]])
        report = measurements.projected_centre_error(mask, line)
        self.assertEqual(report['central_rows'][1] - report['central_rows'][0] + 1, 12)
        self.assertTrue(report['passed'])
        for bad in (mask[:-3], np.vstack((mask[:VALIDATION_FIXTURE['gap_row']], np.zeros((1, width), bool),
                                         mask[VALIDATION_FIXTURE['gap_row']:]))):
            with self.subTest(shape=bad.shape), self.assertRaisesRegex(ValueError, 'insufficient flap rows'):
                measurements.projected_centre_error(bad, line)

    def test_two_extreme_rows_cannot_cancel_into_a_passing_median(self):
        extreme = VALIDATION_FIXTURE['extreme_error_px']
        mask = np.zeros((2, 2 * extreme + 1), bool)
        mask[0, 0], mask[1, -1] = True, True
        line = np.array([[extreme + .5, 0], [extreme + .5, 2]])
        with self.assertRaisesRegex(ValueError, 'insufficient flap rows'):
            measurements.projected_centre_error(mask, line)


if __name__ == '__main__':
    unittest.main()
