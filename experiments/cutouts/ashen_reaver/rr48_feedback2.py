"""Feedback 2: registered underlay tucks, approved interior caps and rest ownership."""
from copy import deepcopy
import numpy as np
from PIL import Image
from rr48_build import CASE,ASSETS,ROOT,VIEWS,MESHES
from rr48_feedback1 import BASE,air_reference,floor_contract
from rr48_feedback2_source import ROUND1,snapshot,source_plan
from cutout_pipeline.cases import read_json,write_json,digest
from maquette_motion.features import source_pixels
from maquette_motion.silhouette import holes,dilate
from humanoid_cutout.skin_layers import layer
from humanoid_cutout.promotion import promote


def visible_images(view):
 layout=read_json(ROUND1/f'layouts/{view}.json');images={p['name']:source_pixels(ROUND1,p) for p in layout['parts'] if not p.get('hidden_material')}
 originals={n:im.copy() for n,im in images.items()}
 for row in read_json(CASE/'feedback2_fragments.json')['fragments']:
  if row['view']!=view:continue
  x,y=np.asarray(row['texels']).T;images[row['source']][y,x]=0
  if row['target']:images[row['target']][y,x]=originals[row['source']][y,x]
 ledger=CASE/'feedback2_rigid_fragments.json'
 if ledger.exists():
  for row in read_json(ledger)['fragments']:
   if row['view']!=view or row['source'] not in images:continue
   x,y=np.asarray(row['texels']).T;images[row['source']][y,x]=0
   if row['target']:images[row['target']][y,x]=originals[row['source']][y,x]
 ledger=CASE/'feedback2_ownership.json'
 if ledger.exists():
  for row in read_json(ledger)['fragments']:
   if row['view']!=view or row['hidden']:continue
   x,y=np.asarray(row['texels']).T;images[row['source']][y,x]=0
   if row['target']:images[row['target']][y,x]=np.asarray(row['rgba'],np.uint8)
 return images


def bounds_for(image,original):
 y,x=np.nonzero(image[...,3]);bounds=[int(x.min()),int(y.min()),int(x.max()+1),int(y.max()+1)] if len(x) else [0,0,2,2]
 if len(x):
  for axis in (0,1):
   bounds[axis]=max(0,bounds[axis]-(bounds[axis]-original['bbox'][axis])%2)
   bounds[axis+2]=min(255,bounds[axis+2]+(original['bbox'][axis]-bounds[axis+2])%2)
 return bounds


def store(view,layout,part,image,original,hidden,skinned):
 name=part['name'];bounds=bounds_for(image,original);part.update(bbox=bounds,offset=bounds[:2]);part.setdefault('presentation_anchor',original.get('presentation_anchor',original['offset']))
 path=CASE/f'pieces/{view}/{name}.png';Image.fromarray(image).crop(bounds).save(path);part['file']=str(path.relative_to(CASE))
 check=np.zeros_like(image);check[image[...,3]>0]=[255,255 if hidden else 0,0,255]
 cp=CASE/f'checks/{view}/{name}.png';Image.fromarray(check).crop(bounds).save(cp)
 layout['proof_layers'][name]={'mask':str(cp.relative_to(CASE)),'mask_offset':bounds[:2],'z_index':part['z_index'],'source':part['file'],'rigid':not skinned,'source_sha256':digest(path)}
 if skinned:layout['joint_meshes'].append(layer(part,part['logical_part'],original['bbox'],layout['joints'],part['z_index'],hidden,recipe=MESHES[part['logical_part']]))


def apply():
 snapshot();partitions={};receipt={};layouts={};build=read_json(ROUND1/'proof/build.json')
 for view in VIEWS:
  old=read_json(ROUND1/f'layouts/{view}.json');layout=deepcopy(old);visible=[p for p in layout['parts'] if not p.get('hidden_material')]
  layout['parts']=list(visible);layout['joint_meshes']=[];layout['proof_layers']={};layout['source_labels']={p['name']:[p['name']] for p in visible}
  for names in layout['idle_groups'].values():names[:]=[n for n in names if not n.startswith(('hidden_','cap_'))]
  originals={p['name']:p for p in old['parts'] if not p.get('hidden_material')};images=visible_images(view);plans=source_plan(view);receipt[view]={}
  grip=layout['held_items']['falchion']['source_grip'];layout['held_items']['falchion']['lock_presented_grip']=True
  for part in visible:
   name=part['name'];original=originals[name]
   if name in ('hand_far','falchion'):part['presentation_anchor']=grip
   store(view,layout,part,images[name],original,False,name in MESHES)
   before=source_pixels(ROUND1,original);changed=np.any(before!=images[name],axis=-1)
   mp=CASE/f'ownership/feedback2_{view}_{name}.png';Image.fromarray(changed.astype('uint8')*255).save(mp)
   prior=next(p for p in read_json(BASE/f'production/{view}.json')['parts'] if p['name']==name)
   baseline=BASE/'production'/prior['file']
   partitions[f'{view}/{name}.png']={'mask':{'path':str(mp.relative_to(ROOT)),'sha256':digest(mp)},'source_offset':part['offset'],'outside':{'path':str(baseline.relative_to(ROOT)),'sha256':digest(baseline),'offset':prior['offset']}}
  for index,(name,plan) in enumerate(plans.items()):
   logical=plan['logical'];original=originals[logical]
   part={'name':name,'bone':plan['bone'],'logical_part':logical,'hidden_material':True,'z_index':index-len(plans)}
   if name.startswith('cap_'):part['presentation_anchor']=layout['joints'][plan['bone']]['position']
   if logical in ('hand_far','falchion'):part['presentation_anchor']=grip
   store(view,layout,part,plan['image'],original,True,logical in MESHES and not name.startswith('cap_'))
   layout['parts'].append(part);layout['source_labels'][name]=[logical]
   for names in layout['idle_groups'].values():
    if logical in names:names.append(name)
   for kind in ('domain','underlay','cap','tuck'):
    path=CASE/f'ownership/feedback2_{view}_{name}_{kind}.png';Image.fromarray(plan[kind].astype('uint8')*255).save(path)
   path=CASE/f'ownership/feedback2_{view}_{name}_domain.png'
   partitions[f'{view}/{name}.png']={'mask':{'path':str(path.relative_to(ROOT)),'sha256':digest(path)},'source_offset':part['offset']}
   receipt[view][name]={'logical':logical,'bone':plan['bone'],'underlay_pixels':int((plan['underlay']&(plan['image'][...,3]>0)).sum()),'cap_pixels':int(plan['cap'].sum()),'mask':str(path.relative_to(CASE))}
  # Canonical rest includes only the director-authorized visible transfers and
  # clears. All hidden layers stay beneath every visible source texel.
  rest=Image.new('RGBA',(255,255))
  for part in sorted(layout['parts'],key=lambda p:p['z_index']):rest.alpha_composite(Image.fromarray(source_pixels(CASE,part)))
  output=CASE/f'source/feedback2_{view}_rest.png';rest.save(output);layout['rest_source']=str(output.relative_to(CASE));layout['rest_source_sha256']=digest(output)
  layout['raw_rest_source']=old['raw_rest_source'];refs=[]
  occupied=np.asarray(rest)[...,3]>0
  for index,mask in enumerate(holes(occupied)):
   rim=dilate(mask,1)&~mask;owner=max(images,key=lambda n:int((rim&(images[n][...,3]>0)).sum()))
   refs.append(air_reference(view,owner,mask,layout,f'Feedback2RestAir{index}'))
  joint_domain=np.logical_or.reduce([p['tuck'] for p in plans.values()])
  for name,plan in plans.items():
   clear=plan['underlay']&(plan['image'][...,3]==0)&~joint_domain
   if clear.any():refs.append(air_reference(view,name,clear,layout,'Feedback2Clear_'+name))
  layout['proof_rest_holes']=refs;layouts[view]=layout
  for tuck in build['views'][view]['tucks']:
   mask=np.asarray(Image.open(CASE/tuck['required_mask']).convert('L'))>0
   supplied=np.logical_or.reduce([source_pixels(CASE,p)[...,3]>0 for p in layout['parts'] if p['logical_part']==tuck['piece']])
   tuck.update(missing_pixels=int((mask&~supplied).sum()),status='PASS' if not (mask&~supplied).any() else 'FINDING_missing_interior_cap')
   tuck.pop('owner_bindings',None)
   # Outline texels are never cap donors. Retain their approved visible cover
   # ownership, as in the rr-42 directed-clear rebind; posed holes stay strict.
   bindings={}
   for y,x in np.argwhere(mask&~supplied):
    candidates=[p for p in visible if images[p['name']][y,x,3]]
    if candidates:
     owner=max(candidates,key=lambda p:p['z_index'])['name'];bindings.setdefault(owner,[]).append([int(x),int(y)]);supplied[y,x]=True
   if bindings:tuck['owner_bindings']=[{'part':n,'texels':uv} for n,uv in bindings.items()]
   tuck.update(missing_pixels=int((mask&~supplied).sum()),status='PASS' if not (mask&~supplied).any() else 'FINDING_missing_interior_cap')
  build['views'][view]['not_applicable_tucks']=[t for t in build['views'][view]['tucks'] if not t['required_pixels']]
  build['views'][view]['tucks']=[t for t in build['views'][view]['tucks'] if t['required_pixels']]
 build.update(build['views']['front']);write_json(CASE/'proof/build.json',build)
 # Recompile derived policy on the accepted director targets, never on a prior
 # search result. Raw director_motion.json remains untouched.
 motion=read_json(ROUND1/'compiled_motion.json');motion.pop('painted_budget_clamps',None)
 floors={v:floor_contract(layouts[v],motion) for v in VIEWS}
 budget=CASE/'feedback2_joint_budgets.json'
 if budget.exists():
  from rr48_budget_search import scaled
  record=read_json(budget)
  for profile in record['profiles']:
   if profile['status']=='measured_and_clamped':motion=scaled(motion,profile['clip'],profile['scale'],profile['group'])
  motion['painted_budget_clamps']=record['clamps']
 for view,layout in layouts.items():write_json(CASE/f'layouts/{view}.json',layout)
 write_json(CASE/'compiled_motion.json',motion);write_json(CASE/'source_partitions.json',partitions)
 write_json(CASE/'feedback2_supply.json',{'views':receipt,'rule':'exact underlay in vacated footprint and own tuck; exact approved interior cap in own tuck; rigid elbow band uses existing 3 px tuck depth','native_pixels':False})
 write_json(CASE/'proof/feedback2_floor.json',floors)
 from humanoid_cutout.native_defects import packed
 contract=read_json(CASE/'material_contract.json')
 for view,layout in layouts.items():contract['views'][view]['interior_palettes']={p['name']:list(map(int,np.unique(packed(source_pixels(CASE,p))[source_pixels(CASE,p)[...,3]>0]))) for p in layout['parts']}
 write_json(CASE/'material_contract.json',contract)
 inputs=read_json(CASE/'inputs.json');inputs['feedback2']={'underlay':'Exact opaque underlay in own tuck and vacated footprints; transparent vacated texels are background','caps':'Exact approved interior source texels, registered elbow/grip bands','ownership':'Exact rest-contact transfers recorded in feedback2 ownership ledgers','floor':'Keyed direction; 95 degree bound; stop at second support'};write_json(CASE/'inputs.json',inputs)
 anatomy=read_json(CASE/'anatomy.json');anatomy['integration']['owner_approval']='reaver-paint-3; director rr-48 feedback 2 source reuse; native motion judgment pending';write_json(CASE/'anatomy.json',anatomy)
 promote(ROOT,CASE,ASSETS/'humanoid_v2',layouts)
 for root in (CASE/'pieces',CASE/'checks',ASSETS/'humanoid_v2'):
  for path in root.rglob('*.png'):path.with_name(path.name+'.import').write_text('[remap]\n\nimporter="keep"\n')
 print('RR48 FEEDBACK 2 SOURCE: exact underlay tucks and approved interior caps; floor follows keyed direction')

if __name__=='__main__':apply()
