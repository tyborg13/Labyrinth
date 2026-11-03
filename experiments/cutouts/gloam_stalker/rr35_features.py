"""Protected violet source features travel with head / drape surfaces.

This is an ownership selector, not a colour replacement. Source RGBA is exact.
"""
from pathlib import Path
import numpy as np
from PIL import Image
from cutout_pipeline.cases import read_json, write_json, digest
from maquette_motion.silhouette import components

# Debug/source classification only; never used to render or recolour a texel.
VIOLET_CHROMA_MARGIN = 40
VIOLET_RED_MARGIN = 20
VIOLET_HUE_MARGIN = 20


def violet(image):
    rgba = np.asarray(image).astype(int)
    r, g, b, a = np.moveaxis(rgba, -1, 0)
    return (a > 0) & (b >= r - VIOLET_HUE_MARGIN) & (r - g >= VIOLET_RED_MARGIN) & (b - g >= VIOLET_CHROMA_MARGIN)


def feature_definitions(case, view, paint):
    labels, groups = components(violet(paint), 8)
    records = []
    # Assign each feature through its native logical ownership; boundary
    # fringes are included by the connected source chroma component.
    baseline = read_json(case / f'{view}_baseline/layouts/{view}.json')
    from maquette_motion.features import source_pixels
    candidates = ['cape_near', 'cape_far'] + (['head'] if view == 'front' else [])
    owners = {n: source_pixels(case / f'{view}_baseline', next(p for p in baseline['parts'] if p['logical_part'] == n))[..., 3] > 0 for n in candidates}
    head = np.asarray(baseline['joints']['head']['position'])
    eye = min(groups, key=lambda row: float(np.min(np.sum((np.argwhere(labels == row[0])[:, ::-1] - head) ** 2, axis=1))))[0] if view == 'front' else None
    for index, _ in groups:
        mask = labels == index
        if index == eye:
            owner = 'head'
        else:
            # The brief assigns violet drape glints to their chains, even
            # where categorical maquette edges placed a fringe on the body.
            choices = ['cape_near', 'cape_far']
            counts = {n: int((mask & owners[n]).sum()) for n in choices}
            if max(counts.values()): owner = max(choices, key=counts.get)
            else:
                xy = np.argwhere(mask)
                owner = min(choices, key=lambda n: float(np.min(np.sum((xy[:, None] - np.argwhere(owners[n])[None]) ** 2, axis=2))))
        file = case / f'features/{view}_{owner}_{index}.png'
        file.parent.mkdir(exist_ok=True)
        Image.fromarray(mask.astype('uint8') * 255).save(file)
        records.append({'name': f'{view}_{owner}_violet_{index}', 'piece': owner,
            'mask': str(file.relative_to(case)), 'sha256': digest(file), 'pixels': int(mask.sum())})
    # Prune masks an earlier build wrote that this one no longer produces.
    kept = {case / r['mask'] for r in records}
    for stale in (case / 'features').glob(f'{view}_*.png'):
        if stale not in kept: stale.unlink()
    write_json(case / f'features/{view}.json', records)
    return records


def enforce_features(case, view, visible, hidden, paint):
    for feature in read_json(case / f'features/{view}.json'):
        mask = np.asarray(Image.open(case / feature['mask'])) > 0
        for name in visible:
            if name == feature['piece']: visible[name][mask] = paint[mask]
            else: visible[name][mask] = 0
