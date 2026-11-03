"""Native round-two clean/overlay beside final CPU clean/underlay-air overlay."""
import numpy as np
from PIL import Image,ImageDraw
from rr48_build import CASE
from rr48_feedback3_cpu import model
from rr48_joint_budget import pose_layers
from cutout_pipeline.cases import read_json,write_json
from humanoid_cutout.canvas import for_case
from humanoid_cutout.native_frames import load_frame

DEFAULTS={'padding_px':16,'gutter_px':8,'matte_rgba':[30,30,36,255],'tear_rgba':[255,0,190,255],'air_rgba':[40,220,255,255]}

def overlay(im,holes,air=()):
 im=im.copy();draw=ImageDraw.Draw(im)
 for rows,colour in [(air,DEFAULTS['air_rgba']),(holes,DEFAULTS['tear_rgba'])]:
  for r in rows:
   a,b,c,d=r['bbox'];draw.rectangle([a,b,c-1,d-1],outline=tuple(colour))
 return im

def sheets():
 case=CASE/'proof/production_case';native=CASE/'proof/native';manifest=read_json(native/'frames.json');old=read_json(CASE/'proof/feedback3_director_native_diag.json');sweep=read_json(case/'proof/feedback3_sweep.json');samples=read_json(case/'proof/raster_samples.json');motion=read_json(case/'compiled_motion.json')
 targets=[('front','sweep',20),('front','rake',20),('front','fall',29),('front','death',90),('rear','sweep',12),('rear','fall',20)]
 targets += [('front','move',i) for i in range(0,round(motion['clips']['move']['seconds']*60),4)]
 output=CASE/'proof/seam_cpu/feedback3';output.mkdir(parents=True,exist_ok=True);records=[]
 with for_case(case):
  models={v:model(case,v) for v in ('front','rear')}
  for view,clip,index in targets:
   native_row=next(r for r in manifest['frames'] if (r['view'],r['clip'],r['frame'])==(view,clip,index));before=load_frame(native/native_row['file']).convert('RGBA')
   row=next(r for r in samples['samples'] if (r['view'],r['clip'],r['frame'])==(view,clip,index));layers,_=pose_layers(models[view],row,motion);after=Image.new('RGBA',before.size)
   for _,im,_ in sorted(layers,key=lambda r:r[0]['z_index']):after.alpha_composite(Image.fromarray(im))
   key=lambda r:(r['view'],r['clip'],r['frame'])==(view,clip,index)
   holes=[p for r in old['holes'] if key(r) for p in r['pockets']];new=[r for r in sweep['remaining_tears'] if key(r)];air=[r for r in sweep['natural_negative_space'] if key(r)]
   panels=[before,overlay(before,holes),after,overlay(after,new,air)];alpha=(np.asarray(before)[...,3]>0)|(np.asarray(after)[...,3]>0);y,x=np.nonzero(alpha);pad=DEFAULTS['padding_px'];box=[max(0,int(x.min())-pad),max(0,int(y.min())-pad),min(before.width,int(x.max()+1)+pad),min(before.height,int(y.max()+1)+pad)];w,h=box[2]-box[0],box[3]-box[1]
   sheet=Image.new('RGBA',(4*w+3*DEFAULTS['gutter_px'],h),tuple(DEFAULTS['matte_rgba']))
   for i,im in enumerate(panels):sheet.alpha_composite(im.crop(box),(i*(w+DEFAULTS['gutter_px']),0))
   path=output/f'{view}_{clip}_{index:03d}.png';sheet.save(path);records.append({'view':view,'clip':clip,'frame':index,'file':str(path.relative_to(CASE)),'old_native_pockets':len(holes),'new_tears':len(new),'natural_air_pockets':len(air)})
 write_json(CASE/'proof/feedback3_sheets.json',{'sheets':records,'native_pixels':False,'panels':['round2 native clean','round2 native holes','final production CPU clean','final CPU tears magenta, inverse-underlay air cyan'],'defaults':DEFAULTS})
 print('RR48 FEEDBACK 3 CPU SHEETS: PASS (%d sheets; six native worst frames and every fourth front move frame)'%len(records))

if __name__=='__main__':sheets()
