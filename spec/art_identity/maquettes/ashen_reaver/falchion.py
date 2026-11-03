"""Director feedback-2 falchion: clipped spine, convex edge, vertical plane."""
import math
import numpy as np
from PIL import Image
from .forms import cord,oval,shell,union,TOPOLOGY
from .source_measurements import PROJECT

BLADE_NUMERICS={'axis_stations':48,'cross_samples':6}


def profile(t,blade_length,H,design):
    maximum=design['maximum_width_fraction_from_guard']
    spine=-design['guard_width_over_H']*H/2
    peak=spine+design['maximum_width_over_H']*H
    start=-spine
    if t<=maximum:
        cutting=peak-(peak-start)*(1-t/maximum)**2
    else:
        cutting=peak*(1-((t-maximum)/(1-maximum))**2)
    clip=1-design['clipped_back_axis_length_over_H']*H/blade_length
    back=spine if t<=clip else spine*(1-(t-clip)/(1-clip))
    return cutting,back


def build_falchion(spec,u,calipers):
    c=calipers;p=spec['pose'];design=spec['director_feedback2']['falchion']
    H=spec['mq16']['height_m'];g=np.asarray(spec['joints']['hand_far'])
    down,out=map(math.radians,[p['blade_down_degrees'],p['blade_outward_degrees']])
    horizontal=np.array([math.cos(out),-math.sin(out),0.])
    direction=horizontal*math.cos(down)+np.array([0,0,-math.sin(down)])
    edge=np.array([0.,0,-1.]);edge-=direction*np.dot(edge,direction);edge/=np.linalg.norm(edge)
    normal=np.cross(direction,edge);normal/=np.linalg.norm(normal)
    grip_half=c['grip_half_length_px']*u;pommel_radius=c['pommel_radius_px']*u
    # Overall axial length includes the pommel's terminal surface, not only
    # its centre. The grip remains centred through the approved fist.
    total_length=design['pommel_to_tip_over_H']*H
    tip_offset=total_length-grip_half-pommel_radius
    guard_at=g+direction*grip_half;blade_length=tip_offset-grip_half
    clip_fraction=1-design['clipped_back_axis_length_over_H']*H/blade_length
    if not design['maximum_width_fraction_from_guard']<clip_fraction<1:
        raise ValueError('Clipped back must start after maximum blade width')
    ts=sorted(set(np.linspace(0,1,BLADE_NUMERICS['axis_stations']+1).tolist()+
                  [design['maximum_width_fraction_from_guard'],clip_fraction]))
    vertices=[];faces=[];outer=[];spine=[]
    for row,t in enumerate(ts[:-1]):
        cutting,back=profile(t,blade_length,H,design)
        centre=guard_at+direction*(t*blade_length)
        depth=min(c['blade_half_thickness_px']*u,(cutting-back)/4)
        cross=[(cutting,0),(cutting-depth,depth),(back+depth,depth),
               (back,0),(back+depth,-depth),(cutting-depth,-depth)]
        for transverse,thick in cross:vertices.append((centre+edge*transverse+normal*thick).tolist())
        outer.append(row*BLADE_NUMERICS['cross_samples']);spine.append(row*BLADE_NUMERICS['cross_samples']+3)
        if row:
            for k in range(BLADE_NUMERICS['cross_samples']):
                a=(row-1)*BLADE_NUMERICS['cross_samples'];b=row*BLADE_NUMERICS['cross_samples'];n=(k+1)%BLADE_NUMERICS['cross_samples']
                faces.append([a+k,a+n,b+n,b+k])
    faces.append(list(reversed(range(BLADE_NUMERICS['cross_samples']))))
    tip_index=len(vertices);tip=g+direction*tip_offset;vertices.append(tip.tolist())
    a=(len(ts)-2)*BLADE_NUMERICS['cross_samples']
    for k in range(BLADE_NUMERICS['cross_samples']):faces.append([a+k,a+(k+1)%BLADE_NUMERICS['cross_samples'],tip_index])
    blade=shell('falchion_blade','falchion','hand_far',vertices,faces)
    grip=cord('falchion_grip','falchion','hand_far',[(g-direction*grip_half).tolist(),guard_at.tolist()],c['grip_radius_px']*u)
    guard=cord('falchion_guard','falchion','hand_far',[(guard_at-normal*c['guard_half_width_px']*u).tolist(),
        (guard_at+normal*c['guard_half_width_px']*u).tolist()],c['grip_radius_px']*u)
    pommel=oval('falchion_pommel','falchion','hand_far',g-direction*grip_half,[pommel_radius]*3,
                [normal,-edge,direction])
    spec['pieces'].append(union('falchion','falchion','hand_far',[blade,grip,guard,pommel]))
    cutting_path=[blade['vertices'][i] for i in outer]+[blade['vertices'][tip_index]]
    glowing=cord('glowing_edge','falchion','hand_far',cutting_path,c['glowing_edge_radius_px']*u)
    source='assets/units/guardians/ashen_reaver/front/blade.png'
    pixels=np.asarray(Image.open(PROJECT/source).convert('RGBA'))
    accent=(pixels[:,:,0]>2*pixels[:,:,1].astype(int))&(pixels[:,:,1]>30)&(pixels[:,:,3]>=128)
    srgb=pixels[accent,:3].mean(0)/255
    glowing['accent_colour']=np.where(srgb<=.04045,srgb/12.92,((srgb+.055)/1.055)**2.4).tolist()
    spec['pieces'].append(glowing)
    maximum_row=ts.index(design['maximum_width_fraction_from_guard']);clip_row=ts.index(clip_fraction)
    spec['mq16']['falchion']={'direction':direction.tolist(),'edge_direction':edge.tolist(),'face_normal':normal.tolist(),
        'tip_world':tip.tolist(),'grip_world':g.tolist(),'pommel_world':(g-direction*grip_half).tolist(),
        'blade_tip_vertex':tip_index,'blade_vertex_count':len(vertices),'blade_face_count':len(faces),
        'grip_vertex_start':len(vertices),'pommel_vertex_start':len(vertices)+len(grip['vertices'])+len(guard['vertices']),
        'sweep_samples':TOPOLOGY['sweep_samples'],'blade_ring_samples':BLADE_NUMERICS['cross_samples'],
        'outer_indices':outer,'spine_indices':spine,'outline_indices':outer+[tip_index]+list(reversed(spine)),
        'maximum_width_row':maximum_row,'clip_row':clip_row,'station_fractions':ts,
        'grip_length_m':grip_half*2,'grip_radius_m':c['grip_radius_px']*u,
        'accent_source_path':source,'accent_source_mean_srgb':srgb.tolist()}
