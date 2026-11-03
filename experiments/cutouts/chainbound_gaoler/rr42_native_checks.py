"""Bind native front pixels to the all-rounding painted exposure proof.

The CPU gate covers every independent per-layer nearest-UV choice. A native
layer must match one of those exact RGBA candidates at every texel, so an
uncalibrated renderer path cannot inherit the CPU certificate.
"""
import argparse
from pathlib import Path
import numpy as np
from rr42_underlay import CASE
from rr42_exposure import PaintedExposure
from cutout_pipeline.cases import read_json,write_json,digest
from humanoid_cutout.cpu_pose import CpuPose,mesh_map,mapped,sprite_transform
from humanoid_cutout.gait_continuations import texture
from humanoid_cutout.canvas import for_case
from humanoid_cutout.gates import bindings
from humanoid_cutout.native_frames import load_frame,frame_digest
from maquette_motion import pixels
from rr42_raster import pose_families,rigid


def report(case,capture):
    manifest=read_json(capture/'frames.json')
    if not manifest.get('native_pixels'):
        raise ValueError('Missing/stale native capture')
    if manifest.get('inputs')!=bindings(case):
        from rr42_retained import verify
        verify(manifest['inputs'],bindings(case),capture)
    from rr42_native_cache import key as cache_bindings,positive
    cache_key=cache_bindings(case,capture);cached=positive(case,capture,manifest,cache_key)
    if cached is not None:return cached
    model=CpuPose(case,read_json(case/'layouts/front.json'),native_skin=True,triangle_batch_size=128)
    parts={p['name']:p for p in model.layout['parts']};painted=PaintedExposure(model)
    poses={(p['clip'],p['frame']):p for p in read_json(case/'proof/logs/samples.json')['samples'] if p['view']=='front' and p['kind']=='presented'}
    inventory={}
    for row in manifest['pieces']:
        if row['view']=='front': inventory.setdefault((row['clip'],row['frame']),[]).append(row)
    errors=[];rows=[]
    if set(inventory)!=set(poses): raise ValueError('Incomplete native front frame inventory')
    with for_case(case):
        for key,pose in poses.items():
            layers=inventory[key]
            if {r['name'] for r in layers}!=set(parts) or len(layers)!=len(parts): raise ValueError('Incomplete native layer inventory')
            for row in layers:
                path=capture/row['file']
                if frame_digest(path)!=row['sha256']:raise ValueError('Changed native layer')
                actual=np.asarray(load_frame(path).convert('RGBA'));part=parts[row['name']]
                source=texture(case,model.layout,part,gait=pose['clip']=='move',clip=pose['clip'])
                matched=np.zeros(actual.shape[:2],bool)
                for context in pose_families(pose):
                    for packed in ((True,False) if part['name'] in model.meshes else (True,)):
                        if part['name'] in model.meshes:
                            mapping=mesh_map(model.layout,context,model.meshes[part['name']],with_ties=True,native_skin=packed,triangle_batch_size=128)
                            candidates=mapped(source,mapping,with_ties=True).candidates
                        else:
                            candidates=rigid(source,model.layout,context,part,with_ties=True).candidates
                        for candidate in candidates:
                            matched |= (candidate[...,3]==actual[...,3]) & ((actual[...,3]==0)|np.all(candidate==actual,axis=-1))
                if not matched.all():errors.append(f'{key}/{part["name"]}: {int((~matched).sum())} native pixels outside calibrated rounding families')
            metrics=painted.measure(pose)
            rows.append({'clip':key[0],'frame':key[1],'metrics':metrics})
            if any(metrics.values()):errors.append(str(key)+': painted exposure '+str(metrics))
    result={'ok':not errors,'native_pixels':True,'errors':errors,'frames':rows,'manifest_sha256':digest(capture/'frames.json')}
    if cache_bindings(case,capture)!=cache_key:raise ValueError('Native proof inputs changed during evaluation')
    result['cache_key']=cache_key
    write_json(case/'proof/logs/rr42_native_paint.json',result)
    return result


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--case',type=Path,default=CASE/'proof/production_case');parser.add_argument('--native',type=Path,required=True)
    args=parser.parse_args();result=report(args.case,args.native)
    print('RR42 NATIVE PAINTED EXPOSURE: %s (%d errors)'%('PASS' if result['ok'] else 'FAIL',len(result['errors'])))
    raise SystemExit(not result['ok'])
