"""Portable geometric proof helpers; no renderer, engine or asset writes."""
from collections import Counter,defaultdict
import numpy as np
from spec.art_identity.maquettes.raster import camera,project,triangle_samples

READABILITY_DEFAULTS={'raster_size':1024,'depth_epsilon_m':1e-7}


def hull(points):
    points=sorted(set(map(tuple,np.asarray(points))))
    if len(points)<3:raise ValueError('Degenerate projected hull')
    def cross(o,a,b):return (a[0]-o[0])*(b[1]-o[1])-(a[1]-o[1])*(b[0]-o[0])
    def half(values):
        result=[]
        for p in values:
            while len(result)>=2 and cross(result[-2],result[-1],p)<=0:result.pop()
            result.append(p)
        return result
    return np.array(half(points)[:-1]+half(reversed(points))[:-1])


def polygon_gap(a,b):
    """Exact convex polygon gap, including containment and crossing rejection."""
    for poly in (a,b):
        edge=np.roll(poly,-1,axis=0)-poly;normal=np.column_stack([-edge[:,1],edge[:,0]])
        pa=np.einsum('nj,kj->nk',a,normal);pb=np.einsum('nj,kj->nk',b,normal)
        if ((pa.max(0)<pb.min(0))|(pb.max(0)<pa.min(0))).any():break
    else:return 0.
    def distances(points,poly):
        starts=poly;d=np.roll(poly,-1,axis=0)-poly
        delta=points[:,None,:]-starts[None,:,:]
        t=np.clip(np.einsum('nkj,kj->nk',delta,d)/np.einsum('kj,kj->k',d,d),0,1)
        return np.linalg.norm(delta-t[:,:,None]*d[None,:,:],axis=2).min()
    return float(min(distances(a,b),distances(b,a)))


def lantern_clearance(spec,points,H):
    matrix,_,basis,_=camera(spec,'front')
    def projected(vertices):return np.einsum('nj,kj->nk',np.einsum('nj,kj->nk',vertices,matrix[:3,:3]),basis[:2])
    lantern=np.concatenate([points[q['id']] for q in spec['pieces'] if q['part']=='lantern' and q['id'] not in ('held_chain','grip_ring','lantern_cap_ring')])
    outline=hull(projected(lantern));gaps={}
    for q in spec['pieces']:
        if q['part'].startswith(('thigh_','shin_','foot_')):
            gaps[q['id']]=polygon_gap(outline,hull(projected(points[q['id']])))/H
    return {'minimum_over_H':min(gaps.values()),'per_leg_piece_over_H':gaps,
        'definition':'Conservative minimum distance between projected native convex envelopes of the lantern body (cap to base) and every iron leg piece in the board front camera.'}


def lantern_overlap(spec,points,faces,H):
    """Depth-tested triangle projections of the body and the complete near leg.

    The denominator excludes the chain and both rings; transparent clay glass
    still contributes its actual solid silhouette. Positive depth is toward
    the front camera. Source and opened-native inputs use the same raster.
    """
    size=READABILITY_DEFAULTS['raster_size']
    depths={name:np.full((size,size),-np.inf) for name in ('lantern','near_leg')}
    for piece in spec['pieces']:
        if piece['part']=='lantern' and piece['id'] not in ('held_chain','grip_ring','lantern_cap_ring'):group='lantern'
        elif piece['part'] in ('thigh_near','shin_near','foot_near'):group='near_leg'
        else:continue
        projected=project(spec,points[piece['id']],'front',size)
        depth=depths[group]
        for face in faces[piece['id']]:
            for k in range(1,len(face)-1):
                triangle=projected[[face[0],face[k],face[k+1]]]
                sampled=triangle_samples(triangle,size,size)
                if sampled is None:continue
                y,x,bary=sampled
                depth[y,x]=np.maximum(depth[y,x],np.sum(bary*triangle[:,2],axis=1))
    body=np.isfinite(depths['lantern']);leg=np.isfinite(depths['near_leg']);overlap=body&leg
    count=int(body.sum());both=int(overlap.sum())
    margin=(depths['lantern'][overlap]-depths['near_leg'][overlap])
    in_front=int((margin>READABILITY_DEFAULTS['depth_epsilon_m']).sum())
    return {'raster_size':size,'lantern_body_pixels':count,'overlap_pixels':both,
        'overlap_share':both/count if count else 1.,'lantern_in_front_pixels':in_front,
        'lantern_in_front':bool(count and both and in_front==both),
        'minimum_depth_margin_over_H':float(margin.min()/H) if both else None,
        'definition':'1024px front-camera triangle projections, cap-to-base body excluding chain/rings; near leg is thigh, knee, shin and foot. Overlap is a union and every overlapping ray must meet the lantern first.'}


def near_plate_visibility(spec,points,faces):
    """Test the complete plate silhouette against other opened native solids.

    Mounting stems join the mantle and may enter it. They are not part of the
    exposed plate. Same-owner relief/rivets can obscure the panel itself.
    This avoids treating antialiased label boundaries as mesh occlusion.
    """
    size=spec['mq20']['capture_size_px']
    depths=[np.full((size,size),-np.inf) for _ in range(2)]
    for piece in spec['pieces']:
        near=piece['part']=='pauldron_near'
        if near and piece['id'].endswith('_mount'):continue
        depth=depths[0 if near else 1]
        projected=project(spec,points[piece['id']],'front',size)
        for face in faces[piece['id']]:
            for k in range(1,len(face)-1):
                triangle=projected[[face[0],face[k],face[k+1]]]
                sampled=triangle_samples(triangle,size,size)
                if sampled is None:continue
                y,x,bary=sampled
                depth[y,x]=np.maximum(depth[y,x],np.sum(bary*triangle[:,2],axis=1))
    mask=np.isfinite(depths[0]);hidden=mask&(depths[1]>depths[0]+READABILITY_DEFAULTS['depth_epsilon_m'])
    return {'passed':bool(mask.any() and not hidden.any()),'raster_size':size,
        'plate_pixels':int(mask.sum()),'occluded_pixels':int(hidden.sum()),
        'definition':'Opened-native front triangle depth test: panel, both rims, rivets and front cross against all other parts; only the mounting stem is excluded.'}


def components(faces):
    neighbours=defaultdict(set)
    for face in faces:
        for a,b in zip(face,face[1:]+face[:1]):neighbours[a].add(b);neighbours[b].add(a)
    count=0
    while neighbours:
        pending=[next(iter(neighbours))];count+=1
        while pending:
            key=pending.pop();pending.extend(neighbours.pop(key,()))
    return count


def sheet_boundaries(faces,count):
    surface=[f for f in faces if all(i<count for i in f)]
    edges=Counter(tuple(sorted((a,b))) for f in surface for a,b in zip(f,f[1:]+f[:1]))
    boundary=[list(edge) for edge,n in edges.items() if n==1]
    return surface,boundary,components(boundary)
