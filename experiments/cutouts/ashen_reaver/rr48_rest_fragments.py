"""rr-42 ownership of disconnected rest islands, including the full source strips."""
import numpy as np
from rr48_build import CASE,VIEWS
from cutout_pipeline.cases import read_json,write_json
from maquette_motion.features import source_pixels
from maquette_motion.silhouette import components,dilate


def plan():
 path=CASE/'feedback2_ownership.json';record=read_json(path);rows=[]
 for view in VIEWS:
  layout=read_json(CASE/f'layouts/{view}.json');images={p['name']:source_pixels(CASE,p) for p in layout['parts'] if not p.get('hidden_material')};cores={}
  for n,im in images.items():
   labels,groups=components(im[...,3]>0,8);cores[n]=labels==groups[0][0]
  for name,image in images.items():
   # The occluded crossguard is joined by the registered grip cap, and must
   # remain part of the same rigid weapon through release.
   if name=='falchion':continue
   labels,groups=components(image[...,3]>0,8)
   for label,count in groups[1:]:
    fragment=labels==label;rim=dilate(fragment,1)&~fragment
    contacts={n:int((rim&core).sum()) for n,core in cores.items() if n!=name and (rim&core).any()}
    if not contacts:contacts={n:int((rim&(im[...,3]>0)).sum()) for n,im in images.items() if n!=name and (rim&(im[...,3]>0)).any()}
    feet={n:c for n,c in contacts.items() if n.startswith('foot_')};candidates=feet or contacts
    target=sorted(candidates,key=lambda n:(-candidates[n],n))[0] if candidates else None;y,x=np.nonzero(fragment)
    rows.append({'view':view,'source':name,'target':target,'source_pixels':int(count),'texels':np.column_stack((x,y)).tolist(),'rgba':image[y,x].tolist(),'hidden':False,'decision':'re-own' if target else 'clear','rule':'rr-42 rest island: touching retained core, foot first then largest boundary; no rest contact clears'})
 record['fragments']+=rows;write_json(path,record);print('RR48 REST ISLAND OWNERSHIP:',len(rows),'islands;',sum(r['source_pixels'] for r in rows),'source texels')
 return len(rows)

if __name__=='__main__':plan()
