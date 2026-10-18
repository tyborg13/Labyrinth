"""Director-authored covered-edge depths; continuation uses existing texels."""
import numpy as np

from maquette_motion.silhouette import dilate
from .materials import connected_mask


def translate(mask, x, y):
    result = np.zeros_like(mask)
    h, w = mask.shape
    result[max(0,y):min(h,h+y), max(0,x):min(w,w+x)] = mask[max(0,-y):min(h,h-y), max(0,-x):min(w,w-x)]
    return result


def required_tuck(name, visible, joints, policy, occlusion=None, continuation=None):
    recipe = policy['pieces'][name]
    base_px = policy['base_px']
    own = visible[name][..., 3] > 0
    covers = recipe['covers']
    if isinstance(covers, str): covers = (covers,)
    cover = np.logical_or.reduce([visible[n][..., 3] > 0 for n in covers]) if occlusion is None else occlusion
    depth = recipe['depth_px']
    if recipe['mode'] in ('wrist', 'foot'):
        if recipe['mode'] == 'wrist':
            start, end = recipe['axis_joints']
            axis = np.asarray(joints[end]['position']) - joints[start]['position']
            axis = axis / np.linalg.norm(axis)
        else:
            axis = np.asarray(recipe['axis'])
        if recipe['mode'] == 'wrist':
            # Extend the existing base continuation without narrowing its
            # transverse width or leaving the cuff's lower corner uncovered.
            base = own | (dilate(own, base_px, grid_distance=True) & cover)
            extended = base.copy()
            extra = depth - base_px
        else:
            # Retain the full covered heel/toe width as well as the upward
            # continuation; the feedback-5 hem seam opens at its side.
            base = own | (dilate(own, base_px, grid_distance=True) & cover)
            extended = base.copy()
            extra = depth
        for row in range(1, extra + 1):
            # Source whole-pixel rows along the authored forearm axis.
            offset = np.copysign(np.floor(np.abs(axis * row) + .5), axis).astype(int)
            extended |= translate(base, *offset)
    elif recipe['mode'] == 'hem':
        # Deepen the existing covered cloth, including rr-05 seed coverage.
        # Growing visible ownership alone misses the belt-side continuation.
        base = own | (dilate(own, base_px, grid_distance=True) & cover)
        if continuation is not None: base |= continuation
        extended = dilate(base, depth - base_px, grid_distance=True)
        # Retain the authored top, deepen its covered sides and continue the
        # lower hem beneath the case's rigid feet.
        side_band = dilate(base, depth - base_px + recipe['side_extension_px'], grid_distance=True) & cover
        foot_cover = np.logical_or.reduce([visible[foot][..., 3] > 0 for foot in recipe['feet']])
        extended |= side_band | (dilate(own, recipe['hem_join_px'], grid_distance=True) & foot_cover)
        cover |= foot_cover
    elif recipe['mode'] == 'inner_edge':
        # Deepen only the inner/chest edge. The existing shoulder tuck is
        # retained; all extra texels remain underneath torso paint at rest.
        base = own | (dilate(own, depth, grid_distance=True) & cover)
        if continuation is not None: base |= continuation
        extended = dilate(base, recipe['extension_px'], grid_distance=True)
    else:
        extended = dilate(own, depth, grid_distance=True)
    return connected_mask(own, extended & cover & ~own)
