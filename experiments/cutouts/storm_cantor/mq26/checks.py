"""On-demand rr-56 source and sampled motion checks; native status stays explicit."""
import argparse
import math
from pathlib import Path
import numpy as np
from PIL import Image
from build import ROOT, CASE, ASSETS, STAGED, VIEWS, partition
from cutout_pipeline.cases import read_json, write_json, digest
from humanoid_cutout.gates import structure_errors, matrix, bindings
from humanoid_cutout.elbows import report as elbows
from humanoid_cutout.action_direction import report as direction
from reach_acceptance import report as reach
from humanoid_cutout.walk_gates import report as walk, support_report
from humanoid_cutout.held_follow import validate, angle
from humanoid_cutout.compiler import compile_motion
from maquette_motion.features import source_pixels
DEFAULTS={'matrix_tolerance':0.0001,'presented_attachment_tolerance_px':0.001,'pixel_attachment_tolerance_px':1.415,'crop_zoom':4}

def bbox(mask):
    y,x=np.nonzero(mask)
    return [int(x.min()),int(y.min()),int(x.max()+1),int(y.max()+1)] if len(x) else None

def longest(mask):
    best=0
    for row in mask:
        lengths=np.diff(np.flatnonzero(np.diff(np.r_[False,row,False])))
        if len(lengths):best=max(best,int(lengths[::2].max(initial=0)))
    return best

def art_report():
    rows={}
    for view in VIEWS:
        reg,paint,images,_=partition(view)
        rest=np.zeros_like(paint)
        for im in images.values():rest[im[...,3]>0]=im[im[...,3]>0]
        assert np.array_equal(rest,paint)
        layout=read_json(CASE/f'layouts/{view}.json')
        under=np.asarray(Image.open(STAGED/f'{view}_body_underlay.png').convert('RGBA'))
        combined=np.zeros_like(under)
        for part in layout['parts']:
            if part.get('hidden_material'):
                im=source_pixels(CASE,part);combined[im[...,3]>0]=im[im[...,3]>0]
        under_exact=bool(np.array_equal(combined[under[...,3]>0],under[under[...,3]>0]))
        outside=(combined[...,3]>0)&(paint[...,3]==0)
        # Source crop is diagnostic only, never new character paint.
        assembled=Image.new('RGBA',(255,255))
        for p in sorted(layout['parts'],key=lambda p:p['z_index']):assembled.alpha_composite(Image.open(CASE/p['file']).convert('RGBA'),tuple(p['offset']))
        crop=bbox(outside);path=CASE/f'proof/{view}_outside_rest_x4.png'
        if crop:assembled.crop(crop).resize(((crop[2]-crop[0])*4,(crop[3]-crop[1])*4),Image.Resampling.NEAREST).save(path)
        head=images['head'];y,x=np.nonzero(head[...,3]);top=int(y.min());body_top=64 if view=='front' else 49
        hero=np.asarray(Image.open(ROOT/f'assets/units/protagonist_cutout/{view}/{view}_assembled_rest_v9.png').convert('RGBA'))
        hy,hx=np.nonzero(hero[...,3]);hero_height=int(hy.max()+1-hy.min())
        sole=max(p['bbox'][3] for p in layout['parts'] if p['name'].startswith('foot_'))
        rows[view]={'source_rest_mismatch_pixels':int(np.any(rest!=paint,axis=-1).sum()),'whole_underlay_exact_rgba':under_exact,
                    'outside_rest_texels':int(outside.sum()),'outside_rest_bbox':crop,'outside_rest_longest_horizontal_run':longest(outside),
                    'outside_rest_crop':str(path.relative_to(CASE)),'drawn_source_height_with_tines_px':sole-top,
                    'drawn_source_height_without_tines_px':sole-body_top,'without_tines_cut_y':body_top,'hero_drawn_height_px':hero_height,
                    'height_ratio_with_tines':(sole-top)/hero_height,'height_ratio_without_tines':(sole-body_top)/hero_height}
    Image.open(CASE/'source/front/approved.png').crop((106,98,141,130)).resize((140,128),Image.Resampling.NEAREST).save(CASE/'proof/front_bell_ribs_x4.png')
    rows['bell_depth']='torso_back < bell < torso_ribs; no over-rib fallback'
    return rows

def attachments(layout,data,samples):
    errors=[];maximum={'staff':0.,'bell':0.};checks=0;floor_checks=0
    view=layout['facing'];j=layout['joints']
    for row in samples['samples']:
        if row['view']!=view:continue
        for item in ('staff','bell'):
            attachment=layout['held_items'][item];parent=attachment['hand']
            pose=matrix(row['bones'][item]['global']);par=matrix(row['bones'][parent]['global'])
            if not np.allclose(pose[:2,:2].T@pose[:2,:2],np.eye(2),atol=DEFAULTS['matrix_tolerance']):errors.append(f'{view}/{row["clip"]}: {item} rigidity')
            release=data['clips'][row['clip']].get('release_at',{}).get(item,float('inf'))
            grip=np.asarray(attachment['source_grip']);bind=np.asarray(j[item]['position']);parent_bind=np.asarray(j[parent]['position'])
            if row['phase']<release:
                gap=float(np.linalg.norm(pose@np.r_[grip-bind,1]-par@np.r_[grip-parent_bind,1]));maximum[item]=max(maximum[item],gap)
                if gap>DEFAULTS['presented_attachment_tolerance_px']:errors.append(f'{view}/{row["clip"]}/{row["phase"]}: {item} hook/grip {gap}')
            elif item=='staff' and row['phase']>=data['view_held_drops'][view]['death']['staff']['land']:
                points=np.asarray(attachment['painted_floor']['points_local']);heights=points@pose[1,:2]+pose[1,2]
                if heights.max()>attachment['floor_line_y']+0.001:errors.append(f'{view}/death: staff penetrates floor')
                floor_checks+=1
            checks+=1
    return {'ok':not errors,'errors':errors,'checks':checks,'floor_checks':floor_checks,'max_attachment_error_px':maximum}

def earlier_byte_identity():
    import subprocess
    changes=subprocess.check_output(['git','diff','--name-only','--','assets/units'],cwd=ROOT,text=True).splitlines()
    errors=[p for p in changes if not p.startswith('assets/units/storm_cantor_cutout/')]
    # Recompile earlier director data under the new optional-key validator.
    for name,case_name in [('ashen_reaver','rr48'),('chainbound_gaoler','rr44')]:
        folder=ROOT/f'experiments/cutouts/{name}/{case_name}'
        if not folder.exists():continue
        layouts={v:read_json(folder/f'layouts/{v}.json') for v in VIEWS}
        compiled=read_json(folder/'compiled_motion.json')
        before=compile_motion(folder/'director_motion.json',name,layouts,compiled['projection'])
        if any('limit_deg' in c.get('held_follow',{}) for c in before['clips'].values()):errors.append(name+': unexpected optional field')
    follow={'item':'staff','grip':'hand_far','deg_per_px':.25,'lag_s':.1,'limit_deg':6,'reference_frame':'body'}
    validate({'held_follow':follow,'gait':{}},{'held_items':{'staff':{'hand':'hand_far'}}},'move')
    if angle(follow,100,1)!=6 or angle(follow,100,-1)!=-6:errors.append('held-follow limit')
    for value in (-1,float('inf'),'6'):
        try:validate({'held_follow':dict(follow,limit_deg=value),'gait':{}},{'held_items':{'staff':{'hand':'hand_far'}}},'move')
        except ValueError:pass
        else:errors.append('invalid optional limit accepted')
    return {'ok':not errors,'errors':errors,'earlier_production_assets_byte_identical':not any(not p.startswith('assets/units/storm_cantor_cutout/') for p in changes)}

def run(samples_path):
    samples=read_json(samples_path);data=read_json(CASE/'compiled_motion.json');build=read_json(CASE/'proof/build.json');bound=bindings(CASE)
    report={'native_pixels':False,'art':art_report(),'views':{},'budget_clamps':data.get('budget_clamps',[]),'earlier_rigs':earlier_byte_identity()}
    errors=[]
    for view in VIEWS:
        layout=read_json(CASE/f'layouts/{view}.json')
        row={'structure':{'errors':structure_errors(layout,build["views"][view])},'elbow':elbows(layout,data,samples),
             'reach':reach(layout,data,step_distance_px=samples['step_distance_px'],screen_pixel_scale=samples['screen_pixel_scale']),
             'walk':walk(layout,data,samples),'supports':support_report(layout,data,samples),
             'signed_direction':direction(layout,data,samples,bound,require_presented=True),'attachments':attachments(layout,data,samples)}
        report['views'][view]=row
        for name,result in row.items():
            result['ok']=not result['errors'];errors+=result['errors']
            print(f'RR56 {name.upper()} {view}: {"PASS" if result["ok"] else "FAIL"} ({len(result["errors"])} errors)',flush=True)
    from humanoid_cutout.stable_paint import geometry_errors
    raster=read_json(CASE/'proof/raster_samples.json')
    geometry=[]
    layouts_geometry={v:read_json(CASE/f'layouts/{v}.json') for v in VIEWS}
    for sample in raster['samples']:
        layout=layouts_geometry[sample['view']]
        if layout.get('stable_source_raster'):geometry+=geometry_errors(layout,sample)
    report['submitted_geometry']={'errors':geometry,'frames':len(raster['samples'])}
    errors+=geometry
    errors+=report['earlier_rigs']['errors']
    report['errors']=errors;report['ok']=not errors;report['native_status']='PENDING director windowed proof; CPU calibration cannot pass until native exists'
    write_json(CASE/'proof/checks.json',report)
    print(f'RR56 FOCUSED CHECKS: {"PASS" if not errors else "FINDINGS"} ({len(errors)} errors)')
    for error in errors[:15]:print(error)
    return not errors

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--samples',type=Path,default=CASE/'proof/samples.json');a=p.parse_args();raise SystemExit(0 if run(a.samples) else 1)
