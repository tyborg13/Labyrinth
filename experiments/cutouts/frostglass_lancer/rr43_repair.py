"""Close rr-43's measured rear joint pockets with existing own-edge recipes.

Consumes strict all-frame failures, never edits paint, motion or gate masks.
The existing continuation builder enforces shaft and cloak source domains.
"""
from rr37_case import CASE
from rr37_continuations import defects, extend, MAX_CONSTRUCTION_PASSES
from rr37_raster import CpuPose
from cutout_pipeline.cases import read_json, write_json
from humanoid_cutout.canvas import for_case

PROGRESS_FRAMES = 64  # Diagnostic logging only.

def repair(view='rear', all_frames=False):
    failures = [] if all_frames else read_json(CASE/f'proof/logs/rr43_{view}_frames.json')[view]['failures']
    keys = {(row['clip'],row['frame']) for row in failures}
    samples = read_json(CASE/'proof/logs/production_runtime_samples.json')['samples']
    poses = [row for row in samples if row['view']==view and row['kind']=='presented' and
        (all_frames or (row['clip'],row['frame']) in keys)]
    if not all_frames and len(poses)!=len(keys): raise ValueError('Missing current failure poses')
    layout = read_json(CASE/f'layouts/{view}.json')
    with for_case(CASE):
        model = CpuPose(CASE,layout)
        for iteration in range(MAX_CONSTRUCTION_PASSES):
            count = 0
            for index,pose in enumerate(poses):
                masks,owners,maps = defects(model,pose)
                for mask in masks:
                    extend(model,pose,mask,owners,maps)
                    count += 1
                if (index+1)%PROGRESS_FRAMES==0:
                    print(f'RR43 {view.upper()} REPAIR PROGRESS: {index+1}/{len(poses)}; {count} gaps',flush=True)
            print(f'RR43 {view.upper()} JOINT REPAIR: pass {iteration+1}, {count} gaps',flush=True)
            if not count: break
        else: raise ValueError('Rear joint repair did not converge')
    for part in layout['parts']: part.pop('proof_ownership',None)
    write_json(CASE/f'layouts/{view}.json',layout)
    for field in ('clip_continuations','gait_continuations'):
        rows = read_json(CASE/(field+'.json'))
        rows[view] = layout.get(field,{})
        write_json(CASE/(field+'.json'),rows)


if __name__=='__main__':
    import argparse
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--view',choices=('front','rear'),default='rear')
    parser.add_argument('--all-frames',action='store_true')
    args=parser.parse_args()
    repair(args.view,args.all_frames)
