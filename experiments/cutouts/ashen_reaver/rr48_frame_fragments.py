"""Exact source ownership of remaining posed fragments after the joint caps."""
from collections import defaultdict
import numpy as np
from rr48_build import CASE,VIEWS
from cutout_pipeline.cases import read_json,write_json
from humanoid_cutout.cpu_pose import CpuPose,mask_mesh
from humanoid_cutout.canvas import for_case
from humanoid_cutout.gates import matrix
from humanoid_cutout.held_release import ComponentPolicy
from rr48_joint_budget import pose_layers
from maquette_motion import pixels
from maquette_motion.features import source_pixels
from maquette_motion.silhouette import components,dilate

MAX_SLIVER_PIXELS=7  # Director's measured strips; larger visible paint is retained.

def plan():
 samples=read_json(CASE/'proof/feedback2_samples.json');motion=read_json(CASE/'compiled_motion.json');found=defaultdict(set);large=[]
 with for_case(CASE):
  for view in VIEWS:
   layout=read_json(CASE/f'layouts/{view}.json');model=CpuPose(CASE,layout,native_skin=True,triangle_batch_size=128);parts={p['name']:p for p in layout['parts']}
   for n,m in model.meshes.items():
    selected=mask_mesh(m,model.image(parts[n]['file'])[...,3]>0)
    if selected['triangles']:model.meshes[n]=selected
   policy=ComponentPolicy(read_json(CASE/'anatomy.json'),motion,layout,1)
   visible={p['name']:source_pixels(CASE,p) for p in layout['parts'] if not p.get('hidden_material')}
   rows=[r for r in samples['samples'] if r['view']==view and r['kind']=='presented']
   for index,row in enumerate(rows):
    layers,maps=pose_layers(model,row,motion);ordered=sorted(layers,key=lambda r:r[0]['z_index']);occupied=np.logical_or.reduce([im[...,3]>0 for _,im,_ in layers]);labels,groups=components(occupied,8)
    if len(groups)<2:continue
    released=policy.report(occupied,layers,row['clip'],row['phase'])['masks'];owner=np.zeros_like(labels)
    for i,(p,im,_) in enumerate(ordered):owner[im[...,3]>0]=i+1
    for label,count in groups[1:]:
     mask=labels==label
     if any(np.array_equal(mask,m) for m in released):continue
     for i,(p,im,_) in enumerate(ordered):
      component=mask&(owner==i+1)
      if not component.any():continue
      if count>MAX_SLIVER_PIXELS and not p.get('hidden_material'):
       large.append({'view':view,'clip':row['clip'],'frame':row['frame'],'piece':p['name'],'pixels':int(component.sum())});continue
      y,x=np.nonzero(component);source=model.image(p['file'])
      if p['name'] in maps:
       mapping=maps[p['name']];codes=y*pixels.PROOF_DEFAULTS['canvas_size']+x;selected=np.isin(mapping.pixels[:,1]*pixels.PROOF_DEFAULTS['canvas_size']+mapping.pixels[:,0],codes);uv=mapping.texels[selected]
       uv=uv[(uv[:,0]>=0)&(uv[:,1]>=0)&(uv[:,0]<source.shape[1])&(uv[:,1]<source.shape[0])];uv=uv[source[uv[:,1],uv[:,0],3]>0]+p['offset']
      else:
       ids=np.zeros_like(source);sy,sx=np.indices(source.shape[:2]);ids[...,0]=sx;ids[...,1]=sy;ids[...,3]=source[...,3]
       encoded=pixels.render(ids,matrix(row['parts'][p['name']]['transform']));uv=encoded[y,x,:2].astype(int)+p['offset']
      found[view,p['name']].update(map(tuple,uv.tolist()))
    if index%100==0:print('RR48 CAP FRAGMENT FRAME',view,row['clip'],row['frame'],flush=True)
 ledger=CASE/'feedback2_ownership.json';result=read_json(ledger)['fragments'] if ledger.exists() else []
 for (view,name),uv in found.items():
  layout=read_json(CASE/f'layouts/{view}.json');parts={p['name']:p for p in layout['parts']};image=source_pixels(CASE,parts[name]);visible={p['name']:source_pixels(CASE,p) for p in layout['parts'] if not p.get('hidden_material')}
  mask=np.zeros((255,255),bool)
  for x,y in uv:mask[y,x]=True
  labels,groups=components(mask,8)
  for label,count in groups:
   fragment=labels==label;rim=dilate(fragment,1)&~fragment
   direct={n:int((fragment&(im[...,3]>0)).sum()) for n,im in visible.items() if n!=name and (fragment&(im[...,3]>0)).any()};contacts=direct or {n:int((rim&(im[...,3]>0)).sum()) for n,im in visible.items() if n!=name and (rim&(im[...,3]>0)).any()}
   target=sorted(contacts,key=lambda n:(-contacts[n],n))[0] if contacts else None;y,x=np.nonzero(fragment)
   result.append({'view':view,'source':name,'target':target,'source_pixels':int(count),'texels':np.column_stack((x,y)).tolist(),'rgba':image[y,x].tolist(),'hidden':bool(parts[name].get('hidden_material')),'decision':'re-own' if target else 'clear','rule':'exact mapped posed component; actual rest cover/contact owner; otherwise clear'})
 write_json(ledger,{'fragments':result,'large_visible_findings':large,'native_pixels':False});print('RR48 CAP FRAGMENT PLAN:',sum(len(v) for v in found.values()),'new source texels;',len(large),'large visible findings',flush=True)
 return sum(len(v) for v in found.values())

if __name__=='__main__':plan()
