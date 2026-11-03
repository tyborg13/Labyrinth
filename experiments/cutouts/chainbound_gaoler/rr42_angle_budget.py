"""Batch real Godot angle poses; cache only provably unchanged body layers."""
import argparse
from copy import deepcopy
from pathlib import Path
import subprocess
import sys
import numpy as np
from rr42_underlay import CASE,PROJECT
from rr42_density import PROOF_CASE
from rr42_candidate import prepare,authored_motion,candidate_motion
from rr42_sweep import sweep,Surfaces
from rr38_cpu_diagnostics import Diagnostics
from cutout_pipeline.cases import read_json,write_json,digest
from humanoid_cutout.cpu_pose import CpuPose,sprite_transform,mesh_map,mapped
from humanoid_cutout.gait_continuations import texture
from humanoid_cutout.canvas import for_case
from humanoid_cutout.gates import bindings
from maquette_motion import pixels

STEP=0.25
BATCH_TIMEOUT_SECONDS=300


def sample(clip,witnesses,source='chain.angle_deg'):
    root=CASE/'proof/angle_budget'/clip
    if source!='chain.angle_deg':root=root/source.replace('.','_')
    root.mkdir(parents=True,exist_ok=True)
    authored=authored_motion(PROOF_CASE)
    maximum=max(abs(k['value']) for t in authored['view_tracks']['front'][clip] if t['source']==source for k in t['keys'])
    original=candidate_motion(PROOF_CASE,clip,{source:maximum})
    candidates=[]
    for index in range(round(maximum/STEP)+1):
        peak=maximum-index*STEP;directory=root/f'{peak:.2f}';directory.mkdir(exist_ok=True)
        data=deepcopy(original)
        for view in data['view_tracks']:
            track=next(t for t in data['view_tracks'][view][clip] if t['source']==source)
            for key in track['keys']:key['value']*=peak/maximum
        motion=directory/'compiled_motion.json';output=directory/'poses.json'
        write_json(motion,data)
        candidates.append({'peak':peak,'motion':str(motion),'output':str(output)})
    request=root/'request.json';write_json(request,{'case':str(PROOF_CASE),'clip':clip,'frames':witnesses,'candidates':candidates})
    subprocess.run([sys.executable,'tools/godot_task_runner.py','--task-id','rr-42','--stream','--','godot','--headless','--path','.',
                    '--script','tests/rr42/angle_samples.gd','--','--request',str(request)],cwd=PROJECT,check=True,timeout=BATCH_TIMEOUT_SECONDS)
    return root,candidates


def search(clip,witnesses,source='chain.angle_deg'):
    before=bindings(PROOF_CASE);root,candidates=sample(clip,witnesses,source)
    models={v:CpuPose(PROOF_CASE,read_json(PROOF_CASE/f'layouts/{v}.json'),native_skin=True,triangle_batch_size=128) for v in ('front','rear')}
    diagnostics={v:Diagnostics(PROOF_CASE,m) for v,m in models.items()}
    for view,diag in diagnostics.items():diag.surface=Surfaces(PROOF_CASE,models[view])
    dynamic={'chain'} if source=='chain.angle_deg' else {'upper_far','fore_far','hand_far','chain'}
    cache={};results=[];full_witnesses=set(witnesses)
    with for_case(PROOF_CASE):
        for candidate in candidates:
            data=read_json(Path(candidate['output']));bad=[]
            if data['compiled_sha256']!=digest(Path(candidate['motion'])):raise ValueError('Stale angle matrix batch')
            for pose in data['samples']:
                view=pose['view'];model=models[view];key=(view,pose['frame'])
                stable={n:r for n,r in pose['bones'].items() if n not in dynamic}
                if key not in cache:
                    layers,maps=model.layers(pose)
                    fixed={n:m for n,m in maps.items() if n in model.meshes and not (set(model.meshes[n]['weights'])&dynamic)}
                    cache[key]=(stable,layers,fixed)
                previous,layers,maps=cache[key]
                if stable!=previous:raise ValueError('Angle changed another bone; cached rejection would be invalid')
                changed=[]
                maps=dict(maps)
                for part,image,checks in layers:
                    moving=part['bone'] in dynamic or (part['name'] in model.meshes and bool(set(model.meshes[part['name']]['weights'])&dynamic))
                    if moving:
                        art=texture(PROOF_CASE,model.layout,part,gait=False,clip=clip)
                        check=texture(PROOF_CASE,model.layout,part,gait=False,clip=clip,checks=True)
                        if part['name'] in model.meshes:
                            mapping=mesh_map(model.layout,pose,model.meshes[part['name']],native_skin=True,triangle_batch_size=128)
                            maps[part['name']]=mapping;image=mapped(art,mapping);checks=mapped(check,mapping)
                        else:
                            transform=sprite_transform(model.layout,pose,part)
                            image=pixels.render(art,transform);checks=pixels.render(check,transform)
                    changed.append((part,image,checks))
                result=diagnostics[view].measure(pose,changed,maps)
                kinds=result['kinds']+[k for k in ('uncovered_foreign_texels','uncovered_outline_pixels','uncovered_outside_surface_pixels') if result['metrics'].get(k)]
                if kinds:
                    bad=[{'view':view,'frame':pose['frame'],'kinds':kinds}];break
            row={'peak':candidate['peak'],'witness_errors':bad};results.append(row)
            if bad:
                if len(results)%20==0:print('RR42 ANGLE REJECTIONS:',clip,len(results),'latest peak',candidate['peak'],flush=True)
                continue
            peak=candidate['peak'];label=f'{clip}_{source.replace(".","_")}_{peak:.2f}'
            # Accept only an independent fresh standalone sampler/full sweep.
            case=prepare(label,clip,{source:peak})
            full=sweep(case,clip,True)
            failed=[r for r in full['frames'] if set(r['kinds'])-{'procedural'}]
            row['full_error_count']=len(full['errors']);row['geometric_error_count']=len(failed)
            if not failed:
                if bindings(PROOF_CASE)!=before:raise ValueError('Parent art changed during angle search')
                result={'ok':True,'clip':clip,'source':source,'target_peak':candidates[0]['peak'],'peak':peak,'step':STEP,
                        'painted_exposure_clean':full['ok'],'candidates':results,'parent_inputs':before,'native_pixels':False,
                        'oracle':'actual production sampler / Bone2D; other bones asserted byte-identical; full accepted clip independently resampled',
                        'case':str(case)}
                write_json(CASE/f'proof/feedback1_{clip}_{source.replace(".","_")}_search.json',result)
                print('RR42 ANGLE BUDGET: PASS',clip,peak,flush=True)
                return result
            # Add the newly found failing frame to the cheap exact rejection set.
            added={r['frame'] for r in failed}-full_witnesses
            if added:
                full_witnesses |= added
                _,additional=sample(clip,sorted(full_witnesses),source)
                candidates[:]=additional
                cache.clear()
            print('RR42 ANGLE FULL REJECTION:',clip,peak,len(failed),flush=True)
    raise ValueError('No angle channel budget at or above rest')


if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--clip',choices=('pin','reel'),required=True);p.add_argument('--frames',required=True);p.add_argument('--source',default='chain.angle_deg',choices=('chain.angle_deg','hand_far.forward_px'))
    a=p.parse_args();search(a.clip,list(map(int,a.frames.split(','))),a.source)
