"""Measured joint-border rebinds, using exact existing director underlay UVs."""
from collections import defaultdict
import argparse
from pathlib import Path
import numpy as np
from rr48_build import CASE,VIEWS
from rr48_feedback2_source import source_plan
from rr48_feedback3_cpu import model,box
from rr48_feedback3_policy import DirectorPolicy
from rr48_joint_budget import pose_layers
from cutout_pipeline.cases import read_json,write_json
from humanoid_cutout.canvas import for_case
from humanoid_cutout.cpu_pose import mesh_map,mapped
from humanoid_cutout.gates import matrix
from maquette_motion import pixels
from maquette_motion.silhouette import holes
from rr48_feedback3_source import support_paths
from rr48_feedback1 import inputs

def plan(findings=None):
 samples=read_json(CASE/'proof/feedback3_raster_samples.json');motion=read_json(CASE/'compiled_motion.json');found=defaultdict(set);observations=[];witnesses=defaultdict(list)
 selected=None if findings is None else {(r['view'],r['clip'],r['frame']) for r in read_json(findings)['remaining_tears']+read_json(findings)['accepted_short_tears']}
 with for_case(CASE):
  for view in VIEWS:
   m=model(CASE,view);policy=DirectorPolicy(m);base=source_plan(view,include_feedback3_caps=False)
   for row in samples['samples']:
    if row['view']!=view or (selected is not None and (view,row['clip'],row['frame']) not in selected):continue
    layers,_=pose_layers(m,row,motion);occupied=np.logical_or.reduce([im[...,3]>0 for _,im,_ in layers])
    masks=holes(occupied)
    for mask in masks:
     hits,traces=policy.painted(mask,row)
     if not hits.any():continue
     observations.append({'view':view,'clip':row['clip'],'frame':row['frame'],'bbox':box(mask),'pixels':int(mask.sum()),'painted_pixels':int(hits.sum()),'receivers':traces})
     for receiver,count in traces.items():
      if not count:continue
      part=policy.parts['hidden_'+receiver];a,b,r,d=part['bbox'];sy,sx=np.indices((d-b,r-a));ids=np.zeros((d-b,r-a,4),np.uint8);ids[...,0]=sx+a;ids[...,1]=sy+b;ids[...,3]=policy.underlay[b:d,a:r,3]
      if receiver in policy.references:
       mesh,_=policy.references[receiver];mapping=mesh_map(m.layout,row,mesh,native_skin=True,triangle_batch_size=m.triangle_batch_size);encoded=mapped(ids,mapping)
      else:encoded=pixels.render(ids,matrix(row['parts'][part['name']]['transform']))
      y,x=np.nonzero(mask&(encoded[...,3]>0))
      for u,v in np.unique(encoded[y,x,:2],axis=0):
       u,v=int(u),int(v)
       if base[part['name']]['image'][v,u,3]:continue
       found[view,receiver].add((u,v));witnesses[view,receiver].append({'uv':[u,v],'clip':row['clip'],'frame':row['frame']})
    if row['frame']==0:print('RR48 JOINT CAP PLAN',view,row['clip'],sum(map(len,found.values())),flush=True)
 path=CASE/'feedback3_joint_caps.json';caps=read_json(path)['caps'] if path.exists() else []
 for (view,receiver),uv in sorted(found.items()):
  old=next((r for r in caps if r['view']==view and r['receiver']==receiver),None)
  if old is None:old={'view':view,'receiver':receiver,'source':'exact director underlay at same coordinate','texels':[]};caps.append(old)
  old['texels']=[list(p) for p in sorted(set(map(tuple,old['texels']))|uv)]
  old['witnesses']=old.get('witnesses',[])+witnesses[view,receiver]
 for row in caps:
  base=source_plan(row['view'],include_feedback3_caps=False)['hidden_'+row['receiver']]['image'][...,3]>0
  row['support_texels']=[list(p) for p in sorted(support_paths(base,inputs(row['view'])[...,3]>0,row['texels']))]
 write_json(path,{'caps':caps,'rule':'Only measured missing receiver UVs, exact director underlay RGBA, registered as receiving-piece tucks and drawn below every visible piece. Spec section 1 requires at least 3 px; it does not cap tuck depth.','native_pixels':False})
 write_json(CASE/'proof/feedback3_cap_requests.json',{'observations':observations,'native_pixels':False})
 print('RR48 JOINT CAP PLAN:',sum(len(r['texels']) for r in caps),'measured source texels',flush=True)

if __name__=='__main__':
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--findings',type=Path);plan(p.parse_args().findings)
