"""Record shipped source provenance without relabelling offline rests as native."""
from pathlib import Path

from PIL import Image
from cutout_pipeline.cases import read_json, write_json, digest
from art_identity_gate import pixel_digest, measure
import process_board_density as density


def record(project, case, assets):
    inputs=read_json(case/'inputs.json')
    build=read_json(case/'proof/build.json')
    source=read_json(case/'compiled_motion.json')
    scale=read_json(project/'data/enemies.json')['hoarfrost_seer'].get('art_scale',1.0)
    identity_path=project/'spec/art_identity/registry.json'
    identity=read_json(identity_path)
    for view in ('front','rear'):
        rest=assets/'humanoid_v2'/view/'rest.png'
        relative=str(rest.relative_to(project))
        entry=next((e for e in identity['entries'] if e['path']==relative),None)
        if entry is None:
            entry={'path':relative};identity['entries'].append(entry)
        job=project/inputs[view+'_job']
        kit=read_json(job/'kit.json')
        entry.update(id='hoarfrost_seer',kind='creature',entry_kind='legacy',anatomy=kit['anatomy'],
            boss=False,art_scale=scale,size_class=kit['size_class'],pixel_sha256=pixel_digest(Image.open(rest)),
            metrics=measure(rest,scale,'creature',kit['anatomy']),source_path=inputs[view+'_job']+'/processed.png',
            source_pixel_sha256=read_json(job/'processed.json')['pixel_sha256'],
            owner_approval='rr-10 feedback 5: supplied approved mq5 front and mq6 rear painting; derived rest snapshot, not a worker art verdict or native proof.')
    write_json(identity_path,identity)
    registry=density.load_registry()
    entry=next(e for e in registry['entries'] if e['id']=='hoarfrost_seer_cutout')
    pending=density.rest_errors([entry],read_json(density.MANIFEST))
    live=[p for p in (assets/'humanoid_v2').rglob('*') if p.is_file()]
    live += [assets/n for n in ('rig.gd','renderer.gd','actions.gd','front.json','rear.json')]
    write_json(assets/'integration.json',{'ready':False,'rig':'humanoid_v2',
        'case':str(case.relative_to(project)),'director_sha256':source['director_sha256'],
        'design_placeholders':inputs.get('design_placeholders',{}),
        'native_proof':'pending director rest/native/production/idle/review',
        'rest_identity':{'scope':'offline approved-source ownership, not native proof',
            'front':build['views']['front']['rest_mismatch_pixels'],
            'rear':build['views']['rear']['rest_mismatch_pixels']},
        'density':{'entry':entry['id'],'paint':'adopted/processed from untouched source parts',
                   'native_rest_pending':pending},
        'files':{str(p.relative_to(assets)):digest(p) for p in sorted(live)}})
    return pending
