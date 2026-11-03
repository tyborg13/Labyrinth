"""Resize round sections without moving an approved sweep's centre path."""
import numpy as np

from .forms import TOPOLOGY


def resize(vertices,diameter,profile='maximum'):
    rings=np.asarray(vertices,float).reshape(-1,TOPOLOGY['sweep_samples'],3)
    centers=rings.mean(axis=1,keepdims=True);offsets=rings-centers
    diameters=np.linalg.norm(rings[:,:6]-rings[:,6:],axis=2).max(axis=1)
    if profile=='maximum':offsets*=diameter/diameters.max()
    elif profile=='constant':
        # Re-normalize opposite pairs: rounded source tips can be very small,
        # and magnifying their quantization must not make an oval section.
        half=TOPOLOGY['sweep_samples']//2
        directions=rings[:,:half]-rings[:,half:]
        directions/=np.linalg.norm(directions,axis=2)[:,:,None]
        offsets=np.concatenate([directions,-directions],axis=1)*diameter/2
    else:raise ValueError(profile)
    return np.round(centers+offsets,TOPOLOGY['coordinate_digits']).reshape(-1,3).tolist()


def centers(vertices):
    return np.asarray(vertices,float).reshape(-1,TOPOLOGY['sweep_samples'],3).mean(axis=1)


def diameter(vertices):
    rings=np.asarray(vertices,float).reshape(-1,TOPOLOGY['sweep_samples'],3)
    return float(np.linalg.norm(rings[:,:6]-rings[:,6:],axis=2).max())
