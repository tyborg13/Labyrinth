"""Opt-in pose transforms for authored closed surfaces; never scales a part."""
from copy import deepcopy
import numpy as np


def transform(points, operation):
    values=np.asarray(points,float)
    if 'height_offsets' in operation:
        stations=np.asarray(operation['height_offsets'],float)
        if stations.ndim!=2 or stations.shape[1]!=4 or np.any(np.diff(stations[:,0])<=0):
            raise ValueError('Pose height offsets need ascending Z stations')
        return values+np.stack([np.interp(values[...,2],stations[:,0],stations[:,i]) for i in (1,2,3)],axis=-1)
    matrix=np.asarray(operation['matrix'],float)
    if matrix.shape!=(4,4) or not np.allclose(matrix[3],[0,0,0,1]) or not np.allclose(matrix[:3,:3].T@matrix[:3,:3],np.eye(3)) or not np.isclose(np.linalg.det(matrix[:3,:3]),1):
        raise ValueError('Surface pose must be a proper rigid transform without scaling')
    return np.einsum("...i,ji->...j",values,matrix[:3,:3])+matrix[:3,3]


def apply(spec, pose):
    result=deepcopy(spec);pieces={p['id']:p for p in result['pieces']}
    for name,offset in pose['joint_offsets_m'].items():
        if name not in result['joints']:raise ValueError('Unknown posed joint: '+name)
        result['joints'][name]=(np.asarray(result['joints'][name])+offset).tolist()
    for operation in pose['operations']:
        for name in operation['pieces']:
            if name not in pieces:raise ValueError('Unknown posed surface: '+name)
            piece=pieces[name]
            for key in ('vertices','path','outline_3d'):
                if key in piece:piece[key]=transform(piece[key],operation).tolist()
    return result


def point(pose, name, value):
    for operation in pose['operations']:
        if name in operation['pieces']:value=transform(value,operation)
    return np.asarray(value)
