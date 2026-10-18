"""Adversarial report and raster fixtures for both delivery entry points."""
from copy import deepcopy
import json
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

from PIL import Image

from .compile_recipe import compile_recipe
from .curate_delivery import sha
from .curate_delivery import stage
from .capture_manifest import write_manifest
from .delivery_validation import REPORTS, load, seal_delivery, validate_delivery
from .regenerate_delivery import compare_captures
from .ownership import require_solos

ROOT = Path(__file__).resolve().parents[1]
VERIFIER_TEST_DEFAULTS = {'figure': 'arc_thrall', 'pixels': (8, 8),
                          'red': (255, 0, 0, 255), 'green': (0, 255, 0, 255)}


class DeliveryValidationTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.figure = Path(self.temporary.name) / 'arc_thrall'
        source = ROOT / 'arc_thrall'
        self.figure.mkdir()
        shutil.copyfile(source / 'measurements.json', self.figure / 'measurements.json')
        # Copy reports; link read-only raster fixtures so failures cannot be
        # explained by a missing or corrupt image instead of the mutated report.
        self.capture = self.figure / 'delivery'
        self.capture.mkdir()
        for path in (source / 'delivery').iterdir():
            if path.is_file():
                if path.suffix == '.png':
                    (self.capture / path.name).symlink_to(path)
                else:
                    shutil.copyfile(path, self.capture / path.name)
        self.spec = compile_recipe(load(self.figure / 'measurements.json'))
        seal_delivery(self.spec, self.capture)

    def change(self, name, function):
        path = self.capture / name
        before = path.read_bytes()
        data = json.loads(before)
        function(data)
        path.write_text(json.dumps(data))
        return path, before

    def test_valid_current_delivery(self):
        validate_delivery(self.spec, self.capture)

    def test_staging_preserves_native_png_bytes_including_stamps(self):
        from PIL.PngImagePlugin import PngInfo
        names = load(self.capture / 'capture_manifest.json')['images']
        for view in ('front', 'rear'):
            for kind in ('clay', 'parts'):
                path = self.capture / (view + '_' + kind + '.png')
                image = Image.open(path).copy()
                path.unlink()  # Fixture PNGs initially link to read-only inputs.
                info = PngInfo(); info.add_text('Date', 'native-stamp-fixture')
                image.save(path, pnginfo=info)
        write_manifest(self.capture, load(self.capture / 'build_report.json')['spec_hash'], 'full', names)
        seal_delivery(self.spec, self.capture)
        destination = self.figure.parent / 'staged'
        destination.mkdir()
        shutil.copyfile(self.figure / 'measurements.json', destination / 'measurements.json')
        stage(destination, self.capture)
        for name in names:
            self.assertEqual(sha(self.capture / name), sha(destination / 'delivery' / name), name)
        validate_delivery(self.spec, destination / 'delivery')

    def test_every_report_is_required(self):
        for name in REPORTS + ('recipe_proof.json', 'exact_native_replay.json'):
            with self.subTest(report=name):
                path = self.capture / name
                before = path.read_bytes()
                path.unlink()
                try:
                    with self.assertRaises(ValueError):
                        validate_delivery(self.spec, self.capture)
                finally:
                    path.write_bytes(before)

    def test_each_passed_and_check_field_rejects_false_or_missing_even_before_sealing(self):
        # Walk actual report schemas so adding a native check extends coverage.
        def fields(value, prefix=()):
            if isinstance(value, dict):
                for key, item in value.items():
                    if key == 'passed' or key.endswith('_passed') or prefix and prefix[-1] in ('checks', 'geometry_checks'):
                        if item is True:
                            yield prefix + (key,)
                    yield from fields(item, prefix + (key,))
        names = REPORTS[:-1] + ('recipe_proof.json', 'exact_native_replay.json')
        tested = 0
        for name in names:
            original = load(self.capture / name)
            # Nested summaries may be optional descriptive records; their
            # removal is rejected by the byte binding, their false value by
            # semantic validation before a new seal can be made.
            for keys in fields(original):
                for missing in (False, True):
                    with self.subTest(report=name, field=keys, missing=missing):
                        data = deepcopy(original)
                        parent = data
                        for key in keys[:-1]:
                            parent = parent[key]
                        if missing:
                            del parent[keys[-1]]
                        else:
                            parent[keys[-1]] = False
                        (self.capture / name).write_text(json.dumps(data))
                        try:
                            with self.assertRaises(ValueError):
                                validate_delivery(self.spec, self.capture, require_binding=missing)
                        finally:
                            (self.capture / name).write_text(json.dumps(original, indent=2) + '\n')
                        # Restore the exact sealed report bytes before testing
                        # the next field (JSON formatting is part of the seal).
                        seal_delivery(self.spec, self.capture)
                        tested += 1
        self.assertGreater(tested, 0)

    def test_collision_and_ownership_details_cannot_hide_behind_true_summary(self):
        cases = [
            ('build_report.json', lambda d: d['cloth'].pop(next(iter(d['cloth'])))),
            ('build_report.json', lambda d: d['cloth'][next(iter(d['cloth']))].update(samples_below_margin=1)),
            ('build_report.json', lambda d: d['cloth'][next(iter(d['cloth']))].update(intersecting_face_pairs=1)),
            ('capture_checks.json', lambda d: d.update(geometry_unchanged=False)),
            ('ownership_validation.json', lambda d: d['empty_required_solos']['front'].append('head')),
            ('solo_coverage.json', lambda d: d['rear'].update(head=0)),
            ('solo_coverage.json', lambda d: d.pop('front')),
        ]
        for name, mutation in cases:
            with self.subTest(report=name):
                path, before = self.change(name, mutation)
                try:
                    with self.assertRaises(ValueError):
                        validate_delivery(self.spec, self.capture, require_binding=False)
                finally:
                    path.write_bytes(before)

    def test_each_hash_binding_is_required_and_current(self):
        binding = load(self.capture / 'recipe_proof.json')['delivery_binding']
        mutations = [(name, lambda d: d.update(spec_hash='stale')) for name in ('build_report.json', 'capture_checks.json')]
        mutations += [('build_report.json', lambda d: d.update(combined_mesh_hash='stale')),
                      ('recipe_proof.json', lambda d: d.pop('delivery_binding'))]
        for name in binding['report_sha256']:
            mutations.append(('recipe_proof.json', lambda d, n=name: d['delivery_binding']['report_sha256'].update({n: 'stale'})))
        for key in ('spec_hash', 'cold_mesh_hash', 'exact_native_replay_sha256'):
            mutations.append(('recipe_proof.json', lambda d, k=key: d['delivery_binding'].update({k: 'stale'})))
        # Benign report edits still invalidate the cold-proof byte binding.
        mutations.append(('ownership_validation.json', lambda d: d.update(annotation='changed')))
        for name, mutation in mutations:
            with self.subTest(report=name):
                path, before = self.change(name, mutation)
                try:
                    with self.assertRaises(ValueError):
                        validate_delivery(self.spec, self.capture)
                finally:
                    path.write_bytes(before)

    def test_copied_thrall_mutation_exits_nonzero_in_both_delivery_tools(self):
        for name in ('capture_checks.json', 'facing_report.json', 'ownership_validation.json'):
            self.change(name, lambda d: d.update(passed=False))
        self.change('build_report.json', lambda d: d['checks'].update(cloth_collision_margin=False))
        (self.figure / 'README.md').write_text('test fixture')
        (self.figure / 'COMMIT_MANIFEST.txt').write_text('\n'.join(
            sorted(str(p.relative_to(self.figure)) for p in self.figure.rglob('*') if p.is_file()) + ['COMMIT_MANIFEST.txt']) + '\n')
        commands = [
            [sys.executable, '-B', str(ROOT / 'blender/quality_delivery.py'), str(self.figure),
             '--capture-subdir', 'delivery', '--lancer', str(self.capture), '--out', str(self.figure / 'review')],
            [sys.executable, '-B', '-m', 'spec.art_identity.maquettes.blender.curate_delivery', 'verify', str(self.figure)],
            [sys.executable, '-B', '-m', 'spec.art_identity.maquettes.blender.curate_delivery', 'curate', str(self.figure)],
            [sys.executable, '-B', '-m', 'spec.art_identity.maquettes.blender.curate_delivery', 'stage', str(self.figure), '--capture', str(self.capture)],
        ]
        before = {str(p): sha(p) for p in self.figure.rglob('*') if p.is_file()}
        for command in commands:
            result = subprocess.run(command, capture_output=True, text=True)
            self.assertNotEqual(result.returncode, 0, result.stdout)
            self.assertIn('Failed delivery check', result.stderr)
        self.assertEqual(before, {str(p): sha(p) for p in self.figure.rglob('*') if p.is_file()})

    def test_required_part_rejection_is_exercised_directly(self):
        require_solos(['head', 'torso'], {'head': 1, 'torso': 5})
        for counts in ({'head': 1}, {'head': 1, 'torso': 0}, {'head': -1, 'torso': 5}):
            with self.subTest(counts=counts), self.assertRaisesRegex(ValueError, 'Required rig labels'):
                require_solos(['head', 'torso'], counts)


class RegenerationRasterTests(unittest.TestCase):
    def test_correct_clays_cannot_mask_missing_or_red_maps(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            native, delivery = root / 'native', root / 'delivery'
            native.mkdir(); delivery.mkdir()
            for view in ('front', 'rear'):
                for kind in ('clay', 'parts'):
                    name = view + '_' + kind + '.png'
                    Image.new('RGBA', VERIFIER_TEST_DEFAULTS['pixels'], VERIFIER_TEST_DEFAULTS['green']).save(native / name)
                    shutil.copyfile(native / name, delivery / name)
            before = {p.name: sha(p) for p in delivery.iterdir()}
            def passed():
                return all(v['passed'] for r in compare_captures(native, delivery, root).values() for v in r.values())
            self.assertTrue(passed())
            for view in ('front', 'rear'):
                path = native / (view + '_parts.png')
                path.unlink()
                self.assertFalse(passed())
                Image.new('RGBA', VERIFIER_TEST_DEFAULTS['pixels'], VERIFIER_TEST_DEFAULTS['red']).save(path)
                self.assertFalse(passed())
                shutil.copyfile(delivery / path.name, path)
            self.assertEqual(before, {p.name: sha(p) for p in delivery.iterdir()})


if __name__ == '__main__':
    unittest.main()
