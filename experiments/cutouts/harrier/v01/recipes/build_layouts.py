"""Build this creature's own joints, small concealed caps and editable shared skins."""
import json,subprocess,sys
from pathlib import Path
from PIL import Image,ImageDraw
C=Path('experiments/cutouts/harrier/v01')
def write(p,d):p.parent.mkdir(parents=True,exist_ok=True);p.write_text(json.dumps(d,indent=2)+'\n')
registration=json.loads((C/'recipes/registration.json').read_text())
# Fix rear upper-arm ownership before source shaft: its anatomical contour occludes the shaft.
d=json.loads((C/'source/rear_ownership.json').read_text()); e=d['priority_polygons']; arm=next(a for a in e if a[0]=='arm_r');e.remove(arm);e.insert(2,arm)
# Reassign the exposed upper-arm edge that overlapped the original overbroad shaft polygon.
m=Image.new('1',(255,255));ImageDraw.Draw(m).polygon([tuple(p) for p in arm[1]],fill=1)
src=Image.open(C/'source/rear_registered.png')
for y in range(255):
 for x in range(255):
  if src.getpixel((x,y))[3] and m.getpixel((x,y)):
   d['pixel_overrides'].append({'point':[x,y],'name':'arm_r'})
write(C/'source/rear_ownership.json',d)
subprocess.run([sys.executable,'tools/cutout_workflow.py','segment','--source',str(C/'source/rear_registered.png'),'--ownership',str(C/'source/rear_ownership.json'),'--output',str(C/'segmented/rear_repaired')],stdout=subprocess.DEVNULL,check=True)
hidden=Image.open(C/'source/hidden_registered.png')
cap_recipes=[]
for f in ['front','rear']:
 mark=registration[f+'_landmarks'];js={}
 def j(n,p,par):js[n]={'position':p,'parent':par}
 center=[145,129] if f=='front' else [119,135]
 j('root',[0,0],None);j('pelvis',center,'root');j('torso',[145,107] if f=='front' else [123,102],'pelvis');j('head',mark['skull'],'torso');j('waistcloth',center,'pelvis')
 for side in ['r','l']:
  j('upper_'+side,mark['shoulder_'+side],'torso');j('fore_'+side,mark['elbow_'+side],'upper_'+side)
  j('hand_'+side,mark['grip'] if side=='r' else mark['wrist_l'],'fore_'+side)
  j('thigh_'+side,mark['hip_'+side],'pelvis');j('shin_'+side,mark['knee_'+side],'thigh_'+side);j('foot_'+side,mark['ankle_'+side],'shin_'+side)
 j('weapon_r',mark['grip'],'hand_r')
 folder='front_complete' if f=='front' else 'rear_repaired'
 seg=json.loads((C/'segmented'/folder/'segmentation.json').read_text())
 parts=[]
 for p in seg['parts']:
  n=p['name'];bone={'spear':'weapon_r','torso':'torso','head':'head','waistcloth':'waistcloth','arm_r':'upper_r','arm_l':'upper_l','leg_r':'thigh_r','leg_l':'thigh_l'}.get(n,n)
  z={'spear':6,'torso':10,'head':12,'waistcloth':9,'arm_r':7,'arm_l':8,'leg_r':2,'leg_l':4,'foot_r':3,'foot_l':5,'hand_r':13,'hand_l':11}[n]
  parts.append(dict(p,file=f'segmented/{folder}/{n}.png',bone=bone,z_index=z,equipment_slot='cloak' if n=='waistcloth' else 'weapon' if n=='spear' else 'body'))
 # Concealed 7px bone sockets from generated shoulder/pelvis paint; exact registration.
 # Every selected pixel lies underneath opaque accepted paint at bind, preserving front rest.
 source=Image.open(C/'source'/f'{f}_registered.png')
 for side in ['r','l']:
  for family,landmark,source_box in [('shoulder','shoulder_'+side,[165,82,172,89]),('hip','hip_'+side,[165,132,172,139])]:
   patch=hidden.crop(tuple(source_box));point=mark[landmark];off=[point[0]-3,point[1]-3]
   for yy in range(7):
    for xx in range(7):
     if source.getpixel((off[0]+xx,off[1]+yy))[3]<250:patch.putpixel((xx,yy),(0,0,0,0))
   n=family+'_cap_'+side;path=C/'assets'/f/(n+'.png');path.parent.mkdir(parents=True,exist_ok=True);patch.save(path)
   parts.append({'name':n,'file':str(path.relative_to(C)),'offset':off,'bone':('upper_' if family=='shoulder' else 'thigh_')+side,'z_index':0,'equipment_slot':'body'})
   cap_recipes.append({'facing':f,'part':n,'source':'source/hidden_registered.png','source_box':source_box,'target_offset':off,'selection':'Only under bind-source alpha >=250. Small joint coverage, no visible body repaint.'})
 layout={'canvas_size':[255,255],'facing':f,'joints':js,'parts':parts,'landmarks':{'sole_r':mark['sole_r'],'sole_l':mark['sole_l'],'weapon_grip':mark['grip'],'weapon_tip':mark['spear_tip']}}
 write(C/'layouts'/f'{f}.json',layout)
 fields=[]
 for side in ['r','l']:
  fields.append({'name':f'{f}_leg_{side}','parts':['leg_'+side,'hip_cap_'+side],'bones':['thigh_'+side,'shin_'+side,'foot_'+side],'grid':[2,1],'bands':[{'center':mark['knee_'+side],'axis':[0,1],'width':8},{'center':mark['ankle_'+side],'axis':[0,1],'width':6}]})
  elbow=mark['elbow_'+side]
  axis=[-1,0] if f=='front' and side=='r' else [1,0] if f=='rear' and side=='r' else [0,1]
  fields.append({'name':f'{f}_arm_{side}','parts':['arm_'+side,'shoulder_cap_'+side],'bones':['upper_'+side,'fore_'+side],'grid':[1,1],'bands':[{'center':elbow,'axis':axis,'width':6}]})
 recipe={'facing':f,'input_layout':f'layouts/{f}.json','output_layout':f'layouts/{f}_skinned.json','fields':fields}
 write(C/'recipes'/f'{f}_skin.json',recipe)
 subprocess.run([sys.executable,'tools/cutout_workflow.py','skin',str(C),'--recipe',str(C/'recipes'/f'{f}_skin.json')],check=True)
write(C/'recipes/hidden_coverage.json',{'generated_registration':{'source':'source/hidden_generated.png','resize':[251,251],'offset':[5,1],'filter':'Lanczos'},'parts':cap_recipes})
config=json.loads((C/'cutout.json').read_text());config['clips']={'idle':{'frames':32,'duration':1.45,'loop':True,'preview_cycles':2},'walk':{'frames':40,'duration':0.48,'loop':True,'preview_cycles':2,'travel':'motion'},'attack':{'frames':40,'duration':0.65,'loop':False},'cast':{'frames':40,'duration':0.75,'loop':False}}
config['rigid_bones']=['head','hand_r','hand_l','weapon_r','foot_r','foot_l'];config['contact_feet']=['foot_r','foot_l']
config['sources']=sorted(set(config['sources']+[str(p.relative_to(C)) for sub in ['source','recipes'] for p in (C/sub).rglob('*') if p.is_file()]))
config['source_baseline']={'kind':'new_character','art_status':'original accepted front; selected generated true rear and small hidden joint material','front_original_sha256':__import__('hashlib').sha256((C/'source/front_original.png').read_bytes()).hexdigest()}
config['draw_order_parts']={f:['Skin_leg_r','Skin_hip_cap_r','foot_r','Skin_leg_l','Skin_hip_cap_l','foot_l'] for f in ['front','rear']}
write(C/'cutout.json',config)
