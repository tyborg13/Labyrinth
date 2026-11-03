"""Bounded rr-38 target-to-rest search, preserving gait support/travel keys."""
from copy import deepcopy
from pathlib import Path
import subprocess
import sys
from rr48_build import CASE,ROOT,VIEWS
from cutout_pipeline.cases import read_json,write_json,digest
from rr48_joint_budget import measure,DEFAULTS,JOINTS

WORK=CASE/'proof/budget_candidates'
# The rr-38 search is uniform: clamping an arm alone can expose the body,
# and clamping the body alone changes both two-bone limb targets. A surviving
# profile must certify the complete assembly, including every limb and grip.
GROUPS={'all':set(JOINTS)}


def scaled(data,clip,factor,group='all'):
 result=deepcopy(data)
 for view,clips in result['view_tracks'].items():
  for track in clips[clip]:
   # A planted gait's world-step timing/endpoints are mandatory. Test only
   # optional excursion channels; never make a stance foot slide to hide a tear.
   if track['bone']=='root' or (clip=='death' and track['bone']=='falchion'):continue
   bone=track['bone']
   arm_bones=('upper_'+group[4:],'fore_'+group[4:],'hand_'+group[4:],'falchion' if group=='arm_far' else '')
   if group.startswith('arm_') and bone not in arm_bones:continue
   if group=='body' and bone not in ('torso','head','loincloth_mid','loincloth_tip','loincloth_back_mid','loincloth_back_tip'):continue
   if group=='legs' and bone!='pelvis' and not bone.startswith(('foot_','thigh_','shin_')):continue
   if clip=='move' and track['bone'].startswith('foot_') and track['channel']=='forward_px':continue
   for key in track['keys']:key['value']*=factor
 if clip=='move' and group not in ('legs','body'):
  arm=result['clips']['move']['gait']['arm_swing']
  for side in ('near','far'):
   if group!='all' and group!='arm_'+side:continue
   arm[side]['upper_deg']*=factor
   arm[side]['forearm_bend_deg']={k:v*factor for k,v in arm[side]['forearm_bend_deg'].items()}
 if clip=='move' and group in ('legs','all'):
  gait=result['clips']['move']['gait']
  for key in ('lift_px','lane_narrowing'):
   if key in gait:gait[key]*=factor
  gait['settle_px']={k:v*factor for k,v in gait['settle_px'].items()}
 return result


def candidate(data,clip,factor,frames=None,group='all'):
 folder=WORK/f'{clip}_{group}_{factor:.8f}';folder.mkdir(parents=True,exist_ok=True)
 for p in CASE.iterdir():
  if p.name in ('proof','compiled_motion.json'):continue
  target=folder/p.name
  if not target.exists():target.symlink_to(p,target_is_directory=p.is_dir())
 write_json(folder/'compiled_motion.json',scaled(data,clip,factor,group))
 row={'case':str(folder),'clip':clip,'output':str(folder/'samples.json')}
 if frames is not None:row['frames']=frames
 return row


def sample(rows,source):
 request=WORK/'request.json';write_json(request,{'candidates':rows,'screen_pixel_scale':source['screen_pixel_scale'],'step_distance_px':source['step_distance_px']})
 subprocess.run([sys.executable,'tools/godot_task_runner.py','--task-id','rr-48','--stream','--','godot','--headless','--path','.', '--script','tests/rr48/budget_samples.gd','--','--request',str(request)],cwd=ROOT,check=True)


def apply_recorded(data):
 path=CASE/('feedback3_joint_budgets.json' if (CASE/'feedback3_policy.json').exists() else 'feedback2_joint_budgets.json' if (CASE/'feedback2_supply.json').exists() else 'joint_budgets.json')
 if not path.exists():return data
 record=read_json(path)
 for profile in record['profiles']:
  if profile['status']=='measured_and_clamped':data=scaled(data,profile['clip'],profile['scale'],profile['group'])
 data['painted_budget_clamps']=record['clamps']
 return data


def live_action_errors(evidence,clip):
 # Preserve the existing production capture's six-changing-state contract.
 # A zero excursion is paint-safe but cannot replace a live authored action.
 errors=[]
 for view in VIEWS:
  rows=[r for r in evidence['samples'] if r['view']==view and r['clip']==clip]
  states={str(r['bones']) for r in rows}
  if len(states)<6:errors.append(view+'/'+clip+': fewer than six changing presented states ('+str(len(states))+')')
 return errors


def clamp_records(before,after,note):
 records=[]
 for view,clips in after['view_tracks'].items():
  for clip,tracks in clips.items():
   for old,new in zip(before['view_tracks'][view][clip],tracks):
    for a,b in zip(old['keys'],new['keys']):
     if a['value']!=b['value']:records.append({'view':view,'clip':clip,'source':old['source'],'at':a['at'],'target':a['value'],'clamped':b['value'],'budget_note':note})
 old=before['clips']['move']['gait']['arm_swing'];new=after['clips']['move']['gait']['arm_swing']
 for side in ('near','far'):
  for channel in ('upper_deg','forearm_bend_deg'):
   if old[side][channel]!=new[side][channel]:records.append({'clip':'move','source':'gait.arm_swing.'+side+'.'+channel,'target':old[side][channel],'clamped':new[side][channel],'budget_note':note})
 for key in ('lift_px','lane_narrowing','settle_px'):
  a=before['clips']['move']['gait'][key];b=after['clips']['move']['gait'][key]
  if a!=b:records.append({'clip':'move','source':'gait.'+key,'target':a,'clamped':b,'budget_note':note})
 return records

def search():
 data=read_json(CASE/'compiled_motion.json');source=read_json(CASE/'proof/feedback1_samples.json')
 initial=read_json(CASE/'proof/feedback1_joint_initial.json');reports=[];result=deepcopy(data);rejected=[]
 for clip in data['clips']:
  for group,selection in GROUPS.items():
   failures=[r for r in initial['errors'] if r['clip']==clip and r['joint'] in selection]
   if not failures:
    reports.append({'clip':clip,'group':group,'scale':1.,'status':'full_requested_excursion_verified','full_frame_checks':initial['frames']});continue
   witnesses=sorted({r['frame'] for r in failures[::max(1,len(failures)//6)]}|{0})
   # One engine batch retains complete clips. Witness rejections and the full
   # acceptance sweep then share the same hash-bound poses; no engine restart
   # for each survivor, and no witness-only candidate can earn a pass.
   candidates=[candidate(result,clip,n/DEFAULTS['search_denominator'],group=group) for n in range(DEFAULTS['search_denominator']-1,-1,-1)]
   sample(candidates,source);trials=[];accepted=None
   for n,row in zip(range(DEFAULTS['search_denominator']-1,-1,-1),candidates):
    evidence=read_json(Path(row['output']))
    if evidence['compiled_sha256']!=digest(Path(row['case'])/'compiled_motion.json'):raise ValueError('Stale budget candidate')
    factor=n/DEFAULTS['search_denominator'];r=measure(evidence,clips=[clip],witnesses=witnesses,selection=selection,stop_on_error=True,case=Path(row['case']))
    trials.append({'scale':factor,'witness_ok':r['ok'],'witness_findings':r['errors'][:2]})
    if not r['ok']:continue
    r=measure(evidence,clips=[clip],selection=selection,stop_on_error=True,case=Path(row['case']))
    trials[-1]['full_ok']=r['ok'];trials[-1]['full_findings']=r['errors'][:4]
    action_errors=live_action_errors(evidence,clip) if r['ok'] else []
    trials[-1]['admissibility_errors']=action_errors
    if r['ok'] and not action_errors:accepted=factor;result=scaled(result,clip,factor,group);break
   paint_only=[t for t in trials if t.get('full_ok') and t.get('admissibility_errors')]
   status='measured_and_clamped' if accepted is not None else ('no_admissible_scale_preserving_live_actions' if paint_only else 'no_admissible_scale_preserving_supports_and_drop')
   profile={'clip':clip,'group':group,'joints':sorted(selection),'scale':accepted if accepted is not None else 1.,'status':status,'trials':trials}
   if paint_only:
    profile['paint_only_scale']=paint_only[0]['scale']
    rejected+=clamp_records(data,scaled(data,clip,paint_only[0]['scale'],group),'Paint-only candidate REJECTED: '+str(paint_only[0]['admissibility_errors']))
   reports.append(profile)
   print('RR48 PAINTED BUDGET',clip,group,accepted if accepted is not None else 'UNRESOLVED',flush=True)
   write_json(CASE/'proof/feedback1_budget_search.json',{'profiles':reports,'native_pixels':False,'grid_denominator':DEFAULTS['search_denominator']})
 clamps=clamp_records(data,result,'Measured full-clip painted joint connectivity and live-action acceptance; rr-38 bounded search')
 statuses={p['clip']:p['status'] for p in reports}
 excursions={v:{c:{t['source']:{'target':[min(k['value'] for k in old['keys']),max(k['value'] for k in old['keys'])],'runtime_target':[min(k['value'] for k in t['keys']),max(k['value'] for k in t['keys'])],'budget':None if statuses[c].startswith('no_admissible') else [min(k['value'] for k in t['keys']),max(k['value'] for k in t['keys'])]} for old,t in zip(data['view_tracks'][v][c],tracks)} for c,tracks in clips.items()} for v,clips in result['view_tracks'].items()}
 write_json(CASE/'joint_budgets.json',{'profiles':reports,'clamps':clamps,'rejected_clamps':rejected,'view_channel_excursions':excursions,'gait':result['clips']['move']['gait'],'native_pixels':False,'source_compiled_sha256':digest(CASE/'compiled_motion.json'),'source_partition_sha256':digest(CASE/'source_partitions.json'),'layout_sha256':{v:digest(CASE/f'layouts/{v}.json') for v in VIEWS},'search_domain':'uniform requested target to rest, 1/60 grid; planted world-step tracks, released drop and six live-action states preserved; every limb/grip must pass','resolution':'Retain accepted director targets when no non-tearing profile preserves mandatory planted travel, released drop and live-action states; brief impossibility rule. Rejected paint-only profiles are never promoted.'})
 result['painted_budget_clamps']=clamps;write_json(CASE/'compiled_motion.json',result)
 return result

if __name__=='__main__':search()
