"""Deterministic rigid-prop ownership/registration; no character rig dependency."""
from pathlib import Path
import hashlib,json
from PIL import Image, ImageDraw
CASE=Path(__file__).resolve().parent
OUT=CASE.parents[3]/'assets/art/props/relic_chest_hinge_v1'
OUT.mkdir(parents=True,exist_ok=True)
source=Image.open(CASE/'source/closed_original.png').convert('RGBA')
opened=Image.open(CASE/'source/open_generated.png').convert('RGBA')
canvas=(128,160); offset=(16,40)
body_polygon=[(0,36),(8,36),(28,49),(89,37),(96,37),(96,96),(0,96)]
mask=Image.new('L',source.size);ImageDraw.Draw(mask).polygon(body_polygon,fill=255)
body=source.copy(); body.putalpha(Image.composite(source.getchannel('A'),Image.new('L',source.size),mask))
lid=source.copy(); lid.putalpha(Image.composite(Image.new('L',source.size),source.getchannel('A'),mask))
for name,part in [('body',body),('lid_exterior',lid)]:
 out=Image.new('RGBA',canvas);out.paste(part,offset);out.save(OUT/f'{name}.png')
# Corresponding native landmarks: the back-left/right hinge and front-left rim.
src=[[280,697],[862,600],[496,844]]
dst=[[25,76],[86,66],[44,89]]
def affine_inverse(a,b):
 u=[a[1][i]-a[0][i] for i in range(2)];v=[a[2][i]-a[0][i] for i in range(2)]
 det=u[0]*v[1]-v[0]*u[1]
 inv=[[v[1]/det,-v[0]/det],[-u[1]/det,u[0]/det]]
 out=[]
 for i in range(2):
  du=b[1][i]-b[0][i];dv=b[2][i]-b[0][i]
  x=du*inv[0][0]+dv*inv[1][0];y=du*inv[0][1]+dv*inv[1][1]
  out.append([x,y,b[0][i]-x*a[0][0]-y*a[0][1]])
 return out
matrix=affine_inverse(src,dst)
inverse=affine_inverse(dst,src)
polygons={
'lid_interior':[(0,0),(1246,0),(1246,580),(899,580),(862,609),(285,710),(0,710)],
'cavity':[(280,697),(862,600),(1080,725),(496,844)]}
for name,polygon in polygons.items():
 owner=Image.new('L',opened.size);ImageDraw.Draw(owner).polygon(polygon,fill=255)
 part=opened.copy();part.putalpha(Image.composite(opened.getchannel('A'),Image.new('L',opened.size),owner))
 registered=part.transform(canvas,Image.Transform.AFFINE,tuple(value for row in inverse for value in row),Image.Resampling.NEAREST)
 registered.save(OUT/f'{name}.png')
rest=Image.new('RGBA',canvas);rest.alpha_composite(body,(offset));rest.alpha_composite(lid,(offset))
expected=Image.new('RGBA',canvas);expected.paste(source,offset)
assert rest.tobytes()==expected.tobytes(), 'Closed source must reconstruct byte-identically'
manifest={'kind':'rigid_hinged_prop','canvas':canvas,'logical_size':[96,96],'logical_offset':offset,'closed_body_polygon':body_polygon,'generated_ownership':polygons,'source_landmarks':src,'target_landmarks':dst,'source_to_registered':matrix,'hinge_registered':[[25,76],[86,66]],'source_sha256':{p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in (CASE/'source').glob('*.png')},'runtime_sha256':{p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in OUT.glob('*.png')},'rest_reconstruction':'RGBA byte-identical'}
(CASE/'registration.json').write_text(json.dumps(manifest,indent=2)+'\n')
print(json.dumps(manifest,indent=2))
