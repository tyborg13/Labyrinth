"""Genuine flat mortar pixels over the unoccluded native head silhouette."""
import numpy as np
from spec.art_identity.maquettes.blender.pixel_coverage import COVERAGE_DEFAULTS


def overlap(spec, rgba, head_solo):
    pixels = np.asarray(rgba).astype(int)
    linear = np.array(spec['labels']['mortar'])
    colour = np.rint(np.where(linear <= .0031308, linear * 12.92,
                              1.055 * linear ** (1 / 2.4) - .055) * 255)
    genuine = ((abs(pixels[:, :, :3] - colour).max(-1) <= COVERAGE_DEFAULTS['srgb_channel_tolerance']) &
               (pixels[:, :, 3] >= COVERAGE_DEFAULTS['alpha_threshold']))
    return {'head_solo_pixels': int(head_solo.sum()),
            'genuine_mortar_over_head_pixels': int((genuine & head_solo).sum())}
