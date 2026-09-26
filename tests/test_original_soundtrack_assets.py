"""Guard the approved original soundtrack copies and their immutable sources."""
import hashlib
import json
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[1]
MUSIC = ROOT / 'assets/audio/music'


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


class OriginalSoundtrackAssets(unittest.TestCase):
    def test_approved_tracks_are_exact_copies_of_verified_auditions(self):
        approval = json.loads((MUSIC / 'ORIGINAL_SOUNDTRACKS_APPROVAL.json').read_text())
        self.assertEqual(approval['status'], 'approved_for_game_integration')
        self.assertEqual({(t['title'], t['version']) for t in approval['tracks']}, {
            ('Lanterns Below', 'v02'), ('The Turning Key', 'v02'),
            ('Ashen Pursuit', 'v03'), ('Thorns in the Dark', 'v02')})
        for track in approval['tracks']:
            source = ROOT / track['source']
            manifest = json.loads((ROOT / track['source_manifest']).read_text())
            for rel, expected in manifest['inputs_sha256'].items():
                self.assertEqual(sha(ROOT / rel), expected, rel)
            render = json.loads((source / 'render.json').read_text())
            for name, expected in render['artifacts_sha256'].items():
                self.assertEqual(sha(source / name), expected, name)
            self.assertEqual(sha(ROOT / track['asset']), track['ogg_sha256'])
            self.assertEqual((ROOT / track['asset']).read_bytes(), (source / 'preview.ogg').read_bytes())
            self.assertEqual(sha(source / 'preview.flac'), track['flac_sha256'])
            self.assertEqual(sha(source / 'arrangement.mid'), track['midi_sha256'])
            self.assertIn('loop=true', (ROOT / (track['asset'] + '.import')).read_text())

    def test_main_menu_and_defeat_remain_exactly_preserved(self):
        for name, expected in {
            'mussorgsky_old_castle_main_menu.ogg': '57fabef2f4298b22ef7477e18b261702152483c9cb7aabe43acd99ece952fdc8',
            'chopin_op35_funeral_march_death_loop.ogg': 'f005bda46c395579b32f0afeb749b5e16775efa2ecee5203e2a4bacd872b2569',
        }.items():
            self.assertEqual(sha(MUSIC / name), expected)


if __name__ == '__main__':
    unittest.main()
