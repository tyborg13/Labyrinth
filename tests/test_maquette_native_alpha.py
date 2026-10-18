"""Immutable saved native fade captures; no window-server dependency."""
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch
import numpy as np
from PIL import Image, ImageFilter

PROJECT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(PROJECT / 'tools'))
from cutout_pipeline.cases import digest, read_json
from maquette_motion import pixels, silhouette, seam_pose

IMAGE_PROBE_TIMEOUT_SECONDS = 60


class NativeAlphaTests(unittest.TestCase):
    def fixture(self):
        root = PROJECT / 'tests/maquette_cutout/alpha_fixtures'
        data = read_json(root / 'manifest.json')
        case = PROJECT / data['case']
        for path, expected in data['source_files'].items():
            self.assertEqual(digest(case / path), expected)
        return root, data, case

    def test_native_late_fade_matches_model_without_phantom_body_pixels(self):
        root, data, case = self.fixture()
        for frame in data['frames']:
            self.assertEqual(digest(root / frame['file']), frame['sha256'])
            native = np.asarray(Image.open(root / frame['file']).convert('RGBA'))[..., 3] > 0
            cpu = silhouette.compose(case, data['layout'], frame['sample'])
            np.testing.assert_array_equal(cpu, native)
        self.assertFalse(cpu.any())
        with patch.object(pixels, 'modulated_alpha', lambda alpha, modulation: pixels.round_pixels(alpha * modulation)):
            legacy = silhouette.compose(case, data['layout'], data['frames'][-1]['sample'])
        self.assertEqual(int(legacy.sum()), data['expected_before_fix_false_pixels_frame70'])
        # Before the correction, round(255 * 0.002877542) incorrectly drew
        # 13,007 mask pixels in this completely transparent native frame.
        print('MAQUETTE NATIVE ALPHA: PASS (death/0069 and /0070: 0px mask diff; old /0070 model invented 13007px)')

    def test_eroded_rest_reference_uses_the_same_canvas_alpha_packing(self):
        _, data, case = self.fixture()
        frame = data['frames'][-1]['sample']
        owner = seam_pose.body_part(data['layout'])
        targets = seam_pose.pose_reference(seam_pose.reference_images(case, data['layout']), frame, owner)
        self.assertFalse(any(mask.any() for mask in targets))
        self.assertGreater(float(frame['parts'][owner['name']]['alpha']), 0)
        self.assertEqual(pixels.modulated_alpha(np.asarray([255]), np.float32(1 / 255)).tolist(), [1])

    def test_godot_reference_erosion_matches_independent_pillow_masks(self):
        with tempfile.TemporaryDirectory(prefix='reference-mask-test-') as temporary:
            command = ['python3', 'tools/godot_task_runner.py', '--task-id', 'rr-05', '--stream', '--',
                       'godot', '--headless', '--path', '.', '--script', 'tests/maquette_cutout/reference_mask_test.gd',
                       '--', '--output', temporary]
            result = subprocess.run(command, cwd=PROJECT, capture_output=True, text=True, timeout=IMAGE_PROBE_TIMEOUT_SECONDS)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            report = read_json(Path(temporary) / 'images.json')
            self.assertFalse(report['native_pixels'])
            self.assertEqual(len(report['images']), 8)
            for row in report['images']:
                version = 'mq3' if row['creature'] == 'shale_bloomer' else 'mq4'
                source = PROJECT / f'experiments/cutouts/{row["creature"]}/{version}/source/{row["view"]}/processed.png'
                expected = np.asarray(Image.open(source).convert('RGBA'))[..., 3] > 0
                if row['kind'] == 'interior':
                    expected = np.asarray(Image.fromarray(np.pad(expected.astype(np.uint8) * 255, 1))
                                          .filter(ImageFilter.MinFilter(3)))[1:-1, 1:-1] > 0
                actual = np.asarray(Image.open(row['file']).convert('RGBA'))[..., 3] > 0
                np.testing.assert_array_equal(actual, expected)
        print('MAQUETTE REFERENCE MASKS: PASS (8 Godot image-operation masks = independent Pillow; no renderer claim)')


if __name__ == '__main__':
    unittest.main()
