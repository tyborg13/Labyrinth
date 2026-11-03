"""Combine complete hash-checked label batches; a partial batch never certifies."""
import shutil
import numpy as np
from PIL import Image
from rr44_case import CASE
from cutout_pipeline.cases import read_json,write_json,digest as file_digest
from spec.art_identity.maquettes.chainbound_gaoler.proof import job,BUILDER,FOLDER,merge_views
from spec.art_identity.maquettes.blender.capture_manifest import read_manifest,write_manifest
from spec.art_identity.maquettes.blender.contract import digest

BATCH_LABELS=4


def capture(source,output,capture):
    spec=read_json(source);native=output/'native';bridge=output/'bridge'
    if not (native/'build_report.json').exists():job(BUILDER/'build.py',[source,native,'--build-only'],bridge,'build')
    if read_json(native/'build_report.json')['spec_hash']!=digest(spec):raise ValueError('Stale native batch build')
    script=FOLDER/'rr44_capture.py'
    for view in ('front','rear'):
        folder=output/view;images={};solos={};joints=None;checks=[]
        batches=[('preview',None)]+[(f'solo_{i:02d}',list(spec['labels'])[i:i+BATCH_LABELS]) for i in range(0,len(spec['labels']),BATCH_LABELS)]
        for name,labels in batches:
            part=output/(view+'_'+name)
            if not (part/'capture_manifest.json').exists():
                job(script,['preview' if labels is None else ','.join(labels),source,native/'maquette.blend',part,view],bridge,view+'_'+name)
            manifest=read_manifest(part,digest(spec),('preview',) if labels is None else ('ownership',))
            current=read_json(part/'joints_px.json')
            if joints is not None and joints!=current:raise ValueError('Batched native joints differ')
            joints=current;check=read_json(part/'capture_checks.json')
            if not check['passed'] or not check['geometry_unchanged']:raise ValueError('Failed native batch geometry')
            checks.append(check);folder.mkdir(exist_ok=True)
            for filename,row in manifest['images'].items():
                if filename in images:
                    if not np.array_equal(np.asarray(Image.open(folder/filename).convert('RGBA')),np.asarray(Image.open(part/filename).convert('RGBA'))):
                        raise ValueError('Repeated capture RGBA differs')
                    continue # Blender's file metadata includes the output path.
                images[filename]=row;shutil.copyfile(part/filename,folder/filename)
            if labels is not None:
                counts=read_json(part/'solo_coverage.json')[view]
                if set(counts)!=set(labels) or set(counts)&set(solos):raise ValueError('Incomplete or duplicate solo batch')
                solos.update(counts)
            for filename in ('build_report.json','capture_checks.json','facing_report.json'):
                if (part/filename).exists():shutil.copyfile(part/filename,folder/filename)
        if set(solos)!=set(spec['labels']):raise ValueError('Incomplete native label inventory')
        write_json(folder/'joints_px.json',joints);write_json(folder/'solo_coverage.json',{view:solos})
        write_json(folder/'batch_receipt.json',dict(spec_hash=digest(spec),checks=checks,labels=spec['labels'],images=images))
        write_manifest(folder,digest(spec),'full',images)
    merge_views(spec,output,capture);shutil.copyfile(native/'maquette.blend',capture/'maquette.blend')
