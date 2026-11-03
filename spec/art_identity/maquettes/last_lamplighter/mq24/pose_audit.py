"""Independent permitted-pose search from measured finger disks and wire.

Uses polygon parity on recovered geometry, not the constructor's analytic
finger inequalities or its pose diagnostics. Axial travel is vectorized;
each ring-plane crossing retains its sign and upper/lower-arc identity.
"""
import numpy as np
from .oracle import digit_path
from .measure import palm_axes

SEARCH_DEFAULTS={'roll_samples':401,'offset_samples':201}


def in_polygon(x,y,polygon):
    inside=np.zeros(np.shape(y),bool)
    for a,b in zip(polygon,np.roll(polygon,-1,axis=0)):
        if a[1]==b[1]:continue
        crossing=((a[1]>y)!=(b[1]>y))&(x<(b[0]-a[0])*(y-a[1])/(b[1]-a[1])+a[0])
        inside ^= crossing
    return inside


def inspect(points,joints,H,c):
    rule=c['feedback1_rules']['near_hand'];samples=c['measurement']['sweep_samples']
    wrist=np.asarray(joints['hand_near']);axis=wrist-joints['elbow_near'];axis/=np.linalg.norm(axis)
    axes,_,_=palm_axes(points['palm_near']);normal=axes[0]-axis*np.dot(axes[0],axis);normal/=np.linalg.norm(normal);width=np.cross(axis,normal)
    palm=np.asarray(points['palm_near']).reshape(13,24,3);centre=(palm[0].mean(0)+palm[-1].mean(0))/2
    reference_offset=float(np.dot(centre-wrist,axis)/H-rule['palm_centre_along_forearm_over_H'])
    wire=np.asarray(points['grip_ring']);toward=wire[np.argmax(wire[:,2])]-wrist
    base=toward-axis*np.dot(toward,axis);base/=np.linalg.norm(base)
    reference_roll=np.degrees(np.arctan2(np.dot(normal,np.cross(axis,base)),np.dot(normal,base)))
    ring=(wire.reshape(-1,samples,3).mean(1)[:-1]-wrist)/H;ring_centre=ring.mean(0)
    paths=[(digit_path(points['finger_near_'+str(k)],3,False,samples)[0]-wrist)/H for k in range(4)]
    polygons=[np.column_stack((path@normal,path@axis)) for path in paths];laterals=[float(np.mean(path@width)) for path in paths]
    limit=rule['maximum_palm_offset_adjustment_over_H'];offsets=np.linspace(-limit,limit,SEARCH_DEFAULTS['offset_samples']);maximum=0;contained=0;upper_axial=[]
    for roll in np.linspace(-rule['maximum_wrist_roll_degrees'],rule['maximum_wrist_roll_degrees'],SEARCH_DEFAULTS['roll_samples']):
        angle=np.radians(roll-reference_roll);n=normal*np.cos(angle)+width*np.sin(angle);w=width*np.cos(angle)-normal*np.sin(angle);links=np.zeros(len(offsets),int)
        for polygon,lateral in zip(polygons,laterals):
            distances=ring@w-lateral;following=np.roll(distances,-1);signed=np.zeros(len(offsets),int);upper=np.zeros(len(offsets),bool)
            for k in np.flatnonzero((distances>0)!=(following>0)):
                t=distances[k]/(distances[k]-following[k]);q=ring[k]+t*(ring[(k+1)%len(ring)]-ring[k])
                inside=in_polygon(float(q@n),float(q@axis)-offsets+reference_offset,polygon)
                signed+=inside*(1 if following[k]>distances[k] else -1)
                if q[2]>ring_centre[2]:upper|=inside;upper_axial.append(float(q@axis))
            links+=(abs(signed)==1)&upper
        maximum=max(maximum,int(links.max()));contained+=int((links==4).sum())
    return {'scope':'all permitted sampled poses; measured polygons, independent parity test',
        'candidate_count':SEARCH_DEFAULTS['roll_samples']*SEARCH_DEFAULTS['offset_samples'],
        'four_loop_containment_candidates':contained,'maximum_upper_loops_linked':maximum,
        'upper_ring_crossing_axial_range_over_H':[min(upper_axial),max(upper_axial)],
        'lowest_possible_finger_disk_axial_coordinate_over_H':float(min(p[:,1].min() for p in polygons)-limit-reference_offset)}
