"""A concealed .01 H vertical lap measured from existing garment hems.

The hood/scarf's last surface row and each pauldron's lower rim are physical
source landmarks. At each angular station, intersect that hem and its own
support surface; never blend a chord between unrelated garment supports.
"""
import math
from functools import lru_cache
import numpy as np
from ..forms import DOME_TOPOLOGY


def support_geometry(spec,points=None):
    H=spec['mq19']['gauge_H_m'];result=[]
    for piece in spec['pieces']:
        name=piece['id']
        if name not in ('hood_scarf','pauldron_far','pauldron_near'):continue
        v=np.asarray(piece['vertices'] if points is None else points[name+'_render'],float)/H
        count=len(v)//2
        # Scarf uses the paired cloth mid-surface; caps use the outer dome.
        if name=='hood_scarf':
            v=(v[:count]+v[count:])/2;nr,nc=9,48
            hem=v[(nr-1)*nc:nr*nc]
        else:
            v=v[:count];nc=DOME_TOPOLOGY['columns'];hem=v[-nc:]
        faces=[f for f in piece['faces'] if all(i<count for i in f)]
        triangles=np.asarray([[v[f[0]],v[f[i]],v[f[i+1]]] for f in faces for i in range(1,len(f)-1)])
        result.append((name,hem,triangles))
    return result


def hem_intersections(hem,origin,radial,tangent):
    following=np.roll(hem,-1,axis=0)
    a=(hem-origin)@tangent;b=(following-origin)@tangent
    valid=(a*b<=0)&(abs(a-b)>1e-12)
    t=a[valid]/(a[valid]-b[valid])
    points=hem[valid]+t[:,None]*(following[valid]-hem[valid])
    return [p for p in points if (p-origin)@radial>0]


def surface_intersections(triangles,origin,radial,tangent,z):
    a=triangles[:,0];e=triangles[:,1]-a;f=triangles[:,2]-a
    A=np.einsum('ij,j->i',e,tangent);B=np.einsum('ij,j->i',f,tangent);C=e[:,2];D=f[:,2]
    r=-np.einsum('ij,j->i',a-origin,tangent);s=z-a[:,2];det=A*D-B*C
    live=abs(det)>1e-12
    u=np.zeros(len(a));v=np.zeros(len(a))
    u[live]=(r[live]*D[live]-B[live]*s[live])/det[live]
    v[live]=(A[live]*s[live]-r[live]*C[live])/det[live]
    live&=(u>=-1e-9)&(v>=-1e-9)&(u+v<=1+1e-9)
    points=a[live]+u[live,None]*e[live]+v[live,None]*f[live]
    return [p for p in points if (p-origin)@radial>0]


def sampler(spec,points=None):
    H=spec['mq19']['gauge_H_m'];geometry=support_geometry(spec,points)
    near,far=(np.asarray(spec['joints']['shoulder_'+side])/H for side in ('near','far'))
    origin=(near+far)/2;origin[2]=0
    transverse=near-far;transverse[2]=0;transverse/=np.linalg.norm(transverse)
    forward=np.array([transverse[1],-transverse[0],0.])
    @lru_cache(maxsize=None)
    def sample(u):
        theta=math.radians(200)*(u-.5)
        radial=-forward*math.cos(theta)+transverse*math.sin(theta)
        tangent=forward*math.sin(theta)+transverse*math.cos(theta)
        candidates=[]
        for name,hem,triangles in geometry:
            for edge in hem_intersections(hem,origin,radial,tangent):
                z=edge[2]+.01
                hits=surface_intersections(triangles,origin,radial,tangent,z)
                if hits:
                    on=max(hits,key=lambda p:(p-origin)@radial)
                    candidates.append(((edge-origin)@radial,name,edge,on))
        if not candidates:raise ValueError('No garment supports the .01 H top lap at u='+str(u))
        _,name,edge,on=max(candidates,key=lambda c:c[0])
        return {'support':name,'hem':edge,'on_surface':on,'radial':radial}
    return sample
