"""Real Bone2D direction evidence and mutations, without a window server."""
import copy
import hashlib
import json
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

PROJECT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(PROJECT / 'tools'))
from cutout_pipeline.cases import read_json
from humanoid_cutout.action_direction import report
from humanoid_cutout.gates import bindings

SCRATCH = Path('/private/tmp/labyrinth_codex/rr-15')
PROOF_TASK_ID = 'rr-15'
PROOF_TIMEOUT_SECONDS = 180
CASES = {'thrall': PROJECT / 'experiments/cutouts/arc_thrall/rr11',
         'seer': PROJECT / 'experiments/cutouts/hoarfrost_seer/rr10'}


class ActionDirectionTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        SCRATCH.mkdir(parents=True, exist_ok=True)
        cls.folder = tempfile.TemporaryDirectory(prefix='direction-tests-', dir=SCRATCH)
        cls.addClassCleanup(cls.folder.cleanup)
        cls.samples, cls.data, cls.layouts, cls.inputs = {}, {}, {}, {}
        for name, case in CASES.items():
            target = Path(cls.folder.name) / (name + '.json')
            command = [sys.executable, 'tools/godot_task_runner.py', '--task-id', PROOF_TASK_ID,
                '--stream', '--', 'godot', '--headless', '--path', '.', '--script',
                'tests/rr11/action_direction.gd', '--', '--case', str(case), '--output', str(target)]
            result = subprocess.run(command, cwd=PROJECT, capture_output=True, text=True,
                                    timeout=PROOF_TIMEOUT_SECONDS)
            if result.returncode:
                raise AssertionError(result.stdout + result.stderr)
            cls.samples[name] = read_json(target)
            cls.data[name] = read_json(case / 'compiled_motion.json')
            cls.layouts[name] = {v: read_json(case / f'layouts/{v}.json') for v in ('front', 'rear')}
            cls.inputs[name] = bindings(case)

    def check_direction(self, name, view, samples=None):
        return report(self.layouts[name][view], self.data[name],
                      self.samples[name] if samples is None else samples,
                      self.inputs[name], require_presented=True)

    def test_all_action_clips_in_both_views_and_seer_rear_staff_actions(self):
        for name in CASES:
            for view in ('front', 'rear'):
                with self.subTest(creature=name, view=view):
                    result = self.check_direction(name, view)
                    self.assertEqual(result['errors'], [])
                    positive = [r for r in result['rows'] if r['forward_px'] > 0]
                    self.assertTrue(positive)
                    expected = {clip for clip, tracks in self.data[name]['view_tracks'][view].items()
                        if any(t['channel'] == 'forward_px' and
                               (t['bone'].startswith('hand_') or t['bone'] == 'tube_tip') and
                               any(k['value'] > 0 for k in t['keys']) for t in tracks)}
                    self.assertEqual({r['clip'] for r in positive}, expected)
                    self.assertTrue(all(r['forward_channel_dot'] > 0 for r in positive))
        rear = self.check_direction('seer', 'rear')['rows']
        for clip in ('mark', 'bolt', 'ward'):
            rows = [r for r in rear if r['clip'] == clip and r['target'] == 'hand_far' and r['forward_px'] > 0]
            self.assertTrue(rows)
            self.assertTrue(all(r['solved_forward_from_rest'] > 0 for r in rows))

    def test_reverse_tube_target_mutation_fails_in_both_views(self):
        for view in ('front', 'rear'):
            mutant = copy.deepcopy(self.samples['thrall'])
            row = next(r for r in mutant['samples'] if r['view'] == view and r['clip'] == 'tether'
                       and r['kind'] == 'authored' and r['phase'] == .35)
            evidence = next(r for r in self.check_direction('thrall', view)['rows']
                            if r['clip'] == 'tether' and r['kind'] == 'authored' and r['phase'] == .35
                            and r['target'] == 'tube_tip')
            for field in ('bones', 'direction_bones'):
                point = row[field]['tube_tip']['global']
                for index, axis in enumerate(evidence['forward']):
                    point[4 + index] -= 2 * evidence['forward_channel_dot'] * axis
            result = self.check_direction('thrall', view, mutant)
            self.assertTrue(any('forward direction reversed' in e for e in result['errors']))

    def test_missing_frame_or_continuous_evidence_fails_closed(self):
        mutant = copy.deepcopy(self.samples['thrall'])
        row = next(r for r in mutant['samples'] if r['view'] == 'rear' and r['clip'] == 'tether'
                   and r['kind'] == 'presented')
        del row['direction_bones']
        self.assertTrue(any('missing continuous direction evidence' in e
                            for e in self.check_direction('thrall', 'rear', mutant)['errors']))
        mutant['samples'].remove(row)
        self.assertTrue(any('incomplete presented inventory' in e
                            for e in self.check_direction('thrall', 'rear', mutant)['errors']))

    def test_front_render_inputs_and_all_front_pose_rows_are_byte_identical(self):
        before = read_json(PROJECT / 'tests/rr11/rr15/feedback1_front_before.json')
        rows = [{k: v for k, v in row.items() if not k.startswith('direction_')}
                for row in self.samples['thrall']['samples'] if row['view'] == 'front']
        actual = hashlib.sha256(json.dumps(rows, sort_keys=True, separators=(',', ':')).encode()).hexdigest()
        self.assertEqual(len(rows), before['front_pose_rows'])
        self.assertEqual(actual, before['front_pose_sha256'])
        for path, expected in before['protected_files'].items():
            self.assertEqual(hashlib.sha256((PROJECT / path).read_bytes()).hexdigest(), expected, path)


if __name__ == '__main__':
    unittest.main()
