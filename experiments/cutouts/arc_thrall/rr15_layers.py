"""Keep existing native texture quads/grids fixed when adding covered paint."""
import numpy as np

from tools.humanoid_cutout.mesh import GRID_PX

EXTENSION_PREFIX = 'joint_extension_'


def split_hidden(image, allocation, garment, registration, *, mesh=False):
    name = 'hidden_' + garment
    original = registration['parts'].get(name)
    if original is None:
        return [(name, image, None, False)] if image[..., 3].any() else []
    bounds = original['bbox']
    inside = np.zeros(image.shape[:2], dtype=bool)
    inside[bounds[1]:bounds[3], bounds[0]:bounds[2]] = True
    core, extra = image.copy(), image.copy()
    core[~inside] = 0
    extra[inside] = 0
    result = [(name, core, bounds, False)] if core[..., 3].any() else []
    allocated = (allocation[..., 3] > 0) & ~inside
    if extra[..., 3].any():
        ys, xs = np.nonzero(allocated)
        crop = [int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1]
        if mesh:
            # Match the original source-grid phase, without moving its vertices.
            crop[0] -= (crop[0] - bounds[0]) % GRID_PX
            crop[1] -= (crop[1] - bounds[1]) % GRID_PX
            crop[2] = min(image.shape[1], crop[2] + (bounds[0] - crop[2]) % GRID_PX)
            crop[3] = min(image.shape[0], crop[3] + (bounds[1] - crop[3]) % GRID_PX)
        result.append((EXTENSION_PREFIX + garment, extra, crop, True))
    return result
