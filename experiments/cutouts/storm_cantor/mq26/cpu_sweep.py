"""Painted excursion limits using the Gaoler's assembled-source-space oracle.

An isolated skin can split at a sampling boundary while approved foreground or
body paint still covers it. Only actual assembled holes / unmatched detached
paint constrain motion; individual-layer islands are not a no-tear budget.
No native renderer proof is inferred from this CPU diagnostic.
"""
import argparse
from pathlib import Path
import numpy as np
from PIL import Image
from build import CASE,VIEWS
from cutout_pipeline.cases import read_json,write_json,digest
from humanoid_cutout.anatomy import load
from humanoid_cutout.canvas import for_case
from humanoid_cutout.cpu_pose import CpuPose,mask_mesh
from humanoid_cutout.gates import matrix,bindings
from cloth_rags import RagComponentPolicy
from humanoid_cutout.source_space import DetachedSource,pocket_report
from humanoid_cutout.silhouette_gates import posed_owners,joint_holes
from maquette_motion import pixels
from maquette_motion.silhouette import components, holes
from surface_policy import SourcePolicy,box

DEFAULTS={'search_denominator':60,'serialized_tolerance_px':.001}
JOINTS={}
for side in ('near','far'):
 JOINTS.update({f'shoulder_{side}':f'upper_{side}',f'wrist_{side}':f'hand_{side}',f'hip_{side}':f'thigh_{side}',f'ankle_{side}':f'foot_{side}',f'internal_arm_{side}':f'fore_{side}',f'internal_leg_{side}':f'shin_{side}'})
JOINTS.update(grip='staff',head_root='head',torso_root='torso',cloth_front_root='tabard_mid',cloth_back_root='cloak_mid')


def nearest_joint(row,box):
 low=np.asarray(box[:2]);high=np.asarray(box[2:]);offset=pixels.PROOF_DEFAULTS['source_offset']
 def distance(item):
  point=np.asarray(row['bones'][item[1]]['global'][4:])+offset
  return float(np.sum((point-np.clip(point,low,high))**2))
 return min(JOINTS.items(),key=distance)[0]


def component_joint(logical,row,box):
 if logical.startswith('hand_'):return 'wrist_'+logical[5:]
 if logical.startswith('foot_'):return 'ankle_'+logical[5:]
 if logical.startswith(('leg_','arm_')):return 'internal_'+logical
 if logical=='staff':return 'grip'
 if logical=='head':return 'head_root'
 if logical in ('torso','pelvis'):return 'torso_root'
 if logical in ('tabard','cloak'):return 'cloth_back_root' if logical.endswith('_back') else 'cloth_front_root'
 return nearest_joint(row,box)


def pose_layers(model,row,motion):
 layers,maps=model.layers(row)
 # A constrained item uses the real captured Sprite2D transform. Its painted
 # grip is snapped once with the fist; its floor pose bypasses anchor snapping.
 layers=[(p,pixels.render(model.image(p['file']),matrix(row['parts'][p['name']]['transform'])),pixels.render(model.image(model.layout['proof_layers'][p['name']]['mask']),matrix(row['parts'][p['name']]['transform']))) if p['name'] not in model.meshes else (p,im,check) for p,im,check in layers]
 return layers,maps


def measure(samples, *, clips=None, views=VIEWS, witnesses=None, selection=None, stop_on_error=False, case=CASE):
 motion=read_json(case/'compiled_motion.json');anatomy=load(case);errors=[];frames=0;surfaces=0;air=0;diagnostics=[];cleared=[]
 with for_case(case):
  for view in views:
   layout=read_json(case/f'layouts/{view}.json');model=CpuPose(case,layout,native_skin=True,triangle_batch_size=128)
   # Exact conservative source-alpha pruning, preserving all potentially painted
   # triangles and their original order; no approximation of a moving surface.
   for name,mesh in model.meshes.items():
    selected=mask_mesh(mesh,model.image(next(p['file'] for p in layout['parts'] if p['name']==name))[...,3]>0)
    if selected['triangles']:model.meshes[name]=selected
   policy=SourcePolicy(model)
   rest=np.asarray(Image.open(case/layout['rest_source']).convert('RGBA'))
   release=RagComponentPolicy(case,anatomy,motion,layout,len(components(rest[...,3]>0,8)[1]));detached=DetachedSource(case,layout)
   logical_by_id=['']+[p['logical_part'] for p in layout['parts']]
   part_ids={p['name']:i+1 for i,p in enumerate(layout['parts'])}
   for row in samples['samples']:
    if row['view']!=view or row['kind']!='presented' or (clips and row['clip'] not in clips):continue
    if witnesses is not None and row['frame'] not in witnesses:continue
    layers,maps=pose_layers(model,row,motion)
    occupied=np.logical_or.reduce([im[...,3]>0 for _,im,_ in layers])
    seams=model.masks(row,layout.get('proof_joint_seams',[]),maps)
    references=model.masks(row,layout.get('proof_rest_holes',[]),maps)
    seam=np.logical_or.reduce(seams) if seams else np.zeros_like(occupied)
    owners=posed_owners(layers,layout['parts'],row['bones'],pixels.PROOF_DEFAULTS['source_offset'],anatomy['ownership'])
    tears=joint_holes(occupied,seam,owners,references,pocket_details=True)
    space=policy.space(occupied,row,tears);air+=len(space['air_pockets'])
    metric=policy.metrics(layers,row,maps)
    diagnostics.append({'view':view,'clip':row['clip'],'frame':row['frame'],'holes':[{'bbox':box(mask),'pixel_count':int(mask.sum())} for mask in holes(occupied)],'metrics':metric,'outline':[r for r in policy.outline_records if r['clip']==row['clip'] and r['frame']==row['frame']]})
    released=release.report(occupied,layers,row['clip'],row['phase'],pose=row,cpu_model=model)
    cleared.extend(dict(view=view,clip=row['clip'],frame=row['frame'],**r) for r in released['director_cloth_components'])
    transforms={name:record['transform'] for name,record in row['parts'].items()}
    source=detached.report(layers,transforms,released['masks'])
    records=[{'joint':'assembly','kind':'paint_metric','metric':key,'count':metric[key]} for key in ('outside_pixels','exposed_outline_pixels','dark_slab_blocks','outline_outside_pixels') if metric[key]]
    for finding in space['failures']:
     records.append({'joint':nearest_joint(row,finding['bbox']),'kind':'joint_hole','source_space':finding})
    owner=np.zeros_like(occupied,dtype=np.uint16)
    for part,im,_ in sorted(layers,key=lambda r:r[0]['z_index']):owner[im[...,3]>0]=part_ids[part['name']]
    for finding in source['unmatched_components']:
     points=np.asarray(finding['pixels']);counts=np.bincount(owner[points[:,1],points[:,0]])
     logical=logical_by_id[int(counts.argmax())]
     records.append({'joint':component_joint(logical,row,finding['bbox']),'kind':'unmatched_detached_paint','logical_part':logical,'component':finding})
    for message in released['errors']:records.append({'joint':'assembly' if message.startswith('floating pieces:') else 'grip','kind':'held_release','message':message})
    for record in records:
     if selection is None or record['joint'] in selection or record['kind'] in ('unmatched_detached_paint','held_release'):errors.append({'view':view,'clip':row['clip'],'frame':row['frame'],'phase':row['phase'],**record})
    frames+=1;surfaces+=len(seams)
    if errors and stop_on_error:return {'ok':False,'errors':errors,'frames':frames,'native_pixels':False}
    if frames%120==0:print('RR56 ASSEMBLED JOINT FRAME',view,row['clip'],row['frame'],'findings',len(errors),flush=True)
 return {'ok':not errors,'errors':errors,'director_cloth_cleared':cleared,'frames':frames,'joint_checks':surfaces,'transported_seam_surfaces':surfaces,'authorized_air_pockets':air,'native_pixels':False,'diagnostics':diagnostics,'method':'Exact approved source/underlay air + Gaoler assembled source-space joint_holes + pocket_report + DetachedSource + declared held-release policy, on actual engine Bone2D poses; no isolated-piece component heuristic','defaults':DEFAULTS}


def clip_job(arguments):
 case,samples,clip=arguments
 return measure(samples,clips=[clip],case=case)

if __name__=='__main__':
 from concurrent.futures import ProcessPoolExecutor
 p=argparse.ArgumentParser();p.add_argument('--case',type=Path,default=CASE);p.add_argument('--samples',type=Path,default=CASE/'proof/raster_samples.json');p.add_argument('--clips');p.add_argument('--output',type=Path,default=CASE/'proof/cpu_sweep.json');p.add_argument('--workers',type=int,default=4);a=p.parse_args()
 samples=read_json(a.samples);bound=bindings(a.case)
 if samples['compiled_sha256']!=digest(a.case/'compiled_motion.json') or samples.get('inputs')!=bound:raise ValueError('Stale CPU input bindings')
 clips=a.clips.split(',') if a.clips else list(read_json(a.case/'compiled_motion.json')['clips'])
 with ProcessPoolExecutor(max_workers=a.workers) as pool:results=list(pool.map(clip_job,[(a.case,samples,c) for c in clips]))
 result=dict(results[0])
 for key in ('errors','diagnostics','director_cloth_cleared'):result[key]=[row for r in results for row in r[key]]
 for key in ('frames','joint_checks','transported_seam_surfaces','authorized_air_pockets'):result[key]=sum(r[key] for r in results)
 result.update(ok=all(r['ok'] for r in results),inputs=bound,samples_sha256=digest(a.samples),workers=a.workers)
 if bindings(a.case)!=bound:raise ValueError('CPU inputs changed during measurement')
 write_json(a.output,result)
 print('RR56 CPU SWEEP: %s (%d frames; %d transported seams; %d findings)'%('PASS' if result['ok'] else 'FINDINGS',result['frames'],result['joint_checks'],len(result['errors'])))
 raise SystemExit(0 if result['ok'] else 1)
