"""Exact separation between rigid painted unit-pixel squares (source pixels)."""
import numpy as np

PIXEL_CORNERS = np.array([[-.5,-.5],[.5,-.5],[.5,.5],[-.5,.5]])


def gap(first, first_basis, second, second_basis):
    delta=first[:,None,:]-second[None,:,:]
    squared=np.sum(delta*delta,axis=2)
    minimum=float(np.sqrt(squared.min()))
    if minimum > 0:
        # A unit square lies within sqrt(2)/2 of its centre. Pairs farther
        # than this bound cannot improve the smallest possible separation.
        candidates=np.argwhere(squared <= (minimum + np.sqrt(2.))**2)
    else:
        return 0.
    a=first[candidates[:,0],None,:]+PIXEL_CORNERS[None,:,:]@first_basis.T
    b=second[candidates[:,1],None,:]+PIXEL_CORNERS[None,:,:]@second_basis.T
    result=np.full(len(a),np.inf)
    separated=np.zeros(len(a),dtype=bool)
    for poly in (a,b):
        for edge in range(2):
            vector=poly[:,(edge+1)%4]-poly[:,edge]
            axis=np.column_stack((-vector[:,1],vector[:,0]))
            pa=np.sum(a*axis[:,None,:],axis=2);pb=np.sum(b*axis[:,None,:],axis=2)
            separated |= (pa.max(1)<pb.min(1)) | (pb.max(1)<pa.min(1))
    if np.any(~separated):return 0.
    for points,edges in ((a,b),(b,a)):
        for edge in range(4):
            start=edges[:,edge];vector=edges[:,(edge+1)%4]-start
            distance=points-start[:,None,:]
            u=np.clip(np.sum(distance*vector[:,None,:],axis=2)/np.sum(vector*vector,axis=1)[:,None],0.,1.)
            residual=distance-u[:,:,None]*vector[:,None,:]
            result=np.minimum(result,np.sqrt(np.min(np.sum(residual*residual,axis=2),axis=1)))
    return float(result.min())
