"""Pinned contract and immutable mq-20 reference; independent of the compiler."""
import hashlib
import json
import lzma
from pathlib import Path
import numpy as np

FOLDER=Path(__file__).resolve().parent


def contract():return json.loads((FOLDER/'contract.json').read_text())


def baseline():
    policy=contract()['baseline'];path=(FOLDER/policy['path']).resolve();raw=path.read_bytes()
    if hashlib.sha256(raw).hexdigest()!=policy['sha256']:raise ValueError('Pinned mq-20 baseline changed')
    return json.loads(lzma.decompress(raw))


def protected():
    project=FOLDER.parents[4]
    hashes=json.loads((FOLDER/'protected_files.json').read_text())
    return all((project/p).is_file() and hashlib.sha256((project/p).read_bytes()).hexdigest()==sha for p,sha in hashes.items()) and director_files_protected()


def director_files_protected():
    files=json.loads((FOLDER/'director_files.json').read_text())['files']
    return set(files)=={'prompt_front.md','prompt_rear.md'} and all(
        (FOLDER/name).is_file() and hashlib.sha256((FOLDER/name).read_bytes()).hexdigest()==value for name,value in files.items())


def round1():
    policy=contract()['round1_preservation'];raw=(FOLDER/policy['path']).read_bytes()
    if hashlib.sha256(raw).hexdigest()!=policy['sha256']:raise ValueError('Pinned round-1 reference changed')
    return json.loads(raw)


def changed_piece(piece):
    return piece['part'] in ('hand_near','hand_far','mantle') or piece['part'].startswith('pauldron_')


def same_faces(actual,expected):
    """Blender may rotate an n-gon's starting loop without changing winding."""
    if actual is None:return False
    def canonical(face):
        face=tuple(face);return min(face[k:]+face[:k] for k in range(len(face)))
    return sorted(map(canonical,actual))==sorted(map(canonical,expected))


def outward_faces(vertices,faces):
    """Match the builder's existing outward-normal bake on the pinned source.

    The inherited sabaton loft uses left-handed profile axes. Its source
    winding is inward; Blender already reverses it in mq-20 and mq-24 alike.
    Derive this from signed volume, never from the live candidate's winding.
    """
    v=np.asarray(vertices,float);indices=np.asarray([[f[0],f[k],f[k+1]] for f in faces for k in range(1,len(f)-1)])
    t=v[indices];volume=float(np.einsum('ij,ij->i',t[:,0],np.cross(t[:,1],t[:,2])).sum())
    return [list(reversed(f)) for f in faces] if volume<0 else faces


def consistent_shell_faces(vertices,faces):
    """Derive the existing native normal bake from pinned shell topology.

    normal_sheet's hem rim has opposite source winding to its skin. Blender
    first makes adjacent faces consistent, then orients the closed shell.
    Traverse shared edges here; the live candidate never supplies the answer.
    """
    edges={};adjacent={k:[] for k in range(len(faces))}
    for k,face in enumerate(faces):
        for a,b in zip(face,face[1:]+face[:1]):edges.setdefault(tuple(sorted((a,b))),[]).append((k,a<b))
    for uses in edges.values():
        if len(uses)!=2:raise ValueError('Pinned shell is not a closed manifold')
        (a,x),(b,y)=uses;adjacent[a].append((b,x==y));adjacent[b].append((a,x==y))
    flip={};result=[None]*len(faces)
    for start in range(len(faces)):
        if start in flip:continue
        flip[start]=False;queue=[start];component=[]
        while queue:
            k=queue.pop();component.append(k)
            for other,toggle in adjacent[k]:
                expected=flip[k]^toggle
                if other not in flip:flip[other]=expected;queue.append(other)
                elif flip[other]!=expected:raise ValueError('Pinned shell is not orientable')
        oriented=[list(reversed(faces[k])) if flip[k] else faces[k] for k in component]
        for k,face in zip(component,outward_faces(vertices,oriented)):result[k]=face
    return result


def angle(a,b):
    a=np.asarray(a,float);b=np.asarray(b,float);den=np.linalg.norm(a)*np.linalg.norm(b)
    return float(np.degrees(np.arccos(np.clip(np.dot(a,b)/den,-1,1)))) if den else float('nan')


def digit_path(vertices,segments,pointed,samples):
    points=np.asarray(vertices,float);count=segments*samples+(1 if pointed else samples)
    if points.shape!=(count,3):raise ValueError('Digit segment topology differs from pinned contract')
    rings=points[:-1] if pointed else points
    rings=rings.reshape(-1,samples,3);centres=rings.mean(1)
    radii=np.linalg.norm(rings-centres[:,None],axis=2).mean(1)
    if pointed:centres=np.vstack((centres,points[-1]));radii=np.r_[radii,0.]
    return centres,radii


def limb_length(vertices,c):
    groups=np.asarray(vertices).reshape(-1,c['measurement']['limb_stations_per_lame'],c['measurement']['limb_ring_samples'],3)
    return float(np.linalg.norm(groups[-1,-1].mean(0)-groups[0,0].mean(0)))
