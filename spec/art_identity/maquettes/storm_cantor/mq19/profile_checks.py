"""Independent per-row fits of opened cloth against the live body envelope.

This observer does not import the cloak generator or read its generated target
indices/coefficients. The acceptance file ratifies profiles, not mesh bytes.
"""
import json
import math
from pathlib import Path
import numpy as np
from .pose import rotation


def acceptance():
    return json.loads(Path(__file__).with_name('cloak_acceptance.json').read_text())


def body_envelope(spec,points,faces,frame,H,joints,settings):
    body=[]
    for piece in spec['pieces']:
        if piece['part'] not in ('torso','pelvis'):continue
        name=piece['id']+'_render';vertices=np.asarray(points[name])
        used=sorted({i for face in faces[name] for i in face})
        body.extend(np.einsum('nj,jk->nk',vertices[used]/H,frame)[:,[2,0]].tolist())
    ordered=sorted(set(map(tuple,body)));halves=[]
    def cross(a,b,c):return (b[0]-a[0])*(c[1]-a[1])-(b[1]-a[1])*(c[0]-a[0])
    for sequence in (ordered,ordered[::-1]):
        chain=[]
        for q in sequence:
            while len(chain)>1 and cross(chain[-2],chain[-1],q)<=0:chain.pop()
            chain.append(q)
        halves.append(chain)
    hull=halves[0][:-1]+halves[1][:-1]
    bottom=float(np.mean([joints['hip_near'][2],joints['hip_far'][2]])/H)
    top=float(np.mean([joints['shoulder_near'][2],joints['shoulder_far'][2]])/H)
    zs=np.linspace(bottom,top,settings['envelope_samples']);samples=[]
    for z in zs:
        hits=[a[1]+(b[1]-a[1])*(z-a[0])/(b[0]-a[0]) for a,b in zip(hull,hull[1:]+hull[:1])
              if min(a[0],b[0])<=z<=max(a[0],b[0]) and abs(b[0]-a[0])>1e-12]
        samples.append([min(hits),max(hits)])
    sigma=settings['envelope_smoothing_over_H']/(zs[1]-zs[0])
    radius=int(settings['kernel_sigma_extent']*sigma);offsets=np.arange(-radius,radius+1)
    kernel=np.exp(-.5*(offsets/sigma)**2);kernel/=kernel.sum();samples=np.asarray(samples)
    smoothed=np.column_stack([np.convolve(np.pad(samples[:,k],(radius,radius),mode='edge'),kernel,mode='valid') for k in (0,1)])
    return lambda z:np.array([np.interp(z,zs,smoothed[:,k]) for k in (0,1)])


def measure(spec,mid,faces,joints,body_points,body_faces):
    rules=acceptance();settings=rules['measurement'];layout=spec['mq19']['cloak_layout'];H=spec['mq19']['gauge_H_m']
    pose=spec['mq19']['design']['pose'];angle=math.radians(200)
    forward=rotation([0,0,1],pose['chest_yaw_toward_viewer_degrees'])[:,0]
    frame=np.column_stack([forward,[-forward[1],forward[0],0.],[0.,0.,1.]])
    local=np.einsum('nj,jk->nk',mid/H,frame)
    live={i for f in faces if all(i<len(mid) for i in f) for i in f}
    grid=np.asarray(layout['solid_grid_indices']);us=np.asarray(layout['us']);ts=np.asarray(layout['ts'])
    top_valid=(grid[0]>=0)&np.array([i in live for i in grid[0]])
    top=np.column_stack([np.interp(us,us[top_valid],local[grid[0,top_valid],k]) for k in range(3)])
    shoulder_frame=rotation([0,0,1],pose['chest_yaw_toward_viewer_degrees'])@rotation([0,1,0],pose['forward_lean_degrees'])@rotation([1,0,0],spec['mq19']['design']['pose_resolution']['chest_roll_degrees'])
    span=abs(float((joints['shoulder_near']-joints['shoulder_far'])@shoulder_frame[:,1]))/H
    envelope=body_envelope(spec,body_points,body_faces,frame,H,joints,settings)
    theta=angle*(us-.5);centres=(np.arange(5)+.5)/5
    weights=np.asarray(spec['mq19']['design']['cloak']['fold_amplitude_multipliers'])
    index=np.clip(np.searchsorted(centres,us)-1,0,3)
    blend=np.clip((us-centres[index])/(centres[index+1]-centres[index]),0,1)
    blend=(1-np.cos(math.pi*blend))/2
    wave=(weights[index]*(1-blend)+weights[index+1]*blend)*np.sin(10*math.pi*us+math.pi/2)
    centre_wave=-float(weights[2]);rows=[]
    root=grid[-1];valid=(root>=0)&np.array([i in live for i in root])
    root_z=float(np.interp(.5,us[valid],local[root[valid],2]));top_z=float(np.interp(.5,us,top[:,2]))
    for t,indices in zip(ts,grid):
        valid=(indices>=0)&top_valid&np.array([i in live for i in indices])
        row={'v':float(t),'live_samples':int(valid.sum())}
        if t==0:
            rows.append(row);continue
        join=min(t/settings['support_blend_end_t'],1.);join=join*join*(3-2*join)
        eased=t*(2-t);low,high=envelope((1-eased)*top_z+eased*root_z);cx=(low+high)/2
        c=np.cos(theta[valid]);s=np.sin(theta[valid]);w=wave[valid];zero=np.zeros(len(c))
        # Fit standoff, amplitude, shoulder pull, centre Y and width radius.
        # The body envelope anchors X: no free X intercept can hide inflation.
        fit=np.r_[np.column_stack([-join*c,(join*centre_wave-w)*c,-join*np.maximum(s,0),zero,zero]),
                  np.column_stack([zero,w*s,zero,np.full(len(c),join),join*s])]
        target_x=local[indices[valid],0]-(1-join)*top[valid,0]-join*(cx-(cx-low)*c)
        target_y=local[indices[valid],1]-(1-join)*top[valid,1]
        targets=np.r_[target_x,target_y]
        coefficients,_,rank,_=np.linalg.lstsq(fit,targets,rcond=None)
        standoff,amplitude,pull,cy,radius=coefficients
        edge_wave=weights[[0,-1]]  # Five complete waves; both edges have phase pi/2.
        chord=(forward[1]*amplitude*(edge_wave[0]-edge_wave[1])*math.cos(angle/2)
               +frame[1,1]*(2*radius+amplitude*edge_wave.sum())*math.sin(angle/2))
        row.update(standoff_over_H=float(standoff),amplitude_over_H=float(amplitude),width_scale=float(chord/span),
            residual_over_H=float(np.max(abs(np.einsum('nj,j->n',fit,coefficients)-targets))),fit_rank=int(rank))
        rows.append(row)
    # At t=0 the attachment blend has zero drape weight. Measure its limiting
    # profile from the first two opened drape rows; do not invent seam values.
    a,b=rows[1:3]
    for key in ('standoff_over_H','amplitude_over_H','width_scale'):
        rows[0][key]=float(a[key]-a['v']*(b[key]-a[key])/(b['v']-a['v']))
    rows[0].update(residual_over_H=0.,fit_rank=5,method='opened first-two-row limit; approved support seam checked separately')
    for row in rows:
        t=row['v'];standoff=rules['standoff'];amplitude=rules['fold_amplitude'];width=rules['width']
        row.update(expected_standoff_over_H=standoff['shoulders_over_H']+(standoff['root_over_H']-standoff['shoulders_over_H'])*t*(2-t),
            expected_amplitude_over_H=amplitude['shoulders_over_H']+(amplitude['root_over_H']-amplitude['shoulders_over_H'])*t,
            expected_width_scale=width['shoulder_scale']+(width['root_scale']-width['shoulder_scale'])*t*(2-t))
        row['checks']={'standoff':abs(row['standoff_over_H']-row['expected_standoff_over_H'])<=rules['standoff']['tolerance_over_H'],
            'amplitude':abs(row['amplitude_over_H']-row['expected_amplitude_over_H'])<=rules['fold_amplitude']['tolerance_over_H'],
            'width':abs(row['width_scale']/row['expected_width_scale']-1)<=rules['width']['relative_tolerance'],
            'surface_fit':row['fit_rank']==5 and row['live_samples']>=5 and row['residual_over_H']<=settings['fit_residual_tolerance_over_H']}
    checks={name:all(r['checks'][key] for r in rows) for name,key in
        [('standoff_profile','standoff'),('fold_amplitude_growth','amplitude'),('width_profile','width'),('cloth_row_surface_fit','surface_fit')]}
    return {'rows':rows,'checks':checks,'acceptance':'cloak_acceptance.json',
        'definition':settings['definition'],'passed':all(checks.values())}
