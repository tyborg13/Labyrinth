"""Triangle-based ring/fist proof, supplied live mesh coordinates only."""
import numpy as np
from .surface_gap import nearest_distance

NUMERICAL_DEFAULTS={'projected_triangle_epsilon':1e-12}


def triangles(points,faces):
    points=np.asarray(points,float)
    return np.asarray([points[[f[0],f[k],f[k+1]]] for f in faces for k in range(1,len(f)-1)])


def ray_hits(origin,direction,mesh,epsilon):
    """Möller–Trumbore positive intersections; no bounding-box containment."""
    a,b,c=mesh[:,0],mesh[:,1],mesh[:,2];e1=b-a;e2=c-a
    p=np.cross(direction,e2);det=np.einsum('ij,ij->i',e1,p)
    valid=abs(det)>epsilon;inverse=np.zeros(len(mesh));inverse[valid]=1/det[valid]
    delta=origin-a;u=np.einsum('ij,ij->i',delta,p)*inverse;q=np.cross(delta,e1)
    v=np.einsum('j,ij->i',direction,q)*inverse;t=np.einsum('ij,ij->i',e2,q)*inverse
    return t[valid&(u>=-epsilon)&(v>=-epsilon)&(u+v<=1+epsilon)&(t>epsilon)]


def inside(point,mesh,epsilon):
    a,b,c=(mesh[:,k]-point for k in range(3))
    la,lb,lc=(np.linalg.norm(q,axis=1) for q in (a,b,c))
    numerator=np.einsum('ij,ij->i',a,np.cross(b,c))
    denominator=la*lb*lc+np.einsum('ij,ij->i',a,b)*lc+np.einsum('ij,ij->i',b,c)*la+np.einsum('ij,ij->i',c,a)*lb
    return abs(float(np.sum(2*np.arctan2(numerator,denominator))))>2*np.pi+epsilon


def surface_distance(point,mesh):
    """Minimum point/triangle distance, including edge and interior regions."""
    a,b,c=mesh[:,0],mesh[:,1],mesh[:,2];normal=np.cross(b-a,c-a)
    area=np.linalg.norm(normal,axis=1);valid=area>0
    normal[valid]/=area[valid,None]
    signed=np.einsum('ij,ij->i',point-a,normal);projection=point-signed[:,None]*normal
    on=valid.copy()
    for start,end in ((a,b),(b,c),(c,a)):
        on &= np.einsum('ij,ij->i',np.cross(end-start,projection-start),normal)>=-NUMERICAL_DEFAULTS['projected_triangle_epsilon']
    distances=np.where(on,abs(signed),np.inf)
    for start,end in ((a,b),(b,c),(c,a)):
        delta=end-start;squared=np.einsum('ij,ij->i',delta,delta)
        t=np.divide(np.einsum('ij,ij->i',point-start,delta),squared,out=np.zeros(len(delta)),where=squared>0)
        distances=np.minimum(distances,np.linalg.norm(point-start-np.clip(t,0,1)[:,None]*delta,axis=1))
    return float(distances.min())


def signed_disk_crossings(ring,path,epsilon):
    """Signed crossings of the actual ring through the closed finger loop.

    The fourth closing edge is the palm bridge between root and fingertip.
    A ring merely placed against the fist has linking number zero.
    """
    disk=triangles(path,[list(range(len(path)))])
    crossings=0;points=[]
    for start,end in zip(ring,np.roll(ring,-1,axis=0)):
        direction=end-start;length=np.linalg.norm(direction)
        if length<=epsilon:continue
        hits=ray_hits(start,direction/length,disk,epsilon)
        if any(hits<length-epsilon):
            normal=np.cross(disk[0,1]-disk[0,0],disk[0,2]-disk[0,0])
            crossings+=1 if np.dot(direction,normal)>0 else -1
            points.append(start+direction/length*min(hits[hits<length-epsilon]))
    return crossings,points


def disk_crossings(ring,path,epsilon):
    crossings,points=signed_disk_crossings(ring,path,epsilon)
    return abs(crossings)==1,points


def linked(ring,path,epsilon):return disk_crossings(ring,path,epsilon)[0]


def middle_surface(vertices,faces,path,outside):
    """Actual swept middle faces on the requested side of the finger."""
    vertices=np.asarray(vertices);middle=(path[1]+path[2])/2
    selected=[f for f in faces if min(f)>=12 and max(f)<36 and np.dot(vertices[f].mean(0)-middle,outside)>0]
    return triangles(vertices,selected)


def fingertip_palm_gaps(points,faces,H,epsilon):
    palm=triangles(points['palm_near'],faces['palm_near'])/H;gaps=[]
    for k in range(4):
        cap=np.asarray(points['finger_near_'+str(k)])[-12:]/H
        gaps.append(nearest_distance(triangles(cap,[list(range(12))]),palm,epsilon))
    return gaps


def ring_fist(points,faces,paths,basis,H,policy):
    epsilon=policy['measurement']['ray_epsilon'];samples=policy['measurement']['sweep_samples']
    ring=np.asarray(points['grip_ring']).reshape(-1,samples,3).mean(1)[:-1]
    centre=ring.mean(0);upper=ring[:,2]>centre[2]+epsilon;lower=ring[:,2]<centre[2]-epsilon
    names=[n for n in points if n.startswith(('palm_near','finger_near_','thumb_near'))]
    meshes=[triangles(points[n],faces[n]) for n in names]
    mesh=np.concatenate(meshes);front=basis[2]
    hidden=[all(len(ray_hits(p,d,mesh,epsilon))>0 for d in (front,-front)) for p in ring[upper]]
    visible=[all(len(ray_hits(p,d,mesh,epsilon))==0 for d in (front,-front)) for p in ring[lower]]
    wire_vertices=np.asarray(points['grip_ring'])
    penetration=max([0.]+[surface_distance(p,m)/H for p in wire_vertices for m in meshes if inside(p,m,epsilon)])
    crossings=[disk_crossings(ring,path,epsilon) for path in paths];links=[v[0] for v in crossings]
    upper_links=[linked and any(p[2]>centre[2]+epsilon for p in hits) for linked,hits in crossings]
    wire_mesh=triangles(wire_vertices,faces['grip_ring'])/H
    clearance=nearest_distance(wire_mesh,mesh/H,epsilon)
    return {'four_fingers_link_ring':len(links)==4 and all(links),'per_finger_link':links,
        'per_finger_signed_crossings':[signed_disk_crossings(ring,path,epsilon)[0] for path in paths],
        'upper_bar_in_every_loop':len(upper_links)==4 and all(upper_links),'per_finger_upper_link':upper_links,
        'nearest_wire_hand_clearance_over_H':clearance,
        'fingertip_palm_distances_over_H':fingertip_palm_gaps(points,faces,H,epsilon),
        'upper_arc_hidden_fraction':sum(hidden)/len(hidden) if hidden else 0.,
        'lower_half_visible_fraction':sum(visible)/len(visible) if visible else 0.,
        'unintended_penetration_over_H':penetration,'penetration_scope':'entire ring against all fingers, thumb and palm',
        'clearance_scope':'minimum exact wire/finger/thumb/palm triangle-surface distance',
        'fingertip_scope':'minimum exact blunt distal cap / palm triangle-surface distance'}


def thumb_contact(points,faces,paths,axes,basis,H):
    v=np.asarray(points['thumb_near']).reshape(3,12,3);stations=v.mean(1)
    target=min(range(4),key=lambda k:np.linalg.norm(paths[k][0]-stations[0]));outside=axes[0]*(1 if np.dot(axes[0],basis[2])>0 else -1)
    mesh=middle_surface(points['finger_near_'+str(target)],faces['finger_near_'+str(target)],paths[target],outside)
    # The blunt distal cap rests on the outside of the selected middle bone.
    cap=np.vstack((v[-1],stations[-1]));gap=min(surface_distance(p,mesh) for p in cap)/H
    direction=stations[1]-stations[0];local=direction@axes.T
    root_curl=float(np.degrees(np.arctan2(local[0],np.linalg.norm(local[1:]))))
    u=direction/np.linalg.norm(direction);other=stations[2]-stations[1];other/=np.linalg.norm(other)
    second=float(np.degrees(np.arccos(np.clip(np.dot(u,other),-1,1))))
    side=float(np.dot(stations[-1]-(paths[target][1]+paths[target][2])/2,outside))
    return {'target_finger_index':target,'distal_cap_clearance_over_H':gap,'joint_curls_degrees':[root_curl,second],'outside':side>0}
