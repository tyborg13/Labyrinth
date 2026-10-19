"""Headless rigid-sprite seam/stray checks; native renderer proof stays separate."""
import numpy as np
from PIL import Image
from rr18_case import CASE
from cutout_pipeline.cases import read_json, write_json
from humanoid_cutout.cpu_pose import CpuPose, sprite_transform
from humanoid_cutout.gates import bindings, clean_metrics
from humanoid_cutout.silhouette_gates import posed_owners, joint_holes
from humanoid_cutout.anatomy import load, owner_ids
from maquette_motion.silhouette import holes as alpha_holes, dilate
from maquette_motion.pixels import PROOF_DEFAULTS

PROGRESS_INTERVAL_FRAMES = 50  # Existing Thrall diagnostic cadence.


def frame_state(model, pose):
    layers,maps = model.layers(pose)
    seams = model.masks(pose,model.layout['proof_joint_seams'],maps)
    references = model.masks(pose,model.layout['proof_rest_holes'],maps)
    seam = np.logical_or.reduce(seams)
    owners = posed_owners(layers,model.layout['parts'],pose['bones'],PROOF_DEFAULTS['source_offset'])
    holes = joint_holes(owners>0,seam,owners,references,pocket_details=True)
    return layers,holes


def source_gap_trace(model,pose,layers,defects):
    """Locate diagnosed gaps in the approved source; never waive a defect."""
    anatomy=load(CASE);ownership=anatomy['ownership'];ids=owner_ids(ownership)
    owners=posed_owners(layers,model.layout['parts'],pose['bones'],PROOF_DEFAULTS['source_offset'])
    source=np.asarray(Image.open(CASE/model.layout['rest_source']).convert('RGBA'))
    candidates=alpha_holes(owners>0)
    result=[]
    for defect in defects:
        left,top,right,bottom=defect['bbox']
        hole=next(h for h in candidates if int(h.sum())==defect['pixel_count'] and int(h[top:bottom,left:right].sum())==defect['pixel_count'])
        boundary=owners[dilate(hole,1)&(owners>0)]
        pair=max(ownership['joint_pairs'],key=lambda p:int(np.count_nonzero((boundary==ids[p[0]])|(boundary==ids[p[1]]))))
        ys,xs=np.nonzero(hole)
        points=np.column_stack((xs+.5-PROOF_DEFAULTS['source_offset'],ys+.5-PROOF_DEFAULTS['source_offset'],np.ones(len(xs))))
        traces={}
        for name in pair:
            part=next(p for p in model.layout['parts'] if p['name']==name)
            local=points@np.linalg.inv(sprite_transform(model.layout,pose,part)).T
            pixels=np.rint(local[:,:2].astype(np.float32)-.5).astype(int)+np.asarray(part['offset'])
            valid=(pixels[:,0]>=0)&(pixels[:,0]<source.shape[1])&(pixels[:,1]>=0)&(pixels[:,1]<source.shape[0])
            transparent=np.ones(len(pixels),dtype=bool)
            transparent[valid]=source[pixels[valid,1],pixels[valid,0],3]==0
            traces[name]={'source_points':pixels.tolist(),'transparent_source_pixels':int(transparent.sum()),'all_transparent':bool(transparent.all())}
        result.append(dict(defect,joint_pair=pair,source=traces))
    return result


def report(layout,samples,save_failures=False):
    if layout['joint_meshes']: raise ValueError('Rigid-only diagnostic cannot accept skinned meshes')
    view=layout['facing']; model=CpuPose(CASE,layout)
    errors,failures=[],[]
    rows=[r for r in samples['samples'] if r['view']==view and r['kind']=='presented']
    for index,pose in enumerate(rows):
        layers,holes=frame_state(model,pose)
        metrics=clean_metrics(layers)
        rejected={k:metrics[k] for k in ('outside_pixels','exposed_outline_pixels','dark_slab_blocks','outline_outside_pixels','stray_components') if metrics[k]}
        if holes or rejected:
            label=f'{view}/{pose["clip"]}/frame {pose["frame"]}'
            errors.append(f'{label}: seam holes {holes}; clean-piece defects {rejected}')
            failures.append({'clip':pose['clip'],'frame':pose['frame'],'holes':holes,'metrics':rejected,'source_gap_trace':source_gap_trace(model,pose,layers,holes)})
            if save_failures:
                composite=Image.new('RGBA',(PROOF_DEFAULTS['canvas_size'],)*2)
                for part,image,_ in sorted(layers,key=lambda r:r[0]['z_index']): composite.alpha_composite(Image.fromarray(image))
                path=CASE/f'proof/seam_cpu/{view}_{pose["clip"]}_{pose["frame"]:04d}.png'
                path.parent.mkdir(parents=True,exist_ok=True);composite.save(path)
        if (index+1)%PROGRESS_INTERVAL_FRAMES==0:
            print(f'RR18 {view.upper()} RIGID SEAMS: {index+1} frames; {len(failures)} failures',flush=True)
    if not rows:errors.append(view+': missing presented rigid seam evidence')
    return {'ok':not errors,'errors':errors,'frames':len(rows),'failures':failures,'native_pixels':False,
            'scope':'headless rigid raster and calibrated joint-hole diagnostics; director native capture still required'}


if __name__=='__main__':
    samples=read_json(CASE/'proof/samples.json'); current=bindings(CASE)
    if samples['inputs']!=current:raise ValueError('Refresh samples before seam diagnostics')
    result={view:report(read_json(CASE/f'layouts/{view}.json'),samples,True) for view in ('front','rear')}
    write_json(CASE/'proof/seams.json',result)
    for view,r in result.items():print(f'RR18 {view.upper()} RIGID SEAM/CLEAN GATES: {"PASS" if r["ok"] else "FAIL"} ({r["frames"]} frames; {len(r["errors"])} errors)')
    raise SystemExit(int(any(not r['ok'] for r in result.values())))
