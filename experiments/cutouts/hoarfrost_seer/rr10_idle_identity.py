"""Read-only source idle identity audit; idle groups are rigid translations.

No mesh skinning/raster oracle: the binding idle contract forbids deformation,
so source layers are only shifted by their sampled whole-pixel group offset.
"""
import argparse
from io import BytesIO
import json
from pathlib import Path
import subprocess
import sys

import numpy as np
from PIL import Image

PROJECT=Path(__file__).resolve().parents[3]
sys.path.insert(0,str(PROJECT/'tools'))
from cutout_pipeline.cases import read_json
from humanoid_cutout.gates import EPSILON

CASE=PROJECT/'experiments/cutouts/hoarfrost_seer/rr10'


def historical(reference,path):
    return subprocess.run(['git','show',reference+':'+str(path.relative_to(PROJECT))],cwd=PROJECT,
                          check=True,capture_output=True).stdout


def layers(layout,reference=None):
    result={}
    for part in layout['parts']:
        path=CASE/part['file']
        image=Image.open(BytesIO(historical(reference,path)) if reference else path).convert('RGBA')
        source=Image.new('RGBA',tuple(layout['canvas_size']))
        source.paste(image,tuple(part['offset']))
        result[part['name']]=source
    return result


def composite(layout,images,row):
    result=Image.new('RGBA',tuple(layout['canvas_size']))
    for part in sorted(layout['parts'],key=lambda p:p['z_index']):
        bone=row['bones'][part['bone']]['global']
        if not np.allclose(bone[:4],[1,0,0,1],atol=EPSILON,rtol=0):
            raise ValueError('Idle is not a rigid translation: '+part['name'])
        offset=np.asarray(bone[4:])-layout['joints'][part['bone']]['position']
        if not np.allclose(offset,np.rint(offset),atol=EPSILON,rtol=0):
            raise ValueError('Idle source offset is not whole pixels')
        result.alpha_composite(images[part['name']],tuple(np.rint(offset).astype(int)))
    return np.asarray(result)


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--reference',required=True)
    args=parser.parse_args()
    layout=read_json(CASE/'layouts/front.json')
    previous=json.loads(historical(args.reference,CASE/'layouts/front.json'))
    current,old=layers(layout),layers(previous,args.reference)
    rows=[r for r in read_json(CASE/'proof/samples.json')['samples'] if r['kind']=='presented' and r['clip']=='idle']
    # New continuations may be exposed by the approved bob (director feedback
    # 1 explicitly permits exposed tucks). Preserve original source texels and
    # report those additional cloth appearances separately from paint changes.
    without_new={}
    original_source_changes=0
    for part in layout['parts']:
        name=part['name'];a=np.array(current[name]);b=np.asarray(old[name])
        original_source_changes+=int((np.any(a!=b,axis=-1)&(b[...,3]>0)).sum())
        added=(a[...,3]>0)&(b[...,3]==0)
        checks=layout['proof_layers'][name]
        check_source=Image.new('RGBA',tuple(layout['canvas_size']))
        check_source.paste(Image.open(CASE/checks['mask']).convert('RGBA'),tuple(checks['mask_offset']))
        if (added & (np.asarray(check_source)[...,1]==0)).any():
            raise ValueError('Added idle source pixels outside authorized continuation: '+name)
        a[added]=0
        without_new[name]=Image.fromarray(a)
    original_frame_changes,new_tuck_appearances=0,0
    affected_frames,maximum_tuck_pixels=0,0
    for row in rows:
        a,b=composite(layout,current,row),composite(previous,old,row)
        stripped=composite(layout,without_new,row)
        original_frame_changes+=int((np.any(stripped!=b,axis=-1)&((stripped[...,3]>0)|(b[...,3]>0))).sum())
        appearances=int((np.any(a!=b,axis=-1)&((a[...,3]>0)|(b[...,3]>0))).sum())
        new_tuck_appearances+=appearances
        affected_frames+=int(appearances>0)
        maximum_tuck_pixels=max(maximum_tuck_pixels,appearances)
    ok=not original_source_changes and not original_frame_changes
    print('RR10 SOURCE IDLE PRESERVATION: %s (%d poses; %d original source changes; %d original frame changes; %d new tuck pixel appearances; reference %s)'%(
        'PASS' if ok else 'FAIL',len(rows),original_source_changes,original_frame_changes,new_tuck_appearances,args.reference))
    print('RR10 IDLE TUCK DELTA: %d affected frames; maximum %d added pixels per frame'%(affected_frames,maximum_tuck_pixels))
    return int(not ok)



if __name__=='__main__':raise SystemExit(main())
