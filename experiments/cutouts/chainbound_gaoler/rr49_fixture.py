"""Preserve the binding final rr-44 native witnesses as a small replay fixture."""
import ast
import gzip
import io
import json
from pathlib import Path
import re
import tarfile
from rr44_case import CASE
from cutout_pipeline.cases import read_json, write_json, digest
from humanoid_cutout.native_frames import load_frame, frame_digest

FIXTURE = CASE.parent/'rr49/fixtures/native_final_rr44'
BASELINE = CASE.parent/'rr49/proof/baseline'


def freeze():
    if FIXTURE.exists(): raise ValueError('Never overwrite frozen native truth')
    FIXTURE.mkdir(parents=True)
    case = BASELINE/'production_case'; capture = BASELINE/'native'
    manifest = read_json(capture/'frames.json')
    errors = read_json(BASELINE/'rr44_native_gates.json')['errors']
    poses = [p for p in read_json(case/'proof/logs/samples.json')['samples'] if p['kind']=='presented']
    files = sorted(p for p in case.rglob('*') if p.is_file() and p.suffix in ('.png','.json') and
                   ('proof' not in p.relative_to(case).parts))
    with tarfile.open(FIXTURE/'case.tar.gz','w:gz') as bundle:
        for path in files:
            data = path.read_bytes(); entry = tarfile.TarInfo(path.relative_to(case).as_posix())
            entry.size = len(data); entry.mode = 0o644; bundle.addfile(entry,io.BytesIO(data))
    (FIXTURE/'poses.json.gz').write_bytes(gzip.compress(json.dumps(poses,separators=(',',':')).encode(),mtime=0))
    witnesses=[]
    for error in errors:
        if error.startswith('groups/'):
            file,_,count=error.partition(': idle pixel mismatch: ')
            row=next(r for r in manifest['idle_groups'] if r['file']==file)
            witnesses.append(dict(kind='idle',**row,pixels=int(count)))
            paths=[row['file'],row['rest']]
        else:
            if error.startswith("('"):
                key,_=error.split(': ',1);view,clip,frame=ast.literal_eval(key);names=['chain'];kind='released'
            else:
                key,details=error.split(': native source RGBA ',1);view,clip,frame=key.split('/');frame=int(frame)
                names=[r['part'] for r in ast.literal_eval(details)];kind='source'
            for name in names:
                row=next(r for r in manifest['pieces'] if (r['view'],r['clip'],r['frame'],r['name'])==(view,clip,frame,name))
                if frame_digest(capture/row['file'])!=row['sha256']: raise ValueError('Changed native witness')
                witnesses.append(dict(kind=kind,**row))
            paths=[r['file'] for r in witnesses[-len(names):]]
        for name in paths:
            target=FIXTURE/name;target.parent.mkdir(parents=True,exist_ok=True)
            load_frame(capture/name).convert('RGBA').save(target)
    truth=dict(base='5ec882b01',errors=errors,witnesses=witnesses,native_manifest_sha256=digest(capture/'frames.json'),
               source_files={str(p.relative_to(case)):digest(p) for p in files})
    write_json(FIXTURE/'truth.json',truth)
    write_json(FIXTURE/'manifest.json',dict(files={str(p.relative_to(FIXTURE)):digest(p) for p in sorted(FIXTURE.rglob('*')) if p.is_file()}))
    (FIXTURE.parent/'.gdignore').write_text('# Immutable native regression inputs, Python only.\n')
    print(f'RR49 NATIVE FIXTURE: {len(errors)} errors; {len(witnesses)} witnesses; '+digest(FIXTURE/'manifest.json'))


if __name__=='__main__': freeze()
