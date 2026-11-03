"""Fresh replay of immutable round-0 poses in bounded CPU diagnostic shards."""
import argparse
from concurrent.futures import ThreadPoolExecutor
import gzip
import json
from pathlib import Path
import subprocess
import sys
import tarfile
import tempfile
import time
from rr44_case import CASE,PROJECT
from rr44_native_fixture import FIXTURE
from rr44_diagnostics import Diagnostics,kinds
from rr42_raster import pose_for_raster
from cutout_pipeline.cases import read_json,write_json,digest
from humanoid_cutout.cpu_pose import CpuPose
from humanoid_cutout.canvas import for_case

SHARD_FRAMES=4
WORKERS=8
SHARD_TIMEOUT_S=85
DIAGNOSTIC_PATHS=['experiments/cutouts/chainbound_gaoler/'+name for name in
    ('rr44_diagnostics.py','rr44_release.py','rr38_cpu_diagnostics.py','rr38_uncovered.py','rr42_raster.py',
     'rr44_surface_policy.py','rr44_authority.py','rr44_continuations.py','rr44_exposure.py','rr44_partition.py','rr44_feedback2_repairs.py','rr44_feedback2_ownership.json','rr44_case.py')]+[
    'tools/humanoid_cutout/'+name for name in ('gates.py','cpu_pose.py','stable_paint.py','native_mesh.py','painted_caps.py','uncovered_surfaces.py','held_release.py','source_space.py')]


def diagnostic_bindings():
    return {path:digest(PROJECT/path) for path in DIAGNOSTIC_PATHS}


def certificate():
    path=CASE/'proof/feedback1_calibration.json'
    if not path.exists():return dict(ok=False,reason='Round-0 native calibration receipt is missing')
    result=read_json(path);truth=load()
    valid=(result.get('ok') and not result.get('missing') and result.get('frames')==892 and
           result.get('native_signatures')==len(truth['signatures']) and
           result.get('fixture_sha256')==digest(FIXTURE/'manifest.json') and result.get('diagnostic_inputs')==diagnostic_bindings())
    return dict(ok=bool(valid),fixture_sha256=digest(FIXTURE/'manifest.json'),native_signatures=len(truth['signatures']),
                receipt_sha256=digest(path),scope='Round-0 native findings covered by fresh CPU observations; new native review pending')


def load(fixture=FIXTURE):
    manifest=read_json(fixture/'manifest.json')
    for name,sha in manifest['files'].items():
        if digest(fixture/name)!=sha:raise ValueError('Changed native calibration fixture: '+name)
    return read_json(fixture/'truth.json')


def observed(rows):
    return {(r['view'],r['clip'],r['frame'],kind) for r in rows for kind in kinds(r)}


def missing(truth,rows):
    return sorted({tuple(r) for r in truth['signatures']}-observed(rows))


def replay(view,clip,start,count,output,fixture=FIXTURE):
    truth=load(fixture)
    poses=json.loads(gzip.decompress((fixture/'poses.json.gz').read_bytes()))
    selected=[p for p in poses if p['view']==view and p['clip']==clip and start<=p['frame']<start+count]
    with tempfile.TemporaryDirectory(prefix='rr44-calibration-') as directory:
        case=Path(directory).resolve()
        with tarfile.open(fixture/'case.tar.gz') as bundle:
            for member in bundle.getmembers():
                target=case/member.name;target.resolve().relative_to(case)
                target.parent.mkdir(parents=True,exist_ok=True);target.write_bytes(bundle.extractfile(member).read())
        for name,sha in truth['source_files'].items():
            if digest(case/name)!=sha:raise ValueError('Changed frozen source: '+name)
        model=CpuPose(case,read_json(case/f'layouts/{view}.json'),native_skin=True,triangle_batch_size=128)
        diagnostic=Diagnostics(case,model);rows=[]
        with for_case(case):
            for original in selected:
                pose=pose_for_raster(original);layers,maps=model.layers(pose)
                row=diagnostic.measure(pose,layers,maps)
                rows.append(dict(view=view,clip=clip,frame=pose['frame'],**{k:row[k] for k in ('kinds','clean','metrics','components')}))
    write_json(output,dict(frames=rows,fixture_sha256=digest(fixture/'manifest.json')))


def run(output,fixture=FIXTURE):
    truth=load(fixture);output.mkdir(parents=True,exist_ok=True)
    poses=json.loads(gzip.decompress((fixture/'poses.json.gz').read_bytes()))
    jobs=sorted({(p['view'],p['clip'],p['frame']//SHARD_FRAMES*SHARD_FRAMES) for p in poses})
    def worker(key):
        view,clip,start=key;path=output/f'{view}_{clip}_{start:03d}.json'
        command=[sys.executable,'-B',__file__,'--fixture',str(fixture),'--view',view,'--clip',clip,
                 '--start',str(start),'--count',str(SHARD_FRAMES),'--output',str(path)]
        began=time.monotonic();p=subprocess.run(command,cwd=PROJECT,capture_output=True,text=True,timeout=SHARD_TIMEOUT_S)
        if p.returncode:raise ValueError(p.stdout+p.stderr)
        row=read_json(path)
        if row['fixture_sha256']!=digest(fixture/'manifest.json'):raise ValueError('Stale calibration shard')
        return row['frames'],time.monotonic()-began
    rows=[];longest=0
    with ThreadPoolExecutor(max_workers=WORKERS) as pool:
        for index,(frames,seconds) in enumerate(pool.map(worker,jobs)):
            rows+=frames;longest=max(longest,seconds)
            if index%20==0:print(f'RR44 CALIBRATION SHARDS: {index+1}/{len(jobs)}',flush=True)
    absent=missing(truth,rows)
    result=dict(ok=not absent,fixture_sha256=digest(fixture/'manifest.json'),native_signatures=len(truth['signatures']),
                observed_signatures=sorted(observed(rows)),missing=absent,frames=len(rows),max_shard_seconds=longest,
                diagnostic_sha256=digest(CASE.parent/'rr44_diagnostics.py'),diagnostic_inputs=diagnostic_bindings())
    write_json(output/'calibration.json',result)
    print(f'RR44 CPU/NATIVE CALIBRATION: {"PASS" if not absent else "FAIL"} ({len(truth["signatures"])-len(absent)}/{len(truth["signatures"])} native signatures; {len(rows)} fresh frames; max shard {longest:.3f}s)',flush=True)
    return result


if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--fixture',type=Path,default=FIXTURE);p.add_argument('--output',type=Path,required=True)
    p.add_argument('--view');p.add_argument('--clip');p.add_argument('--start',type=int,default=0);p.add_argument('--count',type=int,default=SHARD_FRAMES)
    a=p.parse_args()
    if a.view:
        if not 1<=a.count<=SHARD_FRAMES:p.error('Use at most four frames per process')
        replay(a.view,a.clip,a.start,a.count,a.output,a.fixture)
    else:raise SystemExit(not run(a.output,a.fixture)['ok'])
