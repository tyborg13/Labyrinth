"""Retain generated underclothes only at explicitly selected concealed joints."""
from pathlib import Path
import json,subprocess,hashlib
from PIL import Image,ImageDraw
R=Path(__file__).resolve().parents[1];REPO=R.parents[3]
def write(p,v):p.write_text(json.dumps(v,indent=2)+'\n')
for view in ['front','rear']:
 raw=R/'source'/f'{view}_under_generated.png';im=Image.open(raw).convert('RGBA').resize((255,255),Image.Resampling.NEAREST)
 path=R/'source'/f'{view}_under_registered_rgb.png';im.save(path)
 bg=[{'point':[x,y],'name':'excluded_background'} for y in range(255) for x in range(255) if min(im.getpixel((x,y))[:3])>=100 and max(im.getpixel((x,y))[:3])-min(im.getpixel((x,y))[:3])<=42]
 recipe=R/'recipes'/f'{view}_under_background.json'
 write(recipe,{'priority_polygons':[['underbody',[[0,0],[254,0],[254,254],[0,254]]],['excluded_background',[[0,0],[1,0],[1,1]]]],'pixel_overrides':bg})
 out=R/'source'/f'{view}_under_background_split'
 subprocess.run(['python3',str(REPO/'tools/cutout_workflow.py'),'segment','--source',str(path),'--ownership',str(recipe),'--output',str(out)],check=True,stdout=subprocess.DEVNULL)
 report=json.loads((out/'segmentation.json').read_text());part=next(p for p in report['parts'] if p['name']=='underbody')
 under=Image.new('RGBA',(255,255));under.alpha_composite(Image.open(out/part['file']),tuple(part['offset']));under.save(R/'source'/f'{view}_under_registered.png')
 # Each cap is sampled from actual complete generated garment material. These
 # pads stay beneath outer source owners and only reveal during articulation.
 if view=='front':
  patches={
   'pelvis_under':{'polygon':[(115,121),(164,121),(169,158),(154,166),(128,163),(111,151)],'bone':'pelvis','z':1},
   'thigh_hook_under':{'polygon':[(111,134),(132,143),(124,171),(114,191),(94,190),(96,165)],'bone':'thigh_hook','z':2},
   'thigh_fist_under':{'polygon':[(153,140),(173,136),(184,167),(186,193),(164,194),(157,173)],'bone':'thigh_fist','z':2},
   'shoulder_hook_under':{'polygon':[(104,70),(118,72),(121,86),(113,98),(98,94),(96,80)],'bone':'upper_hook','z':9},
   'shoulder_fist_under':{'polygon':[(169,74),(179,75),(187,87),(184,102),(170,102),(164,90)],'bone':'upper_fist','z':9}}
 else:
  patches={
   'pelvis_under':{'polygon':[(114,122),(161,121),(169,148),(156,165),(129,166),(111,150)],'bone':'pelvis','z':1},
   'thigh_fist_under':{'polygon':[(110,135),(131,143),(123,167),(114,191),(94,192),(96,164)],'bone':'thigh_fist','z':2},
   'thigh_hook_under':{'polygon':[(154,140),(170,138),(181,166),(187,194),(165,194),(157,174)],'bone':'thigh_hook','z':2},
   'shoulder_fist_under':{'polygon':[(104,73),(119,70),(119,90),(109,103),(95,98),(97,83)],'bone':'upper_fist','z':9},
   'shoulder_hook_under':{'polygon':[(164,73),(175,75),(185,85),(184,99),(172,104),(159,89)],'bone':'upper_hook','z':9}}
 layout_path=R/'layouts'/f'{view}.json';layout=json.loads(layout_path.read_text());audit=[]
 folder=R/'assets'/view;folder.mkdir(parents=True,exist_ok=True)
 for name,item in patches.items():
  mask=Image.new('1',(255,255));ImageDraw.Draw(mask).polygon(item['polygon'],fill=1)
  selected=Image.new('RGBA',(255,255))
  for y in range(255):
   for x in range(255):
    if mask.getpixel((x,y)):selected.putpixel((x,y),under.getpixel((x,y)))
  box=selected.getbbox();target=folder/(name+'.png');selected.crop(box).save(target)
  layout['parts'].append({'name':name,'file':f'assets/{view}/{name}.png','offset':list(box[:2]),'bone':item['bone'],'z_index':item['z'],'equipment_slot':'legs' if 'thigh' in name else 'chest'})
  audit.append(dict(item,name=name,bbox=box,source=f'source/{view}_under_generated.png',output_sha256=hashlib.sha256(target.read_bytes()).hexdigest()))
 write(layout_path,layout);write(R/'recipes'/f'{view}_hidden_coverage.json',{'source':f'source/{view}_under_generated.png','source_sha256':hashlib.sha256(raw.read_bytes()).hexdigest(),'registration':'whole output 1254x1254 -> 255x255 NEAREST, no shift; only these masked source pixels used','patches':audit})
print('Generated joint caps registered beneath their semantic owners')
