"""Native-image crops, same-scale comparison, and fail-closed delivery binding."""
import json
from pathlib import Path
from PIL import Image,ImageDraw
from spec.art_identity.maquettes.blender.contract import digest
from spec.art_identity.maquettes.blender.curate_delivery import write,sha
from spec.art_identity.maquettes.blender.capture_manifest import read_manifest
from .oracle import baseline,contract,protected
from .capture_gate import inspect as inspect_capture

FOLDER=Path(__file__).resolve().parent
PROJECT=FOLDER.parents[4]


def proof_images(capture):
    capture=Path(capture);defaults=json.loads((FOLDER/'chosen_defaults.json').read_text());crops=[]
    for view in ('front','rear'):
        clay=Image.open(capture/(view+'_clay.png')).convert('RGBA')
        for side in ('near','far'):
            solo=Image.open(capture/(view+'_solo_hand_'+side+'.png')).convert('RGBA')
            box=solo.getchannel('A').getbbox()
            if box is None:raise ValueError('Empty hand solo')
            padding=defaults['hand_crop_padding_px'];box=(max(0,box[0]-padding),max(0,box[1]-padding),min(clay.width,box[2]+padding),min(clay.height,box[3]+padding))
            image=clay.crop(box);scale=defaults['hand_crop_scale'];name=view+'_hand_'+side+'_3x.png'
            image.resize((image.width*scale,image.height*scale),Image.Resampling.NEAREST).save(capture/name)
            crops.append({'path':name,'source':view+'_clay.png','source_sha256':sha(capture/(view+'_clay.png')),
                'solo_sha256':sha(capture/(view+'_solo_hand_'+side+'.png')),'crop_box':list(box),'scale':scale,'sha256':sha(capture/name)})
    panels=[(PROJECT/'assets/units/last_lamplighter.png','Old art',4),
        (FOLDER.parent/'mq20/delivery/front_clay.png','mq-20 front',1),(capture/'front_clay.png','mq-24 front',1),
        (FOLDER.parent/'mq20/delivery/rear_clay.png','mq-20 rear',1),(capture/'rear_clay.png','mq-24 rear',1)]
    width=defaults['sheet_panel_width_px'];sheet=Image.new('RGBA',(width*5,defaults['sheet_height_px']),tuple(defaults['sheet_background_rgba']));draw=ImageDraw.Draw(sheet);inputs=[]
    for k,(path,label,scale) in enumerate(panels):
        image=Image.open(path).convert('RGBA');image=image.resize((image.width*scale,image.height*scale),Image.Resampling.NEAREST)
        box=image.getchannel('A').getbbox()
        if box is None:raise ValueError('Empty comparison input')
        # Align actual sole pixels without fitting any individual figure.
        y=defaults['sheet_sole_y_px']-box[3];x=k*width+(width-image.width)//2
        if y+box[1]<0 or y+box[3]>sheet.height:raise ValueError('Comparison would clip native geometry')
        sheet.alpha_composite(image,(x,y));draw.text((k*width+12,12),label,fill=(230,230,230,255))
        inputs.append({'path':str(path.resolve()),'sha256':sha(path),'scale':scale,'translation_px':[x,y]})
    sheet.convert('RGB').save(capture/'contact_sheet.webp',lossless=True)
    write(capture/'proof_images.json',{'crops':crops,'contact_sheet':{'inputs':inputs,'sha256':sha(capture/'contact_sheet.webp'),'size':list(sheet.size)}})


def acceptance(spec,capture,save=True):
    capture=Path(capture);c=contract();old=baseline();native=json.loads((capture/'native_probe.json').read_text())
    manifest=read_manifest(capture,digest(spec),('full',));images=set(manifest['images']);required=set()
    for view in ('front','rear'):
        required|={view+'_'+kind+'.png' for kind in ('clay','parts')}
        required|={view+'_solo_'+part+'.png' for part in spec['labels']}
    checks={'design_resolved':not spec['mq24']['design_pending'],'protected_mq20_bytes':protected(),
        'native_passed':native.get('passed') is True and all(native.get('checks',{}).values()),
        'native_binding':native.get('spec_hash')==digest(spec),'native_mutations':native.get('mutations',{}).get('caught')==6 and native.get('mutations',{}).get('survived')==0,
        'capture_inventory':required<=images,'no_pauldron_labels':not any(k.startswith('pauldron_') for k in spec['labels']),
        'mantle_label_removed':'mantle' not in spec['labels'],'hand_near_label':spec['labels']['hand_near']==c['near_hand']['label_colour'],
        'hand_far_label':spec['labels']['hand_far']==c['far_hand']['label_colour'],
        'camera_preserved':spec['view_transforms']==old['view_transforms'] and spec['ortho_scale']==old['ortho_scale']}
    for name in required:
        checks[name+'_size']=Image.open(capture/name).size==(1088,1088)
    capture_check=json.loads((capture/'capture_checks.json').read_text());checks['capture_geometry']=capture_check.get('passed') is True and capture_check.get('geometry_unchanged') is True
    image_gate=inspect_capture(spec,capture);checks.update(image_gate['checks'])
    result={'passed':all(checks.values()),'accepted':all(checks.values()),'checks':checks,'spec_hash':digest(spec),'native_capture_gate':image_gate}
    if save:write(capture/'mq24_acceptance.json',result)
    return result


def tables(capture,native):
    capture=Path(capture)
    rows=['| Segment | mq-20 m | mq-24 m | Ratio | Pass |','|---|---:|---:|---:|---|']
    for r in native['segment_lengths']:
        rows.append('| {piece} | {mq20_m:.9f} | {mq24_m:.9f} | {ratio:.9f} | {passed} |'.format(**r))
    (capture/'segment_lengths.md').write_text('\n'.join(rows)+'\n')
    mutations=native.get('mutations',{});rows=['| Mutation | Caught |','|---|---|']
    rows += ['| '+r['mutation']+' | '+str(r['caught'])+' |' for r in mutations.get('rows',[])]
    rows += ['','Caught: '+str(mutations.get('caught',0))+'; survived: '+str(mutations.get('survived',0))+'; status: '+mutations.get('status','not_run')]
    (capture/'mutation_table.md').write_text('\n'.join(rows)+'\n')
