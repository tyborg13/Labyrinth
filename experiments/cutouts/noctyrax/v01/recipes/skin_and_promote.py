"""Build creature-specific bands with maintained skin command, then copy runtime closure."""
from pathlib import Path
import json,subprocess,shutil,hashlib
CASE=Path('experiments/cutouts/noctyrax/v01'); PROD=Path('assets/units/noctyrax_cutout')
for facing in ['front','rear']:
 layout=json.loads((CASE/f'layouts/{facing}.json').read_text())
 fields=[]
 thresholds={'front':{'fore_near':[140,165,178],'fore_far':[149,169,176],'hind_near':[149,171,181],'hind_far':[157,170,174]},'rear':{'fore_near':[148,171,183],'fore_far':[141,158,167],'hind_near':[149,176,182],'hind_far':[151,173,187]}}[facing]
 for limb in ['fore_near','fore_far','hind_near','hind_far']:
  parts=[p['name'] for p in layout['parts'] if p['name']==limb or p['name']=='cap_'+limb]
  if not parts:continue
  a,b,c=thresholds[limb]
  fields.append({'name':facing+'_'+limb,'parts':parts,'bones':['body','upper_'+limb,'lower_'+limb,'claw_'+limb],'grid':[2,1], 'bands':[{'center':[0,a],'axis':[0,1],'width':10},{'center':[0,b],'axis':[0,1],'width':12},{'center':[0,c],'axis':[0,1],'width':4}]})
 if facing=='front':
  neck_bands=[{'center':[119,119],'axis':[-1,-1],'width':18},{'center':[98,93],'axis':[-1,-1],'width':12}]
 else:neck_bands=[{'center':[0,115],'axis':[0,-1],'width':18},{'center':[0,83],'axis':[0,-1],'width':12}]
 fields.append({'name':facing+'_neck','parts':['neck'],'bones':['body','neck','head'],'grid':[2,2],'bands':neck_bands})
 fields.append({'name':facing+'_tail','parts':['tail'],'bones':['body','tail','tail_mid','tail_tip'],'grid':[2,2],'bands':[{'center':[0,172],'axis':[0,1],'width':16},{'center':[0,211],'axis':[0,1],'width':18},{'center':[155 if facing=='front' else 90,0],'axis':[-1 if facing=='front' else 1,0],'width':24}]})
 recipe={'facing':facing,'input_layout':f'layouts/{facing}.json','output_layout':f'layouts/{facing}_skinned.json','fields':fields}
 rp=CASE/f'recipes/{facing}_skin.json';rp.write_text(json.dumps(recipe,indent=2)+'\n')
 out=CASE/f'layouts/{facing}_skinned.json'
 if out.exists():out.unlink()
 recipe_copy=CASE/'recipes'/(out.stem+'.skin.json')
 if recipe_copy.exists():recipe_copy.unlink()
 subprocess.run(['python3','tools/cutout_workflow.py','skin',str(CASE),'--recipe',str(rp.resolve())],check=True,stdout=subprocess.DEVNULL)
 layout=json.loads(out.read_text())
 for part in layout['parts']+layout.get('joint_meshes',[]):
  source=CASE/part['file']; rel=facing+'/'+source.name;dest=PROD/rel;dest.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(source,dest);Path(str(dest)+'.import').write_text('[remap]\n\nimporter="keep"\n');part['file']=rel
 rest=PROD/facing/'rest.png';shutil.copy2(CASE/f'source/{facing}_rest.png',rest);Path(str(rest)+'.import').write_text('[remap]\n\nimporter="keep"\n')
 layout['rest_source']=facing+'/rest.png';layout['rest_source_sha256']=hashlib.sha256(rest.read_bytes()).hexdigest()
 (PROD/f'{facing}.json').write_text(json.dumps(layout,indent=2)+'\n')
config=json.loads((CASE/'cutout.json').read_text())
config['clips']={'idle':{'frames':32,'duration':2.4,'loop':True,'preview_cycles':2},'walk':{'frames':40,'duration':0.85,'loop':True,'preview_cycles':2,'travel':'motion'}}
for clip,seconds,contact in [('claw',1.1,.42),('breath',1.2,.66),('coil',1.2,.38),('eclipse',1.6,.38)]:
 config['clips'][clip]={'frames':40,'duration':seconds,'loop':False,'phase_curve':[[0,0],[contact,.5],[1,1]]}
config['clips']['breath']['phase_curve']=[[0,0],[.12,.30],[.18,.50],[.66,.63],[1,1]]
config['rigid_bones']=['head','claw_fore_near','claw_fore_far','claw_hind_near','claw_hind_far','wing_near','wing_far']
config['contact_feet']=['claw_fore_near','claw_fore_far','claw_hind_near','claw_hind_far']
config['sources']=sorted(str(p.relative_to(CASE)) for folder in ['source','recipes'] for p in (CASE/folder).rglob('*') if p.is_file())
config['source_baseline']={'kind':'new_character','art_status':'front unchanged; rear generated and registered','front_sha256':hashlib.sha256((CASE/'source/front_original.png').read_bytes()).hexdigest()}
(CASE/'cutout.json').write_text(json.dumps(config,indent=2)+'\n')
shutil.copy2(CASE/'motion.gd','scripts/noctyrax_cutout/motion.gd')
