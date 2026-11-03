"""Recompute pose, true-turn, coverage and report-only proportions from proof."""
import csv
import json
from pathlib import Path

import numpy as np
from PIL import Image

from spec.art_identity.maquettes.blender.backend import load_render
from spec.art_identity.maquettes.blender.capture_manifest import read_manifest
from spec.art_identity.maquettes.blender.contract import digest
from spec.art_identity.maquettes.blender.curate_delivery import sha, write
from spec.art_identity.maquettes.blender.pixel_coverage import part_coverage
from spec.art_identity.maquettes.raster import camera
from .source_measurements import FOLDER
from .native_checks import NATIVE_DEFAULTS
from .feedback2_checks import visible_mask_digest

PROOF_DEFAULTS = {'alpha_threshold': 128, 'numerical_epsilon': 1e-6,
                   'shoulder_tolerance_px': 10, 'capture_size': 1024}
NATIVE_REQUIRED_CHECKS = ('opened_mesh_hash_matches_build', 'native_joint_endpoints',
    'knee_angles_within_brief', 'near_elbow_angle_within_brief', 'hip_lean_5_degrees',
    'head_level_and_chest_facing', 'near_foot_forward_half_step',
    'falchion_grip_through_fist', 'falchion_pommel_above_fist',
    'falchion_tip_forward_of_far_foot', 'falchion_director_axis_angles',
    'falchion_tip_above_floor', 'scarf_covers_both_shoulders',
    'whole_native_features', 'material_mutation_rejected', 'geometry_mutation_rejected',
    'stance_width_1_25_shoulders','far_hand_director_position','falchion_vertical_plane','native_geometry_restored','accepted_native_meshes_unchanged',
    'falchion_length_0_48_H','falchion_guard_width','falchion_maximum_width','falchion_width_peak_at_two_thirds',
    'falchion_spine_straight_before_clip','falchion_clipped_back_last_0_08_H','falchion_convex_cutting_edge','native_blade_projected_area_ratio')
NATIVE_REQUIRED_CHECKS += tuple(side+'_'+name for side in ('near','far') for name in (
    'three_closed_shells','one_third_overlaps','drop_0_07_H','domed_top_over_joint',
    'cylinder_bands_follow_arm','equal_lame_heights','no_horizontal_disc_faces','joint_covered'))


def pose_gates(spec, joints, native):
    near, far = [np.asarray(joints['front']['shoulder_'+s]) for s in ('near', 'far')]
    rise, expected = float(near[1]-far[1]), float(.15*abs(near[0]-far[0]))
    native_j = native['joints_world']
    dz = abs(native_j['shoulder_near'][2]-native_j['shoulder_far'][2])
    matrices = {v: camera(spec, v)[0][:3,:3] for v in ('front','rear')}
    delta = matrices['rear'] @ np.linalg.inv(matrices['front'])
    determinants = {v: float(np.linalg.det(m)) for v,m in matrices.items()}
    feet = native['sole_min_z_m']
    hand_delta = {v: joints[v]['hand_far'][0]-joints[v]['torso'][0] for v in ('front','rear')}
    e = PROOF_DEFAULTS['numerical_epsilon']
    checks = {
        'level_shoulders_3d': dz <= e,
        'projected_shoulder_rule': abs(rise-expected) <= PROOF_DEFAULTS['shoulder_tolerance_px'],
        'proper_true_half_turn': bool(np.allclose(delta,np.diag([-1.,-1.,1.]),atol=e,rtol=0)
                                     and all(abs(d-1)<=e for d in determinants.values())),
        'both_soles_planted': set(feet) == {'near','far'} and all(abs(z)<=e for z in feet.values()),
        'weapon_hand_front_left_rear_right': hand_delta['front'] < 0 < hand_delta['rear']}
    return {'passed': all(checks.values()), 'checks': checks,
            'shoulders': {'near_px':near.tolist(),'far_px':far.tolist(),'far_above_near_px':rise,
                          'expected_px':expected,'error_px':abs(rise-expected),'native_level_error_m':dz},
            'true_turn': {'rear_from_front':delta.tolist(),'determinants':determinants,
                          'sole_min_z_m':feet,'far_hand_minus_torso_x_px':hand_delta}}


def bounds(path):
    pixels = np.asarray(Image.open(path).convert('RGBA'))
    y,x = np.where(pixels[...,3] >= PROOF_DEFAULTS['alpha_threshold'])
    if not len(x):
        raise ValueError('Empty proportion mask: ' + str(path))
    return [int(x.min()),int(y.min()),int(x.max()+1),int(y.max()+1)]


def inspect(spec, capture, folder=FOLDER, write_reports=True):
    capture, folder = Path(capture), Path(folder)
    manifest = read_manifest(capture,digest(spec),('full',))
    joints = json.loads((capture/'joints_px.json').read_text())
    native = json.loads((capture/'native_probe.json').read_text())
    build = json.loads((capture/'build_report.json').read_text())
    pose = pose_gates(spec,joints,native)
    coverage = {}
    for view in ('front','rear'):
        raster = load_render(spec,capture,view)
        coverage[view] = part_coverage(spec,raster,Image.open(capture/(view+'_parts.png')).convert('RGBA'))
        for part,row in coverage[view].items():
            # Occlusion is an explicit author input; never infer approval from
            # a missing colour or an empty solo.
            row['explicit_occlusion'] = spec.get('label_occlusions',{}).get(view,{}).get(part)
    missing = {v:[p for p,r in values.items() if not r['solo_pixels'] or r['clipped_at_canvas']
                  or (not r['pure_owner_pixels'] and not r['explicit_occlusion'])]
               for v,values in coverage.items()}
    observed = json.loads((folder/'source_measurements.json').read_text())
    source = observed['measurements']
    clay_box = bounds(capture/'front_clay.png')
    head_box = bounds(capture/'front_solo_head.png')
    front = joints['front']
    native_height = clay_box[3]-clay_box[1]
    scale = source['drawn_height_px']/native_height
    rows = [
        ['drawn height (px)', source['drawn_height_px'],native_height/4],
        ['head-part height / drawn height', source['head_part_height_ratio'],(head_box[3]-head_box[1])/native_height],
        ['great-helm height / drawn height (source caliper)',spec['source_calipers']['helm_height_px']/source['drawn_height_px'],(head_box[3]-head_box[1])/native_height],
        ['shoulder joint horizontal span (source px)',source['shoulder_joint_width_px'],abs(front['shoulder_near'][0]-front['shoulder_far'][0])*scale],
        ['torso neck to belt vertical length (source px)',source['torso_neck_to_belt_px'],abs(front['head'][1]-front['pelvis'][1])*scale]]
    for side in ('near','far'):
        sole = bounds(capture/('front_solo_foot_'+side+'.png'))[3]
        rows.append(['leg hip to contact '+side+' (source px)',source['leg_hip_to_contact_px'][side],(sole-front['hip_'+side][1])*scale])
    shoulder_boxes=[bounds(capture/('front_solo_pauldron_'+s+'.png')) for s in ('near','far')]
    body_box=observed['views']['front']['parts']['body']['bbox_px']
    rows.append(['armoured shoulder envelope width (source px)',body_box[2]-body_box[0],
                 (max(b[2] for b in shoulder_boxes)-min(b[0] for b in shoulder_boxes))*scale])
    o=native['observed'];p=spec['pose'];angle_e=NATIVE_DEFAULTS['angle_tolerance_degrees'];ratio_e=NATIVE_DEFAULTS['ratio_tolerance']
    pose_numbers=all(abs(a-b)<=tol for a,b,tol in [
        (o['knee_angles_degrees']['near'],p['knee_bend_degrees'],angle_e),
        (o['knee_angles_degrees']['far'],p['knee_bend_degrees'],angle_e),
        (o['near_elbow_degrees'],p['near_elbow_bend_degrees'],angle_e),
        (o['hip_lean_degrees'],p['hip_lean_degrees'],angle_e),
        (o['stance_ratio'],p['foot_span_over_shoulder_span'],ratio_e),
        (o['near_step_over_L'],p['near_step_over_leg_length'],ratio_e),
        (o['blade_down_degrees'],p['blade_down_degrees'],angle_e),
        (o['blade_outward_degrees'],p['blade_outward_degrees'],angle_e),
        (native['feedback2']['blade']['pommel_to_tip_over_H'],spec['director_feedback2']['falchion']['pommel_to_tip_over_H'],ratio_e)])
    blade_areas={}
    for view in ('front','rear'):
        path=capture/(view+'_blade_area.png')
        pixels=np.asarray(Image.open(path).convert('RGBA'))
        mask=pixels[:,:,3]>=PROOF_DEFAULTS['alpha_threshold']
        blade_areas[view]=int(mask.sum())
        if not blade_areas[view] or mask[0].any() or mask[-1].any() or mask[:,0].any() or mask[:,-1].any():
            raise ValueError('Empty or clipped native blade area mask')
    area_ratio=blade_areas['rear']/blade_areas['front']
    area_bounds=spec['director_feedback2']['falchion']['projected_area_ratio_bounds']
    blade=native['feedback2']['blade'];design=spec['director_feedback2']['falchion']
    profile_numbers=all(abs(blade[name]-design[name])<=ratio_e for name in (
        'guard_width_over_H','maximum_width_over_H','maximum_width_fraction_from_guard','clipped_back_axis_length_over_H'))
    shell_numbers=all(abs(row['drop_over_H']-spec['director_feedback2']['pauldrons']['bottom_below_shoulder_over_H'])<=ratio_e
        and all(abs(value-spec['director_feedback2']['pauldrons']['overlap_fraction'])<=ratio_e for value in row['overlap_fractions'])
        for row in native['feedback2']['pauldrons']['sides'].values())
    locked=json.loads((folder/'feedback1_preservation.json').read_text())
    preserved=all(build['mesh_hashes'].get(name)==value for name,value in locked['fixed_native_mesh_hashes'].items())
    fixed_pixels=all(visible_mask_digest(capture/name)==expected for name,expected in locked['fixed_solo_pixel_sha256'].items())
    native_joints_match=all(np.linalg.norm(np.subtract(native['joints_world'][name],spec['joints'][name]))<=NATIVE_DEFAULTS['position_tolerance_m']
                            for bone in spec['armature']['bones'] for name in (bone['head'],bone['tail']))
    checks = {**pose['checks'],'native_probe':native.get('passed') is True,
              'required_native_observations':all(native.get('checks',{}).get(k) is True for k in NATIVE_REQUIRED_CHECKS),
              'native_mesh_hash_bound_to_build':native.get('native_mesh_hash')==build['combined_mesh_hash'],
              'native_joint_observations_match_spec':native_joints_match,
              'native_numeric_observations_match_director':pose_numbers and np.allclose(o['far_hand_offset_over_L'],
                  [p['far_hand_forward_over_leg_length'],-p['far_hand_outward_over_leg_length'],0],atol=ratio_e,rtol=0),
              'all_parts_present_or_explicitly_occluded':not any(missing.values()),
              'source_drawn_height':abs(native_height-source['drawn_height_px']*4)<=1,
              'renderer_blade_area_ratio':area_bounds[0]<=area_ratio<=area_bounds[1],
              'native_pauldron_shells':all(native['feedback2']['pauldrons']['checks'].values()),
              'native_feedback2_dimensions':profile_numbers and shell_numbers,
              'accepted_native_parts_and_pixel_joints_unchanged':preserved and joints==locked['render_joints_px'],
              'accepted_unaffected_solo_pixels_unchanged':fixed_pixels}
    checks={k:bool(v) for k,v in checks.items()}
    curation={name:sha(capture/name) for name in ('contact_sheet.webp','contact_sheet.json','validation/receipt_manifest.json') if (capture/name).is_file()}
    result = {'passed':all(checks.values()),'spec_hash':digest(spec),'checks':checks,'curation_bindings':curation,
              'pose':pose,'feedback2_native':native['feedback2'],'blade_area':{'pixels':blade_areas,'rear_over_front':area_ratio,'bounds':area_bounds,
                  'method':'Native renderer isolated blade surface, alpha>=128; hilt/glow excluded.'},'per_part_coverage':coverage,'missing_or_clipped_parts':missing,
              'proportions':{'rows':rows,'report_only':True,'head_part_includes_source_neck_attachment':True},
              'input_sha256':{n:sha(capture/n) for n in ('capture_manifest.json','native_probe.json')},
              'capture_images':manifest['images'],'fit_gate':'Not applicable: new pose; proportions report-only.'}
    if write_reports:
        write(capture/'mq16_acceptance.json',result)
        with (capture/'per_part_coverage.csv').open('w',newline='') as stream:
            writer=csv.writer(stream,lineterminator='\n')
            fields=['solo_pixels','visible_pixels','pure_owner_pixels','visible_fraction_of_solo','clipped_at_canvas','explicit_occlusion']
            writer.writerow(['view','part',*fields])
            for v,values in coverage.items():
                for part,row in values.items(): writer.writerow([v,part,*(row[f] for f in fields)])
        table=['# mq-16 proportions (report-only)','','The source head-part mask includes its neck attachment. No old-pose IoU gate.','',
               '| Measurement | Current art | Native front |','|---|---:|---:|']
        table += ['| '+str(name)+' | '+format(before,'.6f')+' | '+format(after,'.6f')+' |' for name,before,after in rows]
        (capture/'proportion_table.md').write_text('\n'.join(table)+'\n')
    return result


def validate_acceptance(spec,capture,folder=FOLDER):
    retained=json.loads((Path(capture)/'mq16_acceptance.json').read_text())
    current=inspect(spec,capture,folder,write_reports=False)
    if retained != current or current['passed'] is not True:
        raise ValueError('Missing, failed or stale recomputed mq-16 acceptance')
    return current
