"""Independent real-renderer lantern-floor proof."""
import math
import numpy as np
from PIL import Image
from cutout_pipeline.cases import read_json
from humanoid_cutout.gates import matrix
from humanoid_cutout.native_frames import load_frame
VIEWS=("front","rear")
FLOAT_TOLERANCE_PX=.0001
def native_floor_errors(root,capture):
 manifest=read_json(capture/'frames.json');errors=[];checks=0
 layouts={v:read_json(root/f'layouts/{v}.json') for v in VIEWS};motion=read_json(root/'compiled_motion.json')
 for view,layout in layouts.items():
  if layout['held_items']['lantern']['painted_floor']['status']!='PASS':errors.append(view+': director floor-direction decision pending; contact alone is not flat-pose approval')
 for record in manifest['pieces']:
  if record['clip']!='death':continue
  candidate=next((p for p in layouts[record['view']]['parts'] if p['name']==record['name']),None)
  if candidate is None or candidate['logical_part']!='lantern':continue
  view=record['view'];phase=record['frame']/max(1,round(motion['clips']['death']['seconds']*60)-1)
  if phase<motion['view_held_drops'][view]['death']['lantern']['land']:continue
  part=candidate
  image=np.asarray(Image.open(root/part['file']).convert('RGBA'));y,x=np.nonzero(image[...,3]);points=np.concatenate([np.column_stack((x+dx,y+dy)) for dx,dy in ((0,0),(1,0),(0,1),(1,1))])
  transform=matrix(record['transform']);heights=points[:,0]*transform[1,0]+points[:,1]*transform[1,1]+transform[1,2];floor=layouts[view]['held_items']['lantern']['floor_line_y'];checks+=1
  if part['name']=='lantern' and abs(float(heights.max())-floor)>FLOAT_TOLERANCE_PX:errors.append(f'{view}/death/{record["frame"]}: native painted-cell support differs from floor')
  if float(heights.max())>floor+FLOAT_TOLERANCE_PX:errors.append(f'{view}/death/{record["frame"]}: native grip/blade cells below floor')
  angle=math.degrees(math.atan2(transform[1,0],transform[0,0]))
  if layouts[view]['held_items']['lantern']['painted_floor'].get('keyed_direction',0)*angle < -FLOAT_TOLERANCE_PX:errors.append(view+': reversed keyed native floor path')
  native=np.asarray(load_frame(capture/record['file']).convert('RGBA'));ny,_=np.nonzero(native[...,3])
  # Raster pixel centres must never be beneath the continuous source-space
  # floor. Exact contact itself is checked on the captured Sprite2D transform.
  if len(ny) and (ny+.5>floor+192+FLOAT_TOLERANCE_PX).any():errors.append(f'{view}/death/{record["frame"]}: native pixels below floor')
  if not len(ny):errors.append(f'{view}/death/{record["frame"]}: empty native lantern')
  if phase==1 and abs(math.degrees(math.atan2(transform[1,0],transform[0,0]))-layouts[view]['held_items']['lantern']['painted_floor']['limit_deg'])>FLOAT_TOLERANCE_PX:errors.append(view+': terminal native support angle differs')
 if 'death' not in manifest.get('clip_scope',['death']):return {'ok':True,'errors':[],'checks':0,'scope':'death not captured'}
 if not checks:errors.append('Native death floor samples absent')
 return {'ok':not errors,'errors':errors,'checks':checks,'native_pixels':bool(manifest.get('native_pixels',False))}
