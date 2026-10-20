"""Crop geometry, legacy IO, codecs, consumer metrics and evidence mutations."""
import copy
import hashlib
import importlib.util
from contextlib import ExitStack
from types import SimpleNamespace
from unittest.mock import patch
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

import numpy as np
from PIL import Image

PROJECT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(PROJECT / 'tools'))
from humanoid_cutout.native_frames import (crop_rect, to_crop, to_full, crop_box,
    load_frame, frame_digest, stored_path, export_frame, RAW_HEADER, RAW_MAGIC)
from humanoid_cutout.capture_equivalence import compare, decoded_hashes
from humanoid_cutout.gates import idle_pixel_errors, clean_metrics
from humanoid_cutout.proof import encode
from humanoid_cutout.source_space import pocket_report

PROOF_TASK_ID = os.environ.get('LABYRINTH_TASK_ID', 'cap-01')
PROOF_TIMEOUT_SECONDS = 180
CAPTURE_STORAGE_SCRIPT = os.environ.get('CAP01_STORAGE_TEST_SCRIPT', 'tests/maquette_cutout/capture_storage_test.gd')
TEST_SIZE = (64, 48)
TEST_CROP = (12, 8, 32, 32)
TEST_PATTERN_MODULUS = (251, 253, 256)
TEST_BLUE_FACTORS = (7, 11)


def save_json(path, value):
    path.write_text(json.dumps(value))


class NativeFramesTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix='cap01-frames-')
        self.root = Path(self.temporary.name)
        self.addCleanup(self.temporary.cleanup)
        self.pixels = np.zeros((*TEST_SIZE[::-1], 4), dtype=np.uint8)
        self.pixels[16:30, 20:32] = [40, 90, 140, 255]
        self.pixels[20:23, 24:27] = 0
        self.pixels[34, 35] = [40, 90, 140, 255]
        # Exact hidden RGB preservation is part of lossless IO.
        self.pixels[10, 14] = [12, 24, 36, 0]
        self.image = Image.fromarray(self.pixels)

    def crop_capture(self, folder, *, codec='png', reference=False):
        folder.mkdir(parents=True, exist_ok=True)
        x, y, w, h = TEST_CROP
        cropped = self.image.crop((x, y, x+w, y+h))
        actual = folder / ('frame.' + codec)
        if codec == 'rgba':
            actual.write_bytes(RAW_HEADER.pack(RAW_MAGIC, w, h) + cropped.tobytes())
        else:
            cropped.save(actual, **({'lossless': True, 'exact': True} if codec == 'webp' else {}))
        record = {'size': list(TEST_SIZE), 'crop': list(TEST_CROP), 'stored_file': actual.name}
        if reference:
            self.image.save(folder / 'full_idle.png')
            record['reference'] = 'full_idle.png'
        save_json(folder / 'native_storage.json', {'files': {'frame.png': record}})
        return folder / 'frame.png'

    def test_outward_rounding_clamping_and_translation(self):
        crop = crop_rect((30.25, 24.75, 12.5, 8.25), (96, 72))
        self.assertEqual(crop, (14, 8, 45, 41))
        self.assertEqual(crop_rect((-10, -20, 130, 120), (96, 72)), (0, 0, 96, 72))
        self.assertEqual(to_full(to_crop((29, 35), crop), crop), (29, 35))
        self.assertEqual(crop_box((14, 8, 59, 49), crop), (0, 0, 45, 41))
        with self.assertRaises(ValueError): crop_rect((300, 200, 5, 5), (96, 72))

    def test_legacy_no_manifest_and_legacy_manifest(self):
        path = self.root / 'legacy.png'
        self.image.save(path)
        self.assertEqual(load_frame(path).tobytes(), self.image.tobytes())
        save_json(self.root / 'frames.json', {'size': TEST_SIZE, 'frames': [{'file': path.name}]})
        self.assertEqual(load_frame(path).tobytes(), self.image.tobytes())

    def test_crop_only_manifest_and_explicit_geometry(self):
        x, y, w, h = TEST_CROP
        path = self.root / 'crop.png'
        self.image.crop((x, y, x+w, y+h)).save(path)
        manifest = {'size': TEST_SIZE, 'crop': TEST_CROP, 'frames': [{'file': path.name}]}
        self.assertEqual(load_frame(path, manifest).tobytes(), self.image.tobytes())
        save_json(self.root / 'frames.json', manifest)
        self.assertEqual(load_frame(path).tobytes(), self.image.tobytes())

    def test_png_and_raw_restore_coordinates_and_bytes(self):
        for codec in ('png', 'webp', 'rgba'):
            with self.subTest(codec=codec):
                path = self.crop_capture(self.root / codec, codec=codec)
                self.assertEqual(load_frame(path).tobytes(), self.image.tobytes())
                self.assertEqual(load_frame(path, cropped=True).size, TEST_CROP[2:])
                self.assertEqual(frame_digest(path), hashlib.sha256(stored_path(path).read_bytes()).hexdigest())

    def test_reference_preserves_floor_sample_outside_actor(self):
        self.pixels[2, 2] = [11, 22, 33, 255]
        self.image = Image.fromarray(self.pixels)
        path = self.crop_capture(self.root / 'floor', reference=True)
        self.assertEqual(load_frame(path).getpixel((2, 2)), (11, 22, 33, 255))
        self.assertEqual(load_frame(path).tobytes(), self.image.tobytes())

    def test_malformed_header_dimensions_and_crop_fail_closed(self):
        path = self.crop_capture(self.root / 'bad', codec='rgba')
        stored_path(path).write_bytes(RAW_HEADER.pack(RAW_MAGIC, 32, 32) + b'broken')
        with self.assertRaises(ValueError): load_frame(path)
        path = self.crop_capture(self.root / 'geometry')
        save_json(path.parent / 'native_storage.json', {'files': {'frame.png': {
            'stored_file': 'frame.png', 'size': [64, 48], 'crop': [60, 8, 32, 32]}}})
        with self.assertRaises(ValueError): load_frame(path)

    def test_gate_metrics_pockets_and_idle_are_identical(self):
        path = self.crop_capture(self.root / 'gates')
        before = self.pixels
        after = np.asarray(load_frame(path))
        row = {'name': 'body', 'z_index': 0, 'rigid': True}
        mask = np.zeros_like(before)
        a, b = [(row, pixels, mask) for pixels in (before, after)]
        self.assertEqual(clean_metrics([a]), clean_metrics([b]))
        self.assertEqual(pocket_report([a]), pocket_report([b]))
        self.assertEqual(idle_pixel_errors(before, after, [0, 0]), 0)

    def test_equivalence_rejects_metrics_pockets_and_texture_mutations(self):
        before, after = [self.root / n for n in ('before', 'after')]
        before.mkdir(); after.mkdir()
        report = {'errors': [], 'metrics': {'pixels': 5}, 'pockets': [{'bbox': [1, 2, 3, 4]}],
                  'detached': [], 'timestamp': 'old', 'path': str(before / 'frame.png')}
        save_json(before / 'gates.json', report)
        report['timestamp'] = 'new'; report['path'] = str(after / 'frame.png')
        save_json(after / 'gates.json', report)
        self.assertTrue(compare(before, after, reports=['gates.json'])['ok'])
        for key in ('metrics', 'pockets', 'detached', 'errors'):
            mutant = copy.deepcopy(report); mutant[key] = ['changed']
            save_json(after / 'gates.json', mutant)
            self.assertFalse(compare(before, after, reports=['gates.json'])['ok'])
        self.image.save(before / 'frame.png')
        self.crop_capture(after / 'capture')
        row = {'file': 'frame.png', 'stage': 'idle', 'pixels_sha256': 'renderer_hash'}
        save_json(before / 'frames.json', {'frames': [row]})
        save_json(after / 'capture/frames.json', {'frames': [row], 'crop': TEST_CROP})
        # Equal relative directories for the CLI contract.
        (before / 'capture').mkdir()
        shutil.copy(before / 'frame.png', before / 'capture/frame.png')
        shutil.copy(before / 'frames.json', before / 'capture/frames.json')
        self.assertTrue(compare(before, after, captures=['capture'])['ok'])
        row['pixels_sha256'] = 'changed'
        save_json(after / 'capture/frames.json', {'frames': [row], 'crop': TEST_CROP})
        self.assertFalse(compare(before, after, captures=['capture'])['ok'])

    @unittest.skipUnless(shutil.which('ffmpeg') and shutil.which('ffprobe'), 'ffmpeg/ffprobe not installed')
    def test_review_encoder_decodes_identical_crop_and_legacy_frames(self):
        full = Image.new('RGBA', (1920, 1080), (30, 30, 36, 255))
        full.paste(self.image, (700, 400))
        legacy = self.root / 'legacy.png'; full.save(legacy)
        capture = self.root / 'reel'; capture.mkdir()
        crop = (680, 380, 100, 100)
        full.crop((680, 380, 780, 480)).save(capture / 'frame.png')
        full.save(capture / 'full_idle.png')
        save_json(capture / 'native_storage.json', {'files': {'frame.png': {'stored_file': 'frame.png',
            'size': [1920, 1080], 'crop': crop, 'reference': 'full_idle.png'}}})
        a, b = self.root / 'a.mp4', self.root / 'b.mp4'
        encode([legacy] * 2, a); encode([capture / 'frame.png'] * 2, b)
        self.assertEqual(decoded_hashes(a), decoded_hashes(b))

    def test_concat_export_uses_full_coordinates(self):
        path = self.crop_capture(self.root / 'concat', codec='rgba')
        exported = export_frame(path, self.root / 'scratch')
        self.assertEqual(load_frame(exported).tobytes(), self.image.tobytes())
        self.assertEqual(export_frame(path, self.root / 'scratch'), exported)

    def module(self, relative):
        path = PROJECT / relative
        spec = importlib.util.spec_from_file_location('cap01_' + path.stem + str(len(str(path))), path)
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        return module

    def test_actual_bird_and_gaoler_reader_paths_all_codecs(self):
        for relative in ('gust_shrike/mq2/probes/motion_gates.py', 'chainbound_gaoler/mq3/probes/motion_gates.py'):
            module = self.module('experiments/cutouts/' + relative)
            for codec in ('png', 'webp', 'rgba'):
                with self.subTest(reader=relative, codec=codec):
                    path = self.crop_capture(self.root / relative.split('/')[0] / codec, codec=codec)
                    self.assertEqual(module.rgba(str(path)).shape, (48, 64, 4))
                    np.testing.assert_array_equal(module.rgba(str(path)), self.pixels)

    def test_actual_briar_feature_reader_path_all_codecs(self):
        module = self.module('experiments/cutouts/briar_weaver/rr21_residue.py')
        self.image.save(self.root / 'paint.png')
        layout = {'facing': 'front', 'parts': [{'name': 'head', 'bbox': [0, 0, 255, 255], 'file': 'paint.png'}]}
        # UV rendering is independent of the reader under test; retain the real
        # feature consumer's dimension check and pixel-colour comparison.
        projection = SimpleNamespace(candidates=[self.pixels])
        with patch.object(module, 'feature_definitions', return_value=[{'piece': 'head', 'name': 'test'}]), \
             patch.object(module, 'feature_mask', return_value=np.ones((255, 255), dtype=bool)), \
             patch('maquette_motion.pixels.render', return_value=projection):
            for codec in ('png', 'webp', 'rgba'):
                path = self.crop_capture(self.root / 'briar' / codec, codec=codec)
                row = {'name': 'head', 'absolute_file': str(path), 'transform': [1, 0, 0, 1, 0, 0]}
                actual = module.presented_feature_mask(self.root, layout, [row], (48, 64))
                np.testing.assert_array_equal(actual, self.pixels[..., 3] > 0)

    def test_native_gate_rest_loader_all_codecs(self):
        from humanoid_cutout import gates
        case = self.root / 'case'
        (case / 'layouts').mkdir(parents=True)
        (case / 'proof').mkdir()
        data = {'view_tracks': {'front': {}}, 'clips': {'idle': {'seconds': 1 / 60}}}
        save_json(case / 'compiled_motion.json', data)
        save_json(case / 'layouts/front.json', {'parts': [], 'rest_source': 'source.png'})
        save_json(case / 'proof/build.json', {})
        self.image.save(case / 'source.png')
        manifest = {'ok': True, 'errors': [], 'native_pixels': True, 'size': [1920, 1080],
                    'ui_scale': 1, 'inputs': {'test': 'binding'}, 'frames': []}
        with ExitStack() as stack:
            for target, value in ((gates.__name__ + '.load', {}), (gates.__name__ + '.bindings', manifest['inputs']),
                    (gates.__name__ + '.source_errors', []), ('humanoid_cutout.native_exceptions.load', frozenset()),
                    ('humanoid_cutout.bone_evidence.read_report', {'inputs': manifest['inputs'], 'samples': []}),
                    ('humanoid_cutout.bone_evidence.evidence_errors', []), ('humanoid_cutout.rigid_air.for_case', None),
                    ('humanoid_cutout.source_space.DetachedSource', None), ('maquette_motion.material_palette.rules', {})):
                stack.enter_context(patch(target, return_value=value))
            legacy = self.root / 'native_legacy'; legacy.mkdir()
            self.image.save(legacy / 'front_rest.png')
            save_json(legacy / 'frames.json', manifest)
            expected = gates.native_errors(case, legacy)
            self.assertNotIn('front: native rest mismatch', expected)
            for codec in ('png', 'webp', 'rgba'):
                folder = self.root / 'native_rest' / codec
                self.crop_capture(folder, codec=codec)
                index = json.loads((folder / 'native_storage.json').read_text())
                record = index['files'].pop('frame.png')
                actual = 'front_rest.' + codec
                (folder / record['stored_file']).rename(folder / actual)
                record['stored_file'] = actual
                index['files']['front_rest.png'] = record
                save_json(folder / 'native_storage.json', index)
                save_json(folder / 'frames.json', manifest)
                self.assertEqual(gates.native_errors(case, folder), expected)

    def test_encoding_benchmark_loads_headless_through_task_runner(self):
        command = [sys.executable, 'tools/godot_task_runner.py', '--task-id', PROOF_TASK_ID, '--stream', '--',
                   'godot', '--headless', '--path', '.', '--script', 'tests/maquette_cutout/encoding_benchmark.gd',
                   '--', '--validate-only']
        result = subprocess.run(command, cwd=PROJECT, text=True, capture_output=True, timeout=PROOF_TIMEOUT_SECONDS)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn('CAPTURE ENCODER BENCHMARK LOAD: PASS', result.stdout)

    def test_godot_storage_roundtrips_through_task_runner(self):
        command = [sys.executable, 'tools/godot_task_runner.py', '--task-id', PROOF_TASK_ID, '--stream', '--',
                   'godot', '--headless', '--path', '.', '--script', CAPTURE_STORAGE_SCRIPT,
                   '--', '--output', str(self.root / 'godot')]
        result = subprocess.run(command, cwd=PROJECT, text=True, capture_output=True, timeout=PROOF_TIMEOUT_SECONDS)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn('CAPTURE STORAGE: PASS (0 failures)', result.stdout)
        y, x = np.indices((1080, 1920))
        expected = np.stack((x % TEST_PATTERN_MODULUS[0], y % TEST_PATTERN_MODULUS[1],
            (x * TEST_BLUE_FACTORS[0] + y * TEST_BLUE_FACTORS[1]) % TEST_PATTERN_MODULUS[2],
            np.full_like(x, 255)), axis=-1).astype(np.uint8)
        for codec in ('png', 'webp', 'rgba'):
            actual = np.asarray(load_frame(self.root / 'godot' / ('board_' + codec + '.png')))
            np.testing.assert_array_equal(actual, expected, err_msg=codec + ' writer-to-Python reconstruction')


if __name__ == '__main__': unittest.main()
