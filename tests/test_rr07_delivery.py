"""rr-07 input provenance and feature policy; no native-renderer claims."""
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
sys.path.insert(0, str(PROJECT / 'experiments/cutouts/hoarfrost_seer'))
import rr07_inputs as inputs
import rr07_prepare as prepare
from maquette_motion.features import declarations
from rr07_contract import expected
from rr07_gates import motion_errors
from rr07_build import RUNTIME_PATHS
from maquette_motion import compiler, gates
from rr07_geometry import projection_for


class DeliveryTests(unittest.TestCase):
    def test_both_committed_deliveries_have_every_label_and_joint(self):
        # mq-07 removes hand_near and club: four fewer per-view solo files.
        for creature, count in (('hoarfrost_seer', 35), ('arc_thrall', 35)):
            with self.subTest(creature=creature):
                report = inputs.audit(creature)
                self.assertTrue(report['ok'])
                self.assertEqual(len(report['files']), count)
                self.assertEqual(report['missing'], [])
                self.assertEqual(report['blender_invocations'], 0)

    def altered_delivery(self, mutation):
        with tempfile.TemporaryDirectory(prefix='rr07-delivery-') as temporary:
            root = Path(temporary) / 'hoarfrost_seer'
            source = inputs.delivery_for('hoarfrost_seer')
            shutil.copytree(source, root / 'delivery')
            shutil.copyfile(source.parent / 'measurements.json', root / 'measurements.json')
            mutation(root / 'delivery')
            with patch.object(inputs, 'delivery_for', return_value=root / 'delivery'):
                inputs.audit('hoarfrost_seer')

    def test_missing_solo_is_rejected(self):
        with self.assertRaisesRegex(inputs.CutoutError, 'Missing committed rig input'):
            self.altered_delivery(lambda folder: (folder / 'rear_solo_hand_far.png').unlink())

    def test_changed_solo_is_rejected(self):
        def mutate(folder):
            path = folder / 'front_solo_staff_crystal.png'
            image = Image.open(path).convert('RGBA')
            image.putpixel((0, 0), (255, 0, 255, 255))
            image.save(path)
        with self.assertRaisesRegex(inputs.CutoutError, 'Committed capture hash differs'):
            self.altered_delivery(mutate)

    def test_joint_mutation_is_rejected_after_refreshing_checksum(self):
        def mutate(folder):
            path = folder / 'joints_px.json'
            data = inputs.read_json(path)
            data['front']['hand_far'][0] += 1
            inputs.write_json(path, data)
            manifest_path = folder / 'capture_manifest.json'
            manifest = inputs.read_json(manifest_path)
            manifest['joints_sha256'] = inputs.digest(path)
            inputs.write_json(manifest_path, manifest)
        with self.assertRaisesRegex(inputs.CutoutError, 'Compiled camera differs'):
            self.altered_delivery(mutate)

    def test_missing_raw_never_accepts_an_unbound_image(self):
        with tempfile.TemporaryDirectory(prefix='rr07-raw-') as temporary:
            job = Path(temporary) / 'mq5_front'
            job.mkdir()
            Image.new('RGB', (1024, 1024), 'green').save(job / 'similar.png')
            inputs.write_json(job / 'processed.json', {'raw_sha256': '0' * 64})
            with patch.object(inputs, 'job_for', return_value=job):
                with self.assertRaisesRegex(inputs.CutoutError, 'Missing approved registration raw'):
                    inputs.raw_source_path('hoarfrost_seer', 'front')

    def test_raw_step_replay_matches_approved_pixels(self):
        record = inputs.read_json(inputs.job_for('arc_thrall', 'front') / 'processed.json')
        image = inputs.raw_image('arc_thrall', 'front')
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
                    expected_owner = ('staff_crystal' if creature == 'hoarfrost_seer' else
                                      'collar' if feature['name'] == 'chain_stub' else 'club')
                    self.assertEqual(feature['owner'], expected_owner)
                    if view == 'rear' and feature['name'] == 'chain_stub':
                        self.assertFalse(mask.any())
                        self.assertTrue(feature['occluded_reason'])
                    else:
                        self.assertTrue(mask.any())
                        self.assertTrue(np.array_equal(prepare.filled(mask) & (paint[..., 3] > 0), mask))
                        selection = prepare.SELECTIONS[creature][feature['name']]
                        regenerated, seed = prepare.feature_mask(paint, selection, view)
                        self.assertTrue(np.array_equal(mask, regenerated))
                        self.assertTrue(np.all(mask[seed]))


    def test_director_hierarchy_and_every_signed_key_match_independent_oracle(self):
        for creature in inputs.CREATURES:
            case = prepare.case_for(creature)
            self.assertEqual(inputs.read_json(case / 'compiled_motion.json'), expected(case))
            recipe = inputs.read_json(case / 'rig_recipe.json')
            self.assertEqual(recipe['director_decisions']['authority'], 'Director rr-07 feedback 1')
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
                data['parts']['torso']['lean_deg'] *= -1
                return data
            with patch.object(compiler, 'projection', broken):
                mutated = compiler.compile_creature(inputs.DIRECTOR, creature,
                    inputs.read_json(case / 'source/spec.json'), inputs.read_json(case / 'rig_recipe.json'))
            self.assertNotEqual(mutated, expected(case))
            self.assertNotEqual(mutated['view_tracks'], expected(case)['view_tracks'])

    def test_changed_actual_bone_and_missing_contact_sample_fail(self):
        case = prepare.case_for('hoarfrost_seer')
        original = inputs.read_json(case / 'proof/motion_samples.json')
        mutations = [copy.deepcopy(original), copy.deepcopy(original)]
        mutations[0]['samples'][0]['bones']['torso']['global'][4] += 1
        mutations[1]['samples'] = [r for r in original['samples']
            if not (r['view'] == 'front' and r['clip'] == 'mark' and abs(r['phase'] - .72) < 1e-8)]
        with tempfile.TemporaryDirectory(prefix='rr07-motion-') as folder:
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
        original = prepare.case_for('arc_thrall')
        with tempfile.TemporaryDirectory(prefix='rr07-feature-') as temporary:
            case = Path(temporary)
            shutil.copytree(original / 'source', case / 'source')
            shutil.copytree(original / 'features', case / 'features')
            shutil.copyfile(original / 'features.json', case / 'features.json')
            path = case / 'features/front_spark_upper.png'
            image = Image.open(path).convert('L')
            image.putpixel((0, 0), 255)
            image.save(path)
            with self.assertRaisesRegex(inputs.CutoutError, 'transparent paint'):
                declarations(case, 'front')

if __name__ == '__main__':
    unittest.main()
