"""Measurements from opened native vertices and armature endpoints, never recipe vertices."""
import math
import numpy as np
from .forms import TOPOLOGY
from .garments import GARMENT_TOPOLOGY

NATIVE_DEFAULTS={'endpoint_tolerance_m':1e-4,'angular_tolerance_degrees':1.,
                 'normalized_position_tolerance':.01,'sole_tolerance_m':1e-5,'epsilon':1e-8}


def unit(v):
    v=np.asarray(v,float);return v/np.linalg.norm(v)


def angle(a,b):return math.degrees(math.acos(np.clip(np.dot(unit(a),unit(b)),-1,1)))


def contract(spec):
    p,d=spec['pose'],spec['dimensions'];rows={}
    def add(group,name,target,angular=False,minimum=False):rows[name]=(group,target,1. if angular else .01,minimum)
    for side in ('near','far'):add(1,'knee_bend_'+side,p['knee_bend_degrees'],True)
    add(1,'hip_lean',p['hip_lean_degrees'],True)
    add(1,'neck_additional_pitch',p['head_additional_pitch_degrees'],True)
    add(2,'ankle_span_over_shoulders',p['ankle_span_over_shoulders'])
    add(2,'near_step_over_L',p['near_step_over_L'])
    for name in ('fist_height_over_H','fist_forward_of_hip_over_L','fist_outward_of_hip_over_L'):
        add(3,name,p[name])
    add(3,'near_elbow_bend',p['near_elbow_bend_degrees'],True);add(3,'near_pole_outward',p['near_pole_outward_degrees'],True)
    for name in ('lantern_chain_over_H','lantern_body_height_over_H','lantern_width_over_H'):add(4,name,d[name])
    add(4,'lantern_vertical',0,True)
    add(5,'far_upper_out',p['far_upper_out_degrees'],True);add(5,'far_elbow_bend',p['far_elbow_bend_degrees'],True)
    add(5,'far_wrist_ahead_of_thigh_over_L',p['far_wrist_ahead_of_thigh_over_L'])
    for finger in range(4):
        add(5,'finger_'+str(finger)+'_length_over_H',p['far_finger_length_over_H'])
        for k in range(3):add(5,'finger_'+str(finger)+'_knuckle_'+str(k),p['far_finger_knuckle_degrees'],True)
    for side in ('near','far'):
        for name in ('upper','fore','thigh','shin'):add('volumes',name+'_'+side+'_diameter_over_H',d[name+'_diameter_over_H'])
        for name in ('elbow','knee'):add('volumes',name+'_'+side+'_cop_diameter_over_H',d['cop_diameter_over_H'])
        add('volumes','gauntlet_'+side+'_width_over_H',d['gauntlet_width_over_H'])
        add('volumes','sabatons_'+side+'_extension_over_H',d['sabatons_extension_over_H'])
    for name,key in [('chest_width_over_H','chest_width_over_H'),('hood_thickness_over_H','hood_thickness_over_H'),
                     ('mask_height_over_H','mask_height_over_H'),('lamp_width_over_H','lamp_width_over_H'),
                     ('lamp_height_over_H','lamp_height_over_H'),('lamp_depth_over_H','lamp_depth_over_H'),
                     ('cage_height_over_H','cage_height_over_H'),('cage_width_over_H','cage_width_over_H')]:add('volumes',name,d[key])
    add('volumes','lamp_outward',d['lamp_outward_degrees'],True)
    add('volumes','lamp_mantle_support_error_over_H',0)
    add('volumes','robe_thickness_over_H',d['robe_thickness_over_H'],minimum=True)
    for name in ('robe_hem_above_knee_over_L','robe_hem_below_midshin_over_L'):add('volumes',name,0)
    add('volumes','barrel_forward_lean',p['hip_lean_degrees'],True)
    add('volumes','cowl_roll_diameter_over_H',d['cowl_roll_diameter_over_H'])
    add('volumes','lamp_frame_diameter_over_H',d['lamp_frame_diameter_over_H'])
    add('volumes','lamp_mullion_diameter_over_H',d['lamp_frame_diameter_over_H'])
    for side in ('near','far'):
        for finger in [*range(4),'thumb']:
            name='finger_'+side+'_'+str(finger) if finger!='thumb' else 'thumb_'+side
            add('volumes',name+'_thickness_over_H',d['claw_thickness_over_H'])
            add('volumes',name+'_length_over_H',d['claw_length_over_H'])
    return rows


def observe(spec,points,joints):
    points={n.removesuffix('_render'):np.asarray(v,float) for n,v in points.items()};j={n:np.asarray(v,float) for n,v in joints.items()}
    soles={s:float(points['pointed_sabaton_'+s][:,2].min()) for s in ('near','far')}
    H=float(max(points[n][:,2].max() for n in ('draped_hood','cowl_rolled_edge'))-min(soles.values()))
    L=float(np.mean([np.linalg.norm(j['hip_'+s]-[j['ankle_'+s][0],j['ankle_'+s][1],soles[s]]) for s in ('near','far')]))
    values={}
    def put(name,value):values[name]=float(value)
    for side in ('near','far'):
        put('knee_bend_'+side,angle(j['knee_'+side]-j['hip_'+side],j['ankle_'+side]-j['knee_'+side]))
    torso=j['head']-j['torso'];head=j['head_tip']-j['head']
    put('hip_lean',math.degrees(math.atan2(torso[0],torso[2])))
    put('neck_additional_pitch',math.degrees(math.atan2(head[0],head[2]))-values['hip_lean'])
    put('ankle_span_over_shoulders',abs(j['ankle_near'][1]-j['ankle_far'][1])/abs(j['shoulder_near'][1]-j['shoulder_far'][1]))
    put('near_step_over_L',(j['ankle_near'][0]-j['ankle_far'][0])/L)
    hand=j['hand_near'];hip=j['hip_near']
    for name,v in [('fist_height_over_H',hand[2]/H),('fist_forward_of_hip_over_L',(hand[0]-hip[0])/L),('fist_outward_of_hip_over_L',(hand[1]-hip[1])/L)]:put(name,v)
    for side in ('near','far'):
        put(side+'_elbow_bend',angle(j['elbow_'+side]-j['shoulder_'+side],j['hand_'+side]-j['elbow_'+side]))
    pole=j['pole_near_tip']-j['pole_near_root'];put('near_pole_outward',math.degrees(math.atan2(pole[1],-pole[2])))
    put('far_upper_out',math.degrees(math.asin(abs(unit(j['elbow_far']-j['shoulder_far'])[1]))))
    put('far_wrist_ahead_of_thigh_over_L',(j['hand_far'][0]-points['thigh_plate_far'][:,0].max())/L)
    for finger in range(4):
        path=points['finger_far_'+str(finger)].reshape(-1,TOPOLOGY['sweep_samples'],3).mean(1);directions=np.diff(path,axis=0)
        put('finger_'+str(finger)+'_length_over_H',np.linalg.norm(directions,axis=1).sum()/H)
        for k in range(3):put('finger_'+str(finger)+'_knuckle_'+str(k),angle(directions[k],directions[k+1]))
    ring_counts={}
    for side in ('near','far'):
        for name,a,b in [('upper','shoulder','elbow'),('fore','elbow','hand'),('thigh','hip','knee'),('shin','knee','ankle')]:
            v=points[name+'_plate_'+side];axis=unit(j[b+'_'+side]-j[a+'_'+side]);first=unit(np.cross(axis,[0,1,0]));second=np.cross(axis,first)
            rings=v.reshape(-1,TOPOLOGY['ring_samples'],3);means=rings.mean(1);radii=np.linalg.norm(rings-means[:,None,:],axis=2).mean(1)
            put(name+'_'+side+'_diameter_over_H',max(np.ptp(np.einsum('nj,j->n',v,first)),np.ptp(np.einsum('nj,j->n',v,second)))/H)
            ring_counts[name+'_'+side]=len(v)//(6*TOPOLOGY['ring_samples'])
        for name in ('elbow','knee'):put(name+'_'+side+'_cop_diameter_over_H',np.ptp(points[name+'_cop_'+side],axis=0).max()/H)
        put('gauntlet_'+side+'_width_over_H',np.ptp(points['gauntlet_'+side][:,1])/H)
        put('sabatons_'+side+'_extension_over_H',(points['pointed_sabaton_'+side][:,0].max()-j['foot_tip_'+side][0])/H)
    put('chest_width_over_H',np.ptp(points['iron_barrel'][:,1])/H)
    thickness={}
    for label,name in [('hood','draped_hood'),('robe','tattered_robe')]:
        a=points[name];n=len(a)//2;thick=np.linalg.norm(a[:n]-a[n:],axis=1)
        thickness[label]={'minimum_m':float(thick.min()),'maximum_m':float(thick.max())}
        put(label+'_thickness_over_H',thick.min()/H)
    pitch=math.radians(spec['pose']['hip_lean_degrees']+spec['pose']['head_additional_pitch_degrees']);up=np.array([math.sin(pitch),0,math.cos(pitch)])
    put('mask_height_over_H',np.ptp(np.einsum('nj,j->n',points['convex_mask'],up))/H)
    # Native roof/floor and frame recover the box's own axes, independent of
    # its stored authored rotation. Ring-centre edges supply its outward tilt.
    roof=points['lamp_roof'];floor=points['lamp_floor'];lamp_up=unit(roof.mean(0)-floor.mean(0));lamp_y=unit(np.cross(lamp_up,[1,0,0]));lamp_x=np.array([1,0,0])
    lamp=np.concatenate([points[n] for n in ('rounded_lamp_frame','lamp_roof','lamp_floor')])
    for name,axis in [('width',lamp_y),('height',lamp_up),('depth',lamp_x)]:put('lamp_'+name+'_over_H',np.ptp(np.einsum('nj,j->n',lamp,axis))/H)
    put('lamp_outward',math.degrees(math.atan2(-lamp_up[1],lamp_up[2])))
    floor_centre=floor.mean(0);mantle=points['shoulder_mantle']
    local=np.column_stack([np.einsum('nj,j->n',mantle-floor_centre,a) for a in (lamp_x,lamp_y,lamp_up)])
    wire=spec['dimensions']['lamp_frame_diameter_over_H']*H/2
    supported=(abs(local[:,0])<values['lamp_depth_over_H']*H/2-wire)&(abs(local[:,1])<values['lamp_width_over_H']*H/2-wire)
    put('lamp_mantle_support_error_over_H',abs(local[supported,2].max()+wire/2)/H)
    cage=points['curved_birdcage'];put('cage_height_over_H',np.ptp(cage[:,2])/H);put('cage_width_over_H',max(np.ptp(cage[:,0]),np.ptp(cage[:,1]))/H)
    robe=points['tattered_robe'];n=len(robe)//2;mid=(robe[:n]+robe[n:])/2
    hem=mid[-GARMENT_TOPOLOGY['columns']:]
    tears=int(sum(hem[k,2]>hem[k-1,2] and hem[k,2]>hem[k+1,2] for k in range(1,len(hem)-1)))
    # Held union starts with the native chain; recover endpoints from its
    # actual linked sweeps rather than the authored chain target joint.
    held=points['held_lantern'];link_vertices=25*TOPOLOGY['sweep_samples'];chain_points=held[:6*link_vertices]
    put('lantern_chain_over_H',(chain_points[:,2].max()-chain_points[:,2].min())/H)
    # Hex posts follow the ring (25 sweep stations), six straight post sweeps.
    post_start=6*link_vertices+25*TOPOLOGY['sweep_samples']
    post=held[post_start:post_start+6*2*TOPOLOGY['sweep_samples']].reshape(6,2,TOPOLOGY['sweep_samples'],3).mean(2)
    post_bottom=post[:,0].mean(0);post_top=post[:,1].mean(0);lantern_up=unit(post_top-post_bottom)
    put('lantern_vertical',angle(lantern_up,[0,0,1]))
    bottom_z=post_bottom[2]-spec['source_calipers']['chain_wire_px']*spec['mq18']['source_unit_m_per_px']
    put('lantern_body_height_over_H',(chain_points[:,2].min()-bottom_z)/H)
    put('lantern_width_over_H',max(np.linalg.norm(a-b) for a in post[:,0] for b in post[:,0])/H)
    from .feedback_checks import feedback_values
    feedback,feedback_gates,details=feedback_values(spec,points,j,H,L);values.update(feedback)
    rows=[]
    for name,(group,target,tolerance,minimum) in contract(spec).items():
        measured=values[name];passed=math.isfinite(measured) and (measured>=target-1e-6 if minimum else abs(measured-target)<=tolerance)
        rows.append({'requirement':group,'name':name,'target':target,'measured':measured,'tolerance':tolerance,'minimum':minimum,'passed':bool(passed)})
    counts={'lamp_panes_per_face':len(points['lamp_panes'])//8//4,
        'lamp_cross_mullions_per_face':len(points['lamp_cross_mullions'])//(2*TOPOLOGY['sweep_samples'])//4,
        'birdcage_collar_chains':sum(n.startswith('collar_chain_') for n in points),
        'belt_hanging_chains':sum(n.startswith('belt_chain_') for n in points),
        'belt_keys':sum(n.startswith('key_') for n in points)}
    angles=np.sort(np.arctan2(post[:,0,1]-post_bottom[1],post[:,0,0]-post_bottom[0]))
    hex_angles=np.degrees(np.diff(np.r_[angles,angles[0]+math.tau]))
    mantle=points['shoulder_mantle']
    mantle_covers=all(mantle[:,1].min()<j['shoulder_'+s][1]<mantle[:,1].max() and
                      mantle[:,2].min()<j['shoulder_'+s][2]<mantle[:,2].max() for s in ('near','far'))
    checks={'values_within_tolerance':all(r['passed'] for r in rows),
        'both_feet_planted':all(abs(z)<NATIVE_DEFAULTS['sole_tolerance_m'] for z in soles.values()),
        'level_shoulders':abs(j['shoulder_near'][2]-j['shoulder_far'][2])<NATIVE_DEFAULTS['endpoint_tolerance_m'],
        'near_elbow_not_forward':j['elbow_near'][0]<=j['shoulder_near'][0]+NATIVE_DEFAULTS['endpoint_tolerance_m'],
        'forearms_fold_forward':all((unit(j['hand_'+s]-j['elbow_'+s])-unit(j['elbow_'+s]-j['shoulder_'+s]))[0]>0 for s in ('far',)),
        'near_forearm_outward':j['hand_near'][1]>j['elbow_near'][1],
        'accessory_counts':counts=={'lamp_panes_per_face':4,'lamp_cross_mullions_per_face':2,'birdcage_collar_chains':2,'belt_hanging_chains':3,'belt_keys':2},
        'lantern_hexagonal':bool(np.allclose(hex_angles,60,atol=1)),
        'mantle_covers_both_shoulders':mantle_covers,
        'rounded_lames':all(2<=v<=3 for v in ring_counts.values()),'long_ragged_tears':tears>=spec['dimensions']['robe_tears_min'],
        'mask_convex_and_cross_cut':np.ptp(points['convex_mask'][:,0])>H*.01,
        'lantern_fist_pivot':np.linalg.norm(j['hand_near']-chain_points[chain_points[:,2].argmax()])<.01*L}
    c=spec['source_calipers'];proportions={name:{'source':value/c['brief_drawn_height_px'],'native':native/H} for name,value,native in
        [('hood_width',c['hood_width_px'],np.ptp(points['draped_hood'][:,1])),('chest_width',c['shoulder_width_px'],np.ptp(points['iron_barrel'][:,1])),
         ('shoulder_span',c['shoulder_width_px'],abs(j['shoulder_near'][1]-j['shoulder_far'][1])),('hip_to_sole',c['sole_y']-c['hip_y'],L),
         ('body_height',237,H),('mask_height',34,np.ptp(np.einsum('nj,j->n',points['convex_mask'],up)))]}
    checks.update(feedback_gates)
    checks={k:bool(v) for k,v in checks.items()}
    return {'passed':all(checks.values()),'checks':checks,'pose_values':rows,'height_m':H,'leg_length_m':L,
        'soles_m':soles,'lame_counts':ring_counts,'feedback1':details,'robe_tears':tears,'accessory_counts':counts,'lantern_hexagon_angles_degrees':hex_angles.tolist(),'cloth_thickness':thickness,'proportions':proportions}


def valid_rows(spec,rows):
    expected=contract(spec)
    if len(rows)!=len(expected) or {r.get('name') for r in rows}!=set(expected):return False
    for r in rows:
        group,target,tol,minimum=expected[r['name']];v=r.get('measured')
        if type(v) not in (int,float) or not math.isfinite(v) or r.get('target')!=target or r.get('requirement')!=group or r.get('tolerance')!=tol or r.get('minimum')!=minimum:return False
        if r.get('passed') is not True or (v<target-1e-6 if minimum else abs(v-target)>tol):return False
    return True
