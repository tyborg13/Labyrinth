"""Record shipped source provenance without relabelling offline rests as native."""
from PIL import Image
from cutout_pipeline.cases import read_json, write_json, digest
from art_identity_gate import pixel_digest, measure
import process_board_density as density
from .anatomy import load


def record(project, case, assets):
    inputs=read_json(case/'inputs.json')
    build=read_json(case/'proof/build.json')
    source=read_json(case/'compiled_motion.json')
    config=load(case)['integration']
    scale_source=config['scale']
    scale=read_json(project/scale_source['file'])[scale_source['key']].get(scale_source['field'],scale_source['default'])
    identity_path=project/config['identity_registry']
    identity=read_json(identity_path)
    for view in source['view_tracks']:
        rest=assets/config['rig_directory']/view/'rest.png'
        relative=str(rest.relative_to(project))
        entry=next((e for e in identity['entries'] if e['path']==relative),None)
        if entry is None:
            entry={'path':relative};identity['entries'].append(entry)
        job=project/inputs[view+'_job']
        kit=read_json(job/'kit.json')
        entry.update(id=config['identity_id'],kind=config['identity_kind'],entry_kind=config['identity_entry_kind'],anatomy=kit['anatomy'],
            boss=config['identity_boss'],art_scale=scale,size_class=kit['size_class'],pixel_sha256=pixel_digest(Image.open(rest)),
            metrics=measure(rest,scale,config['identity_kind'],kit['anatomy']),source_path=inputs[view+'_job']+'/processed.png',
            source_pixel_sha256=read_json(job/'processed.json')['pixel_sha256'],
            owner_approval=config['owner_approval'])
    write_json(identity_path,identity)
    registry=density.load_registry()
    entry=next(e for e in registry['entries'] if e['id']==config['density_id'])
    pending=density.rest_errors([entry],read_json(density.MANIFEST))
    live=[p for p in (assets/config['rig_directory']).rglob('*') if p.is_file()]
    live += [assets/n for n in config['production_files']]
    integration_path = assets / 'integration.json'
    declarations = read_json(integration_path) if integration_path.exists() else {}
    action_adapter = {key: declarations[key] for key in ('action_adapter',) if key in declarations}
    write_json(integration_path,{'ready':False,'rig':'humanoid_v2', **action_adapter,
        'case':str(case.relative_to(project)),'director_sha256':source['director_sha256'],
        'design_placeholders':inputs.get('design_placeholders',{}),
        'native_proof':'pending director rest/native/production/idle/review',
        'rest_identity':{'scope':'offline approved-source ownership, not native proof',
            **{view:build['views'][view]['rest_mismatch_pixels'] for view in source['view_tracks']}},
        'density':{'entry':entry['id'],'paint':'adopted/processed from untouched source parts',
                   'native_rest_pending':pending},
        'files':{str(p.relative_to(assets)):digest(p) for p in sorted(live)}})
    return pending
