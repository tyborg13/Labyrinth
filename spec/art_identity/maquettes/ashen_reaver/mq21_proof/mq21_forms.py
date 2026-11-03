"""Angular helm, continuous leg armour and pelvis-owned rear cloth."""
import math
import numpy as np
from spec.art_identity.maquettes.blender.closed_loft import loft
from ..forms import shell, closed_sheet, oval, TOPOLOGY
from .mq21_pose import rotation_y


def helm(spec,c,u,design,old_visor):
    j=spec['joints'];H=spec['mq16']['height_m'];head=np.asarray(j['head'])
    d=design['helm'];radius=c['helm_radius_px']*u;height=c['helm_height_px']*u
    dome=H*d['dome_height_over_H'];top=d['top_width_over_base']
    n=d['cross_section_sides']
    # Preserve the source visor width plus its existing one-stroke border.
    # A regular inscribed octagon would leave that cross floating off its face.
    face_half=(c['visor_horizontal_half_width_px']+c['visor_width_px'])*u
    cut=face_half/radius
    section=np.array([[1,cut],[cut,1],[-cut,1],[-1,cut],[-1,-cut],[-cut,-1],[cut,-1],[1,-cut]])
    sections=[[0,0,0,radius,radius],[0,0,height-dome,radius*top,radius*top],
              [0,0,height,radius*c['helm_stations'][-1][1],radius*c['helm_stations'][-1][1]]]
    v=[[x*rx,y*ry,z] for _,_,z,rx,ry in sections for x,y in section]
    f=[[row*n+k,row*n+(k+1)%n,(row+1)*n+(k+1)%n,(row+1)*n+k] for row in range(2) for k in range(n)]
    f.extend([list(reversed(range(n))),list(range(2*n,3*n))])
    turn=rotation_y(spec['pose']['head_pitch_down_degrees'])
    transform=lambda q:(np.einsum('ij,kj->ik',np.asarray(q),turn)+head).tolist()
    spec['pieces'].append(shell('great_helm','head','head',transform(v),f,range(len(f))))
    # The cross lies in the flat +X octagonal plane and follows its taper.
    half=c['visor_width_px']*u/2;z=height*.58;epsilon=1e-6
    def front(z):return radius*(1+(top-1)*z/(height-dome))
    rows=[[[front(z+dz)+epsilon,y,z+dz] for y in (-c['visor_horizontal_half_width_px']*u,c['visor_horizontal_half_width_px']*u)] for dz in (-half,half)]
    a=closed_sheet('visor_horizontal','head','head',rows,2*epsilon,[1,0,0])
    rows=[[[front(q)+epsilon,y,q] for y in (-half,half)] for q in (z-c['visor_vertical_height_px']*u,z+half)]
    b=closed_sheet('visor_vertical','head','head',rows,2*epsilon,[1,0,0])
    from ..forms import union
    visor=union('cross_visor','head','head',[a,b]);visor['vertices']=transform(visor['vertices'])
    visor['clay_colour']=old_visor['clay_colour'];spec['pieces'].append(visor)
    # Fin follows the angular crown surface; its top rises toward -X (rear).
    extent=radius*top;half_thick=d['crest_thickness_over_H']*H/2
    crest=[]
    for x,t in ((extent,0),(0,.5),(-extent,1)):
        base=height-dome*abs(x)/extent
        crest_height=H*((1-t)*d['crest_front_height_over_H']+t*d['crest_rear_height_over_H'])
        crest.append([[x,-half_thick,base],[x,half_thick,base],
                      [x,half_thick,base+crest_height],
                      [x,-half_thick,base+crest_height]])
    vertices=np.asarray(crest).reshape(-1,3);faces=[]
    for row in range(2):
        for k in range(4):faces.append([row*4+k,row*4+(k+1)%4,(row+1)*4+(k+1)%4,(row+1)*4+k])
    faces.extend([[3,2,1,0],[8,9,10,11]])
    spec['pieces'].append(shell('helm_crest','head','head',transform(vertices),faces,range(len(faces))))
    spec['mq21']['helm']={'ring_samples':n,'ring_count':3,'crest_station_count':3}


def leg_axes(start,end):
    axis=np.subtract(end,start);axis/=np.linalg.norm(axis)
    front=np.array([1.,0,0])-axis*axis[0];front/=np.linalg.norm(front)
    lateral=np.cross(axis,front)
    return front,lateral,axis


def leg(spec,side,c,u,design):
    j=spec['joints'];H=spec['mq16']['height_m'];d=design['legs']
    radii={name:d[name+'_size_over_H']*H/2 for name in ('hip','knee','calf','ankle')}
    for name,start,end,stations in (
        ('thigh','hip','knee',[(0,radii['hip']),(1,radii['knee'])]),
        ('shin','knee','ankle',[(0,radii['knee']),(d['calf_bulge_fraction_from_knee'],radii['calf']),(1,radii['ankle'])])):
        a=np.asarray(j[start+'_'+side]);b=np.asarray(j[end+'_'+side]);front,lateral,_=leg_axes(a,b)
        sections=[[*((1-t)*a+t*b),r*d['depth_over_width'],r] for t,r in stations]
        v,f,flat=loft({'sections':sections,'samples':TOPOLOGY['ring_samples'],'axes':[front.tolist(),lateral.tolist()]})
        spec['pieces'].append(shell(name+'_plate_'+side,name+'_'+side,start+'_'+side,v,f,flat))
    knee=np.asarray(j['knee_'+side]);sign=1 if side=='near' else -1
    cop_radius=d['knee_cop_diameter_over_H']*H/2
    front,lateral,axis=leg_axes(j['knee_'+side],j['ankle_'+side])
    spec['pieces'].append(oval('round_knee_'+side,'shin_'+side,'knee_'+side,
        knee+front*radii['knee']*d['depth_over_width'],
        [cop_radius*d['depth_over_width'],cop_radius,cop_radius],[front,lateral,axis]))
    from .mq21_knee_wing import build
    build(spec,side,c,u,design)
    # Inherit the mq-16 padded joint envelope, confined to the back of the knee.
    spec['pieces'].append(oval('knee_gambeson_'+side,'shin_'+side,'knee_'+side,
        knee+[-radii['knee']*d['depth_over_width']/2,0,0],
        [radii['knee']*d['depth_over_width']/2,radii['knee'],c['knee_depth_px']*u]))


def back_tabard(spec,c,u,design):
    j=spec['joints'];H=spec['mq16']['height_m'];d=design['back_tabard']
    hip_width=j['hip_near'][1]-j['hip_far'][1];half=d['width_over_hip_width']*hip_width/2
    tears=np.asarray(d['tear_depths_over_H'])*H
    hem=d['accepted_hem_height_m']
    x=-c['torso_depth_radius_px']*u
    fractions=np.linspace(0,1,2*d['torn_points']+1)
    fractions[1::2]=d['tear_positions_across_width'];ys=(fractions*2-1)*half
    heights=[hem-(tears[(k-1)//2] if k%2 else 0) for k in range(len(ys))]
    rows=[[[x,y,j['pelvis'][2]] for y in ys],[[x,y,z] for y,z in zip(ys,heights)]]
    piece=closed_sheet('back_tabard','tabard','pelvis',rows,c['tabard_thickness_px']*u,[-1,0,0])
    # Match the existing tabard's material/label; clay remains the shared clay.
    spec['pieces'].append(piece)
