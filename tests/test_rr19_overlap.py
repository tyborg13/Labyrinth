"""rr-19: real enemy-phase overlap routing, Git-base parity and clock mutation."""
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
BASE = 'c8d364c7a'
PROOF_TIMEOUT_SECONDS = 90
TYPES = ('hoarfrost_seer', 'arc_thrall', 'burrow_grub', 'ember_tick', 'bile_bloomer', 'lightning_wisp')


def run_samples(output, source=None):
    command = [sys.executable, 'tools/godot_task_runner.py', '--task-id',
        os.environ.get('LABYRINTH_TASK_ID', 'rr-19'), '--stream', '--', 'godot', '--headless',
        '--path', '.', '--script', 'tests/rr19/overlap_samples.gd', '--', '--output', str(output)]
    if source is not None:
        command.extend(['--pacing-source', str(source)])
    result = subprocess.run(command, cwd=ROOT, capture_output=True, text=True, timeout=PROOF_TIMEOUT_SECONDS)
    if result.returncode:
        raise AssertionError(result.stdout + result.stderr)
    return json.loads(output.read_text())


def death_at(case, type, usec):
    row = next(row for row in case['rows'] if row['usec'] == usec)
    return next(unit for unit in row['presentation'].get('death_animation_units', []) if unit['type'] == type)


def encoded(value):
    return json.dumps(value, sort_keys=True, separators=(',', ':')).encode()


def changing_clock(case, type):
    result = []
    previous = None
    for row in case['rows']:
        unit = next((unit for unit in row['presentation'].get('death_animation_units', []) if unit['type'] == type), None)
        if unit is None:
            continue
        state = (unit['death_frame'], unit['death_progress'])
        if state != previous:
            result.append((row['usec'], *state))
        previous = state
    return result


class OverlapTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.temp = tempfile.TemporaryDirectory(prefix='rr19-overlap-')
        cls.directory = Path(cls.temp.name)
        cls.base_source = subprocess.check_output(['git', 'show', BASE + ':scripts/combat_pacing.gd'], cwd=ROOT, text=True)
        baseline = cls.directory / 'base_pacing.gd'
        baseline.write_text(cls.base_source)
        cls.base = run_samples(cls.directory / 'base.json', baseline)
        cls.current = run_samples(cls.directory / 'current.json')

    @classmethod
    def tearDownClass(cls):
        cls.temp.cleanup()

    def test_every_case_reaches_enemy_overlap_and_preserves_resolver_state_and_rail(self):
        for label, case in self.current.items():
            with self.subTest(label=label):
                self.assertEqual(case['queued'], 1)
                self.assertTrue(case['states_unchanged'])
                self.assertEqual(case['orders'], self.base[label]['orders'])
                self.assertEqual(len(case['orders']), 1)
                self.assertTrue(all(unit['hp'] == 0 for unit in case['health']))
                self.assertEqual(case['burst_events'], int(label.startswith('retaliate_')))
                self.assertEqual(case['rows'][-1]['remaining'], 0)
                self.assertNotIn('death_animation_units', case['rows'][-1]['presentation'])

    def test_retaliate_tick_reaches_frame_53_at_900000_usec_as_alone(self):
        solo = death_at(self.base['retaliate_tick'], 'ember_tick', 900000)
        self.assertEqual(solo['death_frame'], 53)
        self._assert_retaliate_tick_clock(self.current)
        self.assertEqual(self.current['retaliate_capacitor']['health'],
                         [{'type': 'ember_tick', 'hp': 0}, {'type': 'storm_capacitor', 'hp': 0}])

    def _assert_retaliate_tick_clock(self, report):
        paired = death_at(report['retaliate_capacitor'], 'ember_tick', 900000)
        self.assertEqual((paired['death_frame'], paired['death_progress']), (53, 1.0))

    def test_all_six_pairs_keep_every_base_overlap_frame_and_last_frame_time(self):
        for type in TYPES:
            expected = changing_clock(self.base[type], type)
            for label in ('capacitor+' + type, type + '+capacitor'):
                with self.subTest(label=label):
                    self.assertEqual(changing_clock(self.current[label], type), expected)
        self.assertEqual(changing_clock(self.current['retaliate_capacitor'], 'ember_tick'),
                         changing_clock(self.current['capacitor+ember_tick'], 'ember_tick'))

    def test_capacitor_has_all_147_frames_and_the_group_keeps_the_longest_hold(self):
        expected = changing_clock(self.base['storm_capacitor'], 'storm_capacitor')
        self.assertEqual(sorted({row[1] for row in expected}), list(range(147)))
        self.assertEqual(encoded(self.current['storm_capacitor']), encoded(self.base['storm_capacitor']))
        for type in TYPES:
            for label in ('capacitor+' + type, type + '+capacitor'):
                with self.subTest(label=label):
                    case = self.current[label]
                    self.assertEqual(changing_clock(case, 'storm_capacitor'), expected)
                    self.assertEqual(changing_clock(case, 'storm_capacitor'), changing_clock(self.base[label], 'storm_capacitor'))
                    hold_end = max(self.base[actor]['duration_usec'] for actor in ('storm_capacitor', type))
                    self.assertEqual(case['duration_usec'], hold_end)
                    self.assertEqual(next(row['remaining'] for row in case['rows'] if row['usec'] == hold_end - 1), 1)
                    self.assertEqual(next(row['remaining'] for row in case['rows'] if row['usec'] == hold_end), 0)
                    self.assertEqual(death_at(case, 'storm_capacitor', hold_end)['death_frame'], 146)

    def test_every_group_without_a_declaration_is_byte_identical_to_git_base(self):
        for label in (*TYPES, 'legacy_multi', 'legacy_all', 'retaliate_tick', 'retaliate_legacy'):
            with self.subTest(label=label):
                self.assertEqual(encoded(self.current[label]), encoded(self.base[label]))

    def test_all_non_death_presentation_is_byte_identical_to_git_base(self):
        for label, case in self.current.items():
            def non_death(rows):
                return [{key: value for key, value in row['presentation'].items() if key != 'death_animation_units'}
                        for row in rows]
            with self.subTest(label=label):
                self.assertEqual(encoded(non_death(case['rows'])), encoded(non_death(self.base[label]['rows'])))

    def test_shared_clock_mutation_is_caught_by_the_retaliate_regression(self):
        source = (ROOT / 'scripts/combat_pacing.gd').read_text()
        anchor = '\n\t\tDeathSequence.configure(sequence, scene, units, true)\n'
        self.assertEqual(source.count(anchor), 1)
        mutant = self.directory / 'shared_clock.gd'
        mutant.write_text(source.replace(anchor, '\n'))
        report = run_samples(self.directory / 'shared_clock.json', mutant)
        # Setup/compilation errors cannot count as a caught behavioral mutation.
        self.assertEqual(report['retaliate_capacitor']['queued'], 1)
        self.assertEqual(death_at(report['retaliate_capacitor'], 'ember_tick', 900000)['death_frame'], 20)
        with self.assertRaises(AssertionError):
            self._assert_retaliate_tick_clock(report)
        print('RR19 SHARED CLOCK MUTATION: CAUGHT (Tick frame 20 instead of 53 at 0.900 s)')


if __name__ == '__main__':
    unittest.main()
