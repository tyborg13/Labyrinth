"""Optional case-owned chroma-residue gate; existing figures keep their rules."""
import numpy as np


def green_dominant(image, margin):
    rgb = np.asarray(image)[..., :3].astype(np.int16)
    return ((np.asarray(image)[..., 3] > 0) & (rgb[..., 1] > rgb[..., 0] + margin)
            & (rgb[..., 1] > rgb[..., 2] + margin))


def colour_errors(image, policy):
    if 'green_dominance_margin' not in policy:
        return []
    count = int(green_dominant(image, policy['green_dominance_margin']).sum())
    return [f'green-dominant texels: {count}'] if count else []
