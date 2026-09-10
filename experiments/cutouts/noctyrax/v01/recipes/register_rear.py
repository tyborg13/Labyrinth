"""Register generated rear paint; explicit alpha ownership of RGB backdrop.
Imagegen returned RGB after an alpha-correction request. Untouched RGB outputs
are retained. This does not repaint the dragon; only background alpha is removed.
"""
from pathlib import Path
import json, hashlib
from PIL import Image
from collections import deque
CASE=Path('experiments/cutouts/noctyrax/v01')
im=Image.open(CASE/'source/rear_generated_rgb.png').convert('RGBA')
w,h=im.size;pix=im.load()
# Connected neutral backdrop, plus individually inspected enclosed membrane gaps.
# Coordinates are fractions of the original square image, not crop coordinates.
seeds=[(0,0),(0.21,0.36),(0.145,0.455),(0.162,0.514),(0.229,0.463),
       (0.35,0.40),(0.414,0.439),(0.835,0.543),(0.921,0.541),(0.786,0.563),
       (0.37,0.805),(0.453,0.801),(0.716,0.716),(0.487,0.912)]
seen=set();todo=deque()
for x,y in seeds:
 q=(min(w-1,int(x*w)),min(h-1,int(y*h)))
 todo.append(q)
while todo:
 x,y=todo.popleft()
 if (x,y) in seen or not(0<=x<w and 0<=y<h):continue
 seen.add((x,y));r,g,b,a=pix[x,y]
 if min(r,g,b)<90 or max(r,g,b)-min(r,g,b)>18:continue
 pix[x,y]=(r,g,b,0)
 todo.extend(((x-1,y),(x+1,y),(x,y-1),(x,y+1)))
# Preserve the untouched source RGB; only the registered output carries alpha.
registered=Image.new('RGBA',(255,255))
registered.alpha_composite(im.resize((244,244),Image.Resampling.LANCZOS),(6,3))
registered.save(CASE/'source/rear_registered.png')
(CASE/'recipes/rear_registration.json').write_text(json.dumps({'source':'source/rear_generated_rgb.png','source_size':[w,h],'output':'source/rear_registered.png','scale':244/w,'translation':[6,3],'alpha_operation':'connected neutral background removal; min RGB >=90, channel span <=18; explicit hole seeds','seed_fractions':seeds,'untouched_source_sha256':hashlib.sha256((CASE/'source/rear_generated_rgb.png').read_bytes()).hexdigest()},indent=2)+'\n')
