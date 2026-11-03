"""Bounded CPU diagnostic shards; no new budgets before native calibration.

Use --plan to list every shard, run those commands, then --merge. A shard
contains at most two frames. Every frame checks both skin families and UV
rounding through the inherited rr-42 painted-exposure gate.
"""
import argparse
from pathlib import Path
import numpy as np
from PIL import Image
from rr44_case import CASE, DEFAULTS
from rr44_exposure import gate, supplied, rear_strip_source
from rr42_raster import pose_for_raster
from rr44_diagnostics import Diagnostics
from rr44_flat import regions as flat_regions
from cutout_pipeline.cases import read_json, write_json, digest
from humanoid_cutout.cpu_pose import CpuPose
from humanoid_cutout.canvas import for_case
from humanoid_cutout.gates import bindings
from rr44_references import crop

SHARD_FRAMES = 2


def diagnostic_inputs():
    paths=list(CASE.parent.glob('rr44_*.py'))+list(CASE.parent.glob('rr49_*.py'))
    paths.append(CASE.parent/'rr44_feedback2_ownership.json')
    paths += [CASE.parent/n for n in ('rr42_exposure.py','rr42_raster.py','rr38_cpu_diagnostics.py','rr38_uncovered.py')]
    # rr-51: the director's 1.10 move acceptance, both files and the live scale.
    from rr51_acceptance import bound_inputs
    return {**{p.name:digest(p) for p in paths},**bound_inputs()}


def proof_inputs(case):
    # Rasterization reads the frozen proof case, not live production. Full
    # suites temporarily mutate production in finally-restored fixtures. Bind
    # those live files once at merge, against the original sample certificate,
    # while every shard still binds its complete source/runtime closure.
    return {k:v for k,v in bindings(case).items() if not k.startswith('production:')}


def coverage_errors(data, rows):
    expected={(v,c,f) for v in data['view_tracks'] for c,d in data['clips'].items()
              for f in range(round(d['seconds']*60))}
    actual=[(r['view'],r['clip'],r['frame']) for r in rows]
    errors=[]
    if len(actual)!=len(set(actual)):errors.append('Duplicate diagnostic frames')
    if set(actual)!=expected:errors.append('Diagnostic frame inventory differs from every declared view/clip/frame')
    return errors


def frames(case, view, clip, start, count):
    rows=[r for r in read_json(case/'proof/logs/samples.json')['samples'] if r['kind']=='presented' and r['view']==view and r['clip']==clip and start<=r['frame']<start+count]
    model=CpuPose(case,read_json(case/f'layouts/{view}.json'),native_skin=True,triangle_batch_size=128)
    diagnostic=Diagnostics(case,model);painted=gate(model);results=[]
    from rr49_checks import Checks
    native_equivalent=Checks(model,diagnostic.anatomy)
    with for_case(case):
        for original in rows:
            row=pose_for_raster(original); layers,maps=model.layers(row)
            result=diagnostic.measure(row,layers,maps)
            result['native_equivalent']=native_equivalent.measure(row,layers)
            if result['native_equivalent']['errors']:result['kinds'].append('native_equivalent')
            result['flat_regions']=flat_regions(diagnostic.surface,row,layers,maps,case/'proof/logs/rr44_flat')
            from rr51_acceptance import flat_errors
            result['flat_ratchet_errors']=flat_errors(result['flat_regions'])
            if result['flat_ratchet_errors']: result['kinds'].append('flat_region')
            provenance=painted.measure(original,collect_texels=True)
            result['metrics'].update(provenance)
            if any(provenance.values()):
                from rr51_acceptance import painted_excused
                if painted_excused(view,clip,row['frame'],provenance,painted.last_rows,painted.last_texels):
                    result['director_exception']='rr-51 painted texels accepted as found'
                else: result['kinds'].append('painted_exposure')
            # Keep all flagged part/footprint boxes for the director, including
            # the rear panel. Nothing is accepted from a global palette match.
            result['painted_regions']=painted.last_rows
            result['uncertified_source_texels']=[dict(part=n,uv=[x,y]) for n,x,y in sorted(painted.last_texels)]
            strip=rear_strip_source(); result['rear_striped_panel_texels']=[dict(part=n,uv=[x,y]) for n,x,y in painted.last_texels if view=='rear' and strip[y,x]]
            result.update(view=view,clip=clip,frame=row['frame'],native_pixels=False)
            result['kinds']=sorted(set(result['kinds']))
            if result['kinds']:
                path=case/f'proof/logs/rr44_crops/{view}_{clip}_{row["frame"]:03d}_cpu_4x.webp'
                crop(case,model.layout,row,path);result['crop']=str(path.relative_to(case))
            results.append(result)
    output=case/f'proof/logs/rr44_shards/{view}_{clip}_{start:03d}.json'
    write_json(output,dict(inputs=proof_inputs(case),diagnostic_inputs=diagnostic_inputs(),samples_sha256=digest(case/'proof/logs/samples.json'),frames=results,native_pixels=False))
    print(f'RR44 SWEEP SHARD: {view}/{clip}/{start} ({len(rows)} frames; {sum(bool(r["kinds"]) for r in results)} findings; native_pixels=False)')


def merge(case):
    data=read_json(case/'compiled_motion.json');results=[];inputs=bindings(case);sample_hash=digest(case/'proof/logs/samples.json')
    if read_json(case/'proof/logs/samples.json')['inputs']!=inputs:raise ValueError('Production/source/runtime changed since sampling')
    for view in data['view_tracks']:
        for clip,definition in data['clips'].items():
            count=round(definition['seconds']*60)
            for start in range(0,count,SHARD_FRAMES):
                shard=read_json(case/f'proof/logs/rr44_shards/{view}_{clip}_{start:03d}.json')
                if shard['inputs']!=proof_inputs(case) or shard['samples_sha256']!=sample_hash or shard['diagnostic_inputs']!=diagnostic_inputs(): raise ValueError('Stale diagnostic shard')
                results+=shard['frames']
    errors=[{k:r[k] for k in ('view','clip','frame','kinds','crop')} for r in results if r['kinds']]
    missing=coverage_errors(data,results)
    if missing:raise ValueError('; '.join(missing))
    from rr44_calibration import certificate
    calibration=certificate()
    from rr49_calibration import replay
    final_native=replay()
    result=dict(ok=not errors and calibration['ok'] and final_native['ok'],inputs=inputs,diagnostic_inputs=diagnostic_inputs(),samples_sha256=sample_hash,frames=results,errors=errors,native_pixels=False,
                native_calibrated=calibration['ok'],calibration=calibration,final_native_calibration=final_native)
    write_json(case/'proof/logs/rr44_sweep.json',result)
    write_json(CASE/'proof/sweep_summary.json',{k:v for k,v in result.items() if k!='frames'})
    print(f'RR44 CPU SWEEP: {"PASS" if result["ok"] else "FAIL"} ({len(results)} frames; {len(errors)} findings; native_calibrated={calibration["ok"]})')
    return result


if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--case',type=Path,default=CASE/'proof/production_case')
    p.add_argument('--plan',action='store_true');p.add_argument('--merge',action='store_true');p.add_argument('--view');p.add_argument('--clip');p.add_argument('--start',type=int);p.add_argument('--count',type=int,default=SHARD_FRAMES)
    a=p.parse_args()
    if a.plan:
        data=read_json(a.case/'compiled_motion.json')
        for view in data['view_tracks']:
            for clip,definition in data['clips'].items():
                for start in range(0,round(definition['seconds']*60),SHARD_FRAMES):
                    print(f'python3 -B {__file__} --case {a.case} --view {view} --clip {clip} --start {start} --count {SHARD_FRAMES}')
    elif a.merge: merge(a.case)
    else:
        if a.count>SHARD_FRAMES: p.error('Shard exceeds two-frame budget')
        frames(a.case,a.view,a.clip,a.start,a.count)
