"""Rest-covered cloth domains, derived from the approved source outlines.

These are source masks, never posed mesh rasters. A sleeve can uncover its
whole rest footprint; a short dilation of the visible chest edge is not a
continuation of that surface.
"""
import numpy as np

from .materials import connected_mask


def row_outline(mask):
    """Close internal ownership gaps without widening the source outline."""
    result = np.zeros_like(mask)
    for y in np.flatnonzero(mask.any(axis=1)):
        xs = np.flatnonzero(mask[y])
        result[y, xs[0]:xs[-1] + 1] = True
    return result


def extend_down(outline, bottom):
    result = outline.copy()
    rows = np.flatnonzero(outline.any(axis=1))
    if len(rows) and bottom > rows[-1]:
        result[rows[-1] + 1:bottom + 1] = outline[rows[-1]]
    return result


def sleeve_domains(visible, solos, roles):
    upper, lower = roles['upper'], roles['lower']
    """Cover both full sleeve footprints, within torso/robe source outlines.

    The torso outline continues to the robe top. All additions are clipped to
    the covering sleeves' painted alpha, so they cannot change a rest pixel.
    """
    own = {name: image[..., 3] > 0 for name, image in visible.items()}
    rest = np.logical_or.reduce(list(own.values()))
    sleeves = np.logical_or.reduce([own[n] | solos[n] for n in roles['arms']]) & rest
    robe_top = int(np.flatnonzero(own[lower].any(axis=1))[0])
    torso = extend_down(row_outline(solos[upper] | own[upper]), robe_top)
    # At the waist the robe must continue beneath the same sleeve footprint,
    # even where categorical rest ownership made its top narrower than the
    # chest. Use the torso's outline only from the existing robe top down.
    waist = torso.copy()
    waist[:robe_top] = False
    robe = row_outline(solos[lower] | own[lower] | waist)
    return {
        upper: connected_mask(own[upper], torso & sleeves & ~own[upper]),
        # The covered waist joins the sleeve footprint back to the robe;
        # clipping to sleeve ownership alone creates hidden-only islands.
        lower: connected_mask(own[lower], robe & (sleeves | own[upper]) & ~own[lower]),
    }


def hem_domain(visible, robe_outline, roles):
    """Continue the hem beneath the full covered boot tops, including steps.

    The existing hem dilation can miss the inside of a boot's rest footprint.
    The covered layer shares the robe field and stays behind the rigid boots.
    """
    own = visible[roles['lower']][..., 3] > 0
    feet = np.logical_or.reduce([visible[n][..., 3] > 0 for n in roles['feet']])
    rows = np.flatnonzero(feet.any(axis=1))
    outline = row_outline(robe_outline | own)
    if len(rows):
        outline = extend_down(outline, int(rows[-1]))
    return connected_mask(own, outline & feet & ~own)
