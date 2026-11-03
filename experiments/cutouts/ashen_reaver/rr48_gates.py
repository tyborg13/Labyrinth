"""Independent all-clip contracts. Missing director paint is never counted as a pass."""
import argparse
import math
from collections import Counter
from pathlib import Path
import numpy as np
from PIL import Image
from rr48_build import ROOT,CASE,ASSETS,VIEWS
from cutout_pipeline.cases import read_json,write_json,digest
from humanoid_cutout.gates import matrix,bindings,native_errors
from humanoid_cutout.action_direction import report as direction_report
from humanoid_cutout.reach import report as reach_report
from humanoid_cutout.walk_gates import report as walk_report,support_report
from humanoid_cutout.canvas import for_case
from humanoid_cutout.cpu_pose import CpuPose
from maquette_motion.features import source_pixels
from maquette_motion import pixels

# Serialized transforms and whole-pixel nearest rounding, respectively.
DEFAULTS={'authored_tolerance_px':0.001,'presented_tolerance_px':1.415,'mask_value':255}

def elbow_errors(data,samples):
 errors=[];max_hyper=0.;checks=0
 for row in samples['samples']:
  forward=np.asarray(data['projection'][row['view']]['forward'])
  for side in data['elbow_policy']['sides']:
   a,b,c=[np.asarray(row['bones'][n+'_'+side]['global'][4:]) for n in ('upper','fore','hand')]
   u,v=b-a,c-b
   cross=lambda x,y:x[0]*y[1]-x[1]*y[0]
   bend=math.degrees(math.atan2(cross(u,v),u@v))*np.sign(cross(u,forward))
   hyper=max(0.,-bend);max_hyper=max(max_hyper,hyper);checks+=1
   if hyper>data['elbow_policy']['max_hyperextension_deg']+1e-4:errors.append(f'{row["view"]}/{row["clip"]}/{row["phase"]}/{side}: hyperextension {hyper:.6f}')
 return {'ok':not errors,'errors':errors,'checks':checks,'max_hyperextension_deg':max_hyper}

def idle_errors(layout,samples):
 errors=[];checks=0
 for row in samples['samples']:
  if row['view']!=layout['facing'] or row['clip']!='idle' or row['kind']!='presented':continue
  for group,parts in layout['idle_groups'].items():
   offsets=[]
   for part in layout['parts']:
    if part['name'] not in parts:continue
    names=next((list(m['weights']) for m in layout['joint_meshes'] if m['name']==part['name']),[part['bone']])
    for name in names:
     bone=matrix(row['bones'][name]['global']);offset=bone[:2,2]-layout['joints'][name]['position'];offsets.append(offset);checks+=1
     if not np.allclose(bone[:2,:2],np.eye(2),atol=1e-5):errors.append('idle rotation/scale/deformation: '+name)
     if not np.allclose(offset,np.round(offset),atol=1e-4):errors.append('idle fractional offset: '+name)
   if not all(np.allclose(offsets[0],o,atol=1e-4) for o in offsets):errors.append('idle group split: '+group)
   if group=='lower_body' and any(np.linalg.norm(o)>1e-4 for o in offsets):errors.append('idle lower body moved')
 return {'ok':not errors,'errors':sorted(set(errors)),'checks':checks,'pixel_mismatch_by_rigid_translation':0 if not errors else None}

def held_errors(layout,data,samples):
 errors=[];checks=0;maximum=0.;floor=layout['held_items']['falchion']['floor_line_y']
 grip=np.asarray(layout['held_items']['falchion']['source_grip']);item=np.asarray(layout['joints']['falchion']['position']);hand=np.asarray(layout['joints']['hand_far']['position'])
 end=np.asarray(layout['held_items']['falchion']['floor_end'])
 for row in samples['samples']:
  if row['view']!=layout['facing']:continue
  bone=matrix(row['bones']['falchion']['global']);checks+=1
  if not np.allclose(bone[:2,:2].T@bone[:2,:2],np.eye(2),atol=1e-4):errors.append('falchion lost rigidity')
  if row['clip']!='death' and abs(math.degrees(math.atan2(bone[1,0],bone[0,0])))>35.0001:errors.append('falchion exceeds binding 35 degree budget')
  tolerance=DEFAULTS['authored_tolerance_px'] if row['kind']=='authored' else DEFAULTS['presented_tolerance_px']
  if row['clip']!='death' or row['phase']<data['clips']['death']['release_at']['falchion']:
   glove=matrix(row['bones']['hand_far']['global']);error=float(np.linalg.norm((bone@np.r_[grip-item,1])-(glove@np.r_[grip-hand,1])))
   maximum=max(maximum,error)
   if error>tolerance:errors.append(f'{row["view"]}/{row["clip"]}/{row["phase"]}: grip gap {error:.6f}')
  elif row['phase']>=data['view_held_drops'][row['view']]['death']['falchion']['land']:
   contact=bone@np.r_[end-item,1]
   if abs(contact[1]-floor)>tolerance:errors.append(f'{row["view"]}/death/{row["phase"]}: floor contact {contact[1]-floor:.6f}')
 return {'ok':not errors,'errors':errors,'checks':checks,'max_grip_error_px':maximum}

def floor_geometry(layout,samples):
 if layout['held_items']['falchion'].get('painted_floor'):
  from rr48_feedback_gates import floor_errors
  result=floor_errors(CASE,samples)
  return {'ok':result['ok'],'status':layout['held_items']['falchion']['painted_floor']['status'],'errors':result['errors'],'checks':result['checks'],'final_angle_deg':result['final_angle_deg'].get(layout['facing'])}
 part=next(p for p in layout['parts'] if p['name']=='falchion')
 image=np.asarray(Image.open(CASE/part['file']).convert('RGBA'));y,x=np.nonzero(image[...,3])
 bind=np.asarray(layout['joints']['falchion']['position'])
 points=np.column_stack((x+part['offset'][0]+.5,y+part['offset'][1]+.5))-bind
 rows=[];floor=layout['held_items']['falchion']['floor_line_y']
 for row in samples['samples']:
  if row['view']!=layout['facing'] or row['clip']!='death' or row['phase']<.45:continue
  bone=matrix(row['bones']['falchion']['global'])
  height=points[:,0]*bone[1,0]+points[:,1]*bone[1,1]+bone[1,2]
  if height.max()>floor+0.7072:rows.append({'kind':row['kind'],'phase':row['phase'],'below_floor_px':float(height.max()-floor)})
 return {'ok':not rows,'status':'TODO_DESIGN_falchion_death_floor_pose' if rows else 'PASS','penetration':rows,'terminal_target_retained':True}

def footprint_requests(samples):
 """Transport each complete moving footprint, and each actually vacated rest area.

 Masks are source-space requests, never colour donors. The director decides the
 receiving surface/air inside a request before supplying an underlay.
 """
 target=CASE.parent/'underlay_requests';target.mkdir(exist_ok=True)
 records=[]
 movers=['arm_near','arm_far','hand_near','hand_far','falchion','loincloth','loincloth_back']
 notes={'arm_near':'torso flank/belly beneath the near arm; proximal arm cap',
 'arm_far':'torso flank and far thigh beneath the sword arm; proximal arm cap',
 'hand_near':'front loincloth and thighs beneath the near gauntlet; sleeve cuff',
 'hand_far':'far thigh/flank beneath the sword gauntlet; sleeve cuff',
 'falchion':'far thigh/flank and floor/air revealed by the single rigid falchion',
 'loincloth':'pelvis and thighs beneath the front loincloth',
 'loincloth_back':'pelvis and thighs beneath the back loincloth'}
 with for_case(CASE):
  for view in VIEWS:
   layout=read_json(CASE/f'layouts/{view}.json');model=CpuPose(CASE,layout)
   parts={p['name']:p for p in layout['parts']}
   footprints={n:np.zeros((255,255),bool) for n in movers};vacated={n:np.zeros((255,255),bool) for n in movers}
   rest={n:source_pixels(CASE,parts[n]) for n in movers}
   count=0
   for row in samples['samples']:
    if row['view']!=view or row['kind']!='presented':continue
    layers,_=model.layers(row);posed={p['name']:im[...,3]>0 for p,im,_ in layers};occupied=np.logical_or.reduce(list(posed.values()));count+=1
    for name in movers:
     recipient='pelvis' if name.startswith('loincloth') else 'torso'
     bind=np.asarray(layout['joints'][recipient]['position']);bone=matrix(row['bones'][recipient]['global']);reference=bone.copy();reference[:2,2]-=bone[:2,:2]@bind
     # The same reference transports the opaque rest footprint beneath the moving piece.
     prior=pixels.render(rest[name],reference)[...,3]>0
     for source,mask in [(footprints[name],posed[name]),(vacated[name],prior&~occupied)]:
      y,x=np.nonzero(mask)
      if not len(x):continue
      points=np.column_stack((x+.5-pixels.PROOF_DEFAULTS['source_offset'],y+.5-pixels.PROOF_DEFAULTS['source_offset'],np.ones(len(x))))
      inverse=np.linalg.inv(reference)
      uv=np.floor(points[:,0,None]*inverse[:2,0]+points[:,1,None]*inverse[:2,1]+inverse[:2,2]).astype(int)
      uv=uv[(uv[:,0]>=0)&(uv[:,0]<255)&(uv[:,1]>=0)&(uv[:,1]<255)]
      source[uv[:,1],uv[:,0]]=True
   for name in movers:
    mask=vacated[name];request=f'{view}_{name}.png';full=f'{view}_{name}_full_footprint.png'
    Image.fromarray(mask.astype('uint8')*255).save(target/request);Image.fromarray(footprints[name].astype('uint8')*255).save(target/full)
    records.append({'view':view,'region':name,'mask':request,'full_motion_footprint':full,'source_size':[255,255],'sampled_frames':count,'uncovered_pixels':int(mask.sum()),'footprint_pixels':int(footprints[name].sum()),'painting_must_continue':notes[name], 'status':f'TODO_DESIGN_underlay_{view}_{name}' if mask.any() else 'no uncovered pixels observed'})
 write_json(target/'index.json',{'native_pixels':False,'scope':'every presented frame of every clip in both views; source painting coordinates, no synthetic fills','regions':records})
 placeholders={r['status']:r['painting_must_continue'] for r in records if r['status'].startswith('TODO_DESIGN')}
 path=CASE/'inputs.json';inputs=read_json(path);inputs['design_placeholders'].update(placeholders);write_json(path,inputs)
 print(f'RR48 UNDERLAY REQUESTS: {len(placeholders)} TODO_DESIGN regions; all 14 motion footprints exported; no paint synthesized')
 return records

def run(samples_path,native=None):
 samples=read_json(samples_path);data=read_json(CASE/'compiled_motion.json');report={'native_pixels':False,'elbows':elbow_errors(data,samples),'held':{},'walk':{},'supports':{},'direction':{},'reach':{},'idle':{},'paint_requirements':{},'floor_geometry':{}}
 for view in VIEWS:
  layout=read_json(CASE/f'layouts/{view}.json')
  report['floor_geometry'][view]=floor_geometry(layout,samples)
  report['idle'][view]=idle_errors(layout,samples)
  from humanoid_cutout.gates import source_errors,structure_errors
  paint_errors=source_errors(CASE,layout,read_json(CASE/'proof/build.json'))+structure_errors(layout,read_json(CASE/'proof/build.json'))
  status=('FINDINGS' if paint_errors else 'PASS') if (CASE/'source_partitions.json').exists() else 'TODO_DESIGN_underlays'
  report['paint_requirements'][view]={'status':status,'errors':paint_errors}
  report['held'][view]=held_errors(layout,data,samples)
  report['walk'][view]=walk_report(layout,data,samples)
  report['supports'][view]=support_report(layout,data,samples)
  report['direction'][view]=direction_report(layout,data,samples,bindings(CASE),require_presented=True)
  report['reach'][view]=reach_report(layout,data,step_distance_px=samples['step_distance_px'],screen_pixel_scale=samples['screen_pixel_scale'])
 report['budget_clamps']=data.get('budget_clamps',[])
 if (CASE/'source_partitions.json').exists():
  from rr48_feedback_gates import underlay_errors,floor_errors,follow_errors
  report['director_underlay']={'source':underlay_errors(),'production':underlay_errors(ASSETS/'humanoid_v2',True),'coverage_record':'proof/underlay_coverage.json','coverage_gated':False}
  report['painted_floor']=floor_errors(CASE,samples)
  report['body_follow']=follow_errors(samples)
  report['painted_budget_clamps']=data.get('painted_budget_clamps',[])
  if (CASE/'feedback2_supply.json').exists():
   from rr48_supply_gates import grip_errors
   report['painted_grip']=grip_errors(CASE,samples)
   feedback3=(CASE/'feedback3_policy.json').exists()
   path=CASE/('proof/feedback3_sweep.json' if feedback3 else 'proof/feedback2_joint_measurement.json')
   joint=read_json(path) if path.exists() else {}
   fresh=joint.get('inputs')==bindings(CASE) and joint.get('samples_sha256')==digest(samples_path)
   if feedback3:
    from rr48_feedback3_contract import walk_arm_errors
    from rr48_feedback3_sweep import diagnostic_inputs
    fresh &= joint.get('diagnostic_inputs')==diagnostic_inputs()
    calibration=read_json(CASE/'proof/feedback3_calibration.json')
    calibrated=calibration['ok'] and not calibration['missing'] and joint.get('calibration_sha256')==digest(CASE/'proof/feedback3_calibration.json')
    fresh &= calibrated
    report['native_calibration']={'ok':calibrated,'errors':[] if calibrated else ['Missing/stale CPU superset of native findings']}
    report['walk_approved_arms']={'errors':walk_arm_errors(data),'ok':not walk_arm_errors(data)}
    kinds=dict(Counter(k for e in joint.get('errors',[]) for k in e['kinds']));kinds['joint_hole']=len(joint.get('remaining_tears',[]))
    count=len(joint.get('frames',[]))
   else:kinds=dict(Counter(e['kind'] for e in joint.get('errors',[])));count=joint.get('frames',0)
   report['assembled_joints']={'ok':fresh and joint.get('ok',False),'fresh':fresh,'frames':count,'findings_by_kind':kinds,'record':str(path.relative_to(CASE)),'native_pixels':False}
  budget_path=CASE/('feedback3_joint_budgets.json' if (CASE/'feedback3_policy.json').exists() else 'feedback2_joint_budgets.json' if (CASE/'feedback2_supply.json').exists() else 'joint_budgets.json')
  budgets=read_json(budget_path) if budget_path.exists() else {'profiles':[]}
  unresolved=[p for p in budgets['profiles'] if p['status'].startswith('no_admissible')]
  report['painted_joint_budget']={'ok':budget_path.exists() and not unresolved,'measured':budget_path.exists(),'unresolved_profiles':[{k:p[k] for k in ('clip','group','status')} for p in unresolved],
   'rejected_clamps':len(budgets.get('rejected_clamps',[])),'record':'joint_budgets.json','native_pixels':False}
  report['painted_joint_budget']['record']=budget_path.name
  report['painted_joint_budget']['retained_for_native']=[{k:p[k] for k in ('clip','group','status')} for p in budgets['profiles'] if p['status']=='approved_motion_retained_for_native_judgment']
  report['painted_joint_budget']['policy_ok']=report['painted_joint_budget']['ok']
  if (CASE/'feedback3_policy.json').exists():report['painted_joint_budget']['ok'] &= budgets.get('status')=='measured_full_requested'
  # Retaining a live action is authorized, but its remaining tears still need
  # the director's native judgment; they must not become a no-tear gate pass.
  report['painted_joint_budget']['ok'] &= not report['painted_joint_budget']['retained_for_native']
 report['dynamic_budget_clamps']=[]
 for row in samples['samples']:
  budget=row.get('held_follow_budget',{})
  if budget and budget['target_deg']!=budget['clamped_deg']:
   report['dynamic_budget_clamps'].append({'view':row['view'],'clip':row['clip'],'phase':row['phase'],'kind':row['kind'],**budget})
 report['TODO_DESIGN']=read_json(CASE/'inputs.json')['design_placeholders']
 report['native_status']='pending director'
 if native:
  with for_case(CASE):report['native_errors']=native_errors(CASE,Path(native))
 errors=report['elbows']['errors']
 for group in ('held','walk','supports','direction','reach','idle'):
  for v,r in report[group].items():
   print(f'RR48 {group.upper()} {v}: {"PASS" if r["ok"] else "FAIL"} ({len(r["errors"])} errors)')
   errors=errors+r['errors']
 for name in ('painted_floor','body_follow','painted_grip','walk_approved_arms','native_calibration'):
  if name in report:errors+=report[name]['errors']
 if 'director_underlay' in report:
  for name in ('source','production'):errors+=report['director_underlay'][name]['errors']
 report['motion_ok']=not errors
 report['art_ok']=not any(r['errors'] for r in report['paint_requirements'].values())
 report['design_resolved']=not report['TODO_DESIGN'] and all(r['status']=='PASS' for r in report['floor_geometry'].values())
 report['ok']=not errors and report['art_ok'] and report['design_resolved'] and report.get('painted_joint_budget',{}).get('ok',True) and report.get('assembled_joints',{}).get('ok',True);report['errors']=errors
 write_json(CASE/'proof/gates.json',report)
 print(f'RR48 ELBOW GATE: {"PASS" if report["elbows"]["ok"] else "FAIL"} ({report["elbows"]["checks"]} checks; maximum hyperextension {report["elbows"]["max_hyperextension_deg"]:.6f} deg)')
 print(f'RR48 ART GATE: {"PASS" if report["art_ok"] else "FINDINGS"} (strict tuck/cap source; transparent underlay is background)')
 if 'painted_joint_budget' in report:print(f'RR48 PAINTED BUDGET GATE: {"PASS" if report["painted_joint_budget"]["ok"] else "FINDINGS"} ({len(report["painted_joint_budget"]["unresolved_profiles"])} unresolved profiles; {len(report["painted_joint_budget"]["retained_for_native"])} retained for native judgment)')
 if 'assembled_joints' in report:print(f'RR48 ASSEMBLED GATE: {"PASS" if report["assembled_joints"]["ok"] else "FINDINGS"} ({report["assembled_joints"]["frames"]} frames; fresh={report["assembled_joints"]["fresh"]}; {report["assembled_joints"]["findings_by_kind"]})')
 print(f'RR48 OVERALL GATE: {"PASS" if report["ok"] else "FINDINGS"}')
 for e in errors[:20]:print(e)
 return report['ok']

if __name__=='__main__':
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--samples',type=Path,default=CASE/'proof/samples.json');p.add_argument('--requests',action='store_true');p.add_argument('--native',type=Path);args=p.parse_args()
 if args.requests:footprint_requests(read_json(args.samples))
 else:raise SystemExit(0 if run(args.samples,args.native) else 1)
