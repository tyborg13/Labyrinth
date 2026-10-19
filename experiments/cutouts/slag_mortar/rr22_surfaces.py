"""Director feedback 1: measured paint ownership and chroma-key cleanup.

All ownership decisions come from the supplied HSV bands, maquette labels and
painted bracer edge. This module never changes the protected paintings.
"""
import numpy as np
from maquette_motion.bleed import edge_texels
from maquette_motion.silhouette import components
from maquette_motion.continuity import adjacent_counts

RESIDUE_MARGIN = 12
RESIDUE_RATIO_NUMERATOR = 3
RESIDUE_RATIO_DENOMINATOR = 2
IRON_SATURATION_MAX = 0.25
MOLTEN_HUE_MIN_DEG = 15
MOLTEN_HUE_MAX_DEG = 50
MOLTEN_VALUE_MIN = 0.55
SPECK_PIXELS_EXCLUSIVE = 4


def hsv(image):
    rgb = np.asarray(image)[..., :3].astype(float) / 255
    value, minimum = rgb.max(-1), rgb.min(-1)
    delta = value - minimum
    saturation = np.divide(delta, value, out=np.zeros_like(delta), where=value != 0)
    hue = np.zeros_like(value)
    for index, numerator, base in [(0, rgb[..., 1] - rgb[..., 2], 0),
                                    (1, rgb[..., 2] - rgb[..., 0], 2),
                                    (2, rgb[..., 0] - rgb[..., 1], 4)]:
        selected = (rgb.argmax(-1) == index) & (delta != 0)
        hue[selected] = (numerator[selected] / delta[selected] + base) * 60
    return hue % 360, saturation, value


def residue_mask(image):
    rgba = np.asarray(image).astype(np.int16)
    other = np.maximum(rgba[..., 0], rgba[..., 2])
    return ((rgba[..., 3] > 0) & (rgba[..., 1] >= other + RESIDUE_MARGIN) &
            (RESIDUE_RATIO_DENOMINATOR * rgba[..., 1] >= RESIDUE_RATIO_NUMERATOR * other))


def clean_residue(image, feature=None):
    """Nearest non-residue donor of this same piece; keep source alpha/shape."""
    result = np.asarray(image).copy()
    selected = residue_mask(result)
    target = selected & ~feature if feature is not None else selected
    if target.any():
        donor = result.copy()
        donor[selected] = 0
        if not (donor[..., 3] > 0).any(): raise ValueError('No non-residue donor in this piece')
        replacement = edge_texels(donor, target)
        result[..., :3][target] = replacement[..., :3][target]
    return result, int(target.sum())


def molten_mask(paint):
    hue, _, value = hsv(paint)
    return ((paint[..., 3] > 0) & (hue >= MOLTEN_HUE_MIN_DEG) &
            (hue <= MOLTEN_HUE_MAX_DEG) & (value > MOLTEN_VALUE_MIN))


def nearest_labels(owners, selected, candidates):
    """Exact Euclidean nearest label, row/column tie order (rr-05 donor rule)."""
    seed = np.zeros((*owners.shape, 4), dtype=np.uint8)
    available = np.isin(owners, candidates)
    seed[..., 0][available] = owners[available] + 1
    seed[..., 3][available] = 255
    result = edge_texels(seed, selected)
    return result[..., 0].astype(int) - 1


def absorb_specks(owners, names):
    """Only isolated components smaller than the director's four-pixel limit."""
    result, transfers = owners.copy(), []
    for index, name in enumerate(names):
        labelled, groups = components(result == index)
        for label, size in groups[1:]:
            if size >= SPECK_PIXELS_EXCLUSIVE: continue
            fragment = labelled == label
            counts = adjacent_counts(fragment, result, len(names))
            counts[index] = 0
            if counts.max():
                destination = int(counts.argmax())
                result[fragment] = destination
                transfers.append({'from': name, 'to': names[destination], 'pixels': size})
    return result, transfers


def front_mortar(paint, owners, names):
    mortar = names.index('mortar')
    _, saturation, _ = hsv(paint)
    region = owners == mortar
    retained = region & ((saturation < IRON_SATURATION_MAX) | molten_mask(paint))
    changed = region & ~retained
    assigned = nearest_labels(owners, changed, [names.index('torso'), names.index('upper_near')])
    result = owners.copy()
    result[changed] = assigned[changed]
    return result, {'region_pixels': int(region.sum()), 'retained_pixels': int(retained.sum()),
                    'transferred_pixels': int(changed.sum())}


def rear_fist(paint, owners, names, joints):
    near = [names.index(n) for n in ('upper_near', 'fore_near', 'hand_near')]
    arm = np.isin(owners, near)
    _, saturation, _ = hsv(paint)
    neutral = arm & (owners == names.index('fore_near')) & (saturation < IRON_SATURATION_MAX)
    labelled, groups = components(neutral)
    bracer = labelled == groups[0][0]
    elbow, wrist = [np.asarray(joints[n]['position'], dtype=float) for n in ('fore_near', 'hand_near')]
    axis = wrist - elbow
    axis /= np.linalg.norm(axis)
    across = np.array([-axis[1], axis[0]])
    yy, xx = np.indices(owners.shape)
    point = np.stack((xx + .5, yy + .5), -1) - elbow
    along = np.sum(point * axis, -1)
    column = np.floor(np.sum(point * across, -1)).astype(int)
    columns = np.unique(column[bracer])
    rim = np.array([along[bracer & (column == c)].max() for c in columns])
    # Extend only the painted lower-rim contour across the arm's silhouette.
    # The nearest source column supplies edge pixels outside the bracer width.
    closest = np.abs(column[..., None] - columns).argmin(-1)
    lower_edge = rim[closest]
    fist = arm & (along > lower_edge) & ~bracer
    result = owners.copy()
    result[bracer] = names.index('fore_near')
    result[fist] = names.index('hand_near')
    return result, {'bracer_pixels': int(bracer.sum()), 'fist_pixels': int(fist.sum()),
        'transferred_pixels': int((result != owners).sum()), 'axis': axis.tolist(),
        'rim_columns': columns.tolist(), 'rim_along_px': rim.tolist()}


def resolve(paint, owners, names, joints, view):
    if view == 'front': result, details = front_mortar(paint, owners, names)
    else: result, details = rear_fist(paint, owners, names, joints)
    result, specks = absorb_specks(result, names)
    return result, {'rule': 'front_crucible_colour' if view == 'front' else 'rear_bracer_lower_rim',
                    **details, 'speck_transfers': specks}


def connect_covered(visible, hidden, paint, depth, definition):
    """Connect a logical piece only through covered, existing three-pixel tucks.

    The rule's colour labels can leave separated visible islands. A piece is
    continuous beneath its occluders: no source ownership or rest alpha moves.
    Every new texel is inside the approved rest and within the declared tuck
    distance of that same piece, and borrows that piece's own non-outline paint.
    """
    from collections import deque
    from maquette_motion.silhouette import dilate
    union = (visible[..., 3] > 0) | (hidden[..., 3] > 0)
    allowed = dilate(union, depth) & (paint[..., 3] > 0)
    added = np.zeros_like(union)
    labelled, groups = components(union)
    while len(groups) > 1:
        main = labelled == groups[0][0]
        other = union & ~main
        previous = np.full((*union.shape, 2), -1, dtype=np.int16)
        seen = main.copy()
        queue = deque(map(tuple, np.argwhere(main)))
        end = None
        while queue and end is None:
            y, x = queue.popleft()
            for dy, dx in ((-1,-1), (-1,0), (-1,1), (0,-1), (0,1), (1,-1), (1,0), (1,1)):
                ny, nx = y + dy, x + dx
                if not (0 <= ny < union.shape[0] and 0 <= nx < union.shape[1]): continue
                if seen[ny, nx] or not allowed[ny, nx]: continue
                seen[ny, nx] = True
                previous[ny, nx] = [y, x]
                if other[ny, nx]:
                    end = (ny, nx)
                    break
                queue.append((ny, nx))
        if end is None: raise ValueError('Piece cannot connect inside its declared covered tuck')
        at = end
        while not main[at]:
            if not union[at]: added[at] = True
            at = tuple(previous[at])
        union |= added
        labelled, groups = components(union)
    result = hidden.copy()
    if added.any():
        donors = hidden.copy()
        donors[visible[..., 3] > 0] = visible[visible[..., 3] > 0]
        replacement = edge_texels(donors, added, definition)
        result[added] = replacement[added]
    return result, added
