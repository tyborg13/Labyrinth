"""Every native-origin frame, using the calibrated raster and director policy."""
import argparse
from pathlib import Path
from collections import Counter
import numpy as np
from PIL import Image
from rr48_build import CASE,VIEWS
from rr48_feedback3_cpu import model,frame
from rr48_feedback3_policy import DirectorPolicy,temporal
from rr48_joint_budget import pose_layers
from cutout_pipeline.cases import read_json,write_json,digest
from humanoid_cutout.canvas import for_case
from humanoid_cutout.held_release import ComponentPolicy
from humanoid_cutout.source_space import DetachedSource
from humanoid_cutout.gates import bindings
from maquette_motion.silhouette import components

def diagnostic_inputs():
 names=('rr48_feedback3_cpu.py','rr48_feedback3_policy.py','rr48_feedback3_source.py','rr48_feedback3_sweep.py','rr48_feedback2_source.py','rr48_feedback2.py','rr48_joint_budget.py')
 return {name:digest(CASE.parent/name) for name in names}

def sweep(case,samples):
 motion=read_json(case/'compiled_motion.json');anatomy=read_json(case/'anatomy.json');results=[];outlines=[];air=[];tears=[];errors=[]
 with for_case(case):
  for view in VIEWS:
   m=model(case,view);policy=DirectorPolicy(m);layout=m.layout
   rest=np.asarray(Image.open(case/layout['rest_source']).convert('RGBA'));release=ComponentPolicy(anatomy,motion,layout,len(components(rest[...,3]>0,8)[1]));detached=DetachedSource(case,layout)
   for row in samples['samples']:
    if row['view']!=view:continue
    layers,maps=pose_layers(m,row,motion);metric=policy.metrics(layers,row,maps);occupied=np.logical_or.reduce([im[...,3]>0 for _,im,_ in layers]);space=policy.space(occupied,row)
    released=release.report(occupied,layers,row['clip'],row['phase']);source=detached.report(layers,{n:p['transform'] for n,p in row['parts'].items()},released['masks'])
    kinds=[]
    if metric['exposed_outline_pixels']:kinds.append('non_director_outline')
    if metric['dark_slab_blocks']:kinds.append('dark_slab')
    if released['errors']:kinds+=released['errors']
    if source['unmatched_components']:kinds.append('unmatched_detached_paint')
    result={k:row[k] for k in ('view','clip','frame','phase')};result.update(metrics=metric,kinds=kinds,holes=space['failures'],air_pockets=space['air_pockets'],unmatched_components=source['unmatched_components'])
    results.append(result);air+=space['air_pockets'];tears+=space['failures']
    if kinds:errors.append(result)
    if len(results)%100==0:print('RR48 CALIBRATED SWEEP FRAME',view,row['clip'],row['frame'],len(tears),'paint-mapped pockets',flush=True)
   outlines+=policy.outline_records
 failures,accepted=temporal(tears)
 return {'ok':not errors and not failures,'native_pixels':False,'frames':results,'errors':errors,'remaining_tears':failures,'accepted_short_tears':accepted,'natural_negative_space':air,'outline':outlines,'compiled_sha256':digest(case/'compiled_motion.json'),'layout_sha256':{v:digest(case/f'layouts/{v}.json') for v in VIEWS},'policy':'Exact registered director pixels; 3x3 slabs block; inverse receiver underlay-air; <=4 px <=3 consecutive frames listed'}

if __name__=='__main__':
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--case',type=Path,default=CASE);p.add_argument('--samples',type=Path,default=CASE/'proof/feedback3_raster_samples.json');p.add_argument('--canonical-samples',type=Path,default=CASE/'proof/feedback3_samples.json');p.add_argument('--output',type=Path,default=CASE/'proof/feedback3_sweep.json');a=p.parse_args()
 bound=bindings(a.case);samples=read_json(a.samples)
 if samples.get('inputs')!=bound or samples.get('compiled_sha256')!=digest(a.case/'compiled_motion.json'):raise ValueError('Stale native-origin poses')
 r=sweep(a.case,samples)
 if bindings(a.case)!=bound:raise ValueError('Inputs changed during calibrated sweep')
 r.update(inputs=bound,samples_sha256=digest(a.canonical_samples),raster_samples_sha256=digest(a.samples),diagnostic_inputs=diagnostic_inputs(),calibration_sha256=digest(CASE/'proof/feedback3_calibration.json'))
 write_json(a.output,r)
 print('RR48 CALIBRATED CPU SWEEP:', 'PASS' if r['ok'] else 'FINDINGS',len(r['frames']),'frames;',len(r['remaining_tears']),'remaining tears;',len(r['accepted_short_tears']),'accepted short tears;',Counter(k for e in r['errors'] for k in e['kinds']),flush=True)
