"""Fresh and resumed maquette regeneration must retain an input-only snapshot."""
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

from spec.art_identity.maquettes.glacial_mirror import regeneration_inputs as inputs
from spec.art_identity.maquettes.glacial_mirror import workflow
from spec.art_identity.maquettes.blender.curate_delivery import sha, write
from spec.art_identity.maquettes.blender.cloth_cache import cache_key
from spec.art_identity.maquettes.blender.facing import board_spec

TEST_DEFAULTS = {'seed': 'generated fixture', 'cache_context': 'fixture-context',
                 'blender_version': 'fixture-version', 'bridge_id': 'fixture-job',
                 'contaminants': ['build/maquette.blend', 'cloth_cache/seed.json', 'capture/front_clay.png',
                                  'spec/art_identity/maquettes/glacial_mirror/cache.blend']}


class RegenerationInputTests(unittest.TestCase):
    def test_new_run_requires_fresh_empty_directory(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            (root / 'old.blend').write_text(TEST_DEFAULTS['seed'])
            with self.assertRaisesRegex(ValueError, 'fresh empty'):
                inputs.clean_inputs(root)

    def test_resume_keeps_original_inventory_and_outputs_outside_inputs(self):
        with tempfile.TemporaryDirectory() as temporary:
            output = Path(temporary) / 'run'
            spec = inputs.clean_inputs(output)
            inventory_path = output / 'clean_input_sha256.json'
            original, stamp = inventory_path.read_bytes(), inventory_path.stat().st_mtime_ns
            self.assertFalse(spec.is_relative_to(output / 'clean_project'))
            for name in TEST_DEFAULTS['contaminants']:
                path = output / name
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text(TEST_DEFAULTS['seed'])
            self.assertEqual(inputs.clean_inputs(output, resume=True), spec)
            self.assertEqual(inventory_path.read_bytes(), original)
            self.assertEqual(inventory_path.stat().st_mtime_ns, stamp)
            inventory = json.loads(original)
            inputs.validate_input_tree(output / 'clean_project', inventory)
            self.assertTrue(all(Path(name).suffix != '.blend' and not {'cloth_cache', 'capture'} & set(Path(name).parts)
                                for name in inventory))

    def test_resume_refuses_generated_files_and_directories_inside_snapshot(self):
        with tempfile.TemporaryDirectory() as temporary:
            output = Path(temporary) / 'run'
            inputs.clean_inputs(output)
            original = (output / 'clean_input_sha256.json').read_bytes()
            for name in TEST_DEFAULTS['contaminants']:
                path = output / 'clean_project' / name
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text(TEST_DEFAULTS['seed'])
                with self.subTest(name=name), self.assertRaisesRegex(ValueError, 'Generated|generated outputs'):
                    inputs.clean_inputs(output, resume=True)
                self.assertEqual((output / 'clean_input_sha256.json').read_bytes(), original)
                path.unlink()
                while path.parent != output / 'clean_project' and not any(path.parent.iterdir()):
                    parent = path.parent
                    parent.rmdir()
                    path = parent

    def test_resume_refuses_changed_original_inventory_and_source_bytes(self):
        with tempfile.TemporaryDirectory() as temporary:
            output = Path(temporary) / 'run'
            inputs.clean_inputs(output)
            inventory_path = output / 'clean_input_sha256.json'
            original = inventory_path.read_bytes()
            inventory = json.loads(original)
            first = next(iter(inventory))
            inventory[first] = TEST_DEFAULTS['seed']
            write(inventory_path, inventory)
            with self.assertRaisesRegex(ValueError, 'Original input-only inventory'):
                inputs.clean_inputs(output, resume=True)
            inventory_path.write_bytes(original)
            (output / 'clean_project' / first).write_text(TEST_DEFAULTS['seed'])
            with self.assertRaisesRegex(ValueError, 'inventory changed'):
                inputs.clean_inputs(output, resume=True)

    def test_resume_refuses_empty_generated_directory(self):
        with tempfile.TemporaryDirectory() as temporary:
            output = Path(temporary) / 'run'
            inputs.clean_inputs(output)
            (output / 'clean_project/cloth_cache').mkdir()
            with self.assertRaisesRegex(ValueError, 'Generated directory'):
                inputs.clean_inputs(output, resume=True)

    def test_resume_refuses_generated_spec_mutation_and_missing_state(self):
        with tempfile.TemporaryDirectory() as temporary:
            output = Path(temporary) / 'run'
            spec = inputs.clean_inputs(output)
            spec.write_text(TEST_DEFAULTS['seed'])
            with self.assertRaisesRegex(ValueError, 'specification was changed'):
                inputs.clean_inputs(output, resume=True)
            (output / 'input_state.json').unlink()
            with self.assertRaisesRegex(ValueError, 'original input-only inventory and state'):
                inputs.clean_inputs(output, resume=True)

    def test_resume_refuses_snapshot_and_inventory_forged_together(self):
        with tempfile.TemporaryDirectory() as temporary:
            output = Path(temporary) / 'run'
            inputs.clean_inputs(output)
            inventory_path = output / 'clean_input_sha256.json'
            inventory = json.loads(inventory_path.read_text())
            name = next(name for name in inventory if name.endswith('/glacial_mirror/measurements.json'))
            path = output / 'clean_project' / name
            recipe = json.loads(path.read_text())
            recipe['measurement_basis'] = TEST_DEFAULTS['seed']
            write(path, recipe)
            inventory[name] = sha(path)
            write(inventory_path, inventory)
            state_path = output / 'input_state.json'
            state = json.loads(state_path.read_text())
            state['inventory_sha256'] = sha(inventory_path)
            write(state_path, state)
            with self.assertRaisesRegex(ValueError, 'Original input-only inventory'):
                inputs.clean_inputs(output, resume=True)

    def test_cache_and_receipt_reuse_are_reported_from_actual_execution(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            # Use a real legacy cloth piece and the actual cache-key function;
            # a stray unrelated cache file must not be called a cache hit.
            recipe = json.loads((inputs.FIGURE.parent / 'hoarfrost_seer/measurements.json').read_text())
            spec = workflow.compile_recipe(recipe)
            spec_path, build = root / 'spec.json', root / 'build'
            write(spec_path, spec)
            write(build / 'build_report.json', {'context_key': TEST_DEFAULTS['cache_context'], 'blender': TEST_DEFAULTS['blender_version']})
            cache = build / 'cloth_cache'
            cache.mkdir()
            (cache / 'unrelated.json').write_text(TEST_DEFAULTS['seed'])
            receipt = root / 'receipt.json'
            result = {'exit': 0, 'stdout': 'fixture native run', 'id': TEST_DEFAULTS['bridge_id']}
            with patch.object(workflow, 'run_job', return_value=result.copy()):
                cold = workflow.job(inputs.BUILDER / 'build.py', [spec_path, build, '--build-only'], receipt, False)
            self.assertFalse(cold['cache_reused'])
            piece = next(p for p in board_spec(spec)['pieces'] if p['type'] == 'cloth')
            key = cache_key(TEST_DEFAULTS['cache_context'], piece, TEST_DEFAULTS['blender_version'])
            (cache / (key + '.json')).write_text(TEST_DEFAULTS['seed'])
            with patch.object(workflow, 'run_job', return_value=result.copy()):
                warm = workflow.job(inputs.BUILDER / 'build.py', [spec_path, build, '--build-only'], receipt, False)
            self.assertTrue(warm['cache_reused'])
            self.assertEqual(warm['cache_hits'], [piece['id']])
            with patch.object(workflow, 'run_job', side_effect=AssertionError('Successful resume must reuse the receipt')):
                resumed = workflow.job(inputs.BUILDER / 'build.py', [spec_path, build, '--build-only'], receipt, True)
            self.assertTrue(resumed['receipt_reused'])
            self.assertEqual(workflow.reuse_summary([resumed], True),
                             {'cache_reused': True, 'build_receipts_reused': True, 'resumed': True})
            self.assertFalse(workflow.reuse_summary([cold], False)['cache_reused'])


if __name__ == '__main__':
    unittest.main()
