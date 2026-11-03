"""Fail-closed mq-21 capture gates; portable numbers never certify a render."""
import json
from pathlib import Path
import numpy as np
from PIL import Image
from spec.art_identity.maquettes.blender.backend import load_render
from spec.art_identity.maquettes.blender.capture_manifest import read_manifest
from spec.art_identity.maquettes.blender.contract import digest
from spec.art_identity.maquettes.blender.curate_delivery import write,sha
from spec.art_identity.maquettes.blender.pixel_coverage import part_coverage
from ..acceptance import pose_gates,bounds
from .mq21_checks import observe
from ..source_measurements import FOLDER

NATIVE_CHECKS=('opened_mesh_hash_matches_build','native_joint_endpoints','whole_native_features',
    'native_geometry','scarf_covers_shoulders','native_facing','material_mutation_rejected',
    'geometry_mutation_rejected','native_geometry_restored','source_reference_bound','accepted_round2_meshes_preserved',
    'finger_1_through_handle_semantic_mutation_rejected','finger_1_detached_semantic_mutation_rejected','grip_mutation_geometry_restored')
RECOMPUTE_DEFAULTS={'degrees_tolerance':.001,'other_tolerance':.0001}


def measurements_agree(expected,actual):
    return set(actual)==set(expected) and all(
        abs(actual[name]['actual']-row['actual'])<=RECOMPUTE_DEFAULTS[
            'degrees_tolerance' if name.endswith('_degrees') else 'other_tolerance']
        for name,row in expected.items())


def inspect(spec,capture,write_reports=True):
    capture=Path(capture);manifest=read_manifest(capture,digest(spec),('full',))
    native=json.loads((capture/'native_probe.json').read_text());build=json.loads((capture/'build_report.json').read_text())
    joints=json.loads((capture/'joints_px.json').read_text());pose=pose_gates(spec,joints,native)
    # Feedback 2 explicitly permits reducing only the far-side hunch.
    h=spec['mq16']['height_m'];allowed=spec['mq21']['forms']['blade_clearance']['maximum_far_shoulder_hunch_reduction_over_H']*h
    delta=native['joints_world']['shoulder_near'][2]-native['joints_world']['shoulder_far'][2]
    pose['checks'].pop('level_shoulders_3d')
    pose['checks']['far_hunch_reduction_within_director_limit']=bool(-1e-6<=delta<=allowed+1e-6)
    pose['passed']=all(pose['checks'].values())
    expected=observe(spec);checks=dict(pose['checks'])
    checks['compiled_geometry_observations']=expected['passed']
    checks['native_geometry_observations']=native.get('passed') is True and all(native.get('checks',{}).get(k) is True for k in (*expected['checks'],*NATIVE_CHECKS))
    checks['native_mesh_and_spec_binding']=native.get('spec_hash')==digest(spec) and native.get('native_mesh_hash')==build['combined_mesh_hash']
    checks['native_measurements_recomputed']=measurements_agree(expected['measurements'],native.get('measurements',{}))
    checks['native_joint_observations_recomputed']=all(name in native['joints_world'] and np.linalg.norm(np.subtract(native['joints_world'][name],spec['joints'][name]))<=1e-5
        for bone in spec['armature']['bones'] for name in (bone['head'],bone['tail']))
    coverage={};centroids={}
    for view in ('front','rear'):
        raster=load_render(spec,capture,view);parts=Image.open(capture/(view+'_parts.png')).convert('RGBA')
        coverage[view]=part_coverage(spec,raster,parts)
        checks[view+'_all_20_labels']=set(coverage[view])==set(spec['labels']) and all(row['solo_pixels']>0 and row['pure_owner_pixels']>0 and not row['clipped_at_canvas'] for row in coverage[view].values())
        pixels=np.asarray(Image.open(capture/(view+'_solo_pauldron_near.png')).convert('RGBA'))
        yy,xx=np.where(pixels[:,:,3]>=128)
        centroids[view]=[float(xx.mean()),float(yy.mean())] if len(xx) else None
        hand=coverage[view]['hand_far'];weapon=coverage[view]['falchion']
        checks[view+'_distinct_grip_and_sword_labels']=hand['pure_owner_pixels']>0 and weapon['pure_owner_pixels']>0 and spec['labels']['hand_far']!=spec['labels']['falchion']
    checks['front_near_pauldron_centroid_outward']=centroids['front'] is not None and centroids['front'][0]>joints['front']['shoulder_near'][0]
    facing=json.loads((capture/'facing_report.json').read_text());checks['rendered_facing']=facing['passed'] is True
    old=json.loads((FOLDER/'source_measurements.json').read_text());front=joints['front'];source=old['measurements']
    h=bounds(capture/'front_clay.png');head=bounds(capture/'front_solo_head.png');height=h[3]-h[1]
    rows=[['drawn height (px)',source['drawn_height_px'],height/4],
          ['head part / drawn height',source['head_part_height_ratio'],(head[3]-head[1])/height],
          ['shoulder-joint span (source px)',source['shoulder_joint_width_px'],abs(front['shoulder_near'][0]-front['shoulder_far'][0])/4]]
    # Compare actual projected limb diameters at the original 4x source scale.
    for side in ('near','far'):
        for limb in ('upper','fore','hand'):
            box=bounds(capture/('front_solo_'+limb+'_'+side+'.png'))
            source_name=('hand_' if limb=='hand' else 'arm_')+side
            original=old['views']['front']['parts'][source_name]['bbox_px']
            rows.append([limb+' '+side+' bounding width (source px; whole source arm for upper/fore)',original[2]-original[0],(box[2]-box[0])/4])
    result={'passed':all(checks.values()),'checks':{k:bool(v) for k,v in checks.items()},'spec_hash':digest(spec),
            'pose':pose,'measurements':native['measurements'],'per_part_coverage':coverage,
            'pauldron_solo_centroids_px':centroids,'proportion_rows':rows,
            'input_sha256':{name:sha(capture/name) for name in ('native_probe.json','build_report.json','capture_manifest.json')},
            'capture_images':manifest['images']}
    if write_reports:
        write(capture/'mq21_acceptance.json',result)
        lines=['# mq-21 proportions against old art (report-only)','','Both maquettes use the mq-16 camera scale. No pose-fit or IoU gate.','',
               '| Measurement | Old art | mq-21 |','|---|---:|---:|']
        lines.extend('| '+str(name)+' | '+format(before,'.6f')+' | '+format(after,'.6f')+' |' for name,before,after in rows)
        (capture/'mq21_proportion_table.md').write_text('\n'.join(lines)+'\n')
    return result


def validate_acceptance(spec,capture):
    saved=json.loads((Path(capture)/'mq21_acceptance.json').read_text());actual=inspect(spec,capture,False)
    if saved!=actual or not actual['passed']:raise ValueError('Missing, failed or stale mq-21 acceptance')
    return actual
