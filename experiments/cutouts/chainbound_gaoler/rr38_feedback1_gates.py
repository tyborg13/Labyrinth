"""Measured feedback-1 motion, floor contact, and complete clamp receipts."""
import argparse
from pathlib import Path
import numpy as np
from rr38_case import CASE
from cutout_pipeline.cases import read_json, write_json, digest
from humanoid_cutout.gates import matrix, evaluate
from humanoid_cutout.bone_contracts import fk_world

MEASUREMENT_EPSILON = .0001
PRESENTATION_ROTATION_STEP_DEG = 1.5  # Binding presentation grid.


def values_at(data, view, clip, phase):
    values, modes = {}, {}
    for track in data['view_tracks'][view][clip]:
        values.setdefault(track['bone'], {})[track['channel']] = evaluate(track['keys'], phase)
        modes[track['bone']] = track['forward_mode']
    return values, modes


def report(case, samples):
    data=read_json(case/'compiled_motion.json');errors=[];views={};clamps=[];angle_clamps=[]
    for view in data['view_tracks']:
        layout=read_json(case/f'layouts/{view}.json');joints=layout['joints']
        authored=[r for r in samples['samples'] if r['view']==view and r['kind']=='authored']
        end=next(r for r in authored if r['clip']=='death' and r['phase']==1)
        bends={};feet={}
        for side in ('near','far'):
            a,b,c=[np.asarray(end['bones'][n+'_'+side]['global'][4:]) for n in ('thigh','shin','foot')]
            u,v=b-a,c-b;cross=np.linalg.det(np.stack((u,v)))
            bends[side]=float(np.degrees(np.arctan2(abs(cross),u@v)))
            ray,elbow=c-a,b-a;actual_side=np.sign(np.linalg.det(np.stack((ray,elbow))))
            expected=layout['clip_knee_bend_side']['death'][side]
            if actual_side!=expected:errors.append(view+'/'+side+': death knee faces away')
            feet[side]=dict(drift_px=float(np.linalg.norm(c-joints['foot_'+side]['position'])),world_angle_deg=float(np.degrees(np.arctan2(end['bones']['foot_'+side]['global'][1],end['bones']['foot_'+side]['global'][0]))))
            if feet[side]['drift_px']>MEASUREMENT_EPSILON or abs(feet[side]['world_angle_deg'])>MEASUREMENT_EPSILON:errors.append(view+'/'+side+': death foot moved')
        hip=float(end['bones']['pelvis']['global'][5]-joints['pelvis']['position'][1])
        target=-evaluate(next(t['keys'] for t in data['view_tracks'][view]['death'] if t['source']=='pelvis.lift_px'),1)
        if abs(hip-target)>MEASUREMENT_EPSILON:errors.append(view+': pelvis sink differs from director target')
        for row in [r for r in authored if r['clip']=='death']:
            wanted=-evaluate(next(t['keys'] for t in data['view_tracks'][view]['death'] if t['source']=='pelvis.lift_px'),row['phase'])
            if abs(row['bones']['pelvis']['global'][5]-joints['pelvis']['position'][1]-wanted)>MEASUREMENT_EPSILON:errors.append(view+': incomplete screen sink at '+str(row['phase']))
            for side in ('near','far'):
                a,b,c=[np.asarray(row['bones'][n+'_'+side]['global'][4:]) for n in ('thigh','shin','foot')]
                rest=[np.asarray(joints[n+'_'+side]['position']) for n in ('thigh','shin','foot')]
                if not np.allclose([np.linalg.norm(b-a),np.linalg.norm(c-b)],[np.linalg.norm(rest[1]-rest[0]),np.linalg.norm(rest[2]-rest[1])],atol=MEASUREMENT_EPSILON,rtol=0):errors.append(view+'/'+side+': death leg stretched')
                if np.linalg.norm(c-rest[2])>MEASUREMENT_EPSILON:errors.append(view+'/'+side+': death support moved')
        drop=data['view_held_drops'][view]['death']['chain'];release=next(r for r in authored if r['clip']=='death' and abs(r['phase']-drop['start'])<1e-10)
        before=matrix(release['bones']['chain']['global']);local=np.asarray(layout['held_items']['chain']['floor_end'])-joints['chain']['position']
        contact=before@np.append(local,1);floor=layout['held_items']['chain']['floor_line_y'];distance=max(0.,floor-contact[1]);drop_errors=[]
        for row in [r for r in authored if r['clip']=='death' and r['phase']>=drop['start']]:
            phase=row['phase'];transform=matrix(row['bones']['chain']['global'])
            if phase<=drop['land']:
                u=(phase-drop['start'])/(drop['land']-drop['start']);expected=before[:2,2]+[0,distance*u*u]
                if not np.allclose(transform[:2,2],expected,atol=MEASUREMENT_EPSILON,rtol=0) or not np.allclose(transform[:2,:2],before[:2,:2],atol=MEASUREMENT_EPSILON,rtol=0):drop_errors.append('fall '+str(phase))
            else:
                actual=transform@np.append(local,1)
                if not np.allclose(actual[:2],[contact[0],floor],atol=MEASUREMENT_EPSILON,rtol=0):drop_errors.append('floor pivot '+str(phase))
        errors += [view+': chain '+e for e in drop_errors]
        budgets={}
        for side in ('near','far'):
            a,b,c=[np.asarray(joints[n+'_'+side]['position']) for n in ('upper','fore','hand')]
            lengths=[float(np.linalg.norm(b-a)),float(np.linalg.norm(c-b))]
            budgets[side]={'segment_lengths_px':lengths,'minimum_reach_px':abs(lengths[0]-lengths[1]),'maximum_reach_px':sum(lengths)}
        for row in [r for r in samples['samples'] if r['view']==view and r['clip'] in ('press','death')]:
            values,modes=values_at(data,view,row['clip'],row['phase']);forward=np.asarray(data['projection'][view]['forward']);fk=fk_world(layout,values,modes,forward,samples['step_distance_px']/samples['screen_pixel_scale'],clip=row['clip'])
            for side in ('near','far'):
                hand='hand_'+side
                if not any(c in values.get(hand,{}) for c in ('lift_px','forward_px','inward_px')):continue
                desired=fk[hand][:2,2];actual=np.asarray(row['bones'][hand]['global'][4:]);delta=float(np.linalg.norm(desired-actual))
                requested=float(np.linalg.norm(desired-fk['upper_'+side][:2,2]));budget=budgets[side]
                limited=float(np.clip(requested,budget['minimum_reach_px'],budget['maximum_reach_px']))
                if abs(requested-limited)>MEASUREMENT_EPSILON:
                    clamps.append(dict(view=view,clip=row['clip'],phase=row['phase'],kind=row['kind'],frame=row['frame'],bone=hand,requested_channels=values[hand],requested_reach_px=requested,limited_reach_px=limited,requested_world_px=desired.tolist(),actual_world_px=actual.tolist(),clamp_distance_px=abs(requested-limited),presented_target_difference_px=delta,reason='measured two-segment reach annulus'))
            if row['kind']=='presented' and row['clip']=='press':
                requested=values['torso']['lean_deg'];limit=layout['presentation_angle_limits_deg']['press']['torso'];stepped=np.floor(limit/PRESENTATION_ROTATION_STEP_DEG)*PRESENTATION_ROTATION_STEP_DEG
                if abs(requested)>stepped:
                    local=row['bones']['torso']['local'];actual=float(np.degrees(np.arctan2(local[1],local[0])))
                    angle_clamps.append(dict(view=view,clip=row['clip'],frame=row['frame'],phase=row['phase'],requested_deg=requested,presented_deg=actual,limit_deg=limit,reason='existing rotation grid within director limit'))
        views[view]=dict(pelvis_screen_drop_px=hip,death_knee_angles_deg=bends,planted_feet=feet,arm_budgets=budgets,chain_drop_distance_px=distance,unit_floor_line_y=floor,chain_drop_errors=drop_errors)
    return dict(ok=not errors,errors=errors,native_pixels=False,views=views,clamps=clamps,clamp_count=len(clamps),presentation_angle_clamps=angle_clamps,note='Reach clamps are measured for every authored and presented target. Native coverage and texture judgment remain independent gates.')


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--case',type=Path,default=CASE);parser.add_argument('--samples',type=Path,required=True);args=parser.parse_args()
    result=report(args.case,read_json(args.samples));result['full_samples_sha256']=digest(args.samples);write_json(args.case/'proof/feedback1_motion.json',result)
    for view,row in result['views'].items():print('RR38 FEEDBACK1 '+view.upper()+': hips=%.6f; knees=%s; chain drop=%.6f'%(row['pelvis_screen_drop_px'],row['death_knee_angles_deg'],row['chain_drop_distance_px']))
    print('RR38 FEEDBACK1 MOTION: %s (%d errors; %d measured clamps; no native claim)'%('PASS' if result['ok'] else 'FAIL',len(result['errors']),len(result['clamps'])))
    raise SystemExit(not result['ok'])
