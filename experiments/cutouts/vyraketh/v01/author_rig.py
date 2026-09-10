"""Dragon-specific binds, hidden paint registration and shared mesh recipes.
Run after the semantic ownership build. This file is authoring evidence only.
"""
import json,sys,hashlib,subprocess
from pathlib import Path
from PIL import Image,ImageDraw,ImageOps
ROOT=Path(__file__).resolve().parent
REPO=ROOT.parents[3]
def put(path,value):
 path.parent.mkdir(parents=True,exist_ok=True);path.write_text(json.dumps(value,indent=2)+'\n')
def point(x,y):return [x,y]
def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()
front={
 'root':(None,128,196),'body':('root',147,153),'neck':('body',128,143),'head':('neck',112,96),'jaw':('head',75,130),
 'wing_near':('body',149,135),'wing_far':('body',99,121),'tail':('root',185,155),'tail_tip':('tail',182,212),
 'fore_far':('body',101,144),'bend_fore_far':('fore_far',80,163),'claw_fore_far':('bend_fore_far',62,174),
 'fore_near':('body',153,147),'bend_fore_near':('fore_near',137,168),'claw_fore_near':('bend_fore_near',126,184),
 'hind_near':('body',178,160),'bend_hind_near':('hind_near',180,175),'claw_hind_near':('bend_hind_near',176,187),
 'hind_far':('body',150,152),'bend_hind_far':('hind_far',143,159),'claw_hind_far':('bend_hind_far',135,166),
}
rear_raw={
 'root':(None,128,196),'body':('root',156,140),'neck':('body',141,109),'head':('neck',132,62),'jaw':('head',112,65),
 'wing_near':('body',128,123),'wing_far':('body',165,120),'tail':('root',166,169),'tail_tip':('tail',180,214),
 'fore_far':('body',123,139),'bend_fore_far':('fore_far',113,150),'claw_fore_far':('bend_fore_far',101,156),
 'fore_near':('body',170,127),'bend_fore_near':('fore_near',169,133),'claw_fore_near':('bend_fore_near',164,140),
 'hind_near':('body',139,149),'bend_hind_near':('hind_near',139,173),'claw_hind_near':('bend_hind_near',119,182),
 'hind_far':('body',195,150),'bend_hind_far':('hind_far',208,177),'claw_hind_far':('bend_hind_far',224,194),
}
rear={k:(p,254-x,y) for k,(p,x,y) in rear_raw.items()}
limbs=['fore_far','fore_near','hind_far','hind_near']
coverage=[]
for facing,graph in [('front',front),('rear',rear)]:
 source=Image.open(ROOT/f'source/{facing}_registered.png').convert('RGBA')
 layout={'canvas_size':[255,255],'facing':facing,'joints':{k:{'parent':p,'position':[x,y]} for k,(p,x,y) in graph.items()},'parts':[],'landmarks':{'projection':'2:1; independent source-space joint and rigid claw support pivots','hidden_limb':'hind_far' if facing=='front' else 'fore_near','muzzle':[66,137] if facing=='front' else [146,66]}}
 # Paint depth follows actual source overlap, not bone parenting.
 layers={'tail':4,'torso':7,'neck':11,'head':15,'jaw':17,'wing_far':5,'wing_near':12,'fore_far':8,'fore_near':13,'hind_far':2,'hind_near':8,'claw_fore_far':9,'claw_fore_near':14,'claw_hind_far':3,'claw_hind_near':9}
 if facing=='rear': layers.update({'wing_far':5,'wing_near':12,'neck':8,'head':9,'jaw':10,'tail':11,'torso':7,'hind_near':13,'claw_hind_near':14,'hind_far':6,'claw_hind_far':7})
 report=json.loads((ROOT/f'segmented/{facing}_v3/segmentation.json').read_text())
 for item in report['parts']:
  name=item['name']; part={'name':name,'file':f'segmented/{facing}_v3/'+item['file'],'offset':item['offset'],'bone':'body' if name=='torso' else name,'z_index':layers[name]};layout['parts'].append(part)
 # Concealed generated surfaces are copied only beneath fully opaque accepted
 # source pixels. They never change the front rest silhouette or visible paint.
 def hidden(name,source_name,crop,target,size,bone,z,mask_polygon=None):
  original=Image.open(ROOT/'source'/source_name).convert('RGBA'); paint=original.crop(crop).resize(size,Image.Resampling.LANCZOS)
  if facing=='rear': paint=ImageOps.mirror(paint)
  mask=Image.new('1',(255,255));ImageDraw.Draw(mask).polygon(mask_polygon or [(target[0],target[1]),(target[0]+size[0],target[1]),(target[0]+size[0],target[1]+size[1]),(target[0],target[1]+size[1])],fill=1)
  count=0
  for y in range(paint.height):
   for x in range(paint.width):
    at=(target[0]+x,target[1]+y)
    if not mask.getpixel(at) or source.getpixel(at)[3]<(255 if facing=='front' else 240):paint.putpixel((x,y),(0,0,0,0))
    elif paint.getpixel((x,y))[3]:count+=1
  path=ROOT/f'assets/{facing}/{name}.png';path.parent.mkdir(parents=True,exist_ok=True);paint.save(path)
  layout['parts'].append({'name':name,'file':str(path.relative_to(ROOT)),'offset':list(target),'bone':bone,'z_index':z})
  coverage.append({'facing':facing,'part':name,'source':'source/'+source_name,'source_crop':crop,'target_offset':target,'target_size':size,'reflect_crop':facing=='rear','mask':'front original alpha 255 only; rear original alpha >=240 (generator emits near-opaque 252), within explicit patch bounds','mask_polygon':mask_polygon,'visible_px':count,'sha256':sha(path)})
 for limb in limbs:
  _,x,y=graph[limb]
  hidden('socket_'+limb,'front_hidden_alpha.png',[618,678,832,864],[x-7,y-5],(14,12),'body',0)
  hidden('cap_'+limb,'front_hidden_alpha.png',[628,711,858,941],[x-7,y-5],(14,14),limb,1)
 missing='hind_far' if facing=='front' else 'fore_near';_,fx,fy=graph['claw_'+missing];_,hx,hy=graph[missing]
 hidden(missing,'front_hidden_alpha.png',[883,807,1039,1018],[min(fx,hx)-5,min(fy,hy)-3],(abs(fx-hx)+11,abs(fy-hy)+9),missing,1)
 hidden('claw_'+missing,'front_hidden_alpha.png',[521,955,710,1095],[fx-9,fy-5],(22,17),'claw_'+missing,2)
 if facing=='front': hidden('mouth_lining','maw_interior_generated.png',[446,754,603,966],[64,129],(12,16),'head',14)
 else: hidden('mouth_lining','maw_interior_generated.png',[446,754,603,966],[139,62],(8,10),'head',8)
 fields=[]
 for limb in limbs:
  _,hx,hy=graph[limb];_,kx,ky=graph['bend_'+limb];_,fx,fy=graph['claw_'+limb]
  fields.append({'name':f'{facing}_{limb}','parts':[limb,'cap_'+limb],'bones':[limb,'bend_'+limb,'claw_'+limb],'grid':[2,2],'bands':[{'center':[kx,ky],'axis':[fx-hx,fy-hy],'width':16},{'center':[fx,fy],'axis':[fx-hx,fy-hy],'width':10}]})
 # Shared neck field keeps overlapping head/neck pixels on the same surface.
 _,nx,ny=graph['neck'];_,hx,hy=graph['head']
 fields.append({'name':f'{facing}_neck','parts':['neck','head'],'bones':['body','neck','head'],'grid':[3,2],'bands':[{'center':[nx,ny-2],'axis':[0,-1],'width':22},{'center':[hx,hy+10],'axis':[0,-1],'width':20}]})
 for wing in ['wing_near','wing_far']:
  _,wx,wy=graph[wing]
  fields.append({'name':f'{facing}_{wing}','parts':[wing],'bones':['body',wing],'grid':[3,3],'bands':[{'center':[wx,wy-5],'axis':[0,-1],'width':28}]})
 _,tx,ty=graph['tail_tip'];fields.append({'name':f'{facing}_tail','parts':['tail'],'bones':['tail','tail_tip'],'grid':[3,2],'bands':[{'center':[tx,ty-8],'axis':[0,1],'width':25}]})
 layout['landmarks']['support_pivots']={n:layout['joints']['claw_'+n]['position'] for n in limbs}
 put(ROOT/f'layouts/{facing}.json',layout)
 recipe={'facing':facing,'input_layout':f'layouts/{facing}.json','output_layout':f'layouts/{facing}_skinned_v2.json','fields':fields};put(ROOT/f'recipes/{facing}_skinned_v2.skin.json',recipe)
 config=json.loads((ROOT/'cutout.json').read_text());config['layouts'][facing]=f'layouts/{facing}.json';put(ROOT/'cutout.json',config)
 result=subprocess.run([sys.executable,str(REPO/'tools/cutout_workflow.py'),'skin',str(ROOT),'--recipe',str(ROOT/f'recipes/{facing}_skinned_v2.skin.json')],cwd=REPO,check=True)
put(ROOT/'recipes/hidden_coverage.json',coverage)
config=json.loads((ROOT/'cutout.json').read_text());config['clips']={
 'idle':{'frames':32,'duration':2.0,'loop':True,'preview_cycles':2},
 'walk':{'frames':40,'duration':0.9,'loop':True,'preview_cycles':2,'travel':'motion'},
 'maw':{'frames':40,'duration':0.85,'loop':False,'phase_curve':[[0,0],[0.42,0.55],[1,1]]},
 'kindle':{'frames':40,'duration':0.68,'loop':False,'phase_curve':[[0,0],[0.20/0.68,0.55],[1,1]]},
 'crownfire':{'frames':40,'duration':0.95,'loop':False,'phase_curve':[[0,0],[0.38,0.55],[1,1]]},
 'cinderfall':{'frames':40,'duration':1.0,'loop':False,'phase_curve':[[0,0],[0.38,0.55],[1,1]]}}
config['rigid_bones']=['head','jaw']+['claw_'+n for n in limbs];config['contact_feet']=['claw_'+n for n in limbs]
config['sources']=sorted(set(config.get('sources',[])+[str(p.relative_to(ROOT)) for folder in ['source','recipes'] for p in (ROOT/folder).rglob('*') if p.is_file()]+['build_vyraketh.py','author_rig.py']))
config['source_baseline']={'kind':'new_character','accepted_front_sha256':sha(ROOT/'source/front_original.png'),'anatomy':'crouched four-legged dragon with two wings, long neck, separate jaws and coiled tail; hidden fourth leg is occluded at rest in each painted view'}
put(ROOT/'cutout.json',config)
# Raw keep imports are deliberately retained source metadata.
for p in ROOT.rglob('*.png'):
 Path(str(p)+'.import').write_text('[remap]\n\nimporter="keep"\n')
print('Authored two 21-bone dragon layouts with registered hidden surface recipes')
