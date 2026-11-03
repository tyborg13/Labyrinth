"""Recomputed mq-17 gates and tables, bound to native capture bytes."""
import csv
import io
import json
import math
from pathlib import Path

import numpy as np
from PIL import Image,ImageDraw

from spec.art_identity.maquettes.blender.backend import load_render
from spec.art_identity.maquettes.blender.capture_manifest import read_manifest
from spec.art_identity.maquettes.blender.contract import digest
from spec.art_identity.maquettes.blender.curate_delivery import write,sha
from spec.art_identity.maquettes.blender.pixel_coverage import part_coverage
from spec.art_identity.maquettes.raster import camera,project
from .recipe import FOLDER,PROJECT
from .volume_checks import valid_report,valid_shape_inventory,shape_checks,required_checks
# Native probe imports bpy, so keep its inventory as a literal here and test
# both ends against the retained opened-scene evidence.
VOLUME_MUTATIONS={'thin_armour','collapsed_cloth','sphere_below_shoulder',
                  'flattened_caps','shortened_armour','collapsed_shells'}

PROOF_DEFAULTS={'alpha_threshold':128,'joint_tolerance_px':.02,'shoulder_tolerance_px':10,
                'sheet_tile_px':1024,'sheet_caption_px':32,'sheet_background':[24,24,24,255],
                'sheet_height_px':1184,'sheet_sole_baseline_px':1100,
                'source_scale':4,'webp_method':6,'budget_bytes':6_000_000}
PROOF_TEXT_FILES=('per_part_coverage.csv','pose_table.md','proportion_table.md')
# Static rear occlusions are explicit rig-v2 delivery facts, not missing parts.
OCCLUSIONS={'front':{'thigh_far':'The draped tabard and pelvis occlude the far thigh; its full native solo is retained.'},'rear':{'bell':'Closed brass back plate occludes the hanging bell.',
    'tabard':'The pelvis and closed back plate hide the front panel.',
    'pelvis':'The rear waist cloth and closed back plate hide the pelvic plate.',
    'sash':'The torso/back plate and cloak cover the waist sash in this view.',
    'hand_near':'Near hand falls behind the torso/cloak after the true turn.'}}


def native_negative_contract(spec,native):
    expected={'flattened_caps':{'pauldron_'+s+'_has_rise' for s in ('near','far')},
        'collapsed_shells':{'pauldron_'+s+'_separated_shell' for s in ('near','far')},
        'shortened_armour':{'upper_plate_near_covers_joints','fore_plate_far_covers_joints'}}
    details=native.get('volume_mutation_details',{})
    if set(details)!=set(expected):return False
    for name,failures in expected.items():
        report=details[name];shapes=report.get('shape_measurements',{})
        results=report.get('observed_shape_results',{})
        if not valid_shape_inventory(shapes) or set(results)!=required_checks(spec):return False
        calculated=shape_checks(shapes)
        if any(results.get(k) is not v for k,v in calculated.items()) or any(results.get(k) is not False for k in failures):return False
    return True


def native_pose_contract(spec,native):
    """A summary boolean cannot replace required rows or director targets."""
    expected={}
    def row(number,name,key,angular=False):
        expected[name]=(number,0 if key is None else spec['pose'][key],1. if angular else .01)
    for side in ('near','far'):row(1,'knee_bend_'+side,'knee_bend_degrees',True)
    row(1,'hip_lean','hip_lean_degrees',True);row(1,'head_level','head_pitch_degrees',True)
    row(2,'ankle_transverse_span_over_shoulders','ankle_span_over_shoulders')
    row(3,'near_half_step_over_L','half_step_over_L')
    for name,key in [('fist_height_over_H','fist_height_over_H'),('fist_forward_over_L','fist_forward_over_L'),
                     ('fist_outward_over_L','fist_outward_over_L')]:row(4,name,key)
    row(5,'staff_vertical_degrees','staff_inclination_degrees',True)
    row(5,'staff_butt_over_H',None);row(5,'grip_axis_distance_over_L',None)
    row(6,'staff_top_over_H','staff_top_over_H')
    row(7,'fork_plane_normal_forward_degrees','fork_plane_normal_forward_degrees',True)
    for name in ('pennant_tie_below_fork_over_H','pennant_length_over_H','pennant_width_over_H'):row(8,name,name)
    row(9,'far_elbow_pole_outward_degrees','far_elbow_pole_outward_degrees',True)
    row(10,'near_upper_out_degrees','near_upper_out_degrees',True)
    row(11,'near_elbow_bend_degrees','near_elbow_bend_degrees',True)
    for finger in range(4):
        for k in range(3):row(12,'near_finger_'+str(finger)+'_knuckle_'+str(k),'near_finger_knuckle_degrees',True)
    row(12,'near_wrist_ahead_of_thigh_over_L','near_wrist_ahead_of_thigh_over_L')
    row('extra','bell_mouth_over_H','bell_mouth_over_H')
    rows=native.get('pose_values',[])
    if len(rows)!=len(expected) or {r.get('name') for r in rows}!=set(expected):return False
    for value in rows:
        number,target,tolerance=expected[value['name']]
        measured=value.get('measured')
        if (not isinstance(measured,(int,float)) or isinstance(measured,bool) or not math.isfinite(measured) or
            value.get('requirement')!=number or value.get('target')!=target or value.get('tolerance')!=tolerance or
            value.get('passed') is not True or abs(measured-target)>tolerance):return False
    required={'pose_values_within_tolerance','both_feet_planted','level_shoulders','far_elbow_not_forward',
        'fork_tine_order_and_curves','pennant_outward','forearm_folds_forward','head_and_chest_forward',
        'opened_mesh_hash_matches_build','native_joint_endpoints','whole_native_features','geometry_report',
        'tabard_sigils_rear_occluded','native_mutations_rejected','native_geometry_restored','cloak_hem_at_near_knee','feedback1_volumes','feedback1_mutations_rejected'}
    mutants={'wrong_polygon_owner','stale_mesh_hash','staff_detached_from_fist','flattened_native_finger','rear_bell_exposed'}
    joints={b[key] for b in spec['armature']['bones'] for key in ('head','tail')}
    return (native.get('passed') is True and required<=set(native.get('checks',{})) and
        all(v is True for v in native['checks'].values()) and set(native.get('mutations',{}))==mutants and
        all(v is True for v in native['mutations'].values()) and set(native.get('observed_joints',{}))==joints and
        valid_report(spec,native.get('volumes',{})) and native_negative_contract(spec,native) and
        set(native.get('volume_mutations',{}))==VOLUME_MUTATIONS and
        all(v is True for v in native['volume_mutations'].values()))


def pose_gates(spec,recorded,native):
    near,far=(recorded['front']['shoulder_'+s] for s in ('near','far'))
    expected=spec['pose']['shoulder_rise_per_projected_span']*abs(near[0]-far[0])
    observed=near[1]-far[1]
    joints=native['observed_joints']
    level=abs(joints['shoulder_near'][2]-joints['shoulder_far'][2])
    errors=[float(np.linalg.norm(np.subtract(project(spec,point,view,1024)[:2],recorded[view][name])))
            for view in ('front','rear') for name,point in joints.items()]
    matrices={v:camera(spec,v)[0] for v in ('front','rear')}
    turn=matrices['rear'][:3,:3]@np.linalg.inv(matrices['front'][:3,:3])
    checks={'shoulder_rule':abs(observed-expected)<=PROOF_DEFAULTS['shoulder_tolerance_px'],
        'shoulders_level_3d':level<=1e-4,'native_joint_projection':max(errors)<=PROOF_DEFAULTS['joint_tolerance_px'],
        'proper_true_turn':bool(np.allclose(turn,np.diag([-1,-1,1])) and abs(np.linalg.det(turn)-1)<1e-8),
        'same_camera_angles_and_scale':all(spec['view_transforms']['front'][k]==spec['view_transforms']['rear'][k]
            for k in ('azimuth_deg','elevation_deg','ortho_scale'))}
    for view in ('front','rear'):
        a=recorded[view]['hand_far'][0];b=recorded[view]['pelvis'][0]
        checks[view+'_staff_side']=a<b if view=='front' else a>b
    return {'passed':all(checks.values()),'checks':checks,'shoulder_rise_px':observed,
        'target_shoulder_rise_px':expected,'shoulder_error_px':abs(observed-expected),
        'level_difference_m':level,'maximum_joint_projection_error_px':max(errors),
        'rear_relative_matrix':turn.tolist(),'rear_determinant':float(np.linalg.det(turn))}


def inspect(capture,spec=None,write_outputs=True):
    capture=Path(capture);spec=spec or json.loads((FOLDER/'measurements.json').read_text())
    manifest=read_manifest(capture,digest(spec),('full',))
    native=json.loads((capture/'native_probe.json').read_text())
    build=json.loads((capture/'build_report.json').read_text())
    if native['spec_hash']!=digest(spec) or native['native_mesh_hash']!=build['combined_mesh_hash']:
        raise ValueError('Stale opened native observations')
    recorded=json.loads((capture/'joints_px.json').read_text());pose=pose_gates(spec,recorded,native)
    coverage={};failures=[];heights={}
    table=io.StringIO(newline='');writer=csv.writer(table,lineterminator='\n')
    writer.writerow(['view','part','solo_pixels','visible_pixels','pure_owner_pixels','clipped','explicit_occlusion'])
    for view in ('front','rear'):
        raster=load_render(spec,capture,view)
        rgba=np.asarray(Image.open(capture/(view+'_parts.png')).convert('RGBA'))
        values=part_coverage(spec,raster,rgba);coverage[view]=values
        for name,row in values.items():
            row['explicit_occlusion']=OCCLUSIONS[view].get(name) if row['pure_owner_pixels']==0 else None
            if row['pure_owner_pixels']==0:
                solo=raster.masks[name]
                row['occluding_owner_pixels']={owner:int(((raster.owners==index)&solo).sum())
                    for index,owner in enumerate(raster.names) if owner!=name and ((raster.owners==index)&solo).any()}
            if not row['solo_pixels'] or row['clipped_at_canvas'] or (not row['pure_owner_pixels'] and not row['explicit_occlusion']):
                failures.append(view+':'+name)
            writer.writerow([view,name,row['solo_pixels'],row['visible_pixels'],row['pure_owner_pixels'],
                             row['clipped_at_canvas'],row['explicit_occlusion'] or ''])
        body=np.logical_or.reduce([raster.masks[n] for n in spec['labels'] if n!='staff'])
        ys=np.argwhere(body)[:,0];heights[view]=int(ys.max()-ys.min()+1)
    checks={'native_pose_and_mutations':native_pose_contract(spec,native),'shoulder_and_turn':pose['passed'],
        'complete_label_coverage':not failures,
        'source_drawn_height':abs(heights['front']-spec['mq17']['source_drawn_height_px']*4)<=2}
    result={'passed':all(checks.values()),'checks':checks,'spec_hash':digest(spec),
        'native_mesh_hash':build['combined_mesh_hash'],'native_probe_sha256':sha(capture/'native_probe.json'),
        'capture_manifest_sha256':sha(capture/'capture_manifest.json'),'pose':pose,
        'per_part_coverage':coverage,'unexplained_parts':failures,'body_height_px':heights,
        'proportions':native['proportions'],'pose_values':native['pose_values'],
        'feedback1_volumes':native['volumes'],
        'fit_gate':'Not applicable: the director changed the pose.',
        'proof_text_sha256':{name:sha(capture/name) for name in PROOF_TEXT_FILES if (capture/name).exists()}}
    if not write_outputs:return result
    (capture/'per_part_coverage.csv').write_text(table.getvalue())
    lines=['| Requirement | Value | Target | Native measurement | Tolerance | Result |',
           '|---|---|---:|---:|---:|---|']
    for row in native['pose_values']:
        lines.append(f"| {row['requirement']} | {row['name']} | {row['target']:.9f} | {row['measured']:.9f} | {row['tolerance']} | {'PASS' if row['passed'] else 'FAIL'} |")
    lines+=['','Distances are normalized to measured native L/H; angular rows are degrees. Native ring means, opened vertex bounds and armature endpoints supply measurements. Rows 1–12 follow the brief; the bell is an additional dimensional check.',
        '',f"Far shoulder rise {pose['shoulder_rise_px']:.6f}px; required {pose['target_shoulder_rise_px']:.6f}px; error {pose['shoulder_error_px']:.6f}px (±10px). 3D shoulder Z difference {pose['level_difference_m']:.9f}m.",
        '',f"Rear relative transform {pose['rear_relative_matrix']}; determinant {pose['rear_determinant']:.9f}. Native soles: {native['soles_m']}. Both staff side checks: {pose['checks']['front_staff_side']}/{pose['checks']['rear_staff_side']}.",
        '',f"Cloak lowest ragged tip Z: {native['cloak_hem']['lowest_hem_z_m']:.9f}m; native near knee Z: {native['cloak_hem']['near_knee_z_m']:.9f}m; error {native['cloak_hem']['error_over_L']:.9f} L."]
    (capture/'pose_table.md').write_text('\n'.join(lines)+'\n')
    lines=['| Proportion | Current art / H | Native / H |','|---|---:|---:|']
    for name,row in native['proportions'].items():lines.append(f"| {name} | {row['source']:.9f} | {row['native']:.9f} |")
    lines+=['','| Director volume dimension | Director / H | Opened native / H | Result |','|---|---:|---:|---|']
    for row in native['volumes']['rows']:
        lines.append(f"| {row['name']} | {'≥ ' if row['minimum'] else ''}{row['target_over_H']:.9f} | {row['measured_over_H']:.9f} | {'PASS' if row['passed'] else 'FAIL'} |")
    lines+=['',native['volumes']['definition'],
        '',f"Native tabard fold crests: {native['volumes']['tabard_crests']}; cloak tails: {native['volumes']['cloak_tails']}."]
    lines+=['','| Proof shape measurement | Opened native value |','|---|---:|']
    for kind,items in native['volumes']['shape_measurements'].items():
        for name,values in items.items():
            for metric,value in values.items():lines.append(f'| {name}: {metric} | {value:.9f} |')
    lines+=['','Source calipers are in source_measurements.json. H excludes the staff and includes the taller helm tine. L is the straight hip-joint-to-sole distance; shoulder width is transverse in body space. Source leg caliper is the old nearer hip/sole; the old pose is asymmetric. Proportions are informational, without a fit gate.',
        '',f"Source drawn height {spec['mq17']['source_drawn_height_px']}px; front body height at 1024 {heights['front']}px (target ×4). Rear body height {heights['rear']}px."]
    (capture/'proportion_table.md').write_text('\n'.join(lines)+'\n')
    result['proof_text_sha256']={name:sha(capture/name) for name in PROOF_TEXT_FILES}
    write(capture/'mq17_acceptance.json',result)
    print('MQ17_ACCEPTANCE: '+('PASS' if result['passed'] else 'FAIL')+'; unexplained_parts='+str(failures),flush=True)
    return result


def validate_acceptance(capture,spec=None):
    capture=Path(capture);before=json.loads((capture/'mq17_acceptance.json').read_text())
    report=inspect(capture,spec,write_outputs=False)
    if before!=report or not report['passed']:
        raise ValueError('Missing, failed or stale mq17 acceptance')
    return report


def review_sheet(capture):
    capture=Path(capture);size=PROOF_DEFAULTS['sheet_tile_px'];caption=PROOF_DEFAULTS['sheet_caption_px']
    refs=[('Current Storm Cantor art',PROJECT/'assets/units/storm_cantor.png',4),
        ('Storm Cantor front clay',capture/'front_clay.png',1),
        ('Storm Cantor rear: true 180 turn',capture/'rear_clay.png',1),
        ('Chainbound Gaoler mq-15 scale reference',FOLDER.parent/'chainbound_gaoler/delivery/front_clay.png',1)]
    canvas=Image.new('RGBA',(4*size,PROOF_DEFAULTS['sheet_height_px']),tuple(PROOF_DEFAULTS['sheet_background']))
    draw=ImageDraw.Draw(canvas);inputs=[]
    for k,(title,path,scale) in enumerate(refs):
        im=Image.open(path).convert('RGBA')
        if scale!=1:im=im.resize((im.width*scale,im.height*scale),Image.Resampling.NEAREST)
        alpha=np.asarray(im)[:,:,3]>=PROOF_DEFAULTS['alpha_threshold']
        sole_edge=int(np.argwhere(alpha)[:,0].max())+1
        y=PROOF_DEFAULTS['sheet_sole_baseline_px']-sole_edge
        if y<caption or y+im.height>canvas.height:raise ValueError('Proof sheet clips an input')
        canvas.alpha_composite(im,(k*size+(size-im.width)//2,y))
        draw.text((k*size+8,8),title,fill='white')
        # Capture-relative paths survive staging/clean regeneration.
        name=path.name if path.parent==capture else str(path.relative_to(PROJECT))
        inputs.append({'path':name,'capture_relative':path.parent==capture,'sha256':sha(path),
                       'display_scale':scale,'display_y_px':y,'sole_edge_px':sole_edge})
    canvas.save(capture/'contact_sheet.webp',lossless=True,exact=True,method=PROOF_DEFAULTS['webp_method'])
    if not np.array_equal(np.asarray(canvas),np.asarray(Image.open(capture/'contact_sheet.webp').convert('RGBA'))):
        raise ValueError('Review sheet encoding changed pixels')
    write(capture/'contact_sheet.json',{'inputs':inputs,'sheet_sha256':sha(capture/'contact_sheet.webp'),
          'registration':'Native at 1:1; 255px current art at exact 4x. Common sole baseline, translation only; no per-figure scale normalization.',
          'size':list(canvas.size)})
    print('MQ17_CONTACT_SHEET: PASS; '+str(capture/'contact_sheet.webp'),flush=True)
