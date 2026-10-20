"""rr-28 copies only own treated texels in the clips with joint tears."""
from copy import deepcopy
from pathlib import Path
import sys
import os
import subprocess
import tempfile
import unittest

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
sys.path[:0] = [str(ROOT / 'tools'), str(ROOT / 'experiments/cutouts/hoarfrost_seer')]
from rr28_build import RIGS, paths, apply, production_layouts
from rr28_check import model_for, committed
from humanoid_cutout.source_space import DetachedSource
from cutout_pipeline.cases import read_json
from humanoid_cutout.gait_continuations import active_recipe, errors, texture
from maquette_motion.pixels import rest_identity

PROOF_TIMEOUT_SECONDS = 90


class JointContinuationTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        folder = tempfile.TemporaryDirectory(prefix='rr28-bones-')
        cls.addClassCleanup(folder.cleanup)
        cls.samples = {}
        for name, (_, version) in RIGS.items():
            output = Path(folder.name) / (name + '.json')
            command = [sys.executable, 'tools/godot_task_runner.py', '--task-id',
                os.environ.get('LABYRINTH_TASK_ID', 'rr-28'), '--stream', '--', 'godot',
                '--headless', '--path', '.', '--script', f'tests/{version}/samples.gd', '--',
                '--case', str(paths(name)[0]), '--output', str(output)]
            result = subprocess.run(command, cwd=ROOT, capture_output=True, text=True,
                timeout=PROOF_TIMEOUT_SECONDS)
            if result.returncode:
                raise AssertionError(result.stdout + result.stderr)
            cls.samples[name] = read_json(output)

    def test_replay_is_idempotent_and_only_recipes_change_in_all_layout_copies(self):
        for name in RIGS:
            case, assets, recipe = paths(name)
            definitions = read_json(recipe / 'joint_continuations.json')
            for view in ('front', 'rear'):
                layout = read_json(case / f'layouts/{view}.json')
                self.assertEqual(errors(case, layout), [])
                self.assertEqual(apply(case, deepcopy(layout), definitions), layout)
                for path in [case / f'layouts/{view}.json', *production_layouts(assets, view)]:
                    production = read_json(path)
                    self.assertEqual(production.get('gait_continuations'), layout.get('gait_continuations'))
                    production.pop('gait_continuations', None)
                    self.assertEqual(production, __import__('json').loads(committed(path)))

    def test_clip_scope_and_exact_own_donor_rgba_including_density_treated_production(self):
        for name in RIGS:
            case, assets, _ = paths(name)
            clips = ['rest', *read_json(case / 'compiled_motion.json')['clips']]
            for view in ('front', 'rear'):
                for root, path in [(case, case / f'layouts/{view}.json'),
                                   *[(p.parent, p) for p in production_layouts(assets, view)]]:
                    layout = read_json(path)
                    for piece, recipe in layout.get('gait_continuations', {}).items():
                        part = next(p for p in layout['parts'] if p['name'] == piece)
                        donor = next(p for p in layout['parts'] if p['name'] == recipe['donor'])
                        self.assertEqual(part['logical_part'], donor['logical_part'])
                        original = texture(root, layout, part)
                        paint = np.asarray(Image.open(root / donor['file']).convert('RGBA'))
                        for clip in clips:
                            active = active_recipe(layout, piece, clip=clip, gait=clip == 'move')
                            filled = texture(root, layout, part, clip=clip, gait=clip == 'move')
                            if clip not in recipe['clips']:
                                self.assertIsNone(active)
                                np.testing.assert_array_equal(filled, original)
                            else:
                                self.assertIsNotNone(active)
                                expected = original.copy()
                                for x, y, u, v in recipe['texels']:
                                    self.assertEqual(original[y, x, 3], 0)
                                    expected[y, x] = paint[v, u]
                                np.testing.assert_array_equal(filled, expected)

    def test_every_original_native_pocket_pixel_is_covered_in_cpu_estimate(self):
        for name in RIGS:
            case, _, recipe = paths(name)
            poses = {(r['view'], r['clip'], r['frame']): r for r in self.samples[name]['samples'] if r['kind'] == 'presented'}
            definitions = read_json(recipe / 'joint_continuations.json')
            models = {v: model_for(name, case, read_json(case / f'layouts/{v}.json')) for v in definitions}
            cache, checked = {}, set()
            for pieces in definitions.values():
                for definition in pieces.values():
                    for row in definition['source_evidence']:
                        if row.get('reason'):
                            continue  # Additional census-trapped pockets have separate all-frame proof.
                        key = row['view'], row['clip'], row['frame']
                        if key not in cache:
                            layers, _ = models[key[0]].layers(poses[key])
                            cache[key] = np.logical_or.reduce([image[..., 3] > 0 for _, image, _ in layers])
                        x, y = np.asarray(row['pixels']).T
                        self.assertTrue(cache[key][y, x].all(), (name, key, row['bbox']))
                        checked.add((*key, tuple(row['bbox'])))
            self.assertEqual(len(checked), 31 if name == 'seer' else 85)

    def test_seer_fold_bridge_prevents_a_detached_copy_in_both_death_frames(self):
        case, _, _ = paths('seer')
        layout = read_json(case / 'layouts/front.json')
        damaged = deepcopy(layout)
        recipe = damaged['gait_continuations']['sleeve_far']
        recipe['texels'] = [row for row in recipe['texels'] if row[:2] != [11, 24]]
        for frame in (63, 64):
            pose = next(p for p in self.samples['seer']['samples'] if
                (p['view'], p['clip'], p['kind'], p['frame']) == ('front', 'death', 'presented', frame))
            transforms = {k: p['transform'] for k, p in pose['parts'].items()}
            for candidate, expected in ((layout, 0), (damaged, 1)):
                model = model_for('seer', case, deepcopy(candidate))
                layers, _ = model.layers(pose)
                report = DetachedSource(case, candidate).report(layers, transforms)
                self.assertEqual(len(report['unmatched_components']), expected)

    def test_rest_composites_stay_exact(self):
        for name in RIGS:
            self.assertTrue(rest_identity(paths(name)[0])['ok'])


if __name__ == '__main__':
    unittest.main(verbosity=2)
