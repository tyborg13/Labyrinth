"""Select actual generated hidden pelvis/thigh paint beneath existing cloth owners."""
import json,hashlib,subprocess,sys
from pathlib import Path
from PIL import Image
C=Path('experiments/cutouts/harrier/v02')
def write(p,d):p.parent.mkdir(parents=True,exist_ok=True);p.write_text(json.dumps(d,indent=2)+'\n')
new=Image.open(C/'source/rear_pelvis_generated.png').convert('RGBA')
bbox=new.getchannel('A').point(lambda a:255 if a>32 else 0).getbbox()
# Explicit component fit: source bone bbox -> rear 44x41 with source-space offset.
small=new.crop(bbox).resize((44,41),Image.Resampling.LANCZOS)
reg=Image.new('RGBA',(255,255));reg.alpha_composite(small,(96,120));reg.save(C/'source/rear_pelvis_registered.png')
records=[]
for f in ['front','rear']:
 cfg=json.loads((C/'cutout.json').read_text());lp=C/cfg['layouts'][f];layout=json.loads(lp.read_text())
 p=next(p for p in layout['parts'] if p['name']=='waistcloth')
 mask=Image.new('RGBA',(255,255));mask.alpha_composite(Image.open(C/p['file']),tuple(p['offset']))
 hidden=Image.open(C/'source'/('hidden_registered.png' if f=='front' else 'rear_pelvis_registered.png'))
 regions={n:Image.new('RGBA',(255,255)) for n in ['pelvis_undercloth','thigh_fill_r','thigh_fill_l']}
 for y in range(110,180):
  for x in range(70,190):
   if mask.getpixel((x,y))[3]<250 or hidden.getpixel((x,y))[3]==0:continue
   if f=='front':
    if y>142 and 139<x<157:continue # No front femur paint may bridge the two legs.
    n='thigh_fill_r' if y>=133 and x<141 else 'thigh_fill_l' if y>=135 and x>=159 else 'pelvis_undercloth'
   else:n='thigh_fill_l' if y>=142 and x<111 else 'thigh_fill_r' if y>=142 and x>=130 else 'pelvis_undercloth'
   regions[n].putpixel((x,y),hidden.getpixel((x,y)))
 for n,image in regions.items():
  box=image.getbbox()
  if not box:raise ValueError((f,n,'empty'))
  path=C/'assets'/f/(n+'.png');image.crop(box).save(path)
  bone='pelvis' if n=='pelvis_undercloth' else 'thigh_'+n[-1]
  layout['parts'].append({'name':n,'file':str(path.relative_to(C)),'offset':list(box[:2]),'bone':bone,'z_index':6 if n=='pelvis_undercloth' else 1,'equipment_slot':'body'})
  records.append({'view':f,'part':n,'source':'source/hidden_registered.png' if f=='front' else 'source/rear_pelvis_registered.png','bbox':list(box),'owner':bone,'selection':'Generated bone pixels only under original waistcloth alpha>=250; hidden pelvis remains distinct from proximal thighs.'})
 write(C/'layouts'/f'{f}_with_pelvis.json',layout)
 recipe=json.loads((C/'recipes'/f'{f}_skinned.skin.json').read_text());recipe['input_layout']=f'layouts/{f}_with_pelvis.json';recipe['output_layout']=f'layouts/{f}_complete_skinned.json'
 for field in recipe['fields']:
  if '_leg_' in field['name']:field['parts'].append('thigh_fill_'+field['name'][-1])
 write(C/'recipes'/f'{f}_pelvis_skin.json',recipe)
 subprocess.run([sys.executable,'tools/cutout_workflow.py','skin',str(C),'--recipe',str(C/'recipes'/f'{f}_pelvis_skin.json')],check=True)
write(C/'recipes/pelvis_registration.json',{'rear_source_bbox':list(bbox),'rear_target_size':[44,41],'rear_target_offset':[96,120],'filter':'Lanczos','source_alpha_preserved':True,'selected_parts':records})
p=C/'motion.gd';s=p.read_text().replace('if clip == "walk":','if clip in ["walk", "retreat"]:').replace('if clip in ["walk","attack","cast"]:','if clip in ["walk","retreat","attack","cast"]:').replace('if clip != "walk":return {}','if clip not in ["walk", "retreat"]:return {}')
s=s.replace('pose["pelvis"]["position"] += Vector2(0, -1.6 * (0.5 - 0.5 * cos(TAU * 2 * t)))','pose["pelvis"]["position"] += Vector2(0, -1.6 * (0.5 - 0.5 * cos(TAU * 2 * t)))\n\t\tif clip == "retreat":\n\t\t\t# A guarded withdrawal follows the resolved lane, then returns to watch the player.\n\t\t\tvar away := Vector2(1, -0.5) if rear else Vector2(-1, 0.5)\n\t\t\tpose["torso"]["position"] -= away * 1.5\n\t\t\t_solve_arm(pose, layout, "r", _point(layout,"fore_r") - away * 2, _point(layout,"hand_r") - away * 4 + Vector2(0,-2), 0)')
s=s.replace('result["Skin_hip_cap_"+side] = 3 if near else 1','result["Skin_hip_cap_"+side] = 3 if near else 1\n\t\tresult["Skin_thigh_fill_"+side] = 3 if near else 1')
p.write_text(s)
cfg=json.loads((C/'cutout.json').read_text());cfg['clips']['retreat']={'frames':40,'duration':0.48,'loop':True,'preview_cycles':2,'travel':'motion'}
for f in cfg['draw_order_parts']:cfg['draw_order_parts'][f]+= ['Skin_thigh_fill_r','Skin_thigh_fill_l']
cfg['sources']=sorted(set(cfg['sources']+[str(p.relative_to(C)) for f in ['source','recipes'] for p in (C/f).rglob('*') if p.is_file()]))
write(C/'cutout.json',cfg)
gen=json.loads((C/'source/generation_requests.json').read_text());gen['requests'] += [{'prompt':'rear_hidden_prompt.txt','output':'rear_hidden_rejected_checker.png','disposition':'rejected RGB painted checkerboard; no selected pixels'},{'prompt':'rear_alpha_prompt.txt','output':'rear_hidden_rejected_checker_v2.png','disposition':'rejected background extraction still RGB checkerboard and altered paint; no selected pixels'},{'prompt':'rear_pelvis_rejected_prompt.txt','output':'rear_pelvis_rejected_checker.png','disposition':'rejected RGB checkerboard; no selected pixels'},{'prompt':'rear_pelvis_prompt.txt','output':'rear_pelvis_generated.png','reference_roles':'New component from text; no image reference','disposition':'selected actual RGBA rear sacrum/pelvis with transparent holes; manually fitted as concealed pelvis and femur caps'}]
gen['sha256']={p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in (C/'source').iterdir() if p.suffix in ['.png','.txt']};write(C/'source/generation_requests.json',gen)
