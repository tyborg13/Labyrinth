"""Build shared source-space skin fields without altering any source paint.

Every body piece samples the same field at the same global 2px grid. Terminal
drawings stay rigid; their attachment collars share the terminal's exact basis.
Explicit ownership remains inspectable and independently editable.
"""
from pathlib import Path
from PIL import Image, ImageFilter
import argparse, copy, json, math, shutil
R=Path.cwd()
def write(p,d):p.parent.mkdir(parents=True,exist_ok=True);p.write_text(json.dumps(d,separators=(',',':'))+'\n')
def smooth(x):x=max(0,min(1,x));return x*x*(3-2*x)
def band(x,y,c,axis,width):
 length=max(.01,math.hypot(*axis));return smooth(((x-c[0])*axis[0]+(y-c[1])*axis[1])/length/width+.5)
def initial_weights(d,a,x,y):
 bones=d.get('field')
 if not bones:return {d['bone']:1.}
 pts=[a['joints'][b]['position'] for b in bones]
 if d['name'].startswith(('arm_','leg_')):
  par,up,low,end=pts;axis=[low[0]-up[0],low[1]-up[1]];axis2=[end[0]-low[0],end[1]-low[1]]
  factors=[band(x,y,up,axis,16),band(x,y,low,axis,18),band(x,y,[end[0]-axis2[0]*.25,end[1]-axis2[1]*.25],axis2,14)]
 elif d['name'].startswith('wing_'):
  par,up,low,end=pts;r=max(35,math.dist(up,end));dist=math.dist([x,y],up)
  attach=smooth((dist-4)/18);tip=smooth((dist-r*.5)/(r*.8))
  return dict(zip(bones,[1-attach,attach*(1-tip),attach*tip*.35,attach*tip*.65]))
 else:
  par,end=pts
  axis=[end[0]-par[0],end[1]-par[1]]
  if math.hypot(*axis)<1:axis=[0,1]
  factors=[band(x,y,[end[0],end[1]+4],axis,24)]
 vals=[1.]
 for f in factors:vals=[v*(1-f) for v in vals]+[f]
 return dict(zip(bones,vals))

def build(root):
 id=root.parent.name;config=json.loads((root/'cutout.json').read_text())
 for facing in ['front','rear']:
  a=json.loads((root/('anatomy_'+facing+'.json')).read_text())
  # Deduplicate the explicitly marked occluded chains from early drafts.
  a['chains']=list({c['name']+'_'+c['kind']:c for c in a['chains']}.values())
  defs={p['name']:p for p in a['parts']}
  defs['body']['rigid']=False
  report_path=root/config['segmentation'][facing]
  report=json.loads(report_path.read_text())
  assert report['ok'],(id,facing)
  segmented=report_path.parent
  fields={b:bytearray(256*256) for b in a['joints']};terminals=[]
  weapons={'blade','spear','lantern'}
  for p in report['parts']:
   if p['name'] in weapons:continue
   d=defs[p['name']];im=Image.open(segmented/p['file']).convert('RGBA');x0,y0=p['offset']
   mask=Image.new('L',(256,256));mask.paste(im.getchannel('A'),(x0,y0))
   if d.get('rigid'):terminals.append((d['bone'],mask.filter(ImageFilter.MaxFilter(7))))
   for y in range(im.height):
    for x in range(im.width):
     if not im.getpixel((x,y))[3]:continue
     gx,gy=x+x0,y+y0;i=gy*256+gx
     for bone,w in initial_weights(d,a,gx,gy).items():fields[bone][i]=round(w*255)
  fields={b:Image.frombytes('L',(256,256),bytes(v)).filter(ImageFilter.GaussianBlur(4)).tobytes() for b,v in fields.items() if any(v)}
  rigid_masks=[(b,m.tobytes()) for b,m in terminals]
  cache={}
  def weight(x,y):
   key=(x,y)
   if key in cache:return cache[key]
   i=min(255,max(0,y))*256+min(255,max(0,x))
   rigid=[b for b,m in rigid_masks if m[i]>0]
   if len(rigid)==1:result={rigid[0]:1.}
   else:
    vals=sorted(((v[i],b) for b,v in fields.items() if v[i]),reverse=True)[:4]
    total=sum(v for v,b in vals);result={b:v/total for v,b in vals} if total else {'torso':1.}
   cache[key]=result;return result
  out=root/('paint_'+facing+'_v02');out.mkdir(exist_ok=True)
  layout={'version':1,'character_id':id,'facing':facing,'canvas_size':[255,255],'family':a['family'],'joints':a['joints'],'chains':a['chains'],'parts':[],'joint_meshes':[],'rest_source':'source/'+facing+'.png','landmarks':{'foot_contacts':{c['bones'][2]:a['joints'][c['bones'][2]]['position'] for c in a['chains'] if c['kind']=='leg'}}}
  for p in report['parts']:
   d=defs[p['name']];im=Image.open(segmented/p['file']);x0,y0,x1,y1=p['bbox']
   # Transparent padding aligns every mesh edge with the common grid.
   bx,by=(x0//2)*2,(y0//2)*2;ex,ey=math.ceil(x1/2)*2,math.ceil(y1/2)*2
   padded=Image.new('RGBA',(ex-bx,ey-by));padded.paste(im,(x0-bx,y0-by));dest=out/p['file'];padded.save(dest)
   part={'name':p['name'],'file':str(dest.relative_to(root)),'offset':[bx,by],'bbox':[bx,by,ex,ey],'bone':d['bone'],'z_index':d['z'],'paint_node':p['name'] if d.get('rigid') else 'Skin_'+p['name']}
   layout['parts'].append(part)
   if d.get('rigid'):continue
   xs=list(range(bx,ex+1,2));ys=list(range(by,ey+1,2));points=[[x,y] for y in ys for x in xs];ws=[weight(x,y) for x,y in points]
   bones=set(b for w in ws for b in w);weights={b:[round(w.get(b,0),8) for w in ws] for b in sorted(bones)}
   triangles=[]
   for row in range(len(ys)-1):
    for col in range(len(xs)-1):
     i=row*len(xs)+col;triangles.extend([[i,i+1,i+len(xs)+1],[i,i+len(xs)+1,i+len(xs)]])
   layout['joint_meshes'].append({'name':part['paint_node'],'replaces_part':p['name'],'file':part['file'],'offset':part['offset'],'bbox':part['bbox'],'z_index':part['z_index'],'vertices':points,'uvs':[[x-bx,y-by] for x,y in points],'triangles':triangles,'weights':weights,'family':'continuous_anatomical_field','coordinate_space':'global source pixels; transparent padded crop-local UV','weight_authoring':'Explicit ownership, shared 4px attachment field and rigid terminal collars; identical global 2px lattice on adjoining pieces.'})
  # The trunk also participates in shoulder, hip and neck attachment fields.
  assert any(m['replaces_part']=='body' for m in layout['joint_meshes']),(id,facing,'body must be flexible at attachments')
  path=root/'layouts'/(facing+'_skinned_v02.json');write(path,layout);config['layouts'][facing]=str(path.relative_to(root));config['draw_order_parts'][facing]=[p['paint_node'] for p in layout['parts']]
  config['sources']=sorted(set(config['sources']+['anatomy_'+facing+'.json']))
 write(root/'cutout.json',config)
 print('Built shared attachments:',id)

def promote(case):
 config=json.loads((case/'cutout.json').read_text())
 dest=R/'assets/units/guardians'/config['character_id']
 for facing,relative in config['layouts'].items():
  layout=copy.deepcopy(json.loads((case/relative).read_text()))
  (dest/facing).mkdir(parents=True,exist_ok=True)
  for piece in layout['parts']+layout['joint_meshes']:
   source=case/piece['file'];target=dest/facing/source.name
   shutil.copyfile(source,target);piece['file']=str(target.relative_to(dest))
  shutil.copyfile(case/'source'/f'{facing}.png',dest/facing/'rest.png')
  layout['rest_source']=f'{facing}/rest.png'
  write(dest/f'{facing}.json',layout)
 print('Promoted production rig:',config['character_id'])

if __name__=='__main__':
 parser=argparse.ArgumentParser(description=__doc__)
 parser.add_argument('actors',nargs='*',help='Guardian ids; omit for the complete authored roster')
 parser.add_argument('--promote',action='store_true',help='Copy verified case layouts and paint into production')
 args=parser.parse_args()
 cases=[p for p in sorted((R/'experiments/cutouts').glob('*/v01')) if (p/'anatomy_front.json').exists() and (not args.actors or p.parent.name in args.actors)]
 for case in cases:
  build(case)
  if args.promote:promote(case)
