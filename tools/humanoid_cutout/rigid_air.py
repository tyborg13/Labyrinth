"""Opt-in source-space pocket calibration for separate rigid painted pieces.

Air can close into a pocket as rigid stones move. Missing immutable silhouette,
tuck or continuation texels still fail, including holes bounded by one owner.
No clip/frame vocabulary or creature identity belongs in this classifier.
"""
import numpy as np
from PIL import Image

from .anatomy import owner_ids
from maquette_motion.pixels import PROOF_DEFAULTS, unpack
from maquette_motion.silhouette import holes, dilate

POLICY = 'air_between_rigid_pieces'


class RigidAirPolicy:
    def __init__(self, case, layout, anatomy):
        if anatomy.get('seam_policy') != POLICY:
            raise ValueError('Rigid-air calibration requires an explicit case seam_policy')
        if layout.get('joint_meshes'):
            raise ValueError('Rigid-air calibration cannot classify skinned meshes')
        self.ids = owner_ids(anatomy['ownership'])
        self.protected = anatomy['seam_protected_pieces']
        self.parts = {}
        self.masks = {}
        visible_masks = {}
        size = tuple(reversed(layout['canvas_size']))
        for part in layout['parts']:
            name = part['logical_part']
            self.parts.setdefault(name, []).append(part)
            mask = self.masks.setdefault(name, np.zeros(size, dtype=bool))
            record = layout['proof_layers'][part['name']]
            # Immutable allowed-paint masks, not possibly damaged current RGBA.
            image = np.asarray(Image.open(case / record['mask']).convert('RGBA'))
            x, y = record['mask_offset']
            allowed = image[..., 0] > 0
            mask[y:y+image.shape[0], x:x+image.shape[1]] |= allowed
            if not part.get('hidden_material'):
                visible = visible_masks.setdefault(name, np.zeros(size, dtype=bool))
                visible[y:y+image.shape[0], x:x+image.shape[1]] |= allowed
        if not set(self.protected) <= self.parts.keys():
            raise ValueError('Protected seam pieces must name painted logical parts')
        # Protect the solid chest's visible contour. Combining overlapping
        # tucks first can close air outside that contour between two stones.
        # Every actual tuck texel is still checked independently below.
        self.protected_masks = {name: visible_masks[name] | self._interiors(visible_masks[name])
                                for name in self.protected}
        self.source = np.asarray(Image.open(case / layout['rest_source']).convert('RGBA'))[..., 3] > 0

    @staticmethod
    def _interiors(mask):
        result = np.zeros_like(mask)
        for hole in holes(mask):
            result |= hole
        return result

    @staticmethod
    def _sample(mask, points):
        x, y = points.T
        inside = (x >= 0) & (y >= 0) & (x < mask.shape[1]) & (y < mask.shape[0])
        result = np.zeros(len(points), dtype=bool)
        result[inside] = mask[y[inside], x[inside]]
        return result

    def report(self, occupied, owners, transforms):
        """Check every pocket pixel through every rigid piece's inverse.

        A different stone painted at that source coordinate is not this
        piece's surface. Its own immutable silhouette/tuck is authoritative.
        Protected silhouettes are checked even when occluded on the rim.
        """
        failures, air = [], []
        inverses = {name: np.linalg.inv(unpack(transform)) for name, transform in transforms.items()}
        for pocket in holes(occupied):
            ys, xs = np.nonzero(pocket)
            rim = owners[dilate(pocket, 1) & occupied]
            surrounding = [name for name, value in self.ids.items() if value in rim]
            points = np.column_stack((xs+.5-PROOF_DEFAULTS['source_offset'],
                                      ys+.5-PROOF_DEFAULTS['source_offset'], np.ones(len(xs))))
            traces = {}
            blocked = np.zeros(len(xs), dtype=bool)
            for name in self.parts:
                interior = np.zeros(len(xs), dtype=bool)
                protected = np.zeros(len(xs), dtype=bool)
                source_points = []
                transparent = np.ones(len(xs), dtype=bool)
                for part in self.parts[name]:
                    inverse = inverses[part['name']]
                    local = (points[:, 0, None] * inverse[None, :2, 0]
                             + points[:, 1, None] * inverse[None, :2, 1] + inverse[None, :2, 2])
                    if not np.isfinite(local).all():
                        raise ValueError('Invalid inverse rigid source coordinates')
                    pixels = np.rint(local.astype(np.float32)-.5).astype(int) + part['offset']
                    source_points.append(pixels.tolist())
                    interior |= self._sample(self.masks[name], pixels)
                    transparent &= ~self._sample(self.source, pixels)
                    if name in self.protected_masks:
                        protected |= self._sample(self.protected_masks[name], pixels)
                blocked |= interior | protected
                if name in surrounding or name in self.protected or interior.any():
                    traces[name] = {'source_points': source_points,
                        'transparent_source_pixels': int(transparent.sum()),
                        'painted_or_tuck_pixels': int(interior.sum()),
                        'protected_silhouette_pixels': int(protected.sum())}
            record = {'bbox': [int(xs.min()), int(ys.min()), int(xs.max())+1, int(ys.max())+1],
                      'pixel_count': len(xs), 'stone_pixels': int(blocked.sum()),
                      'surrounding_pieces': surrounding, 'checked_pieces': len(self.parts), 'source': traces}
            (failures if blocked.any() else air).append(record)
        return {'failures': failures, 'air_pockets': air}


def for_case(case, layout, anatomy):
    """Omitted policy preserves the strict gate for all existing figures."""
    if anatomy.get('seam_policy') == POLICY:
        return RigidAirPolicy(case, layout, anatomy)
    return None
