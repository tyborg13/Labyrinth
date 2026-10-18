"""Opt-in feature partition adapter; leave the legacy builder byte-identical.

Historical cases bind the whole builder's source hash in their reproducibility
manifests. Feature derivation therefore wraps its public registration/ownership
steps in a fresh temporary case instead of changing that legacy implementation.
"""
from contextlib import contextmanager
from unittest.mock import patch
import numpy as np
from PIL import Image
from cutout_pipeline.cases import CutoutError, digest, read_json, write_json
from maquette_motion.features import declarations, source_pixels


@contextmanager
def ownership_adapter(builder, root):
    original_nearest = builder.nearest_labels
    original_hidden = builder.hidden_region
    contexts = {}
    state = {'view': None}

    def nearest(labels, opaque, names, depths):
        owners, report = original_nearest(labels, opaque, names, depths)
        previous = owners.copy()
        for feature in declarations(root, state['view']):
            if feature['owner'] not in names:
                raise CutoutError('Unknown feature owner: ' + feature['owner'])
            owners[feature['pixels']] = names.index(feature['owner'])
        key = owners.tobytes()
        if key in contexts and not np.array_equal(contexts[key], previous):
            raise CutoutError('Ambiguous paired-view hidden ownership')
        contexts[key] = previous
        return owners, report

    def hidden(solo, owners, part):
        result, outside = original_hidden(solo, owners, part)
        previous = contexts.get(owners.tobytes())
        if previous is not None:
            result |= (previous == part) & (owners >= 0) & (owners != part)
        return result, outside

    with patch.object(builder, 'nearest_labels', nearest), patch.object(builder, 'hidden_region', hidden):
        yield state


def extract_nodes(root, view, mapping):
    """Each feature gets one crop/pivot; all overlapping material stays below."""
    declared = declarations(root, view)
    layout_path = root / f'layouts/{view}.json'
    layout = read_json(layout_path)
    mask = np.zeros((255, 255), dtype=bool)
    for feature in declared:
        mask |= feature['pixels']
    parts = []
    for part in layout['parts']:
        if part.get('hidden_material'):
            parts.append(part)
            continue
        image = np.array(Image.open(root / part['file']).convert('RGBA'))
        x, y = part['offset']
        image[mask[y:y + image.shape[0], x:x + image.shape[1]]] = 0
        Image.fromarray(image).save(root / part['file'])
        if image[..., 3].any():
            parts.append(part)
    paint = np.asarray(Image.open(root / f'source/{view}/processed.png').convert('RGBA'))
    foreground = max((p['z_index'] for p in parts), default=0) + 1
    for feature in declared:
        selected = feature['pixels']
        if not selected.any():
            continue
        ys, xs = np.nonzero(selected)
        bounds = [int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1]
        image = np.zeros_like(paint)
        image[selected] = paint[selected]
        name = 'feature_' + feature['name']
        relative = f'segmented/{view}/{name}.png'
        Image.fromarray(image).crop(bounds).save(root / relative)
        parts.append({'name': name, 'feature': feature['name'], 'logical_part': feature['owner'],
                      'bone': mapping[feature['owner']], 'file': relative,
                      'offset': bounds[:2], 'bbox': bounds, 'z_index': foreground})
    layout['parts'] = parts
    write_json(layout_path, layout)
    record_partition(root, view, layout)


def record_partition(root, view, layout):
    # Retain a complete replayable source-pixel recipe for the new partition.
    visible = [p for p in layout['parts'] if not p.get('hidden_material') and not p.get('seam_underlay')]
    recipe = {'priority_polygons': [[p['name'], [[0, 0], [0, 0], [0, 0]]] for p in visible], 'pixel_overrides': []}
    for part in visible:
        ys, xs = np.nonzero(source_pixels(root, part)[..., 3])
        recipe['pixel_overrides'].extend({'point': [int(x), int(y)], 'name': part['name']} for y, x in zip(ys, xs))
    recipe_path = root / f'recipes/{view}_ownership.json'
    write_json(recipe_path, recipe)
    segmentation_path = root / f'segmented/{view}/segmentation.json'
    segmentation = read_json(segmentation_path)
    segmentation['parts'] = [dict(p, file=p['name'] + '.png') for p in visible]
    segmentation['ownership_sha256'] = digest(recipe_path)
    write_json(segmentation_path, segmentation)
    if (root / 'source/spec.json').exists():
        names = list(read_json(root / 'source/spec.json')['labels'])
        owners = np.full((255, 255), -1, dtype=np.int16)
        for part in visible:
            owners[source_pixels(root, part)[..., 3] > 0] = names.index(part['logical_part'])
        np.save(root / f'registered/{view}_owners.npy', owners, allow_pickle=False)
