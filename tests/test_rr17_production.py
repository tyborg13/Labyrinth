"""Actual RunScene callbacks, sound/VFX contact and strict action regressions."""
import copy
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'experiments/cutouts/storm_capacitor'))
from rr17_build import read, CASE, PRODUCTION, write
from rr17_contract import channels, expected_glow, image_digest
from rr17_production import production_errors
from PIL import Image

PROOF_TIMEOUT_SECONDS = 180


class ProductionTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.temp = tempfile.TemporaryDirectory(prefix='rr17-production-')
        output = Path(cls.temp.name)
        command = [sys.executable, 'tools/godot_task_runner.py', '--task-id', os.environ.get('LABYRINTH_TASK_ID', 'rr-17'), '--stream',
            '--', 'godot', '--headless', '--path', '.', '--script', 'tests/rr17/production_capture.gd', '--',
            '--type', 'storm_capacitor', '--output', str(output), '--logic-only']
        process = subprocess.run(command, cwd=ROOT, capture_output=True, text=True, timeout=PROOF_TIMEOUT_SECONDS)
        path = output / 'logic_frames.json'
        if not path.exists(): raise AssertionError(process.stdout + process.stderr)
        cls.report = read(path)
        if process.returncode or cls.report['errors']: raise AssertionError(process.stdout + process.stderr)

    @classmethod
    def tearDownClass(cls):
        cls.temp.cleanup()

    def test_actual_callbacks_meet_all_gates_including_revised_hit(self):
        self.assertFalse(self.report['native_pixels'])
        self.assertTrue(self.report['ok'])
        self.assertEqual(production_errors(self.report), [])
        self.assertEqual(self.report['completions']['charge']['charge'], 1)
        self.assertEqual(self.report['completions']['discharge']['charge'], 0)

    def test_hit_six_changing_frames_rule_stays_strict(self):
        rows = [r for r in self.report['frames'] if r['stage'] == 'hit']
        self.assertGreaterEqual(len({r['pose_sha256'] for r in rows}), 6)
        mutant = copy.deepcopy(self.report)
        for row in mutant['frames']:
            if row['stage'] == 'hit': row['pose_sha256'] = 'frozen'
        self.assertIn('hit: fewer than six changing presented states (1)', production_errors(mutant))

    def test_charge_and_chain_sounds_vfx_begin_at_exact_contacts(self):
        for clip, contact in [('charge', .5), ('discharge', .45)]:
            rows = [r for r in self.report['frames'] if r['stage'] == clip]
            before = [r for r in rows if r['snapshot']['phase'] < contact - 1e-6]
            at = [r for r in rows if abs(r['snapshot']['phase'] - contact) < 1e-6]
            self.assertTrue(at, clip)
            self.assertTrue(all(not r['effect'] and r['sfx_count'] == 0 for r in before), clip)
            self.assertTrue(all(r['effect'] and r['sfx_count'] >= 1 for r in at), clip)
        hops = {r['sfx_count'] for r in self.report['frames'] if r['stage'] == 'discharge'}
        self.assertGreaterEqual(max(hops), 4, 'Existing four-hop fixture plays every chain cue')

    def test_every_runtime_frame_uses_the_director_glow_level(self):
        column = Image.open(CASE / 'paint/column.png').convert('RGBA')
        expected = {level: image_digest(expected_glow(column, level)) for level in range(-2, 3)}
        for row in self.report['frames']:
            snapshot = row['snapshot']
            level = int(channels(row['stage'], snapshot['presented_phase']).get('column.glow', 0))
            self.assertEqual(row['glow_sha256'], expected[level], (row['stage'], snapshot['phase']))

    def test_death_finishes_before_existing_fade(self):
        rows = [r for r in self.report['frames'] if r['stage'] == 'death' and 'fade_progress' in r]
        self.assertTrue(rows)
        self.assertTrue(all(r['fade_progress'] == 0 for r in rows if r['snapshot']['phase'] < 1))
        self.assertTrue(any(r['snapshot']['phase'] == 1 and r['fade_progress'] > .9 for r in rows))

    def test_omitted_contact_and_action_mutations_fail(self):
        mutant = copy.deepcopy(self.report)
        mutant['frames'] = [r for r in mutant['frames'] if r['stage'] != 'charge' or abs(r['snapshot']['phase'] - .5) > 1e-6]
        self.assertIn('charge: missing real contact frame', production_errors(mutant))
        mutant['frames'] = [r for r in mutant['frames'] if r['stage'] != 'death']
        self.assertIn('death: fewer than six sampled frames', production_errors(mutant))

    def test_frozen_progression_and_early_vfx_mutations_fail(self):
        mutant = copy.deepcopy(self.report)
        for row in mutant['frames']:
            if row['stage'] == 'charge':
                row['pose_sha256'] = 'frozen'
                row['effect'] = {'kind': 'status'}
        errors = production_errors(mutant)
        self.assertIn('charge: fewer than six changing presented states (1)', errors)
        self.assertIn('charge: VFX before contact', errors)

    def test_production_bindings_are_required(self):
        mutant = copy.deepcopy(self.report)
        mutant['inputs']['production:compiled_motion.json'] = 'stale'
        self.assertIn('Stale production/case runtime bindings', production_errors(mutant))
        mutant = copy.deepcopy(self.report)
        del mutant['inputs']['production:front.json']
        self.assertIn('Stale production/case runtime bindings', production_errors(mutant))

    def test_reversed_production_only_death_lean_is_caught_from_fresh_rigs(self):
        import rr17_gates as gate
        path = PRODUCTION / 'compiled_motion.json'
        original = path.read_bytes()
        try:
            compiled = read(path)
            for tracks in compiled['view_tracks'].values():
                for track in tracks['death']:
                    if track['channel'] == 'lean_deg':
                        for key in track['keys']: key['value'] *= -1
            write(path, compiled)
            samples = Path(self.temp.name) / 'mutant_samples.json'
            command = [sys.executable, 'tools/godot_task_runner.py', '--task-id', os.environ.get('LABYRINTH_TASK_ID', 'rr-17'), '--stream',
                '--', 'godot', '--headless', '--path', '.', '--script', 'tests/rr17/samples.gd', '--', '--output', str(samples)]
            result = subprocess.run(command, cwd=ROOT, capture_output=True, text=True, timeout=PROOF_TIMEOUT_SECONDS)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            report = read(samples)
            self.assertEqual(gate.motion_errors(report), [], 'Case motion stays unchanged')
            self.assertTrue(any('production:' in e and 'signed' in e for e in gate.production_motion_errors(report)))
            self.assertTrue(any('protected compilation' in e for e in gate.asset_errors()))
            output = Path(self.temp.name) / 'mutant_production'
            command = [sys.executable, 'tools/godot_task_runner.py', '--task-id', os.environ.get('LABYRINTH_TASK_ID', 'rr-17'), '--stream',
                '--', 'godot', '--headless', '--path', '.', '--script', 'tests/rr17/production_capture.gd', '--',
                '--type', 'storm_capacitor', '--output', str(output), '--logic-only']
            result = subprocess.run(command, cwd=ROOT, capture_output=True, text=True, timeout=PROOF_TIMEOUT_SECONDS)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            mutant = read(output / 'logic_frames.json')
        finally:
            path.write_bytes(original)
        # Evaluate after restoration: a stale hash alone cannot satisfy this.
        self.assertIn('death/cap: production signed local motion differs', production_errors(mutant))


if __name__ == '__main__':
    unittest.main()
