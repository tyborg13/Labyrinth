"""Source-space ownership only. No interpolation, colours or invented paint.

The Seer's rear palm was split by the staff ownership strip. Its outer 43px
component is fingers, not a second shaft: restoring the middle palm reconnects
it. The director's feedback-1 item-paint copies live in fills.py and apply only
after the existing release. Original in-hand paint stays untouched.
"""
import numpy as np
from PIL import Image
from config import DEFAULTS
from maquette_motion.features import source_pixels


def images_for(root, layout):
    return {part['name']: source_pixels(root, part) for part in layout['parts']}


def seer_rear(images):
    # Exact native ownership boundary: y=114 is the shaft's dark end;
    # y=115..130 is palm; y=131 onward is the emerging lower shaft.
    palm = np.zeros((255, 255), bool)
    palm[115:131, 170:184] = True
    palm &= images['staff'][..., 3] > 0
    hand, staff = images['hand_far'].copy(), images['staff'].copy()
    if (hand[..., 3][palm] > 0).any():
        raise ValueError('Palm ownership overlaps the original fist')
    hand[palm] = staff[palm]
    staff[palm] = 0
    return {'hand_far': hand, 'staff': staff}, palm


def chain_request(images):
    chain, hand = images['chain'][..., 3] > 0, images['hand_far'][..., 3] > 0
    y, x = np.nonzero(chain)
    top = int(y.min())
    edge_x = np.nonzero(chain[top])[0]
    pad = DEFAULTS['request_padding_px']
    mask = np.zeros(chain.shape, bool)
    mask[max(0, top-pad):top+pad, max(0, int(edge_x.min())-pad):int(edge_x.max())+pad+1] = True
    # Request a conservative native region, not a fabricated arc silhouette.
    return mask & (hand | ~chain)


def active(part, clip, phase):
    variant = part.get('release_texture', {})
    if phase < variant.get('release_at', {}).get(clip, float('inf')):
        return part
    return dict(part, **{key: variant[key] for key in ('file', 'offset', 'bbox')})
