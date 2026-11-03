"""Exact triangle-surface gap with conservative AABB pruning.

Vertices, interior edge pairs and segment/face crossings are all tested.
The broad phase only discards pairs whose lower bound exceeds an already
measured upper bound. Sampling a wire's vertices alone can miss contact.
"""
import numpy as np

NUMERICAL_DEFAULTS={'pair_batch_size':256}


def dot(a,b):return np.einsum('ij,ij->i',a,b)


def point_squared(p,t):
    a,b,c=t[:,0],t[:,1],t[:,2];normal=np.cross(b-a,c-a);area2=dot(normal,normal)
    signed=dot(p-a,normal);projection=p-np.divide(signed,area2,out=np.zeros(len(t)),where=area2>0)[:,None]*normal
    on=area2>0
    for start,end in ((a,b),(b,c),(c,a)):on &= dot(np.cross(end-start,projection-start),normal)>=0
    result=np.where(on,np.divide(signed*signed,area2,out=np.zeros(len(t)),where=area2>0),np.inf)
    for start,end in ((a,b),(b,c),(c,a)):
        direction=end-start;den=dot(direction,direction)
        fraction=np.divide(dot(p-start,direction),den,out=np.zeros(len(t)),where=den>0)
        delta=p-start-np.clip(fraction,0,1)[:,None]*direction;result=np.minimum(result,dot(delta,delta))
    return result


def pierces(start,end,t,epsilon):
    direction=end-start;e1=t[:,1]-t[:,0];e2=t[:,2]-t[:,0];p=np.cross(direction,e2);det=dot(e1,p)
    valid=abs(det)>epsilon;inverse=np.divide(1,det,out=np.zeros(len(t)),where=valid)
    delta=start-t[:,0];u=dot(delta,p)*inverse;q=np.cross(delta,e1);v=dot(direction,q)*inverse;fraction=dot(e2,q)*inverse
    return valid&(u>=-epsilon)&(v>=-epsilon)&(u+v<=1+epsilon)&(fraction>=-epsilon)&(fraction<=1+epsilon)


def pair_squared(first,second,epsilon):
    result=np.full(len(first),np.inf)
    for k in range(3):
        result=np.minimum(result,point_squared(first[:,k],second));result=np.minimum(result,point_squared(second[:,k],first))
        result[pierces(first[:,k],first[:,(k+1)%3],second,epsilon)]=0
        result[pierces(second[:,k],second[:,(k+1)%3],first,epsilon)]=0
    for k in range(3):
        a=first[:,k];u=first[:,(k+1)%3]-a
        for j in range(3):
            b=second[:,j];v=second[:,(j+1)%3]-b;w=a-b
            aa=dot(u,u);bb=dot(u,v);cc=dot(v,v);dd=dot(u,w);ee=dot(v,w);den=aa*cc-bb*bb
            valid=den>0;s=np.divide(bb*ee-cc*dd,den,out=np.zeros(len(first)),where=valid);t=np.divide(aa*ee-bb*dd,den,out=np.zeros(len(first)),where=valid)
            valid &= (s>=0)&(s<=1)&(t>=0)&(t<=1)
            delta=w+s[:,None]*u-t[:,None]*v;result=np.minimum(result,np.where(valid,dot(delta,delta),np.inf))
    return result


def nearest_distance(first,second,epsilon):
    first=np.asarray(first,float);second=np.asarray(second,float)
    a=np.unique(first.reshape(-1,3),axis=0);b=np.unique(second.reshape(-1,3),axis=0)
    best=float(np.min(np.sum((a[:,None]-b[None,:])**2,axis=2)))
    if best==0:return 0.
    separation=np.maximum(np.maximum(first.min(1)[:,None]-second.max(1)[None,:],second.min(1)[None,:]-first.max(1)[:,None]),0)
    lower=np.sum(separation**2,axis=2);i,j=np.nonzero(lower<=best);order=np.argsort(lower[i,j]);i=i[order];j=j[order]
    batch=NUMERICAL_DEFAULTS['pair_batch_size']
    for start in range(0,len(i),batch):
        x=i[start:start+batch];y=j[start:start+batch];keep=lower[x,y]<=best
        if not keep.any():break
        best=min(best,float(pair_squared(first[x[keep]],second[y[keep]],epsilon).min()))
        if best==0:break
    return float(np.sqrt(best))
