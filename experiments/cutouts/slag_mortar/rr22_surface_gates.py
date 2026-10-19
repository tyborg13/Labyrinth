"""Replay director ownership and check the actual logical-piece textures."""
import numpy as np
from PIL import Image
from cutout_pipeline.cases import digest, read_json
from maquette_motion.features import source_pixels
from maquette_motion.silhouette import components
from rr22_surfaces import resolve, clean_residue, molten_mask


def connectivity_errors(images, label, approved=None, rigid=False):
    union = np.logical_or.reduce([image[..., 3] > 0 for image in images])
    labelled, groups = components(union)
    amount = len(groups)
    if approved is not None and rigid:
        source_labels, source_groups = components(approved[..., 3] > 0)
        detached = [n for n, _ in source_groups[1:]]
        for index, _ in groups[1:]:
            if np.isin(source_labels[labelled == index], detached).all():
                amount -= 1
    return [] if amount == 1 else [f'{label}: logical piece has {amount} connected components']


def errors(case, layout):
    view = layout['facing']
    base = case / (view + '_baseline')
    original = read_json(base / f'layouts/{view}.json')
    names = [p['logical_part'] for p in original['parts']]
    paint = np.asarray(Image.open(case / layout['rest_source']).convert('RGBA'))
    owners = np.full(paint.shape[:2], -1, dtype=int)
    for index, part in enumerate(original['parts']):
        owners[source_pixels(base, part)[..., 3] > 0] = index
    from rr22_case import DIRECTOR
    mask_path = DIRECTOR.parent / f'crucible_mask_{view}.png'
    crucible = np.asarray(Image.open(mask_path).convert('L')) > 0
    expected, _ = resolve(paint, owners, names, original['joints'], view, crucible, layout['source_labels'])
    record = read_json(case / f'ownership/{view}.json')
    recorded = np.asarray(Image.open(case / record['map'])).astype(int) - 1
    failures = []
    if (case / f'source/{view}/crucible_mask.png').read_bytes() != mask_path.read_bytes():
        failures.append(view + ': protected crucible mask import differs')
    if record['map_sha256'] != digest(case / record['map']) or not np.array_equal(recorded, expected):
        failures.append(view + ': ownership map differs from director colour/rim rules')
    feature = molten_mask(paint) & (expected == names.index('mortar'))
    features = layout.get('features', [])
    if len(features) != 1 or features[0].get('piece') != 'mortar' or features[0].get('bone') != 'mortar':
        failures.append(view + ': molten feature must belong to mortar')
    elif not np.array_equal(np.asarray(Image.open(case / features[0]['mask'])) > 0, feature):
        failures.append(view + ': molten feature mask differs from director colour band')
    for name, labels in layout['source_labels'].items():
        selected = np.isin(expected, [names.index(label) for label in labels])
        image = np.zeros_like(paint)
        image[selected] = paint[selected]
        image, _ = clean_residue(image, feature if name == 'mortar' else None)
        parts = [p for p in layout['parts'] if p['logical_part'] == name]
        visible = [p for p in parts if not p.get('hidden_material')]
        if len(visible) != 1 or not np.array_equal(source_pixels(case, visible[0]), image):
            failures.append(view + '/' + name + ': actual source cut differs from director ownership')
        failures += connectivity_errors([source_pixels(case, p) for p in parts], view + '/' + name,
                                       paint, rigid=not any(m['logical_part'] == name for m in layout['joint_meshes']))
    return failures
