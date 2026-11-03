"""On-demand Lamplighter gates, with strict failures and no proof exemptions."""
import argparse
import math
import numpy as np
from PIL import Image
from rr52_build import ROOT, CASE, ASSETS, VIEWS, partition
from rr52_checks import elbow_errors, idle_errors,arm_excursions
from cutout_pipeline.cases import read_json, write_json, digest
from humanoid_cutout.gates import matrix, structure_errors, source_errors, bindings
from humanoid_cutout.action_direction import report as direction_report
from humanoid_cutout.reach import report as reach_report
from humanoid_cutout.walk_gates import report as walk_report, support_report
from maquette_motion.features import source_pixels

DEFAULTS={'serialized_tolerance_px':0.001,'presented_grip_tolerance_px':0.001}


def held(layout,data,samples):
    view=layout['facing'];attachment=layout['held_items']['lantern'];grip=np.asarray(attachment['source_grip']);floor=attachment['floor_line_y'];errors=[];checks=0;maximum=0.
    hand=next(p for p in layout['parts'] if p['name']=='hand_near');item=next(p for p in layout['parts'] if p['name']=='lantern')
    hull=np.asarray(attachment['painted_floor']['points_local']);release=data['clips']['death']['release_at']['lantern'];land=data['view_held_drops'][view]['death']['lantern']['land']
    for row in samples['samples']:
        if row['view']!=view:continue
        pose=matrix(row['bones']['lantern']['global']);checks+=1
        if not np.allclose(pose[:2,:2].T@pose[:2,:2],np.eye(2),atol=1e-4):errors.append('lantern lost rigidity')
        if row['clip']!='death' and abs(math.degrees(math.atan2(pose[1,0],pose[0,0])))>35.0001:errors.append('lantern exceeds 35-degree budget')
        if row['clip']!='death' or row['phase']<release:
            if row['kind']=='presented':
                a=matrix(row['parts']['lantern']['transform'])@np.r_[grip-item['offset'],1]
                b=matrix(row['parts']['hand_near']['transform'])@np.r_[grip-hand['offset'],1]
            else:
                a=pose@np.r_[grip-layout['joints']['lantern']['position'],1]
                b=matrix(row['bones']['hand_near']['global'])@np.r_[grip-layout['joints']['hand_near']['position'],1]
            error=float(np.linalg.norm(a-b));maximum=max(maximum,error)
            if error>DEFAULTS['serialized_tolerance_px']:errors.append(f'{view}/{row["clip"]}/{row["phase"]}: grip gap {error}')
        elif row['phase']>=land:
            points=hull@pose[:2,:2].T+pose[:2,2]
            if abs(float(points[:,1].max())-floor)>DEFAULTS['serialized_tolerance_px']:errors.append(f'{view}/death/{row["phase"]}: floor support differs')
    return {'ok':not errors,'checks':checks,'max_grip_error_px':maximum,'errors':errors,'floor_stop_deg':attachment['painted_floor']['limit_deg']}


def source_contract(layout):
    view=layout['facing'];reg,paint,images,_=partition(view);errors=[];recovered=np.zeros_like(paint)
    for im in images.values():recovered[im[...,3]>0]=im[im[...,3]>0]
    if not np.array_equal(recovered,paint):errors.append('approved source identity differs')
    supplied=np.zeros_like(paint)
    approved=np.asarray(Image.open(ROOT/f'spec/peer_benchmark/staged/rr-52/{view}_body_underlay.png').convert('RGBA'))
    from maquette_motion.material_palette import outline_class,rules
    interior=(paint[...,3]>0)&~outline_class(paint,rules(CASE,view))
    for p in layout['parts']:
        if not p.get('paint_sources'):continue
        im=source_pixels(CASE,p);masks={n:np.asarray(Image.open(CASE/path).convert('L'))>0 for n,path in p['paint_sources'].items()}
        expected=np.zeros_like(paint);expected[masks['underlay']]=approved[masks['underlay']];expected[masks['cap']]=paint[masks['cap']]
        if not np.array_equal(im,expected):errors.append('hidden source differs from exact registered underlay/approved-paint UV: '+p['name'])
        if np.any(masks['cap']&(~masks['tuck']|~interior)):errors.append('cap outside its interior registered tuck: '+p['name'])
        supplied[masks['underlay']]=im[masks['underlay']]
    mask=approved[...,3]>0
    if not np.array_equal(supplied,approved):errors.append('whole director underlay differs')
    build=read_json(CASE/'proof/build.json')
    errors+=source_errors(CASE,layout,build)+structure_errors(layout,build)
    return {'ok':not errors,'errors':errors,'source_mismatch_pixels':int(np.any(recovered!=paint,axis=-1).sum()),'underlay':read_json(CASE/f'proof/{view}_underlay.json')}


def run(samples_path):
    samples=read_json(samples_path);data=read_json(CASE/'compiled_motion.json');arms=arm_excursions(data,read_json(CASE/'director_motion.json'));result={'native_pixels':False,'elbows':elbow_errors(data,samples),'defaults':DEFAULTS,'budget_clamps':data.get('budget_clamps',[]),'painted_budget_clamps':data.get('painted_budget_clamps',[]),'walk_arm_excursion_ratios':arms['ratios'],'arm_excursions':arms}
    groups={'source':{},'held':{},'idle':{},'walk':{},'supports':{},'direction':{},'reach':{}}
    for view in VIEWS:
        layout=read_json(CASE/f'layouts/{view}.json')
        groups['source'][view]=source_contract(layout)
        groups['held'][view]=held(layout,data,samples)
        groups['idle'][view]=idle_errors(layout,samples)
        groups['walk'][view]=walk_report(layout,data,samples)
        groups['supports'][view]=support_report(layout,data,samples)
        groups['direction'][view]=direction_report(layout,data,samples,bindings(CASE),require_presented=True)
        groups['reach'][view]=reach_report(layout,data,step_distance_px=samples['step_distance_px'],screen_pixel_scale=samples['screen_pixel_scale'])
    result.update(groups);errors=result['elbows']['errors'][:]+arms['errors']
    for group,views in groups.items():
        for view,r in views.items():
            errors+=r['errors'];print(f'RR52 {group.upper()} {view}: {"PASS" if r["ok"] else "FAIL"} ({len(r["errors"])} errors)',flush=True)
    result['ok']=not errors;result['errors']=errors;result['inputs']=bindings(CASE)
    write_json(CASE/'proof/gates.json',result)
    print(f'RR52 ELBOW GATE: {"PASS" if result["elbows"]["ok"] else "FAIL"} ({result["elbows"]["checks"]} checks; maximum hyperextension {result["elbows"]["max_hyperextension_deg"]:.6f} deg)')
    print(f'RR52 WALK ARM EXCURSIONS: {"PASS" if arms["ok"] else "FAIL"} ({arms["ratios"]})')
    print(f'RR52 POSE GATES: {"PASS" if result["ok"] else "FINDINGS"} ({len(errors)} errors)')
    for e in errors[:25]:print(e)
    return result['ok']

if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--samples',default=CASE/'proof/samples.json',type=__import__('pathlib').Path);args=p.parse_args()
    raise SystemExit(0 if run(args.samples) else 1)
