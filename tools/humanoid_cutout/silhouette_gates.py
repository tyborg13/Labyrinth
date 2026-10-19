"""Native boundary ownership and director-calibrated silhouette gates.

All paint masks come from isolated GPU captures. Bone segments only name the
upper/fore regions of a single sleeve; they never deform or rasterize paint.
"""
import numpy as np

from .anatomy import owner_ids
from maquette_motion.material_palette import luma
from maquette_motion.silhouette import components, dilate, holes

# rr-10 director feedback 3. Distances are native/source pixels, Euclidean.
JOINT_BOUNDARY_FRACTION = .8
JOINT_NEIGHBOURHOOD_PX = 3
OUTLINE_COMPONENT_MAX_PIXELS = 2
OUTLINE_COMPONENT_MAX_LUMA = .12
OUTLINE_COMPONENT_DISTANCE_PX = 2
class OwnedPixels(np.ndarray):
    """Carry the case vocabulary with diagnostic pixels, including old callers."""
    def __array_finalize__(self, source):
        self.ownership = getattr(source, 'ownership', None)


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


def posed_owners(layers, parts, bones, source_offset, ownership=None):
    """Name each visible native boundary texel, including hidden continuations.

    Sleeves are single meshes containing two joined segments. Nearest posed
    segment names their boundary sides; this is not a CPU skin/raster oracle.
    The origin is the existing proof camera's source offset.
    """
    if ownership is None:
        ownership = parts[0]['proof_ownership']
    ids = owner_ids(ownership)
    logical = {part['name']: part['logical_part'] for part in parts}
    owners = np.zeros(layers[0][1].shape[:2], dtype=np.uint8).view(OwnedPixels)
    owners.ownership = ownership
    for row, image, _ in sorted(layers, key=lambda item: item[0]['z_index']):
        name = logical[row['name']]
        y, x = np.nonzero(image[..., 3] > 0)
        if name in ownership['segments']:
            segment = ownership['segments'][name]
            upper, fore, hand = [np.asarray(bones[bone]['global'][4:]) + source_offset
                                 for bone in segment['joints']]
            points = np.column_stack((x + .5, y + .5))
            is_fore = segment_distance(points, fore, hand) < segment_distance(points, upper, fore)
            first, second = segment['owners']
            owners[y, x] = np.where(is_fore, ids[second], ids[first])
        else:
            owners[y, x] = ids[name]
    return owners


def joined_boundary(hole, occupied, owners, ownership=None):
    if ownership is None: ownership = owners.ownership
    ids = owner_ids(ownership)
    # Four-neighbour boundary matches the background's four-connectivity.
    boundary = owners[dilate(hole, 1) & occupied]
    if not len(boundary) or any(ids[n] in boundary for n in ownership['free_space_owners']):
        return False
    for first, second in ownership['joint_pairs']:
        a, b = ids[first], ids[second]
        if a in boundary and b in boundary:
            count = np.count_nonzero((boundary == a) | (boundary == b))
            if count >= JOINT_BOUNDARY_FRACTION * len(boundary):
                return True
    return False


def joint_holes(occupied, seam, owners, references=(), ownership=None, *, pocket_details=False):
    """Only new, joint-local holes bounded >=80% by one actual joint pair.

    Held-item openings and unjoined free space are unrestricted. Existing
    holes still match their transported GPU rest references one-to-one.
    """
    near = dilate(seam, JOINT_NEIGHBOURHOOD_PX)
    remaining = list(references)
    defects = []
    for hole in holes(occupied):
        size = int(hole.sum())
        # Locality means touching the seam band. Growing a real joint tear
        # beyond that band must never turn it into an exempt large opening.
        if size <= 1 or not (hole & near).any() or not joined_boundary(hole, occupied, owners, ownership):
            continue
        overlaps = [int((hole & old).sum()) for old in remaining]
        if overlaps and max(overlaps):
            remaining.pop(int(np.argmax(overlaps)))
        else:
            if pocket_details:
                ys, xs = np.nonzero(hole)
                defects.append({'bbox': [int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1],
                                'pixel_count': size})
            else:
                defects.append(size)
    return defects
