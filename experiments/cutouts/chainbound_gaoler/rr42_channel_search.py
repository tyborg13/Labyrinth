"""Largest passing channel on a declared measurement grid; no common scales."""
import argparse
from rr42_underlay import CASE
from rr42_density import PROOF_CASE
from rr42_candidate import prepare,authored_motion,candidate_motion
from rr42_sweep import frames,sweep
from rr42_motion import FLOORS
from cutout_pipeline.cases import read_json,write_json,digest
from humanoid_cutout.gates import bindings

SEARCH_STEP=0.25  # Proof sampling resolution in the authored channel's units.
DEATH_WITNESSES=(0,32,33,34,35,36,39,40,50,95)


def geometric(rows):
    return [r for r in rows if set(r['kinds'])-{'procedural'}]


def search(clip,source,minimum,witnesses):
    minimum=max(minimum,FLOORS.get((clip,source),0))
    parent=bindings(PROOF_CASE)
    data=authored_motion(PROOF_CASE)
    track=next(t for t in data['view_tracks']['front'][clip] if t['source']==source)
    maximum=max(abs(k['value']) for k in track['keys']);rows=[]
    candidates=[maximum-SEARCH_STEP*i for i in range(round((maximum-minimum)/SEARCH_STEP)+1)]
    if candidates[-1]!=minimum:candidates.append(minimum)
    for peak in candidates:
        label=f'{clip}_{source.replace(".","_")}_{peak:.2f}'
        case=CASE/'proof/feedback1_limits'/label
        full_path=case/'proof/logs/rr42_sweep.json';sample_path=case/'proof/logs/samples.json'
        valid=sample_path.exists() and read_json(sample_path)['inputs']==bindings(case)
        if valid:valid=read_json(case/'compiled_motion.json')==candidate_motion(PROOF_CASE,clip,{source:peak})
        if valid:
            child=bindings(case)
            valid=all(child.get(path)==value for path,value in parent.items() if path!='compiled_motion.json' and not path.startswith('layouts/'))
            for view in ('front','rear'):
                actual=read_json(case/f'layouts/{view}.json');expected=read_json(PROOF_CASE/f'layouts/{view}.json')
                actual['motion_data']=expected['motion_data']
                valid=valid and actual==expected
        full=read_json(full_path) if valid and full_path.exists() else None
        if full is not None and (full.get('inputs')!=bindings(case) or full['samples_sha256']!=digest(sample_path)):
            full=None
        if full is None:
            cached=[]
            if valid:
                for view in ('front','rear'):
                    path=case/f'proof/logs/rr42_shards/{view}_{clip}_000.json'
                    if path.exists():cached+=read_json(path)['frames']
            needed={(v,f) for v in ('front','rear') for f in witnesses}
            if not geometric(cached) and not needed<={(r['view'],r['frame']) for r in cached}:
                case=prepare(label,clip,{source:peak},witnesses)
                for view in ('front','rear'):frames(case,view,clip,0,max(witnesses)+1,False)
                cached=[r for view in ('front','rear') for r in read_json(case/f'proof/logs/rr42_shards/{view}_{clip}_000.json')['frames']]
            bad=[{'view':r['view'],'frame':r['frame'],'kinds':r['kinds']} for r in geometric(cached)]
            entry={'peak':peak,'witness_errors':bad};rows.append(entry)
            print('RR42 CHANNEL SEARCH:',clip,source,peak,'witness errors',len(bad),flush=True)
            if bad:continue
            # A witness pass never substitutes for the full presented clip.
            prepare(label,clip,{source:peak})
            full=sweep(case,clip,True)
        else:
            entry={'peak':peak,'cached_full':True};rows.append(entry)
        failed=geometric(full['frames']);entry['full_errors']=len(full['errors'])
        entry['geometric_errors']=len(failed);entry['painted_exposure_clean']=full['ok']
        if not failed:
            result={'ok':True,'clip':clip,'source':source,'target_peak':maximum,'peak':peak,'step':SEARCH_STEP,
                    'minimum':minimum,'painted_exposure_clean':full['ok'],'candidates':rows,'native_pixels':False,'case':str(case)}
            write_json(CASE/f'proof/feedback1_{clip}_{source.replace(".","_")}_search.json',result)
            return result
        witnesses=sorted(set(witnesses)|{r['frame'] for r in failed})
        print('RR42 FULL-CLIP REJECTION:',peak,'additional witness frames',witnesses,flush=True)
    result={'ok':False,'clip':clip,'source':source,'step':SEARCH_STEP,'minimum':minimum,'candidates':rows,'native_pixels':False}
    write_json(CASE/f'proof/feedback1_{clip}_{source.replace(".","_")}_search.json',result)
    return result


if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--clip',default='death');p.add_argument('--source',default='coat_near_tip.lift_px');p.add_argument('--minimum',type=float,default=0)
    p.add_argument('--frames',default=','.join(map(str,DEATH_WITNESSES)))
    a=p.parse_args();result=search(a.clip,a.source,a.minimum,list(map(int,a.frames.split(','))))
    print('RR42 CHANNEL BUDGET:','PASS' if result['ok'] else 'FAIL',result.get('peak'))
    raise SystemExit(not result['ok'])
