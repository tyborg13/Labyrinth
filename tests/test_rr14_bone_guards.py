"""Negative IK evidence isolates direction and target from segment lengths."""
import copy
import json
import math
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

import numpy as np

PROJECT = Path(__file__).resolve().parents[1]
sys.path[:0] = [str(PROJECT / 'tools'), str(PROJECT / 'tests/rr14')]
from fixture import build
from humanoid_cutout.gates import bone_errors, bindings

SCRATCH = Path('/private/tmp/labyrinth_codex/rr-14/feedback1')
PROOF_TIMEOUT_SECONDS = 180
EPSILON = 0.0001


class BoneGuardTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        SCRATCH.mkdir(parents=True, exist_ok=True)
        cls.temporary = tempfile.TemporaryDirectory(prefix='bone-guards-', dir=SCRATCH)
        cls.addClassCleanup(cls.temporary.cleanup)
        case = Path(cls.temporary.name)
        cls.layout, _, _, cls.compiled = build(case)
        output = case / 'proof/samples.json'
        result = subprocess.run([sys.executable, 'tools/godot_task_runner.py', '--task-id', 'rr-14', '--stream', '--',
            'godot', '--headless', '--path', '.', '--script', 'tests/rr14/runtime_checks.gd', '--',
            '--case', str(case), '--report', str(output)], cwd=PROJECT, capture_output=True, text=True,
            timeout=PROOF_TIMEOUT_SECONDS)
        if result.returncode: raise AssertionError(result.stdout + result.stderr)
        cls.samples = json.loads(output.read_text())
        cls.current = bindings(case)

    def sample(self):
        report = copy.deepcopy(self.samples)
        row = next(r for r in report['samples'] if r['view'] == 'front' and r['clip'] == 'move' and
                   r['kind'] == 'authored' and r['phase'] == 0)
        tag = '%s/%s/%s' % (row['view'], row['clip'], row['phase'])
        return report, row['bones'], tag

    def lengths(self, bones):
        a, b, c = [np.asarray(bones[name]['global'][4:]) for name in ('thigh_near', 'shin_near', 'foot_near')]
        np.testing.assert_allclose([np.linalg.norm(b-a), np.linalg.norm(c-b)], [5., 5.], atol=EPSILON, rtol=0)
        return a, b, c

    def test_reflected_knee_preserves_lengths_and_target_but_fails_specific_bend_error(self):
        report, bones, tag = self.sample()
        self.assertEqual(bone_errors(self.layout, self.compiled, report, self.current), [])
        a, b, c = self.lengths(bones)
        axis = (c-a) / np.linalg.norm(c-a)
        projection = a + axis * np.dot(b-a, axis)
        reflected = 2 * projection - b
        bones['shin_near']['global'][4:] = reflected.tolist()
        self.lengths(bones)
        self.assertEqual(bone_errors(self.layout, self.compiled, report, self.current),
                         [tag + ': IK changed rest bend side: foot_near'])

    def test_wrong_foot_target_preserves_lengths_and_bend_side_but_fails_specific_target_error(self):
        report, bones, tag = self.sample()
        a, _, c = self.lengths(bones)
        c = c + [0., -1.]
        distance = np.linalg.norm(c-a)
        axis = (c-a) / distance
        perpendicular = np.array([-axis[1], axis[0]])
        knee = a + axis * distance / 2 + perpendicular * math.sqrt(25. - distance**2 / 4)
        bones['shin_near']['global'][4:] = knee.tolist()
        bones['foot_near']['global'][4:] = c.tolist()
        a, b, c = self.lengths(bones)
        self.assertGreater((c-a)[0] * (b-a)[1] - (c-a)[1] * (b-a)[0], 0)
        self.assertEqual(bone_errors(self.layout, self.compiled, report, self.current),
                         [tag + ': signed foot target: foot_near'])


if __name__ == '__main__':
    unittest.main()
