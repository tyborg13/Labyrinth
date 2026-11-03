"""Director feedback-2 reach solve: source arm lengths, elbow and hunch only."""
from copy import deepcopy
import math
import numpy as np
from .mq21_grip import build

SOLVER_DEFAULTS={'height_epsilon_m':1e-8}


def solve(old,pose,design,calipers,u):
    p=deepcopy(pose);H=old['mq16']['height_m'];L=old['mq16']['leg_length_m'];rule=design['blade_clearance']
    j={name:np.asarray(point,float) for name,point in old['joints'].items()}
    upper=np.linalg.norm(j['elbow_far']-j['shoulder_far']);lower=np.linalg.norm(j['hand_far']-j['elbow_far'])
    bend=math.radians(rule['minimum_far_elbow_bend_degrees'])
    reach=math.sqrt(upper**2+lower**2+2*upper*lower*math.cos(bend))
    shoulder=j['shoulder_far']+[p['shoulder_forward_over_H']*H,0,p['shoulder_raise_over_H']*H]
    hand=j['hip_far']+[p['far_hand_forward_over_leg_length']*L,-p['far_hand_outward_over_leg_length']*L,
                      -rule['desired_fist_lowering_over_H']*H]
    horizontal_squared=float(np.sum((hand[:2]-shoulder[:2])**2))
    if horizontal_squared>=reach**2:raise ValueError('Horizontal fist offset exceeds source arm reach')
    vertical_reach=math.sqrt(reach**2-horizontal_squared)
    reduction=min(max(0.,shoulder[2]-hand[2]-vertical_reach),rule['maximum_far_shoulder_hunch_reduction_over_H']*H)
    shoulder[2]-=reduction
    hand[2]=max(hand[2],shoulder[2]-vertical_reach)
    lowering=(j['hip_far'][2]-hand[2])/H
    p.update(blade_down_degrees=rule['down_degrees'],blade_outward_degrees=rule['outward_degrees'],
             far_fist_lowering_over_H=float(lowering),far_shoulder_hunch_reduction_over_H=float(reduction/H))
    trial={'pose':p,'joints':{'hand_far':hand.tolist()},'mq16':deepcopy(old['mq16']),'mq21':{},'pieces':[]}
    build(trial,old,calipers,u,design)
    clearance=float(trial['mq16']['falchion']['tip_world'][2]/H)
    if not 0<clearance<=rule['maximum_clearance_over_H']+SOLVER_DEFAULTS['height_epsilon_m']:
        raise ValueError('Fixed-length reach gives clearance outside director limit: '+str(clearance))
    distance=np.linalg.norm(hand-shoulder)
    observed_bend=math.degrees(math.acos(float(np.clip((distance**2-upper**2-lower**2)/(2*upper*lower),-1,1))))
    return p,{'blade_down_degrees':rule['down_degrees'],'blade_outward_degrees':rule['outward_degrees'],
        'far_fist_lowering_over_H':float(lowering),'far_shoulder_hunch_reduction_over_H':float(reduction/H),
        'far_elbow_bend_degrees':observed_bend,'far_upper_length_m':float(upper),'far_forearm_length_m':float(lower),
        'tip_clearance_over_H':clearance,'method':'Source segment lengths fixed; straighten elbow to director limit, then reduce far hunch only as permitted; accept resulting clearance.'}
