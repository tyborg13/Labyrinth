"""Same-scale old art / mq-16 / mq-21 comparison and exact 3x grip crops."""
import json
from pathlib import Path
from PIL import Image,ImageDraw
from spec.art_identity.maquettes.blender.curate_delivery import write,sha
from ..source_measurements import FOLDER,PROJECT

SHEET_DEFAULTS={'tile_size':1024,'caption_height':32,'background':[24,24,24,255],
                'source_scale':4,'grip_crop_scale':3,'grip_crop_padding_px':8,
                'columns':3,'webp_lossless':True}


def scoped_path(path,capture,project=PROJECT):
    path=Path(path).resolve();capture=Path(capture).resolve();project=Path(project).resolve()
    if path.is_relative_to(capture):return {'scope':'delivery','path':str(path.relative_to(capture))}
    if path.is_relative_to(project):return {'scope':'checkout','path':str(path.relative_to(project))}
    raise ValueError('Contact sheet input outside scoped roots: '+str(path))


def resolve_input(item,capture,project=PROJECT):
    roots={'delivery':Path(capture).resolve(),'checkout':Path(project).resolve()}
    if item.get('scope') not in roots:raise ValueError('Unknown contact sheet path scope')
    root=roots[item['scope']];name=Path(item['path']);path=(root/name).resolve()
    if name.is_absolute() or not path.is_relative_to(root):raise ValueError('External contact sheet input')
    return path


def review_sheet(spec,capture,baseline=None,source=None,project=PROJECT):
    capture=Path(capture);baseline=Path(baseline or FOLDER/'delivery')
    source=Path(source or PROJECT/'assets/units/ashen_reaver.png')
    entries=[('Old art',source,4),('mq-16 front',baseline/'front_clay.png',1),
             ('mq-21 front',capture/'front_clay.png',1),('mq-16 rear',baseline/'rear_clay.png',1),
             ('mq-21 rear',capture/'rear_clay.png',1)]
    size=SHEET_DEFAULTS['tile_size'];caption=SHEET_DEFAULTS['caption_height'];columns=SHEET_DEFAULTS['columns']
    crops=[]
    for view in ('front','rear'):
        hand=Image.open(capture/(view+'_solo_hand_far.png')).convert('RGBA');box=hand.getchannel('A').getbbox()
        if box is None:raise ValueError('Empty sword hand crop: '+view)
        pad=SHEET_DEFAULTS['grip_crop_padding_px'];box=[max(0,box[0]-pad),max(0,box[1]-pad),min(hand.width,box[2]+pad),min(hand.height,box[3]+pad)]
        clay=Image.open(capture/(view+'_clay.png')).convert('RGBA');crop=clay.crop(box)
        crop=crop.resize((crop.width*3,crop.height*3),Image.Resampling.NEAREST)
        name=view+'_sword_hand_3x.png';crop.save(capture/name)
        crops.append({'view':view,'box':box,'scale':3,'path':name,'sha256':sha(capture/name),
                      'source_sha256':sha(capture/(view+'_clay.png')),'solo_sha256':sha(capture/(view+'_solo_hand_far.png'))})
        entries.append(('mq-21 '+view+' sword hand 3x',capture/name,1))
    rows=(len(entries)+columns-1)//columns
    canvas=Image.new('RGBA',(size*columns,(size+caption)*rows),tuple(SHEET_DEFAULTS['background']))
    draw=ImageDraw.Draw(canvas);inputs=[]
    for index,(title,path,scale) in enumerate(entries):
        image=Image.open(path).convert('RGBA')
        if scale!=1:image=image.resize((image.width*scale,image.height*scale),Image.Resampling.NEAREST)
        if image.width>size or image.height>size:raise ValueError('Proof tile would crop or rescale '+title)
        x=index%columns*size;y=index//columns*(size+caption)
        canvas.alpha_composite(image,(x+(size-image.width)//2,y+caption+(size-image.height)//2));draw.text((x+8,y+8),title,fill='white')
        inputs.append({'title':title,**scoped_path(path,capture,project),'sha256':sha(path),'display_scale':scale})
    canvas.save(capture/'mq21_contact_sheet.webp',lossless=True,method=6)
    result={'inputs':inputs,'crops':crops,'size':list(canvas.size),'layout':SHEET_DEFAULTS,
            'sheet_sha256':sha(capture/'mq21_contact_sheet.webp'),
            'camera_scale':spec['ortho_scale'],'registration':'Fixed mq-16 native scale for both generations; old art exact 4x NEAREST, hand crops exact 3x NEAREST.'}
    write(capture/'mq21_contact_sheet.json',result)
    print('MQ21_CONTACT_SHEET: PASS; '+str(capture/'mq21_contact_sheet.webp'))
    return result


def verify_sheet(capture,project=PROJECT):
    import numpy as np
    capture=Path(capture);record=json.loads((capture/'mq21_contact_sheet.json').read_text())
    if record['sheet_sha256']!=sha(capture/'mq21_contact_sheet.webp'):raise ValueError('Contact sheet changed')
    for item in record['inputs']:
        if sha(resolve_input(item,capture,project))!=item['sha256']:raise ValueError('Contact sheet input changed')
    for row in record['crops']:
        path=capture/row['path'];source=capture/(row['view']+'_clay.png');solo=capture/(row['view']+'_solo_hand_far.png')
        if sha(path)!=row['sha256'] or sha(source)!=row['source_sha256'] or sha(solo)!=row['solo_sha256']:
            raise ValueError('Sword hand crop input changed')
        with Image.open(source) as clay,Image.open(path) as crop:
            expected=clay.convert('RGBA').crop(row['box'])
            expected=expected.resize((expected.width*3,expected.height*3),Image.Resampling.NEAREST)
            if row['scale']!=3 or not np.array_equal(expected,crop.convert('RGBA')):raise ValueError('Sword hand crop is not exact 3x')
    return True
