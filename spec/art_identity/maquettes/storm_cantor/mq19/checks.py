"""Portable observations; native entry supplies opened vertices and bone frames."""
import math
import numpy as np
from spec.art_identity.maquettes.blender.facing import axis_report
from ..native_checks import angle
from .pose import rotation
from .cloth import mesh_rims, boundary_loops, extrema

CHECK_DEFAULTS = {'angle_tolerance_degrees':1., 'ratio_tolerance':.01,
                  'native_tolerance_m':1e-5, 'shape_tolerance_over_H':1e-6,
                  'shoulder_rule_tolerance_px':10.}


def observe(spec, points, joints, forwards, faces=None):
    p = spec['mq19']['design']['pose']; H = spec['mq19']['gauge_H_m']; L = spec['mq19']['gauge_L_m']
    j = {k:np.asarray(v,float) for k,v in joints.items()}; pts = {k:np.asarray(v,float) for k,v in points.items()}
    rows = []
    def add(number,name,target,value,angular=False):
        tolerance = CHECK_DEFAULTS['angle_tolerance_degrees'] if angular else CHECK_DEFAULTS['ratio_tolerance']
        rows.append({'requirement':number,'name':name,'target':target,'measured':float(value),
                     'tolerance':tolerance,'passed':bool(abs(value-target)<=tolerance)})
    for side in ('near','far'):
        add(1,side+'_knee_degrees',p[side+'_knee_degrees'],
            angle(j['knee_'+side]-j['hip_'+side],j['ankle_'+side]-j['knee_'+side]),True)
    hips = j['hip_near']-j['hip_far']
    add(2,'pelvis_down_near_degrees',p['pelvis_down_near_degrees'],
        math.degrees(math.atan2(-hips[2],hips[1])),True)
    spine = j['head']-j['torso']
    facing = rotation([0,0,1],p['chest_yaw_toward_viewer_degrees'])[:,0]
    add(2,'forward_lean_degrees',p['forward_lean_degrees'],math.degrees(math.atan2(spine@facing,spine[2])),True)
    head,chest,pelvis = (np.asarray(forwards[k],float) for k in ('head','torso','pelvis'))
    yaw = lambda v: math.degrees(math.atan2(v[1],v[0]))
    add(3,'chest_yaw_toward_viewer_degrees',p['chest_yaw_toward_viewer_degrees'],yaw(chest)-yaw(pelvis),True)
    add(4,'head_down_degrees',p['head_down_degrees'],math.degrees(math.atan2(-head[2],np.linalg.norm(head[:2]))),True)
    add(4,'head_matches_chest_yaw',0,yaw(head)-yaw(chest),True)
    up=spine/np.linalg.norm(spine); anterior=chest/np.linalg.norm(chest)
    frame = np.column_stack([anterior,np.cross(up,anterior),up])
    shoulders = (j['shoulder_near']-j['shoulder_far'])@frame
    W = abs(shoulders[1])
    add(5,'ankle_span_over_shoulders',p['ankle_span_over_shoulders'],abs(j['ankle_near'][1]-j['ankle_far'][1])/W)
    add(6,'near_step_over_L',p['near_step_over_L'],(j['ankle_near'][0]-j['ankle_far'][0])/L)
    fist,shoulder = j['hand_far'],j['shoulder_far']
    add(7,'fist_height_over_H',p['fist_height_over_H'],fist[2]/H)
    add(7,'fist_forward_over_L',p['fist_forward_over_L'],(fist[0]-shoulder[0])/L)
    add(7,'fist_outward_over_L',p['fist_outward_over_L'],-(fist[1]-shoulder[1])/L)
    staff = pts['staff_render']; a,b = spec['mq17']['staff_components']['shaft']
    shaft = staff[a:b].reshape(-1,12,3).mean(1); axis = shaft[-1]-shaft[0]; axis/=np.linalg.norm(axis)
    add(7,'staff_from_vertical_degrees',p['staff_from_vertical_degrees'],angle(axis,[0,0,1]),True)
    add(7,'staff_forward_degrees',p['staff_forward_degrees'],math.degrees(math.atan2(axis[0],axis[2])),True)
    add(7,'staff_butt_sole_over_H',0,staff[a:a+12,2].min()/H)
    add(7,'staff_grip_axis_distance_over_L',0,np.linalg.norm(np.cross(fist-shaft[0],axis))/L)
    v = j['elbow_far']-shoulder; reach = fist-shoulder; reach/=np.linalg.norm(reach)
    v-=reach*(v@reach)
    # Recover the directed pole in the YZ plane, undoing its projection onto
    # the shoulder-to-fist reach (same definition as the original proof).
    pole = v-reach*(v[0]/reach[0])
    add(8,'far_elbow_outward_degrees',p['far_elbow_outward_degrees'],math.degrees(math.atan2(-pole[1],-pole[2])),True)
    upper = (j['elbow_near']-j['shoulder_near'])@frame
    fore = (j['hand_near']-j['elbow_near'])@frame
    add(9,'near_upper_out_degrees',p['near_upper_out_degrees'],math.degrees(math.asin(upper[1]/np.linalg.norm(upper))),True)
    add(9,'near_elbow_degrees',p['near_elbow_degrees'],angle(upper,fore),True)
    for finger in range(4):
        rings = pts['finger_near_'+str(finger)+'_render'].reshape(-1,12,3).mean(1)
        directions = np.diff(rings,axis=0)
        for k in range(len(directions)-1):
            add(9,f'near_finger_{finger}_knuckle_{k}',p['near_knuckle_degrees'],angle(directions[k],directions[k+1]),True)
    add(9,'near_wrist_ahead_over_L',p['near_wrist_ahead_over_L'],
        (j['hand_near'][0]-pts['thigh_plate_near_render'][:,0].max())/L)
    soles = {s:float(pts['pointed_sabaton_'+s+'_render'][:,2].min()) for s in ('near','far')}
    from spec.art_identity.maquettes.raster import project
    projected = {v:{n:project(spec,q,v,spec['mq19']['capture_px'])[:2] for n,q in joints.items()} for v in ('front','rear')}
    gates = captured_pose_gates(spec,projected,{'observed_joints':joints})
    tolerance = CHECK_DEFAULTS['native_tolerance_m']
    checks = {'pose_values':all(r['passed'] for r in rows),
        'feet_planted':all(abs(v)<=tolerance for v in soles.values()),
        'staff_butt_outward_of_far_foot':j['ankle_far'][1]-shaft[0,1]>=(spec['mq19']['design']['pose_resolution'].get('minimum_staff_clearance_over_L',0) if isinstance(spec['mq19']['design'].get('pose_resolution'),dict) else 0)*L-1e-7,
        'far_elbow_not_forward':j['elbow_far'][0]<=shoulder[0]+tolerance,
        'forearm_forward':fore[0]>upper[0],
        'shoulder_rule':gates['checks']['shoulder_rule'],
        'level_shoulders':abs(j['shoulder_near'][2]-j['shoulder_far'][2])<=.005*H,
        'true_turn':gates['checks']['proper_true_turn'],
        'facing':axis_report(spec,chest)['passed'],
        'design_resolved':not spec['mq19']['diagnostic_only']}
    cloak = None
    if faces is not None and 'full_back_cloak_render' in pts:
        cloak = observe_cloak(spec,pts['full_back_cloak_render'],faces['full_back_cloak_render'],j,pts,faces)
        checks['cloak']=cloak['passed']
    elif not spec['mq19']['diagnostic_only']:
        checks['cloak']=False
    helm = pts['great_helm_render']; head_up = j['head_tip']-j['head']; head_up/=np.linalg.norm(head_up)
    helm_levels = np.einsum('nj,j->n',helm,head_up)
    tine_top = max(float(np.einsum('nj,j->n',pts['helm_tine_'+s+'_render'],head_up).max()) for s in ('near','far'))
    proportions = {'helm_without_tines_over_H':float(np.ptp(helm_levels)/H),
        'tines_over_H':float((tine_top-helm_levels.max())/H),
        'shoulder_transverse_width_over_H':W/H,
        'torso_neck_to_waist_over_H':float(np.linalg.norm(j['head']-j['pelvis'])/H),
        'leg_hip_to_sole_over_H':float(sum(np.linalg.norm(j['hip_'+s]-[j['ankle_'+s][0],j['ankle_'+s][1],soles[s]]) for s in ('near','far'))/(2*H))}
    checks = {k:bool(v) for k,v in checks.items()}
    gates['checks'] = {k:bool(v) for k,v in gates['checks'].items()}
    gates['checks']['shoulders_level_3d']=checks['level_shoulders']
    gates['passed']=all(gates['checks'].values())
    if not spec['mq19']['diagnostic_only']:
        tabard = observe_tabard(spec,pts['front_tabard_render'],j)
        checks['tabard'] = tabard['passed']
    else: tabard = None
    return {'passed':all(checks.values()), 'checks':checks,'pose_values':rows,'soles_m':soles,
        'staff_top_over_H':float(staff[:,2].max()/H),
        'staff_butt_outward_clearance_over_L':float((j['ankle_far'][1]-shaft[0,1])/L),
        'shoulder_and_turn':gates,'cloak':cloak,'tabard':tabard,'proportions':proportions,
        'definition':'H and L retain mq-17 gauges. Body-space transverse width is measured in the chest frame; sole plane is Z=0.'}


def strip_metrics(hem, H):
    """Torn points include tips at either end; roots are intervening peaks."""
    tips = extrema(hem[:,2],True)
    if hem[0,2]<hem[1,2]: tips.insert(0,0)
    if hem[-1,2]<hem[-2,2]: tips.append(len(hem)-1)
    roots = extrema(hem[:,2],False)
    rows = []
    for tip in tips:
        left = max([i for i in roots if i<tip],default=0)
        right = min([i for i in roots if i>tip],default=len(hem)-1)
        rows.append({'tip':tip,'width_over_H':float(abs(hem[right,1]-hem[left,1])/H),
                     'length_over_H':float((max(hem[left,2],hem[right,2])-hem[tip,2])/H)})
    return rows


def captured_pose_gates(spec,recorded,native):
    from .pose_gates import evaluate
    return evaluate(spec,recorded,native)


def observe_cloak(spec,points,faces,joints,body_points=None,body_faces=None):
    if 'solid_shape' in spec['mq19']['cloak_layout']:
        return observe_generated_cloak(spec,points,faces,joints,body_points,body_faces)
    H = spec['mq19']['gauge_H_m']; layout = spec['mq19']['cloak_layout']; count = layout['paired_vertices']
    mid = (points[:count]+points[count:])/2
    grid = mid.reshape(*layout['shape'],3); nr,nc = layout['shape']
    loops = boundary_loops(mesh_rims(faces,count))
    outer = next((loop for loop in loops if 0 in loop),None)
    if outer is None: raise ValueError('Cloak must retain its shoulder attachment')
    holes = [loop for loop in loops if loop is not outer]
    d = spec['mq19']['design']['cloak']; widths = [float(np.ptp(mid[loop,1])/H) for loop in holes]
    low = float(grid[:,:,2].min()); high = float(grid[:,:,2].max())
    bottom = grid[-1]; strips = strip_metrics(bottom,H)
    folds = extrema(grid[len(grid)//2,:,0],True)
    cuts = {'far':set(),'near':set()}
    for a,b in zip(outer,outer[1:]+outer[:1]):
        if abs(a-b)!=nc: continue
        column = a%nc
        if 0<column<nc//2: cuts['far'].add(min(a,b)//nc)
        elif nc//2<column<nc-1: cuts['near'].add(min(a,b)//nc)
    runs = {s:sum(r-1 not in values for r in values) for s,values in cuts.items()}
    # The brief gives no numerical fold amplitude or tear coordinates. They
    # enter as authored rows; this observer never supplies missing design.
    tolerance = CHECK_DEFAULTS['ratio_tolerance']
    alternating = d['alternating_strip_lengths_over_H']
    lengths = [r['length_over_H'] for r in strips]
    alternate_ok = any(all(abs(v-alternating[(i+phase)%2])<=tolerance for i,v in enumerate(lengths)) for phase in (0,1))
    frame = rotation([0,0,1],spec['mq19']['design']['pose']['chest_yaw_toward_viewer_degrees'])@rotation([0,1,0],spec['mq19']['design']['pose']['forward_lean_degrees'])
    W = abs(((joints['shoulder_near']-joints['shoulder_far'])@frame)[1])
    # Intersect live native polygons with the near hip's horizontal plane;
    # removed grid vertices cannot manufacture the required side flare.
    sections = []
    z = joints['hip_near'][2]
    for face in faces:
        for a,b in zip(face,face[1:]+face[:1]):
            p0,p1 = points[a],points[b]
            if (p0[2]-z)*(p1[2]-z)<=0 and abs(p1[2]-p0[2])>1e-10:
                sections.append(float(p0[1]+(p1[1]-p0[1])*(z-p0[2])/(p1[2]-p0[2])))
    near_flare = (max(sections)-joints['hip_near'][1])/spec['mq19']['gauge_L_m'] if sections else None
    checks = {'three_actual_holes':len(holes)==d['holes'],
        'near_hip_flare':near_flare is not None and abs(near_flare-d['near_flare_over_L'])<=tolerance,
        'hole_widths':all(d['hole_width_over_H'][0]<=w<=d['hole_width_over_H'][1] for w in widths),
        'holes_in_lower_third':all(float(mid[loop,2].max())<=low+(high-low)/3 for loop in holes),
        'nine_hem_strips':len(strips)==d['strips'],
        'strip_widths':all(d['strip_width_over_H'][0]<=r['width_over_H']<=d['strip_width_over_H'][1] for r in strips),
        'alternating_strip_lengths':alternate_ok,
        'side_notches':all(d['notches_per_side'][0]<=n<=d['notches_per_side'][1] for n in runs.values()),
        'four_vertical_folds':len(folds)==d['folds'],
        'hem_centre':abs(float(bottom[nc//2,2])/H-d['hem_centre_over_H'])<=tolerance,
        'hem_sides':abs(float(bottom[0,2])/H-d['hem_sides_over_H'])<=tolerance,
        'hem_span':abs(float(np.ptp(bottom[:,1]))/W-d['hem_span_over_shoulders'])<=tolerance,
        'near_longest_tip':abs(float(bottom[-1,2])/H-d['near_longest_tip_over_H'])<=tolerance and np.argmin(bottom[:,2])==nc-1,
        'cloth_thickness':bool(np.all(np.linalg.norm(points[:count]-points[count:],axis=1)>=spec['feedback1']['cloth_min_thickness']*H-1e-7)),
        'attachment_at_shoulders':max(abs(float(grid[0,i,2]-joints['shoulder_'+s][2]))/H for i,s in [(0,'far'),(-1,'near')])<=tolerance}
    checks = {k:bool(v) for k,v in checks.items()}
    return {'passed':all(checks.values()),'checks':checks,'hole_count':len(holes),'hole_widths_over_H':widths,
        'strip_count':len(strips),'strips':strips,'side_notch_counts':runs,'near_flare_over_L':near_flare,
        'fold_count':len(folds),'boundary_loop_count':len(loops)}


def observe_tabard(spec,points,joints):
    nr,nc = spec['volume_layout']['tabard_grid']; count = nr*nc
    mid = (points[:count]+points[count:])/2
    # Undo only the measured pelvic roll to read the preserved panel's local
    # hem. These are opened native vertices, not the authored hem values.
    hips = joints['hip_near']-joints['hip_far']
    roll = math.degrees(math.atan2(hips[2],hips[1]))
    local = np.einsum('nj,kj->nk',mid,rotation([1,0,0],-roll)).reshape(nr,nc,3)
    d = spec['mq19']['design']['tabard']
    if 'base_hem_z_over_H' in d:
        base=np.asarray(d['base_hem_z_over_H']);observed=local[-1,:,2]/spec['mq19']['gauge_H_m']
        # Remove the rigid translation left by unrolling about world origin.
        observed-=np.mean(observed-np.asarray(d['hem_z_over_H']))
        delta=base-observed;columns=np.arange(nc)
        expected=sum(depth*np.maximum(0,1-abs(columns-c)/d['tent_half_width_columns']) for c,depth in zip(d['point_columns'],d['point_depths_over_H']))
        checks={'five_added_torn_points':len(extrema(delta,False))==5,
            'exact_director_tent_profile':bool(np.max(abs(delta-expected))<=1e-6),
            'cloth_thickness':bool(np.all(np.linalg.norm(points[:count]-points[count:],axis=1)>=spec['feedback1']['cloth_min_thickness']*spec['mq19']['gauge_H_m']-1e-7))}
        return {'passed':all(checks.values()),'checks':checks,'added_point_columns':extrema(delta,False),
            'visible_outline_valleys':extrema(local[-1,:,2],True),'measured_depths_over_H':delta.tolist()}
    rows = strip_metrics(local[-1],spec['mq19']['gauge_H_m'])
    checks = {'five_torn_points':len(rows)==d['points'],
        'point_lengths':all(d['point_length_over_H'][0]<=r['length_over_H']<=d['point_length_over_H'][1] for r in rows),
        'cloth_thickness':bool(np.all(np.linalg.norm(points[:count]-points[count:],axis=1)>=spec['feedback1']['cloth_min_thickness']*spec['mq19']['gauge_H_m']-1e-7))}
    return {'passed':all(checks.values()),'checks':checks,'points':rows}


def numeric_contract(spec,report):
    """Reject omitted rows, altered targets, NaNs and summary-only success."""
    expected = {
        'near_knee_degrees':(1,'near_knee_degrees',True),
        'far_knee_degrees':(1,'far_knee_degrees',True),
        'pelvis_down_near_degrees':(2,'pelvis_down_near_degrees',True),
        'forward_lean_degrees':(2,'forward_lean_degrees',True),
        'chest_yaw_toward_viewer_degrees':(3,'chest_yaw_toward_viewer_degrees',True),
        'head_down_degrees':(4,'head_down_degrees',True),
        'head_matches_chest_yaw':(4,None,True),
        'ankle_span_over_shoulders':(5,'ankle_span_over_shoulders',False),
        'near_step_over_L':(6,'near_step_over_L',False),
        'fist_height_over_H':(7,'fist_height_over_H',False),
        'fist_forward_over_L':(7,'fist_forward_over_L',False),
        'fist_outward_over_L':(7,'fist_outward_over_L',False),
        'staff_from_vertical_degrees':(7,'staff_from_vertical_degrees',True),
        'staff_forward_degrees':(7,'staff_forward_degrees',True),
        'staff_butt_sole_over_H':(7,None,False),
        'staff_grip_axis_distance_over_L':(7,None,False),
        'far_elbow_outward_degrees':(8,'far_elbow_outward_degrees',True),
        'near_upper_out_degrees':(9,'near_upper_out_degrees',True),
        'near_elbow_degrees':(9,'near_elbow_degrees',True),
        'near_wrist_ahead_over_L':(9,'near_wrist_ahead_over_L',False)}
    for finger in range(4):
        for knuckle in range(3): expected[f'near_finger_{finger}_knuckle_{knuckle}']=(9,'near_knuckle_degrees',True)
    rows = report.get('pose_values',[])
    if len(rows)!=len(expected) or {r.get('name') for r in rows}!=set(expected): return False
    for r in rows:
        number,key,angular = expected[r['name']]
        target = 0 if key is None else spec['mq19']['design']['pose'][key]
        tolerance = CHECK_DEFAULTS['angle_tolerance_degrees'] if angular else CHECK_DEFAULTS['ratio_tolerance']
        measured = r.get('measured')
        if (type(measured) not in (int,float) or not math.isfinite(measured) or r.get('target')!=target or
            r.get('requirement')!=number or r.get('tolerance')!=tolerance or r.get('passed') is not True or
            abs(measured-target)>tolerance): return False
    return True


def preserved_shapes(spec,points):
    """Check r3 intrinsic volumes after removing only a best-fit rigid pose.

    The fit cannot repair scale, flattened domes, thin plate or shortened armour.
    New cloth, curled near fingers and the obliquely cut shaft are checked by
    their dedicated observations instead.
    """
    from .shape_reference import decode
    reference=decode(spec['mq19']['baseline_shape_reference']);rows={}
    for name,vertices in reference.items():
        expected = np.asarray(vertices); measured = np.asarray(points.get(name+'_render',[]))
        if measured.shape!=expected.shape:
            rows[name] = {'passed':False,'maximum_error_over_H':None};continue
        a = measured-measured.mean(0); b = expected-expected.mean(0)
        u,_,vt = np.linalg.svd(np.einsum('nj,nk->jk',a,b))
        correction = np.eye(3); correction[-1,-1]=np.linalg.det(u@vt)
        r = u@correction@vt
        error = float(np.linalg.norm(np.einsum('nj,jk->nk',a,r)-b,axis=1).max()/spec['mq19']['gauge_H_m'])
        rows[name] = {'passed':error<=CHECK_DEFAULTS['shape_tolerance_over_H'],'maximum_error_over_H':error}
    return {'passed':bool(rows) and all(r['passed'] for r in rows.values()),'pieces':rows}


def observe_generated_cloak(spec,points,faces,joints,body_points=None,body_faces=None):
    """Read physical strips and actual hole/notch rims, independent of recipe rows."""
    H=spec['mq19']['gauge_H_m'];L=spec['mq19']['gauge_L_m'];layout=spec['mq19']['cloak_layout'];d=spec['mq19']['design']['cloak']
    count=layout['paired_vertices'];mid=(points[:count]+points[count:])/2
    loops=boundary_loops(mesh_rims(faces,count));root=mid[layout['root_indices']]
    outer=max(loops,key=len);holes=[loop for loop in loops if loop is not outer]
    from .live_ribbons import measure as live_ribbons
    live=live_ribbons(spec,mid,faces);observed=live['ribbons']
    for row in observed:
        tip=row['tip_index']
        row['lowest_tip_skin_over_H']=float(min(points[tip,2],points[tip+count,2])/H)
    root_width=float(abs(root[-1,1]-root[0,1]));shoulders=np.asarray(layout['shoulder_indices']);top=mid[shoulders]
    # Hole diameters use their developed boundary length, independent of yaw.
    diameters=[float(sum(np.linalg.norm(mid[b]-mid[a]) for a,b in zip(loop,loop[1:]+loop[:1]))/(math.pi*H)) for loop in holes]
    thickness=np.linalg.norm(points[:count]-points[count:],axis=1)/H
    tolerance=CHECK_DEFAULTS['ratio_tolerance']
    us=np.asarray(layout.get('root_us',layout['us']));theta=np.radians(layout['root_wrap_degrees'])*(us-.5)
    weights=np.asarray(d['fold_amplitude_multipliers']);centres=(np.arange(5)+.5)/5
    index=np.clip(np.searchsorted(centres,us)-1,0,3)
    blend=np.clip((us-centres[index])/(centres[index+1]-centres[index]),0,1)
    blend=(1-np.cos(math.pi*blend))/2
    envelope=weights[index]*(1-blend)+weights[index+1]*blend
    wave=envelope*np.sin(2*math.pi*d['folds']*us+layout['fold_phase_radians'])
    fit=np.r_[np.column_stack([np.ones(len(us)),np.zeros(len(us)),-np.cos(theta),-layout['root_shear']*np.sin(theta),-wave*np.cos(theta)]),
              np.column_stack([np.zeros(len(us)),np.ones(len(us)),np.zeros(len(us)),np.sin(theta),wave*np.sin(theta)])]
    profile_mid=np.einsum('nj,jk->nk',mid,np.asarray(layout['wrap_frame']));profile_root=profile_mid[layout['root_indices']]
    targets=np.r_[profile_root[:,0],profile_root[:,1]];coefficients=np.linalg.lstsq(fit,targets,rcond=None)[0]
    residual=float(np.max(abs(np.einsum('nj,j->n',fit,coefficients)-targets))/H)
    grid=layout['solid_grid_indices'];inverse={i:(r,c) for r,row in enumerate(grid) for c,i in enumerate(row) if i>=0}
    notches={}
    for side in ('far','near'):
        values=[]
        for index in outer:
            row,col=inverse.get(index,(len(grid),0))
            values.append(0<row<len(grid)-1 and mid[index,2]/H>.34 and ((0<col<len(grid[0])//2) if side=='far' else (len(grid[0])//2<col<len(grid[0])-1)))
        notches[side]=int(sum(v and not values[k-1] for k,v in enumerate(values)))
    pose=spec['mq19']['design']['pose'];roll=spec['mq19']['design']['pose_resolution']['chest_roll_degrees']
    frame=rotation([0,0,1],pose['chest_yaw_toward_viewer_degrees'])@rotation([0,1,0],pose['forward_lean_degrees'])@rotation([1,0,0],roll)
    joint_width=abs(((joints['shoulder_near']-joints['shoulder_far'])@frame)[1])
    tears=generated_tear_metrics(mid,layout,holes,H,d['holes'])
    from .profile_checks import measure as profile_measure
    if body_points is None:
        body_points={p['id']+'_render':np.asarray(p['vertices']) for p in spec['pieces']}
        body_faces={p['id']+'_render':p['faces'] for p in spec['pieces']}
    profiles=profile_measure(spec,mid,faces,joints,body_points,body_faces)
    amplitude_rows=profiles['rows'];root_us=us;root_wave=wave
    checks={'three_actual_holes':len(holes)==3,
        'nine_actual_strips':len(observed)==9,
        'elliptical_tears':len(tears)==3 and all(abs(r['aspect_ratio']-2)<=.3 and abs(r['area_ratio']-1)<=.03 and r['long_axis_from_vertical_degrees']<=10 for r in tears),
        'tear_centres_preserved':all(max(abs(v) for v in r['centroid_error_developed_over_H'])<=.002 for r in tears),
        'fold_amplitude_growth':profiles['checks']['fold_amplitude_growth'],
        'five_radial_folds':residual<=1e-6 and abs(coefficients[4]/H-d['fold_amplitude_root_over_H'])<=1e-6 and d['folds']==5,
        'back_centre_valley':abs(root_wave[np.argmin(abs(root_us-.5))]+1.2)<=1e-8,
        'root_wrap_200_degrees':layout['root_wrap_degrees']==200.,
        'exact_side_notch_counts':notches=={'far':2,'near':3},
        'linear_root_chord':abs(root_width/joint_width-d['hem_span_over_shoulders'])<=tolerance,
        'strip_widths':len(observed)==9 and all(abs(row['width_over_H']-target)<=tolerance for row,target in zip(observed,layout['physical_strip_widths_over_H'])),
        'strip_lengths':len(observed)==9 and all(abs(row['length_over_H']-target)<=tolerance for row,target in zip(observed,[v['target_length_over_H'] for v in layout['strips']])),
        'near_longest_tip':len(observed)==9 and abs(observed[-1]['tip_z_over_H']-.10)<=1e-6,
        'tips_above_sole_floor':all(row['lowest_tip_skin_over_H']>=.06-1e-7 for row in observed),
        'width_ratios_preserved':bool(np.max(abs(np.asarray(layout['physical_strip_widths_over_H'])/np.asarray(d['strip_widths_over_H'])-layout['strip_width_scale']))<=1e-9),
        'widths_and_cuts_fill_root':abs(sum(layout['physical_strip_widths_over_H'])+8*d['cut_width_over_H']-layout['root_arc_over_H'])<=1e-9,
        'thickness':bool(np.max(abs(thickness-d['thickness_over_H']))<=1e-6),
        'root_heights':bool(np.max(abs(root[:,2]/H-(.30-.03*abs(2*np.asarray(layout.get('root_us',layout['us']))-1))))<=1e-6),
        'root_near_flare':abs((root[-1,1]-joints['hip_near'][1])/L-d['near_flare_over_L'])<=tolerance,
        'shoulder_attachment':bool(np.max(abs(top/H-np.asarray(layout['attachment_over_H'])))<=1e-6)}
    from .drape_checks import ribbon_metrics
    ribbons=ribbon_metrics(spec,mid,faces,live);checks.update(ribbons['checks']);checks.update(profiles['checks'])
    checks={k:bool(v) for k,v in checks.items()}
    return {'passed':all(checks.values()),'checks':checks,'ribbon_drape':ribbons,'hole_count':len(holes),'boundary_loop_count':len(loops),
        'tears':tears,'cloth_profiles':profiles,'fold_amplitude_rows':amplitude_rows,'hole_developed_diameters_over_H':diameters,'strip_count':len(observed),'strips':observed,
        'root_transverse_width_m':root_width,'side_notch_counts':notches,
        'strip_width_scale':layout['strip_width_scale'],'root_arc_over_H':layout['root_arc_over_H'],
        'clamped_strips':[i+1 for i,v in enumerate(layout['strips']) if v['floor_clamped']],
        'measured_fold_amplitude_over_H':float(coefficients[4]/H),'fold_fit_residual_over_H':residual,'near_tip_over_H':observed[-1]['tip_z_over_H'] if observed else None}


def generated_tear_metrics(mid,layout,holes,H,targets):
    """Measure opened hole rims in developed horizontal distance and world Z.

    Missing interior grid vertices are linearly bridged only to locate the arc
    coordinate; no missing polygon is restored or counted as cloak coverage.
    """
    us=np.asarray(layout['us']);grid=layout['solid_grid_indices']
    inverse={i:(r,c) for r,row in enumerate(grid) for c,i in enumerate(row) if i>=0}
    arcs=[]
    for row in grid:
        indices=np.asarray(row);valid=indices>=0
        xyz=mid[indices[valid]]/H
        filled=np.column_stack([np.interp(us,us[valid],xyz[:,k]) for k in range(3)])
        arcs.append(np.r_[0,np.cumsum(np.linalg.norm(np.diff(filled,axis=0),axis=1))])
    rows=[]
    for loop in holes:
        # A detached ribbon creates an additional boundary loop outside the
        # solid grid. It fails hole-count/root-connectivity guards; it cannot
        # masquerade as a measurable tear or turn rejection into an exception.
        if any(i not in inverse for i in loop):continue
        mean_z=float(np.mean(mid[loop,2])/H)
        degrees,height,diameter=min(targets,key=lambda q:abs(q[1]-mean_z))
        centre_u=.5+degrees/200
        polygon=[];angles=[]
        for i in loop:
            r,c=inverse[i]
            polygon.append([arcs[r][c]-np.interp(centre_u,us,arcs[r]),mid[i,2]/H-height])
            angles.append((us[c]-.5)*200)
        polygon=np.asarray(polygon);x,z=polygon.T
        twice=x*np.roll(z,-1)-np.roll(x,-1)*z
        signed=float(twice.sum()/2);area=abs(signed)
        centroid=np.sum((polygon+np.roll(polygon,-1,axis=0))*twice[:,None],axis=0)/(6*signed)
        width=float(np.ptp(x));tall=float(np.ptp(z));expected=math.pi*(diameter/2)**2
        covariance=np.cov(polygon.T);_,vectors=np.linalg.eigh(covariance);axis=vectors[:,-1]
        tilt=math.degrees(math.atan2(abs(axis[0]),abs(axis[1])))
        rows.append({'centre_angle_degrees':degrees,'centre_height_over_H':height,
            'centroid_error_developed_over_H':centroid.tolist(),'width_over_H':width,'height_over_H':tall,
            'aspect_ratio':tall/width,'area_over_H2':area,'target_area_over_H2':expected,
            'area_ratio':area/expected,'long_axis_from_vertical_degrees':tilt})
    return rows
