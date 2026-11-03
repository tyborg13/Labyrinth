"""Bounded closed-channel fist seating and two-joint thumb contact solve.

Only axial hand travel and wrist roll are pose variables. An infeasible solve
is reported without moving the ring, changing finger lengths or stretching a
limb. The signed crossing prefilter checks every permitted sampled pose.
"""
import numpy as np
from spec.art_identity.maquettes.raster import camera
from .hand_construction import frame,thumb_root,bent_path
from spec.art_identity.maquettes.blender.closed_loft import sweep
from .contact import triangles,ray_hits

SOLVER_DEFAULTS={'roll_samples':401,'offset_samples':201,'thumb_segment_samples':101,
    'thumb_root_angle_samples':121,'epsilon':1e-9,'contact_residual_tolerance_over_H':.0001}


def ring_geometry(spec):
    H=spec['mq18']['height_m'];origin=np.asarray(spec['joints']['hand_near'])
    v=np.asarray(next(p['vertices'] for p in spec['pieces'] if p['id']=='grip_ring'))
    rings=(v-origin).reshape(-1,12,3)/H;centres=rings.mean(1)
    radius=float(np.linalg.norm(rings-centres[:,None],axis=2).max())
    return centres[:-1],radius


def rolled(axes,degrees):
    angle=np.radians(degrees);n,w,a=axes
    return np.array([n*np.cos(angle)+w*np.sin(angle),w*np.cos(angle)-n*np.sin(angle),a])


def upper_crossing(ring,width_axis,lateral):
    distances=ring@width_axis-lateral;next_d=np.roll(distances,-1)
    selected=np.flatnonzero((distances>0)!=(next_d>0));points=[]
    for k in selected:
        t=distances[k]/(distances[k]-next_d[k]);points.append(ring[k]+t*(ring[(k+1)%len(ring)]-ring[k]))
    return max(points,key=lambda p:p[2]) if points else None


def seat(spec,rule):
    base=frame(spec,'near');ring,_=ring_geometry(spec)
    lateral=(np.arange(4)-1.5)*rule['finger_spacing_over_H'];half_width=rule['palm_dimensions_over_H'][1]/2;half_length=rule['palm_dimensions_over_H'][2]/2
    roots=rule['palm_centre_along_forearm_over_H']+half_length*np.sqrt(1-(lateral/half_width)**2)
    proximal,middle,distal=np.asarray(rule['segment_proportions'])*rule['finger_length_over_H']
    offsets=np.linspace(-rule['maximum_palm_offset_adjustment_over_H'],rule['maximum_palm_offset_adjustment_over_H'],SOLVER_DEFAULTS['offset_samples'])
    preferred=rule['preferred_pose'];best=None;contained_count=0;max_links=0;crossing_axis=[]
    for roll in np.linspace(-rule['maximum_wrist_roll_degrees'],rule['maximum_wrist_roll_degrees'],SOLVER_DEFAULTS['roll_samples']):
        axes=rolled(base,roll);normal,width,axis=axes;links=np.zeros(len(offsets),int)
        for k,l in enumerate(lateral):
            distances=ring@width-l;following=np.roll(distances,-1);signed=np.zeros(len(offsets),int);upper=np.zeros(len(offsets),bool)
            for j in np.flatnonzero((distances>0)!=(following>0)):
                fraction=distances[j]/(distances[j]-following[j]);q=ring[j]+fraction*(ring[(j+1)%len(ring)]-ring[j])
                x=float(q@normal);y=roots[k]+offsets-float(q@axis)
                inside=(y>0)&(y<middle)&(x>y*(proximal-distal)/middle)&(x<proximal)
                signed+=inside*(1 if following[j]>distances[j] else -1)
                if q[2]>ring[:,2].mean():upper|=inside;crossing_axis.append(float(q@axis))
            links+=(abs(signed)==1)&upper
        contained_count+=int((links==4).sum());max_links=max(max_links,int(links.max()))
        # With no contained pose there is no accepted solution to score by
        # clearance. Retain the director's preferred pose among equal links.
        motion=abs(offsets-preferred['palm_offset_adjustment_over_H'])/rule['maximum_palm_offset_adjustment_over_H']+abs(float(roll)-preferred['wrist_roll_degrees'])/rule['maximum_wrist_roll_degrees']
        indices=np.flatnonzero(links==links.max());i=int(indices[np.argmin(motion[indices])])
        key=(-int(links[i]),float(motion[i]))
        if best is None or key<best[0]:best=(key,float(offsets[i]),float(roll),axes)
    _,offset,roll,axes=best
    return axes,offset,{'palm_offset_adjustment_over_H':offset,'wrist_roll_degrees':roll,
        'candidate_count':SOLVER_DEFAULTS['roll_samples']*SOLVER_DEFAULTS['offset_samples'],
        'containment_candidates':contained_count,'maximum_upper_loops_linked':max_links,
        'upper_ring_crossing_axial_range_over_H':[min(crossing_axis),max(crossing_axis)],
        'lowest_finger_disk_axial_coordinate_over_H':float(min(roots)-rule['maximum_palm_offset_adjustment_over_H']-middle),
        'pose_status':'contained candidate; live surface gates still required' if contained_count else 'no contained pose; director preferred diagnostic retained'}


def thumb(root,paths,axes,rule,spec):
    n,w,a=axes;length=rule['thumb_length_over_H'];target=min(range(4),key=lambda k:np.linalg.norm(paths[k][0]-root))
    front=camera(spec,'front')[2][2];outside=n*(1 if np.dot(n,front)>0 else -1)
    vertices,faces,_=sweep(paths[target],rule['radii_over_H'],12)
    middle_mesh=triangles(vertices,[f for f in faces if min(f)>=12 and max(f)<36])
    best=None
    for t in np.linspace(0,1,SOLVER_DEFAULTS['thumb_segment_samples']):
        middle=paths[target][1]*(1-t)+paths[target][2]*t
        hits=ray_hits(middle,outside,middle_mesh,SOLVER_DEFAULTS['epsilon'])
        if not len(hits):continue
        surface=middle+outside*max(hits)
        # Using the actual faceted surface avoids treating the mitered joint
        # cross-section as a full-radius capsule. A blunt tip's support in
        # this direction is at most its radius, so the director's 0.001–
        # 0.004 H range includes the entire cap at this minimum-gap target.
        for gap in (rule['thumb_clearance_over_H'][0],):
            tip=surface+outside*(rule['thumb_radii_over_H'][-1]+gap);delta=tip-root;distance=np.linalg.norm(delta)
            if not SOLVER_DEFAULTS['epsilon']<distance<length:continue
            normal_component=np.dot(delta,n);plane=delta-normal_component*n;plane_length=np.linalg.norm(plane)
            if plane_length<SOLVER_DEFAULTS['epsilon']:continue
            plane/=plane_length
            for alpha in np.linspace(0,rule['thumb_joint_max_degrees'],SOLVER_DEFAULTS['thumb_root_angle_samples']):
                angle=np.radians(alpha);first=n*np.sin(angle)+plane*np.cos(angle)
                denominator=2*(length-np.dot(delta,first))
                if denominator<=0:continue
                l1=(length*length-distance*distance)/denominator;l2=length-l1
                if min(l1,l2)<=SOLVER_DEFAULTS['epsilon']:continue
                second=(delta-l1*first)/l2;curl=np.degrees(np.arccos(np.clip(np.dot(first,second),-1,1)))
                if curl>rule['thumb_joint_max_degrees']+SOLVER_DEFAULTS['epsilon']:continue
                beta=np.degrees(np.arctan2(np.dot(second,n),np.dot(second,plane)))
                if beta<alpha-SOLVER_DEFAULTS['epsilon']:continue
                key=(-min(l1,l2),abs(t-.5),gap,alpha)
                if best is None or key<best[0]:best=(key,np.array([root,root+l1*first,tip]),[float(alpha),float(curl)],[float(l1),float(l2)])
    if best:return best[1],{'contact_solution':True,'target_finger_index':target,'joint_degrees':best[2],'segment_lengths_over_H':best[3],'clearance_over_H':float(best[0][2])}
    # Preserve exact thumb length and the existing rest direction if the
    # bounded articulation cannot reach. This remains a failed contact.
    path=bent_path(root,axes,[length/2,length/2],[rule['thumb_joint_max_degrees']]*2)
    return path,{'contact_solution':False,'target_finger_index':target,'joint_degrees':[rule['thumb_joint_max_degrees']]*2,'segment_lengths_over_H':[length/2,length/2]}


def build(spec,rule):
    axes,offset,diagnostics=seat(spec,rule);n,w,a=axes;centre=a*(rule['palm_centre_along_forearm_over_H']+offset)
    half_length=rule['palm_dimensions_over_H'][2]/2;half_width=rule['palm_dimensions_over_H'][1]/2;paths=[]
    for lateral in (np.arange(4)-1.5)*rule['finger_spacing_over_H']:
        root=centre+a*half_length*np.sqrt(1-(lateral/half_width)**2)+lateral*w
        paths.append(bent_path(root,axes,np.asarray(rule['segment_proportions'])*rule['finger_length_over_H'],rule['curl_degrees']))
    root=thumb_root(axes,rule)+offset*a;thumb_path,diagnostics['thumb']=thumb(root,paths,axes,rule,spec)
    lengths=np.asarray(rule['segment_proportions'])*rule['finger_length_over_H']
    diagnostics['distal_to_palm_gap_lower_bound_over_H']=float(max(0,lengths[0]-lengths[2]-rule['palm_dimensions_over_H'][0]/2-rule['radii_over_H'][-1]))
    return {'palm':{'centre_over_H':centre.tolist(),'axes':axes.tolist(),'radii_over_H':(np.asarray(rule['palm_dimensions_over_H'])/2).tolist()},
        'fingers':[{'path_over_H':p.tolist(),'radii_over_H':rule['radii_over_H']} for p in paths],
        'thumb':{'path_over_H':thumb_path.tolist(),'radii_over_H':rule['thumb_radii_over_H']}},diagnostics
