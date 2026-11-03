"""Optional registered source partitions for already approved hidden paint.

Inside a bound mask, use untouched source texels. Outside it, preserve the
registered prior production pixels. This keeps a local cut repair from changing
unrelated paint through neighbourhood-based density cleanup.
"""
from pathlib import Path
import hashlib
import numpy as np
from PIL import Image


def bound_image(root, record):
    root = Path(root).resolve()
    relative = Path(record['path'])
    path = root / relative
    if relative.is_absolute() or '..' in relative.parts or not path.resolve().is_relative_to(root):
        raise ValueError('Expected repo-relative density partition input')
    actual = hashlib.sha256(path.read_bytes()).hexdigest()
    if actual != record['sha256']:
        raise ValueError('Changed density partition input: ' + record['path'])
    with Image.open(path) as image:
        return np.asarray(image.convert('RGBA')).copy()


def offset(record, field):
    value = record[field]
    if not isinstance(value, (list, tuple)) or len(value) != 2 or any(type(n) is not int or n < 0 for n in value):
        raise ValueError('Invalid density partition offset: ' + field)
    return value


def apply(root, original, treated, recipe):
    source = np.asarray(original.convert('RGBA'))
    output = np.asarray(treated.convert('RGBA')).copy()
    if output.shape != source.shape:
        raise ValueError('Density partition requires unchanged source dimensions')
    mask = bound_image(root, recipe['mask'])[..., 0] > 0
    x, y = offset(recipe, 'source_offset')
    height, width = source.shape[:2]
    if x + width > mask.shape[1] or y + height > mask.shape[0]:
        raise ValueError('Density partition outside registered source mask')
    local = mask[y:y+height, x:x+width]
    if local.shape != source.shape[:2]:
        raise ValueError('Density partition outside registered source mask')
    if 'outside' in recipe:
        baseline = bound_image(root, recipe['outside'])
        bx, by = offset(recipe['outside'], 'offset')
        if bx + baseline.shape[1] > mask.shape[1] or by + baseline.shape[0] > mask.shape[0]:
            raise ValueError('Density baseline outside registered source mask')
        canvas = np.zeros((*mask.shape, 4), np.uint8)
        canvas[by:by+baseline.shape[0], bx:bx+baseline.shape[1]] = baseline
        previous = canvas[y:y+height, x:x+width]
        if not np.array_equal(source[..., 3][~local], previous[..., 3][~local]):
            raise ValueError('Density partition changes outside source alpha')
        output[~local] = previous[~local]
    output[local] = source[local]
    return Image.fromarray(output), {'policy': 'exact_source_inside_preserved_production_outside', **recipe}
