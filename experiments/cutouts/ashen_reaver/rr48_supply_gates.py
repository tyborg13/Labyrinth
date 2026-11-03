"""Independent exact source, cap-boundary and painted grip gates for feedback 2."""
import numpy as np
from PIL import Image
from rr48_build import CASE,VIEWS,ROOT
from rr48_feedback1 import BASE
from rr48_feedback2_source import ROUND1,source_plan
from rr48_feedback2 import visible_images
from cutout_pipeline.cases import read_json
from maquette_motion.features import source_pixels
from maquette_motion.silhouette import components,dilate
from maquette_motion.material_palette import outline_class,rules
from rr48_feedback1 import inputs
from humanoid_cutout.gates import matrix


def supply_errors(root=CASE,production=False):
 errors=[];checks=0;caps=0
 for view in VIEWS:
  layout=read_json(root/(view+'.json' if production else f'layouts/{view}.json'));plans=source_plan(view);expected_visible=visible_images(view)
  job=read_json(ROUND1/'inputs.json')[view+'_job'];approved=np.asarray(Image.open(ROOT/job/'processed.png').convert('RGBA'));underlay=inputs(view)
  min_visible=min(p['z_index'] for p in layout['parts'] if not p.get('hidden_material'))
  visible=[source_pixels(root,p) for p in layout['parts'] if not p.get('hidden_material')]
  count=np.sum([im[...,3]>0 for im in visible],axis=0)
  if count.max()>1:errors.append(view+': visible source ownership overlaps')
  for part in layout['parts']:
   name=part['name'];image=source_pixels(root,part)
   if part.get('hidden_material'):
    if name not in plans:errors.append(view+'/'+name+': unknown hidden source');continue
    plan=plans[name];checks+=int(plan['domain'].sum());caps+=int(plan['cap'].sum())
    if np.any(image[plan['cap']]!=approved[plan['cap']]):errors.append(view+'/'+name+': cap is not approved painting at its source coordinate')
    active=plan['underlay']&(image[...,3]>0)
    if np.any(image[active]!=underlay[active]):errors.append(view+'/'+name+': re-owned underlay RGBA differs')
    if (outline_class(image,rules(ROUND1,view))&plan['cap']).any():errors.append(view+'/'+name+': outline-class cap donor')
    if not np.array_equal(image,plan['image']):errors.append(view+'/'+name+': exact underlay/cap RGBA differs')
    if part['z_index']>=min_visible:errors.append(view+'/'+name+': hidden layer is above visible paint')
    if part['bone']!=plan['bone']:errors.append(view+'/'+name+': tucked-piece bone differs')
    for kind in ('domain','underlay','cap','tuck'):
     path=root/f'ownership/feedback2_{view}_{name}_{kind}.png'
     if not path.exists():path=CASE/f'ownership/feedback2_{view}_{name}_{kind}.png'
     actual=np.asarray(Image.open(path).convert('L'))>0
     if not np.array_equal(actual,plan[kind]):errors.append(view+'/'+name+': '+kind+' outside authorized source/tuck mask')
   else:
    expected=expected_visible[name]
    if not production and np.any(image[image[...,3]>0]!=approved[image[...,3]>0]):errors.append(view+'/'+name+': visible source is not approved paint')
    if production:
     old=next(p for p in read_json(BASE/f'production/{view}.json')['parts'] if p['name']==name);expected=source_pixels(BASE/'production',old).copy()
     original=next(p for p in read_json(ROUND1/f'layouts/{view}.json')['parts'] if p['name']==name)
     before=source_pixels(ROUND1,original);changed=np.any(before!=expected_visible[name],axis=-1);expected[changed]=expected_visible[name][changed]
    if not np.array_equal(image,expected):errors.append(view+'/'+name+': unapproved visible ownership change')
  if set(plans)!={p['name'] for p in layout['parts'] if p.get('hidden_material')}:errors.append(view+': missing tucked source layer')
 return {'ok':not errors,'errors':errors,'texel_checks':checks,'cap_texels':caps,'scope':'production' if production else 'source','native_pixels':False}


def grip_errors(case,samples):
 from humanoid_cutout.canvas import for_case
 from rr48_joint_budget import pose_layers
 from humanoid_cutout.cpu_pose import CpuPose,mask_mesh
 errors=[];checks=0;motion=read_json(case/'compiled_motion.json')
 with for_case(case):
  for view in VIEWS:
   layout=read_json(case/f'layouts/{view}.json');model=CpuPose(case,layout,native_skin=True,triangle_batch_size=128)
   for name,mesh in model.meshes.items():model.meshes[name]=mask_mesh(mesh,model.image(next(p['file'] for p in layout['parts'] if p['name']==name))[...,3]>0)
   for row in samples['samples']:
    if row['view']!=view or row['kind']!='presented':continue
    release=motion.get('view_release_at',{}).get(view,{}).get(row['clip'],motion['clips'][row['clip']].get('release_at',{})).get('falchion',float('inf'))
    if row['phase']>=release:continue
    # Actual Sprite2D transforms, including the shared snapped painted grip.
    item=[];hand=[]
    from maquette_motion import pixels
    for p in layout['parts']:
     if p['logical_part'] not in ('falchion','hand_far'):continue
     im=pixels.render(model.image(p['file']),matrix(row['parts'][p['name']]['transform']))[...,3]>0
     (item if p['logical_part']=='falchion' else hand).append(im)
    blade=np.logical_or.reduce(item);fist=np.logical_or.reduce(hand);checks+=1
    if len(components(blade,8)[1])!=1 or not (dilate(blade,1)&fist).any():errors.append({'view':view,'clip':row['clip'],'frame':row['frame'],'joint':'grip','pixels':int(blade.sum()),'message':'falchion detached from painted gauntlet before release'})
 return {'ok':not errors,'errors':errors,'checks':checks,'native_pixels':False}
