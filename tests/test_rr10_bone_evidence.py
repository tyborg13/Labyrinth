"""Complete sampler evidence and independent torso/head limit mutations."""
import copy
import json
import math
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

PROJECT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(PROJECT / 'tools'))
from humanoid_cutout.gates import bindings, bone_errors

CASE = PROJECT / 'experiments/cutouts/hoarfrost_seer/rr10'
PROOF_TASK_ID = os.environ.get('LABYRINTH_TASK_ID', 'rr-13')
PROOF_TIMEOUT_SECONDS = 180
FIXTURE_OVER_LIMIT_DEG = 1.


def read(path):
    return json.loads(path.read_bytes())


def rotate(transform, degrees):
    angle = math.radians(degrees)
    transform[:4] = [math.cos(angle), math.sin(angle), -math.sin(angle), math.cos(angle)]


class BoneEvidenceTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.layout = read(CASE / 'layouts/front.json')
        cls.data = read(CASE / 'compiled_motion.json')
        with tempfile.TemporaryDirectory(prefix='rr13-evidence-') as folder:
            output = Path(folder) / 'samples.json'
            process = subprocess.run([sys.executable, 'tools/godot_task_runner.py', '--task-id', PROOF_TASK_ID,
                '--stream', '--', 'godot', '--headless', '--path', '.', '--script', 'tests/rr10/samples.gd',
                '--', '--output', str(output)], cwd=PROJECT, capture_output=True, text=True,
                timeout=PROOF_TIMEOUT_SECONDS)
            if process.returncode:
                raise AssertionError(process.stdout + process.stderr)
            cls.report = read(output)
        cls.current = bindings(CASE)

    def errors(self, report):
        return bone_errors(self.layout, self.data, report, self.current)

    def test_valid_complete_evidence_passes_and_empty_evidence_fails(self):
        self.assertEqual(self.errors(self.report), [])
        report = copy.deepcopy(self.report)
        report['samples'] = []
        self.assertIn('bone evidence: empty sample inventory', self.errors(report))

    def test_failed_sampler_reported_errors_and_stale_hash_each_fail(self):
        for field, value, expected in [
            ('ok', False, 'sampler did not report ok=true'),
            ('errors', ['planted sampler failure'], 'sampler errors must be empty'),
            ('inputs', {**self.report['inputs'], 'layouts/front.json': 'stale'}, 'stale input bindings'),
            ('compiled_sha256', 'stale', 'stale compiled motion'),
        ]:
            report = copy.deepcopy(self.report)
            report[field] = value
            with self.subTest(field=field):
                self.assertIn('bone evidence: ' + expected, self.errors(report))

    def test_missing_or_duplicate_authored_and_presented_frames_in_either_view_fail(self):
        for view in ('front', 'rear'):
            for kind in ('authored', 'presented'):
                for mutation in ('missing', 'duplicate'):
                    report = copy.deepcopy(self.report)
                    index = next(i for i, row in enumerate(report['samples'])
                                 if row['view'] == view and row['clip'] == 'bolt' and row['kind'] == kind)
                    if mutation == 'missing':
                        report['samples'].pop(index)
                    else:
                        report['samples'].append(copy.deepcopy(report['samples'][index]))
                    with self.subTest(view=view, kind=kind, mutation=mutation):
                        self.assertIn('bone evidence: incomplete %s inventory: %s/bolt' % (kind, view),
                                      self.errors(report))

    def check_limit(self, bone, rule, normal_limit, death_limit):
        for clip, limit in (('hit', normal_limit), ('death', death_limit)):
            for sign in (-1, 1):
                for extra in (0., FIXTURE_OVER_LIMIT_DEG):
                    report = copy.deepcopy(self.report)
                    row = next(row for row in report['samples'] if row['view'] == 'front' and
                               row['clip'] == clip and row['kind'] == 'presented')
                    amount = sign * (limit + extra)
                    rotate(row['bones']['torso']['local'], amount if bone == 'torso' else 0.)
                    rotate(row['bones']['torso']['global'], amount if bone == 'torso' else 0.)
                    # Isolate the selected limit; head is relative to torso.
                    rotate(row['bones']['head']['global'], amount)
                    with self.subTest(bone=bone, clip=clip, sign=sign, extra=extra):
                        errors = self.errors(report)
                        if extra:
                            self.assertTrue(any(rule in error for error in errors), errors)
                        else:
                            self.assertEqual(errors, [])

    def test_torso_limits_pass_at_boundary_and_fail_above(self):
        self.check_limit('torso', 'torso lean limit', 4., 25.)

    def test_head_limits_pass_at_boundary_and_fail_above(self):
        self.check_limit('head', 'head nod limit', 6., 20.)


if __name__ == '__main__':
    unittest.main()
