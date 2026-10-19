"""Slag Mortar implementation contracts and independent failure mutations."""
import copy
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

from PIL import Image

PROJECT = Path(__file__).resolve().parents[1]
sys.path[:0] = [str(PROJECT / 'tools'), str(PROJECT / 'experiments/cutouts/slag_mortar')]
from rr22_case import CASE, ASSETS, DIRECTOR, PIECES
from rr22_gates import support_report, lob_report
from rr22_surfaces import residue_mask, clean_residue, resolve, connect_covered, rear_fist
from rr22_residue_gate import count as residue_pixels, frame_errors as residue_frame_errors, native_errors as residue_native_errors
from rr22_surface_gates import errors as surface_errors, connectivity_errors
from humanoid_cutout.gait_continuations import errors as continuation_errors, texture as continuation_texture
import numpy as np
from humanoid_cutout.gates import structure_errors, source_errors, bone_errors, bindings
from humanoid_cutout.action_direction import report as direction_report
from humanoid_cutout.reach import report as reach_report
from humanoid_cutout.compiler import compile_motion
from cutout_pipeline.cases import read_json
from humanoid_cutout.walk_gates import report as knee_report

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
            self.assertNotIn('leg_roles', self.data)
            self.assertEqual(len(knee_report(layout, self.data, self.samples)['swings']), 6)
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

    def test_director_residue_band_boundaries_and_olive(self):
        rgba = np.array([[[100, 149, 100, 255], [100, 150, 100, 255],
                          [0, 11, 0, 255], [0, 12, 0, 255],
                          [14, 22, 5, 255], [0, 255, 0, 0]]], dtype=np.uint8)
        self.assertEqual(residue_mask(rgba).tolist(), [[False, True, False, True, False, False]])
        self.assertEqual(residue_pixels(Image.open(CASE / 'source/front/approved.png')), 0)
        self.assertEqual(read_json(CASE / 'cutout.json')['design_placeholders'], {})

    def test_residue_cleanup_uses_same_piece_nearest_donor_and_keeps_alpha(self):
        rgba = np.array([[[40, 20, 10, 255], [0, 255, 0, 255], [0, 255, 0, 128],
                          [70, 60, 50, 255]]], dtype=np.uint8)
        feature = np.array([[False, True, False, False]])
        original = rgba.copy()
        cleaned, amount = clean_residue(rgba, feature)
        self.assertEqual(amount, 1)
        self.assertEqual(cleaned[0, 1].tolist(), rgba[0, 1].tolist())
        self.assertEqual(cleaned[0, 2].tolist(), [70, 60, 50, 128])
        self.assertTrue(np.array_equal(rgba, original))
        self.assertTrue(np.array_equal(cleaned[..., 3], rgba[..., 3]))
        self.assertEqual(residue_pixels(Image.fromarray(cleaned), feature), 0)

    def test_presented_residue_outside_feature_is_rejected(self):
        image = Image.new('RGBA', (512, 512))
        image.putpixel((200, 200), (0, 255, 0, 255))
        mask = np.zeros((512, 512), dtype=bool)
        self.assertTrue(residue_frame_errors(image, mask))
        mask[200, 200] = True
        self.assertEqual(residue_frame_errors(image, mask), [])
        image.putpixel((201, 200), (0, 255, 0, 255))
        self.assertTrue(residue_frame_errors(image, mask))

    def test_native_feature_sidecars_require_complete_unchanged_sized_masks(self):
        with tempfile.TemporaryDirectory(prefix='rr22-residue-') as folder:
            capture = Path(folder)
            for view in self.layouts:
                feature = self.layouts[view]['features'][0]['name']
                Image.new('RGBA', (512, 512)).save(capture / 'frame.png')
                manifest = {'frames': [{'view': view, 'clip': 'idle', 'frame': 0, 'file': 'frame.png'}]}
                (capture / 'frames.json').write_text(json.dumps(manifest))
                self.assertIn('incomplete native feature-mask coverage', residue_native_errors(CASE, capture))
                Image.new('RGBA', (512, 512)).save(capture / 'mask.png')
                from cutout_pipeline.cases import digest
                row = {'view': view, 'clip': 'idle', 'frame': 0, 'name': feature,
                       'file': 'mask.png', 'sha256': digest(capture / 'mask.png')}
                manifest['feature_masks'] = [row]
                (capture / 'frames.json').write_text(json.dumps(manifest))
                self.assertEqual(residue_native_errors(CASE, capture), [])
                Image.new('RGBA', (8, 8)).save(capture / 'mask.png')
                self.assertTrue(any('changed/missing' in e for e in residue_native_errors(CASE, capture)))
                row['sha256'] = digest(capture / 'mask.png')
                (capture / 'frames.json').write_text(json.dumps(manifest))
                self.assertTrue(any('dimensions differ' in e for e in residue_native_errors(CASE, capture)))

    def test_ownership_replays_and_logical_pieces_are_connected(self):
        for layout in self.layouts.values():
            self.assertEqual(surface_errors(CASE, layout), [])
        mutant = copy.deepcopy(self.layouts['front'])
        mutant['features'][0]['piece'] = 'torso'
        self.assertTrue(any('feature must belong' in e for e in surface_errors(CASE, mutant)))
        image = np.zeros((7, 7, 4), dtype=np.uint8)
        image[3, 1] = image[3, 5] = [90, 50, 30, 255]
        self.assertTrue(connectivity_errors([image], 'mutation'))
        paint = np.zeros_like(image)
        paint[3, 1:6] = [0, 255, 0, 255]
        hidden, added = connect_covered(image, np.zeros_like(image), paint, 3, None)
        self.assertEqual(int(added.sum()), 3)
        self.assertEqual(connectivity_errors([image, hidden], 'fixture'), [])
        self.assertTrue(np.all(hidden[added] == [90, 50, 30, 255]))

    def test_rear_fist_is_beyond_iron_rim_and_bracer_stays_forearm(self):
        names = ['upper_near', 'fore_near', 'hand_near']
        paint = np.zeros((12, 12, 4), dtype=np.uint8)
        paint[2:10, 3:8] = [110, 60, 30, 255]
        paint[4:6, 3:8] = [80, 80, 80, 255]
        owners = np.full((12, 12), -1)
        owners[2:10, 3:8] = 1
        owners[9, 4] = 2
        joints = {'fore_near': {'position': [5, 3]}, 'hand_near': {'position': [5, 9]}}
        result, report = rear_fist(paint, owners, names, joints)
        self.assertTrue(np.all(result[4:6, 3:8] == 1))
        self.assertTrue(np.all(result[6:10, 3:8] == 2))
        self.assertEqual(report['bracer_pixels'], 10)

    def test_protected_mask_owns_every_inside_texel_and_no_outside_texel(self):
        from maquette_motion.features import source_pixels
        for view, layout in self.layouts.items():
            expected = np.asarray(Image.open(DIRECTOR.parent / f'crucible_mask_{view}.png')) > 0
            part = next(p for p in layout['parts'] if p['name'] == 'mortar')
            self.assertTrue(np.array_equal(source_pixels(CASE, part)[..., 3] > 0, expected))
            self.assertEqual((CASE / f'source/{view}/crucible_mask.png').read_bytes(),
                             (DIRECTOR.parent / f'crucible_mask_{view}.png').read_bytes())

    def test_canon_scale_survives_production_path_registration(self):
        from art_identity_gate import coverage
        metadata = coverage(PROJECT)
        for view in ('front', 'rear'):
            old = 'assets/art/enemies/slag_mortar' + ('_rear' if view == 'rear' else '') + '.png'
            self.assertEqual(metadata[old]['art_scale'], 1.04)
            self.assertEqual(metadata[f'assets/units/slag_mortar_cutout/humanoid_v2/{view}/rest.png']['art_scale'], 1.04)

    def test_action_continuations_copy_own_paint_and_keep_rest_idle_exact(self):
        for view, layout in self.layouts.items():
            self.assertEqual(continuation_errors(CASE, layout), [])
            for name, recipe in layout.get('gait_continuations', {}).items():
                part = next(p for p in layout['parts'] if p['name'] == name)
                original = continuation_texture(CASE, layout, part)
                self.assertTrue(np.array_equal(continuation_texture(CASE, layout, part, clip='idle'), original))
                donor = next(p for p in layout['parts'] if p['name'] == recipe['donor'])
                paint = np.asarray(Image.open(CASE / donor['file']).convert('RGBA'))
                for clip in recipe['clips']:
                    action = continuation_texture(CASE, layout, part, clip=clip)
                    for x, y, u, v in recipe['texels']:
                        self.assertTrue(np.array_equal(action[y, x], paint[v, u]))
                mutant = copy.deepcopy(layout)
                mutant['gait_continuations'][name]['clips'] = ['idle']
                self.assertTrue(any('excluding rest/idle' in e for e in continuation_errors(CASE, mutant)))

    def test_compact_bone_records_preserve_inventory_and_reject_changed_full_data(self):
        import rr22_records
        from humanoid_cutout.bone_evidence import read_report
        from cutout_pipeline.cases import write_json
        with tempfile.TemporaryDirectory(prefix='rr22-summary-') as folder:
            case = Path(folder)
            write_json(case / rr22_records.FULL_SAMPLES, self.samples)
            with patch.object(rr22_records, 'CASE', case): compact = rr22_records.compact_samples()
            self.assertNotIn('samples', compact)
            self.assertNotIn('inputs', compact)
            self.assertEqual(compact['sample_count'], len(self.samples['samples']))
            self.assertEqual(read_report(case), self.samples)
            (case / rr22_records.FULL_SAMPLES).write_text('{}')
            with self.assertRaisesRegex(ValueError, 'evidence changed'): read_report(case)
            write_json(case / 'proof/samples.json', self.samples)
            self.assertEqual(read_report(case), self.samples)

    def test_sparse_cpu_coverage_keeps_exact_pixels_checks_and_hole_transport(self):
        from rr22_cpu import CoveragePose
        from humanoid_cutout.cpu_pose import CpuPose
        for view, clip, frame in [('front', 'death', 31), ('rear', 'lob', 14)]:
            pose = next(r for r in self.samples['samples'] if
                        (r['view'], r['clip'], r['frame'], r['kind']) == (view, clip, frame, 'presented'))
            full = CpuPose(CASE, copy.deepcopy(self.layouts[view]))
            sparse = CoveragePose(CASE, copy.deepcopy(self.layouts[view]))
            original, original_maps = full.layers(pose)
            optimized, optimized_maps = sparse.layers(pose)
            for (_, a, ac), (_, b, bc) in zip(original, optimized):
                self.assertTrue(np.array_equal(a, b))
                self.assertTrue(np.array_equal(ac, bc))
            for field in ('proof_rest_holes', 'proof_joint_seams'):
                a = full.masks(pose, full.layout[field], original_maps)
                b = sparse.masks(pose, sparse.layout[field], optimized_maps)
                self.assertTrue(all(np.array_equal(x, y) for x, y in zip(a, b)))
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
