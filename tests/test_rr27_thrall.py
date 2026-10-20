"""rr-27 own-piece joint copies, frozen poses, and study evidence integrity."""
from copy import deepcopy
from pathlib import Path
import sys
import tempfile
import unittest

import numpy as np

ROOT = Path(__file__).resolve().parents[1]
sys.path[:0] = [str(ROOT / 'tools'), str(ROOT / 'experiments/cutouts/arc_thrall')]
from rr27_build import CASE, RECIPE, ASSETS, apply_front
from rr27_check import preservation
from rr27_tether_sheets import CANDIDATES, PHASES, compose, axis_crosses
from cutout_pipeline.cases import read_json, write_json
from humanoid_cutout.cpu_pose import CpuPose
from humanoid_cutout.gait_continuations import active_recipe, errors as continuation_errors, texture
from humanoid_cutout.source_space import pocket_report
from rr24_seams import frame_report


class ThrallStrictProvenanceTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.layout = read_json(CASE / 'layouts/front.json')
        cls.samples = read_json(CASE / 'proof/samples.json')

    def test_joint_copies_use_own_treated_donors_and_only_the_two_clips(self):
        layout = self.layout
        self.assertEqual(continuation_errors(CASE, layout), [])
        recipe = layout['gait_continuations']['upper_near']
        self.assertEqual(recipe['donor'], 'upper_near')
        self.assertEqual(recipe['clips'], ['jab', 'death'])
        part = next(p for p in layout['parts'] if p['name'] == 'upper_near')
        original = texture(CASE, layout, part)
        for clip in ('rest', 'idle', 'move', 'tether', 'hit'):
            self.assertIsNone(active_recipe(layout, part['name'], clip=clip, gait=clip == 'move'))
            np.testing.assert_array_equal(texture(CASE, layout, part, clip=clip, gait=clip == 'move'), original)
        for clip in recipe['clips']:
            filled = texture(CASE, layout, part, clip=clip)
            for x, y, u, v in recipe['texels']:
                self.assertEqual(original[y, x, 3], 0)
                np.testing.assert_array_equal(filled[y, x], original[v, u])

    def test_removing_joint_copies_reopens_both_reported_tears(self):
        original = deepcopy(self.layout)
        del original['gait_continuations']['upper_near']
        for clip, frame, box in [('jab', 22, [282,248,283,250]), ('death', 31, [280,252,282,256])]:
            pose = next(p for p in self.samples['samples'] if p['kind'] == 'presented' and
                        (p['view'], p['clip'], p['frame']) == ('front', clip, frame))
            for layout, expected in ((original, True), (deepcopy(self.layout), False)):
                layers, _, _, _, independent = frame_report(CpuPose(CASE, layout), pose)
                failures = pocket_report(layers, independent['failures'])['failures']
                self.assertEqual(any(row['bbox'] == box for row in failures), expected)

    def test_replay_is_idempotent_and_production_recipes_match(self):
        self.assertEqual(apply_front(deepcopy(self.layout)), self.layout)
        for path in (ASSETS / 'front.json', ASSETS / 'humanoid_v2/front.json'):
            self.assertEqual(read_json(path)['gait_continuations'], self.layout['gait_continuations'])

    def test_raw_pose_rows_paint_rests_and_motion_are_exact(self):
        self.assertTrue(preservation(self.samples)['ok'])

    def test_study_has_exact_candidates_and_all_six_phases_without_data_edits(self):
        report = read_json(RECIPE / 'tether_study/cpu/samples.json')
        self.assertTrue(report['ok'])
        self.assertFalse(report['native_pixels'])
        self.assertEqual(report['candidates'], CANDIDATES)
        self.assertEqual(report['phases'], PHASES)
        self.assertEqual(len(report['samples']), len(CANDIDATES) * len(PHASES))
        manifest = read_json(RECIPE / 'tether_study/cpu/manifest.json')
        self.assertEqual(len(manifest['files']), 6)
        self.assertEqual(len([r for r in manifest['rows'] if r['phase'] == .5]), 5)
        self.assertEqual(manifest['zoom'], 3)

    def test_native_composer_rejects_cpu_evidence_and_stale_input(self):
        with self.assertRaisesRegex(ValueError, 'Fresh, complete study evidence'):
            compose(RECIPE / 'tether_study/cpu')
        with tempfile.TemporaryDirectory(prefix='rr27-study-') as folder:
            report = read_json(RECIPE / 'tether_study/cpu/samples.json')
            report['inputs'] = {}
            write_json(Path(folder) / 'samples.json', report)
            with self.assertRaisesRegex(ValueError, 'Fresh, complete study evidence'):
                compose(Path(folder), cpu=True)

    def test_axis_crossing_distinguishes_socket_contact_from_interior(self):
        mask = np.zeros((32, 32), dtype=bool)
        mask[8:24, 8:24] = True
        self.assertTrue(axis_crosses(mask, np.array([0,16]), np.array([31,16])))
        self.assertFalse(axis_crosses(mask, np.array([0,0]), np.array([31,0])))


if __name__ == '__main__':
    unittest.main(verbosity=2)
