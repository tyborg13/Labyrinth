#!/usr/bin/env python3
"""Focused source/CPU diagnostics; native acceptance is keyframes.py's gate."""
from pathlib import Path
import sys
import json
import numpy as np
from PIL import Image, ImageDraw
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'tools'))
from cutout_pipeline.cases import read_json
from maquette_motion.gates import unpack
CASE=ROOT/'experiments/cutouts/emaciated_man/emac02'

def green_count(image):
    a=np.array(image.convert('RGBA'))
    return int(((a[...,1]>a[...,[0,2]].max(axis=-1))&(a[...,3]>0)).sum())

def sack_mask(case=CASE):
    config=read_json(case/'cutout.json');layout=read_json(case/config['layouts']['front'])
    recipe=read_json(case/'recipes/rig.json')
    region=next(r for r in recipe['ownership_regions']['front'] if r['part']=='ember_sack')
    mask=Image.new('1',(255,255));ImageDraw.Draw(mask).polygon([tuple(p) for p in region['polygon']],fill=1)
    owners=np.load(case/'registered/front_owners.npy',allow_pickle=False)
    result=np.array(mask,dtype=bool)&(owners==layout['logical_parts'].index('ember_sack'))
    # Round 2 explicitly lets both hands settle 2px onto the sack/knee.
    # Test the static sack surface outside the complete moving contact sweep.
    upper=layout.get('idle_groups',{}).get('upper',{}).get('bones',[])
    for part in layout['parts']:
        if part['bone'] not in upper or part.get('hidden_material'):continue
        alpha=np.array(Image.open(case/part['file']).convert('RGBA'))[...,3]>0
        x,y=part['offset']
        for dy in range(3):
            h=min(alpha.shape[0],255-y-dy);w=min(alpha.shape[1],255-x)
            result[y+dy:y+dy+h,x:x+w]&=~alpha[:h,:w]
    return result

def main():
    config=read_json(CASE/'cutout.json');layout=read_json(CASE/config['layouts']['front'])
    assert layout['glow_min_saturation']==.75
    paths=[CASE/'source/front/processed.png']+[CASE/p['file'] for p in layout['parts']]
    paths+=list((ROOT/'assets/units/emaciated_man_cutout/front').glob('*.png'))
    assert all(green_count(Image.open(p))==0 for p in paths), 'Green residue in runtime paint'
    parts=sorted(layout['parts'],key=lambda p:p['z_index']);rows=read_json(CASE/'proof/motion_samples.json')['samples']
    mask=sack_mask();base=None;peak=0
    for row in rows:
        canvas=Image.new('RGBA',(512,512))
        for p in parts:
            t=unpack(row['bones'][p['bone']]['global']);basis=t[:2,:2];pivot=np.array(layout['joints'][p['bone']]['position'])
            origin=t[:2,2]+np.einsum('ij,j->i',basis,np.array(p['offset'])-pivot)+128
            inv=np.linalg.inv(basis);offset=-np.einsum('ij,j->i',inv,origin)
            affine=(*inv[0],offset[0],*inv[1],offset[1])
            im=Image.open(CASE/p['file']).convert('RGBA').transform((512,512),Image.Transform.AFFINE,affine,Image.Resampling.NEAREST)
            canvas.alpha_composite(im)
        native=np.array(canvas.crop((128,128,383,383)))
        if base is None:base=native.copy()
        changes=int(np.any(native[mask]!=base[mask],axis=-1).sum());peak=max(peak,changes)
        assert changes==0, 'Sack source-pixel seam at phase '+str(row['phase'])
    result={'ok':True,'poses':len(rows),'static_sack_pixels':int(mask.sum()),'max_sack_changed_pixels':peak,'green_pixels':0,'glow_min_saturation':.75,'basis':'CPU nearest-affine diagnostic; native mesh/frame gate remains required'}
    (CASE/'proof/round1_cpu.json').write_text(json.dumps(result,indent=2)+'\n')
    print('EMAC ROUND1 CPU: PASS; poses=%d; sack_changed_pixels=%d; green_pixels=0; glow_cutoff=0.75'%(len(rows),peak))
if __name__=='__main__':main()
