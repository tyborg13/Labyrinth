"""Real Bone2D direction evidence and mutations, without a window server."""
import copy
import hashlib
import json
import os
from pathlib import Path
import shutil
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
PROOF_TASK_ID = os.environ.get('LABYRINTH_TASK_ID', 'rr-16')
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

    def test_painted_caps_are_optional_but_skeletal_evidence_is_required(self):
        samples = copy.deepcopy(self.samples['thrall'])
        for row in samples['samples']:
            row.pop('parts', None)
        for view in ('front', 'rear'):
            result = self.check_direction('thrall', view, samples)
            self.assertEqual(result['errors'], [])
            self.assertEqual(result['positive_checks'], self.check_direction('thrall', view)['positive_checks'])
            self.assertFalse(any('painted_cap' in row for row in result['rows']))
        row = next(r for r in samples['samples'] if r['view'] == 'front' and r['clip'] == 'jab')
        row.pop('bones')
        row.pop('direction_bones')
        self.assertTrue(any('missing skeletal direction evidence' in e
                            for e in self.check_direction('thrall', 'front', samples)['errors']))

    def test_zero_forward_channels_fail_required_clip_coverage_with_fresh_bones(self):
        for zero_clips in [('move', 'jab', 'tether', 'hit', 'death'), ('jab',)]:
            with self.subTest(zero_clips=zero_clips), tempfile.TemporaryDirectory(prefix='zero-direction-') as folder:
                case = Path(folder) / 'case'
                shutil.copytree(CASES['thrall'], case, ignore=shutil.ignore_patterns('proof'))
                data = copy.deepcopy(self.data['thrall'])
                for clips in data['view_tracks'].values():
                    for clip in zero_clips:
                        for track in clips[clip]:
                            if track['channel'] == 'forward_px' and track['bone'] in ('tube_tip', 'hand_far'):
                                for key in track['keys']:
                                    key['value'] = 0
                (case / 'compiled_motion.json').write_text(json.dumps(data))
                target = case / 'proof/samples.json'
                command = [sys.executable, 'tools/godot_task_runner.py', '--task-id', PROOF_TASK_ID,
                    '--stream', '--', 'godot', '--headless', '--path', '.', '--script',
                    'tests/rr11/action_direction.gd', '--', '--case', str(case), '--output', str(target)]
                process = subprocess.run(command, cwd=PROJECT, capture_output=True, text=True,
                                         timeout=PROOF_TIMEOUT_SECONDS)
                self.assertEqual(process.returncode, 0, process.stdout + process.stderr)
                samples, current = read_json(target), bindings(case)
                for view in ('front', 'rear'):
                    layout = read_json(case / f'layouts/{view}.json')
                    layout['motion_data'] = str(case / 'compiled_motion.json')
                    result = report(layout, data, samples, current, require_presented=True)
                    self.assertFalse(result['ok'])
                    self.assertIn(view + '/jab: no positive direction checks for required clip', result['errors'])
                    if 'tether' in zero_clips:
                        self.assertEqual(result['positive_checks'], 0)
                        self.assertIn(view + '/tether: no positive direction checks for required clip', result['errors'])
                    else:
                        self.assertGreater(result['positive_checks'], 0)

    def test_front_render_inputs_and_all_front_pose_rows_are_byte_identical(self):
        before = read_json(PROJECT / 'tests/rr11/rr15/feedback1_front_before.json')
        rows = [{k: v for k, v in row.items() if not k.startswith('direction_')}
                for row in self.samples['thrall']['samples'] if row['view'] == 'front']
        actual = hashlib.sha256(json.dumps(rows, sort_keys=True, separators=(',', ':')).encode()).hexdigest()
        self.assertEqual(len(rows), before['front_pose_rows'])
        self.assertEqual(actual, before['front_pose_sha256'])
        for path, expected in before['protected_files'].items():
            self.assertEqual(hashlib.sha256((PROJECT / path).read_bytes()).hexdigest(), expected, path)

    def test_all_fresh_thrall_and_seer_pose_rows_match_retained_renderer_inputs(self):
        for name, case in CASES.items():
            before = read_json(case / 'proof/samples.json')['samples']
            def renderer_rows(rows):
                return [{k: v for k, v in row.items() if not k.startswith('direction_')} for row in rows]
            self.assertEqual(renderer_rows(self.samples[name]['samples']), renderer_rows(before), name)
            print('RR16 %s POSE IDENTITY: PASS (%d exact rows)' % (name.upper(), len(before)))

    def test_thrall_case_declares_required_actions_independently_of_channels(self):
        self.assertEqual(read_json(CASES['thrall'] / 'cutout.json')['direction_clips'], ['jab', 'tether'])


if __name__ == '__main__':
    unittest.main()
