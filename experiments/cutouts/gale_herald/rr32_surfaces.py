"""Ownership derived from the supplied native banner roots, never new paint."""
import numpy as np
from PIL import Image
from maquette_cutout import projected
from cutout_pipeline.cases import read_json, digest


def split_yoke(case, base, view, visible, hidden):
    spec = read_json(base / 'source/spec_native.json')
    registration = read_json(base / f'registered/{view}_registration.json')
    scale, offset = np.asarray(registration['scale']), np.asarray(registration['offset'])
    yy, xx = np.indices((255, 255))
    pixels = np.stack((xx, yy), axis=-1)
    for side in ('near', 'far'):
        name = 'cape_' + side
        banner = next(p for p in spec['pieces'] if p['id'] == 'banner_' + side + '_' + view)
        first, last = [np.mean(banner['pattern']['rows'][i]['points'], axis=0) for i in (0, -1)]
        start, end = [np.asarray(projected(spec, p, view)) * scale + offset for p in (first, last)]
        # A banner begins at its native pinned edge. Surface on the body side
        # of that plane is the shoulder wrap, fused into the rigid torso.
        body_side = np.sum((pixels - start) * (end - start), axis=-1) < 0
        for layers in (visible, hidden):
            moved = body_side & (layers[name][..., 3] > 0)
            layers['torso'][moved] = layers[name][moved]
            layers[name][moved] = 0


def feature_definitions(case, view, visible):
    records = []
    # Protect the entire immutable feature-bearing surface. This is stronger
    # than a hand-selected mask of just the brass mask / worn insignia pixels.
    for name, piece in [('brass_mask', 'head'), ('near_banner_insignia', 'cape_near'),
                        ('far_banner_insignia', 'cape_far')]:
        path = case / f'features/{view}_{name}.png'
        path.parent.mkdir(parents=True, exist_ok=True)
        mask = visible[piece][..., 3] > 0
        Image.fromarray(mask.astype('uint8') * 255).save(path)
        records.append({'name': name, 'piece': piece, 'mask': str(path.relative_to(case)),
                        'sha256': digest(path), 'scope': 'entire approved feature-bearing surface'})
    return records
