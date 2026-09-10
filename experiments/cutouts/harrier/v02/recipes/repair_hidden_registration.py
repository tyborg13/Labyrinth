"""Register generated concealed anatomy to the painted creature's actual hip/knee landmarks.
No new paint: explicit component ownership, affine fitting, and opaque cloth masks.
"""
from pathlib import Path
import json, shutil
from PIL import ImageChops
from PIL import Image, ImageDraw
C=Path('experiments/cutouts/harrier/v02')
def component(source, polygon, before, after):
    mask=Image.new('L',source.size);ImageDraw.Draw(mask).polygon(polygon,fill=255)
    part=source.copy();part.putalpha(ImageChops.darker(source.getchannel('A'),mask))
    def solve(values):
        x0,y0=after[0];x1,y1=after[1];x2,y2=after[2]
        det=(x1-x0)*(y2-y0)-(x2-x0)*(y1-y0)
        a=((values[1]-values[0])*(y2-y0)-(values[2]-values[0])*(y1-y0))/det
        b=((x1-x0)*(values[2]-values[0])-(x2-x0)*(values[1]-values[0]))/det
        return a,b,values[0]-a*x0-b*y0
    matrix=solve([v[0] for v in before])+solve([v[1] for v in before])
    return part.transform((255,255),Image.Transform.AFFINE,matrix,Image.Resampling.BICUBIC)
records={}
for view in ['front','rear']:
    layout=json.loads((C/'layouts'/f'{view}_complete_skinned.json').read_text())
    source=Image.open(C/'source'/('hidden_registered.png' if view=='front' else 'rear_pelvis_registered.png')).convert('RGBA')
    if view=='front':
        fits={
            'spine_undercloth': ([[145,106],[158,106],[159,130],[145,130]], [[153,110],[153,127],[148,115]], [[146,110],[146,131],[141,115]]),
            'pelvis_undercloth': ([[134,119],[171,119],[159,146],[147,146],[137,134]], [[137,131],[165,136],[153,122]], [[130,131],[163,137],[145,122]]),
            'thigh_fill_r': ([[133,130],[142,136],[114,160],[103,157]], [[137,135],[109,156],[135,143]], [[130,131],[103,152],[128,139]]),
            'thigh_fill_l': ([[164,133],[173,135],[173,171],[161,170]], [[168,138],[166,169],[173,139]], [[163,137],[163,169],[168,138]])}
    else:
        fits={
            'spine_undercloth': ([[111,126],[124,126],[127,145],[111,145]], [[118,128],[118,141],[113,132]], [[115,119],[119,135],[111,125]]),
            'pelvis_undercloth': ([[96,120],[140,120],[138,149],[129,152],[107,150],[98,138]], [[107,146],[134,144],[118,130]], [[101,151],[135,142],[117,130]]),
            'thigh_fill_l': ([[102,142],[111,142],[114,160],[105,160]], [[106,146],[109,157],[111,146]], [[101,153],[96,166],[106,153]]),
            'thigh_fill_r': ([[129,141],[140,142],[143,160],[132,162]], [[134,146],[137,157],[139,146]], [[135,142],[145,150],[139,139]])}
    cloth=next(p for p in layout['parts'] if p['name']=='waistcloth');mask=Image.new('RGBA',(255,255));mask.alpha_composite(Image.open(C/cloth['file']),tuple(cloth['offset']))
    baseline=Image.open(C/'source'/f'{view}_registered.png').convert('RGBA')
    records[view]={}
    for name,(polygon,before,after) in fits.items():
        fitted=component(source,polygon,before,after)
        selected=fitted.copy()
        for y in range(255):
            for x in range(255):
                if mask.getpixel((x,y))[3]<250 or baseline.getpixel((x,y))[3]<(255 if view=='front' else 250):selected.putpixel((x,y),(0,0,0,0))
        box=selected.getbbox();assert box,name
        part=next((p for p in layout['parts'] if p['name']==name),None)
        if part is None:
            part={'name':name,'file':f'assets/{view}/{name}.png','offset':list(box[:2]),'bone':'pelvis','z_index':5,'equipment_slot':'body'}
            layout['parts'].append(part);selected.crop(box).save(C/part['file'])
        # Existing mesh geometry retains its original crop coordinates; retain a full source-space crop that covers both.
        old=Image.open(C/part['file']);ox,oy=part['offset'];bounds=(min(ox,box[0]),min(oy,box[1]),max(ox+old.width,box[2]),max(oy+old.height,box[3]))
        selected.crop(bounds).save(C/part['file']);part['offset']=list(bounds[:2])
        records[view][name]={'polygon':polygon,'source_landmarks':before,'target_landmarks':after,'offset':list(bounds[:2]),'selection':'Generated pixels masked by original cloth alpha >=250; front baseline alpha=255, rear alpha>=250'}
    # Rebuild mesh geometry and UVs for the changed registered crop.
    raw=json.loads((C/'layouts'/f'{view}_with_pelvis.json').read_text())
    for part in layout['parts']:
        if part['name'] in fits and not any(q['name']==part['name'] for q in raw['parts']):raw['parts'].append(part)
    for part in raw['parts']:
        if part['name'] in fits:
            current=next(p for p in layout['parts'] if p['name']==part['name']);part['offset']=current['offset']
    (C/'layouts'/f'{view}_registered_anatomy.json').write_text(json.dumps(raw,indent=2)+'\n')
    recipe=json.loads((C/'recipes'/f'{view}_pelvis_skin.json').read_text())
    recipe['input_layout']=f'layouts/{view}_registered_anatomy.json'
    recipe['output_layout']=f'layouts/{view}_final_skinned.json'
    (C/'recipes'/f'{view}_registered_skin.json').write_text(json.dumps(recipe,indent=2)+'\n')
(C/'recipes/hidden_anatomy_registration.json').write_text(json.dumps(records,indent=2)+'\n')
