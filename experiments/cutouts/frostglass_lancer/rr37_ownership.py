"""Fuse certified pauldron ownership and its painted outline into the torso."""
import numpy as np
from PIL import Image, ImageDraw
from cutout_pipeline.cases import read_json, write_json, digest
from maquette_motion.features import source_pixels
from humanoid_cutout.ownership import apply_override
from maquette_motion.bleed import edge_texels
from humanoid_cutout.materials import clean_continuation


def assign(case, view, visible, hidden, paint, definition):
    base = case / (view + '_baseline')
    old = read_json(base / f'layouts/{view}.json')
    mask = np.zeros(paint.shape[:2], dtype=bool)
    for name in ('pauldron_near', 'pauldron_far'):
        part = next(p for p in old['parts'] if p['logical_part'] == name)
        mask |= source_pixels(base, part)[..., 3] > 0
    for feature in read_json(case / f'features/{view}.json'):
        mask &= ~(np.asarray(Image.open(case / feature['mask'])) > 0)
    # Certified labels approximate the painted lames. Include their complete
    # measured painting outlines, including every edge/fringe texel.
    from rr37_traces import TRACES
    for owner, polygon in TRACES[view]:
        if owner != 'torso' or max(y for _,y in polygon) >= 100: continue  # Shoulder shells only; the pelvis owns the belt.
        trace = Image.new('1', (255, 255))
        ImageDraw.Draw(trace).polygon(polygon, fill=1)
        mask |= np.asarray(trace) & (paint[..., 3] > 0)
    for feature in read_json(case / f'features/{view}.json'):
        mask &= ~(np.asarray(Image.open(case / feature['mask'])) > 0)
    previous = {n: im[..., 3] > 0 for n, im in visible.items()}
    transfers = apply_override(visible, paint, mask, 'torso')
    for name in visible:
        if name == 'torso': hidden[name][mask] = 0; continue
        lost = previous[name] & mask
        if lost.any():
            replacement = edge_texels(visible[name], lost, definition)
            hidden[name][lost] = replacement[lost]
        hidden[name] = clean_continuation(visible[name], hidden[name], definition)
    path = case / f'ownership/{view}_pauldrons.png'; path.parent.mkdir(exist_ok=True)
    Image.fromarray(mask.astype('uint8') * 255).save(path)
    report = {'owner': 'torso', 'bone': 'torso', 'file': str(path.relative_to(case)),
              'sha256': digest(path), 'pixels': int(mask.sum()), 'transfers': transfers}
    write_json(case / f'ownership/{view}_pauldrons.json', report)
    return report


def draw_depths(depths, view):
    result = dict(depths)
    camera = 'near' if view == 'front' else 'far'
    away = 'far' if camera == 'near' else 'near'
    behind = min(result[n] for n in ('torso', 'pelvis', 'cape_near', 'cape_far')) - 2
    for index, kind in enumerate(('arm_', 'hand_')): result[kind + away] = behind + index
    front = max(result.values()) + 1
    result['arm_' + camera], result['hand_' + camera] = front, front + 1
    # mq-14's breastplate, far vambrace and gripping gauntlet face the camera
    # ahead of the held shaft. The old whole-item foreground layer exposed
    # wood through those surfaces and the rear cloak. Keep the rigid item
    # behind them; rr45_occlusion checks every overlap against mq-14 depth,
    # while crystal_contact_errors separately protects the contact landmark.
    result['spear'] = min(result[n] for n in
        ('torso', 'pelvis', 'cape_near', 'cape_far', 'arm_far', 'hand_far')) - 1
    # Preserve rr-43's grip/head layers; only the spear changes depth.
    result['hand_far'] = max(result['hand_far'], front + 3)
    result['head'] = max(result.values()) + 1
    return result
