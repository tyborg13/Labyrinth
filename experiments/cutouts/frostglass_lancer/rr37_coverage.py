"""Own-material underlaps, cut from approved material; never hidden paintings."""
import numpy as np
from PIL import Image, ImageDraw
from maquette_motion.bleed import edge_texels
from humanoid_cutout.covered_surfaces import row_outline
from humanoid_cutout.materials import connected_mask
from maquette_motion.silhouette import components, dilate

SHAFT_BOUNDARY = {'front': [(40,73),(48,73),(79,221),(77,222),(76,224),(73,224)],
                  'rear': [(200,82),(206,82),(169,171),(163,171)]}


def donors(image, name):
    result=image.copy()
    r,g,b=result[...,:3].astype(int).transpose(2,0,1)
    if name.startswith('cape_') or name=='tabard': result[(b<=r)|(g<=r)]=0
    if name=='spear': result[(r<=g)|(r<=b)]=0  # Shaft, never crystal, under the grip.
    if name=='torso': result[(b>r)|(g>r)]=0  # Mail/leather, never scarf or chest crystal.
    return result


def cover(view, visible, hidden, paint, definition):
    # Continue the cloak under the complete covered source footprint. Both
    # halves keep their own fields and own blue cloth donors.
    cloak=(visible['cape_near'][...,3]>0)|(visible['cape_far'][...,3]>0)
    surface=row_outline(cloak)&(paint[...,3]>0)
    for name in ('cape_near','cape_far'):
        own=visible[name][...,3]>0
        target=connected_mask(own,surface&~own)
        hidden[name]=edge_texels(donors(visible[name],name),target,definition)
    # A source outline can be connected to the painting yet separated from
    # its own sleeve by covered cloth. Continue that sleeve through its own
    # one-pixel cut gap, beneath the covering source paint.
    for name in ('arm_near','arm_far','leg_near','leg_far'):
        own=visible[name][...,3]>0
        labels,groups=components(own,8)
        if len(groups)>1:
            target=dilate(own,1)&(paint[...,3]>0)&~own
            missing=target&(hidden[name][...,3]==0)
            fill=edge_texels(donors(visible[name],name),missing,definition)
            hidden[name][missing]=fill[missing]
    mask=Image.new('1',(255,255));ImageDraw.Draw(mask).polygon(SHAFT_BOUNDARY[view],fill=1)
    target=np.asarray(mask)&(paint[...,3]>0)&(visible['spear'][...,3]==0)
    hidden['spear']=edge_texels(donors(visible['spear'],'spear'),target,definition)
