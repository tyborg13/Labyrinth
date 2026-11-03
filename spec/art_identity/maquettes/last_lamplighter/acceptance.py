"""Recomputed mq-18 gates and tables, bound to native capture bytes."""
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
from .native_checks import valid_rows
from .feedback_checks import valid_feedback
PROOF_DEFAULTS={'alpha_threshold':128,'joint_tolerance_px':.02,'shoulder_tolerance_px':10,
                'sheet_tile_px':1024,'sheet_caption_px':32,'sheet_background':[24,24,24,255],
                'sheet_height_px':1184,'sheet_sole_baseline_px':1100,
                'source_scale':4,'webp_method':6,'budget_bytes':6_000_000}
PROOF_TEXT_FILES=('per_part_coverage.csv','pose_table.md','proportion_table.md')
# Static rear occlusions are explicit rig-v2 delivery facts, not missing parts.
OCCLUSIONS={'front':{},'rear':{
    'head':'The closed back of the hood hides the mask and head.',
    'hand_near':'The near fist is hidden by the torso and rear robe after the true turn; its complete solo is retained.',
    'cage':'The closed barrel and robe occlude the front-hanging birdcage.',
    'torso':'The one-piece rear robe and shoulder mantle cover the iron barrel.',
    'pelvis':'The rear robe covers the pelvic plate.',
    'belt':'The rear robe covers the waist band and front keys.'}}


def native_pose_contract(spec,native):
    required={'values_within_tolerance','both_feet_planted','level_shoulders','near_elbow_not_forward',
        'forearms_fold_forward','near_forearm_outward','rounded_lames','rounded_overlapping_lames','soft_vertical_folds','hem_between_knee_and_midshin','panes_recessed_behind_bars','mask_deep_inside_roll','rounded_rear_cowl','long_ragged_tears','mask_convex_and_cross_cut',
        'lantern_fist_pivot','accessory_counts','lantern_hexagonal','mantle_covers_both_shoulders','opened_mesh_hash_matches_build','native_joint_endpoints','geometry_report',
        'whole_native_features','candle_visible_through_glass','two_panes_clear_both_views','passing_native_baseline',
        'native_mutations_rejected','native_geometry_restored'}
    mutants={'wrong_polygon_owner','stale_native_mesh_hash','detached_lantern','flattened_finger',
             'thin_armour','collapsed_cloth','rear_mask_exposed','collapsed_cowl_roll','flattened_vertical_folds','floating_lamp_house','rear_signature_hidden'}
    joints={b[key] for b in spec['armature']['bones'] for key in ('head','tail')}
    return (native.get('passed') is True and valid_feedback(spec,native) and valid_rows(spec,native.get('pose_values',[])) and
        required<=set(native.get('checks',{})) and all(v is True for v in native['checks'].values()) and
        set(native.get('mutations',{}))==mutants and all(v is True for v in native['mutations'].values()) and
        set(native.get('observed_joints',{}))==joints)


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
        a=recorded[view]['hand_near'][0];b=recorded[view]['pelvis'][0]
        checks[view+'_lantern_side']=a>b if view=='front' else a<b
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
        body=np.logical_or.reduce([raster.masks[n] for n in spec['labels'] if n not in ('lantern','lamp_house')])
        ys=np.argwhere(body)[:,0];heights[view]=int(ys.max()-ys.min()+1)
    front_area=coverage['front']['lantern']['pure_owner_pixels'];rear_area=coverage['rear']['lantern']['pure_owner_pixels']
    visible_area_ratio=rear_area/front_area if front_area else 0
    area_ratio=coverage['front']['lantern']['solo_pixels']/coverage['rear']['lantern']['solo_pixels']
    checks={'native_pose_and_mutations':native_pose_contract(spec,native),'shoulder_and_turn':pose['passed'],
        'complete_label_coverage':not failures,
        'source_drawn_height':abs(heights['front']-spec['mq18']['source_drawn_height_px']*4)<=2,
        'lantern_area_ratio':.8<=area_ratio<=1.25,
        'rear_visible_lantern_area':visible_area_ratio>=spec['dimensions']['lantern_rear_visible_over_front_min'],
        'two_panes_and_candle_both_views':native['lantern_visibility']['passed']}
    result={'passed':all(checks.values()),'checks':checks,'spec_hash':digest(spec),
        'native_mesh_hash':build['combined_mesh_hash'],'native_probe_sha256':sha(capture/'native_probe.json'),
        'capture_manifest_sha256':sha(capture/'capture_manifest.json'),'pose':pose,
        'per_part_coverage':coverage,'unexplained_parts':failures,'body_height_px':heights,'lantern_projected_area_ratio':area_ratio,'lantern_visible_area_ratio':visible_area_ratio,
        'proportions':native['proportions'],'pose_values':native['pose_values'],
        'lame_counts':native['lame_counts'],'feedback1':native['feedback1'],'lantern_visibility':native['lantern_visibility'],'robe_tears':native['robe_tears'],
        'fit_gate':'Not applicable: the director changed the pose.',
        'proof_text_sha256':{name:sha(capture/name) for name in PROOF_TEXT_FILES if (capture/name).exists()}}
    if not write_outputs:return result
    (capture/'per_part_coverage.csv').write_text(table.getvalue())
    lines=['| Requirement | Value | Target | Native measurement | Tolerance | Result |',
           '|---|---|---:|---:|---:|---|']
    for row in native['pose_values']:
        lines.append(f"| {row['requirement']} | {row['name']} | {row['target']:.9f} | {row['measured']:.9f} | {row['tolerance']} | {'PASS' if row['passed'] else 'FAIL'} |")
    lines+=['','All pose/volume values come from opened native vertices or actual armature endpoints. H is sole-to-hood crown; L is straight hip-to-sole. The fixed fist and source segment ratio solve the near arm lengths.',
        '',f"Far shoulder rise {pose['shoulder_rise_px']:.6f}px; required {pose['target_shoulder_rise_px']:.6f}px; error {pose['shoulder_error_px']:.6f}px (±10px). 3D shoulder Z difference {pose['level_difference_m']:.9f}m.",
        '',f"Rear transform {pose['rear_relative_matrix']}; determinant {pose['rear_determinant']:.9f}. Soles {native['soles_m']}. Lantern front/rear isolated projected area ratio {result['lantern_projected_area_ratio']} (0.8–1.25). Rear/front visible area ratio {result['lantern_visible_area_ratio']} (minimum 0.6).",
        '',f"Native overlapping lame counts: {native['lame_counts']}. Native long hem tears: {native['robe_tears']}."]
    lines += ['',f"Feedback 1 opened barrel lean: {native['feedback1']['barrel_lean_degrees']:.9f} degrees. Native soft fold crests: {native['feedback1']['fold_crests']}. Hem Z range: {native['feedback1']['hem_z_range_m']}; knee {native['feedback1']['knee_z_m']:.9f}; mid-shin {native['feedback1']['midshin_z_m']:.9f}.",'',native['lantern_visibility']['definition']]
    for view in ('front','rear'):
        lines.append(f"{view} clear pane equivalents: {native['lantern_visibility']['views'][view]['visible_pane_equivalents']:.9f}; candle visible samples: {native['candle_visibility']['visibility'][view]['visible_surface_samples']}.")
    lines += ['','| View | Pane | Visible native samples | Clear pane equivalent |','|---|---|---:|---:|']
    for view in ('front','rear'):
        for name,row in native['lantern_visibility']['views'][view]['panes'].items():
            lines.append(f"| {view} | {name} | {row['visible_samples']}/{row['total_samples']} | {row['visible_pane_equivalent']:.9f} |")
    (capture/'pose_table.md').write_text('\n'.join(lines)+'\n')
    lines=['| Proportion | Current art / H | Native / H |','|---|---:|---:|']
    for name,row in native['proportions'].items():lines.append(f"| {name} | {row['source']:.9f} | {row['native']:.9f} |")
    lines+=['','| Director dimension | Target | Opened native | Result |','|---|---:|---:|---|']
    for row in native['pose_values']:
        if row['requirement']=='volumes':
            lines.append(f"| {row['name']} | {row['target']:.9f} | {row['measured']:.9f} | {'PASS' if row['passed'] else 'FAIL'} |")
    lines+=['','The front art retains 237px body registration at 4x; rear is the true turn. Source calipers and their provenance are in source_measurements.json. Source pose comparison is informational.',
        '',f"Native front/rear body heights: {heights}. No old-pose silhouette fit gate applies."]
    (capture/'proportion_table.md').write_text('\n'.join(lines)+'\n')
    result['proof_text_sha256']={name:sha(capture/name) for name in PROOF_TEXT_FILES}
    write(capture/'mq18_acceptance.json',result)
    print('MQ18_ACCEPTANCE: '+('PASS' if result['passed'] else 'FAIL')+'; unexplained_parts='+str(failures),flush=True)
    return result


def validate_acceptance(capture,spec=None,require_pass=True):
    capture=Path(capture);before=json.loads((capture/'mq18_acceptance.json').read_text())
    report=inspect(capture,spec,write_outputs=False)
    if before!=report or (require_pass and not report['passed']):
        raise ValueError('Missing, failed or stale mq18 acceptance')
    return report


def review_sheet(capture):
    capture=Path(capture);size=PROOF_DEFAULTS['sheet_tile_px'];caption=PROOF_DEFAULTS['sheet_caption_px']
    refs=[('Current Last Lamplighter art',PROJECT/'assets/units/last_lamplighter.png',4),
        ('Last Lamplighter front clay',capture/'front_clay.png',1),
        ('Last Lamplighter rear: true 180 turn',capture/'rear_clay.png',1),
        ('Storm Cantor mq-17 scale reference',FOLDER/'references/mq17_front_clay.webp',1)]
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
    print('MQ18_CONTACT_SHEET: PASS; '+str(capture/'contact_sheet.webp'),flush=True)
