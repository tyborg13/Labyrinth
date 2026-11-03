"""Independent pinned gates for supplied source or opened-native geometry.

Generator dimensions, paths, lengths and annotations are never acceptance
targets. Topology controls and all targets come from contract.json; retained
shapes and joints come from the separately hash-pinned mq-20 measurement file.
"""
import numpy as np
from spec.art_identity.maquettes.raster import camera
from .oracle import contract,baseline,changed_piece,angle,digit_path,limb_length,same_faces,outward_faces,consistent_shell_faces,round1
from .contact import ring_fist,thumb_contact


def palm_axes(vertices):
    # Inherited oval topology: 13 meridians, 24 samples, first/last poles.
    rings=np.asarray(vertices).reshape(13,24,3);centres=rings.mean(1)
    longitudinal=centres[-1]-centres[0];length=np.linalg.norm(longitudinal)
    normal=rings[6,0]-centres[6];depth=2*np.linalg.norm(normal)
    lateral=rings[6,6]-centres[6];width=2*np.linalg.norm(lateral)
    return np.array([normal/(depth/2),lateral/(width/2),longitudinal/length]),length,width


def mantle_metrics(vertices,joints,H,c):
    nr=c['measurement']['mantle_rows'];nc=c['measurement']['mantle_columns']
    p=np.asarray(vertices,float)
    if p.shape!=(2*nr*nc,3):raise ValueError('Mantle topology differs from pinned contract')
    rows=((p[:nr*nc]+p[nr*nc:])/2).reshape(nr,nc,3);hem=rows[-1]
    result={}
    for side,sign in (('near',1),('far',-1)):
        shoulder=np.asarray(joints['shoulder_'+side]);selected=np.flatnonzero(sign*hem[:,1]>=sign*shoulder[1])
        if len(selected)<3:raise ValueError('Mantle does not drape outside '+side+' arm')
        z=hem[selected,2];minima=[k for k in range(1,len(z)-1) if z[k]<z[k-1] and z[k]<z[k+1]]
        maxima=[0]+[k for k in range(1,len(z)-1) if z[k]>z[k-1] and z[k]>z[k+1]]+[len(z)-1]
        lengths=[];kept=[]
        for k in minima:
            left=max(q for q in maxima if q<k);right=min(q for q in maxima if q>k)
            length=float((min(z[left],z[right])-z[k])/H)
            if length>c['measurement']['position_tolerance_over_H']:lengths.append(length);kept.append(k)
        result[side]={'drop_over_H':float((shoulder[2]-max(z))/H),'hem_points':len(kept),'point_lengths_over_H':lengths}
    return result


def observe(points,faces,joints,owners,pending=(),opened_native=False):
    c=contract();old=baseline();tol=c['measurement']['position_tolerance_over_H'];metric=c['measurement']['metric_tolerance_over_H']
    angular=c['measurement']['angle_tolerance_degrees'];points={n.removesuffix('_render'):np.asarray(v,float) for n,v in points.items()}
    faces={n.removesuffix('_render'):v for n,v in faces.items()};owners={n.removesuffix('_render'):v for n,v in owners.items()}
    rows=[];checks={};details={};errors=[]
    def row(name,value,target,tolerance=metric):
        good=np.isfinite(value) and abs(value-target)<=tolerance
        rows.append({'name':name,'measured':float(value) if np.isfinite(value) else None,'target':target,'tolerance':tolerance,'passed':bool(good)})
    soles=[points['pointed_sabaton_'+s][:,2].min() for s in ('near','far')]
    H=float(max(points[n][:,2].max() for n in ('draped_hood','cowl_rolled_edge'))-min(soles))
    checks['no_pauldrons']=not any('pauldron' in n or str(owners.get(n,{}).get('part','')).startswith('pauldron') for n in points)
    bone_joints={b[k] for b in old['armature']['bones'] for k in ('head','tail')}
    checks['joint_inventory']=bone_joints<=set(joints)
    checks['joints_preserved']=checks['joint_inventory'] and all(np.linalg.norm(np.asarray(joints[n])-old['joints'][n])<=tol*H for n in bone_joints)
    retained=[p for p in old['pieces'] if not changed_piece(p)]
    reference_faces={p['id']:outward_faces(p['vertices'],p['faces']) if opened_native else p['faces'] for p in retained}
    checks['retained_geometry']=all(p['id'] in points and points[p['id']].shape==np.shape(p['vertices']) and
        np.max(abs(points[p['id']]-p['vertices']))<=tol*H and same_faces(faces.get(p['id']),reference_faces[p['id']]) for p in retained)
    details['retained_differences']=[{'piece':p['id'],'max_vertex_error_over_H':float(np.max(abs(points[p['id']]-p['vertices']))/H) if p['id'] in points and points[p['id']].shape==np.shape(p['vertices']) else None,
        'faces_equal':same_faces(faces.get(p['id']),reference_faces[p['id']])} for p in retained if p['id'] not in points or points[p['id']].shape!=np.shape(p['vertices']) or np.max(abs(points[p['id']]-p['vertices']))>tol*H or not same_faces(faces.get(p['id']),reference_faces[p['id']])]
    allowed={p['id'] for p in retained}|{'shoulder_mantle'}|{'palm_'+s for s in ('near','far')}|{'thumb_'+s for s in ('near','far')}|{
        'finger_'+s+'_'+str(k) for s in ('near','far') for k in range(4)}
    checks['object_inventory']=set(points)==allowed
    hood=np.concatenate([points[n] for n in ('draped_hood','cowl_rolled_edge')]);hood_y=hood[:,1].min(),hood[:,1].max()
    torso=[points[n] for n,o in owners.items() if o.get('rig_bone')=='torso']
    checks['nothing_rises_beside_hood']=all(not np.any((v[:,2]>H-c['shoulders']['hood_top_exclusion_over_H']*H)&
        ((v[:,1]<hood_y[0])|(v[:,1]>hood_y[1]))) for v in torso)
    checks['mantle_owner']=owners.get('shoulder_mantle',{}).get('part')=='torso' and owners.get('shoulder_mantle',{}).get('rig_bone')=='torso'
    approved=round1()['mantle'];expected=consistent_shell_faces(approved['vertices'],approved['faces']) if opened_native else approved['faces']
    checks['round1_mantle_preserved']=np.asarray(points['shoulder_mantle']).shape==np.shape(approved['vertices']) and np.max(abs(points['shoulder_mantle']-approved['vertices']))<=tol*H and same_faces(faces['shoulder_mantle'],expected)
    length_rows=[]
    for name,target in c['baseline']['limb_lengths_m'].items():
        try:value=limb_length(points[name],c)
        except (KeyError,ValueError):value=float('nan')
        ratio=value/target;row(name+'_length_ratio',ratio,c['limb_ratio']['target'],c['limb_ratio']['tolerance'])
        length_rows.append({'piece':name,'mq20_m':target,'mq24_m':float(value) if np.isfinite(value) else None,'ratio':float(ratio) if np.isfinite(ratio) else None,'passed':rows[-1]['passed']})
    try:
        mantle=mantle_metrics(points['shoulder_mantle'],joints,H,c);details['mantle']=mantle
        for side,observed in mantle.items():
            row('mantle_'+side+'_drop',observed['drop_over_H'],c['shoulders']['mantle_drop_over_H'])
            checks['mantle_'+side+'_points']=c['shoulders']['hem_points_per_side'][0]<=observed['hem_points']<=c['shoulders']['hem_points_per_side'][1]
            checks['mantle_'+side+'_point_lengths']=all(c['shoulders']['hem_point_length_over_H'][0]-metric<=v<=c['shoulders']['hem_point_length_over_H'][1]+metric for v in observed['point_lengths_over_H'])
    except (KeyError,ValueError) as error:checks['mantle_geometry']=False;errors.append(str(error))
    _,_,basis,_=camera(old,'front');far_tips=[];far_directions=[];near_paths=[]
    for side in ('far','near'):
        policy=c[side+'_hand'];part=policy['rig_part'];pointed=side=='far'
        try:
            axes,length,width=palm_axes(points['palm_'+side])
            if side=='far':row('far_palm_length',length/H,policy['palm_length_over_H']);row('far_palm_width',width/H,policy['palm_width_over_H'])
            for k in range(policy['fingers']):
                name='finger_'+side+'_'+str(k);path,radii=digit_path(points[name],policy['segments'],pointed,c['measurement']['sweep_samples'])
                direction=np.diff(path,axis=0);checks[name+'_owner']=owners.get(name,{}).get('part')==part and owners.get(name,{}).get('rig_bone')==part
                local=direction@axes.T
                # The MCP curl is relative to the palm plane; subsequent
                # knuckles are the angles between physical segment axes.
                curls=[float(np.degrees(np.arctan2(local[0,0],np.linalg.norm(local[0,1:]))))]+[angle(a,b) for a,b in zip(direction,direction[1:])]
                if pointed:
                    row(name+'_length',np.linalg.norm(direction,axis=1).sum()/H,policy['length_over_H'])
                    row(name+'_base_thickness',2*radii[0]/H,policy['base_thickness_over_H'])
                    checks[name+'_tapers']=bool(np.all(np.diff(radii)<0))
                    for q,value in enumerate(curls):row(name+'_knuckle_'+str(q),value,policy['knuckle_degrees'],angular)
                    far_tips.append(path[-1]);far_directions.append(local[0])
                else:
                    checks[name+'_knuckles']=all(policy['knuckle_degrees'][0]-angular<=v<=policy['knuckle_degrees'][1]+angular for v in curls)
                    near_paths.append(path)
            thumb_segments=policy['thumb_segments'] if pointed else len(points['thumb_near'])//c['measurement']['sweep_samples']-1
            if thumb_segments<1:raise ValueError('Near thumb needs an owner-authored path')
            thumb,radii=digit_path(points['thumb_'+side],thumb_segments,pointed,c['measurement']['sweep_samples'])
            checks['thumb_'+side+'_owner']=owners.get('thumb_'+side,{}).get('part')==part and owners.get('thumb_'+side,{}).get('rig_bone')==part
            checks['palm_'+side+'_owner']=owners.get('palm_'+side,{}).get('part')==part and owners.get('palm_'+side,{}).get('rig_bone')==part
            if pointed:
                row('far_thumb_length',np.linalg.norm(np.diff(thumb,axis=0),axis=1).sum()/H,policy['thumb_length_over_H'])
                row('far_thumb_knuckle',angle(thumb[1]-thumb[0],thumb[2]-thumb[1]),policy.get('thumb_knuckle_degrees',policy['knuckle_degrees']),angular)
                local=(thumb[1]-thumb[0])@axes.T
                row('far_thumb_inward_angle',angle(local[1:],far_directions[0][1:]),policy['thumb_inward_degrees'],angular)
                checks['far_thumb_opposed']=local[1]*far_directions[0][1]<0
            else:
                fingers=np.concatenate(near_paths);checks['near_thumb_front']=float(np.dot(thumb.mean(0)-fingers.mean(0),basis[2]))>0
                details['knuckle_row_above_ring_centre']=bool(min(p[0,2] for p in near_paths)>np.asarray(points['grip_ring'])[:,2].mean())
        except (KeyError,ValueError,IndexError) as error:checks[side+'_hand_geometry']=False;errors.append(side+': '+str(error))
    if len(far_directions)==4:
        fan=np.degrees(np.arctan2(np.asarray(far_directions)[:,1],np.asarray(far_directions)[:,2]))
        for k,value in enumerate(abs(np.diff(fan))):row('fan_'+str(k),value,c['far_hand']['fan_degrees'],angular)
        projected=np.asarray(far_tips)@basis[:2].T
        gap=min(np.linalg.norm(a-b) for k,a in enumerate(projected) for b in projected[k+1:])/H
        details['minimum_front_tip_gap_over_H']=float(gap);checks['front_claw_tip_separation']=gap>=c['far_hand']['minimum_front_tip_gap_over_H']
    if len(near_paths)==4:
        try:
            contact=ring_fist(points,faces,near_paths,basis,H,c);details['ring_fist']=contact
            # mq-25 ratifies the existing contact. Signed crossings and exact
            # wire distance remain in ring_fist diagnostics, never gates.
            checks['fingertips_close_to_palm']=all(value<=c['near_hand']['maximum_fingertip_palm_distance_over_H']+metric for value in contact['fingertip_palm_distances_over_H'])
            checks['ring_penetration']=contact['unintended_penetration_over_H']<=c['near_hand']['maximum_unintended_penetration_over_H']
            near_axes,_,_=palm_axes(points['palm_near']);thumb=thumb_contact(points,faces,near_paths,near_axes,basis,H);details['thumb_contact']=thumb
            checks['near_thumb_contact']=thumb['outside'] and c['near_hand']['thumb_contact_clearance_over_H'][0]-metric<=thumb['distal_cap_clearance_over_H']<=c['near_hand']['thumb_contact_clearance_over_H'][1]+metric
            checks['near_thumb_joint_limits']=all(-angular<=v<=c['near_hand']['thumb_joint_max_degrees']+angular for v in thumb['joint_curls_degrees'])
        except (KeyError,ValueError) as error:checks['ring_geometry']=False;errors.append(str(error))
    try:
        from .rule_measure import inspect as inspect_rules
        details['hand_pose']=inspect_rules(points,joints,H,c,row,checks)
    except (KeyError,ValueError) as error:checks['feedback1_rule_geometry']=False;errors.append(str(error))
    from .rest_clearance import inspect as inspect_clearance
    details['arm_clearance']=inspect_clearance(points,faces,c['measurement']['ray_epsilon'])
    checks['mantle_rest_pose_clear']=details['arm_clearance']['passed']
    checks['design_resolved']=not pending;checks['numeric_rows']=all(r['passed'] for r in rows)
    return {'passed':bool(all(checks.values())),'checks':{k:bool(v) for k,v in checks.items()},'rows':rows,
        'segment_lengths':length_rows,'height_m':H,'details':details,'errors':errors,'design_pending':list(pending)}
