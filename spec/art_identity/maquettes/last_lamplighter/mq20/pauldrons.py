"""Whole torso-owned plates; visible finish controls come only from the owner."""
import math
import numpy as np
from ..forms import shell,cord,oval,union

TOPOLOGY={'corner_samples':9,'radial_stations':9}


def outline(width,height,radius):
    if not 0<radius<min(width,height)/2:raise ValueError('Owner corner radius must fit the plate')
    return np.array([[0,sy*(width/2-radius)+radius*math.cos(a),sz*(height/2-radius)+radius*math.sin(a)]
        for sy,sz,start in [(1,1,0),(-1,1,90),(-1,-1,180),(1,-1,270)]
        for a in np.radians(np.linspace(start,start+90,TOPOLOGY['corner_samples']))])


def plate(identifier,part,contour,thickness,convexity):
    if not 0<convexity<thickness:raise ValueError('Convexity must be positive and below plate thickness')
    count=len(contour);vertices=[[thickness/2,0,0]];faces=[]
    for r in np.linspace(0,1,TOPOLOGY['radial_stations'])[1:]:
        ring=contour*r;ring[:,0]=thickness/2-convexity*r*r;vertices+=ring.tolist()
    for k in range(count):faces.append([0,1+k,1+(k+1)%count])
    for row in range(TOPOLOGY['radial_stations']-2):
        a=1+row*count;b=a+count
        for k in range(count):faces.append([a+k,b+k,b+(k+1)%count,a+(k+1)%count])
    edge=1+(TOPOLOGY['radial_stations']-2)*count;back=len(vertices)
    ring=contour.copy();ring[:,0]=-thickness/2;vertices+=ring.tolist()
    faces.append(list(reversed(range(back,back+count))))
    for k in range(count):faces.append([edge+k,back+k,back+(k+1)%count,edge+(k+1)%count])
    return shell(identifier,part,'torso',vertices,faces)


def build(spec,surface,placement):
    if surface is None or placement is None:return
    H=spec['mq18']['height_m'];d=spec['dimensions'];j=spec['joints'];pieces=spec['pieces']
    width=d['pauldron_width_over_H']*H;height=d['pauldron_height_over_H']*H;thickness=d['pauldron_thickness_over_H']*H
    contour=outline(width,height,surface['corner_radius_over_H']*H);convexity=surface['convexity_over_H']*H
    rim_width=surface['rim_width_over_H']*H;rim_proud=surface['rim_proud_over_H']*H
    cross_width=surface['cross_width_over_H']*H;proud=d['pauldron_cross_proud_over_H']*H
    for side,sign in [('near',1),('far',-1)]:
        part='pauldron_'+side;tilt=math.radians(d['pauldron_outward_degrees'])
        axes=np.array([[1,0,0],[0,math.cos(tilt),-sign*math.sin(tilt)],[0,sign*math.sin(tilt),math.cos(tilt)]])
        centre=np.asarray(j['shoulder_'+side])+np.array([*placement[side+'_xy_over_H'],0])*H
        centre[2]=H-placement['hood_top_gap_over_H']*H-(np.einsum('nj,jk->nk',contour,axes))[:,2].max()
        panel=plate(part+'_panel',part,contour,thickness,convexity);panel['clay_colour']=[.025,.025,.025]
        local=[panel];rim=[]
        for face in (-1,1):
            path=contour.copy();path[:,0]=face*(thickness/2+(rim_proud-rim_width/2))
            # Both sides carry rims and rivets; only the +X face has a cross.
            rim.append(cord('rim',part,'torso',[*path.tolist(),path[0].tolist()],rim_width/2))
            for y,z in surface['rivets_yz_over_H']:
                radius=surface['rivet_radius_over_H']*H
                local.append(oval(part+('_front' if face==1 else '_back')+'_rivet_'+str(len(local)),part,'torso',
                    [face*(thickness/2+rim_proud),y*H,z*H],[radius]*3))
        local.append(union(part+'_rims',part,'torso',rim))
        # Rectangular raised cross ribs have flat back faces; no rear cross.
        ribs=[]
        for wy,hz in [(cross_width/2,height/2-rim_width),(width/2-rim_width,cross_width/2)]:
            v=[[x,y,z] for x in (thickness/2,thickness/2+proud) for y,z in [(-wy,-hz),(wy,-hz),(wy,hz),(-wy,hz)]]
            ribs.append(shell('rib',part,'torso',v,[[3,2,1,0],[4,5,6,7]]+[[k,(k+1)%4,(k+1)%4+4,k+4] for k in range(4)]))
        local.append(union(part+'_cross',part,'torso',ribs))
        # The approved top-edge placement leaves a small gap above the
        # shoulder mantle. Seat a torso-owned mounting stem in that gap;
        # its diameter is the existing rim width, with no plate displacement.
        mantle=np.einsum('nj,kj->nk',np.asarray(next(q for q in pieces if q['id']=='shoulder_mantle')['vertices'])-centre,axes)
        candidates=mantle[(abs(mantle[:,0])<thickness/2)&(abs(mantle[:,1])<width/2-surface['corner_radius_over_H']*H)]
        if not len(candidates):raise ValueError('No mantle contact under '+part)
        contact=candidates[np.argmax(candidates[:,2])]
        top=contact.copy();top[2]=-height/2+rim_width/2
        if contact[2]<top[2]:local.append(cord(part+'_mount',part,'torso',[contact.tolist(),top.tolist()],rim_width/2))
        for q in local:
            q['vertices']=(centre+np.einsum('nj,jk->nk',np.asarray(q['vertices']),axes)).tolist();pieces.append(q)
        spec['native_features'][part]={'part':part,'objects':[part+'_panel',part+'_rims',part+'_cross'],
            'visibility':{'front':'visible','rear':'visible'}}
        spec['native_features'][part+'_front_cross']={'part':part,'objects':[part+'_cross'],
            # A front relief can expose its projecting edge in a rear
            # oblique view. Plain backs are checked from the opened native
            # face normal in surface_checks, not by hiding front-side tips.
            'visibility':{'front':'visible'}}
