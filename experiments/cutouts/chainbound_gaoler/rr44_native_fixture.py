"""Freeze the director's round-0 evidence before changing its rig inputs.

Only this producer reads ignored reports. Tests replay the hash-bound archive
and poses; they never read the current capture or a gitignored CPU log.
"""
import ast
import gzip
import io
import json
from pathlib import Path
import tarfile
from PIL import Image
from rr44_case import CASE
from cutout_pipeline.cases import read_json,write_json,digest
from humanoid_cutout.gates import bindings
from humanoid_cutout.native_frames import load_frame,frame_digest

FIXTURE=CASE/'fixtures/native_r0'
WITNESSES={'front':{'death':[10,11,12,13,16,17,18,19,20,21,22,31],'press':[13,14,15]},
           'rear':{'death':[10,31]}}


def signatures(errors):
    rows=set()
    for error in errors:
        if not error.startswith("('"):continue
        key,text=error.split(': ',1);key=ast.literal_eval(key)
        rules=(('detached opaque','detached'),('floating pieces:','floating'),('joint-seam hole','seam'),
               ('outline in exposed','outline'),('released held item','released'))
        matches=[kind for token,kind in rules if token in text]
        if len(matches)!=1:raise ValueError('Unclassified native error: '+error)
        rows.add((*key,matches[0]))
    return sorted(rows)


def compressed(path,value):
    path.write_bytes(gzip.compress(json.dumps(value,separators=(',',':')).encode(),mtime=0))


def freeze():
    if (FIXTURE/'manifest.json').exists():raise ValueError('Native baseline already frozen; never overwrite it')
    case=CASE/'proof/production_case';capture=CASE/'proof/native'
    native=read_json(capture/'frames.json');gate=read_json(CASE/'proof/rr44_native_gates.json')
    cpu=read_json(case/'proof/logs/rr44_sweep.json')
    if native['inputs']!=bindings(case):raise ValueError('Director native input is stale')
    without_production=lambda data:{k:v for k,v in data.items() if not k.startswith('production:')}
    if without_production(cpu['inputs'])!=without_production(native['inputs']):raise ValueError('CPU/native raster inputs differ')
    FIXTURE.mkdir(parents=True,exist_ok=True)
    files=sorted(p for p in case.rglob('*') if p.is_file() and p.suffix in ('.png','.json') and
                 ('proof' not in p.relative_to(case).parts or p.relative_to(case).as_posix()=='proof/build.json'))
    with tarfile.open(FIXTURE/'case.tar.gz','w:gz') as bundle:
        for path in files:
            content=path.read_bytes();entry=tarfile.TarInfo(path.relative_to(case).as_posix());entry.size=len(content)
            entry.mode=0o644;bundle.addfile(entry,io.BytesIO(content))
    poses=[p for p in read_json(case/'proof/logs/samples.json')['samples'] if p['kind']=='presented']
    compressed(FIXTURE/'poses.json.gz',poses)
    compressed(FIXTURE/'cpu_measurements.json.gz',[{k:r[k] for k in ('view','clip','frame','kinds','clean','metrics','components')} for r in cpu['frames']])
    truth=dict(raw_errors=gate['errors'],signatures=signatures(gate['errors']),
               native_gate_sha256=digest(CASE/'proof/rr44_native_gates.json'),native_manifest_sha256=digest(capture/'frames.json'),
               native_inputs=native['inputs'],source_files={p.relative_to(case).as_posix():digest(p) for p in files},
               retained_cpu_report_sha256=digest(case/'proof/logs/rr44_sweep.json'))
    write_json(FIXTURE/'truth.json',truth)
    witnesses=[]
    for view,clips in WITNESSES.items():
        for clip,frames in clips.items():
            for frame in frames:
                row=next(r for r in native['frames'] if (r['view'],r['clip'],r['frame'])==(view,clip,frame))
                if frame_digest(capture/row['file'])!=row['sha256']:raise ValueError('Changed native witness')
                image=load_frame(capture/row['file']).convert('RGBA');box=image.getbbox()
                name=f'{view}_{clip}_{frame:03d}_native_4x.webp';picture=image.crop(box)
                picture.resize((picture.width*4,picture.height*4),Image.Resampling.NEAREST).save(FIXTURE/name,lossless=True,exact=True)
                witnesses.append(dict(view=view,clip=clip,frame=frame,source_sha256=row['sha256'],crop=name,crop_box=box))
    write_json(FIXTURE/'witnesses.json',witnesses)
    write_json(FIXTURE/'manifest.json',dict(files={p.name:digest(p) for p in sorted(FIXTURE.iterdir()) if p.is_file()},
               native_pixels=True,raw_native_report_errors=len(gate['errors']),native_frame_kind_signatures=len(truth['signatures'])))
    print('RR44 NATIVE FIXTURE:',digest(FIXTURE/'manifest.json'),len(truth['signatures']),'native signatures')


if __name__=='__main__':freeze()
