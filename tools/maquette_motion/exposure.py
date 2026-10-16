"""Measure hidden underlay exposure from actual sampled Bone2D transforms."""
import argparse
from pathlib import Path
import numpy as np
from PIL import Image
from cutout_pipeline.cases import read_json, write_json, digest
from maquette_motion.gates import unpack
CANVAS_SIZE = 512
POSE_OFFSET = 128

def transformed_mask(case, part, layout, row):
    transform=unpack(row['bones'][part['bone']]['global'])
    basis=transform[:2,:2]
    pivot=np.asarray(layout['joints'][part['bone']]['position'])
    origin=transform[:2,2]+basis@(np.asarray(part['offset'])-pivot)+POSE_OFFSET
    inverse=np.linalg.inv(basis);translation=-inverse@origin
    affine=(*inverse[0],translation[0],*inverse[1],translation[1])
    image=Image.open(case/part['file']).getchannel('A')
    return np.asarray(image.transform((CANVAS_SIZE,CANVAS_SIZE),Image.Transform.AFFINE,affine,Image.Resampling.NEAREST))>128

def measure(case, samples):
    rows=read_json(samples)['samples'];index=read_json(case/'hidden_requests/index.json')
    lookup={(r['view'],r['part']):r for r in index['requests']}
    peaks={}
    for view in ('front','rear'):
        layout=read_json(case/f'layouts/{view}.json')
        # CanvasItem tie order follows Skeleton2D child traversal (not file order).
        children={None:[]}
        for bone,item in layout['joints'].items():children.setdefault(item['parent'],[]).append(bone)
        order=[]
        def visit(bone):
            for child in children.get(bone,[]):visit(child)
            order.extend(p['name'] for p in layout['parts'] if p['bone']==bone)
        for bone in children[None]:visit(bone)
        parts=sorted(layout['parts'],key=lambda p:(p['z_index'],order.index(p['name'])))
        for row in (r for r in rows if r['view']==view):
            visible=np.full((CANVAS_SIZE,CANVAS_SIZE),-1,dtype=np.int16)
            for i,part in enumerate(parts):visible[transformed_mask(case,part,layout,row)]=i
            for i,part in enumerate(parts):
                if not part.get('hidden_material'):continue
                key=(view,part['logical_part'],row['clip'])
                count=int((visible==i).sum())
                previous=peaks.setdefault(key,{'clip':row['clip'],'max_exposed_pixels':0,'peak_phase':0})
                if count>previous['max_exposed_pixels']:previous.update(max_exposed_pixels=count,peak_phase=row['phase'])
    for (view,part),request in lookup.items():
        request['clip_exposure']=[value for (v,p,c),value in peaks.items() if v==view and p==part]
        request['max_exposed_pixels']=max((v['max_exposed_pixels'] for v in request['clip_exposure']),default=0)
        request['exposure_status']='sampled_cpu_visibility'
        request['motions']=[v for v in request['clip_exposure'] if v['max_exposed_pixels']]
    index['exposure_basis']='Actual authored keys and midpoints, both Skeleton2D views; CPU nearest masks, not native renderer proof.'
    index['samples_sha256']=digest(samples)
    write_json(case/'hidden_requests/index.json',index)
    print(f'MAQUETTE EXPOSURE: PASS ({len(lookup)} measured requests)')

def main():
    p=argparse.ArgumentParser();p.add_argument('--case',type=Path,required=True);p.add_argument('--samples',type=Path,required=True);a=p.parse_args();measure(a.case,a.samples)
if __name__=='__main__':main()
