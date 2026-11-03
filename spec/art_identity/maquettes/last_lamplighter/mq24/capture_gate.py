"""mq-25 necessary image gates, measured on hash-bound native captures.

The director permits the ring's highest centreline station inside the native
hand mask or at most eight pixels above its top (director's y=570/576 rule).
Projected triangles locate the grip ring, chain and cap ring only. Visibility comes from
the native lantern solo and depth-tested parts PNG, never a proxy render.
"""
from pathlib import Path
import numpy as np
from PIL import Image
from spec.art_identity.maquettes.raster import project,triangle_samples
from spec.art_identity.maquettes.blender.curate_delivery import sha
from .oracle import contract

IMAGE_DEFAULTS={'alpha_threshold':128}


def rgba(path):
    with Image.open(path) as image:return np.asarray(image.convert('RGBA'))


def region(spec,piece,view,size,lower_than_z=None):
    vertices=np.asarray(piece['vertices']);pixels=project(spec,vertices,view,size)
    mask=np.zeros((size,size),bool)
    for face in piece['faces']:
        for k in range(1,len(face)-1):
            ids=[face[0],face[k],face[k+1]]
            sampled=triangle_samples(pixels[ids],size,size)
            if sampled is None:continue
            y,x,weights=sampled
            if lower_than_z is not None:
                selected=weights@vertices[ids,2]<=lower_than_z;y,x=y[selected],x[selected]
            mask[y,x]=True
    return mask


def top_bar_observation(fist,pixels,indices,maximum_above_px):
    rows=[];height,width=fist.shape;occupied=np.argwhere(fist)
    silhouette_top=int(occupied[:,0].min()) if len(occupied) else None
    for k in indices:
        x,y=map(int,pixels[k]);in_canvas=0<=x<width and 0<=y<height
        hand_y=np.flatnonzero(fist[:,x]) if 0<=x<width else np.array([],dtype=int)
        inside=bool(in_canvas and fist[y,x]);above=int(silhouette_top-y) if len(hand_y) and y<silhouette_top else None
        allowed=inside or bool(in_canvas and above is not None and above<=maximum_above_px)
        rows.append({'station':int(k),'pixel_xy':[x,y],'inside_fist':inside,
            'above_fist_px':above,'within_allowance':allowed})
    return {'satisfied':bool(rows) and all(r['within_allowance'] for r in rows),
        'maximum_above_fist_px':maximum_above_px,'stations':rows}


def column_visibility(fist,required,pixels):
    bottom=np.where(fist,np.arange(fist.shape[0])[:,None],-1).max(0)
    below=np.arange(fist.shape[0])[:,None]>bottom
    shown=pixels&below;occupied=np.flatnonzero(required.any(0));qualifies=shown.any(0)
    rows=[{'x':int(x),'lowest_hand_y':int(bottom[x]) if bottom[x]>=0 else None,
        'required_region_pixels':int(required[:,x].sum()),
        'visible_pixels':int(pixels[:,x].sum()),'visible_below_hand_pixels':int(shown[:,x].sum()),
        'below_hand':bool(qualifies[x])} for x in occupied]
    # Rear observations remain diagnostics. The generic delivery validator
    # recursively treats every `passed` field as mandatory; only the scoped
    # front acceptance checks below should supply that verdict.
    return below,{'satisfied':bool(rows) and all(r['below_hand'] for r in rows),'columns':rows,
        'failed_columns':[r['x'] for r in rows if not r['below_hand']]}


def inspect(spec,capture):
    capture=Path(capture);policy=contract();pieces={p['id']:p for p in spec['pieces']}
    samples=policy['measurement']['sweep_samples']
    ring=np.asarray(pieces['grip_ring']['vertices']).reshape(-1,samples,3).mean(1)[:-1]
    centre=ring.mean(0);top=np.flatnonzero(ring[:,2]>=ring[:,2].max()-policy['measurement']['ray_epsilon'])
    upper=np.flatnonzero(ring[:,2]>centre[2]);views={};inputs={}
    for view in ('front','rear'):
        names=[view+'_solo_hand_near.png',view+'_solo_lantern.png',view+'_parts.png']
        hand,lamp,parts=[rgba(capture/n) for n in names]
        if hand.shape!=lamp.shape or hand.shape!=parts.shape or hand.shape[0]!=hand.shape[1]:
            raise ValueError('Inconsistent native image gate dimensions')
        size=hand.shape[0]
        if size!=policy['native_capture_policy']['size_px']:raise ValueError('Native image gate requires the director capture size')
        threshold=IMAGE_DEFAULTS['alpha_threshold'];fist=hand[:,:,3]>=threshold
        occupied=np.argwhere(fist)
        if not len(occupied):raise ValueError('Empty native fist silhouette')
        bottom=int(occupied[:,0].max())
        # Match the existing native backend's nearest-label decoder. Native
        # antialiasing/denoising does not retain exact byte label colours.
        label_names=list(spec['labels']);distance=np.full(fist.shape,np.inf);owner=np.full(fist.shape,-1)
        for k,name in enumerate(label_names):
            linear=np.asarray(spec['labels'][name]);colour=255*np.where(linear<=.0031308,12.92*linear,1.055*linear**(1/2.4)-.055)
            error=((parts[:,:,:3].astype(float)-colour)**2).sum(2);wins=error<distance
            distance[wins]=error[wins];owner[wins]=k
        visible=(lamp[:,:,3]>=threshold)&(parts[:,:,3]>=threshold)&(owner==label_names.index('lantern'))
        lower=region(spec,pieces['grip_ring'],view,size,centre[2]);chain=region(spec,pieces['held_chain'],view,size)
        cap=region(spec,pieces['lantern_cap_ring'],view,size)
        assembly={'grip_ring':lower,'held_chain':chain,'lantern_cap_ring':cap}
        union=np.zeros_like(fist)
        for name in policy['native_capture_policy']['hanging_assembly_piece_ids']:union|=assembly[name]
        # The lantern solo excludes hand occlusion. Projected piece regions
        # isolate the complete hanging assembly within that native solo;
        # depth-tested ownership only determines which pixels are visible.
        required=union&(lamp[:,:,3]>=threshold)
        below,columns=column_visibility(fist,required,required&visible)
        projected=project(spec,ring,view,size);xy=np.floor(projected[:,:2]).astype(int)
        in_canvas=(xy[:,0]>=0)&(xy[:,0]<size)&(xy[:,1]>=0)&(xy[:,1]<size)
        contained=np.zeros(len(ring),bool);contained[in_canvas]=fist[xy[in_canvas,1],xy[in_canvas,0]]
        top_bar=top_bar_observation(fist,xy,top,policy['native_capture_policy']['maximum_top_bar_above_fist_px'])
        views[view]={'top_bar_station_indices':top.tolist(),'top_bar_in_fist':bool(contained[top].all()),
            'top_bar_allowance':top_bar,'ring_chain_column_visibility':columns,
            'upper_stations':[{'station':int(k),'pixel_xy':xy[k].tolist(),'inside_fist':bool(contained[k])} for k in upper],
            'fist_bbox_xyxy':[int(occupied[:,1].min()),int(occupied[:,0].min()),int(occupied[:,1].max())+1,bottom+1],
            'lower_ring_region_pixels':int(lower.sum()),'lower_ring_visible_pixels':int((lower&visible).sum()),
            'lower_ring_visible_below_fist_pixels':int((lower&visible&below).sum()),
            'chain_region_pixels':int(chain.sum()),'chain_visible_pixels':int((chain&visible).sum()),
            'chain_visible_below_fist_pixels':int((chain&visible&below).sum()),
            'cap_ring_region_pixels':int(cap.sum()),'cap_ring_visible_pixels':int((cap&visible).sum()),
            'cap_ring_visible_below_fist_pixels':int((cap&visible&below).sum())}
        inputs.update({n:sha(capture/n) for n in names})
    front=views['front'];checks={
        'front_ring_top_bar_in_fist_silhouette':front['top_bar_allowance']['satisfied'],
        'front_lower_ring_visible_below_fist':front['lower_ring_visible_below_fist_pixels']>0,
        'front_chain_visible_below_fist':front['chain_visible_below_fist_pixels']>0,
        'front_ring_chain_below_fist_every_occupied_column':front['ring_chain_column_visibility']['satisfied']}
    if set(checks)!=set(policy['native_capture_requirements']):raise ValueError('Incomplete native capture gate policy')
    return {'passed':all(checks.values()),'checks':checks,'views':views,'native_images_sha256':inputs,
        'hanging_assembly_piece_ids':policy['native_capture_policy']['hanging_assembly_piece_ids'],
        'scope':'Required columns come from the complete projected lower grip-ring/held-chain/lantern-cap-ring region in the unoccluded native lantern solo, before depth-tested visibility. Every required column must show assembly pixels below its lowest hand pixel. Top bar inside or within 8 px above the native silhouette top.'}
