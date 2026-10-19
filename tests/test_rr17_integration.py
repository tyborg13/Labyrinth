"""Feedback 1: declarations are opt-in, prior production death clocks are exact."""
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'experiments/cutouts/storm_capacitor'))
from rr17_build import CASE, PRODUCTION, read

BASELINE_HEAD = '2d31a138c3cf8d84bb1f24e3b8206e48d9b89e56'
PROOF_TIMEOUT_SECONDS = 60
UNCHANGED_TYPES = ('hoarfrost_seer', 'arc_thrall', 'burrow_grub', 'ember_tick', 'bile_bloomer', 'lightning_wisp')


class IntegrationTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.temp = tempfile.TemporaryDirectory(prefix='rr17-integration-')
        output = Path(cls.temp.name) / 'integration.json'
        command = [sys.executable, 'tools/godot_task_runner.py', '--task-id', os.environ.get('LABYRINTH_TASK_ID', 'rr-17'), '--stream',
            '--', 'godot', '--headless', '--path', '.', '--script', 'tests/rr17/integration_samples.gd', '--', '--output', str(output)]
        result = subprocess.run(command, cwd=ROOT, capture_output=True, text=True, timeout=PROOF_TIMEOUT_SECONDS)
        if result.returncode: raise AssertionError(result.stdout + result.stderr)
        cls.after = read(output)
        cls.before = read(ROOT / 'tests/rr17/fixtures/integration_before_feedback.json')

    @classmethod
    def tearDownClass(cls):
        cls.temp.cleanup()

    def test_all_six_prior_death_clocks_phases_and_idle_seeds_are_exact(self):
        # The fixture was captured before shared-code edits at BASELINE_HEAD.
        # Compare every real dissolve-material frame, not a copied formula.
        for type in UNCHANGED_TYPES:
            with self.subTest(type=type):
                self.assertEqual(self.after[type], self.before[type])

    def test_declared_death_preserves_capacitor_clock_too(self):
        type = 'storm_capacitor'
        self.assertEqual(self.after[type], self.before[type])
        self.assertEqual(self.after[type]['frames'], 147)

    def test_only_capacitor_declares_death_and_slot_idle_seed(self):
        policy = read(CASE / 'integration.json')
        production = read(PRODUCTION / 'integration.json')
        self.assertEqual(policy['idle_phase_seed'], 'slot')
        self.assertEqual(policy['death_timing'], {'clip_seconds': 1.4, 'dissolve_frames': 28, 'dissolve_frame_seconds': .037})
        for key, value in policy.items(): self.assertEqual(production[key], value)
        for type in UNCHANGED_TYPES:
            folder = 'shale_bloomer' if type == 'bile_bloomer' else type
            path = ROOT / 'assets/units' / (folder + '_cutout/integration.json')
            entry = read(path) if path.exists() else {}
            self.assertNotIn('death_timing', entry)
            self.assertNotIn('idle_phase_seed', entry)

    def test_shared_death_and_idle_code_has_no_creature_specific_branch(self):
        name = 'storm_capacitor'
        self.assertNotIn(name, (ROOT / 'scripts/maquette_cutout_runtime/death.gd').read_text())
        for file in ('combat_board_view', 'cutout_context'):
            self.assertNotIn(name, (ROOT / ('scripts/' + file + '.gd')).read_text())
        scene = (ROOT / 'scripts/run_scene.gd').read_text()
        for line in scene.splitlines():
            if name in line: self.assertIn('_cutout/actions.gd', line)
        presentation = (ROOT / 'scripts/maquette_cutout_runtime/presentation.gd').read_text()
        self.assertNotIn(name, presentation.split('static func sync(', 1)[1])

    def test_extracted_portrait_registry_keeps_all_paths(self):
        import re
        source = (ROOT / 'scripts/turn_order_portraits.gd').read_text()
        actual = dict(re.findall(r'"([^"]+)"\s*:\s*"([^"]+)"', source))
        expected = read(ROOT / 'tests/rr17/fixtures/turn_order_portraits_before_feedback.json')
        self.assertEqual(actual, expected)


if __name__ == '__main__':
    unittest.main()
