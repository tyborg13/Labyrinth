"""Repair demonstrated source-label islands; never edit approved paint."""
import numpy as np

from maquette_motion.silhouette import components, dilate


def transfer(visible, records):
    for row in records:
        source, owner = visible[row['source']], visible[row['owner']]
        labels, _ = components(source[..., 3] > 0, 8)
        x, y = row['seed']
        label = labels[y, x]
        if not label:
            raise ValueError('Missing source edge: ' + str(row))
        mask = labels == label
        ys, xs = np.nonzero(mask)
        bounds = [int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1]
        if int(mask.sum()) != row['pixels'] or bounds != row['bbox']:
            raise ValueError('Changed source edge: ' + str(row))
        if not (dilate(mask, 1, grid_distance=True) & (owner[..., 3] > 0)).any():
            raise ValueError('Source edge is not adjacent to its owner: ' + str(row))
        owner[mask] = source[mask]
        source[mask] = 0
