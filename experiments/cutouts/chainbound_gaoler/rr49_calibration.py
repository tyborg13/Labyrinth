"""Headless replay of all 52 final rr-44 findings, before changing the rig.

Native isolated RGBA is immutable input to the exact-source oracle; idle is
also independently reproduced from CPU-skinned groups. No current capture or
ignored report is an input. This is calibration, never fresh renderer proof.
"""
import argparse
from contextlib import contextmanager
import gzip
import json
from pathlib import Path
import tarfile
import tempfile
import numpy as np
from rr49_fixture import FIXTURE
from cutout_pipeline.cases import read_json, write_json, digest
from humanoid_cutout.cpu_pose import CpuPose
from humanoid_cutout.canvas import for_case
from humanoid_cutout.gates import idle_pixel_errors
from humanoid_cutout.native_frames import load_frame
from rr42_raster import pose_for_raster
from rr44_native_exact import rgba_errors

FIXTURE_SHA256 = 'b623f59da8e6507ee68f44bd828d37fdb36049442d7f6418f683f056981dcf68'


@contextmanager
def frozen(fixture=FIXTURE):
    if digest(fixture/'manifest.json') != FIXTURE_SHA256: raise ValueError('Changed rr49 native fixture manifest')
    for name, sha in read_json(fixture/'manifest.json')['files'].items():
        if digest(fixture/name) != sha: raise ValueError('Changed rr49 native fixture: '+name)
    with tempfile.TemporaryDirectory(prefix='rr49-native-replay-') as folder:
        case=Path(folder).resolve()
        with tarfile.open(fixture/'case.tar.gz') as bundle:
            for entry in bundle.getmembers():
                target=case/entry.name;target.resolve().relative_to(case)
                target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(bundle.extractfile(entry).read())
        truth=read_json(fixture/'truth.json')
        for name,sha in truth['source_files'].items():
            if digest(case/name)!=sha: raise ValueError('Changed rr49 frozen source: '+name)
        poses=json.loads(gzip.decompress((fixture/'poses.json.gz').read_bytes()))
        yield case,truth,poses


def group(layers,names):
    result=np.zeros_like(layers[0][1])
    for part,image,_ in sorted(layers,key=lambda r:r[0]['z_index']):
        if part['logical_part'] in names:
            mask=image[...,3]>0;result[mask]=image[mask]
    return result


def valid(result):
    rows=result.get('findings',[])
    return (result.get('ok') is True and result.get('fixture_sha256')==FIXTURE_SHA256 and
            len(rows)==52 and all(r.get('observed') for r in rows) and
            {kind:sum(r.get('kind')==kind for r in rows) for kind in ('source','idle','released')}==
            dict(source=24,idle=24,released=4))


def replay(fixture=FIXTURE):
    results=[]
    with frozen(fixture) as (case,truth,rows),for_case(case):
        poses={(r['view'],r['clip'],r['frame']):pose_for_raster(r) for r in rows}
        models={v:CpuPose(case,read_json(case/f'layouts/{v}.json'),native_skin=True,triangle_batch_size=128) for v in ('front','rear')}
        idle={}
        for view,model in models.items():
            idle[view]={f:model.layers(poses[view,'idle',f])[0] for f in (0,6)}
        for witness in truth['witnesses']:
            view,frame=witness['view'],witness['frame'];model=models[view];kind=witness['kind']
            if kind=='idle':
                names=model.layout['idle_groups'][witness['group']]
                count=idle_pixel_errors(group(idle[view][0],names),group(idle[view][6],names),witness['offset'])
                native=idle_pixel_errors(np.asarray(load_frame(fixture/witness['rest'])),np.asarray(load_frame(fixture/witness['file'])),witness['offset'])
                observed=count==native==witness['pixels'] and count>0
            else:
                part=next(p for p in model.layout['parts'] if p['name']==witness['name'])
                actual=np.asarray(load_frame(fixture/witness['file']).convert('RGBA'))
                count=sum(r['pixels'] for r in rgba_errors(model,poses[view,witness['clip'],frame],[(part,actual,None)]))
                observed=count>0
            results.append(dict(kind=kind,view=view,clip=witness.get('clip','idle'),frame=frame,
                                part=witness.get('name',witness.get('group')),pixels=count,observed=observed))
    return dict(ok=all(r['observed'] for r in results) and len(results)==52,findings=results,
                fixture_sha256=FIXTURE_SHA256,native_pixels=False,
                scope='Immutable native exact-source replay plus independent CPU idle-group raster; fresh native still required')


if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--output',type=Path);a=p.parse_args()
    result=replay()
    if a.output:write_json(a.output,result)
    print(f'RR49 FINAL-NATIVE CALIBRATION: {"PASS" if result["ok"] else "FAIL"} ({sum(r["observed"] for r in result["findings"])}/52 findings; CPU idle + exact-source replay)')
    raise SystemExit(not result['ok'])
