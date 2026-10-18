"""Director-authored covered-edge depths; continuation uses existing texels."""
import numpy as np

from maquette_motion.silhouette import dilate
from .materials import connected_mask

# rr-10 feedback 4/5. These are design inputs, not renderer tolerances.
BASE_TUCK_PX = 3  # Existing covered silhouette; extensions must never narrow it.
TORSO_SHOULDER_TUCK_PX = 4
SLEEVE_INNER_EXTENSION_PX = 3
HEM_JOIN_TUCK_PX = 3
BELT_SIDE_EXTENSION_PX = 3
TUCK_DEPTHS_PX = {'torso': TORSO_SHOULDER_TUCK_PX, 'head': 3, 'sleeve_near': 3, 'sleeve_far': 3,
                  'hand_near': 5, 'hand_far': 5, 'foot_near': 4,
                  'foot_far': 4, 'robe': 5}
TUCK_COVERS = {'torso': ('sleeve_near', 'sleeve_far', 'robe'), 'head': 'torso', 'sleeve_near': 'torso', 'sleeve_far': 'torso',
               'hand_near': 'sleeve_near', 'hand_far': 'sleeve_far',
               'foot_near': 'robe', 'foot_far': 'robe', 'robe': 'torso'}


def translate(mask, x, y):
    result = np.zeros_like(mask)
    h, w = mask.shape
    result[max(0,y):min(h,h+y), max(0,x):min(w,w+x)] = mask[max(0,-y):min(h,h-y), max(0,-x):min(w,w-x)]
    return result


def required_tuck(name, visible, joints, occlusion=None, continuation=None):
    own = visible[name][..., 3] > 0
    covers = TUCK_COVERS[name]
    if isinstance(covers, str): covers = (covers,)
    cover = np.logical_or.reduce([visible[n][..., 3] > 0 for n in covers]) if occlusion is None else occlusion
    depth = TUCK_DEPTHS_PX[name]
    if name.startswith('hand_') or name.startswith('foot_'):
        if name.startswith('hand_'):
            side = name.split('_')[-1]
            axis = np.asarray(joints['fore_' + side]['position']) - joints[name]['position']
            axis = axis / np.linalg.norm(axis)
        else:
            axis = np.array([0., -1.])
        if name.startswith('hand_'):
            # Extend the EXISTING 3 px wrist continuation by two rows, retaining
            # its transverse width. Extruding only visible skin would narrow
            # the old tuck and leave the cuff's lower corner uncovered.
            base = own | (dilate(own, BASE_TUCK_PX, grid_distance=True) & cover)
            extended = base.copy()
            extra = depth - BASE_TUCK_PX
        else:
            # Retain the full covered heel/toe width as well as the upward
            # continuation; the feedback-5 hem seam opens at its side.
            base = own | (dilate(own, BASE_TUCK_PX, grid_distance=True) & cover)
            extended = base.copy()
            extra = depth
        for row in range(1, extra + 1):
            # Source whole-pixel rows along the authored forearm axis.
            offset = np.copysign(np.floor(np.abs(axis * row) + .5), axis).astype(int)
            extended |= translate(base, *offset)
    elif name == 'robe':
        # Deepen the existing covered cloth, including rr-05 seed coverage.
        # Growing visible ownership alone misses the belt-side continuation.
        base = own | (dilate(own, BASE_TUCK_PX, grid_distance=True) & cover)
        if continuation is not None: base |= continuation
        extended = dilate(base, depth - BASE_TUCK_PX, grid_distance=True)
        # Feedback 5: preserve the five-pixel top, deepen its covered side
        # edges and continue the lower hem beneath the planted boots.
        side_band = dilate(base, depth - BASE_TUCK_PX + BELT_SIDE_EXTENSION_PX, grid_distance=True) & cover
        foot_cover = np.logical_or.reduce([visible['foot_' + side][..., 3] > 0 for side in ('near', 'far')])
        extended |= side_band | (dilate(own, HEM_JOIN_TUCK_PX, grid_distance=True) & foot_cover)
        cover |= foot_cover
    elif name.startswith('sleeve_'):
        # Deepen only the inner/chest edge. The existing shoulder tuck is
        # retained; all extra texels remain underneath torso paint at rest.
        base = own | (dilate(own, depth, grid_distance=True) & cover)
        if continuation is not None: base |= continuation
        extended = dilate(base, SLEEVE_INNER_EXTENSION_PX, grid_distance=True)
    else:
        extended = dilate(own, depth, grid_distance=True)
    return connected_mask(own, extended & cover & ~own)
