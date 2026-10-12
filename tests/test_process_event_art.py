from __future__ import annotations
import importlib.util
import io
import json
from pathlib import Path
import unittest
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('process_event_art', ROOT / 'tools/process_event_art.py')
processor = importlib.util.module_from_spec(spec)
spec.loader.exec_module(processor)


class EventArtTest(unittest.TestCase):
    def test_approved_outputs_and_provenance(self):
        manifest = json.loads((ROOT / 'spec/assets/events/hashes.json').read_text())
        self.assertEqual(len(manifest['assets']), 38)
        for record in manifest['assets']:
            output = ROOT / record['output']
            self.assertEqual(processor.sha256(output), record['output_sha256'], str(output))
            self.assertTrue((ROOT / record['prompt']).is_file(), record['prompt'])
            family = 'omen_icons' if '/omens/' in record['output'] else 'event_art'
            approval = processor.approved_hashes(ROOT / f'spec/peer_benchmark/staged/{family}/approved_sha256.txt')
            self.assertEqual(approval[Path(record['raw']).name], record['raw_sha256'])
            with Image.open(output) as image:
                self.assertEqual(image.mode, 'RGBA' if family == 'omen_icons' else 'RGB')
                self.assertEqual(image.size, (96, 96) if family == 'omen_icons' else (1152, 768))
                if family == 'omen_icons':
                    self.assertEqual(image.getpixel((0, 0))[3], 0)
                    for r, g, b, alpha in image.getdata():
                        if alpha: self.assertLessEqual(g, max(r, b), 'Green matte fringe')

    def test_key_unmix_and_determinism(self):
        raw = Image.new('RGB', (10, 8), (0, 255, 0))
        raw.paste((100, 50, 25), (3, 2, 7, 6))
        raw.putpixel((3, 2), (50, 152, 12))
        first = processor.seal(raw)
        second = processor.seal(raw)
        a, b = io.BytesIO(), io.BytesIO()
        first.save(a, format='PNG', optimize=True)
        second.save(b, format='PNG', optimize=True)
        self.assertEqual(a.getvalue(), b.getvalue())
        self.assertNotEqual(first.getchannel('A').getextrema(), (0, 0))

    def test_rebuild_matches_pinned_hashes_when_sources_available(self):
        manifest = json.loads((ROOT / 'spec/assets/events/hashes.json').read_text())
        for record in manifest['assets']:
            raw = Path(record['raw'])
            if not raw.is_file(): self.skipTest('Director raw-art directory unavailable')
            self.assertEqual(processor.sha256(raw), record['raw_sha256'])
            with Image.open(raw) as image:
                result = processor.seal(image) if '/omens/' in record['output'] else processor.painting(image)
                encoded = io.BytesIO()
                result.save(encoded, format='PNG', optimize=True)
                self.assertEqual(processor.hashlib.sha256(encoded.getvalue()).hexdigest(), record['output_sha256'])


if __name__ == '__main__':
    unittest.main()
