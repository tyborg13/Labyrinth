"""Director fb11 outline class, shared by exposed-material proof and donors."""
import numpy as np
from PIL import Image
from cutout_pipeline.cases import read_json, digest

# Match the project's encoded-RGB luma convention (art_identity_gate.py).
LUMA_WEIGHTS = (0.299, 0.587, 0.114)
OUTLINE_PERCENTILE = 5
# Explicit keyed fringe identified by the director in feedback 11.
DIRECTOR_OUTLINE_PALETTE = {'shale_bloomer': ((6, 13, 13),)}


def luma(image):
    rgb = np.asarray(image)[..., :3].astype(float)
    return rgb[..., 0] * LUMA_WEIGHTS[0] + rgb[..., 1] * LUMA_WEIGHTS[1] + rgb[..., 2] * LUMA_WEIGHTS[2]


def rules(case, view):
    source = case / f'source/{view}/processed.png'
    paint = np.asarray(Image.open(source).convert('RGBA'))
    palette = set()
    config = case / 'cutout.json'
    creature = read_json(config).get('character_id') if config.exists() else None
    palette.update(DIRECTOR_OUTLINE_PALETTE.get(creature, ()))
    index = case / 'hidden_fills/index.json'
    if index.exists():
        data = read_json(index)
        if 'outline_tone' in data.get('parameters', {}):
            palette.add(tuple(data['parameters']['outline_tone']))
        palette.update(tuple(r['outline_tone']) for r in data.get('requests', [])
                       if r['view'] == view and 'outline_tone' in r)
    metadata = case / f'source/{view}/processed.json'
    if metadata.exists():
        for step in read_json(metadata).get('post_steps', []):
            if step['step'] == 'clean_outline' and 'tone' in step['parameters']:
                palette.add(tuple(step['parameters']['tone']))
    return {'outline_palette': [list(c) for c in sorted(palette)],
            'visible_luma_percentile': OUTLINE_PERCENTILE,
            'visible_luma_cutoff': float(np.percentile(luma(paint)[paint[..., 3] > 0], OUTLINE_PERCENTILE)),
            'luma_weights': list(LUMA_WEIGHTS), 'approved_visible_sha256': digest(source)}


def outline_class(image, definition):
    image = np.asarray(image)
    result = luma(image) <= definition['visible_luma_cutoff']
    for colour in definition['outline_palette']:
        result |= np.all(image[..., :3] == colour, axis=-1)
    return result & (image[..., 3] > 0)


def interior_donors(image, definition):
    result = np.asarray(image).copy()
    result[outline_class(result, definition)] = 0
    return result
