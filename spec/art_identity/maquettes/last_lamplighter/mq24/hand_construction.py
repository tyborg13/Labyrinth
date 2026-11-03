"""Construct director-authored hand rules in the retained forearm frames.

All axes, stations and numerical searches are implementation. Visible lengths,
radii, curls and allowed palm travel are supplied by design_details.json.
"""
import numpy as np

CONSTRUCTION_DEFAULTS={'frame_epsilon':1e-10}


def unit(v):
    length=np.linalg.norm(v)
    if length<=CONSTRUCTION_DEFAULTS['frame_epsilon']:raise ValueError('Degenerate hand frame')
    return v/length


def frame(spec,side):
    j=spec['joints'];a=unit(np.asarray(j['hand_'+side])-j['elbow_'+side])
    normal=np.array([-1.,0,0]);normal=unit(normal-a*np.dot(normal,a))
    if side=='near':
        ring=np.asarray(next(p['vertices'] for p in spec['pieces'] if p['id']=='grip_ring'))
        toward=ring[np.argmax(ring[:,2])]-np.asarray(j['hand_near'])
        normal=unit(toward-a*np.dot(toward,a))
    return np.array([normal,unit(np.cross(a,normal)),a])


def thumb_root(axes,rule):
    depth,width,length=np.asarray(rule['palm_dimensions_over_H'])/2
    z=rule['thumb_root_from_wrist_end_over_H']-rule['palm_centre_along_forearm_over_H']
    section=np.sqrt(max(0,1-(z/length)**2))
    direction=np.array([1.,0,0])@axes[:2].T
    radii=np.array([depth,width])*section
    local=radii*radii*direction/np.linalg.norm(radii*direction)
    return local@axes[:2]+axes[2]*rule['thumb_root_from_wrist_end_over_H']


def bent_path(root,axes,lengths,curls,fan=0):
    normal,lateral,longitudinal=axes;fan=np.radians(fan)
    plane=np.sin(fan)*lateral+np.cos(fan)*longitudinal
    path=[np.asarray(root,float)];total=0
    for length,curl in zip(lengths,curls):
        total+=curl;angle=np.radians(total)
        path.append(path[-1]+length*(np.sin(angle)*normal+np.cos(angle)*plane))
    return np.asarray(path)


def build(spec,side,rule):
    if side=='near':
        from .fist_construction import build as fist
        return fist(spec,rule)
    axes=frame(spec,side);a=axes[2];centre=rule['palm_centre_along_forearm_over_H']*a
    half_length=rule['palm_dimensions_over_H'][2]/2;half_width=rule['palm_dimensions_over_H'][1]/2
    fingers=[]
    for k,lateral in enumerate(np.linspace(-half_width,half_width,4)):
        root=centre+a*half_length*np.sqrt(max(0,1-(lateral/half_width)**2))+lateral*axes[1]
        path=bent_path(root,axes,np.asarray(rule['segment_proportions'])*rule['finger_length_over_H'],rule['curl_degrees'],rule['fan_degrees'][k])
        fingers.append({'path_over_H':path.tolist(),'radii_over_H':rule['radii_over_H']})
    root=thumb_root(axes,rule)
    thumb=bent_path(root,axes,rule['thumb_segment_lengths_over_H'],rule['thumb_curl_degrees'],rule['fan_degrees'][0]+rule['thumb_inward_degrees'])
    return {'palm':{'centre_over_H':centre.tolist(),'axes':axes.tolist(),'radii_over_H':(np.asarray(rule['palm_dimensions_over_H'])/2).tolist()},
        'fingers':fingers,'thumb':{'path_over_H':thumb.tolist(),'radii_over_H':rule['thumb_radii_over_H']}},{}
