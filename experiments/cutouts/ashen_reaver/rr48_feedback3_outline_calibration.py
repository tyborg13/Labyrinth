"""Replay exact dark-paint provenance against the director's native archive."""
import numpy as np
from PIL import Image
from rr48_build import CASE,ROOT,VIEWS
from rr48_feedback1 import inputs
from rr48_feedback3_cpu import model
from cutout_pipeline.cases import read_json,write_json
from humanoid_cutout.canvas import for_case
from humanoid_cutout.cpu_pose import mesh_map,mapped
from humanoid_cutout.gates import matrix
from humanoid_cutout.native_frames import load_frame
from maquette_motion.material_palette import outline_class,rules
from maquette_motion import pixels

def replay():
 case=CASE/'proof/feedback3_round2_case';rows={(r['view'],r['clip'],r['frame']):r for r in read_json(CASE/'proof/feedback3_round2_raster_samples.json')['samples']};diag=read_json(CASE/'proof/feedback3_director_native_diag.json');errors=[];records=[]
 with for_case(case):
  models={v:model(case,v) for v in VIEWS}
  for n in diag['outline']:
   _,clip,f,view,_=n['file'].split('/');row=rows[view,clip,int(f)];m=models[view];p=next(p for p in m.layout['parts'] if p['name']==n['part']);source=m.image(p['file'])
   actual=np.asarray(load_frame(CASE/'proof/native'/n['file']).convert('RGBA'));dark=outline_class(actual,rules(case,view));x,y,r,b=n['bbox'];roi=np.zeros_like(dark);roi[y:b+1,x:r+1]=True;dark&=roi
   if p['name'] in m.meshes:
    mapping=mesh_map(m.layout,row,m.meshes[p['name']],with_ties=True,native_skin=True,triangle_batch_size=128);candidates=mapped(source,mapping,with_ties=True).candidates
   else:candidates=pixels.render(source,matrix(row['parts'][p['name']]['transform']),with_ties=True).candidates
   matched=np.logical_or.reduce([np.all(actual==candidate,axis=-1) for candidate in candidates]);bad=dark&~matched
   record={**n,'verified_native_dark_pixels':int(dark.sum()),'unmatched_pixels':int(bad.sum())};records.append(record)
   if bad.any():errors.append(record)
  # The archived source itself must be exact approved paint at the same UV.
  for view,m in models.items():
   paint=np.asarray(Image.open(ROOT/read_json(case/'inputs.json')[view+'_job']/'processed.png').convert('RGBA'));underlay=inputs(view)
   for p in m.layout['parts']:
    if not p.get('hidden_material'):continue
    a,b,r,d=p['bbox'];source=m.image(p['file']);alpha=source[...,3]>0;valid=np.all(source==paint[b:d,a:r],axis=-1)|np.all(source==underlay[b:d,a:r],axis=-1)
    if np.any(alpha&~valid):errors.append({'view':view,'part':p['name'],'source_rgba_invalid':int((alpha&~valid).sum())})
 result={'ok':not errors,'records':records,'errors':errors,'native_pixels':False,'method':'Native archive pixels compared with real approved source UV candidates on native-origin CPU geometry; no global palette allowance'};write_json(CASE/'proof/feedback3_outline_calibration.json',result)
 print('RR48 NATIVE OUTLINE PROVENANCE:', 'PASS' if result['ok'] else 'FINDINGS',len(records),'records;',len(errors),'unmatched records',flush=True)

if __name__=='__main__':replay()
