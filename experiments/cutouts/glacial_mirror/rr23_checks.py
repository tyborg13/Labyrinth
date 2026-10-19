"""Owner-fix proof: exact ankle separation in every clip, fists and guard depth."""
import numpy as np
from PIL import Image

from rr18_case import CASE
from cutout_pipeline.cases import read_json, write_json
from humanoid_cutout.cpu_pose import CpuPose
from humanoid_cutout.gates import matrix
from humanoid_cutout.rigid_joint_gap import gap
from humanoid_cutout.walk_gates import MAX_RIGID_AIR_PX, EPSILON
from maquette_motion.features import source_pixels
from maquette_motion.pixels import render

# Diagnostic mask only: isolates the painting's blue ice from grey boulders.
PROOF_ICE_CHROMA_MARGIN = 24
PROOF_TRANSFORM_DECIMALS = 6


def ankle_report(layout, samples):
    parts = {}
    for part in layout['parts']:
        if not part['bone'].startswith(('shin_', 'foot_')):
            continue
        image = np.asarray(Image.open(CASE/part['file']).convert('RGBA'))
        y, x = np.nonzero(image[..., 3])
        parts[part['name']] = (part['bone'], np.column_stack((x+.5, y+.5)))
    rows = [r for r in samples['samples'] if r['view']==layout['facing'] and r['kind']=='presented']
    records, errors, cache = [], [], {}
    overlap = {}
    for side in ('near', 'far'):
        masks = {}
        for bone in ('shin_'+side, 'foot_'+side):
            masks[bone] = np.logical_or.reduce([source_pixels(CASE,p)[...,3]>0 for p in layout['parts'] if p['bone']==bone])
        overlap[side] = int((masks['shin_'+side] & masks['foot_'+side]).sum())
        if not overlap[side]:
            errors.append(f'{layout["facing"]}/{side}: ankle has no rest overlap')
    for row in rows:
        for side in ('near', 'far'):
            shin = [n for n,(b,_) in parts.items() if b=='shin_'+side]
            foot = [n for n,(b,_) in parts.items() if b=='foot_'+side]
            reference = matrix(row['parts'][shin[0]]['transform'])
            inverse = np.linalg.inv(reference)
            # Common world translation/rotation cannot affect joint separation.
            relative = {n:inverse@matrix(row['parts'][n]['transform']) for n in shin+foot}
            key = (side, tuple(np.round(np.concatenate([relative[n].ravel() for n in shin+foot]),PROOF_TRANSFORM_DECIMALS)))
            if key not in cache:
                posed = {n:parts[n][1]@relative[n][:2,:2].T+relative[n][:2,2] for n in shin+foot}
                cache[key] = min(gap(posed[a],relative[a][:2,:2],posed[b],relative[b][:2,:2]) for a in shin for b in foot)
            distance = cache[key]
            record = {'clip':row['clip'],'frame':row['frame'],'side':side,'air_px':distance}
            records.append(record)
            if distance > MAX_RIGID_AIR_PX + EPSILON:
                errors.append(f'{layout["facing"]}/{row["clip"]}/{row["frame"]}/{side}: ankle air {distance:.6f} px > 3')
    if not rows: errors.append('missing presented ankle frames')
    return {'ok':not errors,'errors':errors,'presented_frames':len(rows),'rest_overlap_pixels':overlap,
            'maximum_ankle_air_px':max((r['air_px'] for r in records),default=0.),
            'clip_maxima':{clip:max(r['air_px'] for r in records if r['clip']==clip) for clip in {r['clip'] for r in rows}},
            'worst':max(records,key=lambda r:r['air_px']) if records else None}


def arm_report(layout, samples):
    view = layout['facing']
    parts = {p['name']:p for p in layout['parts']}
    errors, fists = [], {}
    shoulders={side:layout['joints']['upper_'+side]['position'] for side in ('near','far')}
    shoulder_delta=shoulders['near'][1]-shoulders['far'][1]
    shoulder_expected=.15*abs(shoulders['near'][0]-shoulders['far'][0])
    # The bound 1024px maquette tolerance is converted through its actual registration.
    registration=read_json(CASE/f'{view}_baseline/registered/{view}_registration.json')
    shoulder_tolerance=10*registration['scale'][1]
    if view=='front' and (shoulder_delta<=0 or abs(shoulder_delta-shoulder_expected)>shoulder_tolerance):
        errors.append('front shoulders violate the maquette shoulder-line rule')
    raw = read_json(CASE/f'raw_cut/{view}.json')
    for side in ('near','far'):
        name='fist_'+side
        source=next(p for p in raw['parts'] if p['name']==name)
        image=Image.open(CASE/source['file']).convert('RGBA')
        bounds=image.getbbox()
        fists[side]={'width_px':bounds[2]-bounds[0],'height_px':bounds[3]-bounds[1],
                     'wrist_pivot':layout['joints']['hand_'+side]['position']}
    if view=='front':
        for name in ('fore_near','fist_near'):
            for body in ('torso','head'):
                if parts[name]['z_index']<=parts[body]['z_index']:
                    errors.append(name+' must draw above '+body)
    else:
        for name in ('fist_near','fist_far'):
            if parts[name]['z_index']>=parts['torso']['z_index']:
                errors.append(name+' must draw behind the rear torso')
    rows=[r for r in samples['samples'] if r['view']==view and r['clip']=='guard' and r['kind']=='presented']
    data=read_json(CASE/'compiled_motion.json')
    row=min(rows,key=lambda r:abs(r['phase']-data['clips']['guard']['contact']))
    model=CpuPose(CASE,layout)
    layers,_=model.layers(row)
    painted={p['name']:image for p,image,_ in layers}
    overlap={side:int(((painted['fist_'+side][...,3]>0)&(painted['torso'][...,3]>0)).sum()) for side in ('near','far')}
    ice_overlap=0
    if view=='front':
        torso=parts['torso']
        source=model.image(torso['file']).copy()
        rgb=source[...,:3].astype(int)
        source[~((rgb[...,1]-rgb[...,0]>=PROOF_ICE_CHROMA_MARGIN)&(rgb[...,2]-rgb[...,0]>=PROOF_ICE_CHROMA_MARGIN))]=0
        from humanoid_cutout.cpu_pose import sprite_transform
        ice=render(source,sprite_transform(layout,row,torso))
        ice_overlap=int(((ice[...,3]>0)&(painted['fist_near'][...,3]>0)).sum())
        if not ice_overlap:errors.append('front guard near fist does not cross the painted ice mirror')
    for side in ('near','far'):
        parent='fore_'+side;terminal='fist_'+side
        x,y=np.floor(layout['joints']['hand_'+side]['position']).astype(int)
        arm=np.logical_or.reduce([source_pixels(CASE,p)[...,3]>0 for p in layout['parts'] if p['logical_part']==parent])
        fist=np.logical_or.reduce([source_pixels(CASE,p)[...,3]>0 for p in layout['parts'] if p['logical_part']==terminal])
        if not (arm[y,x] and fist[y,x]):errors.append(terminal+' pivot is outside wrist overlap')
    return {'ok':not errors,'errors':errors,'painted_fists':fists,
            'shoulders':{'positions':shoulders,'front_height_delta_px':shoulder_delta,'front_expected_delta_px':shoulder_expected,'tolerance_px':shoulder_tolerance},
            'guard_contact_frame':row['frame'],
            'guard_contact_phase':row['phase'],'fist_torso_overlap_pixels':overlap,'near_fist_ice_overlap_pixels':ice_overlap,
            'draw_order':{name:parts[name]['z_index'] for name in ('head','torso','fore_near','fist_near','fist_far')}}


def run():
    samples=read_json(CASE/'proof/samples.json')
    reports={}
    for view in ('front','rear'):
        layout=read_json(CASE/f'layouts/{view}.json')
        reports[view]={'ankles':ankle_report(layout,samples),'arms':arm_report(layout,samples)}
        for kind,report in reports[view].items():
            print(f'RR23 {view.upper()} {kind.upper()}: {"PASS" if report["ok"] else "FAIL"} ({len(report["errors"])} errors)')
            for error in report['errors'][:10]:print(error)
        print('RR23 %s MAXIMUM ANKLE AIR: %.6f px' % (view.upper(),reports[view]['ankles']['maximum_ankle_air_px']))
    write_json(CASE/'proof/rr23_owner_fixes.json',reports)
    return int(any(not r['ok'] for view in reports.values() for r in view.values()))


if __name__=='__main__':raise SystemExit(run())
