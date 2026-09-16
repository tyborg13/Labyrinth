from pathlib import Path
import json,shutil,hashlib,subprocess,sys
import argparse
parser=argparse.ArgumentParser(description="Rebuild the Scavenger case from retained original paint into a fresh directory")
parser.add_argument("--output",type=Path,required=True)
args=parser.parse_args()
root=Path(__file__).resolve().parents[5]
case=args.output.resolve()
if case.exists(): raise SystemExit("Output must be a fresh directory")
subprocess.run([sys.executable,str(root/'tools/cutout_workflow.py'),'init','--character','scavenger','--facings','front','--output',str(case)],check=True)
import os
os.chdir(root)
for name in ['source','recipes','layouts']: (case/name).mkdir(exist_ok=True)
source=Path(__file__).resolve().parents[1]/'source/original.png'
shutil.copy2(source,case/'source/original.png')
own={'priority_polygons':[
 ['hood',[[80,0],[146,0],[143,48],[133,60],[112,67],[81,58]]],
 ['occupied_hand',[[114,67],[133,65],[150,81],[153,111],[133,119],[111,92]]],
 ['pack',[[143,20],[205,20],[205,152],[164,145],[153,122],[152,79],[137,62]]],
 ['lantern',[[58,146],[88,146],[88,188],[57,188]]],
 ['coat',[[0,0],[255,0],[255,255],[0,255]]]
]}
(case/'source/ownership.json').write_text(json.dumps(own,indent=2)+'\n')
subprocess.run([sys.executable,'tools/cutout_workflow.py','segment','--source',str(case/'source/original.png'),'--ownership',str(case/'source/ownership.json'),'--output',str(case/'segmented')],check=True)
parts=json.loads((case/'segmented/segmentation.json').read_text())['parts']
joints={'root':{'parent':None,'position':[126,210]},'chest':{'parent':'root','position':[122,104]},'head':{'parent':'chest','position':[113,54]}}
layout={'canvas_size':[255,255],'facing':'front','joints':joints,'parts':[{**p,'file':'segmented/'+p['file'],'bone':'head' if p['name']=='hood' else 'chest','z_index':i} for i,p in enumerate(parts)]}
(case/'layouts/front.json').write_text(json.dumps(layout,indent=2)+'\n')
recipe={'facing':'front','input_layout':'layouts/front.json','output_layout':'layouts/front_skin.json','fields':[{'name':'continuous_breath','parts':[p['name'] for p in parts],'bones':['root','chest','head'],'grid':[2,2],'bands':[{'center':[126,178],'axis':[0,-1],'width':70},{'center':[116,69],'axis':[0,-1],'width':32}]}]}
(case/'recipes/skin.json').write_text(json.dumps(recipe,indent=2)+'\n')
subprocess.run([sys.executable,'tools/cutout_workflow.py','skin',str(case),'--recipe',str(case/'recipes/skin.json')],check=True)
config=json.loads((case/'cutout.json').read_text())
config['clips']={'idle':{'frames':48,'duration':2.5,'loop':True,'preview_cycles':2}}
config['rigid_bones']=['root','head']; config['sources']+=['source/original.png','source/ownership.json','recipes/build_case.py','recipes/registration.json','segmented/segmentation.json']
config['source_baseline']={'kind':'existing_production_paint','path':'assets/art/npcs/scavenger.png','sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'art_status':'native 255px source, unchanged RGBA; all ownership reconstructs exactly'}
(case/'cutout.json').write_text(json.dumps(config,indent=2)+'\n')
(case/'recipes/registration.json').write_text(json.dumps({'native_size':[255,255],'landmarks':{'hood_apex':[109,11],'neck':[113,54],'near_shoulder':[147,68],'occupied_grip':[120,84],'belt':[110,121],'lantern_hook':[75,152],'left_sole':[94,230],'right_sole':[144,244]},'hidden_coverage':'No newly exposed anatomy. All partitions share a continuous source-space field; no part rotates away from the original painting. The lower legs remain planted.','timing':'2.5 second coordinated breath. Chest rises 0.9 native pixels; head adds 0.65. No cloth ripple, rotation, global sprite translation or new view.'},indent=2)+'\n')
shutil.copy2(__file__,case/'recipes/build_case.py')
(case/'motion.gd').write_text('''extends RefCounted
## Small coordinated breath with planted lower body, carried pack and steady grip.
static func sample_pose(clip: String, phase: float, layout: Dictionary, _facing: String) -> Dictionary:
\tif clip != "idle": return {}
\tvar breath: float = (1.0 - cos(TAU * phase)) * 0.5
\tvar pose: Dictionary = {}
\tfor name: String in layout["joints"]:
\t\tvar joint: Dictionary = layout["joints"][name]
\t\tvar point := Vector2(joint["position"][0], joint["position"][1])
\t\tif joint["parent"] != null:
\t\t\tvar parent: Array = layout["joints"][joint["parent"]]["position"]
\t\t\tpoint -= Vector2(parent[0], parent[1])
\t\tif name == "chest": point.y -= 0.9 * breath
\t\tif name == "head": point.y -= 0.65 * breath
\t\tpose[name] = {"position": point}
\treturn pose
''')
