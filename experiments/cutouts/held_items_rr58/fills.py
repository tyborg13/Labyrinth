"""Director feedback 1: integer copies of each item's own existing paint.

Recipes describe source registration, never motion. A ledger stores every
source/destination coordinate so raw and density-treated paint use the same
ownership operation without generating colours or filtering texels.
"""
import numpy as np

# Nearest complete, equally oriented ring below each truncated top link.
# Endpoints are native outer arc ends, paired with the existing cut ends.
CHAIN_ARCS = {
    'front': {'source_region': [81, 166, 98, 169], 'translation': [-1, -21],
              'donor_ends': [[82, 168], [96, 168]], 'cut_ends': [[80, 148], [95, 148]]},
    'rear': {'source_region': [161, 177, 178, 181], 'translation': [0, -17],
             'donor_ends': [[162, 180], [176, 180]], 'cut_ends': [[161, 164], [177, 163]]},
}


def copy_texels(image, checks, mapping):
    result, categorical = image.copy(), checks.copy()
    for x, y, u, v in mapping:
        if not image[v, u, 3]: raise ValueError('Transparent item donor')
        result[y, x] = image[v, u]
        categorical[y, x] = checks[v, u]
    return result, categorical


def chain_arc(view, image, checks, mask):
    recipe = CHAIN_ARCS[view]
    a, b, c, d = recipe['source_region']; dx, dy = recipe['translation']
    mapping, required = [], []
    for v in range(b, d):
        for u in range(a, c):
            x, y = u + dx, v + dy
            if image[v, u, 3] and not image[y, x, 3]:
                required.append([x, y, u, v])
                if mask[y, x]: mapping.append([x, y, u, v])
    ends = np.asarray(recipe['donor_ends']) + [dx, dy]
    distance = np.max(np.abs(ends - recipe['cut_ends']), axis=1)
    if (distance > 1).any(): raise ValueError('Copied chain arc ends do not meet within 1px')
    # Each missing endpoint must be in the authorised mask. Do not silently
    # accept a clipped half-arc merely because its remaining texels can copy.
    mask_complete = all(mask[y, x] for x, y, _, _ in required)
    outside_count = len(required) - len(mapping)
    clipped_count = len(mapping) if not mask_complete else 0
    if not mask_complete: mapping = []  # Retain the approved item until its whole arc fits.
    painted, categorical = copy_texels(image, checks, mapping)
    return painted, categorical, {'method': 'nearest_same_orientation_link_top_arc',
        **recipe, 'endpoint_distance_px': distance.tolist(), 'mask_complete': bool(mask_complete),
        'texels': mapping, 'source_part': 'chain', 'mirror': False, 'clipped_candidate_texels': clipped_count,
        'required_pixels': len(required), 'outside_request_pixels': outside_count}


def shaft(image, checks, mask):
    ys, xs = np.nonzero(mask)
    top, bottom = int(ys.min()), int(ys.max())
    # Adjacent exposed rows establish the existing crooked staff's local axis.
    def section(y):
        x = np.flatnonzero(image[y, :, 3])
        return x[(x >= xs.min()) & (x <= xs.max())]
    upper, lower = section(top - 1), section(bottom + 1)
    axis = [[float((upper.min() + upper.max()) / 2), top - 1],
            [float((lower.min() + lower.max()) / 2), bottom + 1]]
    middle = (top + bottom) / 2
    mapping, rows = [], []
    for y in range(top, bottom + 1):
        target = np.flatnonzero(mask[y])
        side = 'upper' if y <= middle else 'lower'
        candidates = range(top - 1, -1, -1) if side == 'upper' else range(bottom + 1, image.shape[0])
        for v in candidates:
            donor = section(v)
            if len(donor) < 3 or len(donor) > len(target) or not np.all(np.diff(donor) == 1): continue
            outline = checks[v, donor, 2] > 0
            # Partial rows at the occluding palm cut through an edge or include
            # several outline columns. Use the nearest *whole* cross-section:
            # its two outline edges surround the existing body/highlight paint.
            if not (outline[0] and outline[-1] and not outline[1:-1].any()): continue
            break
        else: raise ValueError('No same-side complete staff cross-section')
        center = np.interp(y, [axis[0][1], axis[1][1]], [axis[0][0], axis[1][0]])
        shift = int(np.floor(center - (donor.min() + donor.max()) / 2 + .5))
        shift = int(np.clip(shift, target.min() - donor.min(), target.max() - donor.max()))
        for u in donor:
            x = int(u + shift)
            if not mask[y, x]: raise ValueError('Staff copy leaves the authorised mask')
            mapping.append([x, y, int(u), v])
        rows.append({'target_y': y, 'source_y': v, 'source_x': [int(donor.min()), int(donor.max()) + 1],
                     'translation_x': shift, 'side': side})
    painted, categorical = copy_texels(image, checks, mapping)
    return painted, categorical, {'method': 'nearest_same_side_complete_cross_section',
        'axis': axis, 'midpoint_y': middle, 'rows': rows, 'texels': mapping,
        'source_part': 'staff', 'mirror': False, 'mask_complete': True}
