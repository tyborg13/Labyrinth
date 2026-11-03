"""Feedback 2: source ownership and rest-covered same-surface continuations.

Only existing approved RGBA is transferred. New hidden texels use the shared
rr05 nearest non-outline donor field and are clipped to paint covered at rest.
No motion keys, source paintings, rig joints or gate exceptions are edited.
"""
import numpy as np
from PIL import Image, ImageDraw
from maquette_motion.silhouette import components, dilate
from maquette_motion.bleed import edge_texels
from humanoid_cutout.materials import connected_mask
from cutout_pipeline.cases import write_json, digest


def polygon(points, shape):
    mask = Image.new('1', tuple(reversed(shape)))
    ImageDraw.Draw(mask).polygon([tuple(p) for p in points], fill=1)
    return np.asarray(mask, dtype=bool)


def transfer(visible, paint, owner, mask):
    mask = mask & (paint[..., 3] > 0)
    for name, image in visible.items():
        image[mask] = paint[mask] if name == owner else 0


def repair(case, view, visible, hidden, paint, material_rules):
    yy, xx = np.indices(paint.shape[:2])
    original = {n: a.copy() for n, a in visible.items()}
    if view == 'front':
        # The native categorical regions cut across the director's painted
        # horn, glove and sleeve. Restore the physical surfaces, rather than
        # letting brass deform with the sleeve or the mouthpiece bow with hood.
        arm = (xx < 99) & (yy >= 38) & (yy <= 111)
        arm &= np.logical_or.reduce([visible[n][..., 3] > 0 for n in
                                     ('horn', 'hand_far', 'arm_far', 'torso')])
        transfer(visible, paint, 'arm_far', arm)
        hand = polygon([[49, 66], [61, 62], [72, 64], [80, 59], [87, 59],
                        [87, 77], [78, 88], [65, 90], [53, 81]], yy.shape)
        transfer(visible, paint, 'hand_far', hand)
        shaft = polygon([[0, 100], [43, 89], [58, 76], [64, 79], [68, 84],
                         [57, 99], [30, 145], [0, 145]], yy.shape)
        mouth = (xx < 100) & (yy < 65)
        # Hood pixels to the right of the mouthpiece are never horn material.
        mouth &= (xx + yy < 151)
        transfer(visible, paint, 'horn', shaft | mouth)
        # A dark wrist edge was labelled tabard. It must stay with the rigid
        # glove beside it, not travel/deform with the pelvis cloth chain.
        transfer(visible, paint, 'hand_near', (xx >= 159) & (xx <= 178) &
                 (yy >= 161) & (yy <= 179) & (visible['tabard'][..., 3] > 0))
        # The tabard's other disconnected island is the trouser at the hip.
        transfer(visible, paint, 'leg_near', (xx >= 140) & (visible['tabard'][..., 3] > 0))
        for name in ('cape_near', 'cape_far'):
            labels, groups = components(visible[name][..., 3] > 0, 8)
            transfer(visible, paint, 'torso', (labels > 0) & (labels != groups[0][0]))
    else:
        # Horn-hand specks on the banner roots belong to the arm and cannot
        # trail on the cloth chain.
        labels, groups = components(visible['cape_near'][..., 3] > 0, 8)
        transfer(visible, paint, 'arm_far', (labels > 0) & (labels != groups[0][0]))

    rest = paint[..., 3] > 0
    for name in visible:
        own = visible[name][..., 3] > 0
        # Recompute donors from the corrected physical piece. Never retain
        # inherited painted outline scraps from the old categorical ownership.
        domain = dilate(own, 6, grid_distance=True)
        domain = connected_mask(own, domain & rest & ~own)
        hidden[name] = edge_texels(visible[name], domain, material_rules)
        hidden[name][~domain] = 0

    # Extend the actual banner roots under the tunic and the hood/cuff joins.
    # The measured six-pixel connected overlap closes oblique joint excursions
    # while remaining entirely under existing rest paint.
    # The horn's occluded shaft crosses the whole glove, not a 3px edge band.
    if view == 'front':
        bridge = polygon([[52, 85], [58, 89], [85, 57], [79, 53]], yy.shape)
        own = visible['horn'][..., 3] > 0
        domain = (hidden['horn'][..., 3] > 0) | (bridge & rest & ~own)
        hidden['horn'] = edge_texels(visible['horn'], domain, material_rules)
        hidden['horn'][~domain] = 0

    # Preserve an independently reconstructable partition receipt. This binds
    # the repaired source ownership without pretending a mislabelled surface
    # needs to survive as a hidden copy of the wrong material.
    folder = case / 'ownership_repairs'
    folder.mkdir(exist_ok=True)
    records = []
    for name, image in visible.items():
        mask = image[..., 3] > 0
        path = folder / (view + '_' + name + '.png')
        Image.fromarray(mask.astype('uint8') * 255).save(path)
        records.append({'piece': name, 'file': str(path.relative_to(case)),
                        'sha256': digest(path), 'pixels': int(mask.sum()),
                        'transferred_pixels': int(np.any(image != original[name], axis=-1).sum())})
    write_json(folder / (view + '.json'), records)
    return records


def action_tucks(view, visible, paint):
    """Own-edge joint continuations where the rest silhouette contains air.

    These cannot be baked into rest paint: the 0px rest contract and rigid idle
    require the original air. The shared action-continuation path retains the
    donor coordinates and uses the density-treated production donor at runtime.
    """
    yy, xx = np.indices(paint.shape[:2])
    air = paint[..., 3] == 0
    if view == 'front':
        own = visible['cape_near'][..., 3] > 0
        body = visible['torso'][..., 3] > 0
        root = dilate(own, 6, grid_distance=True) & dilate(body, 6, grid_distance=True)
        root &= air & (yy <= 110)
        sleeve = dilate(visible['arm_near'][..., 3] > 0, 6, grid_distance=True) & air
        sleeve &= (xx <= 165) & (yy >= 128) & (yy <= 165)
        actions = ['move', 'call_the_wind', 'gust_bolt', 'still_air', 'hit', 'death']
        glove = dilate(visible['hand_far'][..., 3] > 0, 3, grid_distance=True) & air
        glove &= (xx >= 56) & (xx <= 62) & (yy >= 75) & (yy <= 81)
        tabard = dilate(visible['tabard'][..., 3] > 0, 6, grid_distance=True) & air
        tabard &= (xx >= 126) & (xx <= 138) & (yy >= 178)
        thigh = dilate(visible['leg_near'][..., 3] > 0, 3, grid_distance=True) & air
        thigh &= (xx <= 148) & (yy >= 173) & (yy <= 225)
        return {'hidden_cape_near': {'mask': root, 'clips': actions},
                'hidden_arm_near': {'mask': sleeve, 'clips': actions},
                'hidden_hand_far': {'mask': glove, 'clips': actions},
                'hidden_tabard': {'mask': tabard, 'clips': ['move']},
                'hidden_leg_near': {'mask': thigh, 'clips': ['move']}}
    own = visible['leg_far'][..., 3] > 0
    # Inner thigh/cloth overlap at the rear walk's narrowed lane. Only the
    # measured source edge band participates, not the leg's outer silhouette.
    inner = dilate(own, 3, grid_distance=True) & air
    inner &= (xx >= 125) & (xx <= 133) & (yy >= 176) & (yy <= 190)
    return {'hidden_leg_far': {'mask': inner, 'clips': ['move']}}
