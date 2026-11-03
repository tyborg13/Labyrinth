"""Pure observations from opened world vertices and actual rig endpoints."""
import math
import numpy as np
from .feedback2_checks import blade_observation,pauldron_observation

NATIVE_DEFAULTS={'position_tolerance_m':1e-5,'angle_tolerance_degrees':.01,
                 'ratio_tolerance':1e-4,'grip_containment_slack_m':1e-5}


def angle(a,b):
    a,b=np.asarray(a),np.asarray(b)
    return math.degrees(math.acos(float(np.clip(np.dot(a,b)/(np.linalg.norm(a)*np.linalg.norm(b)),-1,1))))


def observe(spec,points,joints,head_forward,torso_forward,scarf_hits,faces=None,pauldron_hits=None):
    q={k:np.asarray(v,float) for k,v in points.items()};j={k:np.asarray(v,float) for k,v in joints.items()}
    p=spec['pose'];m=spec['mq16']['falchion'];eps=NATIVE_DEFAULTS['position_tolerance_m']
    angle_eps=NATIVE_DEFAULTS['angle_tolerance_degrees'];ratio_eps=NATIVE_DEFAULTS['ratio_tolerance']
    feet={s:float(q['sabatons_'+s+'_render'][:,2].min()) for s in ('near','far')}
    floor=min(feet.values());L=float(np.mean([j['hip_'+s][2]-floor for s in ('near','far')]))
    H=float(q['great_helm_render'][:,2].max()-floor)
    knee_angles={s:angle(j['knee_'+s]-j['hip_'+s],j['ankle_'+s]-j['knee_'+s]) for s in ('near','far')}
    near_elbow=angle(j['elbow_near']-j['shoulder_near'],j['hand_near']-j['elbow_near'])
    spine=j['head']-j['pelvis'];lean=math.degrees(math.atan2(spine[0],spine[2]))
    head=np.asarray(head_forward);torso=np.asarray(torso_forward)
    head_h=head.copy();head_h[2]=0;torso_h=torso.copy();torso_h[2]=0
    foot_span=(j['ankle_near'][1]-j['ankle_far'][1])/(j['shoulder_near'][1]-j['shoulder_far'][1])
    step=(j['ankle_near'][0]-j['ankle_far'][0])/L
    hand_offset=(j['hand_far']-j['hip_far'])/L
    vertices=q['falchion_render'];blade_count=m['blade_vertex_count'];samples=m['sweep_samples']
    tip=vertices[m['blade_tip_vertex']]
    grip_top=vertices[blade_count:blade_count+samples].mean(0)
    grip_bottom=vertices[blade_count+samples:blade_count+2*samples].mean(0)
    grip=(grip_top+grip_bottom)/2;direction=tip-grip;direction/=np.linalg.norm(direction)
    down=math.degrees(math.atan2(-direction[2],np.linalg.norm(direction[:2])))
    outward=math.degrees(math.atan2(-direction[1],direction[0]))
    pommel_start=m['pommel_vertex_start']
    pommel=vertices[pommel_start:]
    hand=q['gauntlet_far_render'];hand_low,hand_high=hand.min(0),hand.max(0)
    grip_inside=bool(np.all(grip>=hand_low-eps) and np.all(grip<=hand_high+eps))
    blade=blade_observation(spec,vertices,grip,direction,H)
    pauldron=pauldron_observation(spec,q,j,H,faces or {},pauldron_hits or {})
    checks={
        'knee_angles_within_brief':all(abs(v-p['knee_bend_degrees'])<=angle_eps for v in knee_angles.values()),
        'near_elbow_angle_within_brief':abs(near_elbow-p['near_elbow_bend_degrees'])<=angle_eps,
        'hip_lean_5_degrees':abs(lean-p['hip_lean_degrees'])<=angle_eps,
        'head_level_and_chest_facing':abs(head[2])<=eps and angle(head_h,torso_h)<=angle_eps,
        'near_foot_forward_half_step':abs(step-p['near_step_over_leg_length'])<=ratio_eps,
        'stance_width_1_25_shoulders':abs(foot_span-p['foot_span_over_shoulder_span'])<=ratio_eps,
        'far_hand_director_position':bool(np.allclose(hand_offset,[p['far_hand_forward_over_leg_length'],
                      -p['far_hand_outward_over_leg_length'],0],atol=ratio_eps,rtol=0)),
        'falchion_grip_through_fist':grip_inside and np.linalg.norm(grip-j['hand_far'])<=eps,
        'falchion_pommel_above_fist':float(pommel[:,2].max())>float(hand[:,2].max()) and grip_top[2]>grip[2],
        'falchion_tip_forward_of_far_foot':float(tip[0])>float(q['sabatons_far_render'][:,0].max()),
        'falchion_director_axis_angles':abs(down-p['blade_down_degrees'])<=angle_eps and abs(outward-p['blade_outward_degrees'])<=angle_eps,
        'falchion_tip_above_floor':tip[2]>floor,
        'scarf_covers_both_shoulders':set(scarf_hits)=={'near','far'} and all(scarf_hits.values())}
    checks.update(blade['checks']);checks.update(pauldron['checks'])
    return {'checks':{k:bool(v) for k,v in checks.items()},'feedback2':{'blade':blade,'pauldrons':pauldron},'joints_world':{k:v.tolist() for k,v in j.items()},'sole_min_z_m':feet,
        'observed':{'leg_length_m':L,'height_m':H,'knee_angles_degrees':knee_angles,
        'near_elbow_degrees':near_elbow,'hip_lean_degrees':lean,'stance_ratio':float(foot_span),
        'near_step_over_L':float(step),'far_hand_offset_over_L':hand_offset.tolist(),
        'blade_down_degrees':down,'blade_outward_degrees':outward,'blade_tip_clearance_over_H':float((tip[2]-floor)/H),
        'blade_tip_world':tip.tolist(),'grip_world':grip.tolist(),'edge_direction':blade['edge_direction'],
        'scarf_shoulder_hits':scarf_hits}}
