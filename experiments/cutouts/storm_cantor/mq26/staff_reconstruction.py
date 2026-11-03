"""Director feedback 1: continue the straight shaft behind the gripping fist.

The two registered cross-sections are source-paint measurements. Rows in the
upper/lower half reuse the nearest respective cross-section byte for byte;
only their position follows the line through the section centres. No generated
paint, colour interpolation or fist texels are used.
"""
import numpy as np
from PIL import Image
from cutout_pipeline.cases import write_json

SECTIONS = {'front': ((97, 72, 77), (113, 73, 78)),
            'rear': ((108, 174, 180), (124, 173, 179))}
CROP_ZOOM = 4


def apply(view, painting, staff, fist, proof):
    (top, left, right), (bottom, low_left, low_right) = SECTIONS[view]
    sections = [painting[top, left:right].copy(), painting[bottom, low_left:low_right].copy()]
    assert all(np.all(section[:, 3] == 255) for section in sections)
    centres = ((left + right) / 2., (low_left + low_right) / 2.)
    result = staff.copy(); supplied = []
    for y in range(top + 1, bottom):
        section = sections[int(y > (top + bottom) / 2.)]
        centre = centres[0] + (centres[1] - centres[0]) * (y - top) / (bottom - top)
        x0 = int(np.floor(centre - len(section) / 2. + .5))
        for index, rgba in enumerate(section):
            x = x0 + index
            # Existing visible shaft texels are immutable. The new material is
            # exclusively behind the source fist, so source rest stays exact.
            if fist[y, x, 3] and not staff[y, x, 3]:
                result[y, x] = rgba; supplied.append([x, y])
    # Crop includes the visible sections and the complete hidden continuation.
    crop = (min(left, low_left) - 3, top - 3, max(right, low_right) + 3, bottom + 4)
    image = Image.fromarray(result).crop(crop)
    image.resize((image.width*CROP_ZOOM, image.height*CROP_ZOOM), Image.Resampling.NEAREST).save(proof/f'{view}_shaft_reconstruction_x4.png')
    return result, {'sections': [list(s) for s in SECTIONS[view]], 'split_y': (top+bottom)/2.,
                    'added_pixels': supplied, 'rest_occluded_pixels': len(supplied),
                    'rule': 'Nearest visible shaft cross-section, split at midpoint; exact source RGBA on the line through their centres.'}
