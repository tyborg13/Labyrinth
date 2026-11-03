"""One preview pass or four solos per bridge job; unchanged renderer settings."""
import json
from pathlib import Path
import shutil
from spec.art_identity.maquettes.blender.capture_manifest import read_manifest,write_manifest
from spec.art_identity.maquettes.blender.contract import digest
from spec.art_identity.maquettes.blender.curate_delivery import write
from ..bridge import job
from ..capture_workflow import merge

CAPTURE_DEFAULTS={'solo_batch_size':4}


def capture(spec_path,output,script):
    spec_path=Path(spec_path).resolve();output=Path(output).resolve();spec=json.loads(spec_path.read_text())
    for view in ('front','rear'):
        parts=('clay','parts','facing') if view=='front' else ('clay','parts','silhouette')
        destination=output/(view+'_preview');destination.mkdir(exist_ok=True)
        images=[];facing=None;joints=None;reports=[]
        for kind in parts:
            batch=output/(view+'_pass_'+kind)
            if not (batch/'capture_manifest.json').is_file():job(script,[spec_path,output/'native/maquette.blend',batch,view,'pass:'+kind],output/'bridge',batch.name)
            manifest=read_manifest(batch,digest(spec),('preview',));checks=json.loads((batch/'capture_checks.json').read_text())
            if not checks['passed'] or not checks['geometry_unchanged']:raise ValueError('Single-pass capture failed')
            observed=json.loads((batch/'joints_px.json').read_text())
            if joints is not None and joints!=observed:raise ValueError('Single-pass joints differ')
            joints=observed;reports.append(checks)
            if checks['facing'] is not None:facing=checks['facing']
            for name in manifest['images']:
                if name in images:raise ValueError('Duplicate single-pass image')
                images.append(name);shutil.copyfile(batch/name,destination/name)
            if (batch/'facing_report.json').is_file():shutil.copyfile(batch/'facing_report.json',destination/'facing_report.json')
        write(destination/'joints_px.json',joints)
        write_manifest(destination,digest(spec),'preview',images)
        write(destination/'capture_checks.json',{'passed':True,'geometry_unchanged':True,'facing':facing,'spec_hash':digest(spec),'passes':reports})
        labels=list(spec['labels'])
        for start in range(0,len(labels),CAPTURE_DEFAULTS['solo_batch_size']):
            batch=output/(view+'_solo_'+str(start))
            if (batch/'capture_manifest.json').is_file():
                read_manifest(batch,digest(spec),('ownership',));continue
            job(script,[spec_path,output/'native/maquette.blend',output/(view+'_solo_'+str(start)),view,','.join(labels[start:start+4])],output/'bridge',view+'_solo_'+str(start))
    return merge(spec,output)
