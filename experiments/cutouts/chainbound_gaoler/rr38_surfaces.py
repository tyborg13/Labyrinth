"""Source ownership and first-pass own-interior hidden continuations.

No synthesized colour or paint. Native judgment belongs to the director;
flat exposed fills are reported with crops, never procedurally iterated.
"""
import numpy as np
from PIL import Image, ImageDraw
from maquette_motion.silhouette import dilate
from maquette_motion.material_palette import outline_class
from maquette_motion.bleed import edge_texels
from humanoid_cutout.covered_surfaces import row_outline
from humanoid_cutout.ownership import apply_override
from cutout_pipeline.cases import read_json, write_json
from rr38_case import PROJECT

INTERIOR_MARGIN_PX = 2  # Brief §2: at least two pixels inside the rest outline.


def interior(image, definition):
    own = image[..., 3] > 0
    seed = image.copy()
    seed[~(own & ~dilate(~own, INTERIOR_MARGIN_PX)) | outline_class(image, definition)] = 0
    return seed


def partition(case, view, visible, paint):
    # The mq-15 director's semantic masks correct the categorical approximation
    # at the native outline. These are cuts of existing texels, not paint edits.
    from rr38_traces import TRACES
    recipes = TRACES[view]
    records = []
    for owner, polygon in recipes:
        mask = Image.new('1', (255, 255))
        ImageDraw.Draw(mask).polygon([tuple(p) for p in polygon], fill=1)
        mask = np.asarray(mask) & (paint[..., 3] > 0)
        apply_override(visible, paint, mask, owner)
        records.append({'owner': owner, 'pixels': int(mask.sum()), 'polygon': polygon})
    write_json(case / f'ownership/{view}.json', records)


def depths(source, view):
    result = dict(source)
    camera = 'near' if view == 'front' else 'far'
    # All hidden material sits below its original covering paint. The near
    # arm is above the complete body/cloth; helm above both arms.
    top = max(result.values()) + 1
    result['arm_' + camera], result['hand_' + camera] = top, top + 1
    result['chain'] = top + 2
    result['hand_far'] = max(result['hand_far'], result['chain'] + 1)
    result['head'] = max(result.values()) + 1
    return result


def fill(case, view, visible, solos, paint, definition):
    own = {n: im[..., 3] > 0 for n, im in visible.items()}
    painted = paint[..., 3] > 0
    domains = {n: (solos[n] & painted & ~own[n]) for n in visible}
    # Full arm, glove, chain AND leg footprints. Solos supply the receiving
    # surface's independently registered boundary; the fill's alpha cannot
    # shrink these requirements. Torso flanks continue under both root arms.
    body = row_outline(own['torso'])
    arm_footprint = own['arm_near'] | own['arm_far'] | own['hand_far']
    domains['torso'] |= body & arm_footprint
    for name in ('coat_near', 'coat_far', 'tabard', 'leg_near', 'leg_far', 'pelvis'):
        domains[name] |= row_outline(own[name]) & painted & ~own[name]
    hidden = {}
    for name, image in visible.items():
        target = domains[name] & ~own[name]
        seed = interior(image, definition)
        if target.any() and not seed[..., 3].any():
            # A fully covered source cannot donate unseen paint.
            hidden[name] = np.zeros_like(image)
        else:
            hidden[name] = edge_texels(seed, target, definition)
        path = case / f'uncovered/{view}_{name}.png'
        path.parent.mkdir(exist_ok=True)
        Image.fromarray(target.astype('uint8') * 255).save(path)
    return hidden, domains
