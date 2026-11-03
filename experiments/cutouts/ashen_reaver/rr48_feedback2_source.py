"""Exact director-owned tuck and interior joint-cap source plans (feedback 2)."""
import subprocess
from collections import deque
import numpy as np
from PIL import Image
from rr48_build import CASE,ROOT,VIEWS
from rr48_feedback1 import BASE,inputs
from cutout_pipeline.cases import read_json,write_json,digest
from maquette_motion.features import source_pixels
from maquette_motion.material_palette import outline_class,rules
from maquette_motion.silhouette import components,dilate

ROUND1_REVISION='7b4198b20'
ROUND1=CASE/'baseline/round1'

def grip_band(layout,parts,interior,depth):
 """Continue the occluded grip between the blade and crossguard through the fist.

 A shortest 4-connected route uses only approved interior fist paint. The band
 is the existing tuck depth wide; no colour or source coordinate is invented.
 """
 blade=source_pixels(ROUND1,parts['falchion'])[...,3]>0;hand=source_pixels(ROUND1,parts['hand_far'])[...,3]>0
 labels,groups=components(blade,8);result=np.zeros_like(blade)
 if len(groups)<2:return result
 allowed=(dilate(hand,depth)&interior)|blade;core=labels==groups[0][0]
 for label,_ in groups[1:]:
  targets=labels==label;queue=deque(map(tuple,np.argwhere(core)));previous={p:None for p in queue};end=None
  while queue:
   y,x=queue.popleft()
   if targets[y,x]:end=(y,x);break
   for dy,dx in ((-1,0),(1,0),(0,-1),(0,1)):
    p=(y+dy,x+dx)
    if 0<=p[0]<255 and 0<=p[1]<255 and allowed[p] and p not in previous:previous[p]=(y,x);queue.append(p)
  if end is None:raise ValueError('TODO_DESIGN_grip_interior_route: no approved interior path through fist')
  route=np.zeros_like(blade)
  while end is not None:route[end]=True;end=previous[end]
  result |= dilate(route,depth//2)&interior&dilate(hand,depth)
 return result

def snapshot():
 if (ROUND1/'manifest.json').exists():return
 prefix=str(CASE.relative_to(ROOT))+'/'
 paths=subprocess.check_output(['git','ls-tree','-r','--name-only',ROUND1_REVISION,'--',prefix],cwd=ROOT,text=True).splitlines();files={}
 for path in paths:
  name=path[len(prefix):]
  if name.startswith('baseline/'):continue
  if name.startswith('proof/') and name not in ['proof/build.json','proof/feedback1_joint_measurement.json','proof/feedback1_samples.json']:continue
  if not name.endswith(('.json','.png')):continue
  target=ROUND1/name;target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(subprocess.check_output(['git','show',ROUND1_REVISION+':'+path],cwd=ROOT));files[name]=digest(target)
 write_json(ROUND1/'manifest.json',{'revision':ROUND1_REVISION,'files':files});(ROUND1/'.gdignore').touch()


def source_plan(view,*,include_feedback3_caps=True):
 layout=read_json(ROUND1/f'layouts/{view}.json');job=read_json(ROUND1/'inputs.json')[view+'_job'];paint=np.asarray(Image.open(ROOT/job/'processed.png').convert('RGBA'));underlay=inputs(view)
 parts={p['name']:p for p in layout['parts'] if not p.get('hidden_material')};interior=(paint[...,3]>0)&~outline_class(paint,rules(ROUND1,view))
 plans={};depth=read_json(CASE/'anatomy.json')['tucks']['base_px'];grip=grip_band(layout,parts,interior,depth)
 for name,part in parts.items():
  old=CASE/f'ownership/feedback1_{view}_hidden_{name}.png'
  footprint=np.asarray(Image.open(old).convert('L'))>0 if old.exists() else np.zeros((255,255),bool)
  tuck=np.asarray(Image.open(BASE/f'tucks/{view}_{name}.png').convert('L'))>0
  if name=='falchion':tuck |= grip
  cap=tuck&(underlay[...,3]==0)&interior
  image=np.zeros_like(paint);domain=footprint|tuck;image[domain]=underlay[domain];image[cap]=paint[cap]
  plans['hidden_'+name]={'logical':name,'bone':part['bone'],'domain':domain,'underlay':domain&~cap,'cap':cap,'image':image,'tuck':tuck}
 # The internal elbow cap is a rigid cross-joint band. Its three-pixel depth
 # comes from the existing tuck policy, not a new excursion or tuning value.
 yy,xx=np.mgrid[:255,:255];points=np.stack((xx+.5,yy+.5),axis=-1)
 depth=read_json(CASE/'anatomy.json')['tucks']['base_px']
 for side in ('near','far'):
  name='arm_'+side;recipe=read_json(CASE/'anatomy.json')['meshes'][name]
  a,b,c=[np.asarray(layout['joints'][n]['position']) for n in recipe['joints']];axis=(c-a)/np.linalg.norm(c-a)
  own=source_pixels(ROUND1,parts[name])[...,3]>0
  band=(np.abs(np.sum((points-b)*axis,axis=-1))<=depth)&dilate(own,depth)&(paint[...,3]>0)
  cap=band&interior;image=np.zeros_like(paint);image[cap]=paint[cap]
  plans['cap_'+name]={'logical':name,'bone':'fore_'+side,'domain':band,'underlay':np.zeros_like(band),'cap':cap,'image':image,'tuck':band}
 ledger=CASE/'feedback2_rigid_fragments.json'
 if ledger.exists():
  for row in read_json(ledger)['fragments']:
   if row['view']!=view or row['source'] not in plans:continue
   x,y=np.asarray(row['texels']).T;plans[row['source']]['image'][y,x]=0;plans[row['source']]['cap'][y,x]=False
 ledger=CASE/'feedback2_ownership.json'
 if ledger.exists():
  for row in read_json(ledger)['fragments']:
   if row['view']!=view or not row['hidden']:continue
   source=plans[row['source']];x,y=np.asarray(row['texels']).T;values=np.asarray(row['rgba'],np.uint8)
   was_cap=source['cap'][y,x].copy();source['image'][y,x]=0;source['cap'][y,x]=False;source['underlay'][y,x]=False
   if row['target']:
    target=plans['hidden_'+row['target']];target['image'][y,x]=values;target['domain'][y,x]=True;target['tuck'][y,x]=True;target['cap'][y,x]=was_cap;target['underlay'][y,x]=~was_cap
 if (CASE/'feedback3_policy.json').exists():
  from rr48_feedback3_source import supply
  plans=supply(plans,view,caps=include_feedback3_caps)
 return plans
