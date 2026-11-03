"""Fit an unscaled closed hand to the approved fist and painted grip.

The wrist remains fixed. A sphere/orthographic intersection fixes the grip;
the remaining axial rotation is measured against the source hand silhouette.
"""
import math
import numpy as np
from spec.art_identity.maquettes.raster import triangle_samples

FIT_DEFAULTS={'twist_step_deg':5,'centroid_limit_px':5,'mass_relative_limit':.15}


def twist(axis,origin,degrees):
    axis=axis/np.linalg.norm(axis);angle=math.radians(degrees)
    cross=np.array([[0,-axis[2],axis[1]],[axis[2],0,-axis[0]],[-axis[1],axis[0],0]])
    rotation=np.eye(3)+math.sin(angle)*cross+(1-math.cos(angle))*(cross@cross)
    matrix=np.eye(4);matrix[:3,:3]=rotation;matrix[:3,3]=origin-rotation@origin
    return matrix


def fit(spec,gloves,old_wrist,wrist,old_grip,grip_px,basis,origin,source,rigid,sphere_candidates):
    plane=old_grip+np.linalg.pinv(basis)@(np.asarray(grip_px)-(origin+basis@old_grip))
    candidates=sphere_candidates(plane,wrist,np.linalg.norm(old_grip-old_wrist))
    pieces=[p for p in spec['pieces'] if p['id'] in gloves]
    ys,xs=np.nonzero(source);target_centroid=np.array([xs.mean(),ys.mean()]);row=round((ys.min()+ys.max())/2)
    target_width=int(np.ptp(np.flatnonzero(source[row]))+1)
    results=[]
    for grip in candidates:
        base=rigid(old_wrist,old_grip,wrist,grip)
        for angle in range(0,360,FIT_DEFAULTS['twist_step_deg']):
            matrix=twist(grip-wrist,wrist,angle)@base;mask=np.zeros((255,255),bool)
            for piece in pieces:
                vertices=np.asarray(piece['vertices'])@matrix[:3,:3].T+matrix[:3,3]
                projected=vertices@basis.T+origin
                for face in piece['faces']:
                    for index in range(1,len(face)-1):
                        samples=triangle_samples(projected[[face[0],face[index],face[index+1]]],255,255)
                        if samples is not None:mask[samples[0],samples[1]]=True
            y,x=np.nonzero(mask)
            if not len(x):continue
            middle=round((y.min()+y.max())/2);at=np.flatnonzero(mask[middle]);width=int(np.ptp(at)+1) if len(at) else 0
            distance=float(np.linalg.norm(np.array([x.mean(),y.mean()])-target_centroid))
            width_error=abs(width/target_width-1)
            iou=(mask&source).sum()/(mask|source).sum()
            feasible=distance<=FIT_DEFAULTS['centroid_limit_px'] and width_error<=FIT_DEFAULTS['mass_relative_limit']
            score=(not feasible, max(0,distance-5)+max(0,width_error-.15)*target_width,-iou,abs((angle+180)%360-180))
            results.append((score,matrix,grip,dict(twist_deg=angle,width_px=width,source_width_px=target_width,centroid_distance_px=distance,iou=float(iou),feasible=bool(feasible))))
    if not results:raise ValueError('No unscaled hand can reach the approved grip from this wrist')
    _,matrix,grip,receipt=min(results,key=lambda r:r[0])
    return matrix,grip,receipt
