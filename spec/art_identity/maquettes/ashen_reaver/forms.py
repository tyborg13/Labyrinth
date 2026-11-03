"""Rounded native closed forms, source dimensions supplied by the recipe."""
import math
import numpy as np

from spec.art_identity.maquettes.blender.closed_loft import loft, sweep, sheet
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
