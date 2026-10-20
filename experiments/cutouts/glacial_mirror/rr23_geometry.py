"""Register repainted terminal overlaps and the owner's front-arm priority."""
import numpy as np
from PIL import Image

from rr18_case import BONES, CASE
from cutout_pipeline.cases import read_json


def register_terminals(joints, visible, hidden, view):
    """Keep each native landmark when covered; otherwise trace its own overlap.

    The repaint moved two heels relative to the maquette. Snap only displaced
    landmarks to the traced painted ankle overlap. The trace stays in source
    coordinates, rather than adding an animation offset.
    """
    records = {}
    traces = read_json(CASE/'rr23_registration.json')[view]
    for side in ('near', 'far'):
        for parent, terminal in (('shin_', 'foot_'), ('fore_', 'fist_')):
            name = terminal + side
            joint = joints[BONES[name]]
            original = np.asarray(joint['position'])
            overlap = (((visible[parent + side][..., 3] > 0) | (hidden[parent + side][..., 3] > 0)) &
                       ((visible[name][..., 3] > 0) | (hidden[name][..., 3] > 0)))
            joint['position'] = traces.get(name, {}).get('position', original.tolist())
            x, y = np.floor(joint['position']).astype(int)
            if not overlap[y, x]:
                raise ValueError('TODO_DESIGN_' + view + '_' + name + '_painted_overlap')
            records[name] = {'maquette_pivot': original.tolist(), 'painted_overlap_pivot': joint['position'],
                             'overlap_pixels': int(overlap.sum())}
    return records


def compose(visible, hidden, depths):
    rest = Image.new('RGBA', (255, 255))
    for image in hidden.values():
        rest.alpha_composite(Image.fromarray(image))
    for name in sorted(visible, key=depths.get):
        rest.alpha_composite(Image.fromarray(visible[name]))
    return np.asarray(rest)


def front_arm_order(visible, hidden, depths):
    before = compose(visible, hidden, depths)
    above = max(depths.values())
    depths['fore_near'], depths['fist_near'] = above + 1, above + 2
    mismatch = int(np.any(before != compose(visible, hidden, depths), axis=-1).sum())
    if mismatch:
        raise ValueError('TODO_DESIGN_near_arm_order: rest changes by %d px' % mismatch)
    return {'rest_order_mismatch_pixels': mismatch,
            'above_torso_and_head': ['fore_near', 'fist_near']}
