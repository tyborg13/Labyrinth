"""Covered neck/waist material swept from the actual protected action poses.

The head/torso and torso/pelvis cut edges rotate apart in lob/death. Sweep
their existing three-pixel seam bands into each other's source frames; retain
only texels covered by approved rest paint. Colour always comes from the
receiving piece. This changes coverage, never keys, source ownership or rest.
"""
import numpy as np
import hashlib
import json
from PIL import Image
from cutout_pipeline.cases import read_json, write_json, digest
from humanoid_cutout.cpu_pose import sprite_transform
from humanoid_cutout.materials import connected_mask
from maquette_motion.silhouette import dilate
from maquette_motion.bleed import edge_texels

JOINS = [('head', 'torso'), ('torso', 'pelvis')]
ACTION_CLIPS = {'head': ['lob', 'death'], 'pelvis': ['death']}


def source_transform(joints, pose, name, anchor):
    part = dict(bone=name, offset=anchor, presentation_anchor=anchor)
    matrix = sprite_transform(dict(joints=joints), pose, part)
    matrix[:2, 2] -= matrix[:2, :2] @ anchor
    return matrix


def extend(case, view, visible, hidden, paint, joints, policy, definition):
    path = case / 'proof/logs/samples_full.json'
    cache = case / f'continuations/{view}.json'
    basis = dict(director=digest(case / 'director_motion.json'),
                 paint=digest(case / f'source/{view}/processed.png'),
                 ownership=digest(case / f'ownership/{view}.png'),
                 joints=hashlib.sha256(json.dumps(joints, sort_keys=True).encode()).hexdigest())
    samples = read_json(path) if path.is_file() else None
    usable = samples and samples['compiled_sha256'] == digest(case / 'compiled_motion.json')
    if not usable:
        if not cache.is_file() or read_json(cache)['basis'] != basis: return {}, {}
        record = read_json(cache)
        domains = {}
        for name, row in record['domains'].items():
            if digest(case / row['file']) != row['sha256']: raise ValueError('Changed joint continuation calibration')
            domains[name] = np.asarray(Image.open(case / row['file']).convert('L')) > 0
        return apply_domains(visible, hidden, paint, domains, definition)
    rows = [r for r in samples['samples'] if r['view'] == view and r['kind'] == 'presented']
    covered = paint[..., 3] > 0
    own = {n: image[..., 3] > 0 for n, image in visible.items()}
    anchors = {n: np.asarray(Image.fromarray(image).getbbox()[:2]) for n, image in visible.items()}
    domains = {n: np.zeros_like(covered) for pair in JOINS for n in pair}
    for first, second in JOINS:
        for donor, receiver in ((first, second), (second, first)):
            band = own[donor] & dilate(own[receiver], policy['base_px'], grid_distance=True)
            y, x = np.nonzero(band)
            points = np.stack((x + .5, y + .5), axis=1)
            for pose in rows:
                transform = np.linalg.inv(source_transform(joints, pose, receiver, anchors[receiver])) @ source_transform(joints, pose, donor, anchors[donor])
                # Raster footprint of each existing seam texel in the receiving
                # frame. Corners cover rotation ties without a new paint margin.
                for corner in ((-.5, -.5), (-.5, .5), (.5, -.5), (.5, .5)):
                    mapped = np.floor((points + corner) @ transform[:2, :2].T + transform[:2, 2]).astype(int)
                    valid = (mapped >= 0).all(1) & (mapped < covered.shape[0]).all(1)
                    xx, yy = mapped[valid].T
                    domains[receiver][yy, xx] = True
    cached = {}
    for name, domain in domains.items():
        target = case / f'continuations/{view}_{name}.png'
        target.parent.mkdir(exist_ok=True)
        Image.fromarray(domain.astype('uint8') * 255).save(target)
        cached[name] = dict(file=str(target.relative_to(case)), sha256=digest(target))
    write_json(cache, dict(basis=basis, sampled_frames=len(rows), domains=cached,
                          step_distance_px=samples['step_distance_px'], screen_pixel_scale=samples['screen_pixel_scale']))
    return apply_domains(visible, hidden, paint, domains, definition)


def apply_domains(visible, hidden, paint, domains, definition):
    covered = paint[..., 3] > 0
    own = {n: image[..., 3] > 0 for n, image in visible.items()}
    result, action = {}, {}
    for name, domain in domains.items():
        domain &= ~own[name]
        domain = connected_mask(own[name] | (hidden[name][..., 3] > 0), domain)
        if name in ACTION_CLIPS: action[name] = domain & ~covered
        domain &= covered
        missing = domain & (hidden[name][..., 3] == 0)
        fill = edge_texels(visible[name], missing, definition)
        hidden[name][missing] = fill[missing]
        result[name] = int(missing.sum())
    return result, action
