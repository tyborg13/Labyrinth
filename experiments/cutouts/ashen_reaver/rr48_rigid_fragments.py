"""Map the rigid item's measured raster slivers back to exact source texels."""
from collections import defaultdict
import numpy as np
from PIL import Image
from rr48_build import CASE,VIEWS
from rr48_feedback2_source import ROUND1
from cutout_pipeline.cases import read_json,write_json
from humanoid_cutout.gates import matrix
from maquette_motion import pixels
from maquette_motion.features import source_pixels
from maquette_motion.silhouette import components,dilate

MAX_SLIVER_PIXELS=7  # Director's measured thin strips, feedback 2 section 4.

def plan(samples):
 found=defaultdict(set)
 for view in VIEWS:
  layout=read_json(CASE/f'layouts/{view}.json');parts=[p for p in layout['parts'] if p['logical_part']=='falchion'];sources={p['name']:np.asarray(Image.open(CASE/p['file']).convert('RGBA')) for p in parts}
  for row in samples['samples']:
   if row['view']!=view or row['kind']!='presented':continue
   layers=[(p,pixels.render(sources[p['name']],matrix(row['parts'][p['name']]['transform']))[...,3]>0) for p in parts]
   occupied=np.logical_or.reduce([im for _,im in layers]);labels,groups=components(occupied,8)
   for label,count in groups[1:]:
    fragment=labels==label
    # Newly duplicated cap paint can form a larger isolated fist patch. Re-own
    # that cap to its rest cover too; never erase a large piece of the blade.
    visible=np.logical_or.reduce([im for p,im in layers if not p.get('hidden_material')])
    if count>MAX_SLIVER_PIXELS and (fragment&visible).any():continue
    # Attribute visible item pixels in exact layer order, never a bbox donor.
    owner=np.zeros_like(labels)
    for i,(p,im) in enumerate(sorted(layers,key=lambda r:r[0]['z_index'])):owner[im]=i+1
    for i,(p,im) in enumerate(sorted(layers,key=lambda r:r[0]['z_index'])):
     y,x=np.nonzero(fragment&(owner==i+1))
     if not len(x):continue
     # Raster source-coordinate IDs through the very same fixed-subpixel quad
     # and nearest-UV rule. An inverse affine estimate can pick the wrong side
     # of a UV tie and is not provenance for a one-pixel component.
     source=sources[p['name']];ids=np.zeros_like(source);sy,sx=np.indices(source.shape[:2]);ids[...,0]=sx;ids[...,1]=sy;ids[...,3]=source[...,3]
     mapped=pixels.render(ids,matrix(row['parts'][p['name']]['transform']));uv=mapped[y,x,:2].astype(int)+p['offset']
     found[view,p['name']].update(map(tuple,uv.tolist()))
 ledger=CASE/'feedback2_rigid_fragments.json';rows=read_json(ledger)['fragments'] if ledger.exists() else []
 for (view,name),uv in found.items():
  old=read_json(ROUND1/f'layouts/{view}.json');images={p['name']:source_pixels(ROUND1,p) for p in old['parts'] if not p.get('hidden_material')};mask=np.zeros((255,255),bool)
  for x,y in uv:mask[y,x]=True
  labels,groups=components(mask,8)
  for label,count in groups:
   fragment=labels==label;rim=dilate(fragment,1)|fragment;contacts={n:int((rim&(im[...,3]>0)).sum()) for n,im in images.items() if n!='falchion' and (rim&(im[...,3]>0)).any()}
   target=sorted(contacts,key=lambda n:(-contacts[n],n))[0] if contacts else None
   y,x=np.nonzero(fragment);rows.append({'view':view,'source':name,'target':target,'texels':np.column_stack((x,y)).tolist(),'source_pixels':int(count),'decision':'re-own' if target else 'clear','rule':'measured rigid raster sliver; exact source mapping; rest-contact owner or clear'})
 write_json(ledger,{'fragments':rows,'native_pixels':False});print('RR48 RIGID SOURCE SLIVERS:',sum(len(v) for v in found.values()),'new source texels')
 return sum(len(v) for v in found.values())

if __name__=='__main__':plan(read_json(CASE/'proof/feedback2_samples.json'))
