"""Surface contact and angular wrapping from opened hand/hilt meshes.

Topology counts are proof conventions, not construction targets. No hashes or
authoring grip radius/positions are used to decide contact.
"""
import math
import numpy as np

PROBE_DEFAULTS={'sweep_ring_vertices':12,'degeneracy_epsilon':1e-24,'division_epsilon':1e-30}


def triangles(vertices,faces):
    return np.asarray([vertices[[face[0],face[k],face[k+1]]]
                       for face in faces for k in range(1,len(face)-1)])


def radial_minimum(vertices,faces,origin,axis,low,high):
    """Minimum axis distance on actual polygon surfaces within the hilt span.

    Clip each polygon to the finite axial slab before projecting. A polygon
    enclosing the axis has zero distance, even if all its vertices miss it.
    """
    helper=np.eye(3)[np.argmin(abs(axis))];x=np.cross(axis,helper);x/=np.linalg.norm(x)
    y=np.cross(axis,x);local=vertices-origin
    local=np.column_stack((local@x,local@y,local@axis));minimum=float('inf')
    for face in faces:
        polygon=[local[k] for k in face]
        for bound,sign in ((low,1),(high,-1)):
            clipped=[]
            for a,b in zip(polygon,polygon[1:]+polygon[:1]):
                inside_a=sign*(a[2]-bound)>=0;inside_b=sign*(b[2]-bound)>=0
                if inside_a:clipped.append(a)
                if inside_a!=inside_b:clipped.append(a+(b-a)*(bound-a[2])/(b[2]-a[2]))
            polygon=clipped
            if not polygon:break
        if len(polygon)<3:continue
        v=np.asarray(polygon)[:,:2];a=v;b=np.roll(v,-1,axis=0);edge=b-a
        cross=edge[:,0]*(-a[:,1])-edge[:,1]*(-a[:,0])
        area=abs(np.sum(a[:,0]*b[:,1]-a[:,1]*b[:,0]))
        if area>PROBE_DEFAULTS['degeneracy_epsilon'] and (np.all(cross>=0) or np.all(cross<=0)):return 0.
        denominator=np.sum(edge*edge,axis=1)
        t=np.clip(-np.sum(a*edge,axis=1)/np.maximum(denominator,PROBE_DEFAULTS['division_epsilon']),0,1)
        minimum=min(minimum,float(np.linalg.norm(a+t[:,None]*edge,axis=1).min()))
    return minimum


def point_surface_distance(points,tris):
    """Vertex/face and vertex/edge distances (both directions at call site)."""
    a,b,c=tris[:,0],tris[:,1],tris[:,2];ab=b-a;ac=c-a
    normal=np.cross(ab,ac);n2=np.sum(normal*normal,axis=1)
    delta=points[:,None,:]-a;plane=np.sum(delta*normal,axis=2)/np.maximum(n2,PROBE_DEFAULTS['division_epsilon'])
    projected=delta-plane[:,:,None]*normal
    d00=np.sum(ab*ab,axis=1);d01=np.sum(ab*ac,axis=1);d11=np.sum(ac*ac,axis=1)
    d20=np.sum(projected*ab,axis=2);d21=np.sum(projected*ac,axis=2)
    denom=np.maximum(d00*d11-d01*d01,PROBE_DEFAULTS['division_epsilon'])
    u=(d11*d20-d01*d21)/denom;v=(d00*d21-d01*d20)/denom
    inside=(u>=0)&(v>=0)&(u+v<=1)&(n2>PROBE_DEFAULTS['degeneracy_epsilon'])
    best=float(np.where(inside,plane*plane*n2,np.inf).min())
    for start,end in ((a,b),(b,c),(c,a)):
        edge=end-start;delta=points[:,None,:]-start
        t=np.clip(np.sum(delta*edge,axis=2)/np.maximum(np.sum(edge*edge,axis=1),PROBE_DEFAULTS['division_epsilon']),0,1)
        best=min(best,float(np.sum((delta-t[:,:,None]*edge)**2,axis=2).min()))
    return math.sqrt(best)


def surface_gap(a,af,b,bf):
    # Include edge/edge closest points, which vertex-only probes miss.
    edges=lambda q,f:np.asarray([q[[i,j]] for face in f for i,j in zip(face,face[1:]+face[:1])])
    ea=edges(a,af);eb=edges(b,bf);u=ea[:,1]-ea[:,0];v=eb[:,1]-eb[:,0]
    def intersects(edges,tris):
        direction=edges[:,1]-edges[:,0];edge1=tris[:,1]-tris[:,0];edge2=tris[:,2]-tris[:,0]
        cross=np.cross(direction[:,None,:],edge2);det=np.sum(edge1*cross,axis=2)
        inverse=np.divide(1.,det,out=np.zeros_like(det),where=abs(det)>PROBE_DEFAULTS['degeneracy_epsilon'])
        offset=edges[:,None,0]-tris[:,0];u=np.sum(offset*cross,axis=2)*inverse
        q=np.cross(offset,edge1);v=np.sum(direction[:,None,:]*q,axis=2)*inverse
        t=np.sum(edge2*q,axis=2)*inverse
        return np.any((abs(det)>PROBE_DEFAULTS['degeneracy_epsilon'])&(u>=0)&(v>=0)&(u+v<=1)&(t>=0)&(t<=1))
    ta=triangles(a,af);tb=triangles(b,bf)
    if intersects(ea,tb) or intersects(eb,ta):return 0.
    w=ea[:,None,0]-eb[None,:,0]
    aa=np.sum(u*u,axis=1)[:,None];bb=np.einsum('ik,jk->ij',u,v);cc=np.sum(v*v,axis=1)[None,:]
    dd=np.sum(u[:,None,:]*w,axis=2);ee=np.sum(v[None,:,:]*w,axis=2)
    denominator=aa*cc-bb*bb
    s=np.divide(bb*ee-cc*dd,denominator,out=np.zeros_like(dd),where=denominator>PROBE_DEFAULTS['degeneracy_epsilon'])
    t=np.divide(aa*ee-bb*dd,denominator,out=np.zeros_like(dd),where=denominator>PROBE_DEFAULTS['degeneracy_epsilon'])
    valid=(s>=0)&(s<=1)&(t>=0)&(t<=1)&(denominator>PROBE_DEFAULTS['degeneracy_epsilon'])
    distance=np.linalg.norm(w+s[:,:,None]*u[:,None,:]-t[:,:,None]*v[None,:,:],axis=2)
    return min(point_surface_distance(a,tb),point_surface_distance(b,ta),
               float(np.where(valid,distance,np.inf).min()))


def observe(q,faces,blade_count,H,rule):
    grip=q['falchion'][blade_count:blade_count+24].reshape(2,12,3)
    centres=grip.mean(1);axis=centres[1]-centres[0];length=np.linalg.norm(axis);axis/=length
    origin=centres[0];radii=np.linalg.norm(grip-centres[:,None,:],axis=2)
    radius=float(radii.mean());basis=(grip[0,0]-origin)/radii[0,0];other=np.cross(axis,basis)
    checks={};rows={}
    hand_names=['finger_far_'+str(k) for k in range(4)]+['thumb_far','gauntlet_far']
    penetration=0.
    for name in hand_names:
        minimum=radial_minimum(q[name],faces[name],origin,axis,0,length)
        penetration=max(penetration,radius-minimum)
        if name.startswith('finger_'):
            path=q[name].reshape(-1,PROBE_DEFAULTS['sweep_ring_vertices'],3).mean(1)-origin
            angles=np.unwrap(np.arctan2(path@other,path@basis))
            wrap=abs(math.degrees(angles[-1]-angles[0]))
            gap=max(0.,minimum-radius)/H
            rows[name+'_wrap_degrees']={'actual':wrap,'expected':rule['finger_wrap_degrees'],'tolerance':rule['wrap_angle_tolerance_degrees']}
            rows[name+'_hilt_gap_over_H']={'actual':gap,'maximum':rule['maximum_finger_hilt_gap_over_H']}
            checks[name+'_wrap_degrees']=abs(wrap-rule['finger_wrap_degrees'])<=rule['wrap_angle_tolerance_degrees']
            checks[name+'_hilt_contact']=gap<=rule['maximum_finger_hilt_gap_over_H']
    rows['hand_hilt_penetration_over_H']={'actual':max(0.,penetration)/H,'maximum':rule['maximum_penetration_over_H']}
    checks['hand_hilt_penetration']=rows['hand_hilt_penetration_over_H']['actual']<=rule['maximum_penetration_over_H']
    gap=surface_gap(q['thumb_far'],faces['thumb_far'],q['finger_far_0'],faces['finger_far_0'])/H
    rows['thumb_index_surface_gap_over_H']={'actual':gap,'maximum':rule['maximum_thumb_index_gap_over_H']}
    checks['thumb_index_surface_contact']=gap<=rule['maximum_thumb_index_gap_over_H']
    return checks,rows
