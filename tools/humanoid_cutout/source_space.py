"""Approved-paint negative space, using transported immutable paint/tuck masks.

The check captures use the same rigid quads or skin triangles as the paint.
Their red channel therefore answers the inverse-source occupancy question at
each presented pixel, without approximating a skinned mesh by one bone.
Joint tears remain failures; neither a rest-hole overlap nor nearby air can
excuse a missing immutable texel. No creature, clip or frame exceptions live here.
"""
import numpy as np
from PIL import Image

from maquette_motion import pixels
from maquette_motion.features import source_pixels
from maquette_motion.silhouette import components, holes


def bounds(mask):
    yy, xx = np.nonzero(mask)
    return [int(xx.min()), int(yy.min()), int(xx.max()) + 1, int(yy.max()) + 1]


def pocket_report(layers, joint_tears=()):
    """Report every pocket; a single painted/tuck pixel makes it fail.

    Existing joint-boundary detection supplies independently identified tears.
    Immutable masks also catch damage away from a named joint, including 1 px.
    """
    occupied = np.logical_or.reduce([image[..., 3] > 0 for _, image, _ in layers])
    painted = np.logical_or.reduce([(check[..., 0] > 0) & (check[..., 3] > 0)
                                   for _, _, check in layers])
    failures, air = [], []
    tear_bounds = {tuple(record['bbox']) for record in joint_tears}
    for pocket in holes(occupied):
        box = bounds(pocket)
        blocked = int((pocket & painted).sum())
        tear = tuple(box) in tear_bounds
        record = {'bbox': box, 'pixel_count': int(pocket.sum()),
                  'painted_or_tuck_pixels': blocked, 'joint_tear': tear}
        (failures if blocked or tear else air).append(record)
    return {'failures': failures, 'air_pockets': air}


class PaintedComponents:
    """Only components detached in the whole approved painting can pass.

    A cut-induced island is not a painted speck. Certified source components
    must have one rigid owner and follow that owner's sampled rigid transform.
    Skinned owners never acquire a rigid-speck exemption.
    """
    def __init__(self, case, layout):
        self.layout = layout
        source = np.asarray(Image.open(case / layout.get('raw_rest_source', layout['rest_source'])).convert('RGBA'))
        labelled, groups = components(source[..., 3] > 0)
        meshes = {mesh['name'] for mesh in layout.get('joint_meshes', [])}
        self.certified = {}
        for part in layout['parts']:
            if part['name'] in meshes or part.get('hidden_material'):
                continue
            own = source_pixels(case, part)[..., 3] > 0
            selected = np.zeros_like(own)
            for label, _ in groups[1:]:
                component = labelled == label
                if np.all(own[component]):
                    selected |= component
            if selected.any():
                x, y = part['offset']
                with Image.open(case / part['file']) as image:
                    width, height = image.size
                image = np.zeros((height, width, 4), dtype=np.uint8)
                image[selected[y:y+height, x:x+width]] = 255
                self.certified[part['name']] = Image.fromarray(image)

    def report(self, layers, pose):
        if not self.certified:
            return []
        occupied = np.logical_or.reduce([image[..., 3] > 0 for _, image, _ in layers])
        labels, groups = components(occupied)
        if not groups:
            return []
        # Topmost ownership prevents another piece from borrowing a source speck.
        owners = np.full(occupied.shape, '', dtype=object)
        for part, image, _ in sorted(layers, key=lambda item: item[0]['z_index']):
            owners[image[..., 3] > 0] = part['name']
        accepted = []
        references = {}
        for label, size in groups[1:]:
            component = labels == label
            names = set(owners[component])
            if len(names) != 1:
                continue
            name = names.pop()
            if name not in self.certified:
                continue
            if name not in references:
                transform = pixels.unpack(pose['parts'][name]['transform'])
                references[name] = pixels.render(self.certified[name], transform)[..., 3] > 0
            if np.all(references[name][component]):
                accepted.append({'bbox': bounds(component), 'pixel_count': size, 'owner': name})
        return accepted


def apply_painted_components(metric, accepted):
    """Remove certified components from strict, colour-independent totals."""
    result = dict(metric)
    if result.get('exempt_outline_components', 0):
        raise ValueError('Source provenance requires strict detached metrics (allow_outline=False)')
    result['stray_components'] -= len(accepted)
    result['stray_pixels'] -= sum(r['pixel_count'] for r in accepted)
    result['painted_detached_components'] = len(accepted)
    return result
