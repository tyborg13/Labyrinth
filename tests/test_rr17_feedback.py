"""Director feedback regressions against real production death/action callbacks."""
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
BASE = 'eafe1715d'
PROOF_TIMEOUT_SECONDS = 90
TYPES = ('hoarfrost_seer', 'arc_thrall', 'burrow_grub', 'ember_tick', 'bile_bloomer', 'lightning_wisp')


def godot(script, *args):
    return subprocess.run([sys.executable, 'tools/godot_task_runner.py', '--task-id',
        os.environ.get('LABYRINTH_TASK_ID', 'rr-17'), '--stream', '--', 'godot', '--headless',
        '--path', '.', '--script', script, '--', *map(str, args)], cwd=ROOT,
        capture_output=True, text=True, timeout=PROOF_TIMEOUT_SECONDS)


def changing_clock(rows, type):
    result = []
    previous = None
    for row in rows:
        unit = next((u for u in row['units'] if u['type'] == type), None)
        if unit is None: continue
        state = (unit['death_frame'], unit['death_progress'])
        if state != previous: result.append((row['usec'], *state))
        previous = state
    return result


class FeedbackTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.temp = tempfile.TemporaryDirectory(prefix='rr17-feedback-')
        cls.reports = {}
        for key, scene in [('current', 'res://tests/rr17/death_scene.gd'),
                           ('base', 'res://tests/rr17/fixtures/death_before_feedback.gd')]:
            output = Path(cls.temp.name) / (key + '.json')
            result = godot('tests/rr17/feedback_samples.gd', '--output', output, '--scene', scene)
            if result.returncode: raise AssertionError(result.stdout + result.stderr)
            cls.reports[key] = json.loads(output.read_text())

    @classmethod
    def tearDownClass(cls):
        cls.temp.cleanup()

    def test_baseline_method_matches_git_base_with_windows_empty_arrays(self):
        source = subprocess.check_output(['git', 'show', BASE + ':scripts/run_scene.gd'], cwd=ROOT, text=True)
        method = source[source.index('func _animate_defeats_and_terrain_destruction('):source.index('\nfunc _death_hold_presentation(')]
        for name in ('animated_units', 'animated_terrain'):
            method = method.replace('var ' + name + ': Array[Dictionary] = []', 'var ' + name + ': Array[Dictionary]')
        fixture = (ROOT / 'tests/rr17/fixtures/death_before_feedback.gd').read_text()
        self.assertEqual(fixture[fixture.index('func _animate_defeats_and_terrain_destruction('):].rstrip(), method.rstrip())

    def test_all_six_paired_deaths_retain_every_base_frame_and_last_frame_time(self):
        for type in TYPES:
            with self.subTest(type=type):
                expected = changing_clock(self.reports['base']['deaths'][type], type)
                actual = changing_clock(self.reports['current']['deaths']['capacitor+' + type], type)
                self.assertEqual(actual, expected)
                self.assertEqual(changing_clock(self.reports['current']['deaths'][type], type), expected)

    def test_legacy_multi_kill_presentation_is_byte_identical(self):
        def payload(key):
            return json.dumps(self.reports[key]['deaths']['legacy_multi'], sort_keys=True, separators=(',', ':')).encode()
        self.assertEqual(payload('current'), payload('base'))

    def test_fifo_burst_keeps_independent_clocks_and_legacy_output(self):
        current = self.reports['current']['deaths']
        base = self.reports['base']['deaths']
        self.assertEqual(current['legacy_burst'], base['legacy_burst'])
        self.assertEqual(changing_clock(current['capacitor_burst'], 'ember_tick'), changing_clock(base['ember_tick'], 'ember_tick'))
        clock = changing_clock(current['capacitor_burst'], 'storm_capacitor')
        ordinary = changing_clock(current['capacitor+ember_tick'], 'storm_capacitor')
        # The burst kills the Capacitor at the existing first FIFO boundary.
        delay_usec = round(.18 / 11 * 1_000_000)
        self.assertEqual(clock, [(time + delay_usec, frame, phase) for time, frame, phase in ordinary])

    def test_each_pair_runs_all_147_capacitor_frames_on_its_own_clock(self):
        previous = None
        for type in TYPES:
            clock = changing_clock(self.reports['current']['deaths']['capacitor+' + type], 'storm_capacitor')
            self.assertEqual([r[1] for r in clock], list(range(147)))
            self.assertEqual(clock[-1][0], 146 * round((1.4 + 28 * .037) / 147 * 1_000_000))
            if previous is not None: self.assertEqual(clock, previous)
            previous = clock

    def test_four_hop_cues_normal_reduced_and_skipped_recovery(self):
        chains = self.reports['current']['chains']
        for mode in ('normal', 'reduced', 'skip_recovery'):
            with self.subTest(mode=mode):
                row = chains[mode]
                self.assertEqual(row['hops'], 4)
                self.assertEqual(len(row['cues']), 4)
                self.assertEqual(row['cues'], chains['normal']['cues'])
                self.assertEqual(row['popups'], 4)
                self.assertTrue(row['state_matches'])

    def test_shadow_baseline_is_explicit_and_portable(self):
        baseline = Path(self.temp.name) / 'base_shadow.res'
        # HEAD, not the rr-17 branch base: later units legitimately add or refresh their own shadow keys after the merge.
        baseline.write_bytes(subprocess.check_output(['git', 'show', 'HEAD:assets/generated/unit_shadow_cache.res'], cwd=ROOT))
        script = 'experiments/cutouts/storm_capacitor/rr17_shadow_check.gd'
        result = godot(script, '--baseline', baseline)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn('RR17 SHADOW PRESERVATION: PASS (', result.stdout)
        result = godot(script)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('Use -- --baseline PATH', result.stdout + result.stderr)
        self.assertNotIn('/private/tmp/', (ROOT / script).read_text())


if __name__ == '__main__':
    unittest.main()
