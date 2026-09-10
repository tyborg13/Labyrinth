"""Retain reviewed silhouette edge pixels on their adjacent semantic owner.
No visible region is assigned to a torso fallback. Original polygons and exact
per-pixel decisions remain available in ownership JSON and initial segmentation.
"""
import json,math,subprocess,sys
from pathlib import Path
from PIL import Image,ImageDraw
C=Path('experiments/cutouts/harrier/v01')
for f in ['front','rear']:
 source=Image.open(C/'source'/f'{f}_registered.png').convert('RGBA')
 definition=json.loads((C/'source'/f'{f}_ownership.json').read_text())
 owners={}
 for name,polygon in definition['priority_polygons']:
  mask=Image.new('1',(255,255));ImageDraw.Draw(mask).polygon([tuple(p) for p in polygon],fill=1)
  for y in range(255):
   for x in range(255):
    if mask.getpixel((x,y)) and source.getpixel((x,y))[3]:owners.setdefault((x,y),name)
 report=json.loads((C/'segmented'/f/'segmentation.json').read_text())
 rejected=[]
 for x,y in report['unassigned_coordinates']:
  candidates=[(math.hypot(x-a,y-b),owners[(a,b)]) for b in range(max(0,y-9),min(255,y+10)) for a in range(max(0,x-9),min(255,x+10)) if (a,b) in owners]
  if not candidates:
   if source.getpixel((x,y))[3] > 12:raise ValueError(('Unreviewed isolated visible material',f,x,y,source.getpixel((x,y))))
   rejected.append([x,y,list(source.getpixel((x,y)))]);source.putpixel((x,y),(0,0,0,0));continue
  _,name=min(candidates)
  definition['pixel_overrides'].append({'point':[x,y],'name':name})
 definition['edge_review']='Reviewed enlarged native ownership map: adjacent outer contours and dark outline gaps use the same semantic owner. Explicit override coordinates retained. No unassigned fallback.'
 if rejected:
  source.save(C/'source'/f'{f}_registered.png')
  (C/'recipes'/f'{f}_discarded_alpha_speckles.json').write_text(json.dumps({'disposition':'isolated generator alpha speckles only; original retained','pixels':rejected},indent=2)+'\n')
 (C/'source'/f'{f}_ownership.json').write_text(json.dumps(definition,indent=2)+'\n')
 p=subprocess.run([sys.executable,'tools/cutout_workflow.py','segment','--source',str(C/'source'/f'{f}_registered.png'),'--ownership',str(C/'source'/f'{f}_ownership.json'),'--output',str(C/'segmented'/f'{f}_complete')],capture_output=True,text=True)
 print(f,p.returncode,p.stderr)
