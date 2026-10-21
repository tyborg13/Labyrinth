"""Fit transparent rigid-quad storage against strict canonical source coverage.

Only invisible padding changes; source RGBA, anchors, joints and motion do not.
The actual captured source transforms drive every trial.
"""
from copy import deepcopy
import json
import numpy as np
from rr30_case import CASE
from rr30_cpu import CpuPose
from humanoid_cutout.bone_evidence import read_report
from humanoid_cutout.gates import matrix
from humanoid_cutout.rigid_air import RigidAirPolicy
from humanoid_cutout.anatomy import load
from maquette_motion.features import source_pixels
from maquette_motion import pixels
from cutout_pipeline.cases import read_json,write_json

PADDING_TRIALS_PX=(3,0,1,2,4,5,6,7,8,10,12,16,24,32,64,255)


def run():
    previous=read_json(CASE/'proof/logs/feedback3-joint-full-sweep.json')
    samples=read_report(CASE);out={};diagnostic={}
    for view in ('front','rear'):
        layout=read_json(CASE/f'layouts/{view}.json');model=CpuPose(CASE,layout)
        policy=RigidAirPolicy(CASE,layout,load(CASE));frames=[];affected={}
        for failure in previous[view]['failures']:
            pose=next(r for r in samples['samples'] if (r['view'],r['clip'],r['frame'],r['kind'])==(view,failure['clip'],failure['frame'],'presented'))
            layers,_=model.layers(pose);occupied=np.logical_or.reduce([im[...,3]>0 for _,im,_ in layers])
            owners=np.zeros(occupied.shape,dtype=int)
            transforms={n:p['transform'] for n,p in pose['parts'].items()}
            report=policy.report(occupied,owners,transforms)
            index=len(frames);frames.append(dict(pose=pose,layers=layers,transforms=transforms))
            for hole in report['failures']:
                for name,trace in hole['source'].items():
                    if trace['painted_or_tuck_pixels'] or trace['protected_silhouette_pixels']:
                        affected.setdefault(name,set()).add(index)
        out[view]={};diagnostic[view]={}
        sources={p['name']:source_pixels(CASE,p) for p in layout['parts']}
        for logical,indices in affected.items():
          for name in (logical,'hidden_'+logical):
            part=next(p for p in layout['parts'] if p['name']==name)
            original=deepcopy(part);source=sources[name]
            from PIL import Image
            box=Image.fromarray(source).getbbox();trials=[];best=None
            contexts=[]
            for i in sorted(indices):
                frame=frames[i];other=np.logical_or.reduce([im[...,3]>0 for p,im,_ in frame['layers'] if p['name']!=name])
                old=matrix(frame['transforms'][name]);old[:2,2]-=old[:2,:2]@original['offset']
                contexts.append((frame,other,old))
            for pad in PADDING_TRIALS_PX:
                bounds=[max(0,box[0]-pad),max(0,box[1]-pad),min(255,box[2]+pad),min(255,box[3]+pad)]
                part['offset']=bounds[:2];part['bbox']=bounds
                image=source[bounds[1]:bounds[3],bounds[0]:bounds[2]]
                count=points=0
                for frame,other,origin in contexts:
                    transform=origin.copy();transform[:2,2]+=transform[:2,:2]@part['offset']
                    rendered=pixels.render(image,transform)
                    transforms=dict(frame['transforms']);transforms[name]=[transform[0,0],transform[1,0],transform[0,1],transform[1,1],transform[0,2],transform[1,2]]
                    result=policy.report(other|(rendered[...,3]>0),np.zeros(other.shape,dtype=int),transforms)
                    bad=[r['source'][logical] for r in result['failures'] if logical in r['source'] and (r['source'][logical]['painted_or_tuck_pixels'] or r['source'][logical]['protected_silhouette_pixels'])]
                    count+=bool(bad);points+=sum(r['painted_or_tuck_pixels']+r['protected_silhouette_pixels'] for r in bad)
                trial=dict(padding_px=pad,bounds=bounds,failed_frames=count,blocked_points=points);trials.append(trial)
                if best is None or (count,points)<(best['failed_frames'],best['blocked_points']):best=trial
                if not count:break
            bounds=best['bounds'];part['offset']=bounds[:2];part['bbox']=bounds
            image=source[bounds[1]:bounds[3],bounds[0]:bounds[2]]
            for frame in frames:
                old=matrix(frame['transforms'][name]);old[:2,2]-=old[:2,:2]@original['offset']
                old[:2,2]+=old[:2,:2]@part['offset']
                frame['transforms'][name]=[old[0,0],old[1,0],old[0,1],old[1,1],old[0,2],old[1,2]]
                rendered=pixels.render(image,old)
                frame['layers']=[(p,rendered,checks) if p['name']==name else (p,im,checks) for p,im,checks in frame['layers']]
            out[view][name]=bounds;diagnostic[view][name]=dict(best=best,trials=trials)
            print('RR30 QUAD FIT:',view,name,best,flush=True)
            if not best['failed_frames']:break
    write_json(CASE.parent/'rr30_storage_bounds.json',out)
    write_json(CASE/'proof/joint_cleanup/quad_fit.json',diagnostic)
    return out


if __name__=='__main__':run()
