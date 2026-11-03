"""Compose bounded passes through the inherited complete-capture validator."""
import json
from pathlib import Path
import shutil
import numpy as np
from PIL import Image
from spec.art_identity.maquettes.blender.contract import digest
from spec.art_identity.maquettes.blender.capture_manifest import read_manifest,write_manifest
from spec.art_identity.maquettes.blender.curate_delivery import write
from ..capture_workflow import merge,CAPTURE_DEFAULTS
from ..bridge import job


def capture(spec_path,output,local):
    spec=json.loads(Path(spec_path).read_text());output=Path(output);script=Path(local)/'capture.py'
    native=output/'native/maquette.blend'
    for view in ('front','rear'):
        modes=('clay','parts','facing') if view=='front' else ('clay','parts','silhouette')
        for mode in modes:
            job(script,[spec_path,native,output/(view+'_'+mode),view,mode],output/'bridge',view+'_'+mode)
        preview=output/(view+'_preview');preview.mkdir();images={};joints=None;facing=None
        for mode in modes:
            source=output/(view+'_'+mode);manifest=read_manifest(source,digest(spec),('preview',))
            check=json.loads((source/'capture_checks.json').read_text())
            if not check['passed'] or not check['geometry_unchanged']:raise ValueError('Failed bounded preview')
            observed=json.loads((source/'joints_px.json').read_text())
            if joints is not None and joints!=observed:raise ValueError('Preview joints moved between passes')
            joints=observed
            for name in manifest['images']:
                if name in images:
                    if not np.array_equal(np.asarray(Image.open(source/name)),np.asarray(Image.open(preview/name))):
                        raise ValueError('Bounded passes changed duplicate pixels: '+name)
                else:shutil.copyfile(source/name,preview/name);images[name]=True
            if mode=='facing':
                facing=json.loads((source/'facing_report.json').read_text())
                shutil.copyfile(source/'facing_report.json',preview/'facing_report.json')
        write(preview/'joints_px.json',joints)
        write(preview/'capture_checks.json',{'passed':True,'geometry_unchanged':True,'facing':facing})
        write_manifest(preview,digest(spec),'preview',images)
        names=list(spec['labels']);size=CAPTURE_DEFAULTS['solo_batch_size']
        for start in range(0,len(names),size):
            job(script,[spec_path,native,output/(view+'_solo_'+str(start)),view,','.join(names[start:start+size])],
                output/'bridge',view+'_solo_'+str(start))
    return merge(spec,output)
