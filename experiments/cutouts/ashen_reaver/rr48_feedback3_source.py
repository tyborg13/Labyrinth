"""Whole registered director underlay, partitioned by receiving body paint."""
from collections import deque
import numpy as np
from PIL import Image
from rr48_build import CASE,MESHES
from rr48_feedback1 import inputs
from rr48_feedback2_source import ROUND1
from cutout_pipeline.cases import read_json
from maquette_motion.features import source_pixels
from maquette_motion.silhouette import dilate,components

RECEIVERS=('leg_far','leg_near','pelvis','torso','head','foot_far','foot_near')

def support_paths(base,paint,texels):
 # A measured cap must not introduce a free-floating source island. Join it
 # to its receiver by the shortest 8-connected path of existing underlay.
 # This chooses ownership only; every supplied RGBA remains director paint.
 labels,groups=components(base,8);core=labels==groups[0][0]
 previous={tuple(p):None for p in np.argwhere(core&paint)};queue=deque(previous)
 targets={(v,u) for u,v in texels};remaining=targets-set(previous)
 while queue and remaining:
  y,x=queue.popleft()
  for dy,dx in ((-1,-1),(-1,0),(-1,1),(0,-1),(0,1),(1,-1),(1,0),(1,1)):
   point=(y+dy,x+dx);v,u=point
   if not (0<=v<paint.shape[0] and 0<=u<paint.shape[1]) or not paint[v,u] or point in previous:continue
   previous[point]=(y,x);queue.append(point);remaining.discard(point)
 if remaining:raise ValueError('Measured cap has no director-painted path to receiving piece')
 support=set()
 for point in targets:
  while previous[point] is not None:
   y,x=point
   if not base[y,x] and point not in targets:support.add((int(x),int(y)))
   point=previous[point]
 return support

def domains(view):
 from rr48_feedback2 import visible_images
 layout=read_json(ROUND1/f'layouts/{view}.json');parts={p['name']:p for p in layout['parts'] if p['name'] in RECEIVERS}
 images=visible_images(view)
 owner=np.full((255,255),'',object);paint=inputs(view)
 # rr-42 precedence: registered storage, then exact visible source ownership.
 ordered=sorted(parts.values(),key=lambda p:p['z_index'])
 for p in ordered:
  ys,xs=np.nonzero(images[p['name']][...,3]);points=np.column_stack((xs,ys))
  if p['name'] in MESHES:points=np.concatenate((points,np.asarray([layout['joints'][n]['position'] for n in MESHES[p['name']]['joints']])))
  x,y=np.floor(points.min(0)).astype(int);r,b=np.ceil(points.max(0)+1).astype(int);owner[y:b,x:r]=p['name']
 for p in ordered:owner[images[p['name']][...,3]>0]=p['name']
 donors={n:np.column_stack(np.nonzero(images[n][...,3])) for n in RECEIVERS}
 for y,x in np.argwhere((owner=='')&(paint[...,3]>0)):
  owner[y,x]=min(RECEIVERS,key=lambda n:np.min(np.sum((donors[n]-[y,x])**2,axis=1)))
 return {n:(owner==n)&(paint[...,3]>0) for n in RECEIVERS}

def supply(plans,view,caps=True):
 paint=inputs(view);partition=domains(view)
 for name,plan in plans.items():
  if name.startswith('cap_'):continue
  logical=plan['logical'];underlay=plan['underlay']&plan['tuck']
  if logical in partition:underlay|=partition[logical]
  underlay &= ~plan['cap']
  image=np.zeros_like(paint);image[underlay]=paint[underlay]
  image[plan['cap']]=plan['image'][plan['cap']]
  plan.update(underlay=underlay,image=image,domain=underlay|plan['cap'])
 if caps:
  path=CASE/'feedback3_joint_caps.json'
  if path.exists():
   base={n:p['image'][...,3]>0 for n,p in plans.items()};depth=read_json(CASE/'anatomy.json')['tucks']['base_px']
   for row in read_json(path)['caps']:
    if row['view']!=view:continue
    name='hidden_'+row['receiver'];plan=plans[name];xy=np.asarray(row['texels'],int);x,y=xy.T
    # The inherited band is a minimum tuck. Further texels are permitted only
    # when the native-origin inverse-UV sweep measured that exact missing UV.
    measured=np.zeros_like(base[name])
    for witness in row.get('witnesses',[]):
     u,v=witness['uv'];measured[v,u]=True
    allowed=(dilate(base[name],depth)|measured)&(paint[...,3]>0)
    if not allowed[y,x].all():raise ValueError('Joint cap outside registered measured receiving-paint tuck')
    supports=support_paths(base[name],paint[...,3]>0,row['texels'])
    if supports!=set(map(tuple,row.get('support_texels',[]))):raise ValueError('Joint cap support is not its exact director-painted receiving path')
    if supports:
     sx,sy=np.asarray(sorted(supports)).T;x=np.r_[x,sx];y=np.r_[y,sy]
    plan['image'][y,x]=paint[y,x];plan['domain'][y,x]=True;plan['underlay'][y,x]=True;plan['tuck'][y,x]=True;plan['cap'][y,x]=False
 return plans
