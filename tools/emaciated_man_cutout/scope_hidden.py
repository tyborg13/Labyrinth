#!/usr/bin/env python3
"""Limit hidden-material requests to the sampled idle's exposed support.

CPU texel visibility plus a one-texel raster margin is diagnostic authoring
support. Native seam approval still requires the director's rendered frames.
"""
from pathlib import Path
import sys
import numpy as np
from PIL import Image
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'tools'))
from maquette_cutout import request_image, material_neighbours, save_image, bbox, rest_identity, contact_sheet
from cutout_pipeline.cases import read_json, write_json, digest, baseline
from maquette_motion.gates import unpack
from maquette_motion.exposure import transformed_mask
CASE=ROOT/'experiments/cutouts/emaciated_man/emac02'
PROOF_DEFAULTS={'raster_margin_px':1,'canvas':512,'offset':128}

def main():
    config=read_json(CASE/'cutout.json'); path=CASE/config['layouts']['front']; layout=read_json(path)
    recipe=read_json(CASE/'recipes/rig.json')
    if 'hidden_motion_scope' in recipe: raise ValueError('Scope only a fresh unfilled build')
    rows=read_json(CASE/'proof/motion_samples.json')['samples']; names=layout['logical_parts']
    owners=np.load(CASE/'registered/front_owners.npy',allow_pickle=False)
    paint=np.array(Image.open(CASE/'source/front/processed.png').convert('RGBA'))
    parts=sorted(layout['parts'],key=lambda p:p['z_index'])
    supports={p['name']:np.zeros((255,255),bool) for p in parts if p.get('hidden_material')}
    for row in rows:
        physical=np.full((512,512),-1,np.int32)
        for i,p in enumerate(parts):
            # This idle is rigid: integer-shift the original texels. Inverting
            # float Bone2D pivots here invents subpixel exposure between pieces
            # that translate together, contrary to the rigid-pixel contract.
            source=np.array(Image.open(CASE/p['file']).convert('RGBA'))[...,3]>0
            bone=p['bone']; origin=np.array(row['bones'][bone]['global'][4:])
            delta=np.rint(origin-np.array(layout['joints'][bone]['position'])).astype(int)
            x,y=np.array(p['offset'],int)+delta+128
            region=physical[y:y+source.shape[0],x:x+source.shape[1]]
            region[source]=i
        for i,p in enumerate(parts):
            if p['name'] not in supports: continue
            y,x=np.nonzero(physical==i)
            delta=np.rint(np.array(row['bones'][p['bone']]['global'][4:])-np.array(layout['joints'][p['bone']]['position'])).astype(int)
            xy=np.array([x,y])-128-delta[:,None]
            valid=(xy>=0).all(axis=0)&(xy<255).all(axis=0)
            supports[p['name']][xy[1,valid],xy[0,valid]]=True
    requests=read_json(CASE/'hidden_requests/index.json'); scope={}; counts={}
    for request in requests['requests']:
        name=request['part']; full=np.load(CASE/f'registered/front_hidden_{name}.npy',allow_pickle=False)
        mask=np.zeros_like(full)
        for p in parts:
            if p.get('hidden_material') and p['logical_part']==name:
                mask|=supports[p['name']]
        # Protect nearest-sampler/GPU edge ties without filling the whole solo.
        grown=mask.copy()
        grown[1:]|=mask[:-1];grown[:-1]|=mask[1:];grown[:,1:]|=mask[:,:-1];grown[:,:-1]|=mask[:,1:]
        mask=grown&full
        mask_path=f'registered/front_scoped_hidden_{name}.npy'; np.save(CASE/mask_path,mask,allow_pickle=False)
        scope[name]={'mask':mask_path,'sha256':digest(CASE/mask_path)}
        counts[name]={'full_solo_hidden':int(full.sum()),'idle_support':int(mask.sum())}
        request.update(hidden_pixel_count=int(mask.sum()),bounding_box=bbox(mask),exposure_status='sampled_cpu_texel_visibility_with_1px_raster_margin',motions=['idle'] if mask.any() else [])
        request.update(material_neighbours(mask,owners,names.index(name),names))
        for relation in ['occluding_parts','bordering_parts']:
            for item in request[relation]:item['material']=recipe['materials'][item['part']]
        im=request_image(Image.fromarray(paint),owners,names.index(name),mask)
        save_image(CASE/request['image'],im)
        save_image(CASE/request['image'].replace('.png','_4x.png'),im.resize((1020,1020),Image.Resampling.NEAREST))
        keep=[]
        for p in layout['parts']:
            if not p.get('hidden_material') or p['logical_part']!=name:
                keep.append(p);continue
            if not mask.any():
                (CASE/p['file']).unlink();continue
            pixels=np.zeros((255,255,4),np.uint8);pixels[mask]=[255,0,255,255]
            bounds=bbox(mask);save_image(CASE/p['file'],Image.fromarray(pixels).crop(bounds));p['offset']=bounds[:2];keep.append(p)
        layout['parts']=keep
        request['paint_nodes']=[p['name'] for p in keep if p.get('hidden_material') and p['logical_part']==name]
    layout['joint_meshes']=[m for m in layout.get('joint_meshes',[]) if not m['replaces_part'].startswith('hidden_')]
    # Hidden forearm support follows its own elbow bone; requests are below the
    # visible hand, and native proof remains mandatory for this tiny movement.
    recipe['hidden_motion_scope']={'front':scope}
    write_json(CASE/'recipes/rig.json',recipe);write_json(path,layout)
    # Keep the unskinned authoring layout consistent with the immutable requests.
    unskinned=read_json(CASE/'layouts/front.json');unskinned['parts']=layout['parts'];write_json(CASE/'layouts/front.json',unskinned)
    requests['exposure_basis']=str(len(rows))+' actual Godot rigid idle poses, CPU source-texel visibility, one native-pixel raster margin; not rendered proof'
    write_json(CASE/'hidden_requests/index.json',requests)
    write_json(CASE/'proof/hidden_scope.json',{'counts':counts,'samples_sha256':digest(CASE/'proof/motion_samples.json'),'chosen_defaults':PROOF_DEFAULTS})
    contact_sheet([(r['part']+' idle support='+str(r['hidden_pixel_count']),Image.open(CASE/r['image']).convert('RGBA')) for r in requests['requests']],CASE/'proof/idle_hidden_scope_sheet.png')
    rest_identity(CASE);baseline(CASE)
    print('EMAC HIDDEN SCOPE: PASS; '+str(counts))
if __name__=='__main__':main()
