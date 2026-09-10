"""Lightning Wisp v01 ownership/registration recipe; uses maintained case tools.
No generation or hidden paint is synthesized here. Run once in this fresh case.
"""
from pathlib import Path
import json, subprocess, sys, shutil
from PIL import Image
ROOT = Path(__file__).resolve().parent
REPO = ROOT.parents[3]
def write(p, value):
 p.parent.mkdir(parents=True, exist_ok=True); p.write_text(json.dumps(value, indent=2)+'\n')
def command(*args):
 subprocess.run([sys.executable, str(REPO/'tools/cutout_workflow.py'), *map(str,args)], check=True)
# Every visible source pixel has one semantic owner. Core includes its aperture
# and interior filaments; only free outer electrical branches can articulate.
polygons = [
 ['crown', [[0,0],[254,0],[254,60],[0,60]]],
 ['tail', [[0,180],[254,180],[254,254],[0,254]]],
 ['arc_left', [[0,61],[88,61],[88,179],[0,179]]],
 ['arc_right', [[163,61],[254,61],[254,179],[163,179]]],
 ['core', [[89,61],[162,61],[162,179],[89,179]]],
]
joints = {'root': {'parent':None,'position':[127,227]},
 'core':{'parent':'root','position':[127,124]},
 'crown':{'parent':'core','position':[127,60]},
 'tail':{'parent':'core','position':[127,180]},
 'arc_left':{'parent':'core','position':[89,124]},
 'arc_right':{'parent':'core','position':[163,124]}}
fields = {'crown':([127,42],[0,-1],36),'tail':([127,200],[0,1],40),
 'arc_left':([74,124],[-1,0],30),'arc_right':([182,124],[1,0],38)}
for view in ['front','rear']:
 source=ROOT/'source'/f'{view}_registered.png'
 if not source.exists():
  if view=='front': shutil.copyfile(ROOT/'source/front_original.png',source)
  else: continue
 if (ROOT/'segmented'/view).exists(): continue
 write(ROOT/'source'/f'{view}_ownership.json',{'priority_polygons':polygons,'pixel_overrides':[]})
 command('segment','--source',source,'--ownership',ROOT/'source'/f'{view}_ownership.json','--output',ROOT/'segmented'/view)
 segmentation=json.loads((ROOT/'segmented'/view/'segmentation.json').read_text())
 parts=[]
 for p in segmentation['parts']:
  parts.append({**p,'file':f'segmented/{view}/{p["name"]}.png','bone':p['name'],'z_index':3 if p['name']=='core' else 2,'equipment_slot':'core' if p['name']=='core' else 'electrical_arcs'})
 write(ROOT/'layouts'/f'{view}.json',{'canvas_size':[255,255],'facing':view,'joints':joints,'parts':parts,'landmarks':{'hover_anchor':[127,227],'energy_core':[127,124],'aperture':[119,141] if view=='front' else None}})
 recipe={'facing':view,'input_layout':f'layouts/{view}.json','output_layout':f'layouts/{view}_skinned.json','fields':[]}
 for part,(center,axis,width) in fields.items():
  recipe['fields'].append({'name':view+'_'+part,'parts':[part],'bones':['core',part],'grid':[2,2],'bands':[{'center':center,'axis':axis,'width':width}]})
 write(ROOT/'recipes'/f'{view}_skin_input.json',recipe)
 command('skin',ROOT,'--recipe',ROOT/'recipes'/f'{view}_skin_input.json')
config=json.loads((ROOT/'cutout.json').read_text())
config['clips']={'idle':{'frames':24,'duration':1.6,'loop':True,'preview_cycles':2},
 'walk':{'frames':24,'duration':.48,'loop':True,'preview_cycles':2,'travel':'motion'},
 'attack':{'frames':36,'duration':.6,'loop':False},
 'cast':{'frames':36,'duration':.565,'loop':False,'phase_curve':[[0,0],[.22/.565,.36],[(.22+.345*4/30)/.565,.5],[1,1]]}}
config['rigid_bones']=['root','core','crown','tail','arc_left','arc_right']
config['contact_feet']=[]
config['sources']=sorted(str(p.relative_to(ROOT)) for sub in ['source','recipes'] for p in (ROOT/sub).glob('*') if p.is_file())+['build_case.py']
config['source_baseline']={'kind':'new_character','art_status':'accepted front preserved; generated rear registered once','production_front':'res://assets/placeholders/units/lightning_wisp.png','anatomy':'floating energy core with four outer electrical branches; six bones; no humanoid limbs'}
write(ROOT/'cutout.json',config)
for p in ROOT.rglob('*.png'):
 Path(str(p)+'.import').write_text('[remap]\n\nimporter="keep"\n')
