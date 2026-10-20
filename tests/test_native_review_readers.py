"""Exercise additional readers found by the repository-wide native IO audit."""
import importlib.util
import hashlib
import json
from pathlib import Path
import runpy
import sys
import tempfile
import unittest
from unittest.mock import patch

from PIL import Image, ImageChops

PROJECT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(PROJECT / 'tools'))
from humanoid_cutout.native_frames import RAW_HEADER, RAW_MAGIC, frame_digest, load_frame

CODECS = ('png', 'webp', 'rgba')
TEST_POSE_SIZE = (512, 512)
TEST_POSE_CROP = (96, 112, 336, 80)


def write_capture(root, images, crop, codec=None):
    root.mkdir(parents=True, exist_ok=True)
    records = {}
    codec = codec or root.name
    for logical, image in images.items():
        x, y, w, h = crop
        stored = Path(logical).with_suffix('.' + codec)
        path = root / stored; path.parent.mkdir(parents=True, exist_ok=True)
        pixels = image.crop((x, y, x+w, y+h))
        if codec == 'rgba':
            path.write_bytes(RAW_HEADER.pack(RAW_MAGIC, w, h) + pixels.tobytes())
        else:
            pixels.save(path, **({'lossless': True, 'exact': True} if codec == 'webp' else {}))
        if codec != 'png' and (root / logical).is_file(): (root / logical).unlink()
        records[logical] = {'stored_file': stored.as_posix(), 'size': image.size, 'crop': crop}
    (root / 'native_storage.json').write_text(json.dumps({'files': records}))


class NativeReviewReadersTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='cap01-readers-')
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.source = Image.new('RGBA', (255, 255))
        # Harrier's existing audit requires exactly 8,999 opaque source texels.
        self.source.putdata([(40, 90, 140, 255)] * 8999 + [(0, 0, 0, 0)] * (255 * 255 - 8999))
        self.pose = Image.new('RGBA', TEST_POSE_SIZE)
        self.pose.paste(self.source, (112, 128))

    def run_script(self, relative, arguments):
        with patch.object(sys, 'argv', [relative, *map(str, arguments)]):
            runpy.run_path(str(PROJECT / relative), run_name='__main__')

    def test_harrier_native_packager_crop_and_all_codecs(self):
        for codec in CODECS:
            root = self.root / codec / 'a/b/c/d' / codec
            original = root.parents[4] / 'assets/placeholders/units/harrier_anime_trial.png'
            original.parent.mkdir(parents=True, exist_ok=True); self.source.save(original)
            reflected = ImageChops.offset(self.pose.transpose(Image.Transpose.FLIP_LEFT_RIGHT), -1, 0)
            images = {f'{view}/{clip}_000.png': reflected if view.endswith('_reflected') else self.pose
                      for view in ('front', 'rear', 'front_reflected', 'rear_reflected')
                      for clip in ('rest', 'idle', 'walk', 'retreat', 'attack', 'cast')}
            write_capture(root, images, TEST_POSE_CROP)
            (root / 'comparison.json').write_text(json.dumps({'ok': True, 'bake_only': False, 'errors': []}))
            self.run_script('experiments/cutouts/harrier/package_assets.py', [root, '--previous', root])
            report = json.loads((root.parent / 'front_source_preservation.json').read_text())
            self.assertEqual(report['mismatches'], 0)
            self.assertEqual(report['native_file_sha256'], frame_digest(root / 'front/rest_000.png'))
            self.assertEqual(len(list((root.parent / 'inspection_sheets').glob('*.png'))), 20)

    def test_vaeloryx_native_sheets_crop_and_all_codecs(self):
        for codec in CODECS:
            root = self.root / 'vaeloryx' / codec
            rows = [{'facing': view, 'mirrored': mirror, 'clip': clip, 'phase': 0,
                     'label': f'{view}_{mirror}_{clip}', 'bounds': [112, 128, 255, 36]}
                    for view in ('front', 'rear') for mirror in (False, True)
                    for clip in ('idle', 'walk', 'dive', 'gale', 'pull', 'guard')]
            write_capture(root, {r['label'] + '.png': self.pose for r in rows}, TEST_POSE_CROP)
            (root / 'comparison.json').write_text(json.dumps({'ok': True, 'records': rows}))
            output = root.parent / (codec + '-sheets')
            self.run_script('experiments/cutouts/vaeloryx/review_sheets.py', [root, output])
            self.assertEqual(len(list(output.glob('*.png'))), 24)
            record = json.loads((output / 'composition.json').read_text())
            for sheet in record['sheets']:
                for name, digest in sheet['input_sha256'].items(): self.assertEqual(digest, frame_digest(root / name))

    def test_protagonist_native_copy_and_contact_sheet_all_codecs(self):
        spec = importlib.util.spec_from_file_location('cap01_gear_review', PROJECT / 'experiments/cutouts/protagonist_gear/collect_review.py')
        module = importlib.util.module_from_spec(spec); spec.loader.exec_module(module)
        for codec in CODECS:
            root = self.root / 'gear' / codec
            write_capture(root, {'key_pose.png': self.pose}, TEST_POSE_CROP)
            destination = root.parent / (codec + '-restored.png')
            module.copy_native(root / 'key_pose.png', destination, TEST_POSE_SIZE)
            self.assertEqual(load_frame(destination).tobytes(), self.pose.tobytes())
            module.contact_sheet(root, 'idle', [{'file': 'key', 'phase': 0, 'facing': 'front'}])
            self.assertTrue((root / 'idle_contact_sheet.png').is_file())

    def test_shrike_production_coverage_reel_and_rest_all_codecs(self):
        probes = PROJECT / 'experiments/cutouts/gust_shrike/mq2/probes'
        sys.path.insert(0, str(probes))
        sys.path.insert(0, str(probes.parent))
        import production_coverage
        import pack_production
        spec = importlib.util.spec_from_file_location('cap01_shrike_pipeline', probes.parent / 'pipeline.py')
        pipeline = importlib.util.module_from_spec(spec); spec.loader.exec_module(pipeline)
        board = Image.new('RGBA', (1920, 1080)); board.paste(self.source, (112, 128))
        decoded = []
        from humanoid_cutout.capture_equivalence import decoded_hashes
        for codec in CODECS:
            root = self.root / 'shrike' / codec
            images = {'frame_00000.png': board, 'frame_00001.png': board}
            # The board and isolated pose retain distinct original spaces.
            write_capture(root, images, (96, 112, 336, 80))
            pose_root = root / 'poses'; pose_root.mkdir()
            write_capture(pose_root, {'pose.png': self.pose}, TEST_POSE_CROP, codec=codec)
            pose = pose_root / 'pose.png'
            frames = [{'file': f'frame_{i:05d}.png', 'pose_file': f'pose_{i}.png',
                       'seconds': i * .1, 'pose_sha256': hashlib.sha256(self.pose.tobytes()).hexdigest()} for i in range(2)]
            # Fold the pose index into the root, as real mixed-space writers do.
            index = json.loads((root / 'native_storage.json').read_text())
            pose_record = json.loads((pose_root / 'native_storage.json').read_text())['files']['pose.png']
            for i in range(2):
                record = dict(pose_record, stored_file='poses/' + pose_record['stored_file'])
                index['files'][f'pose_{i}.png'] = record
            (root / 'native_storage.json').write_text(json.dumps(index))
            manifest = {'ok': True, 'native_pixels': True, 'clips': sorted(pack_production.REQUIRED_CLIPS),
                        'size': [1920, 1080], 'ui_scale': 1, 'frames': frames}
            (root / 'frames.json').write_text(json.dumps(manifest))
            with patch.object(production_coverage, 'errors', return_value=[]):
                production_coverage.verify(root, manifest)
                pack_production.pack(root)
            decoded.append(decoded_hashes(root / 'production_reel.mp4'))
            destination = root / 'restored.png'
            pipeline.copy_native_rest(pose, destination)
            self.assertEqual(load_frame(destination).tobytes(), self.pose.tobytes())
        self.assertEqual(decoded[0], decoded[1]); self.assertEqual(decoded[0], decoded[2])

    def test_real_gaoler_native_gate_crop_and_all_codecs(self):
        sys.path.insert(0, str(PROJECT / 'tests'))
        from test_maquette_cutout import GaolerCaseTests
        fixture = GaolerCaseTests()
        for codec in CODECS:
            with patch('cutout_pipeline.proof.verify_render', return_value={'ok': True}):
                gates, case, output = fixture._native_gate_fixture(self.root / ('gaoler_' + codec))
                control = gates.native_gates(case, output)
                capture = output / 'motion_gate_capture'
                images = {p.relative_to(capture).as_posix(): load_frame(p).convert('RGBA') for p in capture.rglob('*.png')}
                write_capture(capture, images, (0, 0, 512, 224), codec=codec)
                hashes = json.loads((capture / 'sha256.json').read_text())
                for logical in images: hashes[logical] = frame_digest(capture / logical)
                (capture / 'sha256.json').write_text(json.dumps(hashes))
                self.assertEqual(gates.native_gates(case, output), control)

    def test_native_copy_crop_only_manifest_and_legacy_bytes(self):
        pipeline_path = PROJECT / 'experiments/cutouts/gust_shrike/mq2/pipeline.py'
        sys.path.insert(0, str(pipeline_path.parent))
        spec = importlib.util.spec_from_file_location('cap01_copy_shrike', pipeline_path)
        pipeline = importlib.util.module_from_spec(spec); spec.loader.exec_module(pipeline)
        spec = importlib.util.spec_from_file_location('cap01_copy_gear', PROJECT / 'experiments/cutouts/protagonist_gear/collect_review.py')
        gear = importlib.util.module_from_spec(spec); spec.loader.exec_module(gear)
        root = self.root / 'crop_only'; root.mkdir()
        x, y, w, h = TEST_POSE_CROP
        source = root / 'frame.png'; self.pose.crop((x, y, x+w, y+h)).save(source)
        (root / 'frames.json').write_text(json.dumps({'size': TEST_POSE_SIZE, 'crop': TEST_POSE_CROP}))
        pipeline.copy_native_rest(source, root / 'shrike.png')
        gear.copy_native(source, root / 'gear.png', TEST_POSE_SIZE)
        for name in ('shrike.png', 'gear.png'):
            self.assertEqual(Image.open(root / name).tobytes(), self.pose.tobytes())
        legacy = self.root / 'legacy.png'; self.pose.save(legacy, compress_level=1)
        pipeline.copy_native_rest(legacy, self.root / 'legacy_shrike.png')
        gear.copy_native(legacy, self.root / 'legacy_gear.png', TEST_POSE_SIZE)
        for name in ('legacy_shrike.png', 'legacy_gear.png'):
            self.assertEqual((self.root / name).read_bytes(), legacy.read_bytes())

    def test_strike_trail_native_sheet_crop_and_all_codecs(self):
        board = Image.new('RGBA', (1920, 1080))
        board.paste(self.source, (700, 400))
        for codec in CODECS:
            root = self.root / 'strike' / codec
            write_capture(root, {'board.png': board}, (680, 380, 300, 300))
            (root / 'manifest.json').write_text(json.dumps({'size': [1920, 1080], 'ui_scale': 1,
                'errors': [], 'captures': [{'view': 'front', 'element': 'none', 'reduced': False,
                    'file': 'board.png', 'crop': [680, 380, 300, 300], 'motion': 'heavy', 'progress': 0, 'weapon_z': 0}]}))
            output = root.parent / (codec + '-sheet')
            self.run_script('tools/build_strike_trail_sheet.py', [root, '--output-dir', output])
            self.assertTrue((output / 'strike_trail_front.png').is_file())


if __name__ == '__main__': unittest.main()
