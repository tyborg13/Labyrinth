"""Bounded CPU construction shards, never native-renderer acceptance."""
import argparse
from pathlib import Path
import numpy as np
from PIL import Image
from rr38_case import CASE
from rr38_uncovered import UncoveredSurface, flat_regions, arm_budget_gate
from cutout_pipeline.cases import read_json, write_json, digest
from humanoid_cutout.cpu_pose import CpuPose
from humanoid_cutout.canvas import for_case
from humanoid_cutout.native_defects import measure

SHARD_FRAMES = 4  # Folded terminal knees cost more; keep each shard below 90s.
TRIANGLE_BATCH_SIZE = 128  # Diagnostic memory bound; all triangles are retained.


def run(case, view, clip, start, count, output, only_frames=None):
    samples=read_json(case/'proof/logs/samples.json')
    rows=[r for r in samples['samples'] if r['view']==view and r['clip']==clip and r['kind']=='presented' and start<=r['frame']<start+count]
    if only_frames is not None:rows=[r for r in rows if (view,clip,r['frame']) in only_frames]
    model=CpuPose(case,read_json(case/f'layouts/{view}.json'),triangle_batch_size=TRIANGLE_BATCH_SIZE,native_skin=True)
    gate=UncoveredSurface(case,model)
    budget_gate=arm_budget_gate(case,model,'near' if clip=='press' else 'far') if clip in ('press','death') else None
    contract=read_json(case/'material_contract.json')['views'][view]
    from rr38_cpu_diagnostics import Diagnostics
    diagnostic=Diagnostics(case,model)
    results=[];errors=[];flags=[]
    with for_case(case):
        for row in rows:
            layers,maps=model.layers(row)
            calibrated=diagnostic.measure(row,layers,maps)
            metrics=calibrated['metrics']
            arm_budget=budget_gate.measure(row,layers,maps) if budget_gate else {}
            from rr38_acceptance import rear_cowl_errors
            errors.extend(rear_cowl_errors(model.layout,layers,row))
            defects=measure(layers,contract)
            clean=calibrated['clean']
            tears=calibrated['joint_tears']
            composite=np.zeros_like(layers[0][1])
            for _,image,_ in sorted(layers,key=lambda r:r[0]['z_index']):composite[image[...,3]>0]=image[image[...,3]>0]
            output.mkdir(parents=True,exist_ok=True)
            Image.fromarray(composite).save(output/f'pose_{row["frame"]:04d}.png')
            flat=flat_regions(gate,row,layers,output/'flat')
            flags.extend(flat)
            results.append(dict(calibrated,frame=row['frame'],phase=row['phase'],arm_budget_metrics=arm_budget,defects=defects,flat_regions=flat))
            errors.extend(f'{view}/{clip}/{row["frame"]}: arm budget {k}={v}' for k,v in arm_budget.items() if v)
            errors.extend(f'{view}/{clip}/{row["frame"]}: {k}={v}' for k,v in {**metrics,**defects}.items() if v)
            errors.extend(f'{view}/{clip}/{row["frame"]}: {k}={clean[k]}' for k in ('outside_pixels','exposed_outline_pixels','dark_slab_blocks','outline_outside_pixels') if clean[k])
            if tears:errors.append(f'{view}/{clip}/{row["frame"]}: joint tears={len(tears)}')
            errors.extend(f'{view}/{clip}/{row["frame"]}: calibrated {kind}' for kind in calibrated['kinds'])
    if not rows:errors.append('Missing shard poses')
    result={'ok':not errors,'native_pixels':False,'view':view,'clip':clip,'start':start,'count':len(rows),
        'full_samples_sha256':digest(case/'proof/logs/samples.json'),'errors':errors,'flat_regions':flags,'frames':results}
    write_json(output/'report.json',result)
    print(f'RR38 {view.upper()} {clip.upper()} CPU FRAMES {start}:{start+len(rows)}: {"FAIL" if errors else "PASS"} ({len(errors)} findings; {len(flags)} flat regions; native=False)')
    return result


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--case',type=Path,default=CASE)
    parser.add_argument('--view',choices=('front','rear'),required=True)
    parser.add_argument('--clip',required=True)
    parser.add_argument('--start',type=int,default=0)
    parser.add_argument('--count',type=int,default=SHARD_FRAMES)
    parser.add_argument('--output',type=Path)
    parser.add_argument('--only-frames',type=Path)
    args=parser.parse_args()
    if not 1<=args.count<=SHARD_FRAMES:parser.error(f'Use separate shards of at most {SHARD_FRAMES} frames')
    output=args.output or args.case/f'proof/cpu_frames/{args.view}_{args.clip}_{args.start:04d}'
    selected={tuple(r[:3]) for r in read_json(args.only_frames)['signatures']} if args.only_frames else None
    raise SystemExit(not run(args.case,args.view,args.clip,args.start,args.count,output,selected)['ok'])
