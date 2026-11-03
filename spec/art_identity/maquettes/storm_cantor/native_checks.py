"""Measurements from opened native vertices and actual armature endpoints.

This module knows topology ranges, never substitutes recipe coordinates for
an observation. Pure numerical checks are also exercised without Blender.
"""
import math
import numpy as np

NATIVE_DEFAULTS={'endpoint_tolerance_m':1e-4,'angular_tolerance_degrees':1.,
                 'normalized_position_tolerance':.01,'sole_tolerance_m':1e-5,
                 'sweep_ring_samples':12,'pennant_columns':7,'epsilon':1e-9}


def angle(a,b):
    a,b=np.asarray(a),np.asarray(b)
    return math.degrees(math.acos(float(np.clip(np.dot(a,b)/(np.linalg.norm(a)*np.linalg.norm(b)),-1,1))))


def observe(spec,points,joints,head_forward,torso_forward):
    pts={k:np.asarray(v) for k,v in points.items()};j={k:np.asarray(v) for k,v in joints.items()}
    p=spec['pose'];rows=[]
    def add(number,name,target,measured,angular=False):
        tolerance=NATIVE_DEFAULTS['angular_tolerance_degrees'] if angular else NATIVE_DEFAULTS['normalized_position_tolerance']
        rows.append({'requirement':number,'name':name,'target':target,'measured':float(measured),
                     'tolerance':tolerance,'passed':bool(abs(measured-target)<=tolerance)})
    soles={s:float(pts['pointed_sabaton_'+s+'_render'][:,2].min()) for s in ('near','far')}
    H=max(float(pts['helm_tine_'+s+'_render'][:,2].max()) for s in ('near','far'))-min(soles.values())
    lengths={s:float(np.linalg.norm(j['hip_'+s]-[j['ankle_'+s][0],j['ankle_'+s][1],soles[s]])) for s in soles}
    L=sum(lengths.values())/2
    for side in ('near','far'):
        add(1,'knee_bend_'+side,p['knee_bend_degrees'],angle(j['knee_'+side]-j['hip_'+side],j['ankle_'+side]-j['knee_'+side]),True)
    add(1,'hip_lean',p['hip_lean_degrees'],angle(torso_forward,[1,0,0]),True)
    add(1,'head_level',p['head_pitch_degrees'],angle(head_forward,torso_forward),True)
    W=abs(j['shoulder_near'][1]-j['shoulder_far'][1])
    add(2,'ankle_transverse_span_over_shoulders',p['ankle_span_over_shoulders'],abs(j['ankle_near'][1]-j['ankle_far'][1])/W)
    add(3,'near_half_step_over_L',p['half_step_over_L'],(j['ankle_near'][0]-j['ankle_far'][0])/L)
    fist=j['hand_far'];shoulder=j['shoulder_far']
    add(4,'fist_height_over_H',p['fist_height_over_H'],(fist[2]-min(soles.values()))/H)
    add(4,'fist_forward_over_L',p['fist_forward_over_L'],(fist[0]-shoulder[0])/L)
    add(4,'fist_outward_over_L',p['fist_outward_over_L'],-(fist[1]-shoulder[1])/L)
    staff=pts['staff_render'];components={k:staff[a:b] for k,(a,b) in spec['mq17']['staff_components'].items()}
    n=NATIVE_DEFAULTS['sweep_ring_samples'];shaft=components['shaft'].reshape(-1,n,3).mean(axis=1)
    add(5,'staff_vertical_degrees',p['staff_inclination_degrees'],angle(shaft[-1]-shaft[0],[0,0,1]),True)
    add(5,'staff_butt_over_H',0,(shaft[0,2]-min(soles.values()))/H)
    add(5,'grip_axis_distance_over_L',0,np.linalg.norm((fist-shaft[0])[:2])/L)
    add(6,'staff_top_over_H',p['staff_top_over_H'],(staff[:,2].max()-min(soles.values()))/H)
    fork={k:components['fork_'+k].reshape(-1,n,3).mean(axis=1) for k in ('outer','centre','inner')}
    plane=np.cross(fork['outer'][-1]-fork['outer'][0],fork['inner'][-1]-fork['outer'][0])
    add(7,'fork_plane_normal_forward_degrees',0,min(angle(plane,[1,0,0]),angle(plane,[-1,0,0])),True)
    pennant=components['pennant'];cols=NATIVE_DEFAULTS['pennant_columns']
    front=pennant[:len(pennant)//2].reshape(-1,cols,3);tie=front[0,0]
    add(8,'pennant_tie_below_fork_over_H',p['pennant_tie_below_fork_over_H'],(shaft[-1,2]-tie[2])/H)
    add(8,'pennant_length_over_H',p['pennant_length_over_H'],(front[0,:,2].max()-front[-1,:,2].min())/H)
    add(8,'pennant_width_over_H',p['pennant_width_over_H'],np.ptp(front[:,:,1])/H)
    axis=(fist-shoulder)/np.linalg.norm(fist-shoulder);v=j['elbow_far']-shoulder
    v-=axis*np.dot(v,axis)
    pole=v-axis*(v[0]/axis[0])
    add(9,'far_elbow_pole_outward_degrees',p['far_elbow_pole_outward_degrees'],math.degrees(math.atan2(-pole[1],-pole[2])),True)
    upper=j['elbow_near']-j['shoulder_near'];fore=j['hand_near']-j['elbow_near']
    add(10,'near_upper_out_degrees',p['near_upper_out_degrees'],math.degrees(math.asin(upper[1]/np.linalg.norm(upper))),True)
    add(11,'near_elbow_bend_degrees',p['near_elbow_bend_degrees'],angle(upper,fore),True)
    for finger in range(4):
        centers=pts['finger_near_'+str(finger)+'_render'].reshape(-1,n,3).mean(axis=1)
        directions=np.diff(centers,axis=0)
        for k in range(len(directions)-1):
            add(12,'near_finger_'+str(finger)+'_knuckle_'+str(k),p['near_finger_knuckle_degrees'],angle(directions[k],directions[k+1]),True)
    thigh_front=pts['thigh_plate_near_render'][:,0].max()
    add(12,'near_wrist_ahead_of_thigh_over_L',p['near_wrist_ahead_of_thigh_over_L'],(j['hand_near'][0]-thigh_front)/L)
    add('extra','bell_mouth_over_H',p['bell_mouth_over_H'],np.ptp(pts['bell_render'][:,1])/H)
    helm=pts['great_helm_render'];source=spec['source_calipers'];sourceH=source['sole_y']-source['taller_tine_y']
    proportions={
        'helm_without_tines_over_H':{'source':(source['helm_bottom_y']-source['helm_top_y'])/sourceH,'native':float(np.ptp(helm[:,2])/H)},
        'tines_over_H':{'source':(source['helm_top_y']-source['taller_tine_y'])/sourceH,'native':float((H-helm[:,2].max())/H)},
        'shoulder_transverse_width_over_H':{'source':(source['shoulder_joint_x'][1]-source['shoulder_joint_x'][0])/sourceH,'native':float(W/H)},
        'torso_neck_to_waist_over_H':{'source':(source['waist_y']-source['neck_y'])/sourceH,'native':float(np.linalg.norm(j['head']-j['pelvis'])/H)},
        'leg_hip_to_sole_over_H':{'source':(source['sole_y']-source['hip_y'])/sourceH,'native':float(L/H)}}
    checks={'pose_values_within_tolerance':all(r['passed'] for r in rows),
            'both_feet_planted':all(abs(x)<=NATIVE_DEFAULTS['sole_tolerance_m'] for x in soles.values()),
            'level_shoulders':abs(j['shoulder_near'][2]-j['shoulder_far'][2])<=NATIVE_DEFAULTS['endpoint_tolerance_m'],
            'far_elbow_not_forward':j['elbow_far'][0]<=j['shoulder_far'][0]+NATIVE_DEFAULTS['endpoint_tolerance_m'],
            'fork_tine_order_and_curves':bool(fork['outer'][-1,2]>fork['inner'][-1,2]>fork['centre'][-1,2] and fork['outer'][-1,1]<shaft[-1,1] and fork['inner'][-1,1]>shaft[-1,1]),
            'pennant_outward':bool(front[:,:,1].max()<=shaft[-1,1]+NATIVE_DEFAULTS['endpoint_tolerance_m']),
            'forearm_folds_forward':bool(fore[0]>0),
            'head_and_chest_forward':angle(head_forward,[1,0,0])<=1 and angle(torso_forward,[1,0,0])<=1}
    cloak_z=float(pts['near_cloak_streamer_render'][:,2].min())
    cloak={'lowest_hem_z_m':cloak_z,'near_knee_z_m':float(j['knee_near'][2]),
           'error_over_L':float(abs(cloak_z-j['knee_near'][2])/L)}
    checks['cloak_hem_at_near_knee']=cloak['error_over_L']<=NATIVE_DEFAULTS['normalized_position_tolerance']
    from .volume_checks import observe_volumes
    volumes=observe_volumes(spec,points,joints,H)
    checks['feedback1_volumes']=volumes['passed']
    checks={name:bool(value) for name,value in checks.items()}
    return {'checks':checks,'pose_values':rows,'height_m':H,'leg_length_m':L,'soles_m':soles,
            'proportions':proportions,'cloak_hem':cloak,'volumes':volumes,'passed':all(checks.values())}
