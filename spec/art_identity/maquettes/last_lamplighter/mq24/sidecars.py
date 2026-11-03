"""Generate missing mq24/paint import metadata in an isolated Godot project.

Existing sidecars and all source bytes are immutable. The scratch project
keeps each res:// path so generated remap paths remain correct in Labyrinth.
The tracked-inventory guard still requires the owner to stage the new files.
"""
import argparse
import json
from pathlib import Path
import shutil
import subprocess
import sys
from spec.art_identity.maquettes.blender.curate_delivery import sha,write
from .recipe import FOLDER

PROJECT=FOLDER.parents[4]
IMPORT_DEFAULTS={'project_name':'MQ25 Proof Metadata Import','renderer':'gl_compatibility'}
IMPORT_SUFFIXES={'.csv','.glb','.gltf','.jpeg','.jpg','.mp3','.ogg','.otf','.png','.svg','.ttf','.wav','.webp','.woff','.woff2'}


def generate(output):
    output=Path(output).resolve()
    if output.exists() and any(output.iterdir()):raise ValueError('Sidecar import requires an empty scratch directory')
    scratch=output/'project';scratch.mkdir(parents=True)
    (scratch/'project.godot').write_text('config_version=5\n[application]\nconfig/name="'+IMPORT_DEFAULTS['project_name']+'"\n[rendering]\nrenderer/rendering_method="'+IMPORT_DEFAULTS['renderer']+'"\n')
    folders=[FOLDER,PROJECT/'spec/art_identity/jobs/last_lamplighter/mq24_front',PROJECT/'spec/art_identity/jobs/last_lamplighter/mq24_rear']
    sources=[];original={}
    for folder in folders:
        for source in sorted(folder.rglob('*')):
            if not source.is_file() or source.suffix.lower() not in IMPORT_SUFFIXES:continue
            if {'proof','__pycache__'}&set(source.relative_to(folder).parts):continue
            sources.append(source);relative=source.relative_to(PROJECT);original[str(relative)]=sha(source)
            copied=scratch/relative;copied.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(source,copied)
            sidecar=Path(str(source)+'.import')
            if sidecar.is_file():shutil.copyfile(sidecar,Path(str(copied)+'.import'))
    command=[sys.executable,'-B',str(PROJECT/'tools/godot_task_runner.py'),'--task-id','mq-25','--stream','--','godot','--headless','--path',str(scratch),'--import']
    with (output/'import.log').open('w') as log:
        result=subprocess.run(command,cwd=PROJECT,stdout=log,stderr=subprocess.STDOUT)
    if result.returncode:raise ValueError('Godot metadata import failed; see '+str(output/'import.log'))
    generated=[]
    for source in sources:
        relative=source.relative_to(PROJECT)
        if sha(source)!=original[str(relative)]:raise ValueError('Source bytes changed during import: '+str(source))
        target=Path(str(source)+'.import');imported=Path(str(scratch/relative)+'.import')
        if not imported.is_file():raise ValueError('Missing generated import: '+str(imported))
        if not target.exists():shutil.copyfile(imported,target);generated.append(str(target.relative_to(PROJECT)))
    report={'passed':True,'command':command,'sources_sha256':original,'generated':{name:sha(PROJECT/name) for name in generated},'existing_sidecars_preserved':True}
    write(output/'sidecars.json',report)
    print('MQ25_SIDECARS: PASS; sources='+str(len(sources))+'; generated='+str(len(generated)),flush=True)
    return report


if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--out',type=Path,required=True)
    generate(parser.parse_args().out)
