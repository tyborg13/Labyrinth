"""rr-42 rest-contact ownership of the measured one-pixel source slivers."""
from collections import defaultdict
import numpy as np
from rr48_build import CASE,VIEWS
from rr48_feedback2_source import ROUND1,snapshot
from cutout_pipeline.cases import read_json,write_json
from humanoid_cutout.cpu_pose import CpuPose,mesh_map,mask_mesh
from humanoid_cutout.gates import matrix
from humanoid_cutout.canvas import for_case
from maquette_motion.features import source_pixels
from maquette_motion.silhouette import components,dilate
from maquette_motion import pixels

MAX_SLIVER_PIXELS=7  # Director feedback 2: the measured 1 px, 5-7 px strips.

def plan():
 snapshot();measurement=read_json(ROUND1/'proof/feedback1_joint_measurement.json');samples=read_json(ROUND1/'proof/feedback1_samples.json');gather=defaultdict(set)
 for view in VIEWS:
  layout=read_json(ROUND1/f'layouts/{view}.json');model=CpuPose(ROUND1,layout,native_skin=True,triangle_batch_size=128);parts={p['name']:p for p in layout['parts']}
  findings=defaultdict(list)
  for e in measurement['errors']:
   if e['view']==view and e['kind']=='unmatched_detached_paint' and e['component']['pixel_count']<=MAX_SLIVER_PIXELS:findings[(e['clip'],e['frame'])].append(e)
  rows={(r['clip'],r['frame']):r for r in samples['samples'] if r['view']==view and r['kind']=='presented'}
  with for_case(ROUND1):
   for index,(key,errors) in enumerate(findings.items()):
    row=rows[key]
    for name in {e['logical_part'] for e in errors}:
     part=parts[name];source=model.image(part['file']);targets=np.asarray([p for e in errors if e['logical_part']==name for p in e['component']['pixels']]);codes=targets[:,1]*pixels.PROOF_DEFAULTS['canvas_size']+targets[:,0]
     if name in model.meshes:
      mapping=mesh_map(layout,row,mask_mesh(model.meshes[name],source[...,3]>0),native_skin=True,triangle_batch_size=128)
      selected=np.isin(mapping.pixels[:,1]*pixels.PROOF_DEFAULTS['canvas_size']+mapping.pixels[:,0],codes);uv=mapping.texels[selected]
     else:
      inverse=np.linalg.inv(matrix(row['parts'][name]['transform']));points=np.column_stack((targets+.5-pixels.PROOF_DEFAULTS['source_offset'],np.ones(len(targets))));uv=np.floor((points@inverse.T)[:,:2]).astype(int)
     uv=uv[(uv[:,0]>=0)&(uv[:,1]>=0)&(uv[:,0]<source.shape[1])&(uv[:,1]<source.shape[0])]
     uv=uv[source[uv[:,1],uv[:,0],3]>0]+part['offset']
     gather[(view,name)].update(map(tuple,uv.tolist()))
    if index%100==0:print('RR48 FRAGMENT SOURCE',view,index,flush=True)
 result=[]
 for view in VIEWS:
  layout=read_json(ROUND1/f'layouts/{view}.json');images={p['name']:source_pixels(ROUND1,p) for p in layout['parts'] if not p.get('hidden_material')}
  for (v,name),uv in gather.items():
   if v!=view:continue
   mask=np.zeros((255,255),bool)
   for x,y in uv:mask[y,x]=True
   labels,groups=components(mask,8)
   for label,count in groups:
    fragment=labels==label;rim=dilate(fragment,1)&~fragment
    contacts={n:int((rim&(im[...,3]>0)).sum()) for n,im in images.items() if n!=name and (rim&(im[...,3]>0)).any()}
    feet={n:c for n,c in contacts.items() if n.startswith('foot_')};candidates=feet or contacts
    target=sorted(candidates,key=lambda n:(-candidates[n],n))[0] if candidates else None
    yy,xx=np.nonzero(fragment)
    result.append({'view':view,'source':name,'target':target,'decision':'re-own' if target else 'clear','contacts':contacts,'source_pixels':int(count),'texels':np.column_stack((xx,yy)).tolist(),'rule':'measured thin detached source; touching foot first, then largest shared rest boundary; lexical tie only; no rest contact clears'})
 write_json(CASE/'feedback2_fragments.json',{'fragments':result,'native_pixels':False,'source_revision':'7b4198b20'})
 print('RR48 FRAGMENT PLAN:',len(result),'fragments;',sum(x['source_pixels'] for x in result),'source texels')
 return result

if __name__=='__main__':plan()
