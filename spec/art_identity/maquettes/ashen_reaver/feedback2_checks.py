"""Native blade outline/area and shell-lame observations, independent of recipe paths."""
from collections import Counter
import math
import hashlib
import struct
import numpy as np
from spec.art_identity.maquettes.raster import project


def visible_mask_digest(path):
    from PIL import Image
    image=Image.open(path).convert('RGBA');pixels=np.asarray(image).copy()
    pixels[pixels[:,:,3]==0,:3]=0
    return hashlib.sha256(struct.pack('>II',*image.size)+pixels.tobytes()).hexdigest()


def projected_outline_areas(spec,outline):
    areas={}
    for view in ('front','rear'):
        xy=project(spec,outline,view)[:,:2]
        areas[view]=float(abs(np.dot(xy[:,0],np.roll(xy[:,1],-1))-np.dot(xy[:,1],np.roll(xy[:,0],-1)))/2)
    return areas


def blade_observation(spec,vertices,grip,direction,H):
    m=spec['mq16']['falchion'];design=spec['director_feedback2']['falchion']
    outer=vertices[m['outer_indices']];spine=vertices[m['spine_indices']];tip=vertices[m['blade_tip_vertex']]
    width=outer-spine;edge=width[0]/np.linalg.norm(width[0]);normal=np.cross(direction,edge);normal/=np.linalg.norm(normal)
    root=(outer[0]+spine[0])/2;length=float(np.dot(tip-root,direction));xs=np.einsum('ij,j->i',outer-root,direction)
    ys=np.einsum('ij,j->i',outer-root,edge);back=np.einsum('ij,j->i',spine-root,edge)
    maximum=m['maximum_width_row'];clip=m['clip_row'];pommel=vertices[m['pommel_vertex_start']:]
    full_length=float(np.dot(tip-grip,direction)-np.einsum('ij,j->i',pommel-grip,direction).min())
    widths=np.linalg.norm(width,axis=1);slopes=np.diff(np.r_[ys,0])/np.diff(np.r_[xs,length])
    clip_delta=tip-spine[clip];clip_axis=clip_delta/np.linalg.norm(clip_delta)
    residual=np.cross(spine[clip:]-spine[clip],clip_axis)
    areas=projected_outline_areas(spec,vertices[m['outline_indices']]);ratio=areas['rear']/areas['front']
    eps=1e-5;ratio_eps=1e-4;limits=design['projected_area_ratio_bounds']
    checks={
        'falchion_length_0_48_H':abs(full_length/H-design['pommel_to_tip_over_H'])<=ratio_eps,
        'falchion_guard_width':abs(widths[0]/H-design['guard_width_over_H'])<=ratio_eps,
        'falchion_maximum_width':abs(widths[maximum]/H-design['maximum_width_over_H'])<=ratio_eps and int(np.argmax(widths))==maximum,
        'falchion_width_peak_at_two_thirds':abs(xs[maximum]/length-design['maximum_width_fraction_from_guard'])<=ratio_eps,
        'falchion_spine_straight_before_clip':float(np.ptp(back[:clip+1]))<=eps,
        'falchion_clipped_back_last_0_08_H':abs((length-xs[clip])/H-design['clipped_back_axis_length_over_H'])<=ratio_eps and float(np.linalg.norm(residual,axis=1).max())<=eps,
        'falchion_convex_cutting_edge':bool(np.all(np.diff(slopes)<=ratio_eps) and np.max(ys-ys[0]*(1-xs/length))>eps),
        'falchion_vertical_plane':abs(normal[2])<=ratio_eps and edge[2]<0,
        'native_blade_projected_area_ratio':limits[0]<=ratio<=limits[1]}
    return {'checks':{k:bool(v) for k,v in checks.items()},'edge_direction':edge.tolist(),
        'face_normal':normal.tolist(),'pommel_to_tip_over_H':full_length/H,'guard_to_tip_over_H':length/H,
        'guard_width_over_H':float(widths[0]/H),'maximum_width_over_H':float(widths[maximum]/H),
        'maximum_width_fraction_from_guard':float(xs[maximum]/length),'clipped_back_axis_length_over_H':float((length-xs[clip])/H),
        'projected_area_px2':areas,'rear_over_front_area':ratio,
        'area_method':'Opened native midplane cutting-edge/spine outline; unoccluded blade only, excluding hilt and glow.'}


def pauldron_observation(spec,points,joints,H,faces,hits):
    design=spec['director_feedback2']['pauldrons'];eps=1e-5;rows={};checks={}
    for side in ('near','far'):
        ids=spec['mq16']['pauldrons'][side]['ids'];shoulder=np.asarray(joints['shoulder_'+side]);axis=np.asarray(joints['elbow_'+side])-shoulder;axis/=np.linalg.norm(axis)
        boxes=[(float(points[n+'_render'][:,2].min()),float(points[n+'_render'][:,2].max())) for n in ids]
        heights=[hi-lo for lo,hi in boxes];overlaps=[max(0,min(boxes[i][1],boxes[i+1][1])-max(boxes[i][0],boxes[i+1][0]))/heights[i] for i in (0,1)]
        height=design['bottom_below_shoulder_over_H']*H/(2*(1-design['overlap_fraction']))
        follow=[];closed=[];horizontal_area=[]
        for index,name in enumerate(ids):
            q=points[name+'_render'];fs=faces[name+'_render'];edges=Counter(tuple(sorted((a,b))) for f in fs for a,b in zip(f,f[1:]+f[:1]))
            closed.append(bool(edges) and all(n==2 for n in edges.values()))
            flat_area=0.
            for f in fs:
                polygon=q[f];area_vector=np.cross(polygon,np.roll(polygon,-1,axis=0)).sum(0)/2;area=np.linalg.norm(area_vector)
                if area and abs(area_vector[2])/area>=1-1e-6:flat_area+=float(area)
            horizontal_area.append(flat_area)
            if index:
                ring=q.reshape(-1,spec['mq16']['pauldrons'][side]['ring_samples'],3);means=ring.mean(1)
                expected=np.array([shoulder+axis*(min(0,z-shoulder[2])/axis[2]) for z in means[:,2]])
                expected[:,2]=means[:,2]
                follow.append(float(np.linalg.norm(means-expected,axis=1).max()))
        top=points[ids[0]+'_render'];pole=top[np.argmax(top[:,2])]
        drop=(shoulder[2]-min(b[0] for b in boxes))/H
        row_checks={'three_closed_shells':len(ids)==3 and all(closed),'one_third_overlaps':all(abs(v-design['overlap_fraction'])<=1e-4 for v in overlaps),
            'drop_0_07_H':abs(drop-design['bottom_below_shoulder_over_H'])<=1e-4,
            'domed_top_over_joint':np.linalg.norm(pole[:2]-shoulder[:2])<=eps and abs(heights[0]-height)<=eps and abs(boxes[0][0]-shoulder[2])<=eps,
            'cylinder_bands_follow_arm':all(v<=eps for v in follow),'equal_lame_heights':all(abs(v-height)<=eps for v in heights),
            'no_horizontal_disc_faces':all(v<=eps*eps for v in horizontal_area),'joint_covered':hits.get(side) is True}
        checks.update({side+'_'+name:bool(value) for name,value in row_checks.items()})
        rows[side]={'z_bounds_m':boxes,'heights_m':heights,'overlap_fractions':overlaps,'drop_over_H':float(drop),
                    'upper_arm_axis_error_m':follow,'horizontal_face_area_m2':horizontal_area}
    return {'checks':checks,'sides':rows}
