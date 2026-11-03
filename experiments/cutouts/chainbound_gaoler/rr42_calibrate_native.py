"""Hash-bound native regression: exact source RGBA, no changed-pixel allowance."""
import argparse
from pathlib import Path
from types import SimpleNamespace
import numpy as np
from PIL import Image
from rr42_retained import FIXTURE,FIXTURE_MANIFEST_SHA256
from rr42_underlay import CASE
from rr42_raster import rigid
from cutout_pipeline.cases import read_json,write_json,digest
from humanoid_cutout.cpu_pose import mesh_map,mapped
from humanoid_cutout.canvas import for_case
from humanoid_cutout.gait_continuations import texture


def load():
    if digest(FIXTURE/'manifest.json')!=FIXTURE_MANIFEST_SHA256:raise ValueError('Changed native fixture manifest')
    data=read_json(FIXTURE/'manifest.json')
    if digest(FIXTURE/'geometry.json')!=data['geometry_sha256']:raise ValueError('Changed native fixture geometry')
    for row in data['pieces']:
        if digest(FIXTURE/row['retained_file'])!=row['sha256']:raise ValueError('Changed retained native pixels')
    for row in data['source_images'].values():
        if digest(FIXTURE/row['file'])!=row['sha256']:raise ValueError('Changed retained source paint')
    return data,read_json(FIXTURE/'geometry.json')


def candidates(data,layout,row,*,canonical=False):
    part=next(p for p in layout['parts'] if p['name']==row['name'])
    inventories=[data['canonical_poses']] if canonical else [data['native_origin_poses'],data['canonical_poses']]
    # Replay the unchanged approved clip recipe as well as its raw source.
    # No new pixels are generated: every recipe copies its own retained donor.
    remapped=dict(layout,parts=[dict(p,file=data['source_images'][p['name']]['file']) for p in layout['parts']])
    source_part=next(p for p in remapped['parts'] if p['name']==row['name'])
    image=texture(FIXTURE,remapped,source_part,gait=row['clip']=='move',clip=row['clip'])
    mesh=next((m for m in layout['joint_meshes'] if m['name']==row['name']),None)
    families=[]
    with for_case(CASE):
        for inventory in inventories:
            pose=next(r for r in inventory if (r['clip'],r['frame'])==(row['clip'],row['frame']))
            for packed in ((True,False) if mesh else (True,)):
                family=(rigid(image,layout,pose,part,with_ties=True) if mesh is None else
                        mapped(image,mesh_map(layout,pose,mesh,native_skin=packed,with_ties=True,triangle_batch_size=128),with_ties=True))
                families.append(family)
    return SimpleNamespace(default=families[0].default,candidates=tuple(c for f in families for c in f.candidates))


def unmatched(actual,family):
    return ~np.logical_or.reduce([(a[...,3]==actual[...,3])&((actual[...,3]==0)|np.all(a==actual,axis=-1))
                                  for a in family.candidates])


def run():
    data,layout=load();rows=[]
    for row in data['pieces']:
        actual=np.asarray(Image.open(FIXTURE/row['retained_file']).convert('RGBA'))
        family=candidates(data,layout,row)
        result=dict(clip=row['clip'],frame=row['frame'],part=row['name'],unexplained_pixels=int(unmatched(actual,family).sum()),
                    default_pixel_differences=int(np.any(actual!=family.default,axis=-1).sum()),
                    native_sha256=row['sha256'])
        rows.append(result)
    ok=all(r['unexplained_pixels']==0 for r in rows)
    held=[r for r in rows if r['frame']==95]
    ok=ok and all(r['default_pixel_differences']==0 for r in held)
    result=dict(ok=ok,native_pixels=True,retained=True,fixture_sha256=digest(FIXTURE/'manifest.json'),
                frames=rows,rule='exact source RGBA or real adjacent nearest-UV texel; no pixel-count allowance')
    write_json(CASE/'proof/feedback2_calibration.json',result)
    print('RR42 NATIVE CALIBRATION: %s (%d retained layers; 0 unexplained required; frame95 exact=%s)'%
          ('PASS' if ok else 'FAIL',len(rows),all(r['default_pixel_differences']==0 for r in held)))
    return result


if __name__=='__main__':raise SystemExit(not run()['ok'])
