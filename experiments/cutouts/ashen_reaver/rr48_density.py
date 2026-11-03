"""Scoped density records; CPU rests are explicitly uncertified until native rebake."""
import json
import re
import subprocess
import sys
import shutil
from PIL import Image
from rr48_build import ROOT,CASE,ASSETS,VIEWS
from cutout_pipeline.cases import read_json,write_json,digest
from pixel_density import metrics,strength
from humanoid_cutout.integration import record
ID='ashen_reaver_cutout'
DENSITY=ROOT/'spec/assets/board_pixel_density'

def proof_case():
 target=CASE/'proof/production_case';target.mkdir(parents=True,exist_ok=True)
 for name in ('anatomy.json','inputs.json','cutout.json','director_motion.json','compiled_motion.json','material_contract.json','feedback2_supply.json','feedback2_ownership.json','feedback2_fragments.json','feedback2_rigid_fragments.json','feedback2_joint_budgets.json','feedback3_policy.json','feedback3_joint_budgets.json','feedback3_joint_caps.json'):
  if (CASE/name).exists():shutil.copyfile(CASE/name,target/name)
 for folder in ('pieces','checks','seams','ownership','source','tucks','holes'):
  if (CASE/folder).exists():shutil.copytree(CASE/folder,target/folder,dirs_exist_ok=True)
 for view in VIEWS:
  layout=read_json(CASE/f'layouts/{view}.json');prod=read_json(ASSETS/f'humanoid_v2/{view}.json')
  for p in layout['parts']:
   source=next(q for q in prod['parts'] if q['name']==p['name'])
   shutil.copyfile(ASSETS/'humanoid_v2'/source['file'],target/p['file'])
   layout['proof_layers'][p['name']]['source_sha256']=digest(target/p['file'])
  shutil.copyfile(ASSETS/'humanoid_v2'/prod['rest_source'],target/layout['rest_source'])
  layout['motion_data']='res://'+str(target.relative_to(ROOT)/'compiled_motion.json')
  write_json(target/f'layouts/{view}.json',layout)
 # Palette authority follows each exact density-treated piece.
 from humanoid_cutout.native_defects import packed
 import numpy as np
 contract={'views':{}}
 for view in VIEWS:
  layout=read_json(target/f'layouts/{view}.json');palettes={}
  for part in layout['parts']:
   image=np.asarray(Image.open(target/part['file']).convert('RGBA'));palettes[part['name']]=list(map(int,np.unique(packed(image)[image[...,3]>0])))
  contract['views'][view]={'floor_pieces':['foot_near','foot_far','leg_near','leg_far'],'cloth_pieces':['loincloth','loincloth_back'],'interior_palettes':palettes}
 write_json(target/'material_contract.json',contract)
 write_json(target/'proof/build.json',read_json(CASE/'proof/build.json'))
 for p in target.rglob('*.png'):p.with_name(p.name+'.import').write_text('[remap]\n\nimporter="keep"\n')
 print('RR48 PRODUCTION PROOF CASE: PASS (treated parts; native proof pending)')

def seal():
 for view in VIEWS:
  path=ASSETS/f'humanoid_v2/{view}.json';layout=read_json(path);source=read_json(CASE/f'layouts/{view}.json')
  layout['strike_points']=source['strike_points'];write_json(path,layout)
 pending=record(ROOT,CASE,ASSETS)
 path=ASSETS/'integration.json';info=read_json(path)
 info.update(idle_phase_seed='slot',strike_actions=['melee','aoe'],rig_directory='humanoid_v2',contact_playback_clips=['rake','sweep','fall'],effect_anchors={n:'falchion' for n in ('rake','sweep','fall')})
 write_json(path,info)
 return pending

def register():
 path=DENSITY/'registry.json';registry=read_json(path)
 paths=sorted(str(p.relative_to(ROOT)) for v in VIEWS for p in (ASSETS/f'humanoid_v2/{v}').glob('*.png') if p.name!='rest.png')
 facings={};rests={};scale=read_json(ROOT/'data/enemies.json')['ashen_reaver'].get('art_scale',1.0)
 for view in VIEWS:
  rest=str((ASSETS/f'humanoid_v2/{view}/rest.png').relative_to(ROOT))
  # Retain the untouched calibration source across paint rebuilds. A CPU
  # composite is not a new native calibration or a certified rest rebake.
  calibration=DENSITY/'sources'/rest
  if not calibration.exists():calibration=ROOT/rest
  share=metrics(Image.open(calibration).convert('RGBA'))['orphan_share'];t=strength(share);grid=round(t/scale,2)
  facings[view]={'measurement_path':rest,'orphan_share':share,'t':t,'grid':grid,'mode':'regrid' if grid>=1.2 else 'clean'};rests[view]=[rest]
  registry['excluded_paths'][rest]={'category':'other','reason':'rr-48 derived rest, native rebake pending; recorded separately in rest_paths'}
 entry={'id':ID,'unit_type':'ashen_reaver','kind':'rig','dir':str((ASSETS/'humanoid_v2').relative_to(ROOT)),
  'rig_script':str((ASSETS/'rig.gd').relative_to(ROOT)),'paths':paths,'frames':None,'r':scale,
  'r_derivation':{'path':'data/enemies.json','key':'ashen_reaver.art_scale','expression':'unchanged catalog art_scale'},'facings':facings,'rest_paths':rests}
 partitions=CASE/'source_partitions.json'
 if partitions.exists():
  import numpy as np
  entry['source_partitions']={str((ASSETS/'humanoid_v2'/name).relative_to(ROOT)):recipe for name,recipe in read_json(partitions).items()}
  # Adopt exact director RGBA inside, the pinned accepted production outside.
  for relative,recipe in entry['source_partitions'].items():
   if 'outside' not in recipe:continue
   target=ROOT/relative;im=np.asarray(Image.open(target).convert('RGBA')).copy()
   old=recipe['outside'];previous=np.zeros((255,255,4),np.uint8);source=np.asarray(Image.open(ROOT/old['path']).convert('RGBA'));ox,oy=old['offset'];previous[oy:oy+source.shape[0],ox:ox+source.shape[1]]=source
   x,y=recipe['source_offset'];mask=np.asarray(Image.open(ROOT/recipe['mask']['path']).convert('L'))>0;local=mask[y:y+im.shape[0],x:x+im.shape[1]]
   im[~local]=previous[y:y+im.shape[0],x:x+im.shape[1]][~local];Image.fromarray(im).save(target)
 old=next((i for i,e in enumerate(registry['entries']) if e['id']==ID),None)
 if old is None:registry['entries'].append(entry)
 else:registry['entries'][old]=entry
 write_json(path,registry)
 adopted=paths+[p for group in rests.values() for p in group]
 missing=[p for p in adopted if not (DENSITY/'sources'/p).exists()]
 if missing:subprocess.run([sys.executable,'tools/process_board_density.py','--adopt',*missing],cwd=ROOT,check=True)
 if partitions.exists():subprocess.run([sys.executable,'tools/process_board_density.py','--force-adopt','--adopt',*paths],cwd=ROOT,check=True)
 subprocess.run([sys.executable,'tools/process_board_density.py','--only',ID],cwd=ROOT,check=True)
 for view in VIEWS:
  path=ASSETS/f'humanoid_v2/{view}.json';layout=read_json(path);rest=Image.new('RGBA',(255,255))
  for part in sorted(layout['parts'],key=lambda p:p['z_index']):rest.alpha_composite(Image.open(ASSETS/'humanoid_v2'/part['file']).convert('RGBA'),tuple(part['offset']))
  output=ASSETS/'humanoid_v2'/layout['rest_source'];rest.save(output);layout['rest_source_sha256']=digest(output);write_json(path,layout)
 # Only this actor's ground registration changes; no tuning or geometry rules change.
 report=read_json(CASE/'proof/build.json')['views']
 a,b=report['front']['anchor'],report['rear']['anchor'];heights=[report[v]['anchor'][1]-report[v]['head_top'] for v in VIEWS]
 path=ROOT/'scripts/actor_presentation.gd';s=path.read_text();line='"ashen_reaver": {"front": Vector2(%.8f, %.8f), "rear": Vector2(%.8f, %.8f), "height": Vector2(%.8f, %.8f)},'%(*a,*b,*heights)
 s=re.sub(r'"ashen_reaver": \{"front":.*?\},',line,s,count=1);path.write_text(s)
 if partitions.exists():
  from rr48_feedback1 import floor_contract
  motion=read_json(ASSETS/'humanoid_v2/compiled_motion.json');floors={}
  for view in VIEWS:
   path=ASSETS/f'humanoid_v2/{view}.json';layout=read_json(path);floors[view]=floor_contract(layout,motion,ASSETS/'humanoid_v2');write_json(path,layout)
  write_json(ASSETS/'humanoid_v2/compiled_motion.json',motion)
  prefix='feedback2' if (CASE/'feedback2_supply.json').exists() else 'feedback1'
  write_json(CASE/f'proof/{prefix}_production_floor.json',floors)
 seal();proof_case()
 print(f'RR48 DENSITY PAINT: PASS ({len(paths)} source cuts adopted/processed; native rest pending)')

if __name__=='__main__':
 if '--proof-case' in sys.argv:proof_case()
 elif '--seal-native' in sys.argv:
  pending=seal()
  if pending:raise ValueError('Native rest still pending: '+str(pending))
 else:register()
