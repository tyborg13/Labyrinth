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
CASE=Path(__file__).with_name('rr52')
ASSETS=ROOT/'assets/units/last_lamplighter_cutout'
DIRECTOR=ROOT/'spec/peer_benchmark/staged/rr-52/motion_tracks.json'
VIEWS=('front','rear')
PARENTS={'root':None,'pelvis':'root','torso':'pelvis','head':'torso','lantern':'hand_near',
 'robe_mid':'pelvis','robe_tip':'robe_mid',
 'robe_back_mid':'pelvis','robe_back_tip':'robe_back_mid'}
MESHES={n:{'kind':'chain','bones':['pelvis',n+'_mid',n+'_tip']} for n in ('robe','robe_back')}
BONES={'robe':'pelvis','robe_back':'pelvis'}
for side in ('near','far'):
 PARENTS.update({f'upper_{side}':'torso',f'fore_{side}':f'upper_{side}',f'hand_{side}':f'fore_{side}',f'thigh_{side}':'pelvis',f'shin_{side}':f'thigh_{side}',f'foot_{side}':f'shin_{side}'})
 for name,chain in [('arm',['upper','fore','hand']),('leg',['thigh','shin','foot'])]:
  names=[f'{n}_{side}' for n in chain]
  MESHES[f'{name}_{side}']={'kind':'two_segment','joints':names,'bones':names[:2],'cuff_rows_px':4,'blend_half_width_px':4}
  BONES[f'{name}_{side}']=names[0]
GROUPS={'upper_body':['torso','head','arm_far','hand_far'],
 'weapon_arm':['arm_near','hand_near'],
 'lower_body':['pelvis','robe','robe_back','leg_near','leg_far','foot_near','foot_far']}
# Proof capacity/weight fields inherit the humanoid reference, not new art direction.
CHOSEN_DEFAULTS={'proof_canvas_size':640,'proof_source_offset':192,'diagnostic_mask_rgba':[255,0,0,255]}

def projection(view):
 # Both facings must travel on the same board line, including tile seams.
 front=[-2/np.sqrt(5),1/np.sqrt(5)]
 return {'forward':front if view=='front' else [-value for value in front],
  'lean_sign':-1 if view=='front' else 1}

def store(image,view,name,align_to=None):
 ys,xs=np.nonzero(image[...,3]); bounds=[int(xs.min()),int(ys.min()),int(xs.max()+1),int(ys.max()+1)] if len(xs) else [0,0,1,1]
 if len(xs) and align_to is not None:
  for axis in (0,1):
   bounds[axis]=max(0,bounds[axis]-(bounds[axis]-align_to[axis])%2)
   bounds[axis+2]=min(255,bounds[axis+2]+(align_to[axis]-bounds[axis+2])%2)
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
 for name,points in reg.get('ownership_transfers',{}).items():
  x,y=np.asarray(points).T
  for other,image in images.items():image[y,x]=paint[y,x] if other==name else 0
  labels[y,x]=list(images).index(name)+1
 return reg,paint,images,labels

def anatomy(layouts):
 upper=['torso','head','upper_far','fore_far','hand_far'];weapon=['upper_near','fore_near','hand_near']
 joins=[['head','torso'],['torso','pelvis'],['robe','pelvis'],['robe_back','pelvis'],['lantern','hand_near']]
 for side in ('near','far'):joins += [[f'arm_{side}','torso'],[f'hand_{side}',f'arm_{side}'],[f'leg_{side}','pelvis'],[f'foot_{side}',f'leg_{side}']]
 names=[p['name'] for p in layouts['front']['parts'] if not p.get('hidden_material')]
 segments={};boundaries=[row[:] for row in joins]
 for side in ('near','far'):
  for part,chain in [('arm',['upper','fore','hand']),('leg',['thigh','shin','foot'])]:
   bones=[f'{n}_{side}' for n in chain];owners=bones[:2]
   names+=owners;segments[f'{part}_{side}']={'joints':bones,'owners':owners}
   boundaries += [[owners[0],owners[1]],[owners[1],bones[2]],['torso' if part=='arm' else 'pelvis',owners[0]]]
 legs={s:{} for s in ('near','far')}; knees={'near_straight_deg':6,'by_view':{}}
 for view,layout in layouts.items():
  knees['by_view'][view]={}
  for side in legs:
   a,b,c=[np.asarray(layout['joints'][f'{n}_{side}']['position']) for n in ('thigh','shin','foot')]
   cross=(c-a)[0]*(b-a)[1]-(c-a)[1]*(b-a)[0]; bend=abs(float(np.degrees(np.arctan2((b-a)[0]*(c-b)[1]-(b-a)[1]*(c-b)[0],(b-a)@(c-b)))))
   legs[side][view]={'bend_side':(1 if view=='front' else -1) if bend<=6 else int(np.sign(cross))}
   knees['by_view'][view][side]={'near_straight_deg':6,'crouched_stance_deg':bend}
 return {'schema_version':1,'required_parents':PARENTS,'forbidden_joints':['belt','pauldron_near','pauldron_far','cowl','buckle'],
 'meshes':MESHES,'idle_groups':{'upper_body':{'bones':upper,'stationary':False},'weapon_arm':{'bones':weapon,'stationary':False},'lower_body':{'bones':[n for n in PARENTS if n not in upper+weapon+['lantern']],'stationary':True}},
 'knee_policy':knees,'legs':legs,'planted_bones':['foot_near','foot_far'],'planted_tolerance_px':0.5,'held_depth_roles':{},
 'ownership':{'names':names,'segments':segments,'joint_pairs':boundaries,'free_space_owners':[]},
 'joint_continuations':{'depth_px':3,'bounded_pieces':[]},'tucks':{'base_px':3,'pieces':{}},'seam_joins':joins,'covered_surfaces':{},'intentionally_empty':{},'held_item_release_exemptions':[{'item':'lantern','clip':'death'}],
 'integration':{'production_root':'assets/units/last_lamplighter_cutout','rig_directory':'humanoid_v2',
 'production_files':['rig.gd','renderer.gd','held_drop.gd','held_contract.gd','actions.gd'],'binding_files':['rig.gd','renderer.gd','held_drop.gd','held_contract.gd','actions.gd'],
 'binding_folders':['tools/humanoid_cutout','scripts/maquette_cutout_runtime','experiments/cutouts/last_lamplighter/rr52/probes'],
 'scale':{'file':'data/enemies.json','key':'last_lamplighter','field':'art_scale','default':1.0},
 'identity_registry':'spec/art_identity/registry.json','identity_id':'last_lamplighter','density_id':'last_lamplighter_cutout',
 'owner_approval':'lamplighter-paint-3, 2026-10-29; native rig proof pending','identity_kind':'creature','identity_entry_kind':'legacy','identity_boss':True}}

def build():
 layouts={};reports={};projections={}
 for view in VIEWS:
  for folder in (CASE/f'pieces/{view}',CASE/f'checks/{view}',ASSETS/f'humanoid_v2/{view}'):
   if folder.exists():
    for path in folder.iterdir():
     if path.is_file():path.unlink()
  reg,paint,images,labels=partition(view)
  source=CASE/f'source/{view}';source.mkdir(parents=True,exist_ok=True)
  for name in ('processed.png','processed.json'):shutil.copyfile((ROOT/reg['painting']).parent/name,source/name)
  joints={n:{'parent':PARENTS[n],'position':p} for n,p in reg['joints'].items()}
  # Explicit painter order follows the maquette's near/far ownership and paint overlaps.
  order=['robe_back','leg_far','foot_far','arm_far','hand_far','pelvis','leg_near','foot_near','robe','arm_near','lantern','hand_near','torso','head'] if view=='front' else ['robe','leg_near','foot_near','arm_near','lantern','hand_near','pelvis','leg_far','foot_far','robe_back','arm_far','hand_far','torso','head']
  parts=[];meshes=[];checks={}
  for name in order:
   part=dict(store(images[name],view,name),bone=BONES.get(name,name),logical_part=name,z_index=order.index(name))
   if name in ('hand_near','lantern'):part['presentation_anchor']=joints['lantern']['position']
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
  y,x=np.nonzero(images['lantern'][...,3]);end=[float(x[y==y.max()].mean())+.5,float(y.max()+1)]
  projections[view]=projection(view)
  layout={'version':2,'rig':'humanoid_v2','facing':view,'canvas_size':[255,255],'joints':joints,'parts':parts,'joint_meshes':meshes,
   'underlay_reference_bounds':reg.get('underlay_reference_bounds',{}),
   'idle_groups':{k:list(v) for k,v in GROUPS.items()},'held_items':{'lantern':{'hand':'hand_near','source_grip':joints['lantern']['position'],'floor_end':end,'floor_line_y':anchor[1], 'angle_sign':-1,'lock_presented_grip':True,'follow_reference_bone':'pelvis','follow_hand_joint':True,'follow_zero_at_end':True,'follow_limit_deg':25.0}},
   'held_drop_runtime':'res://assets/units/last_lamplighter_cutout/held_drop.gd',
   'planted_during_death':True,'planted_foot_orientation_clips':['snuff','mourning_hook','last_procession','hit','death'],
   'ik_chains':[],'planted_bones':['foot_near','foot_far'],'source_labels':{n:[n] for n in order},
   'features':[],'strike_points':{'lantern':end},'rest_source':f'source/{view}/processed.png','raw_rest_source':reg['painting'],
   'motion_data':'res://'+str(CASE.relative_to(ROOT)/'compiled_motion.json'),'proof_layers':checks,'proof_rest_holes':[],
   'gait_leg_scale_max':1.22}
  from rr52_underlays import supply
  supply(CASE,layout,images,store,MESHES)
  layout['raw_rest_source']=f'source/{view}/processed.png'
  layouts[view]=layout
  reconstructed=np.zeros_like(paint)
  for im in images.values():reconstructed[im[...,3]>0]=im[im[...,3]>0]
  reports[view]={'tucks':read_json(CASE/f'proof/{view}_tuck_supply.json')['tucks'],'front_rest_mismatch_pixels':0,'rest_mismatch_pixels':int(np.any(reconstructed!=paint,axis=-1).sum()),'soles':feet,'anchor':anchor,'head_top':int(np.nonzero(images['head'][...,3])[0].min()),'paint_sha256':digest(ROOT/reg['painting'])}
  own=CASE/f'ownership/{view}.png';own.parent.mkdir(exist_ok=True);Image.fromarray(labels).save(own)
 a=anatomy(layouts);a['tucks']=read_json(CASE/'proof/front_tuck_supply.json')['policy'];write_json(CASE/'anatomy.json',a)
 for view,l in layouts.items():
  from rr52_air import references
  l['proof_rest_holes']=references(CASE,l,partition(view)[2],MESHES)
  l['proof_joint_seams']=build_masks(CASE,l,{p['name']:source_pixels(CASE,p) for p in l['parts']},a)
  write_json(CASE/f'layouts/{view}.json',l)
 shutil.copyfile(DIRECTOR,CASE/'director_motion.json')
 motion=compile_motion(CASE/'director_motion.json','last_lamplighter',layouts,projections)
 from rr52_motion import clamp_limits
 motion=clamp_limits(motion)
 from rr52_walk import revision
 motion,walk_author,_=revision(motion,layouts,projections)
 from rr52_floor import floor_contract
 floors={v:floor_contract(l,motion,CASE) for v,l in layouts.items()}
 for v,l in layouts.items():write_json(CASE/f'layouts/{v}.json',l)
 write_json(CASE/'proof/floor.json',floors)
 write_json(CASE/'compiled_motion.json',motion)
 write_json(CASE/'cutout.json',{'character_id':'last_lamplighter','rig':'humanoid_v2','proof_geometry':{'canvas_size':640,'source_offset':192},'layouts':{v:f'layouts/{v}.json' for v in VIEWS},'direction_clips':['snuff','mourning_hook','last_procession'],'clips':motion['clips'],'runtime_paths':['scripts/maquette_cutout_runtime/humanoid_motion.gd','scripts/maquette_cutout_runtime/humanoid_presentation.gd']})
 write_json(CASE/'inputs.json',{**{v+'_job':f'spec/art_identity/jobs/last_lamplighter/mq24_{v}' for v in VIEWS},'design_placeholders':{},'director_feedback_1':{'art_scale':1.03,'floor_support':'first second-support stop accepted','outside_rest_texels':'185 front / 265 rear accepted'},'registration':'independent source-paint landmarks; maquette labels only'})
 write_json(CASE/'proof/build.json',{**reports['front'],'views':reports,'native_pixels':False,'director_sha256':digest(DIRECTOR),'chosen_defaults':CHOSEN_DEFAULTS})
 promote(ROOT,CASE,ASSETS/'humanoid_v2',layouts)
 # Keep the protected case director unchanged; ship the explicit walk override.
 (ASSETS/'humanoid_v2/director_motion.json').write_text(json.dumps(walk_author,indent=1)+'\n')
 for view in VIEWS:
  path=ASSETS/f'humanoid_v2/{view}.json';production=read_json(path)
  for part in production['parts']+production['joint_meshes']:part.pop('paint_sources',None)
  write_json(path,production)

 for folder in (CASE,ASSETS/'humanoid_v2'):
  for p in folder.rglob('*.png'):
   if 'proof' not in p.relative_to(folder).parts:Path(str(p)+'.import').write_text('[remap]\n\nimporter="keep"\n')
 for v in VIEWS:print(f'RR52 {v.upper()} REST: {reports[v]["rest_mismatch_pixels"]} px mismatch (source ownership; native pending)')

if __name__=='__main__':build()
