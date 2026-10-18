"""Deepen an existing, connected cloth surface beneath named rest covers."""
import numpy as np

from maquette_motion.silhouette import dilate
from .materials import connected_mask


def domains(visible, hidden, joins, *, depth_px, bounded_pieces):
    result = {}
    for name, recipe in joins.items():
        own = visible[name][..., 3] > 0
        base = own | (hidden[name][..., 3] > 0)
        cover = np.logical_or.reduce([visible[other][..., 3] > 0 for other in recipe['covers']])
        seed = np.zeros_like(own)
        for x, y in recipe['source_points']:
            seed[y, x] = True
        target = dilate(seed, depth_px, grid_distance=True) & cover & ~own
        if name in bounded_pieces:
            # Keep the existing garment grid and weight field unchanged. New
            # texels here are inside that field, not a new deformation recipe.
            ys, xs = np.nonzero(base)
            bounds = np.zeros_like(base)
            bounds[ys.min():ys.max() + 1, xs.min():xs.max() + 1] = True
            target &= bounds
        result[name] = connected_mask(base, target)
    return result
