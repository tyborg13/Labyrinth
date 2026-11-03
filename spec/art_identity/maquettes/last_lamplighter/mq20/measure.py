"""Measure mq-20 from supplied geometry, including opened native meshes.

Recipe arrays are used only by headless source tests; the bridge probe supplies
the opened vertices, polygons and actual armature endpoints independently.
"""
import math
import numpy as np
from ..native_checks import angle,unit,NATIVE_DEFAULTS
from ..forms import TOPOLOGY
from .geometry import lantern_clearance,lantern_overlap


def observe(spec,points,joints,faces):
    points={n.removesuffix('_render'):np.asarray(v,float) for n,v in points.items()}
    faces={n.removesuffix('_render'):v for n,v in faces.items()};j={n:np.asarray(v,float) for n,v in joints.items()}
    d=spec['dimensions'];p=spec['pose'];rows=[];checks={};pending=spec['mq20']['design_pending']
    soles={s:float(points['pointed_sabaton_'+s][:,2].min()) for s in ('near','far')}
    H=max(points[n][:,2].max() for n in ('draped_hood','cowl_rolled_edge'))-min(soles.values())
    L=np.mean([np.linalg.norm(j['hip_'+s]-[j['ankle_'+s][0],j['ankle_'+s][1],soles[s]]) for s in ('near','far')])
    def row(group,name,measured,target,angular=False,minimum=False):
        tol=NATIVE_DEFAULTS['angular_tolerance_degrees' if angular else 'normalized_position_tolerance']
        good=math.isfinite(measured) and (measured>=target-tol if minimum else abs(measured-target)<=tol)
        rows.append({'requirement':group,'name':name,'target':target,'measured':float(measured),'tolerance':tol,'minimum':minimum,'passed':bool(good)})
    for side in ('near','far'):
        row(2,'knee_bend_'+side,angle(j['knee_'+side]-j['hip_'+side],j['ankle_'+side]-j['knee_'+side]),p['knee_bend_'+side+'_degrees'],True)
        row(3 if side=='near' else 5,side+'_elbow_bend',angle(j['elbow_'+side]-j['shoulder_'+side],j['hand_'+side]-j['elbow_'+side]),p[side+'_elbow_bend_degrees'],True)
    barrel=points['iron_barrel'].reshape(-1,48,3).mean(1);axis=barrel[-1]-barrel[0]
    lean=math.degrees(math.atan2(axis[0],axis[2]));row(1,'hip_lean',lean,p['hip_lean_degrees'],True)
    mask=points['convex_mask'];eigen,vectors=np.linalg.eigh(np.cov(mask.T));up=vectors[:,np.argmax(eigen)]
    if up[2]<0:up=-up
    row(1,'head_additional_pitch',math.degrees(math.atan2(up[0],up[2]))-lean,p['head_additional_pitch_degrees'],True)
    row(2,'ankle_span_over_shoulders',abs(j['ankle_near'][1]-j['ankle_far'][1])/abs(j['shoulder_near'][1]-j['shoulder_far'][1]),p['ankle_span_over_shoulders'])
    row(2,'near_step_over_L',(j['ankle_near'][0]-j['ankle_far'][0])/L,p['near_step_over_L'])
    for name,value in [('fist_height_over_H',j['hand_near'][2]/H),('fist_forward_of_hip_over_L',(j['hand_near'][0]-j['hip_near'][0])/L),('fist_outward_of_hip_over_L',(j['hand_near'][1]-j['hip_near'][1])/L)]:row(3,name,value,p[name])
    pole=j['pole_near_tip']-j['pole_near_root'];row(3,'near_pole_outward',math.degrees(math.atan2(pole[1],-pole[2])),p['near_pole_outward_degrees'],True)
    row(5,'far_upper_out',math.degrees(math.asin(abs(unit(j['elbow_far']-j['shoulder_far'])[1]))),p['far_upper_out_degrees'],True)
    row(5,'far_wrist_ahead_of_thigh_over_L',(j['hand_far'][0]-points['thigh_plate_far'][:,0].max())/L,p['far_wrist_ahead_of_thigh_over_L'])
    for finger in range(4):
        path=points['finger_far_'+str(finger)].reshape(-1,TOPOLOGY['sweep_samples'],3).mean(1);directions=np.diff(path,axis=0)
        row(5,f'finger_{finger}_length_over_H',np.linalg.norm(directions,axis=1).sum()/H,p['far_finger_length_over_H'])
        for k in range(3):row(5,f'finger_{finger}_knuckle_{k}',angle(directions[k],directions[k+1]),p['far_finger_knuckle_degrees'],True)
    thumb=points['thumb_far'].reshape(-1,TOPOLOGY['sweep_samples'],3).mean(1);directions=np.diff(thumb,axis=0)
    row(5,'thumb_far_length_over_H',np.linalg.norm(directions,axis=1).sum()/H,p['far_finger_length_over_H'])
    row(5,'thumb_far_knuckle',angle(directions[0],directions[1]),p['far_finger_knuckle_degrees'],True)
    for side in ('near','far'):
        for name in [*[f'finger_{side}_{k}' for k in range(4)],'thumb_'+side]:
            rings=points[name].reshape(-1,TOPOLOGY['sweep_samples'],3);centres=rings.mean(1)
            row('volumes',name+'_thickness_over_H',2*np.linalg.norm(rings-centres[:,None],axis=2).mean()/H,d['claw_thickness_over_H'])
            if side=='near':
                grip=spec['mq20']['design_values'].get('lantern_grip')
                # The accepted director paths supersede the old generic claw
                # length. Measure those paths independently in opened meshes.
                path=(grip['thumb_path_over_H'] if name=='thumb_near' else grip['finger_paths_over_H'][int(name[-1])]) if grip else None
                target=np.linalg.norm(np.diff(path,axis=0),axis=1).sum() if path is not None else d['claw_length_over_H']
                row('volumes',name+'_length_over_H',np.linalg.norm(np.diff(centres,axis=0),axis=1).sum()/H,target)
    cap=points['lantern_cap'];base=points['lantern_base'];chain=points['held_chain']
    row(4,'lantern_chain_over_H',np.ptp(chain[:,2])/H,d['lantern_chain_over_H'])
    row(4,'lantern_body_height_over_H',(cap[:,2].max()-base[:,2].min())/H,d['lantern_body_height_over_H'])
    row(4,'lantern_width_over_H',max(np.linalg.norm(a[:2]-b[:2]) for a in base[:6] for b in base[:6])/H,d['lantern_width_over_H'])
    row(4,'lantern_vertical',angle(cap[-1]-base.mean(0),[0,0,1]),0,True)
    link_centres=chain.reshape(-1,25,TOPOLOGY['sweep_samples'],3).mean((1,2))
    row(4,'chain_vertical',angle(link_centres[-1]-link_centres[0],[0,0,-1]),0,True)
    centre=base[:6].mean(0);angles=np.sort(np.arctan2(base[:6,1]-centre[1],base[:6,0]-centre[0]))
    checks['lantern_hexagonal']=bool(np.allclose(np.degrees(np.diff(np.r_[angles,angles[0]+math.tau])),60,atol=1))
    checks['six_glass_panes']=sum(n.startswith('lantern_pane_') for n in points)==d['lantern_sides']
    checks['candle_inside_lantern']=points['candle'][:,2].min()>base[:,2].min() and points['candle_glow'][:,2].max()<cap[:,2].max()
    if 'grip_ring' in points:
        ring=points['grip_ring'].reshape(-1,TOPOLOGY['sweep_samples'],3).mean(1)
        checks['top_ring_at_fist']=np.linalg.norm(ring[:-1].mean(0)-j['hand_near'])<=.01*L
        grip=spec['mq20']['design_values']['lantern_grip'];normal=0 if grip['ring_plane']=='yz' else 1
        transverse=[a for a in range(3) if a!=normal];radius=grip['ring_radius_over_H']*H
        through=[]
        for finger in range(4):
            path=points['finger_near_'+str(finger)].reshape(-1,TOPOLOGY['sweep_samples'],3).mean(1)-j['hand_near']
            hits=[]
            for a,b in zip(path,path[1:]):
                if a[normal]*b[normal]<=0 and abs(b[normal]-a[normal])>1e-9:
                    crossing=a+(b-a)*(-a[normal]/(b[normal]-a[normal]));hits.append(np.linalg.norm(crossing[transverse])<radius)
            through.append(any(hits))
        checks['fingers_wrapped_through_top_ring']=all(through)
    else:checks['top_ring_at_fist']=False;checks['fingers_wrapped_through_top_ring']=False
    clearance=lantern_clearance(spec,points,H)
    # Clearance is a strict lower bound, not a target with symmetric tolerance.
    policy=spec['mq20']['design_values'].get('lantern_leg_clearance_resolution',{})
    if policy.get('selected',{}).get('mode')=='depth_overlap':
        fallback=policy['fallback'];overlap=lantern_overlap(spec,points,faces,H);clearance['overlap']=overlap
        checks['authorized_overlap_pose']=(p['ankle_span_over_shoulders']==fallback['stance'] and p['fist_outward_of_hip_over_L']==fallback['fist_outward_over_L'])
        checks['lantern_overlap_share']=overlap['overlap_share']<=fallback['maximum_overlap_share']
        checks['lantern_in_front_of_near_leg']=overlap['lantern_in_front']
    else:checks['lantern_leg_clearance']=clearance['minimum_over_H']>=d['lantern_leg_clearance_over_H_min']
    for side in ('near','far'):
        for name,a,b in [('upper','shoulder','elbow'),('fore','elbow','hand'),('thigh','hip','knee'),('shin','knee','ankle')]:
            v=points[name+'_plate_'+side];direction=unit(j[b+'_'+side]-j[a+'_'+side]);lateral=unit(np.cross(direction,[0,1,0]));other=np.cross(direction,lateral)
            row('volumes',name+'_'+side+'_diameter_over_H',max(np.ptp(np.einsum('nj,j->n',v,lateral)),np.ptp(np.einsum('nj,j->n',v,other)))/H,d[name+'_diameter_over_H'])
        for name in ('elbow','knee'):row('volumes',name+'_cop_'+side,np.ptp(points[name+'_cop_'+side],axis=0).max()/H,d['cop_diameter_over_H'])
        row('volumes','gauntlet_'+side+'_width_over_H',np.ptp(points['gauntlet_'+side][:,1])/H,d['gauntlet_width_over_H'])
        row('volumes','sabatons_'+side+'_extension_over_H',(points['pointed_sabaton_'+side][:,0].max()-j['foot_tip_'+side][0])/H,d['sabatons_extension_over_H'])
    row('volumes','chest_width_over_H',np.ptp(points['iron_barrel'][:,1])/H,d['chest_width_over_H'])
    mask_height=np.ptp(np.einsum('nj,j->n',mask,up))/H
    row('volumes','mask_height_over_H',mask_height,d['mask_height_over_H'])
    c=spec['source_calipers']
    proportions={name:{'source':source/c['brief_drawn_height_px'],'native':float(measured)} for name,source,measured in [
        ('hood_width',c['hood_width_px'],np.ptp(points['draped_hood'][:,1])/H),('chest_width',c['shoulder_width_px'],np.ptp(points['iron_barrel'][:,1])/H),
        ('shoulder_span',c['shoulder_width_px'],abs(j['shoulder_near'][1]-j['shoulder_far'][1])/H),
        ('hip_to_sole',c['sole_y']-c['hip_y'],L/H),('body_height',c['brief_drawn_height_px'],1.),('mask_height',34,mask_height)]}
    from .surface_checks import observe as surfaces
    detail=surfaces(spec,points,faces,j,H,L,row,checks)
    checks.update(design_resolved=not pending,values_within_tolerance=all(r['passed'] for r in rows),
        both_feet_planted=all(abs(z)<=NATIVE_DEFAULTS['sole_tolerance_m'] for z in soles.values()),
        shoulders_level=abs(j['shoulder_near'][2]-j['shoulder_far'][2])<=NATIVE_DEFAULTS['endpoint_tolerance_m'],
        near_elbow_not_forward=j['elbow_near'][0]<=j['shoulder_near'][0]+NATIVE_DEFAULTS['endpoint_tolerance_m'],
        mask_faces_chest=abs(up[1])<=math.sin(math.radians(NATIVE_DEFAULTS['angular_tolerance_degrees'])),
        lamp_house_removed='lamp_house' not in spec['labels'] and all(q['part']!='lamp_house' for q in spec['pieces']),
        rigid_lantern=all(q.get('rig_bone')=='hand_near' and q.get('rig_pivot_joint')=='hand_near' for q in spec['pieces'] if q['part']=='lantern'))
    return {'passed':all(checks.values()),'checks':{k:bool(v) for k,v in checks.items()},'pose_values':rows,
        'height_m':float(H),'leg_length_m':float(L),'soles_m':soles,'clearance':clearance,'surfaces':detail,'proportions':proportions,'design_pending':pending}
