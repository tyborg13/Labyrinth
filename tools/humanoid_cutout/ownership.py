"""Hash-bound, source-pixel ownership overrides supplied by the director."""
import numpy as np
from PIL import Image

from pathlib import Path
from cutout_pipeline.cases import digest, read_json
from maquette_motion.features import source_pixels
from maquette_motion.silhouette import components


def read_mask(case, definition, canvas_shape):
    path = case / definition['file']
    if digest(path) != definition['sha256']:
        raise ValueError('protected ownership mask hash differs: ' + definition['file'])
    image = Image.open(path)
    if image.mode != 'RGBA' or image.size != tuple(reversed(canvas_shape)):
        raise ValueError('ownership mask must be source-sized RGBA')
    rgba = np.asarray(image)
    mask = rgba[..., 3] > 0
    if not np.all(rgba[mask] == 255) or np.any(rgba[~mask] != 0):
        raise ValueError('ownership mask must contain opaque white or transparent black')
    if 'pixels' in definition and int(mask.sum()) != definition['pixels']:
        raise ValueError('ownership mask pixel count differs')
    if 'components' in definition and len(components(mask)[1]) != definition['components']:
        raise ValueError('ownership mask component count differs')
    return mask


def apply_override(visible, paint, mask, owner):
    """Move only selected original pixels. Never alter their RGBA or position."""
    if np.any(mask & (paint[..., 3] == 0)):
        raise ValueError('ownership mask extends outside the approved painting')
    previous = {name: int((mask & (image[..., 3] > 0)).sum()) for name, image in visible.items()}
    for name, image in visible.items():
        if name == owner: image[mask] = paint[mask]
        else: image[mask] = 0
    return {name: count for name, count in previous.items() if count}


def partition_errors(case, layout, build, images, continuations, paint):
    """Independently recover source ownership, then check the exact overrides.

    Continuations are not visible ownership. In particular cloth under a rope
    must exist, but must never donate the rope's pixels to the skinned garment.
    """
    overrides = layout.get('ownership_overrides', [])
    if not overrides: return []
    project = Path(__file__).resolve().parents[2]
    baseline_path = project / build['source_ownership']
    if digest(baseline_path) != build['source_ownership_sha256']:
        return ['ownership baseline hash differs']
    original = read_json(baseline_path)
    groups = layout['source_labels']
    expected = {name: np.zeros_like(paint) for name in groups}
    for part in original['parts']:
        if any(part.get(k) for k in ('hidden_material', 'seam_underlay', 'silhouette_backing')): continue
        name = next(name for name, labels in groups.items() if part['logical_part'] in labels)
        layer = source_pixels(baseline_path.parent.parent, part)
        selected = layer[..., 3] > 0
        expected[name][selected] = layer[selected]
    errors = []
    for definition in overrides:
        try: mask = read_mask(case, definition, paint.shape[:2])
        except (ValueError, OSError) as error:
            errors.append(str(error))
            continue
        underlay = definition['underlay']
        required = mask & (expected[underlay][..., 3] > 0)
        recorded = np.asarray(Image.open(case / definition['underlay_required_mask'])) > 0
        if not np.array_equal(required, recorded): errors.append('ownership underlay requirement differs: ' + underlay)
        if np.any(required & ((images[underlay][..., 3] == 0) | ~continuations[underlay])):
            errors.append('ownership override missing cloth continuation: ' + underlay)
        apply_override(expected, paint, mask, definition['owner'])
    actual = {name: np.zeros_like(paint) for name in groups}
    for part in layout['parts']:
        if part.get('hidden_material'): continue
        layer = images[part['name']].copy()
        layer[continuations[part['name']]] = 0
        selected = layer[..., 3] > 0
        actual[part['logical_part']][selected] = layer[selected]
    for name in groups:
        if not np.array_equal(actual[name], expected[name]): errors.append('ownership partition differs: ' + name)
    return errors
