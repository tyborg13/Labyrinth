"""Partition whole approved underlays between their registered receivers.

Only pixel ownership changes. Every opaque director texel survives with its
exact RGBA, including all texels outside the visible painting's alpha. Joint
tucks overlap their receiving surfaces at the same source coordinates.
"""
from pathlib import Path
import numpy as np
from PIL import Image, ImageDraw
from cutout_pipeline.cases import read_json, write_json, digest
from humanoid_cutout.skin_layers import layer
from maquette_motion.silhouette import dilate

RECEIVERS=('head','torso','pelvis','robe','robe_back','leg_near','leg_far','foot_near','foot_far')


def supply(case,layout,images,store,meshes):
    root=case.parents[3];view=layout['facing']
    source=root/f'spec/peer_benchmark/staged/rr-52/{view}_body_underlay.png'
    paint=np.asarray(Image.open(source).convert('RGBA'))
    provenance=read_json(source.parent/'provenance.json')
    if digest(source)!=provenance['files'][source.name]:raise ValueError('Changed protected underlay')
    from rr52_source import plans,DEPTH_PX
    source_plans,tuck_policy=plans(case,layout,images,paint,meshes)
    rest=Image.new('RGBA',(255,255));originals={p['name']:p for p in layout['parts']};receipt=[]
    for i,(name,plan) in enumerate(source_plans.items()):
        n=plan['logical'];image=plan['image'];domain=image[...,3]>0
        part=dict(store(image,view,name,align_to=originals[n]['bbox']),bone=plan['bone'],logical_part=n,hidden_material=True,z_index=i-len(source_plans),presentation_anchor=originals[n].get('presentation_anchor',originals[n]['offset']))
        if name.startswith('cap_'):part['presentation_anchor']=layout['joints'][plan['bone']]['position']
        if n in ('hand_near','lantern'):part['presentation_anchor']=layout['held_items']['lantern']['source_grip']
        sources={}
        for kind in ('underlay','cap','tuck'):
            path=case/f'ownership/{view}_{name}_{kind}.png';path.parent.mkdir(exist_ok=True);Image.fromarray(plan[kind].astype('uint8')*255).save(path);sources[kind]=str(path.relative_to(case))
        part['paint_sources']=sources
        if n in RECEIVERS and name.startswith('hidden_'):part['director_underlay']=True
        layout['parts'].append(part);layout['source_labels'][name]=[n]
        for members in layout['idle_groups'].values():
            if n in members:members.append(name)
        skinned=n in meshes and not name.startswith('cap_')
        if skinned:layout['joint_meshes'].append(layer(part,n,originals[n]['bbox'],layout['joints'],part['z_index'],True,recipe=meshes[n]))
        check=np.zeros_like(image);check[domain]=[255,255,0,255];cp=case/f'checks/{view}/{name}.png';Image.fromarray(check).crop(part['bbox']).save(cp)
        layout['proof_layers'][name]={'mask':str(cp.relative_to(case)),'mask_offset':part['offset'],'z_index':part['z_index'],'source':part['file'],'rigid':not skinned,'source_sha256':digest(case/part['file'])}
        if not name.startswith('hidden_'):continue
        mask=plan['tuck'];path=case/f'tucks/{view}_{n}.png';path.parent.mkdir(exist_ok=True);Image.fromarray(mask.astype('uint8')*255).save(path)
        supplied=(image[...,3]>0)|(images[n][...,3]>0);bindings=[]
        for other,im in images.items():
            take=mask&~supplied&(im[...,3]>0)
            if take.any():
                yy,xx=np.nonzero(take);bindings.append({'part':other,'texels':np.column_stack((xx,yy)).tolist()});supplied|=take
        if mask.any():receipt.append({'piece':n,'minimum_px':DEPTH_PX,'cover':plan['covers'],'required_mask':str(path.relative_to(case)),'required_pixels':int(mask.sum()),'missing_pixels':int((mask&~supplied).sum()),'owner_bindings':bindings,'status':'PASS' if not (mask&~supplied).any() else 'FINDING_missing_paint'})
    write_json(case/f'proof/{view}_tuck_supply.json',{'tucks':receipt,'policy':tuck_policy,'native_pixels':False})
    for p in sorted(layout['parts'],key=lambda p:p['z_index']):rest.alpha_composite(Image.open(case/p['file']).convert('RGBA'),tuple(p['offset']))
    target=case/f'source/{view}/assembled_rest.png';rest.save(target);layout['rest_source']=str(target.relative_to(case));layout['rest_source_sha256']=digest(target)
    original=np.asarray(Image.open(root/layout['raw_rest_source']).convert('RGBA'));outside=(np.asarray(rest)[...,3]>0)&(original[...,3]==0)
    y,x=np.nonzero(outside);bbox=[int(x.min()),int(y.min()),int(x.max()+1),int(y.max()+1)] if len(x) else None
    longest=0
    for row in outside:
        run=0
        for value in row:
            run=run+1 if value else 0;longest=max(longest,run)
    vertical=0
    for row in outside.T:
        run=0
        for value in row:
            run=run+1 if value else 0;vertical=max(vertical,run)
    crop=None
    if bbox:
        x,y,r,b=bbox;crop=[max(0,x-4),max(0,y-4),min(255,r+4),min(255,b+4)]
        rest.crop(crop).resize(((crop[2]-crop[0])*4,(crop[3]-crop[1])*4),Image.Resampling.NEAREST).save(case/f'proof/{view}_outside_rest_4x.png')
    write_json(case/f'proof/{view}_underlay.json',{'exact_rgba':True,'whole_underlay_opaque_texels':int((paint[...,3]>0).sum()),'outside_painting_count':int(outside.sum()),'outside_painting_bbox':bbox,'longest_horizontal_run_px':longest,'longest_vertical_run_px':vertical,'longest_run_px':max(longest,vertical),'bbox_format':'[left,top,right,bottom), source pixels','crop':crop,'crop_4x':f'proof/{view}_outside_rest_4x.png','native_pixels':False})
