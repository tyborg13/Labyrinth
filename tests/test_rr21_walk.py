"""Weaver walk repairs, full-evidence binding and strict negative controls."""
import copy
import json
from pathlib import Path
import sys
import tempfile
import unittest
import numpy as np

ROOT = Path(__file__).resolve().parents[1]
sys.path[:0] = [str(ROOT / 'tools'), str(ROOT / 'experiments/cutouts/briar_weaver')]
from rr21_case import CASE, ASSETS
from rr21_seams import state
from cutout_pipeline.cases import read_json, write_json, digest
from humanoid_cutout.bone_evidence import load_samples
from humanoid_cutout.cpu_pose import CpuPose
from humanoid_cutout.gait_continuations import errors, texture
from humanoid_cutout.gates import clean_metrics
from humanoid_cutout.walk_gates import report as walk_report

FIXTURE_SLIDE_PX = 1
COMPACT_RECORD_LIMIT_BYTES = 100_000  # Proof storage regression budget.
REPAIR_FRAMES = {'front': 5, 'rear': 2}


class WalkTests(unittest.TestCase):
    def test_compact_evidence_loads_legacy_and_hash_bound_full_rows(self):
        with tempfile.TemporaryDirectory(prefix='rr21-evidence-') as folder:
            case = Path(folder) / 'case'
            legacy = {'samples': [{'fixture': True}], 'ok': True}
            write_json(case / 'proof/samples.json', legacy)
            self.assertEqual(load_samples(case), legacy)
            full = case / 'proof/logs/samples.json'
            write_json(full, legacy)
            reference = {'file': 'logs/samples.json', 'sha256': digest(full)}
            write_json(case / 'proof/samples.json', {'full_samples': reference})
            self.assertEqual(load_samples(case), legacy)
            write_json(full, dict(legacy, ok=False))
            with self.assertRaisesRegex(ValueError, 'changed full sample'):
                load_samples(case)
            outside = Path(folder) / 'outside.json'
            write_json(outside, legacy)
            link = case / 'proof/logs/outside_link.json'
            link.symlink_to(outside)
            for target in ('../../outside.json', 'logs/outside_link.json'):
                with self.subTest(target=target):
                    reference = {'file': target, 'sha256': digest(outside)}
                    write_json(case / 'proof/samples.json', {'full_samples': reference})
                    with self.assertRaisesRegex(ValueError, 'changed full sample'):
                        load_samples(case)

    def test_committed_reports_contain_no_full_frame_arrays(self):
        for name in ('samples', 'gates', 'native_gates'):
            path = CASE / f'proof/{name}.json'
            self.assertLess(path.stat().st_size, COMPACT_RECORD_LIMIT_BYTES)
            record = read_json(path)
            self.assertNotIn('samples', record)
            for view in record.get('views', {}).values():
                self.assertNotIn('rows', view['direction'])
                for key in ('walk', 'supports'):
                    for field in ('frames', 'stance', 'rigid_air', 'jab'):
                        self.assertNotIn(field, view[key])
        self.assertTrue(load_samples(CASE)['samples'])

    def test_gait_copies_are_same_piece_edge_texels_and_other_clips_keep_their_paint(self):
        for view in ('front', 'rear'):
            for root, path in ((CASE, f'layouts/{view}.json'), (ASSETS / 'humanoid_v2', view + '.json')):
                layout = read_json(root / path)
                # Production texels are copied from their already treated
                # donor. Canonical donor coordinates are certified on source.
                if root == CASE: self.assertEqual(errors(root, layout), [])
                for name, recipe in layout['gait_continuations'].items():
                    part = next(p for p in layout['parts'] if p['name'] == name)
                    donor = next(p for p in layout['parts'] if p['name'] == recipe['donor'])
                    self.assertEqual(part['logical_part'], donor['logical_part'])
                    original = texture(root, layout, part)
                    gait = texture(root, layout, part, gait=True)
                    x, y = np.array(recipe['texels'])[:, :2].T
                    self.assertTrue((original[y, x, 3] == 0).all())
                    self.assertTrue((gait[y, x, 3] == 255).all())
                    unchanged = np.ones(original.shape[:2], dtype=bool)
                    unchanged[y, x] = False
                    np.testing.assert_array_equal(original[unchanged], gait[unchanged])

    def test_removing_coverage_reopens_real_sampled_gaps(self):
        samples = load_samples(CASE)
        for view, frame in REPAIR_FRAMES.items():
            layout = read_json(CASE / f'layouts/{view}.json')
            pose = next(r for r in samples['samples'] if r['view'] == view and r['clip'] == 'move'
                        and r['kind'] == 'presented' and r['frame'] == frame)
            repaired = state(CpuPose(CASE, copy.deepcopy(layout)), pose)
            self.assertEqual(repaired[3], [])
            self.assertEqual(clean_metrics(repaired[0])['stray_components'], 0)
            layout.pop('gait_continuations')
            unfilled = state(CpuPose(CASE, layout), pose)
            self.assertTrue(unfilled[3] or clean_metrics(unfilled[0])['stray_components'])

    def test_each_leg_rejects_a_one_pixel_stance_slide(self):
        samples = load_samples(CASE)
        data = read_json(CASE / 'compiled_motion.json')
        for view in ('front', 'rear'):
            layout = read_json(CASE / f'layouts/{view}.json')
            for side in ('near', 'far'):
                mutant = copy.deepcopy(samples)
                row = next(r for r in mutant['samples'] if r['view'] == view and r['clip'] == 'move'
                           and r['kind'] == 'presented' and .28 < r['phase'] < .32)
                row['bones']['foot_' + side]['global'][4] += FIXTURE_SLIDE_PX
                self.assertTrue(any('stance moved' in e or 'foot target error' in e
                                    for e in walk_report(layout, data, mutant)['errors']))


if __name__ == '__main__': unittest.main()
