"""Keep the exact authoring partition before director-mandated presentation cleanup."""
import numpy as np
from PIL import Image
from rr18_case import CASE, PROJECT
from cutout_pipeline.cases import read_json, write_json, digest
from maquette_motion.bleed import edge_texels
from humanoid_cutout.material_gates import green_dominant


def raw_cut(visible, depths, view, refresh=False):
    path=CASE/f'raw_cut/{view}.json'
    if refresh or not path.exists():
        parts=[]
        for name,image in visible.items():
            ys,xs=np.nonzero(image[...,3]);box=[int(xs.min()),int(ys.min()),int(xs.max())+1,int(ys.max())+1]
            target=CASE/f'raw_cut/{view}/{name}.png';target.parent.mkdir(parents=True,exist_ok=True)
            Image.fromarray(image).crop(box).save(target)
            parts.append({'name':name,'file':str(target.relative_to(CASE)),'offset':box[:2],
                          'z_index':depths[name],'sha256':digest(target)})
        inputs=read_json(CASE/'inputs.json')
        source=inputs[view+'_job']+'/processed.png'
        write_json(path,{'source':source,'source_sha256':digest(PROJECT/source),'parts':parts})
    data=read_json(path)
    if 'source_sha256' not in data:
        data['source_sha256']=digest(PROJECT/data['source']);write_json(path,data)
    result={}
    for part in data['parts']:
        if digest(CASE/part['file'])!=part['sha256']:raise ValueError('Raw authoring partition changed: '+part['name'])
        image=np.zeros((255,255,4),dtype=np.uint8);paint=np.asarray(Image.open(CASE/part['file']).convert('RGBA'))
        x,y=part['offset'];image[y:y+paint.shape[0],x:x+paint.shape[1]]=paint
        result[part['name']]=image
    return result


def clean_visible(visible, margin):
    result={};corrections=[]
    for name,original in visible.items():
        image=original.copy();bad=green_dominant(image,margin)
        donors=image.copy();donors[bad]=0
        if bad.any() and not (donors[...,3]>0).any():raise ValueError('TODO_DESIGN_non_green_donor_'+name)
        fill=edge_texels(donors,bad) if bad.any() else np.zeros_like(image)
        for y,x in np.argwhere(bad):
            corrections.append({'piece':name,'source_xy':[int(x),int(y)],
                'raw_rgba':image[y,x].tolist(),'presentation_rgba':fill[y,x].tolist()})
        image[bad]=fill[bad];result[name]=image
    return result,corrections


def raw_identity(view):
    data=read_json(CASE/f'raw_cut/{view}.json');rest=Image.new('RGBA',(255,255))
    errors=[]
    for part in sorted(data['parts'],key=lambda p:p['z_index']):
        if digest(CASE/part['file'])!=part['sha256']:errors.append('raw authoring source changed: '+part['name'])
        rest.alpha_composite(Image.open(CASE/part['file']).convert('RGBA'),tuple(part['offset']))
    approved_source=read_json(CASE/'inputs.json')[view+'_job']+'/processed.png'
    if data['source']!=approved_source or data.get('source_sha256')!=digest(PROJECT/approved_source):errors.append('raw authoring protected reference changed')
    approved=np.asarray(Image.open(PROJECT/approved_source).convert('RGBA'))
    mismatch=int(np.any(np.asarray(rest)!=approved,axis=-1).sum())
    if mismatch:errors.append(f'{view}: raw authoring differs from approved painting by {mismatch} px')
    return {'ok':not errors,'errors':errors,'mismatch_pixels':mismatch,'scope':'exact pre-cleanup source partition against protected painting'}


def visible_errors(visible, depths, view, margin):
    raw=raw_cut(visible,depths,view);expected,_=clean_visible(raw,margin)
    errors=[]
    for name,image in visible.items():
        mismatch=int(np.any(image!=expected[name],axis=-1).sum())
        if mismatch:errors.append(f'{name}: visible presentation differs from prescribed raw-source cleanup by {mismatch} px')
    return errors
