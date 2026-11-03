"""Retain existing continuations while repairing a newly found clip gap."""
import argparse
from rr37_case import CASE
from rr37_continuations import defects, extend, MAX_CONSTRUCTION_PASSES, CLIPS
from rr37_raster import CpuPose
from humanoid_cutout.canvas import for_case
from cutout_pipeline.cases import read_json, write_json


def repair(samples, view, clip):
    layout=read_json(CASE/f'layouts/{view}.json')
    poses=[p for p in samples['samples'] if p['view']==view and p['clip']==clip and p['kind']=='presented']
    if not poses:raise ValueError('Missing presented clip poses')
    with for_case(CASE):
        model=CpuPose(CASE,layout)
        for iteration in range(MAX_CONSTRUCTION_PASSES):
            count=0
            for pose in poses:
                masks,owners,maps=defects(model,pose)
                for mask in masks:
                    extend(model,pose,mask,owners,maps);count+=1
            print(f'RR37 {view.upper()} {clip.upper()} REPAIR: pass {iteration+1}, {count} gaps',flush=True)
            if not count:break
        else:raise ValueError('Clip coverage did not converge')
    for part in layout['parts']:part.pop('proof_ownership',None)
    write_json(CASE/f'layouts/{view}.json',layout)
    field='gait_continuations' if clip=='move' else 'clip_continuations'
    write_json(CASE/(field+'.json'),{v:read_json(CASE/f'layouts/{v}.json').get(field,{}) for v in ('front','rear')})
    from rr37_proof_case import build
    from rr37_density import seal
    build();seal()


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--view',choices=('front','rear'),required=True)
    parser.add_argument('--clip',choices=tuple(CLIPS),required=True)
    args=parser.parse_args()
    repair(read_json(CASE/'proof/logs/production_runtime_samples.json'),args.view,args.clip)
