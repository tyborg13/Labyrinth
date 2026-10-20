"""rr-20 protected inputs, source contracts and negative controls; no GUI."""
import copy
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
sys.path[:0] = [str(ROOT/'tools'), str(ROOT/'experiments/cutouts/hollow_mimic')]
import gates as rr20
from case import CASE, ASSETS, DIRECTOR, VIEWS, DESIGN_PLACEHOLDERS, read_json, digest
from humanoid_cutout.gates import structure_errors, source_errors, bone_errors, bindings, idle_pixel_errors, clean_metrics
from humanoid_cutout.action_direction import report as directions
from humanoid_cutout.reach import report as reach
from humanoid_cutout.compiler import compile_motion
from humanoid_cutout.bone_contracts import leg_bend_side
from humanoid_cutout.anatomy import for_layout
from maquette_motion.features import source_pixels
from tests.mq11_preservation import rr20_inventory_context

PROOF_TIMEOUT_SECONDS = 180
MUTATION_OFFSET_PX = 4
FIXTURE_SIZE_PX = 8


class HollowMimicTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.data = read_json(CASE/'compiled_motion.json')
        cls.layouts = {v: read_json(CASE/f'layouts/{v}.json') for v in VIEWS}
        cls.build = read_json(CASE/'proof/build.json')
        with tempfile.TemporaryDirectory(prefix='rr20-bones-') as temporary:
            output = Path(temporary)/'samples.json'
            result = subprocess.run([sys.executable, 'tools/godot_task_runner.py', '--task-id', 'rr-20', '--stream', '--',
                'godot', '--headless', '--path', '.', '--script', 'tests/rr20/samples.gd', '--',
                '--case', str(CASE), '--output', str(output)], cwd=ROOT, capture_output=True, text=True, timeout=PROOF_TIMEOUT_SECONDS)
            if result.returncode: raise AssertionError(result.stdout + result.stderr)
            cls.samples = read_json(output)
        cls.bound = bindings(CASE)

    @rr20_inventory_context(rr20)
    def test_approved_inputs_and_prior_figures_are_byte_identical(self):
        self.assertEqual(rr20.protected_errors(), [])
        self.assertEqual((CASE/'director_motion.json').read_bytes(), DIRECTOR.read_bytes())
        self.assertEqual((ASSETS/'director_motion.json').read_bytes(), DIRECTOR.read_bytes())
        self.assertEqual(compile_motion(DIRECTOR, 'hollow_mimic', self.layouts, self.data['projection']), self.data)
        self.assertEqual(self.data['TODO_DESIGN'], {})

    def test_both_views_exact_rest_cut_and_front_only_feature(self):
        for view, layout in self.layouts.items():
            self.assertEqual(structure_errors(layout, self.build), [])
            self.assertEqual(source_errors(CASE, layout, self.build), [])
            self.assertEqual(self.build['views'][view]['rest_mismatch_pixels'], 0)
            self.assertEqual({m['name'] for m in layout['joint_meshes'] if not m['hidden_material']},
                             {'sleeve_near', 'sleeve_far', 'leg_near', 'leg_far'})
            for name in ('head', 'torso', 'pelvis', 'hand_near', 'hand_far', 'foot_near', 'foot_far'):
                self.assertFalse(any(m['name'] == name for m in layout['joint_meshes']))
            self.assertEqual([f['name'] for f in layout['features']], ['violet_crack'] if view == 'front' else [])
            self.assertEqual(layout['held_items'], {})
            self.assertNotIn('cloth', layout['joints'])

    def test_real_bone_idle_direction_knees_and_supports(self):
        for view, layout in self.layouts.items():
            self.assertEqual(bone_errors(layout, self.data, self.samples, self.bound), [])
            report = directions(layout, self.data, self.samples, self.bound, require_presented=True)
            self.assertEqual(report['errors'], [])
            self.assertTrue(all(report['clip_positive_checks'][clip] for clip in ('bolt', 'mirror')))
            knees = rr20.knee_report(layout, self.data, self.samples)
            self.assertEqual(knees['errors'], [])
            self.assertEqual(len(knees['swings']), 6)
            self.assertGreaterEqual(knees['minimum_peak_bend_deg'], 15)
            support = rr20.supports(layout, self.data, self.samples)
            self.assertEqual(support['errors'], [])
            self.assertTrue(support['overreach'])  # protected 1px death preload, never hidden

    def test_dense_reach_reports_overreach_without_failing(self):
        for view, layout in self.layouts.items():
            report = reach(layout, self.data, step_distance_px=self.samples['step_distance_px'], screen_pixel_scale=self.samples['screen_pixel_scale'])
            self.assertEqual(report['errors'], [])
            self.assertEqual(len(report['paths']), 14)
            self.assertEqual(report['dense_intervals'], 1000)
            self.assertTrue(report['overreach'])
            self.assertTrue(all(p['samples'] >= 1001 for p in report['paths']))

    @rr20_inventory_context(rr20)
    def test_director_residue_cleanup_preserves_sources_and_resolves_placeholder(self):
        self.assertEqual(read_json(CASE/'inputs.json')['design_placeholders'], DESIGN_PLACEHOLDERS)
        self.assertNotIn('TODO_DESIGN_rear_green_texel', DESIGN_PLACEHOLDERS)
        for view in VIEWS:
            painting = Image.open(ROOT/f'spec/art_identity/jobs/hollow_mimic/mq9_{view}/processed.png').convert('RGBA')
            self.assertEqual(rr20.green_pixels(painting), 1 if view == 'rear' else 2)
            rest = Image.open(CASE/self.layouts[view]['rest_source']).convert('RGBA')
            self.assertEqual(rr20.green_pixels(rest), 0)
            self.assertTrue(np.array_equal(np.asarray(rest)[...,3], np.asarray(painting)[...,3]))
            changed = np.any(np.asarray(rest) != np.asarray(painting), axis=-1)
            self.assertEqual(int(changed.sum()), 1 if view == 'rear' else 2)
            from residue import residue_mask
            self.assertTrue(np.array_equal(changed, residue_mask(painting)))
            self.assertEqual((CASE/f'source/{view}/processed.png').read_bytes(),
                             (ROOT/f'spec/art_identity/jobs/hollow_mimic/mq9_{view}/processed.png').read_bytes())
        self.assertEqual(Image.open(ROOT/'spec/art_identity/jobs/hollow_mimic/mq9_rear/processed.png').getpixel((125,54)), (0,26,7,255))
        report = rr20.headless(self.samples)
        self.assertTrue(report['ok'], report['errors'])
        self.assertEqual(report['errors'], [])

    def test_missing_pose_and_changed_idle_basis_mutations_fail(self):
        mutant = copy.deepcopy(self.samples)
        mutant['samples'] = [s for s in mutant['samples'] if s['clip'] != 'mirror']
        self.assertTrue(any('inventory' in e for e in bone_errors(self.layouts['front'], self.data, mutant, self.bound)))
        mutant = copy.deepcopy(self.samples)
        row = next(s for s in mutant['samples'] if s['view'] == 'front' and s['clip'] == 'idle' and s['kind'] == 'presented')
        row['bones']['head']['global'][0] += 1
        self.assertTrue(any('idle rotation/scale' in e for e in bone_errors(self.layouts['front'], self.data, mutant, self.bound)))

    def test_direction_coverage_and_knee_policy_mutations_fail(self):
        data = copy.deepcopy(self.data)
        for track in data['view_tracks']['front']['bolt']:
            if track['channel'] == 'forward_px' and track['bone'].startswith('hand_'):
                for key in track['keys']: key['value'] = 0
        report = directions(self.layouts['front'], data, self.samples, self.bound, require_presented=True)
        self.assertTrue(any('bolt' in e for e in report['errors']))
        layout = copy.deepcopy(self.layouts['front'])
        layout['anatomy'] = copy.deepcopy(for_layout(layout))
        layout['anatomy']['legs']['near'].pop('front')
        # This maquette's near leg is within the spec's straight threshold.
        with self.assertRaisesRegex(ValueError, 'required for straight'):
            leg_bend_side(layout, layout['anatomy'], 'near', 'front')

    def test_reversed_swing_and_sliding_support_mutations_fail(self):
        mutant = copy.deepcopy(self.samples)
        row = next(s for s in mutant['samples'] if s['view'] == 'front' and s['clip'] == 'move' and s['kind'] == 'presented' and .03 < s['phase'] < .06)
        a, b, c = [np.array(row['bones'][n+'_near']['global'][4:]) for n in ('thigh','shin','foot')]
        axis = (c-a) / np.linalg.norm(c-a)
        row['bones']['shin_near']['global'][4:] = (a + 2*axis*np.dot(b-a,axis) - (b-a)).tolist()
        self.assertTrue(rr20.knee_report(self.layouts['front'], self.data, mutant)['errors'])
        mutant = copy.deepcopy(self.samples)
        row = next(s for s in mutant['samples'] if s['view'] == 'front' and s['clip'] == 'block' and s['kind'] == 'presented')
        row['bones']['foot_near']['global'][4] += MUTATION_OFFSET_PX
        self.assertTrue(rr20.supports(self.layouts['front'], self.data, mutant)['errors'])

    def test_native_pixel_guards_reject_idle_noise_and_unowned_paint(self):
        rest = np.zeros((FIXTURE_SIZE_PX,FIXTURE_SIZE_PX,4), dtype=np.uint8)
        rest[2:6,2:6] = [50,40,60,255]
        self.assertEqual(idle_pixel_errors(rest, rest.copy(), [0,0]), 0)
        mutant = rest.copy(); mutant[3,3,0] += 1
        self.assertEqual(idle_pixel_errors(rest, mutant, [0,0]), 1)
        checks = np.zeros_like(rest); checks[2:6,2:6] = [255,0,0,255]
        self.assertEqual(clean_metrics([({'z_index':0},rest,checks)])['outside_pixels'], 0)
        mutant = rest.copy(); mutant[0,0] = [50,40,60,255]
        self.assertGreater(clean_metrics([({'z_index':0},mutant,checks)])['outside_pixels'], 0)
        mutant = rest.copy(); mutant[3,3] = [0,255,0,255]
        self.assertEqual(rr20.green_pixels(mutant), 1)

    def test_density_sources_are_exact_and_native_certification_is_pending(self):
        import process_board_density as density
        entry = next(e for e in density.load_registry()['entries'] if e['id']=='hollow_mimic_cutout')
        manifest = read_json(density.MANIFEST)
        self.assertEqual(density.paint_errors([entry], manifest), [])
        # Native certification is director-owned. This assertion remains valid
        # after the director completes the density stage at merge.
        self.assertEqual(density.rest_errors([entry], manifest),
                         read_json(ASSETS/'integration.json')['density']['native_rest_pending'])
        for view, layout in self.layouts.items():
            prod = read_json(ASSETS/(view+'.json'))
            for source, target in zip(layout['parts'], prod['parts']):
                self.assertEqual((CASE/source['file']).read_bytes(), (density.SOURCES/ASSETS.relative_to(ROOT)/target['file']).read_bytes())
        self.assertFalse(read_json(ASSETS/'integration.json')['ready'])

    def test_registry_patch_retains_unrelated_duplicate_keys_byte_for_byte(self):
        from density import replace_owned_entries
        fixture = '{"entries": [\n    {"path":"other", "legacy":1, "legacy":2}\n  ], "version":1}\n'
        record = {'path':'assets/units/hollow_mimic_cutout/front/rest.png', 'id':'hollow_mimic'}
        patched = replace_owned_entries(fixture, [record])
        self.assertIn('{"path":"other", "legacy":1, "legacy":2}', patched)
        self.assertEqual(replace_owned_entries(patched, [record]), patched)

    def test_runtime_checks(self):
        result = subprocess.run([sys.executable,'tools/godot_task_runner.py','--task-id','rr-20','--stream','--',
            'godot','--headless','--path','.','--script','tests/rr20/runtime_checks.gd'],cwd=ROOT,capture_output=True,text=True,timeout=PROOF_TIMEOUT_SECONDS)
        self.assertEqual(result.returncode,0,result.stdout+result.stderr)
        self.assertIn('RR20 RUNTIME: PASS', result.stdout)


if __name__ == '__main__': unittest.main()
