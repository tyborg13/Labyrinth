"""Classify source texels from verified paint provenance, never from colour alone.

Hidden-request previews/masks pin the original painted fill. A later support
texel is derived even if its colour duplicates an approved painted shadow.
Visible partitions retain approved status only at their exact source RGBA.
Seam bands and recoloured original texels are always derived.
"""
import numpy as np
from PIL import Image
from cutout_pipeline.cases import digest
from maquette_motion import support_seeds


def source_classes(case, view, layout, images):
    """Return local RGBA approval masks, sampled exactly like the source paint."""
    source = Image.open(case / f'source/{view}/processed.png').convert('RGBA')
    classes, counts = {}, {'approved_painted_texels': 0, 'derived_texels': 0}
    for part in layout['parts']:
        image = images[part['name']]
        actual = np.asarray(image)
        occupied = actual[..., 3] > 0
        approved = np.zeros(occupied.shape, dtype=bool)
        if not part.get('seam_underlay'):
            paint = (Image.fromarray(support_seeds.approved(case, view, part))
                     if part.get('hidden_material') else source)
            x, y = part['offset']
            original = np.asarray(paint.crop((x, y, x + image.width, y + image.height)))
            approved = occupied & (original[..., 3] > 0) & np.all(actual == original, axis=-1)
        mask = np.zeros_like(actual)
        mask[..., :3] = approved[..., None] * 255
        mask[..., 3] = actual[..., 3]
        classes[part['name']] = Image.fromarray(mask)
        counts['approved_painted_texels'] += int(approved.sum())
        counts['derived_texels'] += int((occupied & ~approved).sum())
    return classes, dict(counts,
        approved_visible_sha256=digest(case / f'source/{view}/processed.png'),
        hidden_fill_index_sha256=digest(case / 'hidden_fills/index.json'))
