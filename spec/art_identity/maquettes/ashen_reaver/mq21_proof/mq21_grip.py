"""Separate curled finger plates surrounding a rigid, independently owned hilt."""
import math
import numpy as np
from ..forms import cord, oval, shell, union, closed_sheet, TOPOLOGY


def blade_frame(p):
    down,out=map(math.radians,(p['blade_down_degrees'],p['blade_outward_degrees']))
    direction=np.array([math.cos(out)*math.cos(down),-math.sin(out)*math.cos(down),-math.sin(down)])
    edge=np.array([0.,0,-1]);edge-=direction*np.dot(edge,direction);edge/=np.linalg.norm(edge)
    normal=np.cross(direction,edge)
    return direction,edge,normal


def build(spec,old,c,u,design):
    H=spec['mq16']['height_m'];d,e,n=blade_frame(spec['pose']);hand=np.asarray(spec['joints']['hand_far'])
    m=old['mq16']['falchion'];before={p['id']:p for p in old['pieces']}
    scale=design['arms']['gauntlet_multiplier'];half=c['hand_half_height_px']*u*scale
    finger_r=c['finger_radius_px']*u*scale;grip_r=c['grip_radius_px']*u
    length=2*half;spacing=(length-2*finger_r)/(design['grip']['finger_count']-1)
    if spacing<=2*finger_r:raise ValueError('Finger plates overlap at the requested gauntlet size')
    # Index is bladeward, little finger pommelward. Each C-shaped plate wraps
    # the handle; the palm closes its dorsal opening without filling the grip.
    radius=grip_r+finger_r;angle_samples=TOPOLOGY['ring_samples']
    for i in range(design['grip']['finger_count']):
        centre=hand+d*(half-finger_r-i*spacing)
        angles=np.linspace(-math.pi/2,math.pi,angle_samples)
        path=[centre+radius*(math.cos(a)*e+math.sin(a)*n) for a in angles]
        spec['pieces'].append(cord('finger_far_'+str(i),'hand_far','hand_far',path,finger_r))
    # Closed dorsal shell: no solid oval in the space occupied by the grip.
    palm_radius=grip_r+2*finger_r
    angles=np.linspace(math.pi,3*math.pi/2,angle_samples//4+1)
    rows=[[hand+d*z+palm_radius*(math.cos(a)*e+math.sin(a)*n) for a in angles] for z in (-half,half)]
    spec['pieces'].append(closed_sheet('gauntlet_far','hand_far','hand_far',np.asarray(rows).tolist(),finger_r,(-e).tolist()))
    index=hand+d*(half-finger_r)
    thumb=[hand-d*half/2-palm_radius*e,index-palm_radius*e,
           index+n*(radius+2*finger_r),index+e*(radius+2*finger_r)+n*finger_r]
    spec['pieces'].append(cord('thumb_far','hand_far','hand_far',thumb,finger_r))
    # Measure the actual hand envelope; guard surface has precisely .01H
    # clearance along the grip, rather than burying the guard in a finger.
    hand_vertices=np.concatenate([np.asarray(p['vertices']) for p in spec['pieces'] if p['part']=='hand_far'])
    axial=np.einsum('ij,j->i',hand_vertices-hand,d);guard_radius=grip_r
    guard_at=hand+d*(axial.max()+design['grip']['guard_gap_over_H']*H+guard_radius)
    pommel_r=c['pommel_radius_px']*u;pommel_at=hand+d*(axial.min()-pommel_r)
    old_d=np.asarray(m['direction']);old_e=np.asarray(m['edge_direction']);old_n=np.asarray(m['face_normal'])
    rotation=np.column_stack((d,e,n))@np.column_stack((old_d,old_e,old_n)).T
    q=np.asarray(before['falchion']['vertices']);old_root=(q[m['outer_indices'][0]]+q[m['spine_indices'][0]])/2
    transform=lambda v:(np.einsum('ij,kj->ik',np.asarray(v)-old_root,rotation)+guard_at).tolist()
    blade=shell('falchion_blade','falchion','hand_far',transform(q[:m['blade_vertex_count']]),before['falchion']['faces'][:m['blade_face_count']])
    grip=cord('falchion_grip','falchion','hand_far',[pommel_at,guard_at],grip_r)
    guard=cord('falchion_guard','falchion','hand_far',[guard_at-n*c['guard_half_width_px']*u,guard_at+n*c['guard_half_width_px']*u],guard_radius)
    pommel=oval('falchion_pommel','falchion','hand_far',pommel_at,[pommel_r]*3,[n,-e,d])
    spec['pieces'].append(union('falchion','falchion','hand_far',[blade,grip,guard,pommel]))
    from copy import deepcopy
    glow=deepcopy(before['glowing_edge']);glow['vertices']=transform(glow['vertices']);spec['pieces'].append(glow)
    meta=spec['mq16']['falchion'];meta.update(direction=d.tolist(),edge_direction=e.tolist(),face_normal=n.tolist(),
        tip_world=blade['vertices'][m['blade_tip_vertex']],grip_world=hand.tolist(),pommel_world=pommel_at.tolist(),
        pommel_vertex_start=len(blade['vertices'])+len(grip['vertices'])+len(guard['vertices']))
    spec['mq21']['grip']={'guard_vertex_start':len(blade['vertices'])+len(grip['vertices']),
        'guard_vertex_count':len(guard['vertices']),'finger_count':design['grip']['finger_count'],
        'interpretation':'Above/top and below/little finger follow the held hilt axis; its bladeward end points down in world Z.'}
