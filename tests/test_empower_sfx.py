"""Owner-approved Empower assets, provenance and mix integration contracts."""
from __future__ import annotations

import hashlib
import json
from pathlib import Path
import runpy
import sys
import unittest

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from tools.sfx_lab.common import decode
from tools.sfx_lab.sync import leading_ms
from tools.sfx_lab.sync_metrics import envelope_times
MIX = runpy.run_path(str(ROOT / 'spec/peer_benchmark/staged/sfx/measure_mix.py'))['mmax']
TARGETS = {'empower.charge': -24, 'empower.uncharge': -30}
LICENCES = {'empower.charge': 'Sonniss GDC Bundle licence', 'empower.uncharge': 'CC0-1.0'}
MIX_TOLERANCE_LU = 0.05


def read(relative):
    return json.loads((ROOT / relative).read_text())


class EmpowerSfxTests(unittest.TestCase):
    def test_approved_recipe_and_transitive_licence_provenance(self):
        provenance = read('assets/audio/sfx/empower-design-provenance.json')
        recipes = read(provenance['recipe_file'])
        approved = read('spec/peer_benchmark/staged/sfx/approved_empower.json')
        manifest = read('spec/assets/sfx/manifest_empower.json')
        self.assertEqual({row['cue_id'] for row in manifest['outputs']}, set(TARGETS))
        for row in manifest['outputs']:
            cue = row['cue_id']
            with self.subTest(cue=cue):
                design = provenance['designs'][cue]
                self.assertEqual(design['recipe'], recipes[cue]['A'])
                self.assertIn('onset_note', design['recipe'])
                self.assertEqual(design['licence_id'], LICENCES[cue])
                self.assertEqual(row['licence_id'], LICENCES[cue])
                self.assertTrue(all(layer['source_sha256'] and layer['licence_id'] for layer in design['layers']))
                self.assertEqual(row['take_id'], approved[cue]['variants'][0]['take'])
                self.assertEqual(row['take_id'].split('#')[0], row['source_sha256'][:12])
                self.assertEqual(row['source_path'], f'designed/{cue}/A.wav')
                self.assertEqual(row['category'], 'card')
                self.assertFalse(row['loop'])
                path = ROOT / 'assets/audio/sfx/cues' / row['path']
                self.assertEqual(hashlib.sha256(path.read_bytes()).hexdigest(), row['output_sha256'])

    def test_mix_targets_and_six_db_difference(self):
        cues = read('data/sfx_cues.json')['cues']
        targets = read('spec/peer_benchmark/staged/sfx/mix_targets.json')
        actual = {}
        for cue, target in TARGETS.items():
            entry = cues[cue]
            self.assertEqual(targets[cue], target)
            self.assertEqual(entry['bus'], cues['card.select']['bus'])
            path = ROOT / entry['variants'][0].removeprefix('res://')
            actual[cue] = MIX(path) + entry['volume_db']
            self.assertAlmostEqual(actual[cue], target, delta=MIX_TOLERANCE_LU)
            self.assertEqual(entry.get('pitch_jitter', 0), 0)
            self.assertEqual(entry.get('cooldown_ms', 0), 0)
            self.assertFalse(entry.get('loop', False))
            self.assertNotIn('TODO_DESIGN_sync_policy', entry)
            self.assertFalse(entry.get('sync_contact_alignment', False))
        self.assertAlmostEqual(actual['empower.charge'] - actual['empower.uncharge'], 6, delta=MIX_TOLERANCE_LU)

    def test_hash_bound_samples_meet_input_onset_and_duration(self):
        samples = read('tests/fixtures/empower_sfx_samples.json')
        self.assertEqual(len(samples), 2)
        for resource, sample in samples.items():
            path = ROOT / resource.removeprefix('res://')
            audio, rate = decode(path)
            self.assertEqual(hashlib.sha256(path.read_bytes()).hexdigest(), sample['sha256'])
            self.assertEqual(rate, 48000)
            self.assertLessEqual(leading_ms(audio, rate), 10)
            measured = envelope_times(audio, rate)
            self.assertLessEqual(measured['perceived_onset_ms'], 40)
            self.assertLessEqual(measured['peak_ms'], 30)
            self.assertAlmostEqual(leading_ms(audio, rate), sample['leading_ms'])
            self.assertAlmostEqual(len(audio) / rate, sample['duration_seconds'])
            self.assertLessEqual(sample['duration_seconds'], 1.2)


if __name__ == '__main__':
    unittest.main()
