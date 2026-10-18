"""Mutation coverage for the strict eight-pixel presented-frame gate."""
from pathlib import Path
import sys
import unittest
import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'experiments/cutouts/burrow_grub'))
from rr12_stray import small_components

FIXTURE_SIZE = 32


class StrayPixelTests(unittest.TestCase):
    def body(self):
        mask = np.zeros((FIXTURE_SIZE, FIXTURE_SIZE), dtype=bool)
        mask[2:18, 2:18] = True
        return mask

    def test_attached_detail_passes(self):
        mask = self.body()
        mask[17:20, 17] = True
        self.assertEqual(small_components(mask), [])

    def test_every_detached_size_one_through_eight_fails(self):
        for count in range(1, 9):
            mask = self.body()
            mask[20, 20:20 + count] = True
            self.assertEqual(small_components(mask), [count])

    def test_one_pixel_gap_has_no_historical_distance_allowance(self):
        mask = self.body()
        mask[2, 19] = True
        self.assertEqual(small_components(mask), [1])

    def test_larger_component_belongs_to_existing_silhouette_gate(self):
        mask = self.body()
        mask[20:23, 20:23] = True
        self.assertEqual(small_components(mask), [])


if __name__ == '__main__':
    unittest.main()
