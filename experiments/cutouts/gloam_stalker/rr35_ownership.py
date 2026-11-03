"""Source-space ownership traces; selects approved texels without repainting.

The maquette's categorical edges approximate the painting. These outlines trace
its shoulder/back plates so even their outline fringes belong to the torso.
Hidden paint uses the existing same-surface continuation algorithm.
"""
import numpy as np
from PIL import Image, ImageDraw
from cutout_pipeline.cases import read_json, write_json, digest
from maquette_motion.features import source_pixels
from humanoid_cutout.ownership import apply_override

CARAPACE_OUTLINES = {
    'front': [[(131, 55), (140, 52), (158, 59), (170, 72), (179, 89),
               (183, 101), (177, 112), (167, 116), (154, 106), (146, 89), (145, 74)]],
    'rear': [[(91, 98), (95, 91), (110, 89), (124, 99), (142, 108),
              (161, 111), (176, 112), (179, 121), (174, 141), (159, 136),
              (141, 129), (124, 119), (110, 110), (100, 104), (92, 113)]]}


def carapace_mask(view, paint):
    mask = Image.new('1', tuple(reversed(paint.shape[:2])))
    draw = ImageDraw.Draw(mask)
    for polygon in CARAPACE_OUTLINES[view]: draw.polygon(polygon, fill=1)
    return np.asarray(mask) & (paint[..., 3] > 0)


def assign(case, view, visible, hidden, paint, definition):
    from maquette_motion.bleed import edge_texels
    from humanoid_cutout.materials import clean_continuation
    mask = carapace_mask(view, paint)
    base = case / (view + '_baseline')
    original = read_json(base / f'layouts/{view}.json')
    native = next(p for p in original['parts'] if p['logical_part'] == 'carapace')
    mask |= source_pixels(base, native)[..., 3] > 0
    # Genuine painted drape glints take precedence over nearest categorical
    # fringes: the r3 solo's rear edge crosses the violet cloth at x102..105.
    for feature in read_json(case / f'features/{view}.json'):
        mask &= ~(np.asarray(Image.open(case / feature['mask'])) > 0)
    previous = {n: im[..., 3] > 0 for n, im in visible.items()}
    transfers = apply_override(visible, paint, mask, 'torso')
    # Every vacated surface receives its own continuation behind the torso.
    # It remains hidden at rest; moving cover reveals the same material.
    for name in visible:
        if name == 'torso':
            hidden[name][mask] = 0
            continue
        # Only continue the part where it actually lost source ownership.
        # Per-owner masks are captured before reassignment below by the caller.
        lost = previous[name] & mask
        if lost.any():
            replacement = edge_texels(visible[name], lost, definition)
            hidden[name][lost] = replacement[lost]
        hidden[name] = clean_continuation(visible[name], hidden[name], definition, replace_all=bool(lost.any()))
    rgba = np.zeros_like(paint); rgba[mask] = 255
    path = case / f'ownership/{view}_carapace.png'
    path.parent.mkdir(exist_ok=True)
    Image.fromarray(rgba).save(path)
    report = {'owner': 'torso', 'bone': 'torso', 'file': str(path.relative_to(case)),
              'sha256': digest(path), 'pixels': int(mask.sum()), 'transfers': transfers,
              'outlines': CARAPACE_OUTLINES[view]}
    write_json(case / f'ownership/{view}_carapace.json', report)
    return report


def draw_depths(depths, view):
    """Keep inherited lower-body order; enforce the brief's strict arm order."""
    result = dict(depths)
    camera = 'near' if view == 'front' else 'far'
    away = 'far' if camera == 'near' else 'near'
    body = ['torso', 'pelvis', 'cape_near', 'cape_far']
    behind = min(result[n] for n in body) - 2
    for index, kind in enumerate(('arm_', 'hand_')): result[kind + away] = behind + index
    front = max(result[n] for n in body) + 1
    result['arm_' + camera], result['hand_' + camera] = front, front + 1
    result['head'] = front + 2
    return result
