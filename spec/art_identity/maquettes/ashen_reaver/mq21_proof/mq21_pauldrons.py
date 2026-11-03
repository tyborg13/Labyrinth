"""Source-size domes facing outward, with closed lames on the outside arm."""
import math
import numpy as np
from spec.art_identity.maquettes.raster import camera
from ..forms import TOPOLOGY
from .mq21_pose import rotation_between
from ..pauldrons import dome, band


def build(spec,side,c,u,design):
    sign=1 if side=='near' else -1;H=spec['mq16']['height_m']
    shoulder=np.asarray(spec['joints']['shoulder_'+side]);elbow=np.asarray(spec['joints']['elbow_'+side])
    arm=elbow-shoulder;arm/=np.linalg.norm(arm)
    old=spec['director_feedback2']['pauldrons'];d=design['pauldrons']
    drop=old['bottom_below_shoulder_over_H']*H;overlap=old['overlap_fraction']
    height=drop/(2*(1-overlap));radius=c['pauldron_radius_px']*u;thick=c['pauldron_shell_thickness_px']*u
    angle=math.radians(d['outward_tilt_up_degrees']);axis=np.array([0,sign*math.cos(angle),math.sin(angle)])
    part='pauldron_'+side;joint='shoulder_'+side
    cap=dome(part+'_0',part,joint,[0,0,0],radius,height,thick)
    turn=rotation_between([0,0,1],axis)
    cap['vertices']=(np.einsum('ij,kj->ik',np.asarray(cap['vertices']),turn)+shoulder).tolist();pieces=[cap]
    for layer in (1,2):
        top=shoulder[2]+height-layer*(1-overlap)*height
        piece=band(part+'_'+str(layer),part,joint,shoulder,arm,top-height,top,radius,
                   c['upper_arm_radius_px']*u*design['arms']['diameter_multiplier'],thick,drop,2*thick if layer==1 else 0)
        # Keep each inherited ring's radius and height; its closed cross-section
        # is the outside semicircle, with a straight inner rim facing the arm.
        rings=np.asarray(piece['vertices']).reshape(-1,TOPOLOGY['ring_samples'],3)
        for ring in rings:
            centre=ring.mean(0);r=np.linalg.norm(ring[0,:2]-centre[:2])
            angles=np.linspace(-math.pi/2,math.pi/2,len(ring))
            ring[:,0]=centre[0]+r*np.sin(angles);ring[:,1]=centre[1]+sign*r*np.cos(angles)
        piece['vertices']=rings.reshape(-1,3).tolist();pieces.append(piece)
    # Seat against both explicit projection limits, moving only backward.
    points=np.concatenate([p['vertices'] for p in pieces]);chest=next(p for p in spec['pieces'] if p['id']=='cuirass')
    chest_front=float(np.max(np.asarray(chest['vertices'])[:,0]));toward=camera(spec)[2][2]
    forward_limit=chest_front+d['max_forward_of_chest_over_H']*H
    shift=min(0.,forward_limit-points[:,0].max(),
              (d['centroid_toward_viewer_over_H']*H-np.dot(points.mean(0)-shoulder,toward))/toward[0])
    for piece in pieces:
        q=np.asarray(piece['vertices']);q[:,0]+=shift;piece['vertices']=q.tolist()
    spec['pieces'].extend(pieces)
    spec['mq21'].setdefault('pauldrons',{})[side]={'ids':[p['id'] for p in pieces],
        'dome_ring_samples':TOPOLOGY['ring_samples'],'backward_seating_m':float(shift),
        'dome_outer_pole_index':(13-1)*TOPOLOGY['ring_samples'],
        'radius_m':radius,'height_m':height,'thickness_m':thick}
