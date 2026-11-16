#!/usr/bin/env python3
"""Collect requested 1x/2x NEAREST idle keys from verified native render proof."""
from pathlib import Path
import argparse
import json
import colorsys
import numpy as np
from round1_checks import sack_mask, green_count, CASE
from PIL import Image

IDLE_SECONDS = 3.36
# One full bob at 0.21s, plus eye/sack glow peaks and the complete loop seam.
TIMES = sorted(set([round(n * 0.21, 2) for n in range(9)] + [2.52, 3.36]))
NATIVE_REGION = (128, 128, 383, 383)

def check_native(render, record, case):
    mask=sack_mask(case)
    paint=np.array(Image.open(case/'source/front/processed.png').convert('RGBA'))
    # Glow is deliberately animated; only the original ember texels may differ.
    for y,x in np.argwhere(mask):
        h,s,v=colorsys.rgb_to_hsv(*(paint[y,x,:3]/255))
        if 15<=h*360<=35 and s>=.75: mask[y,x]=False
    baseline=None;green=0;seam=0;peak_frame=0
    for index in range(record['cycle_frames']):
        path=render/record['folder']/('pose_%04d.png'%index)
        with Image.open(path) as image:
            if image.size!=(512,512):raise ValueError('Unexpected native action canvas')
            native=image.convert('RGBA').crop(NATIVE_REGION)
        green=max(green,green_count(native))
        pixels=np.array(native)
        if baseline is None:baseline=pixels.copy()
        changed=int(np.any(pixels[mask]!=baseline[mask],axis=-1).sum())
        if changed>seam:seam=changed;peak_frame=index
    result={'ok':green==0 and seam==0,'frames':record['cycle_frames'],'max_green_pixels':green,
            'max_changed_sack_pixels':seam,'peak_sack_frame':peak_frame,'static_sack_pixels':int(mask.sum())}
    print('EMAC NATIVE PIXELS: %s; '%('PASS' if result['ok'] else 'FAIL')+json.dumps(result,sort_keys=True))
    return result

def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--render',type=Path,required=True);p.add_argument('--case',type=Path,default=CASE);p.add_argument('--check-only',action='store_true');a=p.parse_args()
    manifest=json.loads((a.render/'render_manifest.json').read_text())
    record=next(r for r in manifest['clips'] if r['facing']=='front' and r['clip']=='idle')
    if manifest.get('errors'):raise ValueError('Native render reported failures')
    checks=check_native(a.render,record,a.case)
    if not checks['ok']:raise SystemExit(1)
    if a.check_only:return
    folder=a.render/'keyframes';folder.mkdir(exist_ok=False)
    files=[]
    for seconds in TIMES:
        index=round((seconds%IDLE_SECONDS)/record['frame_seconds'])%record['cycle_frames']
        source=a.render/record['folder']/('pose_%04d.png'%index)
        with Image.open(source) as image:
            if image.size!=(512,512):raise ValueError('Unexpected native action canvas')
            native=image.convert('RGBA').crop(NATIVE_REGION)
        for scale in (1,2):
            name='idle_%05.2fs_%dx.png'%(seconds,scale)
            native.resize((255*scale,255*scale),Image.Resampling.NEAREST).save(folder/name)
            files.append(name)
    (folder/'manifest.json').write_text(json.dumps({'times_seconds':TIMES,'files':files,'region':NATIVE_REGION,'resample':'NEAREST','native_pixels':checks,'native_seam_review':'Pixel gates pass; director anatomy/contact inspection remains required'},indent=2)+'\n')
    print('EMAC NATIVE KEYS: PASS; 11 times; 22 PNGs; '+str(folder))
if __name__=='__main__':main()
