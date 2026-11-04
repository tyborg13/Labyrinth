"""Independent exact-paint, root-relative follow and painted-floor oracles."""
import math
import numpy as np
from PIL import Image
from rr48_build import CASE,ASSETS,VIEWS
from rr48_feedback1 import BASE,MOVERS,RECEIVERS,inputs
from cutout_pipeline.cases import read_json
from humanoid_cutout.gates import matrix
from maquette_motion.features import source_pixels
from humanoid_cutout.native_frames import load_frame

FLOAT_TOLERANCE_PX=.0001


def underlay_errors(root=CASE,production=False):
 if (CASE/'feedback2_supply.json').exists():
  from rr48_supply_gates import supply_errors
  return supply_errors(root,production)
 errors=[];checks=0
 for view in VIEWS:
  layout=read_json(root/(view+'.json' if production else f'layouts/{view}.json'));paint=inputs(view)
  authority=np.logical_or.reduce([np.asarray(Image.open(BASE/f'masks/{view}_{n}.png').convert('L'))>0 for n in MOVERS])
  supplied=np.zeros_like(paint)
  for part in layout['parts']:
   image=source_pixels(root,part)
   if part.get('hidden_material'):
    domain=np.asarray(Image.open(CASE/f'ownership/feedback1_{view}_{part["name"]}.png').convert('L'))>0
    if np.any(domain & ~authority):errors.append(view+'/'+part['name']+': underlay authority outside requested vacated footprint')
    checks+=int(domain.sum())
    if np.any(image[domain]!=paint[domain]):errors.append(view+'/'+part['name']+': director RGBA differs, including transparent clears')
    if np.any(image[~domain]):errors.append(view+'/'+part['name']+': paint outside authorized footprint')
    supplied[domain]=image[domain]
   else:
    before=read_json(BASE/f'production/{view}.json') if production else read_json(BASE/f'layouts/{view}.json')
    previous=next(p for p in before['parts'] if p['name']==part['name'])
    old=source_pixels(BASE/'production' if production else BASE,previous)
    if not np.array_equal(image,old):errors.append(view+'/'+part['name']+': accepted visible paint changed')
  if not np.array_equal(supplied[authority],paint[authority]):errors.append(view+': incomplete director authority')
 return {'ok':not errors,'errors':errors,'texel_checks':checks,'scope':'production' if production else 'source','native_pixels':False}


def floor_errors(root,samples,production=False):
 errors=[];checks=0;final={}
 for view in VIEWS:
  layout=read_json(root/(view+'.json' if production else f'layouts/{view}.json'));part=next(p for p in layout['parts'] if p['name']=='falchion')
  # Derive the independent silhouette from the actual piece, not the contract's
  # hull or floor angle. Every opaque texel contributes all four cell corners.
  opaque=np.logical_or.reduce([source_pixels(root,dict(p,**{k:p['release_texture'][k] for k in ('file','offset','bbox')}) if 'release_texture' in p else p)[...,3]>0 for p in layout['parts'] if p['logical_part']=='falchion']);y,x=np.nonzero(opaque);bind=np.asarray(layout['joints']['falchion']['position']);points=np.concatenate([np.column_stack((x+dx,y+dy)) for dx,dy in ((0,0),(1,0),(0,1),(1,1))])-bind
  floor=layout['held_items']['falchion']['floor_line_y'];data=read_json(root/'compiled_motion.json');land=data['view_held_drops'][view]['death']['falchion']['land']
  for row in samples['samples']:
   if row['view']!=view or row['clip']!='death' or row['phase']<land:continue
   bone=matrix(row['bones']['falchion']['global']);heights=points[:,0]*bone[1,0]+points[:,1]*bone[1,1]+bone[1,2];lowest=float(heights.max());checks+=1
   angle=math.degrees(math.atan2(bone[1,0],bone[0,0]));contract=layout['held_items']['falchion']['painted_floor']
   if contract.get('keyed_direction',0)*angle < -FLOAT_TOLERANCE_PX:errors.append(view+': reversed keyed floor path')
   if abs(lowest-floor)>FLOAT_TOLERANCE_PX:errors.append(f'{view}/{row["kind"]}/{row["phase"]}: lowest painted cell {lowest}, floor {floor}')
   if np.any(heights>floor+FLOAT_TOLERANCE_PX):errors.append(f'{view}/{row["phase"]}: painted texels below floor')
   if row['phase']==1:
    final[view]=math.degrees(math.atan2(bone[1,0],bone[0,0]))
    expected=layout['held_items']['falchion']['painted_floor']['limit_deg']
    if abs(final[view]-expected)>FLOAT_TOLERANCE_PX:errors.append(view+': terminal floor support angle differs')
    support=points[np.abs(heights-floor)<=FLOAT_TOLERANCE_PX]
    if contract.get('second_support_reached',True) and len(np.unique(support,axis=0))<2:errors.append(view+': second painted support point absent')
 return {'ok':not errors,'errors':errors,'checks':checks,'final_angle_deg':final,'native_pixels':False}


def follow_errors(samples):
 errors=[];checks=0
 for row in samples['samples']:
  if row['clip']!='move' or row['phase'] not in (0.,1.):continue
  bone=matrix(row['bones']['falchion']['global']);angle=math.degrees(math.atan2(bone[1,0],bone[0,0]));checks+=1
  if abs(angle)>.0001:errors.append(f'{row["view"]}/{row["kind"]}/{row["phase"]}: move endpoint falchion angle {angle}')
 return {'ok':not errors,'errors':errors,'checks':checks}


def native_floor_errors(root,capture):
 manifest=read_json(capture/'frames.json');errors=[];checks=0
 layouts={v:read_json(root/f'layouts/{v}.json') for v in VIEWS};motion=read_json(root/'compiled_motion.json')
 for view,layout in layouts.items():
  if layout['held_items']['falchion']['painted_floor']['status']!='PASS':errors.append(view+': director floor-direction decision pending; contact alone is not flat-pose approval')
 for record in manifest['pieces']:
  if record['clip']!='death':continue
  candidate=next((p for p in layouts[record['view']]['parts'] if p['name']==record['name']),None)
  if candidate is None or candidate['logical_part']!='falchion':continue
  view=record['view'];phase=record['frame']/max(1,round(motion['clips']['death']['seconds']*60)-1)
  if phase<motion['view_held_drops'][view]['death']['falchion']['land']:continue
  from rr48_weapon_ownership import released_part
  part=released_part(candidate,'death',phase)
  image=np.asarray(Image.open(root/part['file']).convert('RGBA'));y,x=np.nonzero(image[...,3]);points=np.concatenate([np.column_stack((x+dx,y+dy)) for dx,dy in ((0,0),(1,0),(0,1),(1,1))])
  transform=matrix(record['transform']);heights=points[:,0]*transform[1,0]+points[:,1]*transform[1,1]+transform[1,2];floor=layouts[view]['held_items']['falchion']['floor_line_y'];checks+=1
  if part['name']=='falchion' and abs(float(heights.max())-floor)>FLOAT_TOLERANCE_PX:errors.append(f'{view}/death/{record["frame"]}: native painted-cell support differs from floor')
  if float(heights.max())>floor+FLOAT_TOLERANCE_PX:errors.append(f'{view}/death/{record["frame"]}: native grip/blade cells below floor')
  angle=math.degrees(math.atan2(transform[1,0],transform[0,0]))
  if layouts[view]['held_items']['falchion']['painted_floor'].get('keyed_direction',0)*angle < -FLOAT_TOLERANCE_PX:errors.append(view+': reversed keyed native floor path')
  native=np.asarray(load_frame(capture/record['file']).convert('RGBA'));ny,_=np.nonzero(native[...,3])
  # Raster pixel centres must never be beneath the continuous source-space
  # floor. Exact contact itself is checked on the captured Sprite2D transform.
  if len(ny) and (ny+.5>floor+192+FLOAT_TOLERANCE_PX).any():errors.append(f'{view}/death/{record["frame"]}: native pixels below floor')
  if not len(ny):errors.append(f'{view}/death/{record["frame"]}: empty native falchion')
  if phase==1 and abs(math.degrees(math.atan2(transform[1,0],transform[0,0]))-layouts[view]['held_items']['falchion']['painted_floor']['limit_deg'])>FLOAT_TOLERANCE_PX:errors.append(view+': terminal native support angle differs')
 if 'death' not in manifest.get('clip_scope',['death']):return {'ok':True,'errors':[],'checks':0,'scope':'death not captured'}
 if not checks:errors.append('Native death floor samples absent')
 return {'ok':not errors,'errors':errors,'checks':checks,'native_pixels':bool(manifest.get('native_pixels',False))}
