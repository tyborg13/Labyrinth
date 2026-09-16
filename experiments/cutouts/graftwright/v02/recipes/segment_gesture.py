from pathlib import Path
from PIL import Image, ImageDraw, ImageChops
import json,copy,argparse,shutil,hashlib
parser=argparse.ArgumentParser();parser.add_argument('--promote',action='store_true');args=parser.parse_args()
case=Path(__file__).resolve().parents[1]
original=Image.open(case/'source/original.png').convert('RGBA')
# Native paint ownership: the exposed forearm and occupied hand are rigid.
polygons=[[[580,754],[612,710],[661,643],[677,624],[688,570],[702,522],[709,475],[742,445],[766,421],[782,403],[819,401],[930,396],[947,520],[890,588],[803,597],[779,603],[766,625],[746,645],[729,654],[711,675],[677,735],[648,806],[625,879]],[[792,190],[1086,190],[1086,410],[792,410]],[[850,408],[1086,408],[1086,710],[841,710],[805,585],[841,561]]]
mask=Image.new('L',original.size)
for points in polygons:ImageDraw.Draw(mask).polygon(points,fill=255)
# Add a two-pixel ownership margin at painted contour antialiasing. This is
# extraction of existing source pixels, not synthesis or painted replacement.
from PIL import ImageFilter
mask=mask.filter(ImageFilter.MaxFilter(5))
square_mask=Image.new('L',(1448,1448));square_mask.paste(mask,(181,0))
arm=Image.new('RGBA',(1448,1448));arm.paste(original,(181,0));arm.putalpha(ImageChops.multiply(arm.getchannel('A'),square_mask));arm.save(case/'paint/needle_hand.png')
# Reconstruct the accepted owners from retained native polygons, so this
# recipe is portable and never depends on a sibling experimental revision.
original_square=Image.new('RGBA',(1448,1448));original_square.paste(original,(181,0))
remaining=Image.new('L',(1448,1448),255);owners={}
for name,points in json.loads((case/'recipes/registration.json').read_text())['native_ownership']:
    owner_mask=Image.new('L',(1448,1448));ImageDraw.Draw(owner_mask).polygon([(x+181,y) for x,y in points],fill=255)
    owner_mask=ImageChops.multiply(owner_mask,remaining);remaining=ImageChops.subtract(remaining,owner_mask)
    image=original_square.copy();image.putalpha(ImageChops.multiply(image.getchannel('A'),owner_mask));owners[name]=image
# All source pixels outside that rigid ownership retain their original owner.
for name in ['head','lantern','coat']:
    im=owners[name].copy()
    im.putalpha(ImageChops.multiply(im.getchannel('A'),ImageChops.invert(square_mask)))
    im.save(case/f'paint/{name}.png')
# Old hand owner also contained sleeve/cloak: return those original pixels to
# the torso, instead of stretching them with the forearm.
old=owners['needle_hand'].copy();old.putalpha(ImageChops.multiply(old.getchannel('A'),ImageChops.invert(square_mask)))
coat=Image.open(case/'paint/coat.png').convert('RGBA');coat=Image.alpha_composite(coat,old);coat.save(case/'paint/coat.png')
# Only hidden material from the generated edit is admitted under the limb.
back=Image.open(case/'source/hidden_torso_generated.png').convert('RGBA').resize(original.size,Image.Resampling.LANCZOS)
back.putalpha(ImageChops.multiply(back.getchannel('A'),mask))
patch=Image.new('RGBA',(1448,1448));patch.paste(back,(181,0));patch.save(case/'paint/underarm.png')
layout=json.loads((case/'source/idle_layout.json').read_text())
for mesh in layout['joint_meshes']:
    mesh.pop('family',None)
    if mesh['replaces_part']=='needle_hand':
        mesh['weights']={b:[1.0 if b=='needle_hand' else 0.0]*len(mesh['vertices']) for b in layout['joints']}
    else:
        for i in range(len(mesh['vertices'])):
            mesh['weights']['chest'][i]+=mesh['weights']['needle_hand'][i]
            mesh['weights']['needle_hand'][i]=0.0
        mesh['family']='body'
# Backing follows the torso, beneath the rigid limb and original costume.
under=copy.deepcopy(next(m for m in layout['joint_meshes'] if m['replaces_part']=='coat'))
under['name']='hidden_torso';under['replaces_part']='underarm';under['file']='paint/underarm.png';under['z_index']=0
arm_mesh=next(m for m in layout['joint_meshes'] if m['replaces_part']=='needle_hand');arm_mesh['z_index']=0
layout['joint_meshes']=[under]+[m for m in layout['joint_meshes'] if m is not arm_mesh]+[arm_mesh]
layout['parts'].append({'name':'underarm','bone':'chest','file':'paint/underarm.png','offset':[0,0],'z_index':0})
(case/'layouts/front_hd.json').write_text(json.dumps(layout,indent=2)+'\n')
(case/'source/gesture_ownership.json').write_text(json.dumps({'native_polygons':polygons,'margin_px':2,'original_offset':[181,0],'generated_patch':'hidden_torso_generated.png','patch_restriction':'rigid limb mask intersect generated alpha; drawn below original limb and original costume'},indent=2)+'\n')
for image in (case/'paint').glob('*.png'):Path(str(image)+'.import').write_text('[remap]\n\nimporter="keep"\n')
if args.promote:
    production=case.parents[3]/'assets/units/graftwright_cutout'
    (production/'front.json').write_text(json.dumps(layout,separators=(',',':'))+'\n')
    for image in (case/'paint').glob('*'):shutil.copyfile(image,production/'paint'/image.name)
