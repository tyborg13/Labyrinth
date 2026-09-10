"""Register untouched rear source and assign backdrop to a discarded owner.
The maintained cutout segment command produces the actual transparent parts.
No source RGB values are repainted; nearest sampling records a uniform fit.
"""
from pathlib import Path
from collections import deque
import json, hashlib, subprocess, sys
from PIL import Image
root=Path(__file__).resolve().parent.parent
repo=root.parents[3]
original=root/'source/rear_generated.png'
source=Image.open(original).convert('RGBA')
# One uniform native fit: target height 210px for the 1048px source silhouette.
# Full source resamples to 251px and translates 5px right, 0px down.
registered=Image.new('RGBA',(255,255))
registered.paste(source.resize((251,251),Image.Resampling.NEAREST),(5,0))
registered.save(root/'source/rear_registered_with_background.png')
# Backdrop is neutral grey/white. Warm white lightning interiors are enclosed
# by their saturated amber contour and have no grey checker seed. Record each
# chosen pixel explicitly so future assembly is independent of this selector.
neutral=set()
for y in range(255):
 for x in range(255):
  r,g,b,a=registered.getpixel((x,y))
  if a and min(r,g,b)>=150 and max(r,g,b)-min(r,g,b)<=24: neutral.add((x,y))
background=set()
while neutral:
 seed=neutral.pop(); component={seed}; queue=deque([seed]); grey=False
 while queue:
  x,y=queue.popleft()
  r,g,b,_=registered.getpixel((x,y))
  grey |= max(r,g,b)<235
  for p in [(x-1,y),(x+1,y),(x,y-1),(x,y+1)]:
   if p in neutral: neutral.remove(p); component.add(p);queue.append(p)
 if grey: background.update(component)
# Outside the observed character envelope is unequivocally backdrop.
for y in range(255):
 for x in range(255):
  if not (65<=x<=198 and 16<=y<=228): background.add((x,y))
polygons=[['background',[[0,0],[254,0],[254,254],[0,254]]]]
for name in ['crown','tail','arc_left','arc_right','core']:
 polygons.append([name,[[0,0],[254,0],[254,254],[0,254]]])
overrides=[]
for y in range(255):
 for x in range(255):
  if registered.getpixel((x,y))[3] and (x,y) not in background:
   name='crown' if y<=60 else 'tail' if y>=180 else 'arc_left' if x<=88 else 'arc_right' if x>=163 else 'core'
   overrides.append({'point':[x,y],'name':name})
def write(path,value): path.write_text(json.dumps(value,indent=2)+'\n')
write(root/'source/rear_background_ownership.json',{'priority_polygons':polygons,'pixel_overrides':overrides})
subprocess.run([sys.executable,str(repo/'tools/cutout_workflow.py'),'segment','--source',str(root/'source/rear_registered_with_background.png'),'--ownership',str(root/'source/rear_background_ownership.json'),'--output',str(root/'segmented/rear_source')],check=True)
report=json.loads((root/'segmented/rear_source/segmentation.json').read_text())
assembled=Image.new('RGBA',(255,255))
for p in report['parts']:
 if p['name']=='background': continue
 part=Image.open(root/'segmented/rear_source'/p['file'])
 assembled.paste(part,tuple(p['offset']))
assembled.save(root/'source/rear_registered.png')
write(root/'source/registration.json',{
 'front':{'source':'front_original.png','operation':'unchanged copy','canvas':[255,255],'bounds':[59,17,203,227]},
 'rear':{'source':'rear_generated.png','source_size':list(source.size),'uniform_resample_size':[251,251],'filter':'nearest','canvas':[255,255],'offset':[5,0],'bounds':list(assembled.getbbox()),'ownership':'rear_background_ownership.json','discarded_owner':'background','rgb_repainted':False,'foreground_pixels':len(overrides),'selector':'neutral connected components with grey seed; explicit saved pixel overrides authoritative'},
 'projection':'2:1 isometric; front aperture points down-left, rear turns up-right; reflected views provided by renderer',
 'anchors':{'hover':[127,227],'core':[127,124]},
 'hidden_material':'No new hidden core paint required: outer arc meshes blend to rigid core at each segmented root; all requested motion uses continuous paint.'})
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
write(root/'source/generation.json',{'tool':'built-in image_gen','requests':[
 {'prompt_file':'rear_prompt.txt','reference_roles':[{'path':'front_original.png','role':'accepted character identity and palette reference','sha256':sha(root/'source/front_original.png')}],'output':'rear_generated.png','sha256':sha(original),'disposition':'selected rear character paint; painted backdrop assigned to excluded background owner'},
 {'prompt':'Use case: background-extraction. Edit target: the provided rear Lightning Wisp sprite. Remove the painted grey and white checkerboard completely, including gaps inside the lightning, and return actual transparent alpha RGBA pixels. Preserve the character itself exactly, its silhouette, all dark core paint, gold lightning and purple filaments. This is a background repair only. No checkerboard drawn into RGB, no white background, no black background, no shadow or glow rectangle. Keep a single full rear character.','reference_roles':[{'path':'rear_generated.png','role':'edit target','sha256':sha(original)}],'output':'rear_alpha_attempt.png','sha256':sha(root/'source/rear_alpha_attempt.png'),'disposition':'rejected: still RGB checkerboard and smoother paint; no runtime pixels selected'}]})
