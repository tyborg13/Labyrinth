"""Slag Mortar implementation contracts and independent failure mutations."""
import copy
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

from PIL import Image

PROJECT = Path(__file__).resolve().parents[1]
sys.path[:0] = [str(PROJECT / 'tools'), str(PROJECT / 'experiments/cutouts/slag_mortar')]
from rr22_case import CASE, ASSETS, DIRECTOR, PIECES
from rr22_gates import support_report, lob_report, green_pixels
from humanoid_cutout.gates import structure_errors, source_errors, bone_errors, bindings
from humanoid_cutout.action_direction import report as direction_report
from humanoid_cutout.reach import report as reach_report
from humanoid_cutout.compiler import compile_motion
from cutout_pipeline.cases import read_json
from rr11_knees import knee_report

PROOF_TIMEOUT_SECONDS = 180
FIXTURE_SLIDE_PX = 2


class SlagMortarTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.layouts = {v: read_json(CASE / f'layouts/{v}.json') for v in ('front', 'rear')}
        cls.data = read_json(CASE / 'compiled_motion.json')
        cls.build = read_json(CASE / 'proof/build.json')
        with tempfile.TemporaryDirectory(prefix='rr22-bones-') as folder:
            path = Path(folder) / 'samples.json'
            result = subprocess.run([sys.executable, 'tools/godot_task_runner.py', '--task-id', 'rr-22', '--stream', '--',
                'godot', '--headless', '--path', '.', '--script', 'tests/rr22/samples.gd', '--',
                '--case', str(CASE), '--output', str(path)], cwd=PROJECT, capture_output=True, text=True, timeout=PROOF_TIMEOUT_SECONDS)
            if result.returncode: raise AssertionError(result.stdout + result.stderr)
            cls.samples = read_json(path)
        cls.bound = bindings(CASE)

    def test_protected_motion_and_compilation(self):
        self.assertEqual((CASE / 'director_motion.json').read_bytes(), DIRECTOR.read_bytes())
        self.assertEqual(compile_motion(DIRECTOR, 'slag_mortar', self.layouts, self.data['projection']), self.data)
        self.assertEqual(self.data['TODO_DESIGN'], {})

    def test_exact_visible_rest_cut_and_source(self):
        for view, layout in self.layouts.items():
            with self.subTest(view=view):
                self.assertEqual(structure_errors(layout, self.build), [])
                self.assertEqual(source_errors(CASE, layout, self.build), [])
                self.assertEqual(self.build['views'][view]['rest_mismatch_pixels'], 0)
                self.assertEqual(layout['source_labels'], PIECES)
                self.assertEqual(layout['joints']['mortar']['parent'], 'torso')
                self.assertEqual(layout['joints']['apron_mid']['parent'], 'pelvis')
                self.assertEqual(layout['joints']['apron_tip']['parent'], 'apron_mid')
                self.assertEqual({m['name'] for m in layout['joint_meshes'] if not m['hidden_material']},
                                 {'arm_near', 'arm_far', 'leg_near', 'leg_far', 'apron'})
                self.assertEqual(layout['features'][0]['piece'], 'mortar')
                self.assertEqual((CASE / f'source/{view}/approved.png').read_bytes(),
                                 (PROJECT / f'spec/art_identity/jobs/slag_mortar/mq9_{view}/processed.png').read_bytes())

    def test_all_motion_and_idle_groups(self):
        for layout in self.layouts.values():
            self.assertEqual(bone_errors(layout, self.data, self.samples, self.bound), [])
        mutant = copy.deepcopy(self.samples)
        row = next(r for r in mutant['samples'] if r['view'] == 'front' and r['clip'] == 'idle')
        row['bones']['hand_near']['global'][4] += FIXTURE_SLIDE_PX
        self.assertTrue(any('idle group deformed' in e for e in bone_errors(self.layouts['front'], self.data, mutant, self.bound)))

    def test_lob_and_scatter_directions(self):
        for view, layout in self.layouts.items():
            direction = direction_report(layout, self.data, self.samples, self.bound, require_presented=True)
            self.assertEqual(direction['errors'], [])
            self.assertTrue(any(r['clip'] == 'scatter' and r['forward_px'] > 0 for r in direction['rows']))
            self.assertEqual(lob_report(layout, self.data, self.samples)['errors'], [])
        mutant = copy.deepcopy(self.samples)
        row = next(r for r in mutant['samples'] if r['view'] == 'front' and r['clip'] == 'lob' and r['kind'] == 'authored' and r['phase'] == .6)
        row['bones']['mortar']['global'][1] *= -1
        self.assertTrue(lob_report(self.layouts['front'], self.data, mutant)['errors'])

    def test_knees_supports_and_dense_reach(self):
        for view, layout in self.layouts.items():
            self.assertEqual(knee_report(layout, self.data, self.samples)['errors'], [])
            self.assertEqual(support_report(layout, self.data, self.samples)['errors'], [])
            reach = reach_report(layout, self.data, step_distance_px=96, screen_pixel_scale=2)
            self.assertEqual(reach['errors'], [])
            self.assertEqual(reach['dense_intervals'], 1000)
            self.assertTrue(reach['overreach'])
            self.assertEqual(self.data['leg_roles'][view]['stride'], 'near' if view == 'front' else 'far')
        mutant = copy.deepcopy(self.samples)
        row = next(r for r in mutant['samples'] if r['view'] == 'front' and r['clip'] == 'move' and r['kind'] == 'presented' and r['frame'] == 0)
        row['bones']['foot_near']['global'][4] += FIXTURE_SLIDE_PX
        self.assertTrue(support_report(self.layouts['front'], self.data, mutant)['errors'])

    def test_missing_mesh_and_tuck_mutations(self):
        layout = copy.deepcopy(self.layouts['front'])
        layout['joint_meshes'] = [m for m in layout['joint_meshes'] if m['name'] != 'apron']
        self.assertTrue(any('required meshes differ' in e for e in structure_errors(layout, self.build)))
        build = copy.deepcopy(self.build)
        build['tucks'][0]['minimum_px'] = 2
        self.assertTrue(any('tuck' in e for e in structure_errors(self.layouts['front'], build)))

    def test_green_gate_does_not_silently_approve_director_conflict(self):
        source = Image.open(CASE / 'source/front/approved.png')
        self.assertEqual(green_pixels(source), 28)
        self.assertIn('TODO_DESIGN_front_green_dominant_texels', read_json(CASE / 'cutout.json')['design_placeholders'])
        self.assertEqual(green_pixels(Image.new('RGBA', (1, 1), (0, 255, 0, 255))), 1)
        self.assertEqual(green_pixels(Image.new('RGBA', (1, 1), (0, 255, 0, 0))), 0)

    def test_canon_scale_survives_production_path_registration(self):
        from art_identity_gate import coverage
        metadata = coverage(PROJECT)
        for view in ('front', 'rear'):
            old = 'assets/art/enemies/slag_mortar' + ('_rear' if view == 'rear' else '') + '.png'
            self.assertEqual(metadata[old]['art_scale'], 1.04)
            self.assertEqual(metadata[f'assets/units/slag_mortar_cutout/humanoid_v2/{view}/rest.png']['art_scale'], 1.04)

    def test_identity_record_update_preserves_unrelated_raw_entries(self):
        from rr22_density import preserve_identity_entries
        before = '{"entries": [\n    {"path": "other", "id": "first", "id": "second"}\n  ]}\n'
        updated = {'entries': [{'path': 'assets/units/slag_mortar_cutout/front/rest.png', 'id': 'slag_mortar'}]}
        result = preserve_identity_entries(before, updated)
        self.assertIn('{"path": "other", "id": "first", "id": "second"}', result)
        self.assertEqual(len(json.loads(result)['entries']), 2)

    def test_production_closure_and_data(self):
        integration = read_json(ASSETS / 'integration.json')
        self.assertEqual(integration['rig_directory'], 'humanoid_v2')
        self.assertEqual(integration['idle_phase_seed'], 'slot')
        self.assertEqual(integration['death_timing']['clip_seconds'], 1.5)
        self.assertFalse(integration['ready'])
        for view in self.layouts:
            layout = read_json(ASSETS / f'humanoid_v2/{view}.json')
            self.assertNotIn('experiments/', layout['motion_data'])
            for part in layout['parts'] + layout['joint_meshes']:
                self.assertTrue((ASSETS / 'humanoid_v2' / part['file']).is_file())
        self.assertEqual((ASSETS / 'humanoid_v2/director_motion.json').read_bytes(), DIRECTOR.read_bytes())


if __name__ == '__main__': unittest.main()
