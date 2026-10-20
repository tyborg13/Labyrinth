"""Explicit rr-24 repaint baseline recording; tests never update this file."""
from copy import deepcopy
import hashlib
import json
from pathlib import Path
import subprocess

import numpy as np
from PIL import Image

from rr24_build import PROJECT,CASE,RECIPE,read_json,write_json,digest
from rr24_seams import frame_report,SkirtAirPolicy
from tools.humanoid_cutout.cpu_pose import CpuPose

REPAINT_COMMIT='4de3c0dc2d59a83246c6b36abfcada081ff1fdc0'
DIRECTOR_DATA_COMMIT='80d5ec39bfa4b79c176835a02c6137044a7de75e'
BASELINE_FILE=RECIPE/'repaint_baseline.json'
GEOMETRY_FIELDS=('bbox','vertices','uvs','triangles','weights','weight_bounds')
OWNED_ART_PREFIXES=('assets/units/arc_thrall_cutout/','experiments/cutouts/arc_thrall/',
                   'spec/assets/board_pixel_density/sources/assets/units/arc_thrall_cutout/')


def canonical(value):
    return hashlib.sha256(json.dumps(value,sort_keys=True,separators=(',',':')).encode()).hexdigest()


def file_record(relative):
    path=PROJECT/relative
    # Native rest recording changes only the derived snapshot fingerprint.
    # Pin its adopted untreated calibration source, not a stale pre-rebake PNG.
    if relative.endswith('/rest.png') and relative.startswith('assets/units/arc_thrall_cutout/'):
        path=PROJECT/'spec/assets/board_pixel_density/sources'/relative
    if path.suffix=='.json':
        data=read_json(path)
        if isinstance(data,dict) and 'parts'in data and 'joints'in data:
            data.pop('rest_source_sha256',None)
            return {'reference_path':str(path.relative_to(PROJECT)),'canonical_layout_sha256':canonical(data)}
    return {'reference_path':str(path.relative_to(PROJECT)),'sha256':digest(path)}


def assert_preserved(test,relative):
    baseline=read_json(BASELINE_FILE)
    test.assertIn(relative,baseline['files'])
    test.assertEqual(file_record(relative),baseline['files'][relative],relative)


def render_rows(rows):
    return [{k:v for k,v in row.items() if not k.startswith('direction_') and not(row['kind']=='authored'and k=='parts')}
            for row in rows if row['view']=='front'and row['clip']!='move']


def record():
    samples=read_json(CASE/'proof/samples.json')
    from tools.humanoid_cutout.gates import bindings
    if samples['inputs']!=bindings(CASE):raise ValueError('Refresh samples before explicit baseline recording')
    fixtures=PROJECT/'tests/rr11/rr15'
    paths=set(read_json(fixtures/'feedback1_front_before.json')['protected_files'])
    paths.update(read_json(fixtures/'protected.json'))
    paths.add(str((CASE/'rr24_policy.json').relative_to(PROJECT)))
    for root in (CASE,PROJECT/'assets/units/arc_thrall_cutout/humanoid_v2',RECIPE/'raw',
                 PROJECT/'spec/assets/board_pixel_density/sources/assets/units/arc_thrall_cutout'):
        for path in root.rglob('*'):
            if path.is_file()and path.suffix=='.png'and 'proof'not in path.relative_to(root).parts:
                paths.add(str(path.relative_to(PROJECT)))
    for relative in subprocess.check_output(['git','diff','--name-only','HEAD'],cwd=PROJECT,text=True).splitlines():
        if relative.endswith('.png')and relative.startswith(OWNED_ART_PREFIXES):paths.add(relative)
    for view in ('front','rear'):
        paths.add(str((CASE/f'layouts/{view}.json').relative_to(PROJECT)))
    geometry={};gait_frames={};opaque={}
    for view in ('front','rear'):
        layout=read_json(CASE/f'layouts/{view}.json')
        for mesh in layout['joint_meshes']:
            geometry[view+'/'+mesh['name']]=canonical({k:mesh[k]for k in GEOMETRY_FIELDS if k in mesh})
        # Mutation fixture: immutable final masks versus omitted gait-only
        # texture copies. These are numeric source-geometry regressions, not
        # claimed renderer captures.
        unfilled=deepcopy(layout);unfilled.pop('gait_continuations')
        model=CpuPose(CASE,unfilled);policy=SkirtAirPolicy(CASE,layout)
        rows=[]
        for pose in samples['samples']:
            if pose['view']!=view or pose['clip']!='move'or pose['kind']!='presented':continue
            failures=frame_report(model,pose,policy)[-1]['failures']
            if failures:rows.append({'frame':pose['frame'],'pockets':[{k:p[k]for k in ('bbox','pixel_count')}for p in failures]})
        gait_frames[view]=rows
    layout=read_json(CASE/'layouts/front.json')
    name='leg_far'
    part=next(p for p in layout['parts']if p['name']==name)
    image=np.asarray(Image.open(CASE/part['file']).convert('RGBA'))
    y,x=np.argwhere(image[...,3]==0)[0]
    opaque={'part':name,'opaque_target':[1,37],'transparent_target':[int(x),int(y)]}
    # Re-colour the old *alpha-only* shoulder removal fixture with the current
    # mq7b part. The historical texture is retained and never used as new paint.
    from rr15_shoulder_proof import BEFORE
    layout=read_json(CASE/'layouts/rear.json');part=next(p for p in layout['parts']if p['name']=='hidden_upper_near')
    image=np.asarray(Image.open(CASE/part['file']).convert('RGBA')).copy()
    alpha=np.asarray(Image.open(BEFORE).convert('RGBA'))[...,3]>0
    image[~alpha]=0
    target=RECIPE/'feedback1_shoulder_before.png';Image.fromarray(image).save(target)
    Path(str(target)+'.import').write_text('[remap]\n\nimporter="keep"\n')
    paths.add(str(target.relative_to(PROJECT)))
    layout=read_json(CASE/'layouts/rear.json');model=CpuPose(CASE,deepcopy(layout))
    overrides={p['name']:model.image(p['file']).copy() for p in layout['parts']}
    points=read_json(RECIPE/'joint_continuations.json')['rear']['head']['source_points']
    for part in layout['parts']:
        if part['logical_part']!='head'or not part.get('hidden_material'):continue
        x,y,right,bottom=part['bbox']
        for u,v in points:
            if x<=u<right and y<=v<bottom:overrides[part['name']][v-y,u-x]=0
    nape=[]
    for frame in (43,44,45,46,56):
        pose=next(p for p in samples['samples']if p['view']=='rear'and p['clip']=='death'and p['frame']==frame and p['kind']=='presented')
        defects=frame_report(model,pose,source_overrides=overrides)[-1]['failures']
        if not defects:raise ValueError('Nape removal fixture must reopen the painted joint')
        nape.append({'frame':frame,'pockets':[{k:p[k]for k in ('bbox','pixel_count')}for p in defects]})
    result={'authority':{'repaint_commit':REPAINT_COMMIT,'director_data_commit':DIRECTOR_DATA_COMMIT,
        'director_sha256':digest(CASE/'director_motion.json'),
        'paintings':{v:{'path':f'spec/art_identity/jobs/arc_thrall/mq7b_{v}/processed.png',
                       'sha256':digest(PROJECT/f'spec/art_identity/jobs/arc_thrall/mq7b_{v}/processed.png')}for v in ('front','rear')}},
        'files':{p:file_record(p)for p in sorted(paths)},'geometry':geometry,
        'front_render_rows':{'count':len(render_rows(samples['samples'])),'sha256':canonical(render_rows(samples['samples']))},
        'gait_removal_frames':gait_frames,'opaque_fixture':opaque,'nape_removal_frames':nape}
    write_json(BASELINE_FILE,result)
    print(f'RR24 REPAINT BASELINE: RECORDED ({len(paths)} Thrall files; director {DIRECTOR_DATA_COMMIT}; mq7b both views)')


if __name__=='__main__':record()
