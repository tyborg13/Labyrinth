"""Immutable painted hidden seeds, recovered from their verified fill previews.

The preview contains approved RGBA over keyed green; registered hidden masks
select the original fill, including its original transparent crop padding.
The pre-continuity RGBA hash in the fill record independently pins the result.
Never use a previously dilated runtime texture as a fresh paint seed.
"""
import hashlib
import numpy as np
from PIL import Image
from cutout_pipeline.cases import CutoutError, read_json, digest


def approved(case, view, part):
    index = read_json(case / 'hidden_fills/index.json')
    name = part.get('logical_part', part['bone'])
    record = next(r for r in index['requests'] if r['view'] == view and r['part'] == name)
    preview = case / record['preview']
    mask_path = case / f'registered/{view}_hidden_{name}.npy'
    mask = np.load(mask_path, allow_pickle=False)
    if digest(preview) != record['preview_sha256'] or hashlib.sha256(mask.tobytes()).hexdigest() != record['hidden_mask_sha256']:
        raise CutoutError(f'Changed approved hidden seed: {view}/{name}')
    paint = np.asarray(Image.open(preview).convert('RGBA'))
    seed = np.zeros_like(paint)
    seed[mask] = paint[mask]
    ys, xs = np.nonzero(mask)
    bounds = [int(xs.min()), int(ys.min()), int(xs.max()) + 1, int(ys.max()) + 1]
    crop = seed[bounds[1]:bounds[3], bounds[0]:bounds[2]]
    if hashlib.sha256(crop.tobytes()).hexdigest() != record['outputs'][0]['output_rgba_sha256']:
        raise CutoutError(f'Painted hidden RGBA differs from approved fill: {view}/{name}')
    return seed
