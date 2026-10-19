"""Headless rigid-sprite seam/stray checks; native renderer proof stays separate."""
import numpy as np
from PIL import Image
from rr18_case import CASE
from cutout_pipeline.cases import read_json, write_json
from humanoid_cutout.cpu_pose import CpuPose, sprite_transform
from humanoid_cutout.gates import bindings, clean_metrics
from humanoid_cutout.silhouette_gates import posed_owners, joint_holes
from humanoid_cutout.anatomy import load
from humanoid_cutout.rigid_air import for_case
from maquette_motion.pixels import PROOF_DEFAULTS

PROGRESS_INTERVAL_FRAMES = 50  # Existing Thrall diagnostic cadence.
CROP_PADDING_PX = 8  # Diagnostic context only.
CROP_ZOOM = 3  # Shared native failure-crop zoom.


def frame_report(model, pose):
    layers,maps = model.layers(pose)
    owners = posed_owners(layers,model.layout['parts'],pose['bones'],PROOF_DEFAULTS['source_offset'])
    if not hasattr(model,'air_policy'):
        model.air_policy = for_case(model.case,model.layout,load(model.case))
    if model.air_policy is not None:
        transforms = {}
        for part in model.layout['parts']:
            t = sprite_transform(model.layout,pose,part)
            transforms[part['name']] = [t[0,0],t[1,0],t[0,1],t[1,1],t[0,2],t[1,2]]
        return layers,model.air_policy.report(owners>0,owners,transforms)
    seams = model.masks(pose,model.layout['proof_joint_seams'],maps)
    references = model.masks(pose,model.layout['proof_rest_holes'],maps)
    defects = joint_holes(owners>0,np.logical_or.reduce(seams),owners,references,pocket_details=True)
    return layers,{'failures':defects,'air_pockets':[]}


def frame_state(model, pose):
    layers,result = frame_report(model,pose)
    return layers,result['failures']


def report(layout,samples,save_failures=False):
    if layout['joint_meshes']: raise ValueError('Rigid-only diagnostic cannot accept skinned meshes')
    view=layout['facing']; model=CpuPose(CASE,layout)
    errors,failures,air=[],[],[]
    rows=[r for r in samples['samples'] if r['view']==view and r['kind']=='presented']
    for index,pose in enumerate(rows):
        layers,pockets=frame_report(model,pose)
        holes=pockets['failures']
        if pockets['air_pockets']:
            air.append({'clip':pose['clip'],'frame':pose['frame'],'count':len(pockets['air_pockets']),
                        'pixels':sum(h['pixel_count'] for h in pockets['air_pockets'])})
        metrics=clean_metrics(layers)
        rejected={k:metrics[k] for k in ('outside_pixels','exposed_outline_pixels','dark_slab_blocks','outline_outside_pixels','stray_components') if metrics[k]}
        if holes or rejected:
            label=f'{view}/{pose["clip"]}/frame {pose["frame"]}'
            summary=[{k:h[k] for k in ('bbox','pixel_count','stone_pixels') if k in h} for h in holes]
            errors.append(f'{label}: seam holes {summary}; clean-piece defects {rejected}')
            failures.append({'clip':pose['clip'],'frame':pose['frame'],'holes':holes,'metrics':rejected})
            if save_failures:
                composite=Image.new('RGBA',(PROOF_DEFAULTS['canvas_size'],)*2)
                for part,image,_ in sorted(layers,key=lambda r:r[0]['z_index']): composite.alpha_composite(Image.fromarray(image))
                path=CASE/f'proof/seam_cpu/{view}_{pose["clip"]}_{pose["frame"]:04d}.png'
                path.parent.mkdir(parents=True,exist_ok=True);composite.save(path)
                for pocket_index,hole in enumerate(holes):
                    bounds=hole['bbox'];padding=CROP_PADDING_PX
                    crop_bounds=[max(0,bounds[0]-padding),max(0,bounds[1]-padding),
                                 min(composite.width,bounds[2]+padding),min(composite.height,bounds[3]+padding)]
                    crop=composite.crop(crop_bounds)
                    target=path.with_name(path.stem+f'_pocket_{pocket_index:02d}.png')
                    crop.resize((crop.width*CROP_ZOOM,crop.height*CROP_ZOOM),Image.Resampling.NEAREST).save(target)
                    hole['crop']=str(target.relative_to(CASE))
                    hole['crop_bounds']=crop_bounds
        if (index+1)%PROGRESS_INTERVAL_FRAMES==0:
            print(f'RR18 {view.upper()} RIGID SEAMS: {index+1} frames; {len(failures)} failures',flush=True)
    if not rows:errors.append(view+': missing presented rigid seam evidence')
    return {'ok':not errors,'errors':errors,'frames':len(rows),'failures':failures,'air_pockets':air,'native_pixels':False,
            'seam_policy':load(CASE).get('seam_policy','strict'),
            'scope':'headless rigid raster and calibrated joint-hole diagnostics; director native capture still required'}


if __name__=='__main__':
    samples=read_json(CASE/'proof/samples.json'); current=bindings(CASE)
    if samples['inputs']!=current:raise ValueError('Refresh samples before seam diagnostics')
    result={view:report(read_json(CASE/f'layouts/{view}.json'),samples,True) for view in ('front','rear')}
    write_json(CASE/'proof/seams.json',result)
    for view,r in result.items():print(f'RR18 {view.upper()} RIGID SEAM/CLEAN GATES: {"PASS" if r["ok"] else "FAIL"} ({r["frames"]} frames; {len(r["errors"])} errors)')
    raise SystemExit(int(any(not r['ok'] for r in result.values())))
