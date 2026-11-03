"""Rounded native closed forms, source dimensions supplied by the recipe."""
import math
import numpy as np

from spec.art_identity.maquettes.blender.closed_loft import loft, sweep
from spec.art_identity.maquettes.blender.source_recipe import common

TOPOLOGY = {'ring_samples':24, 'meridian_samples':13, 'tip_fraction':.001,
            'sweep_samples':12, 'coordinate_digits':8}


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


def cord(identifier,part,joint,path,radius):
    v,f,flat=sweep(path,[radius]*len(path),TOPOLOGY['sweep_samples'])
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

