"""Deterministic cuts of approved paint. This recipe never creates hidden paint."""
from pathlib import Path
import json
import shutil
import sys
import numpy as np
from PIL import Image, ImageDraw
ROOT=Path(__file__).resolve().parents[3]
sys.path[:0]=[str(ROOT/'tools'),str(ROOT)]
from cutout_pipeline.cases import read_json,write_json,digest
from humanoid_cutout.skin_layers import layer
from humanoid_cutout.compiler import compile_motion
from humanoid_cutout.promotion import promote
from humanoid_cutout.seams import build_masks
from maquette_motion.features import source_pixels
CASE=Path(__file__).with_name('rr48')
ASSETS=ROOT/'assets/units/ashen_reaver_cutout'
DIRECTOR=ROOT/'spec/peer_benchmark/staged/rr-48/motion_tracks.json'
VIEWS=('front','rear')
PARENTS={'root':None,'pelvis':'root','torso':'pelvis','head':'torso','falchion':'hand_far',
 'loincloth_mid':'pelvis','loincloth_tip':'loincloth_mid',
 'loincloth_back_mid':'pelvis','loincloth_back_tip':'loincloth_back_mid'}
MESHES={n:{'kind':'chain','bones':['pelvis',n+'_mid',n+'_tip']} for n in ('loincloth','loincloth_back')}
BONES={'loincloth':'pelvis','loincloth_back':'pelvis'}
for side in ('near','far'):
 PARENTS.update({f'upper_{side}':'torso',f'fore_{side}':f'upper_{side}',f'hand_{side}':f'fore_{side}',f'thigh_{side}':'pelvis',f'shin_{side}':f'thigh_{side}',f'foot_{side}':f'shin_{side}'})
 for name,chain in [('arm',['upper','fore','hand']),('leg',['thigh','shin','foot'])]:
  names=[f'{n}_{side}' for n in chain]
  MESHES[f'{name}_{side}']={'kind':'two_segment','joints':names,'bones':names[:2],'cuff_rows_px':4,'blend_half_width_px':4}
  BONES[f'{name}_{side}']=names[0]
GROUPS={'upper_body':['torso','head','arm_near','hand_near'],
 'weapon_arm':['arm_far','hand_far','falchion'],
 'lower_body':['pelvis','loincloth','loincloth_back','leg_near','leg_far','foot_near','foot_far']}
# Proof capacity/weight fields inherit the humanoid reference, not new art direction.
CHOSEN_DEFAULTS={'proof_canvas_size':640,'proof_source_offset':192,'diagnostic_mask_rgba':[255,0,0,255]}

def store(image,view,name):
 ys,xs=np.nonzero(image[...,3]); bounds=[int(xs.min()),int(ys.min()),int(xs.max()+1),int(ys.max()+1)] if len(xs) else [0,0,1,1]
 path=CASE/f'pieces/{view}/{name}.png';path.parent.mkdir(parents=True,exist_ok=True)
 Image.fromarray(image).crop(bounds).save(path)
 return dict(name=name,file=str(path.relative_to(CASE)),offset=bounds[:2],bbox=bounds)

def partition(view):
 reg=read_json(CASE/f'registration/{view}.json')
 paint=np.array(Image.open(ROOT/reg['painting']).convert('RGBA'))
 remaining=paint[...,3]>0; images={}; labels=np.zeros(remaining.shape,np.uint8)
 for index,(name,polygon) in enumerate(reg['ownership_polygons'].items(),1):
  mask=Image.new('1',(255,255));ImageDraw.Draw(mask).polygon([tuple(p) for p in polygon],fill=1)
  own=np.asarray(mask)&remaining
  image=np.zeros_like(paint);image[own]=paint[own];images[name]=image
  labels[own]=index;remaining[own]=False
 for name,boxes in reg.get('ownership_extra_boxes',{}).items():
  index=list(images).index(name)+1
  for x,y,r,b in boxes:
   own=np.zeros_like(remaining);own[y:b,x:r]=remaining[y:b,x:r]
   images[name][own]=paint[own];labels[own]=index;remaining[own]=False
 for name,points in reg.get('ownership_exact_pixels',{}).items():
  for x,y in points:
   if remaining[y,x]:images[name][y,x]=paint[y,x];labels[y,x]=list(images).index(name)+1;remaining[y,x]=False
 # Never silently donate unassigned pixels to a convenient body part.
 if remaining.any():
  y,x=np.nonzero(remaining);write_json(CASE/f'proof/{view}_unassigned.json',list(zip(x.tolist(),y.tolist())))
  problem=np.zeros_like(paint);problem[remaining]=[255,0,255,255];Image.fromarray(problem).save(CASE/f'proof/{view}_unassigned.png')
  raise ValueError(f'{view}: {remaining.sum()} painted pixels require explicit ownership (proof/{view}_unassigned.json)')
 return reg,paint,images,labels

def anatomy(layouts):
 upper=['torso','head','upper_near','fore_near','hand_near'];weapon=['upper_far','fore_far','hand_far','falchion']
 joins=[['head','torso'],['torso','pelvis'],['loincloth','pelvis'],['loincloth_back','pelvis'],['falchion','hand_far']]
 for side in ('near','far'):joins += [[f'arm_{side}','torso'],[f'hand_{side}',f'arm_{side}'],[f'leg_{side}','pelvis'],[f'foot_{side}',f'leg_{side}']]
 legs={s:{} for s in ('near','far')}; knees={'near_straight_deg':6,'by_view':{}}
 for view,layout in layouts.items():
  knees['by_view'][view]={}
  for side in legs:
   a,b,c=[np.asarray(layout['joints'][f'{n}_{side}']['position']) for n in ('thigh','shin','foot')]
   cross=(c-a)[0]*(b-a)[1]-(c-a)[1]*(b-a)[0]; bend=abs(float(np.degrees(np.arctan2((b-a)[0]*(c-b)[1]-(b-a)[1]*(c-b)[0],(b-a)@(c-b)))))
   legs[side][view]={'bend_side':(1 if view=='front' else -1) if bend<=6 else int(np.sign(cross))}
   knees['by_view'][view][side]={'near_straight_deg':6,'crouched_stance_deg':bend}
 return {'schema_version':1,'required_parents':PARENTS,'forbidden_joints':['belt','pauldron_near','pauldron_far','cowl','buckle'],
 'meshes':MESHES,'idle_groups':{'upper_body':{'bones':upper,'stationary':False},'weapon_arm':{'bones':weapon,'stationary':False},'lower_body':{'bones':[n for n in PARENTS if n not in upper+weapon],'stationary':True}},
 'knee_policy':knees,'legs':legs,'planted_bones':['foot_near','foot_far'],'planted_tolerance_px':0.5,'held_depth_roles':{},
 'ownership':{'names':list(layouts['front']['source_labels']), 'segments':{},'joint_pairs':joins,'free_space_owners':[]},
 'joint_continuations':{'depth_px':3,'bounded_pieces':[]},'tucks':{'base_px':3,'pieces':{}},'seam_joins':joins,'covered_surfaces':{},'intentionally_empty':{},'held_item_release_exemptions':[{'item':'falchion','clip':'death'}],
 'integration':{'production_root':'assets/units/ashen_reaver_cutout','rig_directory':'humanoid_v2',
 'production_files':['rig.gd','renderer.gd','held_drop.gd'],'binding_files':['rig.gd','renderer.gd','held_drop.gd'],
 'binding_folders':['tools/humanoid_cutout','scripts/maquette_cutout_runtime','tests/rr48'],
 'scale':{'file':'data/enemies.json','key':'ashen_reaver','field':'art_scale','default':1.0},
 'identity_registry':'spec/art_identity/registry.json','identity_id':'ashen_reaver','density_id':'ashen_reaver_cutout',
 'owner_approval':'reaver-paint-3, 2026-10-28; native rig proof pending','identity_kind':'creature','identity_entry_kind':'legacy','identity_boss':True}}

def build():
 layouts={};reports={};projections={}
 for view in VIEWS:
  reg,paint,images,labels=partition(view)
  source=CASE/f'source/{view}';source.mkdir(parents=True,exist_ok=True)
  for name in ('processed.png','processed.json'):shutil.copyfile((ROOT/reg['painting']).parent/name,source/name)
  joints={n:{'parent':PARENTS[n],'position':p} for n,p in reg['joints'].items()}
  # Explicit painter order follows the maquette's near/far ownership and paint overlaps.
  order=['loincloth_back','leg_far','foot_far','arm_far','falchion','hand_far','pelvis','leg_near','foot_near','loincloth','arm_near','hand_near','torso','head'] if view=='front' else ['loincloth','leg_near','foot_near','arm_near','hand_near','pelvis','loincloth_back','leg_far','foot_far','arm_far','falchion','hand_far','torso','head']
  parts=[];meshes=[];checks={}
  for name in order:
   part=dict(store(images[name],view,name),bone=BONES.get(name,name),logical_part=name,z_index=order.index(name))
   parts.append(part)
   if name in MESHES:meshes.append(layer(part,name,part['bbox'],joints,part['z_index'],recipe=MESHES[name]))
   check=np.zeros_like(images[name]);check[images[name][...,3]>0]=[255,0,0,255]
   path=CASE/f'checks/{view}/{name}.png';path.parent.mkdir(parents=True,exist_ok=True)
   Image.fromarray(check).crop(part['bbox']).save(path)
   checks[name]={'mask':str(path.relative_to(CASE)),'mask_offset':part['offset'],'z_index':part['z_index'],'source':part['file'],'rigid':name not in MESHES,'source_sha256':digest(CASE/part['file'])}
  feet={}
  for s in ('near','far'):
   y,x=np.nonzero(images['foot_'+s][...,3]);feet[s]=[float(x[y==y.max()].mean())+.5,float(y.max()+1)]
  anchor=np.mean(list(feet.values()),axis=0).tolist()
  y,x=np.nonzero(images['falchion'][...,3]);end=[float(x[y==y.max()].mean())+.5,float(y.max()+1)]
  forward=[(-1 if view=='front' else 1)*2/np.sqrt(5),(1 if view=='front' else -1)/np.sqrt(5)];lean=-1 if view=='front' else 1
  projections[view]={'forward':forward,'lean_sign':lean}
  layout={'version':2,'rig':'humanoid_v2','facing':view,'canvas_size':[255,255],'joints':joints,'parts':parts,'joint_meshes':meshes,
   'idle_groups':GROUPS,'held_items':{'falchion':{'hand':'hand_far','source_grip':joints['falchion']['position'],'floor_end':end,'floor_line_y':anchor[1], 'angle_sign':-1}},
   'held_drop_runtime':'res://assets/units/ashen_reaver_cutout/held_drop.gd',
   'planted_during_death':True,'planted_foot_orientation_clips':['rake','sweep','fall','hit','death'],
   'ik_chains':[],'planted_bones':['foot_near','foot_far'],'source_labels':{n:[n] for n in order},
   'features':[],'strike_points':{'falchion':end},'rest_source':f'source/{view}/processed.png','raw_rest_source':reg['painting'],
   'motion_data':'res://'+str(CASE.relative_to(ROOT)/'compiled_motion.json'),'proof_layers':checks,'proof_rest_holes':[],
   'gait_leg_scale_max':1.22}
  layouts[view]=layout
  reconstructed=np.zeros_like(paint)
  for im in images.values():reconstructed[im[...,3]>0]=im[im[...,3]>0]
  reports[view]={'tucks':[],'front_rest_mismatch_pixels':0,'rest_mismatch_pixels':int(np.any(reconstructed!=paint,axis=-1).sum()),'soles':feet,'anchor':anchor,'head_top':int(np.nonzero(images['head'][...,3])[0].min()),'paint_sha256':digest(ROOT/reg['painting'])}
  own=CASE/f'ownership/{view}.png';own.parent.mkdir(exist_ok=True);Image.fromarray(labels).save(own)
 a=anatomy(layouts);write_json(CASE/'anatomy.json',a)
 for view,l in layouts.items():
  l['proof_joint_seams']=build_masks(CASE,l,{p['name']:source_pixels(CASE,p) for p in l['parts']},a)
  write_json(CASE/f'layouts/{view}.json',l)
 shutil.copyfile(DIRECTOR,CASE/'director_motion.json')
 motion=compile_motion(CASE/'director_motion.json','ashen_reaver',layouts,projections)
 from rr48_motion import clamp_limits
 motion=clamp_limits(motion)
 write_json(CASE/'compiled_motion.json',motion)
 write_json(CASE/'cutout.json',{'character_id':'ashen_reaver','rig':'humanoid_v2','proof_geometry':{'canvas_size':640,'source_offset':192},'layouts':{v:f'layouts/{v}.json' for v in VIEWS},'direction_clips':['rake','sweep','fall'],'clips':motion['clips'],'runtime_paths':['scripts/maquette_cutout_runtime/humanoid_motion.gd','scripts/maquette_cutout_runtime/humanoid_presentation.gd']})
 write_json(CASE/'inputs.json',{**{v+'_job':f'spec/art_identity/jobs/ashen_reaver/mq21_{v}' for v in VIEWS},'design_placeholders':{},'registration':'independent source-paint landmarks; maquette labels only'})
 write_json(CASE/'proof/build.json',{'views':reports,'native_pixels':False,'director_sha256':digest(DIRECTOR),'chosen_defaults':CHOSEN_DEFAULTS})
 promote(ROOT,CASE,ASSETS/'humanoid_v2',layouts)
 from rr48_underlays import record_tucks
 record_tucks()
 for folder in (CASE,ASSETS/'humanoid_v2'):
  for p in folder.rglob('*.png'):
   if 'proof' not in p.relative_to(folder).parts:Path(str(p)+'.import').write_text('[remap]\n\nimporter="keep"\n')
 for v in VIEWS:print(f'RR48 {v.upper()} REST: {reports[v]["rest_mismatch_pixels"]} px mismatch (source ownership; native pending)')

if __name__=='__main__':build()
