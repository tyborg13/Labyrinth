"""Exact approved front-only feature texels; no new paint."""
import numpy as np
from PIL import Image
from cutout_pipeline.cases import write_json, read_json
from humanoid_cutout.ownership import apply_override

# Source-space bounds measured on the supplied 255px paintings.
FEATURE_BOUNDS = {'cyan_visor': ('head', [96, 40, 112, 67]),
                  'chest_crystal': ('torso', [94, 80, 115, 107]),
                  'crystal_spearhead': ('spear', [26, 5, 49, 76])}


def feature_definitions(case, view, paint):
    features = []
    if view in ('front', 'rear'):
        cyan = (paint[..., 3] > 0) & (paint[..., 2].astype(int) > paint[..., 0].astype(int) + 15) & (paint[..., 1].astype(int) > paint[..., 0].astype(int) + 10)
        bounds = FEATURE_BOUNDS if view == 'front' else {'crystal_spearhead': ('spear', [197, 30, 226, 86])}
        for name, (piece, box) in bounds.items():
            x0, y0, x1, y1 = box
            mask = np.zeros(paint.shape[:2], dtype=bool)
            mask[y0:y1, x0:x1] = cyan[y0:y1, x0:x1]
            path = case / f'features/{view}_{name}.png'; path.parent.mkdir(exist_ok=True)
            Image.fromarray(mask.astype('uint8') * 255).save(path)
            features.append({'name': name, 'piece': piece, 'mask': str(path.relative_to(case))})
    write_json(case / f'features/{view}.json', features)


def enforce_features(case, view, visible, hidden, paint):
    for feature in read_json(case / f'features/{view}.json'):
        mask = np.asarray(Image.open(case / feature['mask'])) > 0
        apply_override(visible, paint, mask, feature['piece'])
        for name in visible: hidden[name][mask] = 0
