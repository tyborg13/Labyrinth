"""Ordered closed latitude topology, independent of native operator allocation."""
import math

TOPOLOGY_DEFAULTS = {'clip_epsilon': 1e-10}


def uv_sphere(segments,rings):
    if segments<3 or rings<2:raise ValueError('Sphere requires >=3 segments and >=2 rings')
    vertices=[[0.,0.,1.]]
    for row in range(1,rings):
        theta=math.pi*row/rings
        for column in range(segments):
            angle=math.tau*column/segments
            vertices.append([math.sin(theta)*math.cos(angle),math.sin(theta)*math.sin(angle),math.cos(theta)])
    bottom=len(vertices);vertices.append([0.,0.,-1.])
    faces=[]
    for column in range(segments):
        following=(column+1)%segments
        faces.append([0,1+column,1+following])
    for row in range(rings-2):
        first=1+row*segments;second=first+segments
        for column in range(segments):
            following=(column+1)%segments
            faces.append([first+column,second+column,second+following,first+following])
    first=1+(rings-2)*segments
    for column in range(segments):
        following=(column+1)%segments
        faces.append([first+column,bottom,first+following])
    return vertices,faces


def ico_sphere(subdivisions):
    if subdivisions<1:raise ValueError('Icosphere requires positive subdivisions')
    phi=(1+math.sqrt(5))/2
    raw=[[-1,phi,0],[1,phi,0],[-1,-phi,0],[1,-phi,0],[0,-1,phi],[0,1,phi],
         [0,-1,-phi],[0,1,-phi],[phi,0,-1],[phi,0,1],[-phi,0,-1],[-phi,0,1]]
    def normalise(p):
        length=math.sqrt(sum(v*v for v in p))
        return [v/length for v in p]
    vertices=[normalise(p) for p in raw]
    faces=[[0,11,5],[0,5,1],[0,1,7],[0,7,10],[0,10,11],[1,5,9],[5,11,4],
           [11,10,2],[10,7,6],[7,1,8],[3,9,4],[3,4,2],[3,2,6],[3,6,8],
           [3,8,9],[4,9,5],[2,4,11],[6,2,10],[8,6,7],[9,8,1]]
    for level in range(subdivisions-1):
        cache={}
        def midpoint(a,b):
            key=tuple(sorted((a,b)))
            if key not in cache:
                cache[key]=len(vertices)
                vertices.append(normalise([(x+y)/2 for x,y in zip(vertices[a],vertices[b])]))
            return cache[key]
        refined=[]
        for a,b,c in faces:
            ab,bc,ca=midpoint(a,b),midpoint(b,c),midpoint(c,a)
            refined.extend([[a,ab,ca],[b,bc,ab],[c,ca,bc],[ab,bc,ca]])
        faces=refined
    return vertices,faces


def clip_convex(vertices,faces,normal,distance):
    """Clip a closed convex mass with stable intersections and an outward cap."""
    import numpy as np
    points=[np.array(p,float) for p in vertices]
    n=np.array(normal,float);n/=np.linalg.norm(n)
    signed=[float(p@n-distance) for p in points]
    signed=[0. if abs(value)<=TOPOLOGY_DEFAULTS['clip_epsilon'] else value for value in signed]
    cuts={};cap=[];cap_seen=set();polygons=[]
    def add_cap(index):
        if index not in cap_seen:cap.append(index);cap_seen.add(index)
    def intersection(a,b):
        key=tuple(sorted((a,b)))
        if key not in cuts:
            lo,hi=key
            t=signed[lo]/(signed[lo]-signed[hi])
            cuts[key]=len(points);points.append(points[lo]+t*(points[hi]-points[lo]));add_cap(cuts[key])
        return cuts[key]
    for face in faces:
        polygon=[]
        for a,b in zip(face,face[1:]+face[:1]):
            if signed[a]<=0:polygon.append(a)
            if signed[a]==0:add_cap(a)
            if (signed[a]<0<signed[b]) or (signed[b]<0<signed[a]):polygon.append(intersection(a,b))
        if len(polygon)>=3:polygons.append(polygon)
    if len(cap)>=3:
        centre=np.mean([points[i] for i in cap],axis=0)
        reference=np.eye(3)[int(np.argmin(abs(n)))]
        u=np.cross(n,reference);u/=np.linalg.norm(u);v=np.cross(n,u)
        cap.sort(key=lambda i:(math.atan2(float((points[i]-centre)@v),float((points[i]-centre)@u)),i))
        polygons.append(cap)
    used=sorted({i for face in polygons for i in face});indices={old:new for new,old in enumerate(used)}
    return [points[i].tolist() for i in used],[[indices[i] for i in face] for face in polygons]


def outward_faces(vertices,faces):
    import numpy as np
    points=np.array(vertices,float);centre=points.mean(0);result=[]
    for face in faces:
        a,b,c=points[face[:3]]
        normal=np.cross(b-a,c-a)
        result.append(list(reversed(face)) if normal@(points[face].mean(0)-centre)<0 else list(face))
    return result


def validate_volume(volume):
    from collections import Counter
    from .contract import vector
    vertices,faces=volume['vertices'],volume['faces']
    if not vertices or not faces:raise ValueError('Cutout must be a closed nonempty volume')
    for point in vertices:vector(point,3,'cutout vertex')
    if any(len(f)<3 or any(type(i) is not int or not 0<=i<len(vertices) for i in f) for f in faces):
        raise ValueError('Invalid cutout face indices')
    edges=Counter(tuple(sorted((a,b))) for f in faces for a,b in zip(f,f[1:]+f[:1]))
    if any(count!=2 for count in edges.values()):raise ValueError('Cutout must be closed and manifold')
