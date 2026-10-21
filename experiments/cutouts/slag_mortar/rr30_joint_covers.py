"""Construct joint-local rigid covers from adjacent approved painted material.

No animation, source painting or visible source ownership changes. Static
source cuts calibrated over the complete CPU sweep remove raster-edge texels
whose presented footprint exceeds the director's three-pixel joint bound.
"""
import numpy as np
from maquette_motion.bleed import edge_texels
from maquette_motion.material_palette import luma
from humanoid_cutout.materials import connected_mask
from rr30_joint_geometry import (COVER_LIMIT_PX,SKIN_PREFIXES,
                                interfaces,declared_joins,distance,material_floor)

# Clarification requested from the director; literal hinge disks cannot span
# the painted limb contact. This is recorded explicitly in the proof contract.
TODO_DESIGN_joint_cover_distance_basis = 'painted_contact_boundary'


def construct(visible, hidden, paint, anatomy, definition, *, view, joints):
    contacts=interfaces(visible,declared_joins(anatomy))
    skin_floor=max(material_floor(image,definition) for name,image in visible.items()
                   if name.startswith(SKIN_PREFIXES))
    from rr30_joint_calibrate import CUTS,basis
    from cutout_pipeline.cases import read_json
    # The caller supplies the complete rest joint map; calibration binds that
    # map and every immutable visible cut, rather than a selected clip/frame.
    calibration=read_json(CUTS).get(view) if CUTS.exists() else None
    if calibration and calibration['basis']!=basis(visible,joints):
        raise ValueError('Joint source cuts stale: recalibrate changed visible paint/joints')
    records={}
    for name,image in visible.items():
        original=hidden[name].copy()
        target=(paint[...,3]>0) & (image[...,3]==0)
        yy,xx=np.nonzero(target)
        points=np.column_stack((xx+.5,yy+.5))
        nearest=np.full(len(points),np.inf)
        result=np.zeros_like(image)
        for row in contacts.values():
            if name not in row['pieces'] or not row['segments']: continue
            other=next(n for n in row['pieces'] if n!=name)
            distances=distance(points,row['segments'])
            retained=original[yy,xx,3]>0
            selected=((distances<=COVER_LIMIT_PX)|retained) & (distances<nearest)
            if not selected.any(): continue
            mask=np.zeros_like(target);mask[yy[selected],xx[selected]]=True
            seed=image.copy()
            if name.startswith(SKIN_PREFIXES) and other.startswith(SKIN_PREFIXES):
                seed[visible[other][...,3]>0]=visible[other][visible[other][...,3]>0]
            elif name in ('torso','pelvis') and other.startswith(SKIN_PREFIXES):
                seed=visible[other].copy()
            floor=material_floor(seed,definition)
            if name.startswith(SKIN_PREFIXES) or name in ('torso','pelvis'):
                # A bent limb can overlap another limb's skin region. Every
                # newly revealed donor must meet all painted skin minima.
                floor=max(floor,skin_floor)
            seed[luma(seed)<floor]=0
            fill=edge_texels(seed,mask)
            result[mask]=fill[mask]
            nearest[selected]=distances[selected]
        for x,y in calibration['cuts'].get('hidden_'+name,[]) if calibration else []:
            result[y,x]=0
        result[~connected_mask(image[...,3]>0,result[...,3]>0)]=0
        hidden[name][:]=result
        records[name]=dict(removed_texels=int(((original[...,3]>0)&(result[...,3]==0)).sum()),
                           covered_texels=int((result[...,3]>0).sum()),
                           changed_colour_texels=int(((result[...,3]>0)&np.any(result!=original,axis=2)).sum()))
    return dict(distance_basis=TODO_DESIGN_joint_cover_distance_basis,
                maximum_visible_distance_px=COVER_LIMIT_PX,
                source_contact_radius_px=COVER_LIMIT_PX,
                pieces=records)


def bound_action_domains(action, visible, anatomy, *, view):
    from rr30_joint_calibrate import CUTS
    from cutout_pipeline.cases import read_json
    contacts=interfaces(visible,declared_joins(anatomy))
    cuts=read_json(CUTS)[view]['cuts'] if CUTS.exists() else {}
    for name,mask in action.items():
        segments=[row['segments'] for row in contacts.values() if name in row['pieces'] and row['segments']]
        yy,xx=np.nonzero(mask)
        selected=distance(np.column_stack((xx+.5,yy+.5)),np.concatenate(segments))<=COVER_LIMIT_PX
        mask[:]=False;mask[yy[selected],xx[selected]]=True
        for x,y in cuts.get('hidden_'+name,[]):mask[y,x]=False
