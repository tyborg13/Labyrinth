"""mq-20 native/capture gates and the five-panel comparison requested by owner."""
import csv
import io
import json
from pathlib import Path
from copy import deepcopy
import numpy as np
from PIL import Image,ImageDraw
from spec.art_identity.maquettes.blender.backend import load_render
from spec.art_identity.maquettes.blender.capture_manifest import read_manifest
from spec.art_identity.maquettes.blender.contract import digest
from spec.art_identity.maquettes.blender.curate_delivery import write,sha
from spec.art_identity.maquettes.blender.pixel_coverage import part_coverage
from ..acceptance import pose_gates,OCCLUSIONS,PROOF_DEFAULTS
from .recipe import BASE,PROJECT,CAPTURE_SIZE
from .measure import observe
from spec.art_identity.maquettes.raster import project

REPORT_TABLES=('pose_table.md','proportion_table.md','per_part_coverage.csv')


def native_contract(spec,native):
    expected=observe(spec,{p['id']:p['vertices'] for p in spec['pieces']},spec['joints'],{p['id']:p['faces'] for p in spec['pieces']})
    if expected['passed'] is not True:return False
    observed=native.get('pose_values',[]);rows=expected['pose_values']
    if len(observed)!=len(rows) or len({r.get('name') for r in observed})!=len(rows):return False
    by_name={r['name']:r for r in rows}
    for row in observed:
        target=by_name.get(row.get('name'))
        if target is None or any(row.get(k)!=target[k] for k in ('requirement','target','tolerance','minimum')):return False
        value=row.get('measured')
        if type(value) not in (int,float) or not np.isfinite(value) or row.get('passed') is not True:return False
        if (value<target['target']-target['tolerance'] if target['minimum'] else abs(value-target['target'])>target['tolerance']):return False
    required=set(expected['checks'])|{'opened_mesh_hash_matches_build','native_joint_endpoints','native_geometry','whole_native_features',
        'candle_and_glass_visible_both_views','passing_native_baseline','native_mutations_rejected','native_geometry_restored'}
    joints={b[key] for b in spec['armature']['bones'] for key in ('head','tail')}
    return (native.get('passed') is True and native.get('spec_hash')==digest(spec) and not spec['mq20']['design_pending'] and
        required<=set(native.get('checks',{})) and all(v is True for v in native['checks'].values()) and
        set(native.get('observed_joints',{}))==joints and
        set(native.get('mutations',{}))=={'flattened_claw','rear_cross','collapsed_robe','detached_lantern'} and all(v is True for v in native['mutations'].values()))


def inspect(capture,spec,write_outputs=True):
    capture=Path(capture);manifest=read_manifest(capture,digest(spec),('full',))
    native=json.loads((capture/'native_probe.json').read_text());build=json.loads((capture/'build_report.json').read_text())
    if native['spec_hash']!=digest(spec) or native['native_mesh_hash']!=build['combined_mesh_hash']:raise ValueError('Stale mq-20 native observations')
    size=spec['mq20'].get('capture_size_px',1024)
    normalized_joints=deepcopy(json.loads((capture/'joints_px.json').read_text()))
    for view in normalized_joints:
        for name,point in normalized_joints[view].items():normalized_joints[view][name]=[v*1024/size for v in point]
    pose=pose_gates(spec,normalized_joints,native)
    coverage={};rasters={};failures=[];table=io.StringIO(newline='');writer=csv.writer(table,lineterminator='\n')
    writer.writerow(['view','part','solo_pixels','visible_pixels','pure_owner_pixels','clipped','explicit_occlusion'])
    for view in ('front','rear'):
        raster=load_render(spec,capture,view);rasters[view]=raster
        coverage[view]=part_coverage(spec,raster,np.array(Image.open(capture/(view+'_parts.png')).convert('RGBA')))
        for name,r in coverage[view].items():
            reason=OCCLUSIONS[view].get(name) if not r['pure_owner_pixels'] else None
            r['explicit_occlusion']=reason
            if not r['solo_pixels'] or r['clipped_at_canvas'] or (not r['pure_owner_pixels'] and not reason):failures.append(view+':'+name)
            writer.writerow([view,name,r['solo_pixels'],r['visible_pixels'],r['pure_owner_pixels'],r['clipped_at_canvas'],reason or ''])
    front=rasters['front'];far=front.masks['pauldron_far'];names={n:k for k,n in enumerate(front.names)}
    hidden_by_hood=int((far&np.isin(front.owners,[names['hood'],names['head']])).sum())
    near=coverage['front']['pauldron_near'];far_row=coverage['front']['pauldron_far']
    area=coverage['front']['lantern']['solo_pixels']/coverage['rear']['lantern']['solo_pixels']
    rear_visible=coverage['rear']['lantern']['pure_owner_pixels']/max(1,coverage['front']['lantern']['pure_owner_pixels'])
    body=np.logical_or.reduce([front.masks[n] for n in spec['labels'] if n!='lantern']);ys=np.argwhere(body)[:,0]
    body_points=np.concatenate([np.asarray(p['vertices']) for p in spec['pieces'] if p['part']!='lantern'])
    expected_height=float(np.ptp(project(spec,body_points,'front',size)[:,1]))
    common_scale=json.loads((BASE/'measurements.json').read_text())['ortho_scale']
    checks={'native_observations':native_contract(spec,native),'shoulder_and_true_turn':pose['passed'],
        'label_coverage':not failures,'near_plate_fully_visible':native.get('near_plate_visibility',{}).get('passed') is True,
        'far_plate_partly_hidden_by_head':hidden_by_hood>0 and far_row['pure_owner_pixels']>0,
        'both_rear_plates_visible':all(coverage['rear']['pauldron_'+s]['pure_owner_pixels']>0 for s in ('near','far')),
        'lantern_projected_area_ratio':spec['dimensions']['lantern_projected_area_ratio_min']<=area<=spec['dimensions']['lantern_projected_area_ratio_max'],
        'lantern_rear_visible_area':rear_visible>=spec['dimensions']['lantern_rear_visible_over_front_min'],
        'candle_and_panes_both_views':native['lantern_visibility']['passed'],
        'source_registration':abs(spec['ortho_scale']/size-common_scale/1024)<1e-12 and abs(int(ys.max()-ys.min()+1)-expected_height)<=2}
    result={'passed':all(checks.values()),'checks':checks,'spec_hash':digest(spec),'native_mesh_hash':build['combined_mesh_hash'],
        'native_probe_sha256':sha(capture/'native_probe.json'),'capture_manifest_sha256':sha(capture/'capture_manifest.json'),
        'pose':pose,'coverage':coverage,'unexplained_parts':failures,'far_plate_pixels_hidden_by_head':hidden_by_hood,
        'lantern_projected_area_ratio':area,'lantern_rear_front_visible_area':rear_visible,
        'registration':{'common_mq18_ortho_scale':common_scale,'expected_body_height_px':expected_height,'captured_body_height_px':int(ys.max()-ys.min()+1)},
        'tables_sha256':{n:sha(capture/n) for n in REPORT_TABLES if (capture/n).exists()}}
    if write_outputs:
        (capture/'per_part_coverage.csv').write_text(table.getvalue())
        lines=['| Requirement | Measurement | Target | Observed | Tolerance | Result |','|---|---|---:|---:|---:|---|']
        for r in native['pose_values']:lines.append(f"| {r['requirement']} | {r['name']} | {r['target']:.9f} | {r['measured']:.9f} | {r['tolerance']} | {'PASS' if r['passed'] else 'FAIL'} |")
        lines+=['',json.dumps(native['clearance'],sort_keys=True),'',json.dumps(native['surfaces'],sort_keys=True)]
        (capture/'pose_table.md').write_text('\n'.join(lines)+'\n')
        old=json.loads((BASE/'delivery/native_probe.json').read_text())['proportions']
        lines=['| Proportion | Current art / H | mq-18 / H | mq-20 / H |','|---|---:|---:|---:|']
        for name,r in native['proportions'].items():lines.append(f"| {name} | {r['source']:.9f} | {old[name]['native']:.9f} | {r['native']:.9f} |")
        (capture/'proportion_table.md').write_text('\n'.join(lines)+'\n')
        result['tables_sha256']={n:sha(capture/n) for n in REPORT_TABLES};write(capture/'mq20_acceptance.json',result)
        print('MQ20_ACCEPTANCE: '+('PASS' if result['passed'] else 'FAIL')+'; unexplained_parts='+str(failures),flush=True)
    return result


def validate_acceptance(capture,spec):
    recorded=json.loads((Path(capture)/'mq20_acceptance.json').read_text());current=inspect(capture,spec,False)
    if recorded!=current or current['passed'] is not True:raise ValueError('Missing, failed or stale mq-20 acceptance')
    return current


def review_sheet(capture):
    capture=Path(capture);size=CAPTURE_SIZE
    extra=size-PROOF_DEFAULTS['sheet_tile_px']
    refs=[('Old art',PROJECT/'assets/units/last_lamplighter.png',4),('mq-18 front clay',BASE/'delivery/front_clay.png',1),
        ('mq-20 front clay',capture/'front_clay.png',1),('mq-18 rear clay',BASE/'delivery/rear_clay.png',1),('mq-20 rear clay',capture/'rear_clay.png',1)]
    canvas=Image.new('RGBA',(5*size,PROOF_DEFAULTS['sheet_height_px']+extra),tuple(PROOF_DEFAULTS['sheet_background']));draw=ImageDraw.Draw(canvas);inputs=[]
    for k,(title,path,scale) in enumerate(refs):
        im=Image.open(path).convert('RGBA')
        if scale!=1:im=im.resize((im.width*scale,im.height*scale),Image.Resampling.NEAREST)
        sole=int(np.argwhere(np.array(im)[:,:,3]>=PROOF_DEFAULTS['alpha_threshold'])[:,0].max())+1
        y=PROOF_DEFAULTS['sheet_sole_baseline_px']+extra-sole
        if y<PROOF_DEFAULTS['sheet_caption_px'] or y+im.height>canvas.height:raise ValueError('Contact sheet clips an input')
        canvas.alpha_composite(im,(k*size+(size-im.width)//2,y));draw.text((k*size+8,8),title,fill='white')
        inputs.append({'path':path.name if path.parent==capture else str(path.relative_to(PROJECT)),
            'capture_relative':path.parent==capture,'sha256':sha(path),'display_scale':scale,'display_y_px':y})
    canvas.save(capture/'contact_sheet.webp',lossless=True,exact=True,method=PROOF_DEFAULTS['webp_method'])
    if not np.array_equal(np.array(canvas),np.array(Image.open(capture/'contact_sheet.webp').convert('RGBA'))):raise ValueError('Contact sheet pixels changed')
    write(capture/'contact_sheet.json',{'inputs':inputs,'sheet_sha256':sha(capture/'contact_sheet.webp'),'size':list(canvas.size),
        'registration':'Old production art at exact 4x; all native clays at 1:1, inherited common registration; sole translations only. No individual scale fitting.'})
    print('MQ20_CONTACT_SHEET: PASS; '+str(capture/'contact_sheet.webp'),flush=True)
