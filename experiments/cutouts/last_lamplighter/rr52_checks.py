"""On-demand pose contracts; lantern idle sway is director-authored."""
import math
import numpy as np
from humanoid_cutout.gates import matrix

def arm_excursions(data,director):
 expected=director['last_lamplighter']['clips']['move']['gait']['arm_swing'];actual=data['clips']['move']['gait']['arm_swing'];errors=[];ratios={}
 for side in ('near','far'):
  ratios[side]=actual[side]['upper_deg']/expected[side]['upper_deg']
  if actual[side]!=expected[side]:errors.append('walk '+side+' arm differs from the approved 100% shoulder pendulum')
 return {'ok':not errors,'errors':errors,'ratios':ratios,'checks':2}

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
    if part['name'] not in parts or part['logical_part']=='lantern':continue
    names=next((list(m['weights']) for m in layout['joint_meshes'] if m['name']==part['name']),[part['bone']])
    for name in names:
     bone=matrix(row['bones'][name]['global']);offset=bone[:2,2]-layout['joints'][name]['position'];offsets.append(offset);checks+=1
     if not np.allclose(bone[:2,:2],np.eye(2),atol=1e-5):errors.append('idle rotation/scale/deformation: '+name)
     if not np.allclose(offset,np.round(offset),atol=1e-4):errors.append('idle fractional offset: '+name)
   if not all(np.allclose(offsets[0],o,atol=1e-4) for o in offsets):errors.append('idle group split: '+group)
   if group=='lower_body' and any(np.linalg.norm(o)>1e-4 for o in offsets):errors.append('idle lower body moved')
 return {'ok':not errors,'errors':sorted(set(errors)),'checks':checks,'pixel_mismatch_by_rigid_translation':0 if not errors else None}
