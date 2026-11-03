"""Measure mq-21 world geometry, independently of construction bookkeeping."""
from collections import Counter
import math
import numpy as np
from spec.art_identity.maquettes.raster import camera,project
from ..native_checks import angle
from .mq21_pose import rotation_y
from .mq21_forms import leg_axes
from .mq21_contract import load as director_contract
from spec.art_identity.maquettes.blender.contract import digest

CHECK_DEFAULTS={'ring_samples':24}


def closed(faces):
    edges=Counter(tuple(sorted((a,b))) for face in faces for a,b in zip(face,face[1:]+face[:1]))
    return bool(edges) and all(count==2 for count in edges.values())


def observe(spec,points=None,joints=None,faces=None,baseline=None):
    q={p['id']:np.asarray(p['vertices'],float) for p in spec['pieces']} if points is None else {k.removesuffix('_render'):np.asarray(v,float) for k,v in points.items()}
    j={k:np.asarray(v,float) for k,v in (spec['joints'] if joints is None else joints).items()}
    fs={p['id']:p['faces'] for p in spec['pieces']} if faces is None else {k.removesuffix('_render'):v for k,v in faces.items()}
    if baseline is None:
        from ..recipe import compile_spec
        baseline=compile_spec()
    old=baseline;oldq={p['id']:np.asarray(p['vertices']) for p in old['pieces']};oldj=old['joints']
    fixed=director_contract();p=dict(fixed['pose']);d=fixed['forms'];checks={};rows={};c=old['source_calipers']
    for name in ('blade_down_degrees','blade_outward_degrees','far_fist_lowering_over_H','far_shoulder_hunch_reduction_over_H'):
        p[name]=fixed['accepted_far_arm']['solve'][name]
    checks['authoring_forms_match_director_contract']={k:v for k,v in spec['mq21']['forms'].items() if k not in ('authority','preservation')}==d
    checks['authoring_pose_matches_director_contract']=spec['pose']==p
    checks['source_reference_matches_director_contract']=digest(old)==fixed['source_spec_hash']
    checks['authoring_preservation_matches_director_contract']=spec['mq21']['forms']['preservation']==fixed['accepted_round2']
    floor=min(q['sabatons_'+side][:,2].min() for side in ('near','far'))
    L=fixed['leg_length_m']
    # H uses mq-16's established body-space gauge, reconstructed from calipers.
    H=fixed['reference_height_m']
    tolerance=fixed['geometry_tolerances']
    e=tolerance['numerical_m'];ae=tolerance['angle_degrees'];le=tolerance['dimension_over_H_or_L']
    def measure(name,actual,expected,tolerance):
        rows[name]={'actual':float(actual),'expected':float(expected),'tolerance':float(tolerance)}
        checks[name]=bool(abs(actual-expected)<=tolerance)
    for side in ('near','far'):
        measure('knee_'+side+'_degrees',angle(j['knee_'+side]-j['hip_'+side],j['ankle_'+side]-j['knee_'+side]),p['knee_bend_degrees'][side],ae)
        leg_axis=j['ankle_'+side]-j['hip_'+side];leg_axis/=np.linalg.norm(leg_axis)
        forward=np.array([1.,0,0])-leg_axis*leg_axis[0]
        checks['knee_'+side+'_bends_forward']=np.dot(j['knee_'+side]-j['hip_'+side],forward)>0
        raise_over_H=p['shoulder_raise_over_H']-(p['far_shoulder_hunch_reduction_over_H'] if side=='far' else 0)
        measure('shoulder_'+side+'_raise_over_H',(j['shoulder_'+side][2]-oldj['shoulder_'+side][2])/H,raise_over_H,le)
        measure('shoulder_'+side+'_forward_over_H',(j['shoulder_'+side][0]-oldj['shoulder_'+side][0])/H,p['shoulder_forward_over_H'],le)
        measure('sole_'+side,q['sabatons_'+side][:,2].min(),0,e)
        for name,start,end in (('upper','shoulder','elbow'),('fore','elbow','hand')):
            axis=j[end+'_'+side]-j[start+'_'+side];axis/=np.linalg.norm(axis)
            v=q[name+'_plate_'+side]-j[start+'_'+side]
            radius=np.linalg.norm(v-np.outer(np.einsum('ij,j->i',v,axis),axis),axis=1).max()
            old_r=c['upper_arm_radius_px' if name=='upper' else 'forearm_radius_px']*L/c['hip_to_sole_px']
            measure(name+'_'+side+'_diameter_multiplier',radius/old_r,d['arms']['diameter_multiplier'],e)
        leg=d['legs']
        for name,start,end,expected in (('thigh','hip','knee',[leg['hip_size_over_H'],leg['knee_size_over_H']]),
                                         ('shin','knee','ankle',[leg['knee_size_over_H'],leg['calf_size_over_H'],leg['ankle_size_over_H']])):
            rings=q[name+'_plate_'+side].reshape(-1,CHECK_DEFAULTS['ring_samples'],3)
            front,lateral,axis=leg_axes(j[start+'_'+side],j[end+'_'+side])
            for index,(ring,size) in enumerate(zip(rings,expected)):
                local=ring-ring.mean(0)
                width=np.ptp(np.einsum('ij,j->i',local,lateral));depth=np.ptp(np.einsum('ij,j->i',local,front))
                measure(name+'_'+side+'_station_'+str(index)+'_over_H',width/H,size,le)
                measure(name+'_'+side+'_station_'+str(index)+'_depth_over_width',depth/width,leg['depth_over_width'],le)
            if name=='shin':
                centres=rings.mean(1);fraction=np.dot(centres[1]-centres[0],axis)/np.dot(centres[-1]-centres[0],axis)
                measure('calf_'+side+'_bulge_fraction',fraction,leg['calf_bulge_fraction_from_knee'],le)
            checks[name+'_'+side+'_continuous_taper']=bool(len(rings)==len(expected) and np.ptp(expected)>0 and closed(fs[name+'_plate_'+side]))
        checks['knee_'+side+'_wing_and_rear_padding']=bool(q['knee_wing_'+side][:,1].max()>j['knee_'+side][1] if side=='near' else q['knee_wing_'+side][:,1].min()<j['knee_'+side][1]) and bool(q['knee_gambeson_'+side][:,0].max()<=j['knee_'+side][0]+e)
        front,lateral,_=leg_axes(j['knee_'+side],j['ankle_'+side])
        cop=q['round_knee_'+side]
        cop_width=np.ptp(np.einsum('ij,j->i',cop,lateral));cop_depth=np.ptp(np.einsum('ij,j->i',cop,front))
        measure('knee_cop_'+side+'_diameter_over_H',cop_width/H,leg['knee_cop_diameter_over_H'],le)
        measure('knee_cop_'+side+'_depth_over_width',cop_depth/cop_width,leg['depth_over_width'],le)
        foot_width=np.ptp(q['sabatons_'+side][:,1])/H
        rows['sabaton_'+side+'_width_over_H']={'actual':float(foot_width),'minimum':leg['sabaton_minimum_width_over_H']}
        checks['sabaton_'+side+'_width_over_H']=foot_width>=leg['sabaton_minimum_width_over_H']-e
        measure('sabaton_'+side+'_source_width_over_H',foot_width,fixed['sabaton_width_over_H'],le)
        wing=q['knee_wing_'+side];wd=leg['knee_wing'];sign=1 if side=='near' else -1
        measure('knee_wing_'+side+'_width_over_H',np.ptp(wing[:,1])/H,wd['width_over_H'],le)
        measure('knee_wing_'+side+'_height_over_H',np.ptp(wing[:,2])/H,wd['height_over_H'],le)
        cop_outer=np.max(sign*(q['round_knee_'+side][:,1]-j['knee_'+side][1]))
        measure('knee_wing_'+side+'_projection_over_H',(np.max(sign*(wing[:,1]-j['knee_'+side][1]))-cop_outer)/H,wd['outward_projection_over_H'],le)
        ridge_ids=['knee_wing_ridge_'+side+'_'+str(k) for k in range(wd['raised_ridges'])]
        checks['knee_wing_'+side+'_two_raised_ridges']=all(name in q and closed(fs[name]) and q[name][:,0].max()>wing[:,0].max() for name in ridge_ids)
    spine=j['head']-j['pelvis']
    measure('hip_lean_degrees',math.degrees(math.atan2(spine[0],spine[2])),p['hip_lean_degrees'],ae)
    head=j['head_tip']-j['head']
    measure('head_pitch_down_degrees',math.degrees(math.atan2(head[0],head[2])),p['head_pitch_down_degrees'],ae)
    checks['head_faces_chest']=abs(head[1])<=e and head[2]>0
    measure('near_elbow_degrees',angle(j['elbow_near']-j['shoulder_near'],j['hand_near']-j['elbow_near']),p['near_elbow_bend_degrees'],ae)
    segment_table=[]
    for side,sign in (('near',1),('far',-1)):
        for name,a,b,mesh in (('upper_arm','shoulder','elbow','upper'),('forearm','elbow','hand','fore'),
                               ('thigh','hip','knee','thigh'),('shin','knee','ankle','shin')):
            source=fixed['source_segment_lengths_m'][side+'_'+name]
            actual=float(np.linalg.norm(j[b+'_'+side]-j[a+'_'+side]));ratio=actual/source
            measure(side+'_'+name+'_source_length_ratio',ratio,1.,fixed['geometry_tolerances']['segment_ratio'])
            vertices=q[mesh+'_plate_'+side]
            if name in ('thigh','shin'):
                centres=vertices.reshape(-1,24,3).mean(1);mesh_length=np.linalg.norm(centres[-1]-centres[0])
            else:
                axis=j[b+'_'+side]-j[a+'_'+side];axis/=np.linalg.norm(axis)
                mesh_length=np.ptp(vertices@axis)
            measure(side+'_'+name+'_mesh_length_ratio',mesh_length/source,1.,fixed['geometry_tolerances']['segment_ratio'])
            segment_table.append({'segment':side+'_'+name,'source_m':source,'delivered_m':actual,'ratio':ratio,'mesh_length_m':float(mesh_length)})
        target=np.array([sign*p['near_step_over_leg_length']*L/2,sign*p['foot_span_over_shoulder_span']*(oldj['shoulder_near'][1]-oldj['shoulder_far'][1])/2])
        hip=j['hip_'+side];ankle=j['ankle_'+side]
        upper=fixed['source_segment_lengths_m'][side+'_thigh'];lower=fixed['source_segment_lengths_m'][side+'_shin']
        reach2=upper**2+lower**2+2*upper*lower*math.cos(math.radians(p['knee_bend_degrees'][side]))
        radius=math.sqrt(max(0.,reach2-(ankle[2]-hip[2])**2))
        # Independent optimality condition: distance to target must equal the
        # shortest distance from that target to the planted reach circle.
        minimum_miss=abs(np.linalg.norm(target-hip[:2])-radius)
        measure(side+'_leg_soft_target_optimality_m',np.linalg.norm(ankle[:2]-target),minimum_miss,e)
        measure(side+'_ankle_height_m',ankle[2],oldj['ankle_'+side][2],e)
    span=(j['ankle_near'][1]-j['ankle_far'][1])/(j['shoulder_near'][1]-j['shoulder_far'][1])
    step=(j['ankle_near'][0]-j['ankle_far'][0])/L
    rows['foot_span_over_shoulder_span']={'actual':float(span),'target':p['foot_span_over_shoulder_span'],'report_only':True}
    rows['near_step_over_L']={'actual':float(step),'target':p['near_step_over_leg_length'],'report_only':True}
    for coordinate,expected in enumerate([p['far_hand_forward_over_leg_length'],-p['far_hand_outward_over_leg_length'],-p['far_fist_lowering_over_H']*H/L]):
        measure('far_hand_offset_'+str(coordinate)+'_over_L',(j['hand_far'][coordinate]-j['hip_far'][coordinate])/L,expected,le)
    front_thigh=q['thigh_plate_near'][:CHECK_DEFAULTS['ring_samples'],0].max()
    target=np.array([front_thigh+p['near_fist_forward_of_thigh_over_L']*L,j['shoulder_near'][1],j['hip_near'][2]])
    delta=target-j['shoulder_near'];endpoint=j['hand_near']-j['shoulder_near']
    upper=fixed['source_segment_lengths_m']['near_upper_arm'];lower=fixed['source_segment_lengths_m']['near_forearm']
    reach=math.sqrt(upper**2+lower**2+2*upper*lower*math.cos(math.radians(p['near_elbow_bend_degrees'])))
    fist_miss=float(np.linalg.norm(j['hand_near']-target))
    measure('near_arm_fixed_bend_target_optimality_m',fist_miss,abs(np.linalg.norm(delta)-reach),e)
    checks['near_arm_forward_plane']=abs(endpoint[1])<=e and j['hand_near'][0]>j['elbow_near'][0]
    rows['near_fist_forward_of_thigh_over_L']={'actual':float((j['hand_near'][0]-front_thigh)/L),'target':p['near_fist_forward_of_thigh_over_L'],'report_only':True}
    rows['near_fist_hip_height_over_L']={'actual':float((j['hand_near'][2]-j['hip_near'][2])/L),'target':0.,'report_only':True}
    soft_misses={'near_fist_over_H':fist_miss/H,'stance_over_H':float((span-p['foot_span_over_shoulder_span'])*(j['shoulder_near'][1]-j['shoulder_far'][1])/H),
        'step_over_L':float(step-p['near_step_over_leg_length']),'near_fist_target_m':target.tolist(),
        'policy':'Exact source lengths, bends, lean and planted soles; project soft position targets onto each fixed-length reach locus. No rescaling.'}
    cov=lambda a:np.linalg.eigvalsh(np.cov(a.T))
    measure('near_gauntlet_scale',math.sqrt(cov(q['gauntlet_near'])[-1]/cov(oldq['gauntlet_near'])[-1]),d['arms']['gauntlet_multiplier'],e)
    chest=q['cuirass'];old_chest=oldq['cuirass'];upper=chest[:,2]>=j['shoulder_near'][2]
    nonzero=upper&(abs(old_chest[:,1])>e)
    measure('chest_shoulder_width_multiplier',np.mean(chest[nonzero,1]/old_chest[nonzero,1]),d['arms']['chest_shoulder_width_multiplier'],e)
    turn=rotation_y(p['head_pitch_down_degrees']);helm=np.einsum('ij,jk->ik',q['great_helm']-j['head'],turn)
    rings=helm.reshape(3,8,3)
    measure('helm_top_over_base_width',np.ptp(rings[1,:,1])/np.ptp(rings[0,:,1]),d['helm']['top_width_over_base'],e)
    measure('helm_dome_rise_over_H',(rings[2,:,2].mean()-rings[1,:,2].mean())/H,d['helm']['dome_height_over_H'],le)
    checks['helm_octagonal_flat_front']=len(rings[0])==8 and abs(rings[0,0,0]-rings[0,-1,0])<=e and all(closed(fs[name]) for name in ('great_helm','helm_crest'))
    crest=np.einsum('ij,jk->ik',q['helm_crest']-j['head'],turn);crest=crest.reshape(3,4,3)
    heights=(crest[:,2,2]-crest[:,1,2])/H
    measure('crest_height_over_H',heights.max(),d['helm']['crest_rear_height_over_H'],le)
    for index,t in enumerate((0,.5,1)):
        measure('crest_station_'+str(index)+'_height_over_H',heights[index],(1-t)*d['helm']['crest_front_height_over_H']+t*d['helm']['crest_rear_height_over_H'],le)
    measure('crest_thickness_over_H',np.ptp(crest[:,:,1])/H,d['helm']['crest_thickness_over_H'],le)
    checks['crest_rises_toward_back']=bool((crest[-1,2,2]-crest[-1,1,2])>(crest[0,2,2]-crest[0,1,2]))
    toward=camera(spec)[2][2]
    for side,sign in (('near',1),('far',-1)):
        cap=q['pauldron_'+side+'_0'];centre=cap[:24].mean(0);pole=cap[(13-1)*24];axis=pole-centre;axis/=np.linalg.norm(axis)
        measure('pauldron_'+side+'_tilt_up_degrees',math.degrees(math.asin(axis[2])),d['pauldrons']['outward_tilt_up_degrees'],ae)
        checks['pauldron_'+side+'_axis_lateral']=bool(abs(axis[0])<=e and sign*axis[1]>0)
        measure('pauldron_'+side+'_source_radius',np.linalg.norm(cap[:24]-centre,axis=1).mean(),c['pauldron_radius_px']*L/c['hip_to_sole_px'],e)
        measure('pauldron_'+side+'_source_shell_thickness',np.linalg.norm(cap[288]-cap[577]),c['pauldron_shell_thickness_px']*L/c['hip_to_sole_px'],e)
        pts=np.concatenate([q['pauldron_'+side+'_'+str(k)] for k in range(3)])
        forward=(pts[:,0].max()-chest[:,0].max())/H;depth=np.dot(pts.mean(0)-j['shoulder_'+side],toward)/H
        rows['pauldron_'+side+'_forward_over_H']={'actual':float(forward),'maximum':.03}
        rows['pauldron_'+side+'_centroid_depth_over_H']={'actual':float(depth),'maximum':.02}
        checks['pauldron_'+side+'_forward_limit']=bool(forward<=.03+e)
        checks['pauldron_'+side+'_centroid_depth']=bool(depth<=.02+e)
        projection=project(spec,[pts.mean(0),j['shoulder_'+side]])
        if side=='near':checks['pauldron_near_centroid_outward']=bool(projection[0,0]>projection[1,0])
        checks['pauldron_'+side+'_closed_shells']=all(closed(fs['pauldron_'+side+'_'+str(k)]) for k in range(3))
    # The lower near lames follow the corrected upper arm. Preserve their
    # accepted ring sizes/heights rather than freezing world-space positions.
    shoulder=j['shoulder_near'];arm=j['elbow_near']-shoulder
    seating=q['pauldron_near_0'][:24].mean(0)[0]-shoulder[0]
    mean_cos=np.cos(np.linspace(-math.pi/2,math.pi/2,24)).mean()
    for name,profiles in fixed['accepted_near_lame_profiles_m'].items():
        rings=q[name].reshape(-1,24,3)
        actual=np.array([[np.ptp(r[:,0]),np.ptp(r[:,1]),r[:,2].mean()-shoulder[2]] for r in rings])
        checks[name+'_accepted_ring_profiles']=bool(actual.shape==np.shape(profiles) and np.allclose(actual,profiles,atol=e,rtol=0))
        expected=[]
        for ring in rings:
            z=ring[:,2].mean();centre=shoulder+arm*min(0,z-shoulder[2])/arm[2];centre[2]=z
            centre+=np.array([seating,np.ptp(ring[:,0])/2*mean_cos,0]);expected.append(centre)
        checks[name+'_follows_corrected_arm']=bool(np.allclose(rings.mean(1),expected,atol=e,rtol=0))
    blade=q['falchion'];meta=spec['mq16']['falchion'];root=(blade[meta['outer_indices'][0]]+blade[meta['spine_indices'][0]])/2;tip=blade[meta['blade_tip_vertex']]
    direction=tip-root;direction/=np.linalg.norm(direction)
    measure('blade_down_degrees',math.degrees(math.atan2(-direction[2],np.linalg.norm(direction[:2]))),p['blade_down_degrees'],ae)
    measure('blade_outward_degrees',math.degrees(math.atan2(-direction[1],direction[0])),p['blade_outward_degrees'],ae)
    clearance=float((tip[2]-floor)/H);rule=d['blade_clearance']
    rows['blade_tip_clearance_over_H']={'actual':clearance,'maximum':rule['maximum_clearance_over_H']}
    checks['blade_tip_clearance_over_H']=0<clearance<=rule['maximum_clearance_over_H']+e
    down=rows['blade_down_degrees']['actual'];lowering=(j['hip_far'][2]-j['hand_far'][2])/H
    measure('far_fist_lowering_over_H',lowering,p['far_fist_lowering_over_H'],le)
    far_bend=angle(j['elbow_far']-j['shoulder_far'],j['hand_far']-j['elbow_far'])
    reduction=(oldj['shoulder_far'][2]+p['shoulder_raise_over_H']*H-j['shoulder_far'][2])/H
    checks['blade_solve_within_director_bounds']=bool(abs(down-rule['down_degrees'])<=ae
        and -e<=lowering<=rule['desired_fist_lowering_over_H']+e
        and -e<=reduction<=rule['maximum_far_shoulder_hunch_reduction_over_H']+e
        and far_bend>=rule['minimum_far_elbow_bend_degrees']-ae)
    rows['far_elbow_bend_degrees']={'actual':far_bend,'minimum':rule['minimum_far_elbow_bend_degrees']}
    checks['far_elbow_bend_degrees']=far_bend>=rule['minimum_far_elbow_bend_degrees']-ae
    for name,a,b in (('upper','shoulder','elbow'),('forearm','elbow','hand')):
        measure('far_'+name+'_source_length_m',np.linalg.norm(j[b+'_far']-j[a+'_far']),np.linalg.norm(np.subtract(oldj[b+'_far'],oldj[a+'_far'])),e)
    count=meta['blade_vertex_count'];oldmeta=old['mq16']['falchion'];oldblade=oldq['falchion'][:count]
    # Rigid-invariant Gram matrices catch any change to the approved blade.
    a=blade[:count]-blade[0];b=oldblade-oldblade[0]
    checks['falchion_shape_preserved']=bool(np.allclose(np.einsum('ij,kj->ik',a,a),np.einsum('ij,kj->ik',b,b),atol=e,rtol=0))
    hand=np.concatenate([q[piece['id']] for piece in spec['pieces'] if piece['part']=='hand_far'])
    hand_ax=np.einsum('ij,j->i',hand-j['hand_far'],direction);gm=spec['mq21']['grip'];guard=blade[gm['guard_vertex_start']:gm['guard_vertex_start']+gm['guard_vertex_count']]
    measure('guard_gap_over_H',(np.einsum('ij,j->i',guard-j['hand_far'],direction).min()-hand_ax.max())/H,d['grip']['guard_gap_over_H'],le)
    grip=blade[count:count+24].reshape(2,12,3).mean(1);line=grip[1]-grip[0];line/=np.linalg.norm(line)
    checks['grip_through_closed_hand']=bool(np.linalg.norm(np.cross(j['hand_far']-grip[0],line))<=e and np.dot(j['hand_far']-grip[0],line)>0 and np.dot(grip[1]-j['hand_far'],line)>0)
    finger_names=['finger_far_'+str(k) for k in range(4)]
    checks['four_separate_fingers_and_thumb']=all(name in q and closed(fs[name]) for name in finger_names+['thumb_far'])
    finger_centres=q['finger_far_0'].reshape(-1,12,3).mean(1)
    thumb_centres=q['thumb_far'].reshape(-1,12,3).mean(1)
    radial=lambda a:np.linalg.norm((a-j['hand_far'])-np.outer(np.einsum('ij,j->i',a-j['hand_far'],direction),direction),axis=1)
    checks['thumb_wraps_over_index']=bool(radial(thumb_centres[-2:]).min()>radial(finger_centres).max())
    from .mq21_grip_checks import observe as grip_observations
    contact_checks,contact_rows=grip_observations(q,fs,count,H,fixed['grip_tolerances'])
    checks.update(contact_checks);rows.update(contact_rows)
    measure('far_gauntlet_axial_scale',np.ptp(hand_ax)/(2*c['hand_half_height_px']*L/c['hip_to_sole_px']),d['arms']['gauntlet_multiplier'],le)
    checks['pommel_below_little_finger']=bool(np.einsum('ij,j->i',blade[meta['pommel_vertex_start']:]-j['hand_far'],direction).min()<np.einsum('ij,j->i',q['finger_far_3']-j['hand_far'],direction).min())
    pieces={piece['id']:piece for piece in spec['pieces']}
    checks['hand_weapon_ownership']=all(pieces[name]['part']=='hand_far' for name in finger_names+['thumb_far','gauntlet_far']) and all(pieces[name]['part']=='falchion' and pieces[name]['rig_bone']=='hand_far' for name in ('falchion','glowing_edge'))
    tab=q['back_tabard'];hip_width=j['hip_near'][1]-j['hip_far'][1]
    measure('back_tabard_width_over_hip',np.ptp(tab[:,1])/hip_width,d['back_tabard']['width_over_hip_width'],le)
    hem=tab[9:18];tears=hem[::2,2][0]-hem[1::2,2]
    checks['back_tabard_four_torn_points']=len(tears)==4 and bool(np.all((tears/H>=.02-e)&(tears/H<=.04+e)))
    knee_height=(j['knee_near'][2]+j['knee_far'][2])/2
    measure('back_tabard_knee_gap_over_H',(hem[::2,2].mean()-knee_height)/H,d['back_tabard']['knee_clearance_over_H'],le)
    for index,(point,depth) in enumerate(zip(hem[1::2],tears)):
        measure('back_tabard_tear_'+str(index)+'_position',(point[1]-hem[:,1].min())/np.ptp(hem[:,1]),d['back_tabard']['tear_positions_across_width'][index],le)
        measure('back_tabard_tear_'+str(index)+'_depth_over_H',depth/H,d['back_tabard']['tear_depths_over_H'][index],le)
    checks['tabard_pelvis_ownership']=pieces['back_tabard']['rig_bone']=='pelvis' and pieces['back_tabard']['part']=='tabard'
    checks['front_tabard_unchanged']=bool(np.allclose(q['tabard'],oldq['tabard'],atol=e,rtol=0))
    checks['all_meshes_closed']=all(closed(faces) for faces in fs.values())
    checks['labels_unchanged']=spec['labels']==old['labels']
    checks={name:bool(value) for name,value in checks.items()}
    return {'passed':all(checks.values()),'checks':checks,'measurements':rows,'segment_lengths':segment_table,'soft_target_misses':soft_misses,
        'observed_mesh_hashes':{name:digest({'vertices':vertices.tolist(),'faces':fs[name]}) for name,vertices in sorted(q.items())},
        'height_gauge_m':H,'far_arm_length_multiplier':float((np.linalg.norm(j['elbow_far']-j['shoulder_far'])+np.linalg.norm(j['hand_far']-j['elbow_far']))/(np.linalg.norm(np.subtract(oldj['elbow_far'],oldj['shoulder_far']))+np.linalg.norm(np.subtract(oldj['hand_far'],oldj['elbow_far'])))),
        'actual_crown_height_m':float(q['great_helm'][:,2].max()-floor),
        'actual_crest_height_m':float(q['helm_crest'][:,2].max()-floor),
        'joints_world':{k:v.tolist() for k,v in j.items()},
        'sole_min_z_m':{side:float(q['sabatons_'+side][:,2].min()) for side in ('near','far')}}
