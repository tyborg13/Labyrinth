"""Feedback-3 source continuations and measured material ownership.

Only approved texels are selected/copied. Full covered domains, rather than
posed hole patches, define the torso flank, cloak and glove/shaft underlap.
"""
import numpy as np
from functools import lru_cache
from PIL import Image
from humanoid_cutout.ownership import apply_override
from humanoid_cutout.covered_surfaces import row_outline
from maquette_motion.silhouette import dilate
from maquette_motion.bleed import edge_texels
from maquette_motion.material_palette import interior_donors, outline_class

INTERIOR_MARGIN_PX = 2  # Director feedback 3.
REAR_SHAFT_CORE_WIDTH_PX = 3  # Upper end of the director's 2–3px shaft target.


def rear_shaft_core(x,y):
    centre=rear_shaft_axis()[np.clip(np.asarray(y,dtype=int),0,254)]
    return (y>=82)&(y<=245)&(abs(x-centre)<REAR_SHAFT_CORE_WIDTH_PX/2)


@lru_cache(maxsize=1)
def rear_shaft_axis():
    """Interpolate the approved wood's measured row centres through occlusion.

    A straight maquette fit sits several texels left of the painted lower
    shaft. Its narrow tuck must follow the painting, rather than bridge that
    registration error with a broad strip.
    """
    from rr37_case import CASE
    from rr43_outline import registration_paint
    paint=registration_paint()
    mask=rear_shaft(paint)
    r,g,b=paint[...,:3].astype(int).transpose(2,0,1)
    wood=mask & (r>g) & (r>b)
    rows=np.flatnonzero(wood.any(axis=1))
    centres=[float(np.median(np.flatnonzero(wood[y]))) for y in rows]
    return np.interp(np.arange(255),rows,centres)


def interior(seed, definition, outline_source=None):
    original=seed if outline_source is None else outline_source
    own = original[..., 3] > 0
    outline=(own & dilate(~own,1)) | outline_class(original,definition)
    result = interior_donors(seed, definition)
    result[dilate(~own | outline, INTERIOR_MARGIN_PX)] = 0
    return result


def rear_shaft(paint):
    y, x = np.indices(paint.shape[:2])
    r, g, b = paint[..., :3].astype(int).transpose(2, 0, 1)
    # Material boundary measured on the approved rear: the glove occludes
    # rows 102..118, and the cloak crosses the lower shaft near row 158.
    # rr-43: measured on the registered v2, including the floor-length end.
    band = (y >= 84) & (y <= 245) & (abs(x - (234 - .375*y)) <= 6)
    brown = band & (r > 1.3*g) & (r > 1.6*b) & (paint[..., 3] > 0)
    brown[(y >= 102) & (y <= 118)] = False
    # Include only the shaft's adjacent dark outline, never a pink glove or
    # teal cloak neighbour. This transfers existing source pixels unchanged.
    dark = (r <= 45) & (g <= 22) & (b <= 15)
    mask = brown | (dilate(brown, 2) & dark & (paint[..., 3] > 0))
    # The approved shaft has disconnected black edge runs two texels from
    # its brown core. All opaque pixels in its corridor outside the cloak
    # belong to the item too; colour-only cuts left these runs on cape_far.
    corridor=(y>=84)&(y<=245)&(abs(x-(234-.375*y))<=6)
    cloth=(b>r)&(g>r)&(x<185)&(paint[...,3]>0)
    edge=np.array([np.flatnonzero(row)[-1] if row.any() else -1 for row in cloth])
    outside=(y<102)|((y>=119)&(y<=174)&(x>edge[:,None]+2))
    mask |= corridor & outside & (paint[...,3]>0)
    mask[(y >= 102) & (y <= 118)] = False
    # The v2 shaft passes behind the cloak/leg here. Warm leg pixels in
    # this corridor are not exposed wood and must not bend the hidden axis.
    mask[(y >= 175) & (y < 214)] = False
    # The supplied palette transfer leaves a teal one-pixel outer fringe on
    # the new floor end. It is still the spear's outline, not cloak or boot.
    # Keeping it on those pieces leaves a shaft-shaped ghost during attacks.
    # Include the entire measured three-texel keyed fringe, including olive
    # and near-black samples. Colour classification alone strands those
    # samples on the cloak after the supplied material palette transfer.
    fringe_band = (y >= 84) & (y <= 245) & (abs(x - (234 - .375*y)) <= 8)
    fringe = dilate(mask, 3) & fringe_band & (paint[..., 3] > 0)
    exposed = (y < 102) | ((y >= 119) & (y < 175)) | (y >= 214)
    from maquette_motion.silhouette import components
    expanded = mask | (fringe & exposed)
    labels, groups = components(expanded, 8)
    # A nearby boot edge can fall inside the fringe's bounding corridor.
    # Retain only components actually connected to approved wood/ink seeds.
    retained = [label for label, _ in groups if (mask & (labels == label)).any()]
    mask |= fringe & exposed & np.isin(labels, retained)
    return mask


def ownership(view, visible, paint):
    y, x = np.indices(paint.shape[:2])
    if view == 'front':
        r, g, b = paint[..., :3].astype(int).transpose(2, 0, 1)
        strip = (x < 90) & (y >= 80) & (y <= 145) & (g > r) & (b > r)
        strip &= visible['cape_near'][..., 3] > 0
        apply_override(visible, paint, strip, 'cape_far')
    else:
        # rr-37 native guard/lunge exposes this near-hem edge on cape_far.
        # It is the near cloth's outer ink; carry it on that cloth while the
        # far cloth continues beneath with its own existing interior texels.
        hem = np.zeros(paint.shape[:2], bool)
        hem[205, 106] = True  # Registered source UV of the reviewed native texel.
        apply_override(visible, paint, hem, 'cape_near')
        old = visible['spear'][..., 3] > 0
        shaft = rear_shaft(paint)
        correct = shaft | (old & (y < 84))
        foreign = old & ~correct
        glove = foreign & (y >= 102) & (y <= 118)
        apply_override(visible, paint, foreign & ~glove, 'cape_far')
        apply_override(visible, paint, glove, 'hand_far')
        apply_override(visible, paint, correct, 'spear')


def domains(view, visible, paint, solos):
    own = {n: im[..., 3] > 0 for n, im in visible.items()}
    painted = paint[..., 3] > 0
    if view == 'front':
        from rr39_underlay import domains as director_domains
        return director_domains(visible, solos)
    # The approved cloth edge bounds this rear continuation. The maquette's
    # wider hidden wedge extends into air below the hand in this painting.
    cloak=rear_cloak_outline(visible,paint)
    return {'cape_far': cloak & own['spear'] & painted}


def cover(view, visible, hidden, paint, definition, solos):
    required = domains(view, visible, paint, solos)
    if view == "front":
        from rr39_underlay import replace
        required = replace(visible, hidden, solos)
        from rr41_underlay import replace as replace_legs
        replace_legs(hidden)
        return required
    for name, target in required.items():
        target &= visible[name][..., 3] == 0
        fill = edge_texels(interior(visible[name], definition), target)
        hidden[name][target] = fill[target]
    if view == 'rear':
        outline=rear_cloak_outline(visible,paint)
        yy,_=np.indices(outline.shape)
        allowed=outline | (yy<80) | (yy>180)
        for name in ('cape_near','cape_far'):hidden[name][~allowed]=0
        y, x = np.indices(paint.shape[:2])
        # A narrow, continuous shaft tuck under the glove and crossing cloak.
        # Its centre/width are measured from the approved shaft, not the broad
        # maquette ownership wedge which previously carried glove/cloth.
        target = rear_shaft_core(x,y)
        target &= (paint[..., 3] > 0) & (visible['spear'][..., 3] == 0)
        hidden['spear'] = edge_texels(visible['spear'], target, definition)
    return required


def rear_cloak_outline(visible,paint):
    r,g,b=paint[...,:3].astype(int).transpose(2,0,1)
    cloak=(visible['cape_far'][...,3]>0)|(visible['cape_near'][...,3]>0)
    from humanoid_cutout.materials import connected_mask
    cloth=cloak & (b>r) & (g>r)
    # Retain the cloth's own dark outer edge and pouch pixels, but not a
    # disconnected shaft fringe which happens to sit beside that edge.
    return row_outline(connected_mask(cloth,cloak))


def coherent_fill(seed,target):
    """Translate one approved interior field; never stretch a lone edge texel.

    Maximize covered donor area, then minimize translation. Missing patch-edge
    samples use the same exact nearest interior donor in translated space.
    """
    if not target.any():return np.zeros_like(seed)
    ty,tx=np.nonzero(target);sy,sx=np.nonzero(seed[...,3])
    if not len(sx):raise ValueError('TODO_DESIGN_covered_surface_interior')
    centre=np.rint([(ty.min()+ty.max())/2,(tx.min()+tx.max())/2]).astype(int)
    shifts=np.column_stack((sy,sx))-centre
    best=None
    for dy,dx in shifts:
        yy,xx=ty+dy,tx+dx
        inside=(yy>=0)&(xx>=0)&(yy<seed.shape[0])&(xx<seed.shape[1])
        valid=inside.copy();valid[inside]=seed[yy[inside],xx[inside],3]>0
        score=(int(valid.sum()),-int(dy*dy+dx*dx))
        if best is None or score>best[0]:best=(score,int(dy),int(dx))
    nearest=edge_texels(seed,np.ones(target.shape,bool))
    yy=np.clip(ty+best[1],0,seed.shape[0]-1);xx=np.clip(tx+best[2],0,seed.shape[1]-1)
    result=np.zeros_like(seed);result[ty,tx]=nearest[yy,xx]
    return result


def provenance(case, layout, visible, definition):
    """Certify source donor depth before density changes encoded RGB values."""
    from maquette_motion.features import source_pixels
    from humanoid_cutout.native_defects import packed
    from rr37_coverage import donors
    for part in layout['parts']:
        image=source_pixels(case,part)
        seed=interior(donors(visible[part['logical_part']],part['logical_part']),definition,visible[part['logical_part']])
        values=np.unique(packed(seed)[seed[...,3]>0])
        valid=(image[...,3]>0) & np.isin(packed(image),values) if part.get('hidden_material') else image[...,3]>0
        from rr41_underlay import paint_mask
        approved = paint_mask(case, layout, part)
        valid |= approved
        path = case/f'uncovered/painted_{layout["facing"]}_{part["name"]}.png'
        if approved.any(): Image.fromarray(approved.astype('uint8')*255).save(path)
        else: path.unlink(missing_ok=True)
        Image.fromarray(valid.astype('uint8')*255).save(case/f'uncovered/donor_{layout["facing"]}_{part["name"]}.png')
