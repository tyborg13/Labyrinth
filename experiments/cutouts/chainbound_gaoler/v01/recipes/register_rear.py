"""Register untouched imagegen paint, then explicitly separate creature/background owners."""
from pathlib import Path
import hashlib, json, subprocess
from PIL import Image, ImageDraw
ROOT=Path(__file__).resolve().parents[1]
REPO=ROOT.parents[3]
source=ROOT/'source/rear_generated_v01.png'
image=Image.open(source).convert('RGBA')
registered=image.resize((255,255),Image.Resampling.NEAREST)
shifted=Image.new('RGBA',(255,255));shifted.alpha_composite(registered,(26,2));registered=shifted
registered.save(ROOT/'source/rear_registered_rgb.png')
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
recipe_path=ROOT/'recipes/rear_background_ownership_v03.json'
recipe_path.write_text(json.dumps(recipe,indent=2)+'\n')
output=ROOT/'source/rear_background_split_v03'
subprocess.run(['python3',str(REPO/'tools/cutout_workflow.py'),'segment','--source',str(ROOT/'source/rear_registered_rgb.png'),'--ownership',str(recipe_path),'--output',str(output)],check=True)
report=json.loads((output/'segmentation.json').read_text())
part=next(p for p in report['parts'] if p['name']=='creature')
creature=Image.new('RGBA',(255,255));creature.alpha_composite(Image.open(output/part['file']),tuple(part['offset']))
creature.save(ROOT/'source/rear_registered.png')
mask=creature.getchannel('A');mask.save(ROOT/'source/rear_alpha_mask.png')
hashfile=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
(ROOT/'recipes/rear_registration.json').write_text(json.dumps({'selected':'source/rear_generated_v01.png','rejected':None,'rejection_reason':None, 'source_sha256':hashfile(source),'input_size':list(image.size),'registered_size':[255,255],'uniform_scale':255/image.width,'resize':'nearest; complete canvas without crop or independent part fitting','translation':[26,2], 'translation_reason':'Align average projected boot contacts across front and rear without scaling individual parts or changing paint' ,'exclude_part':'excluded_background','kept_part':'creature','kept_rgb':'exact nearest source pixels; no recolor or synthesized pixels','background_ownership_sha256':hashfile(recipe_path),'output_sha256':hashfile(ROOT/'source/rear_registered.png'),'mask_sha256':hashfile(ROOT/'source/rear_alpha_mask.png'),'visible_bbox':list(creature.getbbox()),'background_pixels':len(excluded)},indent=2)+'\n')
