"""Explicit registration/ownership of generated concealed material, never repaint front.
The generated outputs stay untouched. Patches sit under original fully opaque
owners, retain narrow joint widths and cannot alter the accepted front rest.
"""
from pathlib import Path
import json
from PIL import Image,ImageDraw
CASE=Path('experiments/cutouts/noctyrax/v01')
recipes=[]
for facing in ['front','rear']:
 layout_path=CASE/f'layouts/{facing}.json';layout=json.loads(layout_path.read_text())
 layout['parts']=[p for p in layout['parts'] if not p['name'].startswith('hidden_') and (facing=='front' or p['name'] not in ['fore_far','claw_fore_far'])]
 source=Image.open(CASE/f'source/{facing}_hidden_generated.png').convert('RGBA')
 # Coordinates below refer to a 255px inspection grid; crop is taken from
 # full generation resolution with a single transform into the native patch.
 if facing=='front':crop=[119,110,140,132]
 else:crop=[173,120,188,143]
 box=tuple(round(v*source.width/255) for v in crop)
 paint=source.crop(box)
 registered=Image.open(CASE/f'source/{facing}_registered.png')
 caps=[('fore_near', [133,133,161,156],8)] if facing=='front' else [('fore_near',[165,141,184,160],3)]
 # Wing-root material is only exposed by purposeful folding/spreading.
 caps += [('wing_near',[139,116,164,139],2),('wing_far',[54,93,76,120],-1)] if facing=='front' else [('wing_near',[89,127,114,150],7),('wing_far',[153,115,176,138],-1)]
 if facing=='front':caps.append(('wing_near_base',[170,127,201,151],2))
 for cap_name,region,z in caps:
  owner=cap_name.removesuffix('_base')
  own=next(p for p in layout['parts'] if p['name']==owner)
  owner_img=Image.new('RGBA',(255,255));owner_img.alpha_composite(Image.open(CASE/own['file']),tuple(own['offset']))
  x0,y0,x1,y1=region;part=paint.resize((x1-x0,y1-y0),Image.Resampling.LANCZOS)
  for y in range(part.height):
   for x in range(part.width):
    # Insets avoid bright rim pixels and leave source antialias unchanged.
    if owner_img.getpixel((x+x0,y+y0))[3] !=255:part.putpixel((x,y),(0,0,0,0))
  if not part.getbbox():continue
  rel=f'assets/{facing}/hidden_{cap_name}.png';dest=CASE/rel;dest.parent.mkdir(parents=True,exist_ok=True);part.save(dest)
  layout['parts'].append({'name':'hidden_'+cap_name,'file':rel,'offset':[x0,y0],'bone':'body','z_index':z})
  recipes.append({'facing':facing,'source':f'source/{facing}_hidden_generated.png','native_grid_source_crop':crop,'source_crop':box,'output':rel,'target_rect':region,'mask':'opaque source pixels owned by '+owner,'owner':'body','purpose':'narrow concealed socket beneath moving owner'})
 if facing=='rear':
  # This generated foreleg was revealed by removing the near-side occluder.
  # Register its complete paint as the far foreleg, with a smaller projected
  # length. The torso/near leg hide its proximal section at the rest pose.
  native=source.resize((255,255),Image.Resampling.LANCZOS)
  mask=Image.new('L',(255,255));ImageDraw.Draw(mask).polygon([(180,139),(188,142),(197,161),(211,176),(221,177),(228,188),(225,200),(208,199),(191,186),(179,169),(173,151)],fill=255)
  for y in range(255):
   for x in range(255):
    r,g,b,a=native.getpixel((x,y))
    if r>80 and b>100 and r>g*1.6 and b>g*1.6:mask.putpixel((x,y),0)
  native.putalpha(mask)
  reg=Image.new('RGBA',(255,255));reg.alpha_composite(native.resize((214,214),Image.Resampling.LANCZOS),(3,21))
  for name,ymin,ymax,bone,z in [('fore_far',0,169,'upper_fore_far',-3),('claw_fore_far',169,255,'claw_fore_far',-2)]:
   part=reg.copy();pix=part.load()
   for y in range(255):
    if ymin<=y<ymax:continue
    for x in range(255):pix[x,y]=(0,0,0,0)
   bbox=part.getbbox();rel=f'assets/rear/{name}.png';part.crop(bbox).save(CASE/rel)
   layout['parts'].append({'name':name,'file':rel,'offset':list(bbox[:2]),'bone':bone,'z_index':z})
  for n,p in [('upper_fore_far',[157,140]),('lower_fore_far',[164,161]),('claw_fore_far',[179,178])]:layout['joints'][n]['position']=p
  recipes.append({'facing':facing,'source':'source/rear_hidden_generated.png','full_source_registration':{'native_size':[214,214],'translation':[3,21]},'mask_polygon_native_255':[(180,139),(188,142),(197,161),(211,176),(221,177),(228,188),(225,200),(208,199),(191,186),(179,169),(173,151)],'claw_split_y':169,'purpose':'complete concealed far foreleg; behind accepted torso and near leg'})
 layout_path.write_text(json.dumps(layout,indent=2)+'\n')
(CASE/'recipes/hidden_registration.json').write_text(json.dumps(recipes,indent=2)+'\n')
