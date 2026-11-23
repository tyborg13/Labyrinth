"""Channel encoding for approved Electrified ramps and their crack graphs."""

import sys
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools"))
from build_atlases import GREYS, encode_electrified


class ElectrifiedChannelsTest(unittest.TestCase):
    def test_eight_connected_multisource_paths_and_fallback(self):
        width, height = 11, 8
        cracked = {
            (1, 1): 4, (2, 1): 1, (3, 2): 2, (4, 3): 0, (5, 3): 1, (6, 3): 4,
            (7, 6): 1, (8, 6): 3, (9, 7): 3, (8, 7): 2,
            (0, 7): 0,
        }
        rgba = bytearray(width * height * 4)
        for (x, y), index in cracked.items():
            offset = (y * width + x) * 4
            rgba[offset:offset + 4] = bytes((GREYS[index],) * 3 + (255,))
        original = bytes(rgba)

        encode_electrified(rgba, width, [(0, 0, width, height)], 8)

        expected = {
            (1, 1): (0, 0), (2, 1): (1, 0), (3, 2): (2, 0), (4, 3): (2, 4),
            (5, 3): (1, 4), (6, 3): (0, 0),
            (7, 6): (1, 4), (8, 6): (0, 0), (9, 7): (1, 1), (8, 7): (1, 2),
            (0, 7): (0, 0),
        }
        for (x, y), (distance, sector) in expected.items():
            offset = (y * width + x) * 4
            self.assertEqual(rgba[offset + 1:offset + 3], bytes((distance, sector * 32)), (x, y))
        self.assertEqual(rgba[0::4], original[0::4])
        self.assertEqual(rgba[3::4], original[3::4])
        encoded = bytes(rgba)
        encode_electrified(rgba, width, [(0, 0, width, height)], 8)
        self.assertEqual(rgba, encoded)

    def test_distance_saturates_and_packed_rects_do_not_connect(self):
        width = 260
        rgba = bytearray(bytes((0, 0, 0, 255)) * width)
        rgba[0] = GREYS[4]

        encode_electrified(rgba, width, [(0, 0, 258, 1), (258, 0, 2, 1)], 8)

        self.assertEqual(rgba[1::4], bytes(range(256)) + bytes((255, 255, 0, 1)))


if __name__ == "__main__":
    unittest.main()
