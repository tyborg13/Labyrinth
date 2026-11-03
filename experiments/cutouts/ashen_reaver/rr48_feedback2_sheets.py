"""Diagnostic-only CPU proof at the immutable round-one worst frame indices."""
import numpy as np
from PIL import Image,ImageDraw
from rr48_build import CASE,VIEWS
from rr48_feedback2_source import ROUND1
from cutout_pipeline.cases import read_json,write_json
from humanoid_cutout.cpu_pose import CpuPose,mask_mesh
from humanoid_cutout.canvas import for_case
from rr48_joint_budget import pose_layers

DEFAULTS={'padding_px':16,'gutter_px':8,'matte_rgba':[30,30,36,255],'overlay_rgba':[255,0,190,255]}

def model(case,view):
 l=read_json(case/f'layouts/{view}.json');m=CpuPose(case,l,native_skin=True,triangle_batch_size=128)
 for n,mesh in m.meshes.items():
  selected=mask_mesh(mesh,m.image(next(p['file'] for p in l['parts'] if p['name']==n))[...,3]>0)
  if selected['triangles']:m.meshes[n]=selected
 return m

def compose(m,row,motion):
 layers,_=pose_layers(m,row,motion);image=Image.new('RGBA',layers[0][1].shape[:2][::-1])
 for p,im,_ in sorted(layers,key=lambda r:r[0]['z_index']):image.alpha_composite(Image.fromarray(im))
 return image

def overlay(image,errors):
 image=image.copy();draw=ImageDraw.Draw(image)
 for e in errors:
  box=e.get('source_space',e.get('component',{})).get('bbox')
  if box:draw.rectangle([box[0],box[1],box[2]-1,box[3]-1],outline=tuple(DEFAULTS['overlay_rgba']))
 return image

def sheets():
 target=CASE/'proof/seam_cpu/feedback2_compare';target.mkdir(parents=True,exist_ok=True);old=read_json(ROUND1/'proof/feedback1_samples.json');new=read_json(CASE/'proof/feedback2_samples.json')
 errors=read_json(CASE/'proof/feedback2_joint_measurement.json')['errors'];prior=read_json(ROUND1/'proof/feedback1_joint_measurement.json')['errors'];records=[]
 with for_case(CASE):
  for view in VIEWS:
   before=model(ROUND1,view);after=model(CASE,view)
   for frame in read_json(CASE/'proof/feedback2_worst_frames.json')['frames']:
    if frame['view']!=view:continue
    clip=frame['clip'];index=frame['frame'];key=lambda r:r['view']==view and r['clip']==clip and r['frame']==index and r['kind']=='presented'
    a=compose(before,next(r for r in old['samples'] if key(r)),read_json(ROUND1/'compiled_motion.json'));b=compose(after,next(r for r in new['samples'] if key(r)),read_json(CASE/'compiled_motion.json'))
    first=[e for e in prior if e['view']==view and e['clip']==clip and e['frame']==index];last=[e for e in errors if e['view']==view and e['clip']==clip and e['frame']==index]
    alpha=(np.asarray(a)[...,3]>0)|(np.asarray(b)[...,3]>0);y,x=np.nonzero(alpha);pad=DEFAULTS['padding_px'];box=[max(0,int(x.min())-pad),max(0,int(y.min())-pad),min(a.width,int(x.max()+1)+pad),min(a.height,int(y.max()+1)+pad)]
    panels=[a,overlay(a,first),b,overlay(b,last)];w=box[2]-box[0];h=box[3]-box[1];sheet=Image.new('RGBA',(4*w+3*DEFAULTS['gutter_px'],h),tuple(DEFAULTS['matte_rgba']))
    for i,panel in enumerate(panels):sheet.alpha_composite(panel.crop(box),(i*(w+DEFAULTS['gutter_px']),0))
    path=target/f'{view}_{clip}_{index:03d}.png';sheet.save(path);records.append({**frame,'current_findings':len(last),'panels':['round1 clean','round1 overlay','feedback2 clean','feedback2 overlay'],'file':str(path.relative_to(CASE)),'crop':box})
 write_json(CASE/'proof/feedback2_sheets.json',{'sheets':records,'native_pixels':False,'defaults':DEFAULTS});print('RR48 WORST-FRAME CPU SHEETS: PASS (%d sheets; same round-one indices)'%len(records))

if __name__=='__main__':sheets()
