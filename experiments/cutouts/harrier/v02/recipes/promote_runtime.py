"""Copy the final Harrier case's runtime closure into production-owned paths."""
import json,shutil
from pathlib import Path
from PIL import Image
C=Path('experiments/cutouts/harrier/v02');A=Path('assets/units/harrier_cutout');S=Path('scripts/harrier_cutout')
cfg=json.loads((C/'cutout.json').read_text())
for f,relative in cfg['layouts'].items():
 layout=json.loads((C/relative).read_text());paths={}
 source=Image.open(C/'source'/f'{f}_registered.png')
 for p in layout['parts']:
  old=p['file'];dst=A/f/(p['name']+'.png');dst.parent.mkdir(parents=True,exist_ok=True)
  im=Image.open(C/old).convert('RGBA')
  if p['name'].startswith(('shoulder_cap','hip_cap','thigh_fill','pelvis_undercloth')):
   ox,oy=p['offset']
   for y in range(im.height):
    for x in range(im.width):
     if source.getpixel((ox+x,oy+y))[3]<(255 if f=='front' else 250):im.putpixel((x,y),(0,0,0,0))
   im.save(C/old)
  shutil.copy2(C/old,dst);Path(str(dst)+'.import').write_text('[remap]\n\nimporter="keep"\n')
  paths[old]=str(dst.relative_to(A));p['file']=paths[old]
 for mesh in layout.get('joint_meshes',[]):mesh['file']=paths[mesh['file']]
 layout['rest_source']=f+'/rest.png'
 (A/(f+'.json')).write_text(json.dumps(layout,indent=2)+'\n')
 shutil.copy2(C/'source'/f'{f}_registered.png',A/f/'rest.png');(A/f/'rest.png.import').write_text('[remap]\n\nimporter="keep"\n')
shutil.copy2(C/'motion.gd',S/'motion.gd')
