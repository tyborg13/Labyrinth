"""Register untouched imagegen paint, then explicitly separate creature/background owners."""
from pathlib import Path
import hashlib, json, subprocess
from PIL import Image, ImageDraw
ROOT=Path(__file__).resolve().parents[1]
REPO=ROOT.parents[3]
source=ROOT/'source/front_generated_v01.png'
image=Image.open(source).convert('RGBA')
registered=image.resize((255,255),Image.Resampling.NEAREST)
shifted=Image.new('RGBA',(255,255));shifted.alpha_composite(registered,(-10,0));registered=shifted
registered.save(ROOT/'source/front_registered_rgb.png')
# The selected image has brown/copper character paint and neutral light checkerboard.
# This criterion records exclusions, never modifies/repaints a creature RGB pixel.
excluded=[]
for y in range(255):
 for x in range(255):
  r,g,b,a=registered.getpixel((x,y))
  if a and min(r,g,b)>=100 and max(r,g,b)-min(r,g,b)<=42:
   excluded.append({'point':[x,y],'name':'excluded_background'})
recipe={'priority_polygons':[['creature',[[0,0],[254,0],[254,254],[0,254]]],['excluded_background',[[0,0],[1,0],[1,1],[0,1]]]],'pixel_overrides':excluded,
 'purpose':'Background ownership exclusion only; semantic anatomy subdivision follows native and real-board painting QA.',
 'predicate':'min(R,G,B)>=100 and max(R,G,B)-min(R,G,B)<=42; evaluated at registered nearest-neighbor samples; retained as exact pixel overrides'}
recipe_path=ROOT/'recipes/front_background_ownership_v03.json'
recipe_path.write_text(json.dumps(recipe,indent=2)+'\n')
output=ROOT/'source/front_background_split_v03'
subprocess.run(['python3',str(REPO/'tools/cutout_workflow.py'),'segment','--source',str(ROOT/'source/front_registered_rgb.png'),'--ownership',str(recipe_path),'--output',str(output)],check=True)
report=json.loads((output/'segmentation.json').read_text())
part=next(p for p in report['parts'] if p['name']=='creature')
creature=Image.new('RGBA',(255,255));creature.alpha_composite(Image.open(output/part['file']),tuple(part['offset']))
creature.save(ROOT/'source/front_registered.png')
mask=creature.getchannel('A');mask.save(ROOT/'source/front_alpha_mask.png')
hashfile=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
(ROOT/'recipes/front_registration.json').write_text(json.dumps({'selected':'source/front_generated_v01.png','rejected':'source/front_generated_v02.png','rejection_reason':'Second extraction also RGB checkerboard and needlessly resampled painting; no pixels used.', 'source_sha256':hashfile(source),'input_size':list(image.size),'registered_size':[255,255],'uniform_scale':255/image.width,'resize':'nearest; complete canvas without crop or independent part fitting','translation':[-10,0], 'translation_reason':'Align average projected boot contacts across front and rear without scaling individual parts or changing paint' ,'exclude_part':'excluded_background','kept_part':'creature','kept_rgb':'exact nearest source pixels; no recolor or synthesized pixels','background_ownership_sha256':hashfile(recipe_path),'output_sha256':hashfile(ROOT/'source/front_registered.png'),'mask_sha256':hashfile(ROOT/'source/front_alpha_mask.png'),'visible_bbox':list(creature.getbbox()),'background_pixels':len(excluded)},indent=2)+'\n')
# Native scale means no per-character fitting. Crawler retains its native 127px scale.
refs=[('Gaoler old','gaoler_original.png'),('Gaoler repaint','front_registered.png'),('Warden','warden_style.png'),('Crawler','crawler_style.png'),('Harrier','harrier_style.png'),('Surgeon','surgeon_style.png')]
sheet=Image.new('RGB',(255*6,287),(28,27,26));draw=ImageDraw.Draw(sheet)
for i,(label,filename) in enumerate(refs):
 im=Image.open(ROOT/'source'/filename).convert('RGBA');x=i*255+(255-im.width)//2;y=26+255-im.height
 sheet.paste(im,(x,y),im);draw.text((i*255+8,7),label,fill=(226,216,192))
sheet.save(ROOT/'source/native_roster_comparison.png')
print('REGISTERED',creature.getbbox(),'alpha',mask.getextrema())
