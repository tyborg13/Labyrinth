"""Approved-pose preservation and the rr-26 source-edge regressions; no GUI."""
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

import numpy as np

ROOT = Path(__file__).resolve().parents[1]
sys.path[:0] = [str(ROOT / 'tools'), str(ROOT / 'experiments/cutouts/hollow_mimic')]
from case import CASE, read_json
from humanoid_cutout.cpu_pose import CpuPose
from humanoid_cutout.rest_space import DetachedSource
from humanoid_cutout.gates import structure_errors, source_errors

APPROVED_REVISION = 'e0d78de13'
SEER = ROOT / 'experiments/cutouts/hoarfrost_seer/rr10'
PROOF_TIMEOUT_SECONDS = 180


def approved(path):
    return subprocess.check_output(['git', 'show', APPROVED_REVISION + ':' + str(path.relative_to(ROOT))], cwd=ROOT)


class FragmentTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.samples = {}
        with tempfile.TemporaryDirectory(prefix='rr26-fragments-') as folder:
            for name, case, script in (('mimic', CASE, 'tests/rr20/samples.gd'),
                                       ('seer', SEER, 'tests/rr10/samples.gd')):
                output = Path(folder) / (name + '.json')
                command = [sys.executable, 'tools/godot_task_runner.py', '--task-id',
                    os.environ.get('LABYRINTH_TASK_ID', 'rr-26'), '--stream', '--',
                    'godot', '--headless', '--path', '.', '--script', script, '--',
                    '--case', str(case), '--output', str(output)]
                result = subprocess.run(command, cwd=ROOT, capture_output=True, text=True,
                                        timeout=PROOF_TIMEOUT_SECONDS)
                if result.returncode: raise AssertionError(result.stdout + result.stderr)
                cls.samples[name] = read_json(output)

    def test_original_paint_rest_motion_and_meshes_are_unchanged(self):
        for case, assets in ((CASE, ROOT / 'assets/units/hollow_mimic_cutout'),
                             (SEER, ROOT / 'assets/units/hoarfrost_seer_cutout/humanoid_v2')):
            for view in ('front', 'rear'):
                path = case / f'layouts/{view}.json'
                old, current = json.loads(approved(path)), read_json(path)
                self.assertEqual(old['joints'], current['joints'])
                for key in ('parts', 'joint_meshes'):
                    current_rows = {row['name']: row for row in current[key]}
                    for row in old[key]: self.assertEqual(row, current_rows[row['name']])
                for part in old['parts']:
                    if not part.get('hidden_material'):
                        path = case / part['file']
                        self.assertEqual(approved(path), path.read_bytes())
                for path in (case / old['rest_source'], assets / view / 'rest.png'):
                    self.assertEqual(approved(path), path.read_bytes())
            for folder in (case, assets):
                for name in ('compiled_motion.json', 'director_motion.json'):
                    path = folder / name
                    self.assertEqual(approved(path), path.read_bytes())

    def test_mimic_near_leg_underlap_fixes_both_frames_and_removal_reopens_them(self):
        layout = read_json(CASE / 'layouts/rear.json')
        model, source = CpuPose(CASE, layout), DetachedSource(CASE, layout)
        part = next(p for p in layout['parts'] if p['name'] == 'leg_near_hidden')
        missing = model.image(part['file']).copy()
        x, y = np.array([90, 185]) - part['offset']
        self.assertGreater(missing[y, x, 3], 0)
        missing[y, x] = 0
        overrides = {p['name']: missing if p['name'] == part['name'] else model.image(p['file'])
                     for p in layout['parts']}
        samples = self.samples['mimic']
        for frame in (12, 19):
            pose = next(p for p in samples['samples'] if p.get('kind') == 'presented' and
                        (p['view'], p['clip'], p['frame']) == ('rear', 'mirror', frame))
            transforms = {k: v['transform'] for k, v in pose['parts'].items()}
            self.assertEqual(source.report(model.layers(pose)[0], transforms)['metrics']['stray_components'], 0)
            self.assertGreater(source.report(model.layers(pose, overrides)[0], transforms)['metrics']['stray_components'], 0)

    def test_seer_sleeve_underlap_fixes_death_and_removal_reopens_it(self):
        layout = read_json(SEER / 'layouts/rear.json')
        model, source = CpuPose(SEER, layout), DetachedSource(SEER, layout)
        samples = self.samples['seer']
        pose = next(p for p in samples['samples'] if p.get('kind') == 'presented' and
                    (p['view'], p['clip'], p['frame']) == ('rear', 'death', 76))
        transforms = {k: v['transform'] for k, v in pose['parts'].items()}
        layers, _ = model.layers(pose)
        self.assertEqual(source.report(layers, transforms)['metrics']['stray_components'], 0)
        missing = [row for row in layers if row[0]['name'] != 'hidden_sleeve_far_edge_underlap']
        self.assertGreater(source.report(missing, transforms)['metrics']['stray_components'], 0)

    def test_both_changed_source_cases_keep_the_existing_structure_and_surface_rules(self):
        for case in (CASE, SEER):
            build = read_json(case / 'proof/build.json')
            for view in ('front', 'rear'):
                layout = read_json(case / f'layouts/{view}.json')
                self.assertEqual(structure_errors(layout, build), [])
                self.assertEqual(source_errors(case, layout, build), [])


if __name__ == '__main__': unittest.main()
