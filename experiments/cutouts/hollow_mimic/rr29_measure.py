"""Independent pendulum and projected-depth gates; source px, zero-based frames."""
import math
import numpy as np
from PIL import Image
from rr29_build import CASE, BASE, read_json, write_json
from humanoid_cutout.gait import schedule
from humanoid_cutout.gates import matrix
from humanoid_cutout.cpu_pose import CpuPose

# Test non-collinearity at serialized-bone precision. The director's terminal
# ramp shortens the first/last arcs; no minimum visible curvature was authored.
PROOF = {'crop_zoom':4, 'crop_padding_px':8, 'arc_departure_min_px':0.0001,
         'matrix_tolerance':0.0001}


def wave(gait, side, phase):
    if phase <= 0 or phase >= 1: return 0.
    keys = [(0.,0.)]
    swings = schedule(gait)
    for i, swing in enumerate(swings):
        amplitude = .5 if i in (0,len(swings)-1) else 1.
        keys.append((swing['end'], amplitude*(-1 if side == swing['side'] else 1) if i < len(swings)-1 else 0.))
    for (a,x),(b,y) in zip(keys,keys[1:]):
        if a <= phase <= b:
            u=(phase-a)/(b-a)
            return x+(y-x)*u*u*(3-2*u)
    raise ValueError(phase)


def diameter(points):
    points=np.asarray(points)
    return float(np.linalg.norm(points[:,None]-points[None,:],axis=2).max())


def envelope_at(gait, phase):
    envelope = gait['arm_swing'].get('envelope')
    if envelope is None: return 1.
    ramp = envelope['ramp_fraction']
    smooth = lambda value: (lambda u: u*u*(3-2*u))(min(1.,max(0.,value/ramp)))
    return smooth(phase)*smooth(1-phase)


def arm_report(samples, before):
    data=read_json(CASE/'compiled_motion.json');clip=data['clips']['move'];gait=clip['gait']
    result,errors={},[]
    for view in ('front','rear'):
        layout=read_json(CASE/f'layouts/{view}.json');old=read_json(BASE/f'layouts/{view}.json')
        forward=np.array(data['projection'][view]['forward'])
        rows=[r for r in samples['samples'] if r['view']==view and r['clip']=='move' and r['kind']=='presented']
        baseline=[r for r in before['samples'] if r['view']==view and r['clip']=='move' and r['kind']=='presented']
        result[view]={}
        for side in ('near','far'):
            names=[n+'_'+side for n in ('upper','fore','hand')]
            a,b,c=[np.array(layout['joints'][n]['position']) for n in names]
            settings=gait['arm_swing'][side]
            # Remove the moving shoulder, retaining the actual screen-space
            # orientation. This measures the arm rather than root tile travel.
            path=[np.array(r['bones'][names[2]]['global'][4:])-r['bones'][names[0]]['global'][4:] for r in rows]
            old_path=[np.array(r['bones'][names[2]]['global'][4:])-r['bones'][names[0]]['global'][4:] for r in baseline]
            travel,slide=diameter(path),diameter(old_path)
            if travel < 2.5*slide: errors.append(f'{view}/{side}: travel below 2.5x rr20')
            residuals=[]
            for step in [s for s in schedule(gait) if s['side']==side]:
                segment=np.array([point for r,point in zip(rows,path) if step['start']<=r['phase']<=step['end']])
                if len(segment)<3:continue
                # A slide is collinear. Distance to the best-fit line measures
                # curvature without assuming a circular wrist about the elbow.
                centred=segment-segment.mean(axis=0)
                _,_,axes=np.linalg.svd(centred)
                residuals.append(float(np.max(np.abs(centred@axes[-1]))))
            if not residuals or min(residuals)<PROOF['arc_departure_min_px']:
                errors.append(f'{view}/{side}: step path is not an arc')
            # Independently derive the exact authored FK from director angles.
            for row in samples['samples']:
                if row['view']!=view or row['clip']!='move' or row['kind']!='authored':continue
                phase=row['phase'];envelope=envelope_at(gait,phase)
                w=wave(gait,side,phase)*envelope
                lag=wave(gait,side,phase-settings['forearm_lag_s']*envelope/clip['seconds'])*envelope
                base=matrix(row['bones']['torso']['global']);base_angle=math.atan2(base[1,0],base[0,0])
                cross=lambda a,b: a[0]*b[1]-a[1]*b[0]
                direction=np.sign(cross(c-a,forward));bend_side=np.sign(cross(b-a,c-b))
                ua=base_angle+math.radians(direction*settings['upper_deg']*w)
                fa=base_angle+math.radians(direction*settings['upper_deg']*lag + bend_side*abs(lag)*settings['forearm_bend_deg']['forward' if lag>=0 else 'back'])
                rot=lambda angle: np.array([[math.cos(angle),-math.sin(angle)],[math.sin(angle),math.cos(angle)]])
                shoulder=np.array(row['bones'][names[0]]['global'][4:]);elbow=shoulder+rot(ua)@(b-a);hand=elbow+rot(fa)@(c-b)
                for name,angle,position in zip(names,(ua,fa,fa),(shoulder,elbow,hand)):
                    actual=matrix(row['bones'][name]['global'])
                    if not np.allclose(actual[:2,:2],rot(angle),atol=PROOF['matrix_tolerance'],rtol=0) or not np.allclose(actual[:2,2],position,atol=PROOF['matrix_tolerance'],rtol=0):
                        errors.append(f'{view}/{side}/{phase}: pendulum FK differs from director model');break
            endpoints=[]
            for row in (rows[0],rows[-1]):
                root=np.array(row['bones']['root']['global'][4:])-layout['joints']['root']['position']
                delta=max(float(np.max(np.abs(matrix(row['bones'][name]['global'])[:2,:2]-np.eye(2)))) for name in names)
                delta=max(delta,max(float(np.max(np.abs(np.array(row['bones'][name]['global'][4:])-root-layout['joints'][name]['position']))) for name in names))
                endpoints.append({'frame':row['frame'],'phase':row['phase'],'maximum_rest_error':delta})
                if delta>PROOF['matrix_tolerance']:errors.append(f'{view}/{side}/{row["frame"]}: endpoint differs from root-translated rest')
            result[view][side]={'peak_to_peak_px':travel,'rr20_slide_px':slide,'ratio':travel/slide,'endpoints':endpoints,
                'step_arc_departure_px':residuals, 'screen_pixel_scale':samples['screen_pixel_scale']}
    return {'ok':not errors,'errors':sorted(set(errors)),'views':result,'units':'source px; screen px = source px * screen_pixel_scale'}


def box(layout,pose,part):
    transform=matrix(pose['bones'][part['bone']]['global'])
    left,top,right,bottom=part['bbox'];bind=np.array(layout['joints'][part['bone']]['position'])
    points=np.array([[left,top],[right,top],[left,bottom],[right,bottom]])-bind
    points=points@transform[:2,:2].T+transform[:2,2]
    return np.r_[points.min(axis=0),points.max(axis=0)]


def camera_sides(layout,pose):
    if pose['view']!='front':return []
    parts={p['name']:p for p in layout['parts']};torso=box(layout,pose,parts['torso'])
    middle=pose['bones']['torso']['global'][4]
    rest_side=layout['joints']['hand_far']['position'][0]-layout['joints']['torso']['position'][0]
    result=[]
    for side in ('near','far'):
        hand='hand_'+side;b=box(layout,pose,parts[hand])
        overlap=all(b[i]<torso[i+2] and b[i+2]>torso[i] for i in (0,1))
        crossed=(pose['bones'][hand]['global'][4]-middle)*rest_side<=0
        if overlap and (side=='near' or crossed):result.append(side)
    return result


def depths(layout,pose):
    result={p['name']:p['z_index'] for p in layout['parts']}
    torso=result['torso']
    for side in camera_sides(layout,pose):
        for name in ('sleeve_'+side,'hand_'+side):result[name]=max(result[name],torso+1)
    return result


def draw_report(samples, *, crops=False):
    errors,findings=[],[]
    for view in ('front','rear'):
        layout=read_json(CASE/f'layouts/{view}.json');parts={p['name']:p for p in layout['parts']}
        model=CpuPose(CASE,layout) if crops else None
        for pose in samples['samples']:
            if pose['view']!=view or pose['kind']!='presented':continue
            expected=depths(layout,pose)
            for name,z in expected.items():
                if pose['parts'][name].get('z_index')!=z:errors.append(f'{view}/{pose["clip"]}/{pose["frame"]}/{name}: draw order')
            for side in camera_sides(layout,pose):
                names=['sleeve_'+side,'hand_'+side]
                behind=[n for n in names if parts[n]['z_index']<=parts['torso']['z_index']]
                row={'clip':pose['clip'],'frame':pose['frame'],'side':side,'before_behind':behind,
                     'after_above':all(pose['parts'][n]['z_index']>parts['torso']['z_index'] for n in names)}
                if crops and behind:
                    layers,_=model.layers(pose)
                    bounds=box(layout,pose,parts['torso']);origin=128
                    crop=[int(bounds[0])+origin-PROOF['crop_padding_px'],int(bounds[1])+origin-PROOF['crop_padding_px'],int(bounds[2])+origin+PROOF['crop_padding_px'],int(bounds[3])+origin+PROOF['crop_padding_px']]
                    for stage in ('before','after'):
                        image=Image.new('RGBA',(512,512))
                        for part,paint,_ in sorted(layers,key=lambda r:r[0]['z_index'] if stage=='before' else expected[r[0]['name']]):image.alpha_composite(Image.fromarray(paint))
                        image=image.crop(crop);image=image.resize((image.width*PROOF['crop_zoom'],image.height*PROOF['crop_zoom']),Image.Resampling.NEAREST)
                        path=CASE/f'proof/draw_order/{pose["clip"]}_{pose["frame"]:03d}_{side}_{stage}.png';path.parent.mkdir(parents=True,exist_ok=True);image.save(path)
                        row[stage+'_crop']=str(path.relative_to(CASE))
                findings.append(row)
    return {'ok':not errors,'errors':errors,'frames_checked':sum(r['kind']=='presented' for r in samples['samples']),
        'findings':findings,'crop_scope':'CPU diagnostic of mq11 paint, rr20 static depths vs corrected depths; not native capture'}
