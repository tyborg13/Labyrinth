"""Spec §1: transported immutable paint/tuck masks distinguish air from holes.

Native check textures are sampled by the very same GPU geometry as the paint.
Their red/green channels therefore answer the inverse-pose query, including
skinned pieces and folded triangles, without a CPU skin/raster oracle. CPU
diagnostics may supply their estimated layers to this same classifier.
"""
import numpy as np
from PIL import Image

from maquette_motion import pixels
from maquette_motion.silhouette import components, holes
from .silhouette_gates import detached_metrics


def bounds(mask):
    y, x = np.nonzero(mask)
    return [int(x.min()), int(y.min()), int(x.max()) + 1, int(y.max()) + 1]


def pockets(layers):
    """Check every pixel against every piece, even owners absent from the rim.

    Allowed masks are immutable source silhouettes plus tucks, independent of
    potentially damaged RGBA. A single missing painted/tuck pixel fails.
    Transparent approved source space is never filled or envelope-dilated.
    """
    occupied = np.logical_or.reduce([image[..., 3] > 0 for _, image, _ in layers])
    allowed = [(row['name'], (checks[..., 3] > 0) &
                ((checks[..., 0] > 0) | (checks[..., 1] > 0)))
               for row, _, checks in layers]
    failures, air = [], []
    for pocket in holes(occupied):
        hits = {name: int((pocket & mask).sum()) for name, mask in allowed
                if (pocket & mask).any()}
        record = {'bbox': bounds(pocket), 'pixel_count': int(pocket.sum())}
        if hits:
            record['painted_or_tuck_pixels_by_piece'] = hits
            failures.append(record)
        else:
            air.append(record)
    return {'failures': failures, 'air_pockets': air}


class DetachedSource:
    """Detached approved paint passes only at its rigid owner's exact texels.

    References come from disconnected components of the approved rest, never
    from the presented image or an arbitrary component of an isolated piece.
    A transformed bounding box or colour alone cannot authorize a stray.
    """
    def __init__(self, case, layout):
        source = np.asarray(Image.open(case / layout.get('raw_rest_source', layout['rest_source'])).convert('RGBA'))
        labels, groups = components(source[..., 3] > 0, 8)
        skinned = {mesh['name'] for mesh in layout.get('joint_meshes', [])}
        self.references = []
        for label, size in groups[1:]:
            component = labels == label
            for part in layout['parts']:
                name = part['name']
                if name in skinned or part.get('hidden_material'):
                    continue
                record = layout['proof_layers'][name]
                checks = np.asarray(Image.open(case / record['mask']).convert('RGBA'))
                x, y = record['mask_offset']
                h, w = checks.shape[:2]
                owned = np.zeros_like(component)
                owned[y:y+h, x:x+w] = (checks[..., 0] > 0) & (checks[..., 3] > 0)
                if not np.all(owned[component]):
                    continue
                paint = source.copy()
                paint[~component] = 0
                self.references.append({'piece': name, 'source_bbox': bounds(component),
                    'source_pixel_count': size, 'texture': paint[y:y+h, x:x+w]})

    def report(self, layers, transforms):
        visible = np.zeros_like(layers[0][1])
        owner = np.full(visible.shape[:2], '', dtype=object)
        for row, image, _ in sorted(layers, key=lambda item: item[0]['z_index']):
            mask = image[..., 3] > 0
            visible[mask] = image[mask]
            owner[mask] = row['name']
        labels, groups = components(visible[..., 3] > 0, 8)
        passed, references = [], []
        if len(groups) > 1:
            for record in self.references:
                name = record['piece']
                if name not in transforms:
                    continue  # Missing independent rigid pose cannot earn a pass.
                samples = pixels.render(record['texture'], pixels.unpack(transforms[name]), with_ties=True)
                # Exact legal nearest-source tie choices only; no raster-error
                # allowance is used to authorize detached source components.
                matching = np.all(visible == samples.default, axis=-1) & (samples.default[..., 3] > 0)
                for candidate in samples.candidates:
                    matching |= samples.ties & np.all(visible == candidate, axis=-1) & (candidate[..., 3] > 0)
                references.append((record, matching & (owner == name)))
            for label, size in groups[1:]:
                component = labels == label
                for record, matching in references:
                    if matching[component].all():
                        passed.append({key: value for key, value in record.items() if key != 'texture'} |
                                      {'bbox': bounds(component), 'pixel_count': size})
                        visible[component] = 0
                        break
        return {'metrics': detached_metrics(visible), 'source_components': passed}
