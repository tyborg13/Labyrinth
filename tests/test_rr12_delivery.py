"""rr-12 input provenance and feature policy; no native-renderer claims."""
from pathlib import Path
import shutil
import sys
import tempfile
import unittest
import copy
from unittest.mock import patch

import numpy as np
from PIL import Image

PROJECT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(PROJECT / 'experiments/cutouts/burrow_grub'))
import rr12_inputs as inputs
import rr12_prepare as prepare
from maquette_motion.features import declarations
from rr12_contract import expected
from rr12_gates import motion_errors
from rr12_build import RUNTIME_PATHS
from maquette_motion import compiler, gates
from rr12_geometry import projection_for


class DeliveryTests(unittest.TestCase):
    def test_both_committed_deliveries_have_every_label_and_joint(self):
        for creature, count in (('burrow_grub', 33), ('ember_tick', 41)):
            with self.subTest(creature=creature):
                report = inputs.audit(creature)
                self.assertTrue(report['ok'])
                self.assertEqual(len(report['files']), count)
                self.assertEqual(report['missing'], [])
                self.assertEqual(report['blender_invocations'], 0)

    def altered_delivery(self, mutation):
        with tempfile.TemporaryDirectory(prefix='rr12-delivery-') as temporary:
            root = Path(temporary) / 'burrow_grub'
            source = inputs.delivery_for('burrow_grub')
            shutil.copytree(source, root / 'delivery')
            shutil.copyfile(source.parent / 'measurements.json', root / 'measurements.json')
            mutation(root / 'delivery')
            with patch.object(inputs, 'delivery_for', return_value=root / 'delivery'):
                inputs.audit('burrow_grub')

    def test_missing_solo_is_rejected(self):
        with self.assertRaisesRegex(inputs.CutoutError, 'Missing committed rig input'):
            self.altered_delivery(lambda folder: (folder / 'rear_solo_leg_far_1.png').unlink())

    def test_changed_solo_is_rejected(self):
        def mutate(folder):
            path = folder / 'front_solo_head.png'
            image = Image.open(path).convert('RGBA')
            image.putpixel((0, 0), (255, 0, 255, 255))
            image.save(path)
        with self.assertRaisesRegex(inputs.CutoutError, 'Committed capture hash differs'):
            self.altered_delivery(mutate)

    def test_joint_mutation_is_rejected_after_refreshing_checksum(self):
        def mutate(folder):
            path = folder / 'joints_px.json'
            data = inputs.read_json(path)
            data['front']['leg_near_1_base'][0] += 1
            inputs.write_json(path, data)
            manifest_path = folder / 'capture_manifest.json'
            manifest = inputs.read_json(manifest_path)
            manifest['joints_sha256'] = inputs.digest(path)
            inputs.write_json(manifest_path, manifest)
        with self.assertRaisesRegex(inputs.CutoutError, 'Compiled camera differs'):
            self.altered_delivery(mutate)

    def test_missing_raw_never_accepts_an_unbound_image(self):
        with tempfile.TemporaryDirectory(prefix='rr12-raw-') as temporary:
            job = Path(temporary) / 'mq5_front'
            job.mkdir()
            Image.new('RGB', (1024, 1024), 'green').save(job / 'similar.png')
            inputs.write_json(job / 'processed.json', {'raw_sha256': '0' * 64})
            with patch.object(inputs, 'job_for', return_value=job):
                with self.assertRaisesRegex(inputs.CutoutError, 'Missing approved registration raw'):
                    inputs.raw_source_path('burrow_grub', 'front')

    def test_raw_step_replay_matches_approved_pixels(self):
        record = inputs.read_json(inputs.job_for('burrow_grub', 'front') / 'processed.json')
        image = inputs.raw_image('burrow_grub', 'front')
        self.assertEqual(inputs.pixel_digest(image), record['raw_pixel_sha256'])

    def test_protected_director_copies_remain_byte_identical(self):
        for creature in inputs.CREATURES:
            path = prepare.case_for(creature) / 'director_motion.json'
            self.assertEqual(path.read_bytes(), inputs.DIRECTOR.read_bytes())

    def test_features_preserve_opaque_source_and_fill_holes(self):
        for creature in inputs.CREATURES:
            case = prepare.case_for(creature)
            for view in inputs.VIEWS:
                source = case / f'source/{view}/processed.png'
                self.assertEqual(source.read_bytes(), (inputs.job_for(creature, view) / 'processed.png').read_bytes())
                paint = np.asarray(Image.open(source).convert('RGBA'))
                for feature in declarations(case, view):
                    mask = feature['pixels']
                    self.assertEqual(feature['owner'], 'head' if creature == 'burrow_grub' else 'shell')
                    if not mask.any():
                        self.assertTrue(feature['occluded_reason'])
                    else:
                        self.assertTrue(np.array_equal(prepare.filled(mask) & (paint[..., 3] > 0), mask))
                        from maquette_motion.silhouette import components
                        self.assertEqual(len(components(mask)[1]), 1)
                selection = next(iter(prepare.SELECTIONS[creature].values()))
                regenerated, seed = prepare.feature_mask(paint, selection, view)
                masks = [f['pixels'] for f in declarations(case, view)]
                self.assertTrue(np.array_equal(np.logical_or.reduce(masks), regenerated))



    def test_director_hierarchy_and_every_signed_key_match_independent_oracle(self):
        for creature in inputs.CREATURES:
            case = prepare.case_for(creature)
            self.assertEqual(inputs.read_json(case / 'compiled_motion.json'), expected(case))
            recipe = inputs.read_json(case / 'rig_recipe.json')
            self.assertEqual(recipe['director_decisions']['authority'], 'rr-12 brief, committed mq-05 anatomy')
            self.assertEqual(recipe['design_placeholders'], {})

    def test_every_authored_key_midpoint_and_contact_reaches_real_bones(self):
        for creature in inputs.CREATURES:
            case = prepare.case_for(creature)
            self.assertEqual(motion_errors(case, case / 'proof/motion_samples.json'), [])

    def test_wrong_compiler_sign_is_rejected_by_independent_oracle(self):
        for creature in inputs.CREATURES:
            case = prepare.case_for(creature)
            def broken(spec, points, mapping, view):
                data = projection_for(case, spec, points, mapping, view)
                data['parts']['head']['lean_deg'] *= -1
                return data
            with patch.object(compiler, 'projection', broken):
                mutated = compiler.compile_creature(inputs.DIRECTOR, creature,
                    inputs.read_json(case / 'source/spec.json'), inputs.read_json(case / 'rig_recipe.json'))
            self.assertNotEqual(mutated, expected(case))
            self.assertNotEqual(mutated['view_tracks'], expected(case)['view_tracks'])

    def test_changed_actual_bone_and_missing_contact_sample_fail(self):
        case = prepare.case_for('burrow_grub')
        original = inputs.read_json(case / 'proof/motion_samples.json')
        mutations = [copy.deepcopy(original), copy.deepcopy(original)]
        mutations[0]['samples'][0]['bones']['head']['global'][4] += 1
        mutations[1]['samples'] = [r for r in original['samples']
            if not (r['view'] == 'front' and r['clip'] == 'gnaw' and abs(r['phase'] - .5) < 1e-8)]
        with tempfile.TemporaryDirectory(prefix='rr12-motion-') as folder:
            for index, mutated in enumerate(mutations):
                path = Path(folder) / f'mutation_{index}.json'
                inputs.write_json(path, mutated)
                errors = motion_errors(case, path)
                self.assertTrue(errors)
                self.assertTrue(any(('applied bone global' if index == 0 else 'missing/duplicate') in e for e in errors))

    def test_extra_runtime_sources_are_bound_in_python_and_godot(self):
        for creature in inputs.CREATURES:
            case = prepare.case_for(creature)
            bindings = gates.input_bindings(case)
            for path in RUNTIME_PATHS:
                self.assertEqual(bindings['runtime:' + path], inputs.digest(inputs.PROJECT / path))

    def test_transparent_feature_mutation_is_rejected(self):
        original = prepare.case_for('ember_tick')
        with tempfile.TemporaryDirectory(prefix='rr12-feature-') as temporary:
            case = Path(temporary)
            shutil.copytree(original / 'source', case / 'source')
            shutil.copytree(original / 'features', case / 'features')
            shutil.copyfile(original / 'features.json', case / 'features.json')
            path = case / 'features/front_ember_crack_front_01.png'
            image = Image.open(path).convert('L')
            image.putpixel((0, 0), 255)
            image.save(path)
            with self.assertRaisesRegex(inputs.CutoutError, 'transparent paint'):
                declarations(case, 'front')

if __name__ == '__main__':
    unittest.main()
