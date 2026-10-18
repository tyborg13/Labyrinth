"""Invoke the generator directly; each constraint has an independent negative."""
from pathlib import Path
import sys
import unittest

import numpy as np

PROJECT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(PROJECT / 'tools'))
from humanoid_cutout.joint_continuations import domains

FIXTURE_SIZE_PX = 16


def rgba(mask):
    image = np.zeros((*mask.shape, 4), dtype=np.uint8)
    image[mask] = 255
    return image


class ContinuationDomainTests(unittest.TestCase):
    def domain(self, own, cover, points, depth=3, bounded=False):
        return domains({'cloth': rgba(own), 'cover': rgba(cover)}, {'cloth': rgba(np.zeros_like(own))},
                       {'cloth': {'covers': ['cover'], 'source_points': points}},
                       depth_px=depth, bounded_pieces=['cloth'] if bounded else [])['cloth']

    def test_named_cover_clips_connected_continuation(self):
        own = np.zeros((FIXTURE_SIZE_PX,) * 2, dtype=bool)
        own[4:9, 5] = True
        cover = np.zeros_like(own); cover[4:9, 6:8] = True
        result = self.domain(own, cover, [[7, 6]])
        self.assertGreater(result.sum(), 0)
        self.assertFalse((result & ~cover).any())
        self.assertFalse((result & own).any())

    def test_garment_bounds_clip_even_under_a_named_cover(self):
        own = np.zeros((FIXTURE_SIZE_PX,) * 2, dtype=bool)
        own[5:10, 5] = True; own[9, 5:10] = True
        cover = np.zeros_like(own); cover[2:13, 2:13] = True
        result = self.domain(own, cover, [[7, 7]], bounded=True)
        bounds = np.zeros_like(own); bounds[5:10, 5:10] = True
        self.assertGreater(result.sum(), 0)
        self.assertFalse((result & ~bounds).any())

    def test_connectivity_discards_hidden_only_island_under_cover(self):
        own = np.zeros((FIXTURE_SIZE_PX,) * 2, dtype=bool); own[2:5, 2:5] = True
        cover = np.zeros_like(own); cover[2:5, 5:7] = True; cover[10:13, 10:13] = True
        result = self.domain(own, cover, [[5, 3], [11, 11]], depth=1)
        self.assertTrue(result[2:5, 5:7].any())
        self.assertFalse(result[10:13, 10:13].any())


if __name__ == '__main__':
    unittest.main()
