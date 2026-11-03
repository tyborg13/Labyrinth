"""Native-origin CPU oracle; calibration precedes feedback-3 paint changes."""
import argparse
from collections import defaultdict
import numpy as np
from PIL import Image
from rr48_build import CASE,VIEWS
from rr48_joint_budget import pose_layers
from cutout_pipeline.cases import read_json,write_json,digest
from humanoid_cutout.cpu_pose import CpuPose,mask_mesh
from humanoid_cutout.canvas import for_case
from maquette_motion.silhouette import holes
from maquette_motion.material_palette import outline_class,rules

DEFAULTS={'triangle_batch_size':128}

def model(case,view):
 layout=read_json(case/f'layouts/{view}.json');m=CpuPose(case,layout,native_skin=True,triangle_batch_size=DEFAULTS['triangle_batch_size'])
 for name,mesh in m.meshes.items():
  selected=mask_mesh(mesh,m.image(next(p['file'] for p in layout['parts'] if p['name']==name))[...,3]>0)
  if selected['triangles']:m.meshes[name]=selected
 return m

def box(mask):
 y,x=np.nonzero(mask)
 return [int(x.min()),int(y.min()),int(x.max()+1),int(y.max()+1)] if len(x) else None

def frame(m,row,motion):
 layers,maps=pose_layers(m,row,motion);occupied=np.zeros(layers[0][1].shape[:2],bool);outline=[]
 for part,im,checks in sorted(layers,key=lambda r:r[0]['z_index'],reverse=True):
  alpha=im[...,3]>0
  dark=alpha&~occupied&(checks[...,1]>0)&outline_class(im,rules(m.case,row['view']))
  if dark.any():outline.append({'part':part['name'],'n':int(dark.sum()),'bbox':box(dark)})
  occupied|=alpha
 pockets=[{'bbox':box(mask),'pixel_count':int(mask.sum())} for mask in holes(occupied) if mask.sum()>1]
 return {'view':row['view'],'clip':row['clip'],'frame':row['frame'],'outline':outline,'holes':pockets},layers,maps

def contains(a,b):return a[0]<=b[0] and a[1]<=b[1] and a[2]>=b[2] and a[3]>=b[3]

def calibrate():
 case=CASE/'proof/feedback3_round2_case';samples=read_json(CASE/'proof/feedback3_round2_raster_samples.json');native=read_json(CASE/'proof/feedback3_director_native_diag.json');motion=read_json(case/'compiled_motion.json');records=[]
 with for_case(case):
  for view in VIEWS:
   m=model(case,view)
   for row in samples['samples']:
    if row['view']==view:records.append(frame(m,row,motion)[0])
 index={(r['view'],r['clip'],r['frame']):r for r in records};missing=[];coverage=defaultdict(lambda:{'hole_frames':0,'pockets':0,'outline_records':0,'missed_pockets':0,'missed_outline':0})
 for n in native['holes']:
  r=index[n['view'],n['clip'],n['frame']];c=coverage[n['view'],n['clip']];c['hole_frames']+=1
  for pocket in n['pockets']:
   c['pockets']+=1
   if not any(contains(p['bbox'],pocket['bbox']) and p['pixel_count']>=pocket['pixel_count'] for p in r['holes']):missing.append({'kind':'hole',**n,'pocket':pocket,'cpu':r['holes']});c['missed_pockets']+=1
 for n in native['outline']:
  _,clip,f,view,_=n['file'].split('/');r=index[view,clip,int(f)];c=coverage[view,clip];c['outline_records']+=1;b=n['bbox'];b=[b[0],b[1],b[2]+1,b[3]+1]
  if not any(p['part']==n['part'] and contains(p['bbox'],b) and p['n']>=n['n'] for p in r['outline']):missing.append({'kind':'outline','native':n,'cpu':r['outline']});c['missed_outline']+=1
 result={'ok':not missing,'native_pixels':False,'method':'Independent native-origin packed-weight CPU surfaces; all closed pockets and exposed continuation outline before policy changes','defaults':DEFAULTS,'coverage':[dict(view=v,clip=c,**r) for (v,c),r in sorted(coverage.items())],'missing':missing,'frames':records,'native_archive_sha256':digest(CASE/'proof/native/frames.json'),'director_diagnostic_sha256':digest(CASE/'proof/feedback3_director_native_diag.json')}
 write_json(CASE/'proof/feedback3_calibration.json',result)
 print('RR48 CPU SUPERSET NATIVE:', 'PASS' if result['ok'] else 'FAIL',len(native['holes']),'hole frames;',len(native['outline']),'outline records;',len(missing),'misses',flush=True)

if __name__=='__main__':
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--calibrate',action='store_true');a=p.parse_args()
 if a.calibrate:calibrate()
