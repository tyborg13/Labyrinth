"""Closed, thick ragged panels from director-authored surface grids.

No tear placement, fold depth or outline is chosen by this module. Deleted
quads make real holes/notches; both skins are joined at every resulting rim.
Topology indices survive native construction, so proof reads actual vertices.
"""
from collections import Counter
import numpy as np
from ..forms import normal_sheet, shell

CLOTH_DEFAULTS = {'flatness_tolerance_m':1e-8}


def panel(identifier, part, joint, rows, thickness, removed_quads):
    rows = np.asarray(rows, float)
    if rows.ndim != 3 or rows.shape[2] != 3 or min(rows.shape[:2]) < 2 or not np.isfinite(rows).all():
        raise ValueError('Cloth requires a finite rectangular surface grid')
    nr, nc, _ = rows.shape
    removed = {tuple(q) for q in removed_quads}
    if len(removed) != len(removed_quads) or any(len(q)!=2 or any(type(v) is not int for v in q) or
            not (0<=q[0]<nr-1 and 0<=q[1]<nc-1) for q in removed):
        raise ValueError('Invalid or duplicate removed cloth quad')
    draft = normal_sheet(identifier, part, joint, rows, thickness)
    count = nr*nc; faces = []; surface = []; edges = Counter()
    for r in range(nr-1):
        for c in range(nc-1):
            if (r,c) in removed: continue
            a = r*nc+c; face = [a,a+1,a+nc+1,a+nc]; surface.append(face)
            faces.extend([face, [v+count for v in reversed(face)]])
            for a,b in zip(face,face[1:]+face[:1]): edges[tuple(sorted((a,b)))]+=1
    if not surface: raise ValueError('Empty cloth panel')
    boundary = []
    for face in surface:
        for a,b in zip(face,face[1:]+face[:1]):
            if edges[tuple(sorted((a,b)))]==1:
                boundary.append([a,b]); faces.append([b,a,a+count,b+count])
    # Keep the complete paired grid for independent measurements. Unused
    # vertices do not own pixels; every live edge must have exactly two faces.
    piece = shell(identifier, part, joint, draft['vertices'], faces)
    return piece, {'shape':[nr,nc], 'surface_faces':surface, 'boundary_edges':boundary,
                   'paired_vertices':count}


def boundary_loops(edges):
    adjacency = {}
    for a,b in edges:
        adjacency.setdefault(a,[]).append(b); adjacency.setdefault(b,[]).append(a)
    if any(len(v)!=2 for v in adjacency.values()):
        raise ValueError('Cloth tears touch at a vertex or have a nonmanifold rim')
    remaining = set(adjacency); loops = []
    while remaining:
        start = min(remaining); previous = None; current = start; loop = []
        while current not in loop:
            loop.append(current)
            following = next(v for v in adjacency[current] if v!=previous)
            previous,current = current,following
        if current!=start: raise ValueError('Cloth boundary does not close')
        remaining.difference_update(loop); loops.append(loop)
    return loops


def mesh_rims(faces, paired_count):
    """Recover live surface boundaries from opened native polygon topology."""
    edges = Counter()
    for face in faces:
        if all(v<paired_count for v in face):
            for a,b in zip(face,face[1:]+face[:1]): edges[tuple(sorted((a,b)))]+=1
    return [list(edge) for edge,n in edges.items() if n==1]


def extrema(values, minimum):
    """Indices of strict peaks; flat runs count once, endpoints excluded."""
    values = np.asarray(values); result = []; i = 1
    while i<len(values)-1:
        end = i
        while end+1<len(values) and np.isclose(values[end+1],values[i],rtol=0,atol=CLOTH_DEFAULTS['flatness_tolerance_m']): end+=1
        if end+1<len(values):
            sign = -1 if minimum else 1
            if sign*values[i]>sign*values[i-1] and sign*values[end]>sign*values[end+1]:
                result.append((i+end)//2)
        i = end+1
    return result


def closed_surface(identifier,part,joint,vertices,faces,thickness,horizontal_tips=(),edge_normals=None):
    """Thicken a connected surface with sewn rims, retaining pointed strip tips."""
    vertices=np.asarray(vertices,float);normal=np.zeros_like(vertices)
    for face in faces:
        polygon=vertices[face]
        vector=np.cross(polygon[1]-polygon[0],polygon[-1]-polygon[0])
        for index in face:normal[index]+=vector
    # Pointed ends terminate on a horizontal cut. Both skins must respect the
    # director's sole-plane clearance, not merely the centre surface.
    for index in horizontal_tips:normal[index,2]=0.
    for index,direction in (edge_normals or {}).items():
        direction=np.asarray(direction,float)
        normal[index]=direction*(1 if normal[index]@direction>=0 else -1)
    length=np.linalg.norm(normal,axis=1)
    if np.any(length<=1e-12):raise ValueError('Garment has an isolated or degenerate surface vertex')
    normal/=length[:,None]
    count=len(vertices);skins=np.concatenate([vertices+normal*thickness/2,vertices-normal*thickness/2])
    output=[];edges=Counter()
    for face in faces:
        output.extend([face,[i+count for i in reversed(face)]])
        for a,b in zip(face,face[1:]+face[:1]):edges[tuple(sorted((a,b)))]+=1
    boundary=[]
    for face in faces:
        for a,b in zip(face,face[1:]+face[:1]):
            if edges[tuple(sorted((a,b)))]==1:
                boundary.append([a,b]);output.append([b,a,a+count,b+count])
    boundary_loops(boundary)
    piece=shell(identifier,part,joint,skins.tolist(),output)
    return piece,{'paired_vertices':count,'surface_faces':faces,'boundary_edges':boundary}
