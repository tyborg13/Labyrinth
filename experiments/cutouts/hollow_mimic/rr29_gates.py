"""rr20 full gates + canonical tear, pendulum and per-frame front hand order."""
import argparse
import json
from pathlib import Path
import sys
import numpy as np
from rr29_build import ROOT,CASE,BASE,ASSETS,DIRECTOR,VIEWS,read_json,write_json,digest
from rr29_measure import arm_report,draw_report,depths
from humanoid_cutout.gates import structure_errors,source_errors,bone_errors,native_errors,bindings,clean_metrics
from humanoid_cutout.action_direction import report as directions
from humanoid_cutout.reach import report as reach
from humanoid_cutout.walk_gates import report as walk
from humanoid_cutout.gait_continuations import errors as continuation_errors
from humanoid_cutout.compiler import compile_motion
from humanoid_cutout.source_space import DetachedSource,pocket_report
from humanoid_cutout.silhouette_gates import posed_owners,joint_holes
from humanoid_cutout.anatomy import load
from maquette_motion.pixels import PROOF_DEFAULTS
from cpu_proof import CpuPose
from continuations import derivation_errors
from gates import supports,native_residue_errors
from residue import count as residue_count,feature_mask
from maquette_motion.features import source_pixels

PROOF = {'progress_frames':100}
DESIGN_FOLLOWUPS = {'TODO_DESIGN_mq11_rear_residue':
    'The approved mq11 rear contains two green residue texels in the rigid head. Exact rest identity preserves it; removing or recolouring it needs director data.'}


def headless(samples):
    data=read_json(CASE/'compiled_motion.json');build=read_json(CASE/'proof/build.json');bound=bindings(CASE)
    layouts={v:read_json(CASE/f'layouts/{v}.json') for v in VIEWS}
    errors=[];views={}
    for folder in (CASE,ASSETS):
        if (folder/'director_motion.json').read_bytes()!=DIRECTOR.read_bytes():errors.append('Director copy differs: '+str(folder))
    if compile_motion(DIRECTOR,'hollow_mimic',layouts,data['projection'])!=data:errors.append('Compiled motion differs')
    old=read_json(BASE/'compiled_motion.json')
    for v in VIEWS:
        for clip in data['clips']:
            if clip!='move' and data['view_tracks'][v][clip]!=old['view_tracks'][v][clip]:errors.append('Non-move motion changed: '+v+'/'+clip)
        l=layouts[v]
        source=structure_errors(l,build)+source_errors(CASE,l,build)+derivation_errors(l,case=CASE)+continuation_errors(CASE,l)
        for folder, painted in ((CASE,l),(ASSETS,read_json(ASSETS/(v+'.json')))):
            for part in painted['parts']:
                if residue_count(source_pixels(folder,part),feature_mask(CASE,l,part['logical_part'])):
                    source.append(f'{folder.name}/{v}/{part["name"]}: chroma-key residue')
        bones=bone_errors(l,data,samples,bound)
        direction=directions(l,data,samples,bound,require_presented=True)
        knee=walk(l,data,samples);support=supports(l,data,samples)
        target=reach(l,data,step_distance_px=samples['step_distance_px'],screen_pixel_scale=samples['screen_pixel_scale'])
        errors+=source+bones+direction['errors']+knee['errors']+support['errors']+target['errors']
        views[v]={'source_errors':source,'bone_errors':bones,'direction_errors':direction['errors'],
            'walk':knee,'supports':support,'reach':target}
    arms=arm_report(samples,read_json(CASE/'proof/before_samples.json'));draw=draw_report(samples,crops=True)
    errors+=arms['errors']+draw['errors']
    write_json(CASE/'proof/arm_measurements.json',arms)
    write_json(CASE/'proof/draw_order_findings.json',draw)
    return {'ok':not errors,'errors':sorted(set(errors)),'views':views,'pendulum':arms,'draw_order':draw,
        'native_pixels':False,'native_pending':'director real-renderer captures','design_followups':DESIGN_FOLLOWUPS}


def census(samples):
    before = bindings(CASE)
    if samples['inputs'] != before: raise ValueError('Refresh bound samples before canonical tear census')
    results={}
    for view in VIEWS:
        layout=read_json(CASE/f'layouts/{view}.json');model=CpuPose(CASE,layout);detached=DetachedSource(CASE,layout)
        records=[];failures=[];count=0;cache={}
        for pose in samples['samples']:
            if pose['view']!=view or pose['kind']!='presented':continue
            key=json.dumps([pose['clip'],pose['bones'],pose['parts']],sort_keys=True)
            if key in cache:
                row=dict(cache[key],clip=pose['clip'],frame=pose['frame'])
                records.append(row)
                if row['failures'] or row['unmatched_components'] or row['material_failures']: failures.append(row)
                count+=1
                continue
            layers,maps=model.layers(pose);expected=depths(layout,pose)
            layers=[(dict(part,z_index=expected[part['name']]),paint,check) for part,paint,check in layers]
            owners=posed_owners(layers,layout['parts'],pose['bones'],PROOF_DEFAULTS['source_offset'],load(CASE)['ownership'])
            seam=np.logical_or.reduce(model.masks(pose,layout['proof_joint_seams'],maps))
            refs=model.masks(pose,layout['proof_rest_holes'],maps)
            tears=joint_holes(owners>0,seam,owners,refs,pocket_details=True)
            space=pocket_report(layers,tears)
            rigid={n:p['transform'] for n,p in pose['parts'].items() if 'transform' in p}
            source=detached.report(layers,rigid);metrics=clean_metrics(layers)
            rejected={k:metrics[k] for k in ('outside_pixels','exposed_outline_pixels','dark_slab_blocks','outline_outside_pixels') if metrics[k]}
            row={'clip':pose['clip'],'frame':pose['frame'],**space,
                'unmatched_components':source['unmatched_components'],'material_failures':rejected}
            records.append(row)
            cache[key]=row
            if space['failures'] or source['unmatched_components'] or rejected:failures.append(row)
            count+=1
            if count%PROOF['progress_frames']==0:print(f'RR29 CPU {view}: {count} frames; {len(failures)} failing',flush=True)
        results[view]={'ok':not failures,'frames':count,'failures':failures,'records':records}
        print(f'RR29 CANONICAL TEAR {view.upper()}: {"PASS" if not failures else "FAIL"} ({count} frames; {len(failures)} failing)',flush=True)
    errors = [f'{view}/{row["clip"]}/{row["frame"]}: canonical tear/material/source failure'
              for view, result in results.items() for row in result['failures']]
    if before != bindings(CASE): errors.append('Inputs changed during canonical tear census')
    return {'ok':not errors,'errors':errors,'native_pixels':False,'no_exemptions':True,'views':results}


def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--native',type=Path);p.add_argument('--census',action='store_true');a=p.parse_args()
    samples=read_json(CASE/'proof/samples.json')
    if a.native:
        spaces=[];errors=native_errors(CASE,a.native,space_details=spaces)
        manifest=read_json(a.native/'frames.json');layouts={v:read_json(CASE/f'layouts/{v}.json') for v in VIEWS}
        errors+=native_residue_errors(a.native,manifest,layouts)
        # Native isolated-piece depths must agree with independent per-frame
        # geometry, rather than only compositing their own declared ordering.
        poses={(r['view'],r['clip'],r['frame']):r for r in samples['samples'] if r['kind']=='presented'}
        for row in manifest['pieces']:
            pose=poses[(row['view'],row['clip'],row['frame'])]
            if row['z_index']!=depths(layouts[row['view']],pose)[row['name']]:errors.append('Native depth differs: '+row['file'])
        result={'ok':not errors,'errors':errors,'native_pixels':True,'rest_space':spaces}
    elif a.census:result=census(samples)
    else:result=headless(samples)
    write_json(CASE/('proof/census.json' if a.census else 'proof/native_gates.json' if a.native else 'proof/gates.json'),result)
    print(f'RR29 {"NATIVE" if a.native else "CANONICAL TEAR" if a.census else "SOURCE/BONE/DIRECTION/KNEE/SUPPORT/REACH/ARM/DEPTH"} GATES: {"PASS" if result["ok"] else "FAIL"} ({len(result.get("errors",[]))} errors)',flush=True)
    for error in result.get('errors',[])[:30]:print(error)
    return int(not result['ok'])


if __name__=='__main__':raise SystemExit(main())
