"""Full-clip, per-view joint budgets; never certify from witness frames."""
from collections import Counter
from copy import deepcopy
from concurrent.futures import ProcessPoolExecutor
from pathlib import Path
import os,shutil,subprocess,sys
from rr52_build import ROOT,CASE
from rr52_joint_budget import measure
from rr52_checks import elbow_errors
from cutout_pipeline.cases import read_json,write_json,digest
from humanoid_cutout.gates import bindings
from humanoid_cutout.reach import report as reach_report
from humanoid_cutout.walk_gates import report as walk_report

RATIOS=(0.9,0.8,0.7,0.6)  # rr-48 feedback 3, section 5.
WORKERS=3  # Diagnostic resource bound, not motion tuning.


def group(joint,view=None,clip=None,data=None):
    for side in ('near','far'):
        if joint in ('shoulder_'+side,'wrist_'+side,'internal_arm_'+side):return 'arm_'+side
        if joint in ('ankle_'+side,'internal_leg_'+side):
            if data is not None and clip!='move':
                tracks=data['view_tracks'][view][clip]
                if not any(t['bone'] in {n+'_'+side for n in ('thigh','shin','foot')} for t in tracks) and any(t['bone']=='pelvis' for t in tracks):return 'pelvis'
            return 'leg_'+side
        if joint=='hip_'+side:return 'pelvis'
    return {'head_root':'head','torso_root':'torso','cloth_front_root':'robe','cloth_back_root':'robe_back','grip':'lantern'}.get(joint)


def scaled(data,view,clip,name,ratio):
    value=deepcopy(data)
    bones={name}
    if name.startswith('arm_'):bones={n+'_'+name[4:] for n in ('upper','fore','hand')}
    if name.startswith('leg_'):bones={n+'_'+name[4:] for n in ('thigh','shin','foot')}
    if name in ('robe','robe_back'):bones={name+'_mid',name+'_tip'}
    for t in value['view_tracks'][view][clip]:
        if t['bone'] not in bones or clip=='death' and t['bone']=='lantern':continue
        if clip=='move' and t['bone'].startswith('foot_') and t['channel']=='forward_px':continue
        for key in t['keys']:key['value']*=ratio
    return value


def records(before,after,note):
    rows=[]
    for view,clips in after['view_tracks'].items():
        for clip,tracks in clips.items():
            for a,b in zip(before['view_tracks'][view][clip],tracks):
                for x,y in zip(a['keys'],b['keys']):
                    if x['value']!=y['value']:rows.append({'view':view,'clip':clip,'source':a['source'],'at':x['at'],'target':x['value'],'clamped':y['value'],'budget_note':note})
    return rows


def candidate(spec):
    view,clip,name=spec;data=read_json(CASE/'compiled_motion.json');initial=read_json(CASE/'proof/cpu_sweep.json')
    baseline=[e for e in initial['errors'] if (e['view'],e['clip'])==(view,clip)]
    trials=[];selected=None
    if clip=='idle' or clip=='move' and name.startswith('arm_') or clip=='death' and name=='lantern':
        return {'view':view,'clip':clip,'group':name,'scale':1.0,'status':'approved_excursion_retained','reason':'Prescribed idle, full walk arm ratios and released-item floor path stay fixed','trials':[]}
    for ratio in RATIOS:
        value=scaled(data,view,clip,name,ratio)
        if not records(data,value,'probe'):
            return {'view':view,'clip':clip,'group':name,'scale':1.0,'status':'no_independent_target','trials':trials}
        folder=CASE/f'proof/joint_search/{view}_{clip}_{name}_{ratio}';folder.mkdir(parents=True,exist_ok=True)
        for p in CASE.iterdir():
            if p.name in ('proof','compiled_motion.json'):continue
            target=folder/p.name
            if p.is_dir():shutil.copytree(p,target,dirs_exist_ok=True)
            else:shutil.copyfile(p,target)
        write_json(folder/'compiled_motion.json',value);proof=folder/'proof';proof.mkdir(exist_ok=True);bound=bindings(folder)
        output=proof/'raster_samples.json';command=[sys.executable,'tools/godot_task_runner.py','--task-id','rr-52','--stream','--','godot','--headless','--path','.', '--script','experiments/cutouts/last_lamplighter/rr52/probes/raster_samples.gd','--','--case',str(folder),'--geometry',str(CASE/'proof/samples.json'),'--output',str(output),'--views',view,'--clips',clip]
        with (proof/'engine.log').open('w') as log:subprocess.run(command,cwd=ROOT,env=dict(os.environ,LABYRINTH_CEL_LOOK='off'),stdout=log,stderr=subprocess.STDOUT,check=True)
        samples=read_json(output)
        if samples['inputs']!=bound or bindings(folder)!=bound:raise ValueError('Joint candidate input mismatch')
        result=measure(samples,clips=[clip],views=[view],case=folder)
        if bindings(folder)!=bound:raise ValueError('Joint candidate inputs changed')
        errors=result['errors'];target=[e for e in errors if group(e['joint'],view,clip,data)==name]
        old_hard=Counter(e['kind'] for e in baseline if e['kind']!='joint_hole');hard=Counter(e['kind'] for e in errors if e['kind']!='joint_hole')
        states={str(r['bones']) for r in samples['samples']};live=len(states)>=6;elbows=elbow_errors(value,samples)
        geometry=read_json(CASE/'proof/samples.json');reach=reach_report(read_json(folder/f'layouts/{view}.json'),value,step_distance_px=geometry['step_distance_px'],screen_pixel_scale=geometry['screen_pixel_scale'])
        walk=walk_report(read_json(folder/f'layouts/{view}.json'),value,dict(geometry,samples=samples['samples'])) if clip=='move' else {'ok':True,'errors':[]}
        admissible=live and elbows['ok'] and reach['ok'] and walk['ok'] and all(hard[k]<=old_hard[k] for k in hard)
        trial={'scale':ratio,'frames':result['frames'],'target_findings':len(target),'total_findings':len(errors),'live_states':len(states),'elbows_ok':elbows['ok'],'reach_ok':reach['ok'],'walk_ok':walk['ok'],'admissible':admissible}
        trials.append(trial);write_json(proof/'measurement.json',dict(result,inputs=bound,trial=trial))
        print(f'RR52 JOINT TRIAL {view}/{clip}/{name} x{ratio}: {len(target)} target, {len(errors)} total, admissible={admissible}',flush=True)
        if admissible and (not target or ratio==RATIOS[-1]):
            selected=trial;break
    if selected:
        return {'view':view,'clip':clip,'group':name,'scale':selected['scale'],'status':'measured_safe' if not selected['target_findings'] else 'measured_floor_remaining','trials':trials}
    return {'view':view,'clip':clip,'group':name,'scale':1.0,'status':'approved_excursion_retained','reason':'No admissible full-clip budget at or above 60%; preserve live action/elbows/component contracts','trials':trials}


def apply_recorded(data):
    path=CASE/'measured_joint_budgets.json'
    if not path.exists():return data
    record=read_json(path)
    for row in record['profiles']:
        if row['status'].startswith('measured_'):data=scaled(data,row['view'],row['clip'],row['group'],row['scale'])
    data['painted_budget_clamps']=record['clamps']
    return data


def run():
    baseline=read_json(CASE/'proof/cpu_sweep.json');data=read_json(CASE/'compiled_motion.json')
    specs=sorted({(e['view'],e['clip'],group(e['joint'],e['view'],e['clip'],data)) for e in baseline['errors'] if group(e['joint'],e['view'],e['clip'],data)})
    with ProcessPoolExecutor(max_workers=WORKERS) as pool:profiles=list(pool.map(candidate,specs))
    result=deepcopy(data);clamps=[]
    for row in profiles:
        if row['status'].startswith('measured_'):
            after=scaled(result,row['view'],row['clip'],row['group'],row['scale']);clamps+=records(result,after,f"Complete native-origin clip joint budget {row['group']} x {row['scale']}; {row['status']}");result=after
    report={'profiles':profiles,'clamps':clamps,'source_sweep_sha256':digest(CASE/'proof/cpu_sweep.json'),'walk_arm_excursion_ratios':{'near':1.0,'far':1.0},'native_pixels':False,'defaults':{'ratios':RATIOS,'workers':WORKERS}}
    write_json(CASE/'measured_joint_budgets.json',report)
    print('RR52 PER-JOINT BUDGETS: %d profiles; %d key clamps; complete clips, no witness certification'%(len(profiles),len(clamps)))


def audit_walk():
    """Recheck stored complete candidates against the unchanged gait contract.

    View/side lift keys cannot be scaled while the shared protagonist lift
    curve stays fixed. Reject such candidates rather than changing that curve.
    """
    path=CASE/'measured_joint_budgets.json';report=read_json(path);data=read_json(CASE/'compiled_motion.json');geometry=read_json(CASE/'proof/samples.json');checks=0
    for row in report['profiles']:
        row['joints']=sorted({e['joint'] for e in read_json(CASE/'proof/cpu_sweep.json')['errors'] if (e['view'],e['clip'])==(row['view'],row['clip']) and group(e['joint'],row['view'],row['clip'],data)==row['group']})
        if row['clip']!='move' or not row['trials']:continue
        for trial in row['trials']:
            folder=CASE/f"proof/joint_search/{row['view']}_{row['clip']}_{row['group']}_{trial['scale']}";measurement=read_json(folder/'proof/measurement.json');poses=read_json(folder/'proof/raster_samples.json');value=read_json(folder/'compiled_motion.json')
            if measurement['inputs']!=bindings(folder) or poses['compiled_sha256']!=digest(folder/'compiled_motion.json'):raise ValueError('Stale full-clip walk candidate')
            walk=walk_report(read_json(folder/f"layouts/{row['view']}.json"),value,dict(geometry,samples=poses['samples']));checks+=1
            trial.update(walk_ok=walk['ok'],walk_errors=walk['errors'],admissible=trial['admissible'] and walk['ok'])
        selected=next((t for t in row['trials'] if t['admissible'] and (not t['target_findings'] or t['scale']==RATIOS[-1])),None)
        if selected:row.update(scale=selected['scale'],status='measured_safe' if not selected['target_findings'] else 'measured_floor_remaining')
        else:row.update(scale=1.0,status='approved_excursion_retained',reason='No measured budget preserves the existing protagonist lift curve, knees and supports')
    result=deepcopy(data);clamps=[]
    for row in report['profiles']:
        if row['status'].startswith('measured_'):
            after=scaled(result,row['view'],row['clip'],row['group'],row['scale']);clamps+=records(result,after,f"Complete native-origin clip joint budget {row['group']} x {row['scale']}; {row['status']}");result=after
    report.update(clamps=clamps,walk_admissibility_checks=checks);write_json(path,report)
    print(f'RR52 WALK BUDGET AUDIT: PASS ({checks} complete candidates; {len(clamps)} retained key clamps)')

if __name__=='__main__':
    if '--audit-walk' in sys.argv:audit_walk()
    else:run();audit_walk()
