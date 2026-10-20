"""Crop geometry, legacy IO, codecs, consumer metrics and evidence mutations."""
import copy
import hashlib
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
TEST_SIZE = (64, 48)
TEST_CROP = (12, 8, 32, 32)


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
            cropped.save(actual)
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
        for codec in ('png', 'rgba'):
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

    def test_encoding_benchmark_loads_headless_through_task_runner(self):
        command = [sys.executable, 'tools/godot_task_runner.py', '--task-id', PROOF_TASK_ID, '--stream', '--',
                   'godot', '--headless', '--path', '.', '--script', 'tests/maquette_cutout/encoding_benchmark.gd',
                   '--', '--validate-only']
        result = subprocess.run(command, cwd=PROJECT, text=True, capture_output=True, timeout=PROOF_TIMEOUT_SECONDS)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn('CAPTURE ENCODER BENCHMARK LOAD: PASS', result.stdout)

    def test_godot_storage_roundtrips_through_task_runner(self):
        command = [sys.executable, 'tools/godot_task_runner.py', '--task-id', PROOF_TASK_ID, '--stream', '--',
                   'godot', '--headless', '--path', '.', '--script', 'tests/maquette_cutout/capture_storage_test.gd',
                   '--', '--output', str(self.root / 'godot')]
        result = subprocess.run(command, cwd=PROJECT, text=True, capture_output=True, timeout=PROOF_TIMEOUT_SECONDS)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn('CAPTURE STORAGE: PASS (0 failures)', result.stdout)


if __name__ == '__main__': unittest.main()
