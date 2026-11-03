"""Opened-surface evidence for ribbon flatness, shared roots and far exposure."""
import numpy as np
from .cloth import mesh_rims,boundary_loops
from spec.art_identity.maquettes.raster import camera,project


def ribbon_metrics(spec,mid,faces,live=None):
    from .live_ribbons import measure
    H=spec['mq19']['gauge_H_m'];layout=spec['mq19']['cloak_layout'];count=len(mid)
    live=live if live is not None else measure(spec,mid,faces)
    rows=live['ribbons']
    # Incisions are the eight interior boundary runs above the root. Actual
    # opened rim heights determine where they start, not authored row labels.
    inverse={i:(r,c) for r,row in enumerate(layout['solid_grid_indices']) for c,i in enumerate(row) if i>=0}
    boundary=set(max(boundary_loops(mesh_rims(faces,count)),key=len));us=np.asarray(layout['us']);slits=[]
    for left,right in layout['slit_gaps']:
        centre=(left+right)/2;root=.30-.03*abs(2*centre-1)
        rim=[i for i in boundary if i in inverse and inverse[i][0]>0 and left+1e-9<us[inverse[i][1]]<right-1e-9]
        highest=max(mid[i,2]/H for i in rim)
        slits.append({'start_above_root_over_H':float(highest-root)})
    return {'ribbons':rows,'slits':slits,'ignored_orphan_vertices':live['ignored_orphan_vertices'],'detached_surfaces':live['detached_surfaces'],'checks':{
        'flat_lower_ribbons':len(rows)==9 and all(r['lower_half_plane_error_over_H']<=1e-6 for r in rows),
        'continuous_shared_strip_roots':len(rows)==9 and not live['detached_surfaces'] and all(r['root_edges_shared'] and r['continuous_rows'] for r in rows),
        'eight_slits_start_003H_above_root':len(slits)==8 and all(abs(r['start_above_root_over_H']-.03)<=.003 for r in slits)}}


def scanline_left(vertices,faces,size):
    edges=np.asarray([(a,b) for face in faces for a,b in zip(face,face[1:]+face[:1])],int)
    a=vertices[edges[:,0],:2];b=vertices[edges[:,1],:2]
    low=np.maximum(0,np.ceil(np.minimum(a[:,1],b[:,1])-.5).astype(int))
    high=np.minimum(size-1,np.floor(np.maximum(a[:,1],b[:,1])-.5).astype(int))
    counts=np.maximum(0,high-low+1);counts[abs(a[:,1]-b[:,1])<1e-12]=0
    index=np.repeat(np.arange(len(edges)),counts);offset=np.r_[0,np.cumsum(counts)]
    y=np.repeat(low,counts)+np.arange(len(index))-np.repeat(offset[:-1],counts)
    t=(y+.5-a[index,1])/(b[index,1]-a[index,1]);x=a[index,0]+t*(b[index,0]-a[index,0])
    result=np.full(size,np.inf);np.minimum.at(result,y,x)
    return result


def front_exposure(spec,points,faces):
    H=spec['mq19']['gauge_H_m'];size=spec['mq19']['capture_px'];body=np.full(size,np.inf);cloak=None
    for piece in spec['pieces']:
        name=piece['id']+'_render'
        if piece['part']=='staff':continue
        xy=project(spec,np.asarray(points[name]),'front',size)
        edge=scanline_left(xy,faces[name],size)
        if piece['part']=='cloak':cloak=edge if cloak is None else np.minimum(cloak,edge)
        else:body=np.minimum(body,edge)
    live=np.isfinite(body)&np.isfinite(cloak)
    delta=np.zeros(size);delta[live]=np.maximum(0,body[live]-cloak[live])
    _,_,_,scale=camera(spec,'front');extension=float(delta.max()*scale/size/H)
    cloak_left=float(cloak[np.isfinite(cloak)].min())
    hand=project(spec,np.asarray(points['gauntlet_far_render']),'front',size)[:,0].min()
    return {'definition':'Native polygon silhouette left edge at pixel-centre scanlines; all body/arm pieces except staff and cloak form the comparison. Cloak solo is conservative even when occluded.',
        'maximum_beyond_body_over_H':extension,'maximum_row_px':int(delta.argmax()),
        'cloak_left_px':cloak_left,'staff_hand_left_px':float(hand),
        'checks':{'front_far_exposure_at_most_006H':extension<=.06+1e-6,
                  'no_cloth_past_staff_hand':bool(cloak_left>=hand-1e-5)}}
