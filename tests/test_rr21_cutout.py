"""rr-21 implementation contracts and negative controls; no window server."""
import copy
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
sys.path[:0] = [str(ROOT / 'tools'), str(ROOT / 'experiments/cutouts/briar_weaver'),
                str(ROOT / 'experiments/cutouts/arc_thrall')]
from rr21_case import CASE, ASSETS, DIRECTOR, PIECES
from rr21_density import scoped_identity
from rr21_residue import residue, clean_piece, feature_mask, feature_definitions, outside_count, source_report, presented_feature_mask
from cutout_pipeline.cases import read_json, digest
from humanoid_cutout.compiler import compile_motion
from humanoid_cutout.gates import structure_errors, source_errors, bone_errors, bindings, idle_pixel_errors, clean_metrics
from humanoid_cutout.action_direction import report as direction_report
from humanoid_cutout.reach import report as reach_report
from humanoid_cutout.production_gates import production_errors
from humanoid_cutout.walk_gates import report as walk_report
from humanoid_cutout.bone_evidence import read_report
from rr21_evidence import compact_samples, FULL_SAMPLES

PROOF_TIMEOUT_SECONDS = 180
FIXTURE_TRANSLATION_PX = 1
FIXTURE_OVERREACH_PX = 1000
FIXTURE_STEP_PX = 96
FIXTURE_SCREEN_SCALE = 2
FIXTURE_RGBA_SIZE = (8, 8)
FIXTURE_PAINT_RGBA = (80, 60, 40, 255)
PRESERVED_FAMILIES = ('hoarfrost_seer', 'arc_thrall', 'glacial_mirror', 'storm_capacitor')


def run_script(script, *args):
    command = [sys.executable, 'tools/godot_task_runner.py', '--task-id', 'rr-21', '--stream', '--',
               'godot', '--headless', '--path', '.', '--script', script]
    if args: command += ['--', *map(str, args)]
    result = subprocess.run(command, cwd=ROOT, capture_output=True, text=True, timeout=PROOF_TIMEOUT_SECONDS)
    if result.returncode: raise AssertionError(result.stdout + result.stderr)
    return result.stdout


class CutoutTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.layouts = {v: read_json(CASE / f'layouts/{v}.json') for v in ('front', 'rear')}
        cls.data = read_json(CASE / 'compiled_motion.json')
        cls.build = read_json(CASE / 'proof/build.json')
        run_script('tests/rr21/samples.gd', '--case', CASE, '--output', FULL_SAMPLES)
        compact_samples()
        cls.samples = read_report(CASE)
        cls.bound = bindings(CASE)

    def test_protected_import_compilation_and_native_delivery(self):
        self.assertEqual((CASE / 'director_motion.json').read_bytes(), DIRECTOR.read_bytes())
        self.assertEqual((ASSETS / 'humanoid_v2/director_motion.json').read_bytes(), DIRECTOR.read_bytes())
        self.assertEqual(compile_motion(DIRECTOR, 'briar_weaver', self.layouts, self.data['projection']), self.data)
        for view, report in self.build['views'].items():
            for file, expected in report['delivery'].items():
                self.assertEqual(digest(ROOT / 'spec/art_identity/maquettes/briar_weaver/delivery' / file), expected)
            self.assertEqual(report['rest_mismatch_pixels'], 0)

    def test_source_cut_and_five_meshes_both_views(self):
        for layout in self.layouts.values():
            self.assertEqual(structure_errors(layout, self.build), [])
            self.assertEqual(source_errors(CASE, layout, self.build), [])
            self.assertEqual({m['name'] for m in layout['joint_meshes'] if not m['hidden_material']},
                             {'arm_near', 'arm_far', 'leg_near', 'leg_far', 'tatters'})
            self.assertEqual(layout['source_labels'], PIECES)
            self.assertEqual(layout['joints']['tatters_mid']['parent'], 'pelvis')
            self.assertEqual(layout['joints']['tatters_tip']['parent'], 'tatters_mid')
            self.assertEqual(layout['idle_groups']['weapon_arm'], [])
            self.assertEqual(set(layout['idle_groups']['upper_body']),
                             {'torso', 'head', 'arm_near', 'hand_near', 'arm_far', 'hand_far'})

    def test_real_bone_signed_motion_and_rigid_idle(self):
        for layout in self.layouts.values():
            self.assertEqual(bone_errors(layout, self.data, self.samples, self.bound), [])
            report = direction_report(layout, self.data, self.samples, self.bound, require_presented=True)
            self.assertEqual(report['errors'], [])
            for clip in ('lash', 'thornwall'): self.assertGreater(report['clip_positive_checks'][clip], 0)

    def test_director_walk_passes_shared_gates_without_runtime_tuning(self):
        author = read_json(DIRECTOR)['briar_weaver']['clips']['move']
        self.assertEqual(author['seconds'], .9)
        gait = author['gait']
        self.assertEqual(gait['steps_per_tile'], 6)
        self.assertEqual(gait['lift_px'], 7)
        self.assertEqual(gait['settle_px']['down'], 2.5)
        for layout in self.layouts.values():
            self.assertNotIn('leg_roles', layout)
            self.assertEqual(layout['planted_bones'], ['foot_near', 'foot_far'])
            report = walk_report(layout, self.data, self.samples)
            self.assertEqual(len(report['swings']), 6)
            self.assertEqual(report['errors'], [])
            self.assertEqual(report['maximum_stance_frame_change_px'], 0)
        self.assertNotIn('leg_roles', read_json(CASE / 'anatomy.json'))
        self.assertEqual(read_json(CASE / 'inputs.json')['design_placeholders'], {})

    def test_reach_reports_1000_intervals_and_no_hidden_clamp(self):
        for layout in self.layouts.values():
            report = reach_report(layout, self.data, step_distance_px=self.samples['step_distance_px'], screen_pixel_scale=self.samples['screen_pixel_scale'])
            self.assertEqual(report['dense_intervals'], 1000)
            self.assertEqual(len(report['paths']), 14)
            self.assertEqual(report['errors'], [])

    def test_declared_eye_is_preserved_and_all_derived_surfaces_are_clean(self):
        mask = feature_mask(CASE, 'front', 'head')
        self.assertEqual(int(mask.sum()), 23)
        self.assertEqual(len(feature_definitions(CASE, 'rear')), 0)
        self.assertEqual(self.layouts['front']['features'][0]['piece'], 'head')
        for view in ('front', 'rear'):
            image = Image.open(CASE / f'source/{view}/processed.png').convert('RGBA')
            self.assertEqual(outside_count(image, feature_mask(CASE, view)), 0)
            self.assertEqual((CASE / f'source/{view}/processed.png').read_bytes(),
                (ROOT / f'spec/art_identity/jobs/briar_weaver/mq9_{view}/processed.png').read_bytes())
        self.assertEqual(source_report(CASE, ASSETS)['errors'], [])
        self.assertEqual(read_json(CASE / 'inputs.json')['design_placeholders'], {})

    def test_production_data_and_density_closure(self):
        policy = read_json(ASSETS / 'integration.json')
        self.assertEqual(policy['rig_directory'], 'humanoid_v2')
        self.assertEqual(policy['idle_phase_seed'], 'slot')
        self.assertEqual(policy['death_timing']['clip_seconds'], 1.5)
        self.assertEqual(policy['action_aliases'], {'heal': 'heal_ally'})
        registry = read_json(ROOT / 'spec/assets/board_pixel_density/registry.json')
        entry = next(e for e in registry['entries'] if e['id'] == 'briar_weaver_cutout')
        self.assertEqual(set(entry['facings']), {'front', 'rear'})
        for relative in entry['paths']:
            self.assertTrue((ROOT / relative).is_file())
            self.assertTrue((ROOT / 'spec/assets/board_pixel_density/sources' / relative).is_file())
        for view in self.layouts:
            layout = read_json(ASSETS / f'humanoid_v2/{view}.json')
            self.assertEqual(layout['rig'], 'humanoid_v2')
            for part in layout['parts'] + layout['joint_meshes']:
                self.assertNotIn('experiments/', part['file'])
                self.assertTrue((ASSETS / 'humanoid_v2' / part['file']).is_file())

    def test_prior_creature_assets_and_case_data_are_byte_identical(self):
        folders = [f'{base}/{name}{suffix}' for name in PRESERVED_FAMILIES for base, suffix in
                   [('assets/units', '_cutout'), ('experiments/cutouts', '')]]
        changed = subprocess.check_output(['git', 'diff', '--name-only', 'HEAD', '--', *folders], cwd=ROOT, text=True)
        self.assertEqual(changed, '')

    def test_scoped_identity_preserves_even_duplicate_baseline_keys(self):
        original = '{"entries":[{"path":"prior","id":"old","id":"current"}],"version":1}'
        record = {'path': 'assets/units/briar_weaver_cutout/front/rest.png', 'id': 'briar_weaver'}
        updated = scoped_identity(original, [record])
        self.assertIn('{"path":"prior","id":"old","id":"current"}', updated)
        self.assertEqual(json.loads(updated)['entries'][-1], record)
        self.assertEqual(scoped_identity(updated, [record]), updated)

    def test_mutations_catch_idle_rotation_and_missing_inventory(self):
        for mode in ('rotation', 'missing'):
            mutant = copy.deepcopy(self.samples)
            if mode == 'rotation':
                row = next(r for r in mutant['samples'] if r['clip'] == 'idle' and r['view'] == 'front')
                row['bones']['head']['global'][0] += FIXTURE_TRANSLATION_PX
            else: mutant['samples'].pop()
            self.assertTrue(bone_errors(self.layouts['front'], self.data, mutant, self.bound))

    def test_mutation_reverses_a_real_positive_action_target(self):
        layout = self.layouts['front']
        report = direction_report(layout, self.data, self.samples, self.bound, require_presented=True)
        reference = next(r for r in report['rows'] if r['clip'] == 'lash' and r['kind'] == 'authored' and r['phase'] == .45 and r['target'] == 'hand_near')
        mutant = copy.deepcopy(self.samples)
        row = next(r for r in mutant['samples'] if r['view'] == 'front' and r['clip'] == 'lash' and r['kind'] == 'authored' and r['phase'] == .45)
        reverse = np.asarray(reference['neutral_solved_tip']) - np.asarray(reference['forward']) * FIXTURE_TRANSLATION_PX
        row['direction_bones']['hand_near']['global'][4:] = reverse.tolist()
        errors = direction_report(layout, self.data, mutant, self.bound, require_presented=True)['errors']
        self.assertTrue(any('forward direction reversed' in e for e in errors))

    def test_mutations_catch_wrong_knee_policy_and_mesh_weights(self):
        for field in ('knee', 'mesh'):
            mutant = copy.deepcopy(self.layouts['rear'])
            if field == 'knee':
                mutant['anatomy'] = read_json(CASE / 'anatomy.json')
                mutant['anatomy']['legs']['far']['rear']['bend_side'] = 1
            else: mutant['joint_meshes'][0]['weights']['pelvis'][0] += FIXTURE_TRANSLATION_PX
            self.assertTrue(structure_errors(mutant, self.build))

    def test_mutations_catch_stale_direction_and_overreach(self):
        mutant = copy.deepcopy(self.samples); mutant['inputs'] = {}
        self.assertTrue(direction_report(self.layouts['front'], self.data, mutant, self.bound)['errors'])
        data = copy.deepcopy(self.data)
        track = next(t for t in data['view_tracks']['front']['lash'] if t['source'] == 'hand_near.forward_px')
        for key in track['keys']: key['value'] += FIXTURE_OVERREACH_PX # Diagnostic impossible target, not live tuning.
        self.assertTrue(reach_report(self.layouts['front'], data, step_distance_px=FIXTURE_STEP_PX, screen_pixel_scale=FIXTURE_SCREEN_SCALE)['overreach'])

    def test_pixel_mutations_reject_idle_mismatch_and_stray_pixel(self):
        rest = np.zeros((*FIXTURE_RGBA_SIZE, 4), dtype=np.uint8)
        rest[2:6, 2:6] = FIXTURE_PAINT_RGBA
        frame = rest.copy(); frame[3, 3, 0] += 1
        self.assertTrue(idle_pixel_errors(rest, frame, [0, 0]))
        frame = rest.copy(); frame[0, 0] = FIXTURE_PAINT_RGBA
        checks = np.zeros_like(frame); checks[rest[..., 3] > 0] = [255, 0, 0, 255]
        self.assertGreater(clean_metrics([({'z_index': 0}, frame, checks)])['outside_pixels'], 0)

    def test_runtime_and_native_probe_load_headlessly(self):
        self.assertIn('RR21 RUNTIME: PASS', run_script('tests/rr21/runtime_checks.gd'))
        self.assertIn('RR21 NATIVE PROBE LOAD: PASS', run_script('tests/rr21/native_capture.gd', '--case', CASE,
            '--output', CASE / 'proof/logs/native_validate', '--validate-only'))


if __name__ == '__main__': unittest.main()
