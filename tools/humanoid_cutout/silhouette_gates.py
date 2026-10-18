"""Native boundary ownership and director-calibrated silhouette gates.

All paint masks come from isolated GPU captures. Bone segments only name the
upper/fore regions of a single sleeve; they never deform or rasterize paint.
"""
import numpy as np

from maquette_motion.material_palette import luma
from maquette_motion.silhouette import components, dilate, holes

# rr-10 director feedback 3. Distances are native/source pixels, Euclidean.
JOINT_BOUNDARY_FRACTION = .8
JOINT_NEIGHBOURHOOD_PX = 3
OUTLINE_COMPONENT_MAX_PIXELS = 2
OUTLINE_COMPONENT_MAX_LUMA = .12
OUTLINE_COMPONENT_DISTANCE_PX = 2
OWNER_NAMES = ('head', 'torso', 'upper_near', 'fore_near', 'upper_far',
               'fore_far', 'hand_near', 'hand_far', 'staff', 'robe',
               'foot_near', 'foot_far')
OWNER_IDS = {name: index + 1 for index, name in enumerate(OWNER_NAMES)}
JOINT_PAIRS = (('torso', 'head'), ('torso', 'robe'),
               ('robe', 'foot_near'), ('robe', 'foot_far')) + tuple(
    pair for side in ('near', 'far') for pair in (
        ('torso', 'upper_' + side), ('upper_' + side, 'fore_' + side),
        ('fore_' + side, 'hand_' + side)))


def detached_metrics(image):
    """Exempt only tiny dark outlines within 2 px of the main body."""
    labels, groups = components(image[..., 3] > 0, 8)
    result = {'stray_components': 0, 'stray_pixels': 0,
              'exempt_outline_components': 0}
    if not groups:
        return result
    nearby = dilate(labels == groups[0][0], OUTLINE_COMPONENT_DISTANCE_PX)
    dark = luma(image) / 255 < OUTLINE_COMPONENT_MAX_LUMA
    for label, size in groups[1:]:
        component = labels == label
        if (size <= OUTLINE_COMPONENT_MAX_PIXELS and dark[component].all()
                and nearby[component].any()):
            result['exempt_outline_components'] += 1
        else:
            result['stray_components'] += 1
            result['stray_pixels'] += size
    return result


def segment_distance(points, start, end):
    direction = end - start
    projection = np.clip(np.sum((points - start) * direction, axis=1) / np.sum(direction * direction), 0, 1)
    return np.sum((points - start - projection[:, None] * direction) ** 2, axis=1)


def posed_owners(layers, parts, bones, source_offset):
    """Name each visible native boundary texel, including hidden continuations.

    Sleeves are single meshes containing two joined segments. Nearest posed
    segment names their boundary sides; this is not a CPU skin/raster oracle.
    The origin is the existing proof camera's source offset.
    """
    logical = {part['name']: part['logical_part'] for part in parts}
    owners = np.zeros(layers[0][1].shape[:2], dtype=np.uint8)
    for row, image, _ in sorted(layers, key=lambda item: item[0]['z_index']):
        name = logical[row['name']]
        y, x = np.nonzero(image[..., 3] > 0)
        if name.startswith('sleeve_'):
            side = name.split('_')[-1]
            upper, fore, hand = [np.asarray(bones[bone + side]['global'][4:]) + source_offset
                                 for bone in ('upper_', 'fore_', 'hand_')]
            points = np.column_stack((x + .5, y + .5))
            is_fore = segment_distance(points, fore, hand) < segment_distance(points, upper, fore)
            owners[y, x] = np.where(is_fore, OWNER_IDS['fore_' + side], OWNER_IDS['upper_' + side])
        else:
            owners[y, x] = OWNER_IDS[name]
    return owners


def joined_boundary(hole, occupied, owners):
    # Four-neighbour boundary matches the background's four-connectivity.
    boundary = owners[dilate(hole, 1) & occupied]
    if not len(boundary) or OWNER_IDS['staff'] in boundary:
        return False
    for first, second in JOINT_PAIRS:
        a, b = OWNER_IDS[first], OWNER_IDS[second]
        if a in boundary and b in boundary:
            count = np.count_nonzero((boundary == a) | (boundary == b))
            if count >= JOINT_BOUNDARY_FRACTION * len(boundary):
                return True
    return False


def joint_holes(occupied, seam, owners, references=()):
    """Only new, joint-local holes bounded >=80% by one actual joint pair.

    Staff-bounded openings and unjoined free space are unrestricted. Existing
    holes still match their transported GPU rest references one-to-one.
    """
    near = dilate(seam, JOINT_NEIGHBOURHOOD_PX)
    remaining = list(references)
    defects = []
    for hole in holes(occupied):
        size = int(hole.sum())
        if size <= 1 or (hole & ~near).any() or not joined_boundary(hole, occupied, owners):
            continue
        overlaps = [int((hole & old).sum()) for old in remaining]
        if overlaps and max(overlaps):
            remaining.pop(int(np.argmax(overlaps)))
        else:
            defects.append(size)
    return defects
