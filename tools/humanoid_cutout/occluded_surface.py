"""Explicit director donors for a solo with no visible source ownership.

The borrowed surface retains its painted outline. It is not a tuck: only the
additional covered continuation uses the rr-05 non-outline donor rule.
"""
import numpy as np
from PIL import Image

from cutout_pipeline.cases import digest
from maquette_motion.bleed import edge_texels
from maquette_motion.features import source_pixels
from .tucks import translate


def bind(case, base, old, view, piece, recipe):
    donor = next(p for p in old['parts'] if p['name'] == recipe['donor'])
    solo = base / f'registered/{view}_solo_{piece}.png'
    source = base / donor['file']
    return dict(recipe, piece=piece, surface_part='hidden_' + piece,
                donor_file=str(source.relative_to(case)), donor_offset=donor['offset'],
                donor_sha256=digest(source), solo_file=str(solo.relative_to(case)),
                solo_sha256=digest(solo))


def derive(case, record, paint):
    """Bottom-center translation only, then exact nearest painted texels.

    No rotation, mirroring, scaling, palette filtering or invented colour.
    Whole-pixel registration uses NumPy's nearest/ties-to-even convention.
    Rest-alpha clipping is the existing covered-fill policy: a registered
    maquette fringe outside the approved painting must not change its rest.
    """
    for name in ('donor', 'solo'):
        if digest(case / record[name + '_file']) != record[name + '_sha256']:
            raise ValueError('occluded donor input hash differs: ' + name)
    if record['alignment'] != 'bottom_center' or not record['clip_to_rest_alpha']:
        raise ValueError('unsupported occluded donor registration')
    donor = source_pixels(case, {'file': record['donor_file'], 'offset': record['donor_offset']})
    solo = np.asarray(Image.open(case / record['solo_file']).convert('RGBA'))[..., 3] > 128
    sy, sx = np.nonzero(donor[..., 3])
    ty, tx = np.nonzero(solo)
    if not len(sx) or not len(tx):
        raise ValueError('occluded donor or solo is empty')
    offset = [int(np.rint((tx.min() + tx.max() - sx.min() - sx.max()) / 2)),
              int(ty.max() - sy.max())]
    shifted = np.stack([translate(donor[..., channel], *offset) for channel in range(4)], axis=-1)
    copied = solo & (shifted[..., 3] > 0)
    missing = solo & ~copied
    image = edge_texels(shifted, missing)
    image[copied] = shifted[copied]
    outside = solo & (paint[..., 3] == 0)
    image[outside] = 0
    report = {'translation_px': offset, 'solo_pixels': int(solo.sum()),
              'copied_pixels': int((copied & ~outside).sum()),
              'nearest_pixels': int((missing & ~outside).sum()),
              'rest_alpha_clipped_yx': np.argwhere(outside).tolist()}
    return image, report


def source_errors(case, layout, images, continuations, paint):
    errors = []
    for record in layout.get('occluded_surfaces', []):
        try:
            expected, report = derive(case, record, paint)
        except (ValueError, OSError) as error:
            errors.append(str(error))
            continue
        name = record['surface_part']
        base = expected[..., 3] > 0
        if np.any(images[name][base] != expected[base]):
            errors.append('occluded donor surface differs: ' + record['piece'])
        if np.any(continuations[name] & base) or np.any(
                (images[name][..., 3] > 0) & ~base & ~continuations[name]):
            errors.append('occluded surface/tuck classification differs: ' + record['piece'])
        if record.get('derivation') != report:
            errors.append('occluded donor registration differs: ' + record['piece'])
    return errors
