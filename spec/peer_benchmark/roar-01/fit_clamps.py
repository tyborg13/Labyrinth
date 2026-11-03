#!/usr/bin/env python3
"""Evaluate explicit clamp candidates through the calibrated alpha-variant gate."""
import argparse
import hashlib
import json
from pathlib import Path
import numpy as np
from cpu_render import Renderer
from cpu_check import topology_counts
from seam_check import IDS, ALPHA_THRESHOLD, thin_gaps


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--poses',type=Path,required=True)
    parser.add_argument('--output',type=Path,required=True)
    parser.add_argument('--dragon',action='append',choices=IDS)
    parser.add_argument('--include-current',action='store_true')
    args=parser.parse_args()
    rows=json.loads(args.poses.read_text())['records'];result={}
    for dragon in args.dragon or IDS:
        renderer=Renderer(dragon);samples=[p for p in rows if p['dragon']==dragon]
        rest,_u,rest_parts=renderer.render(next(p for p in samples if p['clip']=='roar' and p['phase']==0 and 'case' not in p),True)
        rest_variants={k:v.copy() for k,v in renderer.part_variants.items()}
        baseline_counts=[];baseline_parts=[]
        for p in samples:
            if p['clip']=='roar':continue
            renderer.render(p,True)
            baseline_counts.append([len(thin_gaps(v>ALPHA_THRESHOLD,rest>ALPHA_THRESHOLD)) for v in renderer.variants])
            baseline_parts.append({k:v.copy() for k,v in renderer.part_variants.items()})
        budget=int(np.max(baseline_counts,axis=0).min());cache={}
        def part_counts(part,paint):
            key=(part,hashlib.sha256(paint.tobytes()).digest())
            if key not in cache:cache[key]=topology_counts(paint)
            return cache[key]
        limits={part:int(np.maximum.reduce([part_counts(part,rest_variants[part])]+[part_counts(part,p[part]) for p in baseline_parts]).min()) for part in rest_parts}
        cases={}
        if args.include_current:cases['current']=[dict(p,clamps={}) for p in samples if p['clip']=='roar' and 'case' not in p]
        for p in samples:
            if 'case' in p:cases.setdefault(p['case'],[]).append(p)
        observations=[];winner=None
        for name,poses in cases.items():
            failures=[]
            for pose in poses:
                if pose['phase'] in (0,1):continue
                renderer.render(pose,True)
                counts=[len(thin_gaps(v>ALPHA_THRESHOLD,rest>ALPHA_THRESHOLD)) for v in renderer.variants]
                if max(counts)>budget:
                    failures.append({'phase':pose['phase'],'counts':counts,'baseline':budget});break
                for part,paint in renderer.part_variants.items():
                    actual=part_counts(part,paint)
                    if actual.max()>limits[part]:failures.append({'phase':pose['phase'],'part':part,'counts':actual.tolist(),'baseline':limits[part]})
                if failures:break
            observations.append({'name':name,'clamps':poses[0]['clamps'],'failures':failures})
            print(dragon,name,'FAIL '+str(failures[:1]) if failures else 'PASS',flush=True)
            if not failures:winner=poses[0]['clamps'];break
        result[dragon]={'winner':winner,'observations':observations}
        args.output.write_text(json.dumps(result,indent=2)+'\n')
    return 0 if all(r['winner'] is not None for r in result.values()) else 1

if __name__=='__main__':raise SystemExit(main())
