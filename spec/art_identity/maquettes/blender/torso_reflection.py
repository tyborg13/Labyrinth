"""Reflect pixel centres around a projected torso centreline (pixel edges)."""
import numpy as np

from .facing import FACING_DEFAULTS


def asymmetry(mask, centreline):
    a, b = np.asarray(centreline)
    yy, xx = np.indices(mask.shape)
    if abs(b[1] - a[1]) < FACING_DEFAULTS['epsilon']:
        raise ValueError('Cannot project a horizontal torso centreline')
    centre_x = a[0] + (yy + .5 - a[1]) * (b[0] - a[0]) / (b[1] - a[1])
    mirror_x = np.rint(2 * centre_x - (xx + .5) - .5).astype(int)
    valid = (mirror_x >= 0) & (mirror_x < mask.shape[1])
    reflected = mask[yy, np.clip(mirror_x, 0, mask.shape[1] - 1)] & valid
    union = np.count_nonzero(mask | reflected)
    left = int(np.count_nonzero(mask & (xx + .5 < centre_x)))
    right = int(np.count_nonzero(mask & (xx + .5 >= centre_x)))
    return {'left_area_px': left, 'right_area_px': right,
            'area_imbalance': abs(left - right) / max(left + right, 1),
            'mirror_difference': float(np.count_nonzero(mask ^ reflected) / max(union, 1))}


def passes_asymmetry(report):
    return report['mirror_difference'] >= FACING_DEFAULTS['asymmetry_min']
