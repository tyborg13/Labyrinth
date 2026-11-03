"""Per-joint-group rr-38 limits after the feedback-2 paint/ownership repair."""
import argparse
from copy import deepcopy
from pathlib import Path
from rr48_build import CASE,VIEWS
from rr48_budget_search import candidate,sample,scaled,clamp_records,live_action_errors,apply_recorded
from rr48_feedback2_source import ROUND1
from rr48_feedback1 import floor_contract
from rr48_joint_budget import measure,DEFAULTS
from cutout_pipeline.cases import read_json,write_json,digest
from humanoid_cutout.walk_gates import report as walk_report,support_report

GROUPS={'body':{'head_root','torso_root','cloth_front_root','cloth_back_root'},'arm_near':{'shoulder_near','wrist_near','internal_arm_near'},'arm_far':{'shoulder_far','wrist_far','internal_arm_far','grip'},'legs':{'hip_near','hip_far','ankle_near','ankle_far','internal_leg_near','internal_leg_far'}}

def targets():
 # Always start with accepted targets, even when the measured clamps are live.
 data=read_json(ROUND1/'compiled_motion.json');data.pop('painted_budget_clamps',None)
 for view in VIEWS:floor_contract(read_json(CASE/f'layouts/{view}.json'),data)
 path=CASE/'proof/feedback2_targets.json';write_json(path,data)
 initial=read_json(CASE/'proof/feedback2_joint_initial.json')
 if digest(path)!=initial['compiled_sha256'] or digest(CASE/'source_partitions.json')!=initial['source_partition_sha256'] or any(digest(CASE/f'layouts/{v}.json')!=initial['layout_sha256'][v] for v in VIEWS):raise ValueError('Stale initial joint-budget geometry or motion')
 return data

def admissible(case,motion,evidence,clip):
 errors=live_action_errors(evidence,clip)
 for view in VIEWS:
  layout=read_json(case/f'layouts/{view}.json')
  if clip=='move':errors+=walk_report(layout,motion,evidence)['errors']
  errors+=support_report(layout,motion,evidence)['errors']
 return errors


def search():
 data=targets();source=read_json(CASE/'proof/feedback2_samples.json');initial=read_json(CASE/'proof/feedback2_joint_initial.json');result=deepcopy(data);profiles=[]
 checkpoint=CASE/'proof/feedback2_budget_search.json'
 previous={(p['clip'],p['group']):p for p in read_json(checkpoint)['profiles']} if checkpoint.exists() else {}
 for clip in data['clips']:
  for group,selection in GROUPS.items():
   failures=[e for e in initial['errors'] if e['clip']==clip and e['joint'] in selection]
   if not failures:profiles.append({'clip':clip,'group':group,'scale':1.,'status':'full_requested_excursion_verified'});continue
   old=previous.get((clip,group))
   if old and old['status']=='measured_and_clamped':
    folder=CASE/f'proof/budget_candidates/{clip}_{group}_{old["scale"]:.8f}'
    expected=scaled(result,clip,old['scale'],group)
    if read_json(folder/'compiled_motion.json')==expected:
     evidence=read_json(folder/'samples.json')
     # Reuse only the hash-bound captured candidate, rechecking the newly
     # strengthened global detached-component guard before promotion.
     global_check=measure(evidence,clips=[clip],selection=set(),stop_on_error=True,case=folder)
     if global_check['ok']:
      result=expected;profiles.append(old);print('RR48 JOINT BUDGET REPLAY',clip,group,old['scale'],flush=True);continue
   witnesses=sorted({e['frame'] for e in failures[::max(1,len(failures)//6)]}|{0})
   candidates=[candidate(result,clip,n/DEFAULTS['search_denominator'],group=group) for n in range(DEFAULTS['search_denominator']-1,0,-1)];sample(candidates,source);trials=[];accepted=None
   for numerator,row in zip(range(DEFAULTS['search_denominator']-1,0,-1),candidates):
    case=Path(row['case']);evidence=read_json(Path(row['output']));motion=read_json(case/'compiled_motion.json')
    assert evidence['compiled_sha256']==digest(case/'compiled_motion.json')
    factor=numerator/DEFAULTS['search_denominator'];errors=admissible(case,motion,evidence,clip)
    trial={'scale':factor,'live_motion_errors':errors};trials.append(trial)
    if errors:continue
    r=measure(evidence,clips=[clip],witnesses=witnesses,selection=selection,stop_on_error=True,case=case)
    trial.update(witness_ok=r['ok'],witness_findings=r['errors'][:2])
    if not r['ok']:continue
    r=measure(evidence,clips=[clip],selection=selection,stop_on_error=True,case=case);trial.update(full_ok=r['ok'],full_findings=r['errors'][:4])
    if not r['ok']:
     # A newly discovered failing frame becomes an early-rejection witness
     # for every smaller profile. Acceptance still checks every frame.
     witnesses=sorted(set(witnesses)|{e['frame'] for e in r['errors']})
     continue
    accepted=factor;result=scaled(result,clip,factor,group);break
   profile={'clip':clip,'group':group,'joints':sorted(selection),'scale':accepted if accepted is not None else 1.,'status':'measured_and_clamped' if accepted is not None else 'approved_motion_retained_for_native_judgment','trials':trials}
   if accepted is None:profile['remaining_tears']=[{'view':e['view'],'frame':e['frame'],'joint':e['joint'],'pixels':e.get('source_space',e.get('component',{})).get('pixel_count',0),'kind':e['kind']} for e in failures]
   profiles.append(profile);write_json(CASE/'proof/feedback2_budget_search.json',{'profiles':profiles,'native_pixels':False});print('RR48 JOINT BUDGET',clip,group,accepted if accepted is not None else 'KEEP APPROVED / NATIVE JUDGMENT',flush=True)
 clamps=clamp_records(data,result,'Measured no-tear joint-group budget; full clip and live-action/walk/support checks; director feedback 2')
 record={'profiles':profiles,'clamps':clamps,'native_pixels':False,'source_compiled_sha256':digest(CASE/'proof/feedback2_targets.json'),'source_partition_sha256':digest(CASE/'source_partitions.json'),'layout_sha256':{v:digest(CASE/f'layouts/{v}.json') for v in VIEWS},'rule':'No zero profiles; unachievable joint budgets retain approved joint motion and exact tear lists for director native judgment','search_denominator':DEFAULTS['search_denominator']}
 write_json(CASE/'feedback2_joint_budgets.json',record);result['painted_budget_clamps']=clamps;write_json(CASE/'compiled_motion.json',result)
 print('RR48 JOINT BUDGET RECORD:',len(clamps),'key clamps;',sum(p['status']=='approved_motion_retained_for_native_judgment' for p in profiles),'retained joint profiles')

if __name__=='__main__':
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--verify-record',action='store_true');a=p.parse_args()
 if a.verify_record:
  if apply_recorded(targets())!=read_json(CASE/'compiled_motion.json'):raise ValueError('Recorded joint clamps do not reproduce live motion')
  count=len(read_json(CASE/'feedback2_joint_budgets.json')['clamps'])
  print(f'RR48 JOINT BUDGET REPLAY: PASS (accepted targets; exact initial geometry; {count} recorded clamps reproduce live motion)')
 else:search()
