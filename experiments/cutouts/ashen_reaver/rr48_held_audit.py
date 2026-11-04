"""Production release inventory and 3x CPU diagnostic strips (never native)."""
import argparse
from pathlib import Path
import numpy as np
from PIL import Image,ImageDraw
from cutout_pipeline.cases import read_json,write_json
from maquette_motion import pixels
from humanoid_cutout.gates import matrix
from rr48_weapon_ownership import released_part
from rr48_build import ROOT

DEFAULTS={'canvas_size_px':1024,'source_offset_px':384,'strip_gutter_px':24,'magnification':3}

def render(samples,output):
    output.mkdir(parents=True,exist_ok=True);records=[]
    previous=dict(pixels.PROOF_DEFAULTS)
    pixels.PROOF_DEFAULTS.update(canvas_size=DEFAULTS['canvas_size_px'],source_offset=DEFAULTS['source_offset_px'])
    try:
        for r in samples['inventory']:
            layout=r['layout'];base=ROOT/'assets/units'/r['rig']/'humanoid_v2';attachment=layout['held_items'][r['item']];images=[]
            for row in r['samples']:
                composite=Image.new('RGBA',(DEFAULTS['canvas_size_px'],)*2)
                for part in sorted(layout['parts'],key=lambda p:p['z_index']):
                    if part['logical_part'] not in (r['item'],attachment['hand']):continue
                    active=released_part(part,'death',row['phase']);paint=np.asarray(Image.open(base/active['file']).convert('RGBA'))
                    composite.alpha_composite(Image.fromarray(pixels.render(paint,matrix(row['parts'][part['name']]['transform']))))
                images.append(composite)
            bounds=[im.getbbox() for im in images if im.getbbox()];bbox=(min(b[0] for b in bounds),min(b[1] for b in bounds),max(b[2] for b in bounds),max(b[3] for b in bounds))
            width=(bbox[2]-bbox[0])*3;height=(bbox[3]-bbox[1])*3;gutter=DEFAULTS['strip_gutter_px']
            strip=Image.new('RGBA',(4*width,height+gutter),(42,42,47,255));draw=ImageDraw.Draw(strip)
            for i,(im,row) in enumerate(zip(images,r['samples'])):
                strip.alpha_composite(im.crop(bbox).resize((width,height),Image.Resampling.NEAREST),(i*width,gutter));draw.text((i*width,0),f'{r["rig"]} {r["view"]} frame {row["frame"]}',fill='white')
            path=output/f'{r["rig"]}_{r["view"]}_drop_3x_cpu.png';strip.save(path)
            records.append({'rig':r['rig'],'view':r['view'],'item':r['item'],'release':r['release'],'frames':[row['frame'] for row in r['samples']],'capture':str(path),'native_pixels':False})
    finally:pixels.PROOF_DEFAULTS.clear();pixels.PROOF_DEFAULTS.update(previous)
    write_json(output/'inventory.json',{'native_pixels':False,'defaults':DEFAULTS,'records':records})
    print('RR57 HELD-ITEM AUDIT: 6 rigs / 12 view-items; diagnostic strips '+str(output))

if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--samples',type=Path,required=True);p.add_argument('--output',type=Path,required=True);a=p.parse_args();render(read_json(a.samples),a.output)
