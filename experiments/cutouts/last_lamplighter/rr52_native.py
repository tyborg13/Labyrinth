"""Director-run fail-closed native gates and CPU/native superset calibration."""
import argparse
from pathlib import Path
import numpy as np
from rr52_build import CASE
from rr52_surface import NativeSurface,SurfacePolicy
from rr52_native_floor import native_floor_errors
from cutout_pipeline.cases import read_json,write_json,digest
from humanoid_cutout.gates import native_errors,clean_metrics
from humanoid_cutout.native_frames import load_frame
from maquette_motion.material_palette import rules
from maquette_motion.silhouette import holes,components


def calibrate(case,capture):
    from humanoid_cutout.cpu_pose import CpuPose,mask_mesh
    from humanoid_cutout.canvas import for_case
    from rr52_joint_budget import pose_layers
    from humanoid_cutout.anatomy import load
    from humanoid_cutout.held_release import ComponentPolicy
    from humanoid_cutout.source_space import DetachedSource,pocket_report
    from humanoid_cutout.silhouette_gates import posed_owners,joint_holes
    from maquette_motion import pixels
    samples=read_json(case/'proof/raster_samples.json');motion=read_json(case/'compiled_motion.json');manifest=read_json(capture/'frames.json');errors=[];groups={};checks=0
    for row in manifest['pieces']:groups.setdefault((row['view'],row['clip'],row['frame']),[]).append(row)
    index={(r['view'],r['clip'],r['frame']):r for r in samples['samples']}
    with for_case(case):
        for view in ('front','rear'):
            layout=read_json(case/f'layouts/{view}.json');model=CpuPose(case,layout,native_skin=True,triangle_batch_size=128)
            for name,mesh in model.meshes.items():
                selected=mask_mesh(mesh,model.image(next(p['file'] for p in layout['parts'] if p['name']==name))[...,3]>0)
                if selected['triangles']:model.meshes[name]=selected
            parts={p['name']:p for p in layout['parts']};surface=SurfacePolicy(model)
            baseline=np.asarray(load_frame(case/layout['rest_source']).convert('RGBA'))[...,3]>0
            anatomy=load(case);release_policy=ComponentPolicy(anatomy,motion,layout,len(components(baseline,8)[1]))
            source_policy=DetachedSource(case,layout)
            for key,rows in groups.items():
                if key[0]!=view:continue
                if key not in index:errors.append(f'{key}: missing CPU frame');continue
                layers=[(parts[r['name']],np.asarray(load_frame(capture/r['file']).convert('RGBA')),np.asarray(load_frame(capture/r['checks']).convert('RGBA'))) for r in rows]
                prediction,maps=pose_layers(model,index[key],motion)
                native=clean_metrics(layers,rules(case,view));predicted=clean_metrics(prediction,rules(case,view))
                occupied=np.logical_or.reduce([im[...,3]>0 for _,im,_ in layers]);cpu_occupied=np.logical_or.reduce([im[...,3]>0 for _,im,_ in prediction])
                native_release=release_policy.report(occupied,layers,key[1],index[key]['phase'])
                cpu_release=release_policy.report(cpu_occupied,prediction,key[1],index[key]['phase'])
                transforms={name:part['transform'] for name,part in index[key]['parts'].items()}
                # The legacy tiny/dark outline allowance cannot certify a
                # detached component. Calibrate the same strict provenance
                # and declared release used by the native and CPU gates.
                native.update(source_policy.report(layers,transforms,native_release['masks'])['metrics'])
                predicted.update(source_policy.report(prediction,transforms,cpu_release['masks'])['metrics'])
                if len(cpu_release['errors'])<len(native_release['errors']):errors.append(f'{key}: CPU missed native held-release/component finding')
                native_space=surface.space(occupied,index[key]);cpu_space=surface.space(cpu_occupied,index[key])
                native=surface.metrics(layers,index[key],maps,native=True)|{'stray_components':native['stray_components'],'stray_pixels':native['stray_pixels']}
                predicted=surface.metrics(prediction,index[key],maps)|{'stray_components':predicted['stray_components'],'stray_pixels':predicted['stray_pixels']}
                for finding in native_space['failures']:
                    b=finding['bbox']
                    if not any(p['bbox'][0]<=b[0] and p['bbox'][1]<=b[1] and p['bbox'][2]>=b[2] and p['bbox'][3]>=b[3] and p['pixel_count']>=finding['pixel_count'] for p in cpu_space['failures']):errors.append(f'{key}: CPU missed native source-space tear {b}')
                for metric in ('outside_pixels','exposed_outline_pixels','dark_slab_blocks',
                               'outline_outside_pixels','stray_components','stray_pixels'):
                    if predicted.get(metric,0)<native.get(metric,0):errors.append(f'{key}/{metric}: CPU {predicted.get(metric,0)} < native {native.get(metric,0)}')
                # Painted-pocket coverage was compared above. A native pocket
                # mapping only to director-underlay air is correct background,
                # not a missing CPU blocker (feedback 2: eighteen such cases).
                checks+=1
    return {'ok':not errors,'errors':errors,'checks':checks,'cpu_samples_sha256':digest(case/'proof/raster_samples.json'),'native_sha256':digest(capture/'frames.json')}


def run(case,capture):
    errors=native_errors(case,capture,surface_policy_factory=lambda c,l:NativeSurface(c,l,capture));floor=native_floor_errors(case,capture);errors+=floor['errors'];calibration=calibrate(case,capture);errors+=calibration['errors']
    report={'ok':not errors,'errors':errors,'painted_floor':floor,'cpu_superset_native':calibration,'native_pixels':True}
    write_json(case/'proof/native_gates.json',report)
    print(f'RR52 NATIVE GATES: {"FAIL" if errors else "PASS"} ({len(errors)} errors)')
    for e in errors[:30]:print(e)
    return not errors

if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--case',type=Path,default=CASE);p.add_argument('--native',type=Path,required=True);a=p.parse_args();raise SystemExit(int(not run(a.case,a.native)))
