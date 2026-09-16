from pathlib import Path
import json, shutil, hashlib, sys, argparse
from PIL import Image, ImageDraw
root=Path(__file__).resolve().parents[5]; sys.path.insert(0,str(root/'tools'))
from cutout_pipeline.assets import segment,apply_skin
from cutout_pipeline.cases import write_json, init_case
parser=argparse.ArgumentParser(description='Rebuild the Graftwright ownership and HD skin in a fresh cutout case.')
parser.add_argument('--output',type=Path,required=True)
parser.add_argument('--promote',action='store_true',help='Explicitly replace the production layout and paint')
args=parser.parse_args();case=args.output.resolve();init_case(case,'graftwright',['front'])
shutil.copyfile(root/'scripts/graftwright_cutout/motion.gd',case/'motion.gd')
(case/'source').mkdir(exist_ok=True); (case/'recipes').mkdir(exist_ok=True); (case/'paint').mkdir(exist_ok=True)
source=root/'assets/art/npcs/graftwright.png'; shutil.copyfile(source,case/'source/original.png')
im=Image.open(source).convert('RGBA'); square=Image.new('RGBA',(1448,1448));square.paste(im,(181,0)); registered=square.resize((255,255),Image.Resampling.LANCZOS);registered.save(case/'source/registered.png')
# Explicit priority ownership in original-paint coordinates. Art is not repainted.
native=[['head',[[326,0],[785,0],[785,326],[706,401],[619,447],[546,427],[507,416],[490,374],[369,329],[296,409],[298,181]]],['needle_hand',[[1017,206],[1086,206],[1086,685],[933,684],[904,626],[851,671],[800,707],[722,810],[670,874],[616,861],[570,799],[633,696],[674,610],[694,485],[744,417],[798,385],[813,319],[875,267]]],['lantern',[[272,399],[336,404],[355,453],[324,484],[272,492],[253,566],[269,609],[291,645],[297,851],[266,898],[266,962],[226,1001],[172,966],[165,884],[128,861],[110,891],[50,891],[2,802],[0,694],[79,619],[114,484],[170,437]]],['coat',[[0,0],[1086,0],[1086,1448],[0,1448]]]]
logical=[[name,[[(x+181)*255/1448,y*255/1448] for x,y in pts]] for name,pts in native]
own={'priority_polygons':logical,'pixel_overrides':[]};write_json(case/'source/ownership.json',own)
report=segment(case/'source/registered.png',case/'source/ownership.json',case/'segmented')
# Transparent antialias fringe introduced only by registration may fall outside
# native polygons; make the explicit coat owner cover the full registered canvas.
if not report['ok']:
    shutil.rmtree(case/'segmented'); own['priority_polygons'][-1][1]=[[0,0],[255,0],[255,255],[0,255]];write_json(case/'source/ownership.json',own);report=segment(case/'source/registered.png',case/'source/ownership.json',case/'segmented')
assert report['ok']
remaining=Image.new('L',square.size,255)
for name,points in native:
    mask=Image.new('L',square.size); ImageDraw.Draw(mask).polygon([(x+181,y) for x,y in points],fill=255)
    from PIL import ImageChops
    mask=ImageChops.multiply(mask,remaining); remaining=ImageChops.subtract(remaining,mask)
    part=square.copy();part.putalpha(ImageChops.multiply(square.getchannel('A'),mask));part.save(case/f'paint/{name}.png')
    # The maintained skin tool authors the logical field on registered paint.
    low=Image.new('RGBA',(255,255));spec=next(p for p in report['parts'] if p['name']==name); crop=Image.open(case/'segmented'/spec['file']);low.paste(crop,tuple(spec['offset']));low.save(case/f'source/{name}_registered.png')
joints={'root':{'parent':None,'position':[128,246]},'chest':{'parent':'root','position':[126,146]},'head':{'parent':'chest','position':[132,58]},'needle_hand':{'parent':'chest','position':[172,91]},'lantern':{'parent':'chest','position':[71,134]}}
layout={'version':1,'facing':'front','canvas_size':[255,255],'joints':joints,'parts':[{'name':name,'bone':name if name!='coat' else 'chest','file':f'source/{name}_registered.png','offset':[0,0],'z_index':0} for name,_ in native],'joint_meshes':[],'landmarks':{'mask':[134,48],'needle_grip':[177,85],'cuff':[144,143],'bench_contact':[127,232]}}
write_json(case/'layouts/front.json',layout)
recipe={'facing':'front','input_layout':'layouts/front.json','output_layout':'layouts/front_skin.json','fields':[{'name':'continuous_body','parts':[n for n,_ in native],'bones':['root','chest','head'],'grid':[6,6],'bands':[{'center':[128,216],'axis':[0,-1],'width':62},{'center':[132,86],'axis':[0,-1],'width':24}]}]};write_json(case/'recipes/body_skin.json',recipe);apply_skin(case,case/'recipes/body_skin.json')
layout=json.loads((case/'layouts/front_skin.json').read_text())
def smooth(v):
    v=max(0,min(1,v));return v*v*(3-2*v)
for mesh in layout['joint_meshes']:
    mesh['file']=f"paint/{mesh['replaces_part']}.png"
    mesh['uvs']=[[x*1448/255,y*1448/255] for x,y in mesh['vertices']]
    weights={b:[] for b in joints}
    for x,y in mesh['vertices']:
        # One field for every paint owner: shared edges deform identically.
        chest=1-smooth((y-185)/62)
        hand=smooth((x-(186-.28*y))/12)*(1-smooth((y-130)/37))
        head=(1-smooth((y-74)/24))*(1-hand)
        lantern=(1-smooth((x-74)/18))*smooth((y-77)/20)*(1-smooth((y-176)/24))*(1-head)*(1-hand)
        body=max(0,1-hand-head-lantern)
        row={'root':body*(1-chest),'chest':body*chest,'head':head,'needle_hand':hand,'lantern':lantern}
        total=sum(row.values())
        for b in weights:weights[b].append(round(row[b]/total,8))
    mesh['weights']=weights
    mesh['coordinate_space']='255px logical vertices; original 1448px square source UVs, no production resampling'
for part in layout['parts']: part['file']=f"paint/{part['name']}.png"
write_json(case/'layouts/front_hd.json',layout)
config=json.loads((case/'cutout.json').read_text());config['layouts']={'front':'layouts/front_hd.json'};config['clips']['idle']={'frames':48,'duration':2.4,'loop':True,'preview_cycles':2};config['rigid_bones']=['head','needle_hand','lantern'];config['sources']=sorted(set(config['sources']+['source/original.png','source/registered.png','source/ownership.json','segmented/segmentation.json','recipes/build_case.py','recipes/registration.json','layouts/front_skin.json']+[f'source/{n}_registered.png' for n,_ in native]));config['source_baseline']={'kind':'existing_npc_portrait','commit':'e97ac78c4fe8df14b8884500ffdc57bbf0628a18','source_sha256':hashlib.sha256(source.read_bytes()).hexdigest(),'art_status':'Original full-resolution paint; explicit ownership, continuous shared skin; no generated fill needed for translation-only idle.'};write_json(case/'cutout.json',config)
write_json(case/'recipes/registration.json',{'original_size':[1086,1448],'square_size':[1448,1448],'original_offset':[181,0],'logical_size':[255,255],'uv_scale':1448/255,'visible_paint_preserved':True,'motion':'Stationary root; coordinated chest/head bob, slightly delayed needle hand and lantern. No periodic rotation or cloth ripple. Shared skin at every ownership boundary preserves covered joints.','native_ownership':native})
shutil.copyfile(__file__,case/'recipes/build_case.py')
for path in case.rglob('*.png'): Path(str(path)+'.import').write_text('[remap]\n\nimporter="keep"\n')
if args.promote:
    prod=root/'assets/units/graftwright_cutout';(prod/'paint').mkdir(parents=True,exist_ok=True)
    for name,_ in native:shutil.copyfile(case/f'paint/{name}.png',prod/f'paint/{name}.png')
    (prod/'front.json').write_text(json.dumps(layout,separators=(',',':'))+'\n')
    for path in prod.rglob('*.png'): Path(str(path)+'.import').write_text('[remap]\n\nimporter="keep"\n')
