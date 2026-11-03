"""Director feedback 3: shoulder-tucked, five-fold, physically measured cloak.

The 200 degree wrap is fixed. Width ratios, not the wrap, absorb root-arc
length differences. All dimensions here use the unchanged mq-17 height gauge.
"""
import math
from functools import lru_cache
import numpy as np

MESH_DEFAULTS = {'solid_rows':129, 'columns':161, 'strip_rows':17,
                 'arc_samples':4097, 'parameter_digits':12, 'solve_iterations':70,
                 'tear_axis_degrees':[0.,0.,0.]}
STRIP_WIDTHS = [.04,.06,.03,.05,.04,.06,.03,.05,.05]
STRIP_LENGTHS = [.08,.15,.05,.13,.06,.15,.05,.12,.17]
HOLES = [[-35.,.38,.025],[10.,.42,.020],[45.,.34,.030]]
NOTCHES = {'far':[[.62,.020],[.48,.020]], 'near':[[.66,.025],[.52,.025],[.40,.025]]}
FOLD_WEIGHTS = [1.,.8,1.2,.9,1.1]


def rule_fields():
    return {'owner':'torso','shoulder_wrap_degrees':200,'root_wrap_degrees':200,
        'root_centre_over_H':.30,'root_sides_over_H':.27,
        'hem_span_over_shoulders':1.15,'near_flare_over_L':.05,'near_longest_tip_over_H':.10,
        'folds':5,'fold_phase_radians':math.pi/2,
        'fold_amplitude_shoulders_over_H':0.,'fold_amplitude_root_over_H':.02,
        'fold_amplitude_multipliers':FOLD_WEIGHTS,'thickness_over_H':.008,
        'attachment_tuck_over_H':.01,'minimum_back_coverage':.95,
        'coverage_domain':'world_shoulder_plane',
        'standoff_shoulders_over_H':.02,'standoff_root_over_H':.035,'slit_start_above_root_over_H':.03,
        'front_far_exposure_limit_over_H':.06,
        'strip_widths_over_H':STRIP_WIDTHS,'strip_lengths_over_H':STRIP_LENGTHS,
        'strip_length_multiplier':1.5,'minimum_tip_over_H':.06,'cut_width_over_H':.008,
        'holes':HOLES,'tear_aspect_ratio':2.,'tear_axis_degrees':MESH_DEFAULTS['tear_axis_degrees'],
        'side_notches':NOTCHES,'notch_half_height_over_depth':1.5}


def fold_weight(u):
    """Smoothly join amplitudes at the five valley centres; no radial steps."""
    u=np.asarray(u);centres=(np.arange(5)+.5)/5
    index=np.clip(np.searchsorted(centres,u)-1,0,3)
    t=np.clip((u-centres[index])/(centres[index+1]-centres[index]),0,1)
    t=(1-np.cos(math.pi*t))/2
    weights=np.asarray(FOLD_WEIGHTS)
    return weights[index]*(1-t)+weights[index+1]*t


def wave(u):
    return fold_weight(u)*np.sin(10*math.pi*np.asarray(u)+math.pi/2)


def generate(spec):
    H=spec['mq19']['gauge_H_m'];L=spec['mq19']['gauge_L_m'];j=spec['joints']
    from .pose import rotation
    p=spec['mq19']['design']['pose'];r=spec['mq19']['design']['pose_resolution']['chest_roll_degrees']
    frame=rotation([0,0,1],p['chest_yaw_toward_viewer_degrees'])@rotation([0,1,0],p['forward_lean_degrees'])@rotation([1,0,0],r)
    width=abs((np.subtract(j['shoulder_near'],j['shoulder_far'])@frame)[1])/H
    # The shoulder attachment follows its actual line, but the hanging hem
    # settles across the anatomical back, rather than inheriting the diagonal
    # shoulder caliper as a rigid radial frame all the way down to the calves.
    forward=rotation([0,0,1],p['chest_yaw_toward_viewer_degrees'])[:,0]
    transverse=np.array([-forward[1],forward[0],0.])
    wrap=np.column_stack([forward,transverse,[0.,0.,1.]])
    body=np.einsum('nj,jk->nk',np.concatenate([np.asarray(x['vertices'])/H for x in spec['pieces'] if x['part'] in ('torso','pelvis')]),wrap)
    projected=sorted(set((float(z),float(x)) for x,y,z in body))
    def cross(a,b,c):return (b[0]-a[0])*(c[1]-a[1])-(b[1]-a[1])*(c[0]-a[0])
    halves=[]
    for ordered in (projected,projected[::-1]):
        half=[]
        for point in ordered:
            while len(half)>=2 and cross(half[-2],half[-1],point)<=0:half.pop()
            half.append(point)
        halves.append(half)
    hull=halves[0][:-1]+halves[1][:-1]
    shoulder=(np.asarray([j['shoulder_far'],j['shoulder_near']])/H)@wrap
    hip_z=np.mean([j['hip_near'][2],j['hip_far'][2]])/H
    def raw_envelope(z):
        z=max(hip_z,min(float(shoulder[:,2].mean()),z));hits=[]
        for a,b in zip(hull,hull[1:]+hull[:1]):
            if min(a[0],b[0])<=z<=max(a[0],b[0]) and abs(b[0]-a[0])>1e-12:
                hits.append(a[1]+(b[1]-a[1])*(z-a[0])/(b[0]-a[0]))
        return min(hits),max(hits)
    # Smooth the polygonal body envelope so its armour corners cannot print
    # a horizontal ridge into the cloth. The smoothing radius is .02 H.
    zs=np.linspace(hip_z,float(shoulder[:,2].mean()),257)
    samples_x=np.asarray([raw_envelope(z) for z in zs]);sigma=.02/(zs[1]-zs[0])
    offsets=np.arange(-int(3*sigma),int(3*sigma)+1);kernel=np.exp(-.5*(offsets/sigma)**2);kernel/=kernel.sum()
    smooth_x=np.column_stack([np.convolve(np.pad(samples_x[:,k],(len(offsets)//2,)*2,mode='edge'),kernel,mode='valid') for k in range(2)])
    def envelope(z):return tuple(float(np.interp(z,zs,smooth_x[:,k])) for k in range(2))
    root_span=1.15*width;gap=.008;angle=math.radians(200)
    shear=0.
    samples=np.linspace(0,1,MESH_DEFAULTS['arc_samples'])
    # Unequal edge amplitudes must not alter the prescribed chord.
    def chord_radius(span,amplitude):
        edge_delta=forward[1]*amplitude*(wave(0.)-wave(1.))*math.cos(angle/2)
        return (span-edge_delta)/(2*transverse[1]*math.sin(angle/2))-amplitude*(wave(0.)+wave(1.))/2
    root_radius=chord_radius(root_span,.02)
    def root_curve(u):
        u=np.asarray(u);theta=angle*(u-.5);rad=root_radius+.02*wave(u)
        low,high=envelope(.30);cx=(low+high)/2
        rx=cx-low+.035-.02*wave(.5)
        return np.stack([cx-(rx+.02*wave(u))*np.cos(theta)-shear*root_radius*np.sin(theta),rad*np.sin(theta),.30-.03*abs(2*u-1)],axis=-1)
    curve=root_curve(samples)
    distance=np.r_[0,np.cumsum(np.linalg.norm(np.diff(curve,axis=0),axis=1))]
    width_scale=(distance[-1]-8*gap)/sum(STRIP_WIDTHS)
    if width_scale<=0:raise ValueError('Root arc cannot accommodate eight cuts')
    physical_widths=np.asarray(STRIP_WIDTHS)*width_scale
    boundaries=[];cursor=0.
    for value in physical_widths:
        boundaries.append([float(np.interp(cursor,distance,samples)),float(np.interp(cursor+value,distance,samples))])
        cursor+=value+gap
    gap_samples=np.concatenate([np.linspace(boundaries[i][1],boundaries[i+1][0],17) for i in range(8)])
    us=np.unique(np.round(np.r_[np.linspace(0,1,MESH_DEFAULTS['columns']),np.asarray(boundaries).ravel(),gap_samples],MESH_DEFAULTS['parameter_digits']))

    from .attachment import sampler
    sample=sampler(spec)
    # The fold starts under the hood: a smooth top seam seats both skins
    # inside the support; folds grow below it rather than bunching over it.
    sink=.006
    @lru_cache(maxsize=None)
    def attachment(u):
        support=sample(u)
        q=support['on_surface']-sink*support['radial']
        return q@wrap
    caps={side:np.asarray(next(p for p in spec['pieces'] if p['id']=='pauldron_'+side)['vertices'])[0]@wrap/H for side in ('far','near')}
    top=np.asarray([attachment(u)@wrap.T for u in us]);top_z=float(top[:,2].max())
    centre_y=float(shoulder[:,1].mean());target_near=j['hip_near'][1]/H+.05*L/H
    root_near=root_curve(1.)
    root_centre_y=(target_near-forward[1]*root_near[0])/transverse[1]-root_near[1]
    top_centre_z=float(attachment(.5)[2])
    def surface(t,u):
        theta=angle*(u-.5);amplitude=.02*t
        direction=np.array([-math.cos(theta),math.sin(theta),0.])
        q=attachment(u);top_base=q
        root_z=.30-.03*abs(2*u-1);z=(1-t)*q[2]+t*root_z
        shape_t=t*(2-t)
        middle_z=(1-shape_t)*top_centre_z+shape_t*.30
        low,high=envelope(middle_z);cx=(low+high)/2
        standoff=.02+.015*shape_t
        rx=cx-low+standoff-amplitude*wave(.5)
        normal_radius=chord_radius(width*(1+.15*shape_t),amplitude)
        # The cloth follows the back rather than inflating a body-wide tent.
        radius=normal_radius
        cy=(1-t)*centre_y+t*root_centre_y
        base=np.array([cx-rx*math.cos(theta),cy+radius*math.sin(theta),z])
        join=min(t/.12,1.);join=join*join*(3-2*join)
        # Follow the near shoulder's posterior attachment toward the root,
        # keeping the broad cloth behind the forward channelling arm.
        edge_x=cx-rx*math.cos(angle/2)
        near_pull=(1-t)*max(0.,edge_x-caps['near'][0])
        base[0]-=near_pull*max(0.,math.sin(theta))
        base=(1-join)*np.array([top_base[0],top_base[1],z])+join*base
        return (base+amplitude*wave(u)*direction)@wrap.T

    # Refine the actual tear footprints, keeping their fixed angular centres.
    extra_u=[];extra_t=[]
    for degrees,height,diameter in HOLES:
        u=.5+math.radians(degrees)/angle;q=attachment(u);root_z=.30-.03*abs(2*u-1)
        t=(q[2]-height)/(q[2]-root_z)
        dense=np.asarray([surface(t,x) for x in samples])
        developed_dense=np.r_[0,np.cumsum(np.linalg.norm(np.diff(dense,axis=0),axis=1))]
        at=float(np.interp(u,samples,developed_dense));minor=diameter/(2*math.sqrt(2));major=diameter/math.sqrt(2)
        extra_u.extend(np.interp(at+np.linspace(-1.2*minor,1.2*minor,25),developed_dense,samples))
        extra_t.extend((q[2]-(height+np.linspace(-1.2*major,1.2*major,33)))/(q[2]-root_z))
    us=np.unique(np.round(np.r_[us,extra_u],MESH_DEFAULTS['parameter_digits']))
    top=np.asarray([attachment(u)@wrap.T for u in us]);top_z=float(top[:,2].max())
    heights=[h+sign*depth*1.5 for shapes in NOTCHES.values() for h,depth in shapes for sign in (-1,0,1)]
    heights+=[h+sign*diameter/math.sqrt(2) for degrees,h,diameter in HOLES for sign in (-1,0,1)]
    adaptive=[(top_z-h)/(top_z-.27) for h in heights if .30<h<top_z]
    slit_gaps=[(boundaries[i][1],boundaries[i+1][0]) for i in range(8)]
    slit_apices=[1-.03/(attachment((a+b)/2)[2]-(.30-.03*abs(a+b-1))) for a,b in slit_gaps]
    adaptive.extend(slit_apices)
    ts=np.unique(np.r_[np.linspace(0,1,MESH_DEFAULTS['solid_rows']),adaptive,extra_t]);nr,nc=len(ts),len(us)
    vertices=[surface(t,u).tolist() for t in ts for u in us];faces=[];removed=[]
    grid=np.asarray(vertices).reshape(nr,nc,3)
    developed=np.column_stack([np.zeros(nr),np.cumsum(np.linalg.norm(np.diff(grid,axis=1),axis=2),axis=1)])
    tear_centres=[]
    for degrees,height,diameter in HOLES:
        u=.5+math.radians(degrees)/angle;q=attachment(u);root_z=.30-.03*abs(2*u-1)
        t=(q[2]-height)/(q[2]-root_z)
        along=float(np.interp(u,us,[np.interp(t,ts,developed[:,c]) for c in range(nc)]))
        tear_centres.append({'u':u,'t':t,'point':surface(t,u).tolist(),'developed':along,
                             'semiaxes':[diameter/(2*math.sqrt(2)),diameter/math.sqrt(2)],
                             'row_centres':[float(np.interp(u,us,row)) for row in developed]})
    for row in range(nr-1):
        for col in range(nc-1):
            point=grid[row:row+2,col:col+2].mean(axis=(0,1));along=float(developed[row:row+2,col:col+2].mean())
            hole=False
            for tear,axis in zip(tear_centres,MESH_DEFAULTS['tear_axis_degrees']):
                dx=along-(tear['row_centres'][row]+tear['row_centres'][row+1])/2;dz=point[2]-tear['point'][2];a=math.radians(axis)
                short=dx*math.cos(a)-dz*math.sin(a);long=dx*math.sin(a)+dz*math.cos(a)
                hole|=(short/tear['semiaxes'][0])**2+(long/tear['semiaxes'][1])**2<1
            notch=False
            for side,shapes in NOTCHES.items():
                edge_distance=along if side=='far' else float(developed[row:row+2,-1].mean())-along
                for height,depth in shapes:
                    notch|=edge_distance/depth+abs(point[2]-height)/(depth*1.5)<1
            a=row*nc+col
            slit=False
            row_t=float((ts[row]+ts[row+1])/2);column_u=float((us[col]+us[col+1])/2)
            for (left,right),apex in zip(slit_gaps,slit_apices):
                opening=np.clip((row_t-apex)/(1-apex),0.,1.)
                slit|=abs(column_u-(left+right)/2)<(right-left)*opening/2
            if hole or notch or slit:removed.append([row,col]);continue
            faces.append([a,a+1,a+nc+1,a+nc])
    strips=[]
    for index,((left,right),original_length,physical_width) in enumerate(zip(boundaries,STRIP_LENGTHS,physical_widths)):
        columns=np.flatnonzero((us>=left-1e-12)&(us<=right+1e-12)).tolist()
        previous=[(nr-1)*nc+c for c in columns];roots=previous.copy()
        start_distance=float(np.interp(left,samples,distance));end_distance=start_distance+physical_width
        tip_distance=(start_distance+end_distance)/2+(1 if index%2==0 else -1)*.3*physical_width
        tip_u=float(np.interp(tip_distance,distance,samples))
        root_z=float(surface(1,tip_u)[2]);requested_tip=root_z-1.5*original_length
        tip_z=.10 if index==8 else max(.06,requested_tip)
        # A ribbon continues the same surface at the root, then relaxes into
        # its vertical tangent plane. No circular cross-section is constructed.
        ribbon_rows=[previous.copy()]
        root_points=np.asarray([vertices[i] for i in roots]);tip=surface(1,tip_u);tip[2]=tip_z
        tangent=surface(1,min(1.,tip_u+1e-4))-surface(1,max(0.,tip_u-1e-4))
        tangent[2]=0.;tangent/=np.linalg.norm(tangent)
        root_centre=surface(1,tip_u)
        for v in np.linspace(0,1,MESH_DEFAULTS['strip_rows'])[1:]:
            current=[]
            offsets=[0.] if v==1 else [float((q-root_centre)@tangent) for q in root_points]
            for k,offset in enumerate(offsets):
                if v==1:point=tip.copy()
                else:
                    initial=root_points[k]
                    # Smoothly remove transverse curvature without a root seam.
                    fade=min(v/.45,1.);fade=fade*fade*(3-2*fade)
                    planar=root_centre+offset*tangent;planar[2]=initial[2]
                    root_at=(1-fade)*initial+fade*planar
                    point=(1-v)*root_at+v*tip
                current.append(len(vertices));vertices.append(point.tolist())
            if len(current)==1:
                for a,b in zip(previous,previous[1:]):faces.append([a,b,current[0]])
            else:
                for c in range(len(current)-1):faces.append([previous[c],previous[c+1],current[c+1],current[c]])
            previous=current;ribbon_rows.append(current.copy())
        strips.append({'root_indices':roots,'tip_index':previous[0],'left_u':left,'right_u':right,
            'tip_u':tip_u,'target_width_over_H':float(physical_width),'requested_length_over_H':1.5*original_length,
            'target_length_over_H':root_z-tip_z,'requested_tip_over_H':requested_tip,'tip_over_H':tip_z,
            'ribbon_rows':ribbon_rows,'floor_clamped':index!=8 and requested_tip<.06,'near_tip_override':index==8})
    used=sorted({i for face in faces for i in face});mapping={v:i for i,v in enumerate(used)}
    faces=[[mapping[i] for i in face] for face in faces]
    for strip in strips:
        strip['root_indices']=[mapping[i] for i in strip['root_indices']];strip['tip_index']=mapping[strip['tip_index']]
        strip['ribbon_rows']=[[mapping[i] for i in row] for row in strip['ribbon_rows']]
    layout={'solid_shape':[nr,nc],'shoulder_indices':[mapping[c] for c in range(nc) if c in mapping],
        'root_indices':[mapping[(nr-1)*nc+c] for c in range(nc) if (nr-1)*nc+c in mapping],
        'root_us':[float(us[c]) for c in range(nc) if (nr-1)*nc+c in mapping],'strips':strips,
        'solid_grid_indices':[[mapping.get(r*nc+c,-1) for c in range(nc)] for r in range(nr)],
        'us':us.tolist(),'ts':ts.tolist(),'slit_gaps':[list(gap) for gap in slit_gaps],'slit_apices':slit_apices,'root_wrap_degrees':200.,'root_arc_over_H':float(distance[-1]),
        'wrap_frame':wrap.tolist(),'root_shear':float(shear),'strip_width_scale':float(width_scale),'physical_strip_widths_over_H':physical_widths.tolist(),
        'fold_phase_radians':math.pi/2,'notch_half_height_over_depth':1.5,
        'shoulder_us':[float(us[c]) for c in range(nc) if c in mapping],
        'attachment_over_H':[top[c].tolist() for c in range(nc) if c in mapping],
        'attachment_normals':[sample(float(us[c]))['radial'].tolist() for c in range(nc) if c in mapping],
        'attachment_sink_over_H':sink,'attachment_lap_definition':'world Z above native local support hem',
        'attachment_supports':[sample(float(us[c]))['support'] for c in range(nc) if c in mapping],'tear_centres':tear_centres,
        'fold_weight_interpolation':'cosine between the five valley centres; constant beyond first/last centre'}
    return dict(rule_fields(),surface={'vertices_over_H':[vertices[i] for i in used],'faces':faces,'layout':layout},removed_quads=removed)
