"""Bounded exact native source-RGBA proof for painted backing and joint caps."""
import argparse
from pathlib import Path
import numpy as np
from rr44_case import CASE
from rr42_raster import pose_for_raster,rigid
from cutout_pipeline.cases import read_json,write_json,digest
from humanoid_cutout.cpu_pose import CpuPose,mesh_map,mapped
from humanoid_cutout.canvas import for_case
from humanoid_cutout.gates import bindings
from humanoid_cutout.gait_continuations import texture
from humanoid_cutout.native_frames import load_frame,frame_digest
from maquette_motion import pixels,native_ties


def implementation():
    from rr51_acceptance import bound_inputs
    return {**{name:digest(CASE.parent/name) for name in ('rr44_native_exact.py','rr44_flat.py','rr44_authority.py','rr44_continuations.py','rr44_exposure.py','rr44_surface_policy.py','rr38_uncovered.py','rr42_raster.py','rr49_checks.py','rr49_calibration.py')},
            **bound_inputs()}


def rgba_errors(model,pose,layers):
    errors=[]
    for part,actual,_ in layers:
        name=part['name']
        source=texture(model.case,model.layout,part,gait=pose['clip']=='move',clip=pose['clip'])
        legal=np.zeros(actual.shape[:2],bool)
        if name in model.meshes:
            families=[mapped(source,mesh_map(model.layout,pose,model.meshes[name],with_ties=True,native_skin=native,triangle_batch_size=128),with_ties=True) for native in (False,True)]
        else:families=[rigid(source,model.layout,pose,part,with_ties=True)]
        for candidates in families:
            selected,_=native_ties.select(actual,candidates)
            legal|=~pixels.changed(actual,selected)
        if not legal.all():errors.append(dict(part=name,pixels=int((~legal).sum()),locations=np.argwhere(~legal)[:,::-1].tolist()))
    return errors


def shard(case,capture,view,clip,start,count):
    manifest=read_json(capture/'frames.json');sample=case/'proof/logs/samples.json'
    poses={(r['view'],r['clip'],r['frame']):pose_for_raster(r) for r in read_json(sample)['samples'] if r['kind']=='presented'}
    layout=read_json(case/f'layouts/{view}.json');parts={p['name']:p for p in layout['parts']};model=CpuPose(case,layout,native_skin=True,triangle_batch_size=128);rows=[]
    from rr44_diagnostics import Diagnostics
    from rr44_flat import regions as flat_regions
    # rr-51: the same director-accepted 1.10 move flat inventory as the CPU sweep.
    from rr51_acceptance import flat_errors
    diagnostic=Diagnostics(case,model)
    with for_case(case):
        for frame in range(start,min(start+count,round(read_json(case/'compiled_motion.json')['clips'][clip]['seconds']*60))):
            layers=[]
            for row in manifest['pieces']:
                if (row['view'],row['clip'],row['frame'])!=(view,clip,frame):continue
                if frame_digest(capture/row['file'])!=row['sha256']:raise ValueError('Changed native source layer')
                layers.append((dict(parts[row['name']],z_index=row['z_index']),np.asarray(load_frame(capture/row['file']).convert('RGBA')),None))
            if {p['name'] for p,_,_ in layers}!=set(parts):raise ValueError('Missing native source layers')
            pose=poses[view,clip,frame];flats=flat_regions(diagnostic.surface,pose,layers)
            violations=flat_errors(flats,render_mode='native')
            errors=rgba_errors(model,pose,layers)+[dict(flat_ratchet=r) for r in violations]
            if layout.get('stable_source_raster'):
                from humanoid_cutout.stable_paint import geometry_errors
                submitted={}
                for row in manifest['pieces']:
                    if (row['view'],row['clip'],row['frame'])==(view,clip,frame):submitted.update(row.get('submitted_geometry',{}))
                errors += [dict(submitted_geometry=e) for e in geometry_errors(layout,dict(pose,stable_geometry=submitted))]
            rows.append(dict(view=view,clip=clip,frame=frame,errors=errors,flat_regions=flats,flat_ratchet_errors=violations))
    write_json(case/f'proof/logs/rr44_native_exact/{view}_{clip}_{start:03d}.json',dict(inputs=bindings(case),implementation=implementation(),capture_sha256=digest(capture/'frames.json'),samples_sha256=digest(sample),frames=rows))
    print(f'RR44 NATIVE EXACT SHARD: {view}/{clip}/{start}; {sum(bool(r["errors"]) for r in rows)} failures')


def merge(case,capture):
    manifest=read_json(capture/'frames.json');current=bindings(case)
    if not manifest.get('native_pixels') or manifest['inputs']!=current:raise ValueError('Stale native source proof')
    frames=[];data=read_json(case/'compiled_motion.json');capture_sha=digest(capture/'frames.json');samples_sha=digest(case/'proof/logs/samples.json')
    for view in data['view_tracks']:
        for clip,definition in data['clips'].items():
            for start in range(0,round(definition['seconds']*60),4):
                row=read_json(case/f'proof/logs/rr44_native_exact/{view}_{clip}_{start:03d}.json')
                if row['inputs']!=current or row['implementation']!=implementation() or row['capture_sha256']!=capture_sha or row['samples_sha256']!=samples_sha:raise ValueError('Stale native exact shard')
                frames+=row['frames']
    errors=[r for r in frames if r['errors']];result=dict(ok=not errors,inputs=current,implementation=implementation(),capture_sha256=capture_sha,frames=frames,errors=errors,native_pixels=True)
    from rr44_sweep import coverage_errors
    missing=coverage_errors(data,frames)
    if missing:raise ValueError('; '.join(missing))
    write_json(case/'proof/logs/rr44_native_exact.json',result)
    print(f'RR44 NATIVE EXACT SOURCE: {"PASS" if not errors else "FAIL"} ({len(frames)} frames; {len(errors)} failing frames)')
    return result


if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--case',type=Path,default=CASE/'proof/production_case');p.add_argument('--capture',type=Path,required=True)
    p.add_argument('--plan',action='store_true');p.add_argument('--merge',action='store_true');p.add_argument('--view');p.add_argument('--clip');p.add_argument('--start',type=int);p.add_argument('--count',type=int,default=4)
    a=p.parse_args()
    if a.plan:
        data=read_json(a.case/'compiled_motion.json')
        for view in data['view_tracks']:
            for clip,definition in data['clips'].items():
                for start in range(0,round(definition['seconds']*60),4):print(f'python3 -B {__file__} --case {a.case} --capture {a.capture} --view {view} --clip {clip} --start {start}')
    elif a.merge:raise SystemExit(not merge(a.case,a.capture)['ok'])
    else:
        if not 1<=a.count<=4:p.error('At most four frames per bounded process')
        shard(a.case,a.capture,a.view,a.clip,a.start,a.count)
