"""Single-translation source silhouette and semantic centroid fit at 255px."""
import json
import numpy as np
from PIL import Image,ImageDraw
from .mass_gates import source_measurements,labels
from .cloth_gates import source_cloth

FIT_PROOF_DEFAULTS={'size_px':255,'alpha_threshold':128,'fft_padding':512,'overlay_scale':4,
                    'outline_colour':(80,220,240,255),'outline_width_px':1}
FIT_LABELS=('head','hand_far','chain_hook','hand_near','foot_near','foot_far','tabard')


def silhouette(path):
    return np.asarray(Image.open(path).convert('RGBA').resize((255,255),Image.Resampling.LANCZOS))[:,:,3]>=128


def best_translation(source,clay):
    size=FIT_PROOF_DEFAULTS['fft_padding']
    correlation=np.fft.irfft2(np.fft.rfft2(source,s=(size,size))*np.conj(np.fft.rfft2(clay,s=(size,size))),s=(size,size)).round().astype(int)
    # Tie break by smallest translation, then Y/X, independent of FFT storage.
    candidates=np.argwhere(correlation==correlation.max())
    offsets=[(int(x if x<size//2 else x-size),int(y if y<size//2 else y-size)) for y,x in candidates]
    dx,dy=min(offsets,key=lambda p:(p[0]**2+p[1]**2,p[1],p[0]))
    overlap=int(correlation.max())
    return {'translation_px':[dx,dy],'iou':overlap/int(source.sum()+clay.sum()-overlap)}


def centroid(mask):
    if not mask.any():raise ValueError('Empty fit semantic mask')
    return np.argwhere(mask).mean(0)[::-1]


def centroid_passed(offset,limit):
    return bool(np.linalg.norm(offset)<=limit)



def iou_passed(value,limit):
    return value>=limit


def native_masks_255(capture,palette):
    return {name:np.asarray(Image.fromarray(mask.astype('uint8')*255).resize((255,255),Image.Resampling.LANCZOS))>=128
            for name,mask in labels(capture/'front_parts.png',palette).items()}


def source_masks(folder,project):
    recipe=json.loads((folder/'measurements.json').read_text());data=json.loads((folder/'fit_annotations.json').read_text())
    path=project/recipe['sources']['front'];alpha=silhouette(path)
    _,masks,_=source_measurements(folder,path)
    _,cloth=source_cloth(folder,project);masks['tabard']=cloth['front']['tabard']
    for name,polygons in data['additional_source_polygons'].items():
        im=Image.new('1',(255,255));draw=ImageDraw.Draw(im)
        for polygon in polygons:draw.polygon([tuple(p) for p in polygon],fill=1)
        masks[name]=(masks.get(name,np.zeros_like(alpha))|np.asarray(im,bool))&alpha
    for name,path in data.get('fit_mask_files',{}).items():
        from pathlib import Path
        masks[name]=(np.asarray(Image.open(Path(folder)/path).convert('L'))>0)&alpha
    return data,{name:masks[name] for name in (*FIT_LABELS,*data.get('additional_fit_labels',[]))}


def inspect_fit(folder,capture,project,spec,native):
    data,source=source_masks(folder,project);recipe=json.loads((folder/'measurements.json').read_text())
    views={view:best_translation(silhouette(project/recipe['sources'][view]),silhouette(capture/(view+'_clay.png'))) for view in ('front','rear')}
    maps=native_masks_255(capture,spec['labels']);table={}
    for name in source:
        approved=centroid(source[name])
        if name=='chain_hook':actual=np.array(native['hook_centroid_255_px'])
        else:
            actual=centroid(maps[name])
        offset=actual+views['front']['translation_px']-approved
        table[name]={'approved_centroid_px':approved.tolist(),'native_centroid_px':actual.tolist(),
                     'offset_px':offset.tolist(),'distance_px':float(np.linalg.norm(offset)),
                     'limit_px':data['centroid_limit_px'],'passed':centroid_passed(offset,data['centroid_limit_px'])}
    passed=all(v['passed'] for v in table.values()) and iou_passed(views['front']['iou'],data['front_iou_minimum'])
    return {'passed':passed,'table':table,'views':views,'front_iou_minimum':data['front_iou_minimum'],'method':data['method']}


def outline_overlay(folder,capture,project,result):
    recipe=json.loads((folder/'measurements.json').read_text())
    image=Image.open(project/recipe['sources']['front']).convert('RGBA')
    image=Image.alpha_composite(Image.new('RGBA',image.size,(24,24,24,255)),image)
    clay=silhouette(capture/'front_clay.png');edge=clay&~(np.roll(clay,1,0)&np.roll(clay,-1,0)&np.roll(clay,1,1)&np.roll(clay,-1,1))
    dx,dy=result['views']['front']['translation_px'];draw=ImageDraw.Draw(image)
    for y,x in np.argwhere(edge):draw.point((int(x+dx),int(y+dy)),fill=FIT_PROOF_DEFAULTS['outline_colour'])
    image.resize((1020,1020),Image.Resampling.NEAREST).convert('RGB').save(capture/'front_fit_overlay.webp',lossless=True,exact=True,method=6,quality=100)
