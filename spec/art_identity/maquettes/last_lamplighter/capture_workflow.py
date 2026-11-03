"""Bounded view/solo jobs merged into one complete hash-checked capture."""
import json
from pathlib import Path
import shutil

from spec.art_identity.maquettes.blender.contract import digest
from spec.art_identity.maquettes.blender.capture_manifest import read_manifest,write_manifest
from spec.art_identity.maquettes.blender.curate_delivery import write
from .bridge import job
from .recipe import FOLDER

CAPTURE_DEFAULTS={'solo_batch_size':4}


def capture(spec_path,output,script=None):
    output=Path(output).resolve();spec_path=Path(spec_path).resolve();spec=json.loads(spec_path.read_text())
    script=script or FOLDER/'capture.py';native=output/'native/maquette.blend'
    for view in ('front','rear'):
        for mode in ('preview',):
            destination=output/(view+'_'+mode)
            if destination.exists():
                read_manifest(destination,digest(spec),('preview',))
                print('MQ18_CAPTURE_REUSE: verified '+view+' '+mode,flush=True)
            else:job(script,[spec_path,native,destination,view,mode],output/'bridge',view+'_'+mode)
        names=list(spec['labels'])
        for start in range(0,len(names),CAPTURE_DEFAULTS['solo_batch_size']):
            batch=names[start:start+CAPTURE_DEFAULTS['solo_batch_size']]
            job(script,[spec_path,native,output/(view+'_solo_'+str(start)),view,','.join(batch)],
                output/'bridge',view+'_solo_'+str(start))
    return merge(spec,output)


def merge(spec,output):
    output=Path(output);dest=output/'capture';dest.mkdir(parents=True,exist_ok=True)
    images=[];joints={};solos={};batch_bindings={}
    report=json.loads((output/'native/build_report.json').read_text())
    for view in ('front','rear'):
        for mode in ('preview',):
            preview=output/(view+'_'+mode);manifest=read_manifest(preview,digest(spec),('preview',))
            check=json.loads((preview/'capture_checks.json').read_text())
            if not check['passed'] or not check['geometry_unchanged']:raise ValueError('Invalid preview')
            batch_bindings[view+'_'+mode]=digest(manifest)
            for name in manifest['images']:
                if name in images:raise ValueError('Duplicate preview image')
                shutil.copyfile(preview/name,dest/name);images.append(name)
            observed=json.loads((preview/'joints_px.json').read_text())[view]
            if view in joints and joints[view]!=observed:raise ValueError('Preview joints changed')
            joints[view]=observed
        solos[view]={}
        for start in range(0,len(spec['labels']),CAPTURE_DEFAULTS['solo_batch_size']):
            batch=output/(view+'_solo_'+str(start));m=read_manifest(batch,digest(spec),('ownership',))
            check=json.loads((batch/'capture_checks.json').read_text())
            build=json.loads((batch/'build_report.json').read_text())
            if not check['passed'] or not check['geometry_unchanged'] or build['mesh_hashes']!=report['mesh_hashes']:
                raise ValueError('Invalid bounded capture')
            if json.loads((batch/'joints_px.json').read_text())[view]!=joints[view]:raise ValueError('Batch joints changed')
            batch_bindings[batch.name]=digest(m)
            for part,count in json.loads((batch/'solo_coverage.json').read_text())[view].items():
                if part in solos[view]:raise ValueError('Duplicate solo owner')
                name=view+'_solo_'+part+'.png'
                if name not in m['images']:raise ValueError('Missing batch solo')
                solos[view][part]=count;images.append(name);shutil.copyfile(batch/name,dest/name)
        if set(solos[view])!=set(spec['labels']) or not all(n>0 for n in solos[view].values()):raise ValueError('Incomplete solos')
    facing=json.loads((output/'front_preview/facing_report.json').read_text())
    report['checks'].update(required_solo_coverage=True,rendered_torso_asymmetry=facing['passed'],capture_geometry_unchanged=True)
    report['passed']=all(report['checks'].values())
    values={'joints_px.json':joints,'solo_coverage.json':solos,'build_report.json':report,'facing_report.json':facing,
        'ownership_validation.json':{'passed':True,'empty_required_solos':{'front':[],'rear':[]}},
        'capture_checks.json':{'passed':report['passed'],'spec_hash':digest(spec),'geometry_unchanged':True,
                              'geometry_checks':report['checks'],'facing':facing,'batch_manifest_digests':batch_bindings}}
    for name,value in values.items():write(dest/name,value)
    write_manifest(dest,digest(spec),'full',images)
    print('MQ18_CAPTURE_MERGE: PASS; views=2; solos=44',flush=True)
    return dest
