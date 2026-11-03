"""Rounded native closed forms, source dimensions supplied by the recipe."""
import math
import numpy as np

from spec.art_identity.maquettes.blender.closed_loft import loft, sweep, sheet
from spec.art_identity.maquettes.blender.source_recipe import common

TOPOLOGY = {'ring_samples':24, 'meridian_samples':13, 'tip_fraction':.001,
            'sweep_samples':12, 'coordinate_digits':8}
DOME_TOPOLOGY={'columns':32,'rows':12}


def shell(identifier, part, joint, vertices, faces, flat=()):
    piece=common(identifier,'rigid_shell',part)
    piece.update(vertices=np.round(vertices,TOPOLOGY['coordinate_digits']).tolist(),
                 faces=faces,flat_faces=list(flat),rig_joint=joint,
                 rig_bone=joint,rig_pivot_joint=joint)
    return piece


def oval(identifier,part,joint,centre,radii,axes=None):
    axes=np.eye(3) if axes is None else np.asarray(axes)
    rings=[]
    for t in np.linspace(-math.pi/2,math.pi/2,TOPOLOGY['meridian_samples']):
        factor=max(TOPOLOGY['tip_fraction'],math.cos(t))
        location=np.asarray(centre)+axes[2]*radii[2]*math.sin(t)
        rings.append([*location,radii[0]*factor,radii[1]*factor])
    v,f,flat=loft({'sections':rings,'axes':axes[:2].tolist(),'samples':TOPOLOGY['ring_samples']})
    return shell(identifier,part,joint,v,f,flat)


def capsule(identifier,part,joint,start,end,radii):
    direction=np.subtract(end,start);length=np.linalg.norm(direction);direction/=length
    first=np.cross(direction,[0,1,0])
    if np.linalg.norm(first)<1e-9:first=np.cross(direction,[1,0,0])
    first/=np.linalg.norm(first);second=np.cross(direction,first)
    return oval(identifier,part,joint,(np.asarray(start)+end)/2,
                [*radii,length/2],[first,second,direction])


def cord(identifier,part,joint,path,radius):
    v,f,flat=sweep(path,[radius]*len(path),TOPOLOGY['sweep_samples'])
    return shell(identifier,part,joint,v,f,flat)


def closed_sheet(identifier,part,joint,rows,thickness,direction):
    v,f,flat=sheet({'rows':rows,'thickness':thickness,'thickness_axis':direction})
    return shell(identifier,part,joint,v,f,flat)


def union(identifier,part,joint,pieces):
    vertices,faces,flat=[],[],[]
    for piece in pieces:
        offset,face_offset=len(vertices),len(faces)
        vertices+=piece['vertices']
        faces += [[i+offset for i in f] for f in piece['faces']]
        flat += [i+face_offset for i in piece['flat_faces']]
    return shell(identifier,part,joint,vertices,faces,flat)


def normal_sheet(identifier,part,joint,rows,thickness,periodic=False):
    """A sewn, closed sheet; corresponding vertices are a full thickness apart."""
    rows=np.asarray(rows,float);nr,nc,_=rows.shape
    along=np.gradient(rows,axis=0)
    across=(np.roll(rows,-1,axis=1)-np.roll(rows,1,axis=1)) if periodic else np.gradient(rows,axis=1)
    normals=np.cross(across,along);normals/=np.linalg.norm(normals,axis=2)[:,:,None]
    if not periodic:
        # Preserve a director-specified transverse hem width at its boundary.
        normals[:,[0,-1],1]=0
        normals[:,[0,-1]]/=np.linalg.norm(normals[:,[0,-1]],axis=2)[:,:,None]
    count=nr*nc
    v=np.concatenate([(rows+normals*thickness/2).reshape(-1,3),(rows-normals*thickness/2).reshape(-1,3)])
    faces=[]
    for r in range(nr-1):
        for c in range(nc if periodic else nc-1):
            nxt=(c+1)%nc;a=r*nc+c;b=r*nc+nxt
            face=[a,b,b+nc,a+nc];faces.extend([face,[i+count for i in reversed(face)]])
    if periodic:
        boundary=[list(range(nc)),list(range((nr-1)*nc,nr*nc))]
    else:
        boundary=[list(range(nc))+[r*nc+nc-1 for r in range(1,nr)]+
                  list(range(count-2,count-nc-1,-1))+[r*nc for r in range(nr-2,0,-1)]]
    for ring in boundary:
        for a,b in zip(ring,ring[1:]+ring[:1]):faces.append([a,a+count,b+count,b])
    return shell(identifier,part,joint,v,faces)


def armour_limb(identifier,part,joint,start,end,diameter):
    direction=np.subtract(end,start);length=np.linalg.norm(direction);direction/=length
    first=np.cross(direction,[0,1,0]);first/=np.linalg.norm(first);second=np.cross(direction,first)
    # Rounded end transitions surround a substantial, gently tapered plate.
    stations=[(0,.3),(.04,.65),(.12,.94),(.3,1),(.65,.98),(.86,.86),(.96,.55),(1,.3)]
    sections=[[*((1-t)*np.asarray(start)+t*np.asarray(end)),diameter*r/2,diameter*r/2] for t,r in stations]
    v,f,flat=loft({'sections':sections,'axes':[first.tolist(),second.tolist()],'samples':TOPOLOGY['ring_samples']})
    return shell(identifier,part,joint,v,f,flat)


def dome(identifier,part,joint,centre,radii,thickness):
    """Hollow ellipsoid shoulder cap, with a closed rolled lower rim."""
    centre=np.asarray(centre);radii=np.asarray(radii)
    nc=DOME_TOPOLOGY['columns'];nr=DOME_TOPOLOGY['rows']
    vertices=[];faces=[]
    for radius in (radii,radii-thickness):
        vertices.append((centre+[0,0,radius[2]]).tolist())
        for theta in np.linspace(0,math.pi/2,nr+1)[1:]:
            for phi in np.linspace(0,math.tau,nc,endpoint=False):
                vertices.append((centre+radius*[math.sin(theta)*math.cos(phi),math.sin(theta)*math.sin(phi),math.cos(theta)]).tolist())
    count=1+nr*nc
    for offset,reverse in [(0,False),(count,True)]:
        for col in range(nc):
            face=[offset,offset+1+col,offset+1+(col+1)%nc]
            faces.append(list(reversed(face)) if reverse else face)
        for row in range(nr-1):
            for col in range(nc):
                a=offset+1+row*nc+col;b=offset+1+row*nc+(col+1)%nc
                face=[a,b,b+nc,a+nc];faces.append(list(reversed(face)) if reverse else face)
    rim=1+(nr-1)*nc
    for c in range(nc):
        a=rim+c;b=rim+(c+1)%nc;faces.append([a,a+count,b+count,b])
    return shell(identifier,part,joint,vertices,faces)
