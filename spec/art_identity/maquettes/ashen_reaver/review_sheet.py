"""Same-scale current art, native pair and mq-15 scale reference; proof only."""
import json
from pathlib import Path
from PIL import Image,ImageDraw
from spec.art_identity.maquettes.blender.curate_delivery import write,sha
from .source_measurements import FOLDER,PROJECT

SHEET_DEFAULTS={'tile_size':1024,'caption_height':32,'background':[24,24,24,255],
                'source_scale':4,'webp_lossless':True}


def review_sheet(spec,capture):
    capture=Path(capture)
    references=[('Current front art',PROJECT/'assets/units/ashen_reaver.png','source'),
        ('Ashen Reaver front clay',capture/'front_clay.png','native'),
        ('Ashen Reaver rear clay: true 180 turn',capture/'rear_clay.png','native'),
        ('Chainbound Gaoler mq-15 front: scale reference',FOLDER.parent/'chainbound_gaoler/delivery/front_clay.png','native')]
    size=SHEET_DEFAULTS['tile_size'];caption=SHEET_DEFAULTS['caption_height']
    canvas=Image.new('RGBA',(size*len(references),size+caption),tuple(SHEET_DEFAULTS['background']))
    draw=ImageDraw.Draw(canvas);inputs=[]
    area=json.loads((capture/'mq16_acceptance.json').read_text())['blade_area']
    for index,(title,path,kind) in enumerate(references):
        image=Image.open(path).convert('RGBA')
        if kind=='source':image=image.resize((image.width*4,image.height*4),Image.Resampling.NEAREST)
        x=index*size+(size-image.width)//2;y=caption+(size-image.height)//2
        canvas.alpha_composite(image,(x,y));draw.text((index*size+8,8),title,fill='white')
        if index in (1,2):
            view='front' if index==1 else 'rear'
            draw.text((index*size+8,20),'Blade area '+str(area['pixels'][view])+' px; rear/front '+format(area['rear_over_front'],'.6f'),fill='white')
        inputs.append({'title':title,'path':str(path.relative_to(PROJECT)),'sha256':sha(path),
                       'display_scale':4 if kind=='source' else 1})
    canvas.save(capture/'contact_sheet.webp',lossless=True,method=6)
    write(capture/'contact_sheet.json',{'inputs':inputs,'proof_layout':SHEET_DEFAULTS,
        'size':list(canvas.size),'sheet_sha256':sha(capture/'contact_sheet.webp'),
        'registration':'Native PNGs remain at 1:1; current 255px source at exact 4x NEAREST. No per-figure normalization.'})
    print('MQ16_CONTACT_SHEET: PASS; '+str(capture/'contact_sheet.webp'))
