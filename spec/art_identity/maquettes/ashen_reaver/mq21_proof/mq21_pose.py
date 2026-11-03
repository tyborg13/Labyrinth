"""Body-space mq-21 pose; no renderer or source-art fitting."""
import math
import numpy as np


def rotation_y(degrees):
    a=math.radians(degrees);c,s=math.cos(a),math.sin(a)
    return np.array([[c,0,s],[0,1,0],[-s,0,c]])


def rotation_between(before,after):
    a=np.asarray(before,float);a/=np.linalg.norm(a)
    b=np.asarray(after,float);b/=np.linalg.norm(b)
    cross=np.cross(a,b);cosine=float(np.dot(a,b))
    if cosine<=-1+1e-9:raise ValueError('Antiparallel pose transport requires an explicit axis')
    skew=np.array([[0,-cross[2],cross[1]],[cross[2],0,-cross[0]],[-cross[1],cross[0],0]])
    return np.eye(3)+skew+skew@skew/(1+cosine)


def fixed_knee(hip,ankle,upper,lower):
    delta=ankle-hip;distance=np.linalg.norm(delta);axis=delta/distance
    along=(upper**2-lower**2+distance**2)/(2*distance)
    forward=np.array([1.,0,0])-axis*axis[0];forward/=np.linalg.norm(forward)
    return hip+axis*along+forward*math.sqrt(max(0.,upper**2-along**2))


def posed_joints(old,p,H,leg_design):
    from ..recipe import elbow
    j={k:np.array(v,float) for k,v in old['joints'].items()}
    previous={k:v.copy() for k,v in j.items()};L=old['mq16']['leg_length_m']
    waist=j['pelvis'][2];slope=math.tan(math.radians(p['hip_lean_degrees']))
    for name in ('torso','head'):
        j[name][0]=(j[name][2]-waist)*slope
    j['head_tip']=j['head']+rotation_y(p['head_pitch_down_degrees'])@(previous['head_tip']-previous['head'])
    W=j['shoulder_near'][1]-j['shoulder_far'][1]
    for side,sign in (('near',1),('far',-1)):
        shoulder=j['shoulder_'+side]
        shoulder+=np.array([p['shoulder_forward_over_H']*H,0,p['shoulder_raise_over_H']*H])
        if side=='far':shoulder[2]-=p['far_shoulder_hunch_reduction_over_H']*H
        hip=j['hip_'+side];ankle=j['ankle_'+side]
        ankle[:2]=[sign*p['near_step_over_leg_length']*L/2,sign*p['foot_span_over_shoulder_span']*W/2]
        upper=np.linalg.norm(previous['knee_'+side]-hip)
        lower=np.linalg.norm(previous['ankle_'+side]-previous['knee_'+side])
        reach2=upper**2+lower**2+2*upper*lower*math.cos(math.radians(p['knee_bend_degrees'][side]))
        horizontal2=reach2-(ankle[2]-hip[2])**2
        if horizontal2<0:raise ValueError('Fixed knee bend cannot reach the planted sole plane')
        # Planted feet and exact bends leave a horizontal reach circle.
        # Project the requested stance/step onto it; never stretch a segment.
        direction=ankle[:2]-hip[:2];direction/=np.linalg.norm(direction)
        ankle[:2]=hip[:2]+direction*math.sqrt(horizontal2)
        j['knee_'+side]=fixed_knee(hip,ankle,upper,lower)
        j['foot_tip_'+side]=ankle+previous['foot_tip_'+side]-previous['ankle_'+side]
        upper=np.linalg.norm(previous['elbow_'+side]-previous['shoulder_'+side])
        lower=np.linalg.norm(previous['hand_'+side]-previous['elbow_'+side])
        if side=='near':
            axis=j['knee_near']-hip;axis/=np.linalg.norm(axis)
            front=np.array([1.,0,0])-axis*axis[0];front/=np.linalg.norm(front)
            thigh_front=hip[0]+leg_design['hip_size_over_H']*H/2*leg_design['depth_over_width']*front[0]
            target=np.array([thigh_front+p['near_fist_forward_of_thigh_over_L']*L,shoulder[1],hip[2]])
            bend=math.radians(p['near_elbow_bend_degrees'])
            delta=target-shoulder
            # The bend is exact. Only shoulder swing varies in the forward
            # plane. Its endpoint traces a circle; nearest point is radial.
            swing=math.atan2(delta[0],-delta[2])-math.atan2(lower*math.sin(bend),upper+lower*math.cos(bend))
            j['elbow_near']=shoulder+upper*np.array([math.sin(swing),0,-math.cos(swing)])
            j['hand_near']=j['elbow_near']+lower*np.array([math.sin(swing+bend),0,-math.cos(swing+bend)])
            j['hand_tip_near']=j['hand_near']+previous['hand_tip_near']-previous['hand_near']
            continue
        else:
            hand=hip+np.array([p['far_hand_forward_over_leg_length']*L,-p['far_hand_outward_over_leg_length']*L,
                               -p.get('far_fist_lowering_over_H',0)*H])
            # The feedback-2 reach solve changes elbow angle and hunch only.
            # Both source segment lengths remain exact.
        j['hand_'+side]=hand;j['elbow_'+side]=elbow(shoulder,hand,upper,lower)
        j['hand_tip_'+side]=hand+previous['hand_tip_'+side]-previous['hand_'+side]
    return {k:v.tolist() for k,v in j.items()}
