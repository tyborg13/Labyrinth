"""Feedback-2 cloth coverage measured from approved and native label masks."""
import json
from pathlib import Path
import numpy as np
from PIL import Image, ImageDraw
from .mass_gates import labels

CLOTH_PROOF_DEFAULTS = {'alpha_threshold':128, 'painting_scale':4, 'native_size':1024, 'webp_effort':100}


def silhouette_measure(mask):
    widths=[]
    for y,row in enumerate(mask):
        xs=np.flatnonzero(row)
        for group in np.split(xs,np.flatnonzero(np.diff(xs)>1)+1):
            if len(group):widths.append((len(group),y,int(group[0]),int(group[-1])))
    if not widths:return {'width':0,'hem':0,'widest_row':0,'endpoints':[0,0]}
    width,y,left,right=max(widths)
    return {'width':width,'hem':int(np.argwhere(mask)[:,0].max())+1,
            'widest_row':y,'endpoints':[left,right]}


def cloth_row_passed(name, measured, approved, limits):
    return approved>0 and abs(measured/approved-1)<=limits[name]


def hem_points_passed(points, limits):
    return limits[0]<=points<=limits[1]


def source_cloth(folder, project):
    data=json.loads((folder/'cloth_annotations.json').read_text())
    recipe=json.loads((folder/'measurements.json').read_text())
    masks={}
    for view,parts in data['source_masks'].items():
        alpha=np.asarray(Image.open(project/recipe['sources'][view]).convert('RGBA'))[:,:,3]>=CLOTH_PROOF_DEFAULTS['alpha_threshold']
        masks[view]={}
        for name,polygon in parts.items():
            image=Image.new('1',(alpha.shape[1],alpha.shape[0]));ImageDraw.Draw(image).polygon([tuple(p) for p in polygon],fill=1)
            masks[view][name]=np.asarray(image,dtype=bool)&alpha
    return data,masks


def exterior_far_tail(mask, capture, view='front'):
    # The second far-tail fragment visible through the crotch is not the
    # exterior sliver requested by the director. Use unoccluded leg ownership.
    leg=np.logical_or.reduce([np.asarray(Image.open(capture/f'{view}_solo_{part}_far.png').convert('RGBA'))[:,:,3]>=128 for part in ['thigh','shin','foot']])
    result=mask.copy()
    for y,row in enumerate(leg):
        xs=np.flatnonzero(row)
        if len(xs):result[y,int(xs[0]):]=False
        else:result[y]=False
    return result


def inspect_cloth(folder,capture,spec,native):
    project=Path(__file__).resolve().parents[4]
    data,masks=source_cloth(folder,project)
    table={};observations={}
    for view,parts in masks.items():
        native_masks=labels(capture/f'{view}_parts.png',spec['labels']);observations[view]={}
        for label,source in parts.items():
            visible=native_masks[label]
            if view=='front' and label=='coat_far':visible=exterior_far_tail(visible,capture)
            approved=silhouette_measure(source);actual=silhouette_measure(visible)
            observations[view][label]={'source':approved,'native':actual}
            for measure in ['width','hem']:
                name=view+'_'+label+'_'+measure;reference=approved[measure]*4;value=actual[measure]
                table[name]={'approved_native_px':reference,'native_px':value,
                             'relative_error':value/reference-1 if reference else 0,'tolerance':data['limits'][name],
                             'minimum_px':None,'passed':cloth_row_passed(name,value,reference,data['limits'])}
    # Tip counts are read from the actual saved mesh's source-bound lower edge,
    # not inferred from antialiased one-pixel noise or occluded garment edges.
    hems=native.get('cloth_hems',{})
    point_checks={name:hem_points_passed(hems.get(name,{}).get('tip_count',0),limit)
                  for name,limit in data['hem_point_limits'].items()}
    return {'passed':all(row['passed'] for row in table.values()) and all(point_checks.values()),
            'table':table,'observations':observations,'hem_points':hems,
            'hem_point_checks':point_checks,'method':data['method']}


def review_cloth(folder,capture,result,background,guide):
    """Approved masks and actual ownership pixels, at the same native scale."""
    project=Path(__file__).resolve().parents[4];recipe=json.loads((folder/'measurements.json').read_text())
    data,masks=source_cloth(folder,project);size=CLOTH_PROOF_DEFAULTS['native_size']
    image=Image.new('RGBA',(2*size,2*size),background);draw=ImageDraw.Draw(image)
    for row,view in enumerate(['front','rear']):
        with Image.open(project/recipe['sources'][view]) as source:
            image.alpha_composite(source.convert('RGBA').resize((1020,1020),Image.Resampling.NEAREST),(0,row*size))
        with Image.open(capture/f'{view}_parts.png') as parts:image.alpha_composite(parts.convert('RGBA'),(size,row*size))
        for name,polygon in data['source_masks'][view].items():
            draw.line([(4*x,row*size+4*y) for x,y in polygon+[polygon[0]]],fill=guide,width=1)
            values=result['observations'][view][name]
            for column,key,scale in [(0,'source',4),(1,'native',1)]:
                observation=values[key];left,right=observation['endpoints'];y=observation['widest_row']*scale+row*size
                draw.line((column*size+left*scale,y,column*size+(right+1)*scale,y),fill='white',width=2)
                draw.text((column*size+left*scale,y+2),name+' '+str(observation['width']*scale),fill='white')
                hem=observation['hem']*scale+row*size
                draw.line((column*size+left*scale,hem,column*size+(right+1)*scale,hem),fill=guide,width=1)
    image.save(capture/'cloth_landmarks.webp',lossless=True,exact=True,method=6,quality=CLOTH_PROOF_DEFAULTS['webp_effort'])
