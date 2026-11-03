"""Scoped exact-paint density derivation and honest CPU rest records."""
import os
import subprocess
import sys
from PIL import Image
import numpy as np
from rr42_underlay import CASE, ASSETS, PROJECT
from rr42_build import BASELINE
from cutout_pipeline.cases import read_json, write_json, digest
from humanoid_cutout.promotion import promote
from rr38_density import expected_rests
import rr38_density
from rr38_proof_case import build as proof_case

DENSITY = PROJECT/'spec/assets/board_pixel_density'
ID = 'chainbound_gaoler_cutout'
PROOF_CASE = CASE/'proof/production_case'


def build():
    layouts={v:read_json(CASE/f'layouts/{v}.json') for v in ('front','rear')}
    promote(PROJECT,CASE,ASSETS/'humanoid_v2',layouts)
    path=DENSITY/'registry.json'; registry=read_json(path)
    entry=next(e for e in registry['entries'] if e['id']==ID)
    partitions={}
    for view,layout in layouts.items():
        old={p['name']:p for p in read_json(BASELINE/(view+'.json'))['parts']}
        for part in layout['parts']:
            mask=CASE/f'ownership/rr42_{view}_{part["name"]}.png'
            previous=old[part['name']]; baseline=BASELINE/previous['file']
            target=ASSETS/'humanoid_v2'/view/(part['name']+'.png')
            partitions[str(target.relative_to(PROJECT))]={
                'mask':{'path':str(mask.relative_to(PROJECT)),'sha256':digest(mask)},
                'source_offset':part['offset'],
                'outside':{'path':str(baseline.relative_to(PROJECT)),'sha256':digest(baseline),'offset':previous['offset']}}
    from pixel_density import metrics,strength
    for view,layout in layouts.items():
        with Image.open(CASE/layout['rest_source']) as source:
            share=metrics(source.convert('RGBA'))['orphan_share']
        treatment=strength(share);grid=round(treatment/entry['r'],2)
        entry['facings'][view].update(orphan_share=share,t=treatment,grid=grid,mode='regrid' if grid>=1.2 else 'clean')
    entry['source_partitions']=partitions
    write_json(path,registry)
    paths=list(entry['paths'])
    # The adopted input is a registered source partition: untouched director
    # pixels inside, already approved prior production outside. Re-adopting raw
    # outside paint would expose newly cut edge colours to a second treatment.
    for view,layout in layouts.items():
        previous={p['name']:p for p in read_json(BASELINE/(view+'.json'))['parts']}
        for part in layout['parts']:
            target=ASSETS/'humanoid_v2'/view/(part['name']+'.png')
            source=np.asarray(Image.open(target).convert('RGBA')).copy()
            mask=np.asarray(Image.open(CASE/f'ownership/rr42_{view}_{part["name"]}.png').convert('L'))>0
            old=previous[part['name']];baseline=np.zeros((255,255,4),np.uint8)
            old_image=np.asarray(Image.open(BASELINE/old['file']).convert('RGBA'))
            bx,by=old['offset'];baseline[by:by+old_image.shape[0],bx:bx+old_image.shape[1]]=old_image
            x,y,x1,y1=part['bbox'];local=mask[y:y1,x:x1]
            source[~local]=baseline[y:y1,x:x1][~local]
            Image.fromarray(source).save(target)
    # Only this unit's derived source cuts are re-adopted. The protected paint
    # remains outside this pipeline, and all other registry entries survive.
    rest_paths=[p for group in entry['rest_paths'].values() for p in group]
    subprocess.run([sys.executable,'tools/process_board_density.py','--force-adopt','--adopt',*paths,*rest_paths],cwd=PROJECT,check=True)
    subprocess.run([sys.executable,'tools/process_board_density.py','--only',ID],cwd=PROJECT,check=True)
    rr38_density.CASE=CASE
    expected_rests()
    proof_case(case=CASE,output=PROOF_CASE)
    print('RR42 DENSITY PARTITIONS: PASS (exact changed texels; retained baseline production elsewhere)')


def rests(task_id='rr-42', timeout_s=300):
    from humanoid_cutout.cpu_pose import CpuPose
    from humanoid_cutout.canvas import for_case
    from maquette_motion import pixels
    import process_board_density as density
    folder=CASE/'proof/logs'; folder.mkdir(parents=True,exist_ok=True)
    poses=folder/'rest_poses.json'
    subprocess.run([sys.executable,'tools/godot_task_runner.py','--task-id',task_id,'--timeout',str(timeout_s),'--stream','--',
        'godot','--headless','--path','.','--script','tests/rr38/samples.gd','--',
        '--case',str(CASE),'--production','--rest-only','--output',str(poses)],cwd=PROJECT,check=True)
    counts={}
    with for_case(CASE):
        for pose in read_json(poses)['samples']:
            view=pose['view']; layout=read_json(PROOF_CASE/f'layouts/{view}.json')
            model=CpuPose(PROOF_CASE,layout,native_skin=True)
            layers,_=model.layers(pose); actual=np.zeros_like(layers[0][1])
            for _,image,_ in sorted(layers,key=lambda r:r[0]['z_index']): actual[image[...,3]>0]=image[image[...,3]>0]
            expected=np.zeros_like(actual); offset=pixels.PROOF_DEFAULTS['source_offset']
            rest=np.asarray(Image.open(PROOF_CASE/layout['rest_source']).convert('RGBA'))
            expected[offset:offset+255,offset:offset+255]=rest
            counts[view]=int(np.any(actual!=expected,axis=-1).sum())
    if set(counts)!={'front','rear'} or any(counts.values()): raise ValueError('Rest geometry mismatch: '+str(counts))
    report=CASE/'proof/rest_equivalence.json'
    write_json(report,{'native_pixels':False,'method':'CPU assembly using fresh headless production Godot rest poses',
                      'pose_sha256':digest(poses),'mismatch_pixels':counts})
    entry=next(e for e in density.load_registry()['entries'] if e['id']==ID)
    density.record_rests([entry],read_json(density.MANIFEST))
    manifest=read_json(density.MANIFEST)
    for path in density.rest_paths(entry):
        manifest[path]['evidence']={'native_pixels':False,'method':'CPU-equivalent rest; director windowed rebake pending',
                                  'report':str(report.relative_to(PROJECT)),'report_sha256':digest(report)}
    write_json(density.MANIFEST,dict(sorted(manifest.items())))
    rr38_density.CASE=CASE
    rr38_density.seal()
    print('RR42 REST EQUIVALENCE: PASS (front=0px rear=0px; native_pixels=False)')


if __name__=='__main__':
    if '--seal-native' in sys.argv:
        rr38_density.CASE=CASE
        if rr38_density.seal(): raise ValueError('Native rest rebake remains pending')
    elif '--rests' in sys.argv: rests()
    else: build()
