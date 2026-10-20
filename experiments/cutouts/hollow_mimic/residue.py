"""Director feedback 1: remove only chroma-key residue from derived paint.

Distance is Euclidean in registered source pixels. Equidistant donors use
row/column order for reproducibility. Features remain unchanged and never
supply residue-coloured donors to the rest of a piece.
"""
import numpy as np
from PIL import Image

GREEN_MARGIN = 12
GREEN_RATIO_NUMERATOR = 3
GREEN_RATIO_DENOMINATOR = 2


def residue_mask(image):
    rgba = np.asarray(image).astype(np.int32)
    other = np.maximum(rgba[..., 0], rgba[..., 2])
    return ((rgba[..., 3] > 0) & (rgba[..., 1] >= other + GREEN_MARGIN) &
            (GREEN_RATIO_DENOMINATOR * rgba[..., 1] >= GREEN_RATIO_NUMERATOR * other))


def count(image, features=None):
    mask = residue_mask(image)
    if features is not None: mask &= ~np.asarray(features, dtype=bool)
    return int(mask.sum())


def feature_mask(case, layout, piece=None):
    width, height = layout['canvas_size']
    result = np.zeros((height, width), dtype=bool)
    for feature in layout.get('features', []):
        if piece is None or feature['piece'] == piece:
            image = Image.open(case / feature['mask'])
            mask = np.asarray(image.getchannel('A') if 'A' in image.getbands() else image.convert('L')) > 0
            if mask.shape != result.shape: raise ValueError('Feature mask dimensions differ: ' + feature['name'])
            result |= mask
    return result


def clean_piece(visible, hidden, features=None):
    """Clean one logical piece and its fills with the same registered donors."""
    combined = hidden.copy()
    combined[visible[..., 3] > 0] = visible[visible[..., 3] > 0]
    residue = residue_mask(combined)
    targets = residue.copy()
    if features is not None: targets &= ~np.asarray(features, dtype=bool)
    donors = np.argwhere((combined[..., 3] > 0) & ~residue)
    if targets.any() and not len(donors): raise ValueError('Piece has no non-residue donor')
    layers = [visible.copy(), hidden.copy()]
    replacements = []
    for y, x in np.argwhere(targets):
        donor_y, donor_x = donors[np.argmin(np.sum((donors - [y, x]) ** 2, axis=1))]
        for image in layers:
            if image[y, x, 3]: image[y, x, :3] = combined[donor_y, donor_x, :3]
        replacements.append({'at': [int(x), int(y)], 'donor': [int(donor_x), int(donor_y)]})
    return *layers, replacements
