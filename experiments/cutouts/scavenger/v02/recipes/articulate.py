"""Registered Scavenger limb fields; keeps every original RGBA paint pixel.

Run with --output FRESH_DIR to rebuild this version from retained source paint.
Every mesh uses the same source-space field, including adjacent cloak/arm seams.
"""
from pathlib import Path
import argparse,json,math,subprocess,sys,shutil
parser=argparse.ArgumentParser()
parser.add_argument('--case',type=Path)
parser.add_argument('--output',type=Path)
a=parser.parse_args()
root=next(p for p in Path(__file__).resolve().parents if (p/'tools/cutout_workflow.py').exists())
sys.path.insert(0,str(root/'tools'))
from cutout_pipeline.assets import segment,skin_mesh
from PIL import Image
if a.output:
    case=a.output.resolve()
    subprocess.run([sys.executable,str(root/'tools/cutout_workflow.py'),'fork',str(Path(__file__).resolve().parents[1]),'--output',str(case),'--character','scavenger'],check=True)
    # A rebuild retains source/recipe but writes new registered output names.
    destination=case/'segmented_articulated'
    if destination.exists():shutil.rmtree(destination)
else:case=a.case.resolve()
owned={'priority_polygons':[
 ['hood',[[80,0],[146,0],[143,48],[133,60],[112,67],[81,58]]],
 ['occupied_hand',[[114,67],[133,65],[150,81],[153,111],[133,119],[111,92]]],
 ['pack',[[143,20],[205,20],[205,152],[164,145],[153,122],[152,79],[137,62]]],
 ['lantern',[[58,146],[88,146],[88,188],[57,188]]],
 ['near_sleeve',[[128,57],[153,57],[163,84],[160,126],[139,125],[134,96],[122,77]]],
 ['far_arm',[[83,66],[103,69],[97,101],[86,132],[77,152],[61,154],[66,121],[74,89]]],
 ['coat_and_legs',[[0,0],[255,0],[255,255],[0,255]]]
]}
(case/'source/ownership_articulated.json').write_text(json.dumps(owned,indent=2)+'\n')
report=segment(case/'source/original.png',case/'source/ownership_articulated.json',case/'segmented_articulated')
assert report['ok']
joints={
 'root':{'parent':None,'position':[126,210]},
 'chest':{'parent':'root','position':[119,104]},
 'head':{'parent':'chest','position':[113,54]},
 'grip_shoulder':{'parent':'chest','position':[147,69]},
 'grip_forearm':{'parent':'grip_shoulder','position':[145,108]},
 'grip_hand':{'parent':'grip_forearm','position':[119,83]},
 'hanging_shoulder':{'parent':'chest','position':[88,73]},
 'hanging_forearm':{'parent':'hanging_shoulder','position':[79,111]},
 'hanging_hand':{'parent':'hanging_forearm','position':[71,145]},
 'lantern':{'parent':'hanging_hand','position':[72,159]},
 'pack':{'parent':'chest','position':[160,75]}}
part_bones={'hood':'head','occupied_hand':'grip_hand','pack':'pack','lantern':'lantern','near_sleeve':'grip_shoulder','far_arm':'hanging_forearm','coat_and_legs':'chest'}
parts=[{**p,'file':'segmented_articulated/'+p['file'],'bone':part_bones[p['name']],'z_index':i} for i,p in enumerate(report['parts'])]
layout={'canvas_size':[255,255],'facing':'front','joints':joints,'parts':parts}
def smooth(x):
 x=max(0,min(1,x));return x*x*(3-2*x)
def capsule(x,y,start,end,core,outer):
 vx,vy=end[0]-start[0],end[1]-start[1]
 t=max(0,min(1,((x-start[0])*vx+(y-start[1])*vy)/(vx*vx+vy*vy)))
 distance=math.hypot(x-start[0]-t*vx,y-start[1]-t*vy)
 return 1-smooth((distance-core)/(outer-core)),t
def weights(x,y):
 chest=smooth((185-y)/80)
 w={'root':1-chest,'chest':chest}
 def replace(f,values):
  for bone in list(w):w[bone]*=1-f
  for bone,value in values.items():w[bone]=w.get(bone,0)+f*value
 # The carried sack settles against the shoulder, without waving its fabric.
 replace(smooth((x-145)/25)*smooth((155-y)/28),{'pack':1})
 for shoulder,elbow,hand,prefix,core,outer in [([88,73],[79,111],[71,145],'hanging',6,15),([147,69],[145,108],[119,83],'grip',8,19)]:
  upper,u=capsule(x,y,shoulder,elbow,core,outer)
  lower,t=capsule(x,y,elbow,hand,core,outer)
  reach=max(upper,lower)*smooth((y-shoulder[1]+8)/19)
  forearm=smooth((y-shoulder[1]-12)/27) if lower<=upper else 1
  terminal=smooth((t-.18)/.60) if lower>upper else 0
  replace(reach,{prefix+'_shoulder':1-forearm,prefix+'_forearm':forearm*(1-terminal),prefix+'_hand':forearm*terminal})
 # Rigid lantern body, with a continuous transition across its metal hook.
 replace((1-smooth((abs(x-72)-9)/9))*smooth((y-146)/13)*(1-smooth((y-187)/8)),{'lantern':1})
 head=smooth((82-y)/24)*(1-smooth((abs(x-112)-24)/19))
 replace(head,{'head':1})
 return {name:round(w.get(name,0),8) for name in joints}
meshes=[]
for part in parts:
 with Image.open(case/part['file']) as image:
  mesh=skin_mesh(part,image.size,{'name':'registered_articulated_body','bones':['root'],'bands':[],'grid':[2,2]})
 mesh['weights']={name:[] for name in joints}
 for x,y in mesh['vertices']:
  for name,value in weights(x,y).items():mesh['weights'][name].append(value)
 meshes.append(mesh)
layout['joint_meshes']=meshes
(case/'layouts/front_articulated.json').write_text(json.dumps(layout,separators=(',',':'))+'\n')
config=json.loads((case/'cutout.json').read_text())
config['layouts']={'front':'layouts/front_articulated.json'}
config['clips']={'idle':{'frames':60,'duration':1.8,'loop':True,'preview_cycles':2}}
config['rigid_bones']=['root','head','grip_hand','hanging_hand','lantern','pack']
config['sources']=sorted(set(config['sources']+['recipes/articulate.py','recipes/registration_v02.json','source/ownership_articulated.json','segmented_articulated/segmentation.json']))
(case/'cutout.json').write_text(json.dumps(config,indent=2)+'\n')
(case/'recipes/registration_v02.json').write_text(json.dumps({'native_size':[255,255],'joint_landmarks':joints,'paint':'Unchanged original RGBA, manually registered semantic partitions; exact neutral reconstruction.','coverage':'Shared continuous source-space field across every part. Small projected elbow/hand offsets do not expose unseen anatomy. No procedural new paint, cloth ripple or root translation.','timing':'1.8-second coordinated breath. Chest subtle, head rises/nods, elbows flex, hands/pack settle with a short physical lag. Arm and head motion oppose, so this cannot reduce to whole-image translation.','weight_recipe':'articulate.py: same anatomical capsule fields on all mesh vertices, with rigid terminal hand/lantern/pack regions.'},indent=2)+'\n')
print(json.dumps({'parts':len(parts),'bones':len(joints),'vertices':sum(len(m['vertices']) for m in meshes),'case':str(case)}))
