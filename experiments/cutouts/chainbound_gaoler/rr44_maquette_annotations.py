"""Source-derived new-arm measurements; original mq-15 limits stay exact."""
import numpy as np
from PIL import Image
from rr44_case import CASE,PROJECT
from cutout_pipeline.cases import read_json,write_json
from maquette_motion.features import source_pixels


def prepare():
    original=PROJECT/'spec/art_identity/maquettes/chainbound_gaoler';folder=CASE/'maquette'
    layout=read_json(CASE/'layouts/front.json');parts={p['name']:p for p in layout['parts']}
    images={n:source_pixels(CASE,p)[...,3]>0 for n,p in parts.items()}
    yy,_=np.indices((255,255));elbow=layout['joints']['fore_far']['position'][1]
    masks=dict(upper_far=images['arm_far']&(yy<elbow),fore_far=images['arm_far']&(yy>=elbow),
               hand_far=images['hand_far'],chain=images['chain'],chain_hook=images['chain']&(yy>=195))
    paths={}
    for name,mask in masks.items():
        path=folder/f'source_{name}.png';Image.fromarray((mask*255).astype(np.uint8)).save(path);paths[name]=path.name
    for name in ('mass_annotations','cloth_annotations','fit_annotations'):
        data=read_json(original/(name+'.json'))
        if name=='mass_annotations':
            data['source_mask_files']=paths
            ys=np.nonzero(images['hand_far'])[0]
            data['source_scanlines']['chain_fist']=['hand_far',float((ys.min()+ys.max())/2)]
            for label,a,b in [('upper_far','upper_far','fore_far'),('fore_far','fore_far','hand_far')]:
                data['source_arm_axes'][label]=[layout['joints'][a]['position'],layout['joints'][b]['position']]
        if name=='fit_annotations':
            data['fit_mask_files']=paths;data['additional_fit_labels']=['upper_far','fore_far','chain']
        write_json(folder/(name+'.json'),data)


if __name__=='__main__':prepare()
