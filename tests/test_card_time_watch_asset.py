"""Keep the painted time-cost watch, its geometry and the badge constants in step."""
import hashlib
import json
import re
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]


class CardTimeWatchAsset(unittest.TestCase):
    def test_badge_constants_match_processed_watch(self):
        meta = json.loads((ROOT / 'assets/art/ui/card_time_watch.json').read_text())
        source = (ROOT / 'scripts/card_widget.gd').read_text()

        def vector(name):
            match = re.search(r'const %s := Vector2\(([-\d.]+), ([-\d.]+)\)' % name, source)
            self.assertIsNotNone(match, name)
            return [float(match.group(1)), float(match.group(2))]

        self.assertEqual(vector('WATCH_TEXTURE_SIZE'), [float(v) for v in meta['size']])
        self.assertEqual(vector('WATCH_DIAL_CENTER'), meta['dial_center'])
        radius = re.search(r'const WATCH_CASE_RADIUS: float = ([\d.]+)', source)
        self.assertEqual(float(radius.group(1)), meta['case_radius'])

    def test_source_painting_is_recorded(self):
        readme = (ROOT / 'spec/assets/card_time_watch/README.md').read_text()
        digest = hashlib.sha256((ROOT / 'spec/assets/card_time_watch/watch_source.png').read_bytes()).hexdigest()
        self.assertIn(digest, readme)
        self.assertEqual(json.loads((ROOT / 'assets/art/ui/card_time_watch.json').read_text())['source'],
                         'spec/assets/card_time_watch/watch_source.png')


if __name__ == '__main__':
    unittest.main()
