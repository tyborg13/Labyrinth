"""Feedback-1 numeric checks, recovered from live geometry, pinned targets."""
import numpy as np
from .oracle import angle,digit_path
from .measure import palm_axes

# The maquette's established body front is +X. This is a coordinate reference,
# not a palm-constructor axis or a target recovered from the candidate hand.
BODY_BACKWARD_AXIS=(-1.,0.,0.)


def inspect(points,joints,H,c,row,checks):
    rules=c['feedback1_rules'];samples=c['measurement']['sweep_samples'];angular=c['measurement']['angle_tolerance_degrees'];metric=c['measurement']['metric_tolerance_over_H']
    observed={}
    for side in ('far','near'):
        rule=rules[side+'_hand'];axes,length,width=palm_axes(points['palm_'+side]);palm=np.asarray(points['palm_'+side]).reshape(13,24,3)
        centre=(palm[0].mean(0)+palm[-1].mean(0))/2;wrist=np.asarray(joints['hand_'+side]);axis=wrist-joints['elbow_'+side];axis/=np.linalg.norm(axis)
        along=np.dot(centre-wrist,axis)/H;offset=along-rule['palm_centre_along_forearm_over_H']
        row(side+'_palm_length_rule',length/H,rule['palm_dimensions_over_H'][2]);row(side+'_palm_width_rule',width/H,rule['palm_dimensions_over_H'][1])
        row(side+'_palm_depth_rule',np.linalg.norm(palm[6,0]-palm[6,12])/H,rule['palm_dimensions_over_H'][0])
        row(side+'_palm_axis_rule',angle(axes[2],axis),0,angular)
        row(side+'_palm_transverse_offset',np.linalg.norm(centre-wrist-axis*along*H)/H,0)
        if side=='far':
            row('far_palm_centre_rule',along,rule['palm_centre_along_forearm_over_H'])
            backward=np.asarray(BODY_BACKWARD_AXIS);normal=backward-axis*np.dot(backward,axis)
            normal/=np.linalg.norm(normal)
            normal_angle=angle(axes[0],normal)
            row('far_palm_backward_normal_degrees',normal_angle,0,angular)
            observed.update(far_palm_normal=axes[0].tolist(),far_body_backward_forearm_normal=normal.tolist(),
                far_palm_backward_normal_degrees=normal_angle)
        else:
            checks['near_palm_offset_within_limit']=abs(offset)<=rule['maximum_palm_offset_adjustment_over_H']+metric
            ring=np.asarray(points['grip_ring']);toward=ring[np.argmax(ring[:,2])]-wrist
            normal=toward-axis*np.dot(toward,axis);normal/=np.linalg.norm(normal);width_ref=np.cross(axis,normal)
            roll=float(np.degrees(np.arctan2(np.dot(axes[0],width_ref),np.dot(axes[0],normal))))
            checks['near_wrist_roll_within_limit']=abs(roll)<=rule['maximum_wrist_roll_degrees']+angular
            observed.update(palm_offset_adjustment_over_H=float(offset),wrist_roll_degrees=roll)
        for k in range(4):
            name='finger_'+side+'_'+str(k);path,radii=digit_path(points[name],3,side=='far',samples)
            lengths=np.linalg.norm(np.diff(path,axis=0),axis=1)/H
            for q,(value,ratio) in enumerate(zip(lengths,rule['segment_proportions'])):row(name+'_segment_'+str(q),value,rule['finger_length_over_H']*ratio)
            for q,(value,target) in enumerate(zip(radii/H,rule['radii_over_H'])):row(name+'_radius_'+str(q),value,target)
            lateral=np.dot(path[0]-centre,axes[1])/H
            expected=np.linspace(-width/H/2,width/H/2,4)[k] if side=='far' else (k-1.5)*rule['finger_spacing_over_H']
            row(name+'_root_lateral',lateral,expected)
            local=(path[1]-path[0])@axes.T
            if side=='far':row(name+'_fan_rule',np.degrees(np.arctan2(local[1],local[2])),rule['fan_degrees'][k],angular)
        thumb,radii=digit_path(points['thumb_'+side],2,side=='far',samples)
        for q,(value,target) in enumerate(zip(radii/H,rule['thumb_radii_over_H'])):row(side+'_thumb_radius_'+str(q),value,target)
        row(side+'_thumb_root_along_forearm',np.dot(thumb[0]-wrist,axis)/H,rule['thumb_root_from_wrist_end_over_H']+offset)
        if side=='far':
            for q,(value,target) in enumerate(zip(np.linalg.norm(np.diff(thumb,axis=0),axis=1)/H,rule['thumb_segment_lengths_over_H'])):row('far_thumb_segment_'+str(q),value,target)
            local=(thumb[1]-thumb[0])@axes.T
            row('far_thumb_root_curl',np.degrees(np.arctan2(local[0],np.linalg.norm(local[1:]))),rule['thumb_curl_degrees'][0],angular)
        else:row('near_thumb_length',np.linalg.norm(np.diff(thumb,axis=0),axis=1).sum()/H,rule['thumb_length_over_H'])
    return observed
