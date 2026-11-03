"""Director feedback 1: rounded cowl and folded, normally thick cloth."""
import math
import numpy as np
from spec.art_identity.maquettes.blender.closed_loft import loft
from .forms import oval,cord,shell,normal_sheet,union,TOPOLOGY

GARMENT_TOPOLOGY={'columns':73,'rows':19,'mask_meridians':49,'mask_columns':96}

def head(spec,u):
    H=spec['mq18']['height_m'];c=spec['source_calipers'];d=spec['dimensions'];j=spec['joints'];pieces=spec['pieces']
    pitch=math.radians(spec['pose']['hip_lean_degrees']+spec['pose']['head_additional_pitch_degrees'])
    axes=np.array([[math.cos(pitch),0,-math.sin(pitch)],[0,1,0],[math.sin(pitch),0,math.cos(pitch)]])
    origin=np.array(j['head']);rx=c['hood_depth_px']*u/2;ry=c['hood_width_px']*u/2
    height=(H-origin[2])/math.cos(pitch)
    rows=[]
    for t in np.linspace(0,1,GARMENT_TOPOLOGY['rows']):
        radial=max(.015,math.sqrt(max(0,1-((t-.40)/.60)**2)))
        mask_front=rx*.25+d['mask_height_over_H']*H*c['mask_convex_depth_height_ratio']
        opening=math.acos(min(.99,mask_front/rx))*min(1,(1-t)/.2)
        row=[]
        for a in np.linspace(opening,math.tau-opening,GARMENT_TOPOLOGY['columns']):
            local=np.array([rx*radial*math.cos(a),ry*radial*math.sin(a),t*height])
            local[0]-=abs(math.sin(3*a))*.4*u*(1-t)
            row.append((origin+local@axes).tolist())
        rows.append(row)
    hood=normal_sheet('draped_hood','hood','head',rows,d['hood_thickness_over_H']*H)
    # The two mouth edges and rounded upper arch share one thick cloth roll.
    path=[row[0] for row in rows]+[row[-1] for row in rows[-2::-1]]
    roll=cord('cowl_rolled_edge','hood','head',path,d['cowl_roll_diameter_over_H']*H/2)
    maximum=max(np.asarray(piece['vertices'])[:,2].max() for piece in (hood,roll))
    shift=H-maximum
    for piece in (hood,roll):
        a=np.asarray(piece['vertices']);a[:,2]+=shift;piece['vertices']=a.tolist();pieces.append(piece)
    centre=origin+np.array([rx*.25,0,height*.51])@axes+[0,0,shift]
    mh=d['mask_height_over_H']*H;mw=mh*c['mask_width_height_ratio'];md=mh*c['mask_convex_depth_height_ratio']
    # Convex oval with a real deep cross recess, closed by a dark inner plate.
    sections=[]
    for t in np.linspace(-math.pi/2,math.pi/2,GARMENT_TOPOLOGY['mask_meridians']):
        r=max(.001,math.cos(t));sections.append([0,0,mh/2*math.sin(t),md*r,mw/2*r])
    v,f,flat=loft({'sections':sections,'samples':GARMENT_TOPOLOGY['mask_columns']})
    v=np.asarray(v);w=mh*c['slit_width_mask_height_ratio']/2
    slot=((abs(v[:,1])<w)&(abs(v[:,2])<mh*c['slit_vertical_mask_height_ratio']/2))|((abs(v[:,2])<w)&(abs(v[:,1])<mh*c['slit_horizontal_mask_height_ratio']/2))
    v[(v[:,0]>0)&slot,0]-=.002*H
    pieces.append(shell('convex_mask','head','head',(centre+np.einsum('nj,jk->nk',v,axes)).tolist(),f,flat))
    bars=[]
    for wy,hz in [(w,mh*c['slit_vertical_mask_height_ratio']/2),(mh*c['slit_horizontal_mask_height_ratio']/2,w)]:
        rows=[]
        for z in np.linspace(-hz,hz,13):
            row=[]
            for y in np.linspace(-wy,wy,9):
                x=md*math.sqrt(max(0,1-(y/(mw/2))**2-(z/(mh/2))**2))-.001*H
                row.append((centre+np.array([x,y,z])@axes).tolist())
            rows.append(row)
        bars.append(normal_sheet('cross','head','head',rows,.0005*H))
    backing=union('mask_cross_backing','head','head',bars);backing['clay_colour']=[.015,.015,.015];pieces.append(backing)
    # Dark geometry appears through the native recess; no separate painted view.
    spec['native_features']['mask']={'part':'head','objects':['convex_mask'],'visibility':{'front':'visible','rear':'occluded'}}
    spec['native_features']['cross_slit']={'part':'head','objects':['mask_cross_backing'],'visibility':{'front':'visible','rear':'occluded'}}


def cloth(spec,u,cx):
    H=spec['mq18']['height_m'];j=spec['joints'];c=spec['source_calipers'];d=spec['dimensions'];pieces=spec['pieces']
    W=abs(j['shoulder_near'][1]-j['shoulder_far'][1]);shear=spec['mq18']['shoulder_shear'];neck=j['head'][2]
    rows=[]
    for t in np.linspace(0,1,7):
        radius=(1-t)*c['hood_width_px']*u/2+t*(W/2+.03*H)
        z=neck*(1-t)+(j['shoulder_near'][2]-.025*H)*t
        rows.append([[cx(z)+(c['hood_depth_px']*u/2*(1-t)+.055*H*t)*math.cos(a)-shear*radius*math.sin(a),
            radius*math.sin(a),z+.01*H*math.cos(3*a)*math.sin(math.pi*t)] for a in np.linspace(0,math.tau,49,endpoint=False)])
    pieces.append(normal_sheet('shoulder_mantle','mantle','torso',rows,d['hood_thickness_over_H']*H,periodic=True))
    # One continuous open wrap. Its front far flap and back near flap follow
    # the source robe; the open near-front sector exposes the near leg.
    rows=[];hem=np.asarray(c['robe_hem_y']);knee=min(j['knee_near'][2],j['knee_far'][2]);mid_shin=(knee+min(j['ankle_near'][2],j['ankle_far'][2]))/2
    for t in np.linspace(0,1,GARMENT_TOPOLOGY['rows']):
        row=[]
        for k,a in enumerate(np.linspace(math.pi/2,math.tau,GARMENT_TOPOLOGY['columns'])):
            s=k/(GARMENT_TOPOLOGY['columns']-1)
            hem_z=mid_shin+(max(hem)-np.interp(s,np.linspace(0,1,len(hem)),hem))/(max(hem)-min(hem))*(knee-mid_shin)
            z=(j['shoulder_near'][2]-.025*H)*(1-t)+hem_z*t
            radius=float(np.interp(z,[mid_shin,j['pelvis'][2],j['shoulder_near'][2]],
                [c['robe_half_width_px']*u,d['chest_width_over_H']*H/2,W/2]))
            if math.sin(a)<0:radius=(1-t)*W/2+t*c['robe_half_width_px']*u
            fold=c['robe_fold_depth_px']*u*math.sin(12*math.pi*s)*math.sin(math.pi*t/2)
            x=cx(z)+(c['torso_depth_px']*u/2+fold+d['robe_thickness_over_H']*H/2)*math.cos(a)-shear*radius*math.sin(a)*max(0,(z-j['pelvis'][2])/(j['shoulder_near'][2]-j['pelvis'][2]))
            row.append([x,(radius+fold)*math.sin(a),z])
        rows.append(row)
    rows=seat_robe(rows,spec)
    pieces.append(normal_sheet('tattered_robe','robe','torso',rows,d['robe_thickness_over_H']*H))


def seat_robe(rows,spec):
    """Drape below the waist around the actual enlarged leg envelopes.

    The waist width follows the native barrel. Free lower fabric keeps its
    source flare; cloth is then seated outside the leg armour plus half its
    specified thickness, so the signature item clears the robe naturally.
    """
    result=np.asarray(rows);j=spec['joints'];d=spec['dimensions'];H=spec['mq18']['height_m']
    clearance=d['robe_thickness_over_H']*H/2
    profiles=[]
    for side in ('near','far'):
        for name,a,b in [('thigh','hip','knee'),('shin','knee','ankle')]:
            start=np.asarray(j[a+'_'+side]);end=np.asarray(j[b+'_'+side]);axis=end-start;length=np.linalg.norm(axis);direction=axis/length
            v=np.asarray(next(p['vertices'] for p in spec['pieces'] if p['id']==name+'_plate_'+side))
            groups=v.reshape(-1,6,TOPOLOGY['ring_samples'],3);sections=[]
            for group in groups:
                centres=group.mean(1);t=np.einsum('nj,j->n',centres-start,direction)/length
                radius=np.linalg.norm(group-centres[:,None],axis=2).mean(1)
                sections.append((t,radius))
            profiles.append((start,axis,sections))
    for row in result:
        for point in row:
            if point[2]>=j['pelvis'][2]:continue
            for start,axis,sections in profiles:
                t=np.dot(point-start,axis)/np.dot(axis,axis)
                active=[np.interp(t,ts,rs) for ts,rs in sections if ts[0]<=t<=ts[-1]]
                if not active:continue
                centre=start+t*axis;radial=point-centre;distance=np.linalg.norm(radial)
                radius=max(active)+clearance
                if 0<distance<radius:point[:]=centre+radial*radius/distance
    return result.tolist()
