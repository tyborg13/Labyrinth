"""rr-17 exact painting, signed motion, presented pixels and mutation checks."""
import copy
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'experiments/cutouts/storm_capacitor'))
import rr17_gates as gate
from rr17_build import CASE, DIRECTOR, PRODUCTION, read, arc_mask, glow
from rr17_contract import expected_glow

PROOF_TIMEOUT_SECONDS = 60
FIXTURE_SIZE = 32


class CutoutTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.temp = tempfile.TemporaryDirectory(prefix='rr17-samples-')
        output = Path(cls.temp.name) / 'samples.json'
        command = [sys.executable, 'tools/godot_task_runner.py', '--task-id', os.environ.get('LABYRINTH_TASK_ID', 'rr-17'), '--stream',
            '--', 'godot', '--headless', '--path', '.', '--script', 'tests/rr17/samples.gd', '--', '--output', str(output)]
        result = subprocess.run(command, cwd=ROOT, capture_output=True, text=True, timeout=PROOF_TIMEOUT_SECONDS)
        if result.returncode: raise AssertionError(result.stdout + result.stderr)
        cls.samples = read(output)

    @classmethod
    def tearDownClass(cls):
        cls.temp.cleanup()

    def test_all_headless_gates(self):
        result = gate.pixel_gate(self.samples)
        self.assertEqual(result['errors'], [])
        self.assertEqual(result['held_shimmer_residual'], 0)
        self.assertEqual(len(result['frames']), 696)
        self.assertFalse(result['native_pixels'])
        for view in ('front', 'rear'):
            self.assertEqual(result['changing_states'][view + '/hit'], 6)
            self.assertEqual(result['transitions'][view + '/hit'], 7)

    def test_protected_bytes_and_rest_partition(self):
        self.assertEqual(gate.asset_errors(), [])
        for name, target in [('motion_tracks.json', 'director_motion.json'), ('cap_mask.png', 'source/cap_mask.png'), ('vent_fill.png', 'source/vent_fill.png')]:
            self.assertEqual((DIRECTOR / name).read_bytes(), (CASE / target).read_bytes())
        for view in ('front', 'rear'):
            layout = read(CASE / f'layouts/{view}.json')
            for part in layout['parts']:
                self.assertEqual((CASE / part['file']).read_bytes(), (PRODUCTION / part['file']).read_bytes())

    def test_glow_table_preserves_every_non_arc_pixel_and_alpha(self):
        layout = read(CASE / 'layouts/front.json')
        original = np.asarray(Image.open(CASE / 'paint/column.png').convert('RGBA'))
        mask = arc_mask(original)
        self.assertGreater(int(mask.sum()), 0)
        for level in range(-2, 3):
            actual = np.asarray(Image.open(PRODUCTION / layout['glow_textures'][str(level)]).convert('RGBA'))
            self.assertTrue(np.array_equal(actual, expected_glow(original, level)))
            self.assertTrue(np.array_equal(actual[~mask], original[~mask]))
            self.assertTrue(np.array_equal(actual[..., 3], original[..., 3]))

    def test_hold_holds_previous_until_key_then_jumps(self):
        rows = [[0, 0], [.5, 2, 'hold'], [1, -1, 'hold']]
        self.assertEqual(gate.value(rows, .5 - 1e-9), 0)
        self.assertEqual(gate.value(rows, .5), 2)
        self.assertEqual(gate.value(rows, .999), 2)
        self.assertEqual(gate.value(rows, 1), -1)

    def test_compiler_sign_and_applied_bone_mutations_fail(self):
        mutant = copy.deepcopy(self.samples)
        row = next(r for r in mutant['authored'] if r['clip'] == 'death' and r['phase'] > .4)
        row['bones']['cap']['local'][1] *= -1
        row['bones']['cap']['local'][2] *= -1
        self.assertTrue(any('signed local motion' in e for e in gate.motion_errors(mutant)))
        row['bones']['root']['global'][4] += 1
        self.assertTrue(any('root' in e for e in gate.motion_errors(mutant)))

    def test_omitted_keys_midpoints_contacts_and_actions_fail(self):
        mutant = copy.deepcopy(self.samples)
        mutant['authored'] = [r for r in mutant['authored'] if r['clip'] != 'discharge' or abs(r['phase'] - .45) > 1e-8]
        self.assertTrue(any('discharge' in e for e in gate.coverage(mutant, 'authored')))
        mutant['samples'] = [r for r in mutant['samples'] if r['clip'] != 'charge']
        self.assertTrue(any('charge' in e for e in gate.coverage(mutant)))

    def test_frozen_glow_and_frozen_sprite_mutations_fail(self):
        mutant = copy.deepcopy(self.samples)
        row = next(r for r in mutant['samples'] if r['clip'] == 'charge' and .4 < r['phase'] < .5)
        row['glow_sha256'] = 'frozen'
        row['parts']['cap']['transform'][5] += 1
        result = gate.pixel_gate(mutant)
        self.assertTrue(any('runtime glow differs' in e for e in result['errors']))
        self.assertTrue(any('stepped transform differs' in e for e in result['errors']))

    def test_detached_components_of_each_size_one_through_eight_fail(self):
        for count in range(1, 9):
            image = np.zeros((FIXTURE_SIZE, FIXTURE_SIZE, 4), dtype=np.uint8)
            image[2:18, 2:18, 3] = 255
            image[20, 20:20 + count, 3] = 255
            self.assertEqual(gate.small_components(image), [count])

    def test_dark_slab_exempts_only_vent_and_approved_paint(self):
        image = np.full((FIXTURE_SIZE, FIXTURE_SIZE, 4), 255, dtype=np.uint8)
        mutant = image.copy()
        mutant[5:8, 5:8, :3] = 0
        self.assertTrue(gate.dark_slab_errors(mutant, image))
        exemption = np.zeros((FIXTURE_SIZE, FIXTURE_SIZE), dtype=bool)
        exemption[5:8, 5:8] = True
        self.assertEqual(gate.dark_slab_errors(mutant, image, exemption), [])
        self.assertEqual(gate.dark_slab_errors(mutant, mutant), [])

    def test_native_pixel_and_tie_mutations_fail(self):
        from maquette_motion import pixels, native_ties
        image = np.full((16, 16, 4), 255, dtype=np.uint8)
        transform = np.eye(3)
        samples = pixels.render(Image.fromarray(image), transform, with_ties=True)
        actual = samples.default.copy()
        self.assertTrue(pixels.native_frame_matches(actual, samples.default, samples))
        actual[128:144, 128:144, :3] = 0
        self.assertFalse(pixels.native_frame_matches(actual, samples.default, samples))
        canonical = np.zeros((16, 16, 4), dtype=np.uint8)
        previous = canonical.copy()
        current = canonical.copy(); current[1, 1] = 255
        before, after = native_ties.explanation(previous, current, True, canonical, canonical)
        self.assertEqual(pixels.residual(previous, current, before, after)[0], 1)


if __name__ == '__main__':
    unittest.main()
