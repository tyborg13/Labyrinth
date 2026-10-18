"""Extract director-native body masks for rigid wrist/foot tuck regressions.

No mesh rasterization: body ownership, seam and rest-hole masks are read from
existing GPU captures. Updated rigid tucks use the established rr-05 path.
"""
import sys
from pathlib import Path

import numpy as np
from PIL import Image

PROJECT = Path(__file__).resolve().parents[3]
sys.path.insert(0,str(PROJECT/'tools'))
from cutout_pipeline.cases import read_json, write_json, digest
from humanoid_cutout.silhouette_gates import posed_owners
from humanoid_cutout.anatomy import load as load_anatomy
from maquette_motion.pixels import PROOF_DEFAULTS

CASE = PROJECT/'experiments/cutouts/hoarfrost_seer/rr10'
OUTPUT = PROJECT/'tests/rr10/feedback4'
CASES = [('mark',30,'hidden_hand_far'),('death',30,'hidden_hand_far'),('move',9,'hidden_foot_near'),('bolt',27,None)]
RIGID_TUCKS = ('hidden_hand_near','hidden_hand_far','hidden_foot_near','hidden_foot_far')


def main():
    capture=CASE/'proof/native'
    manifest=read_json(capture/'frames.json')
    layout=read_json(CASE/'layouts/front.json')
    samples=read_json(CASE/'proof/samples.json')
    OUTPUT.mkdir(parents=True,exist_ok=True)
    records=[]
    for clip,frame,target in CASES:
        selected=lambda r:r['view']=='front' and r['clip']==clip and r['frame']==frame
        rows=[r for r in manifest['pieces'] if selected(r)]
        layers=[(r,np.asarray(Image.open(capture/r['file']).convert('RGBA')),None) for r in rows if r['name'] not in RIGID_TUCKS]
        pose=next(r for r in samples['samples'] if selected(r) and r['kind']=='presented')
        owners=posed_owners(layers,layout['parts'],pose['bones'],PROOF_DEFAULTS['source_offset'], load_anatomy(CASE)['ownership'])
        seam=np.logical_or.reduce([np.asarray(Image.open(capture/r['file']).convert('RGBA'))[...,3]>0 for r in manifest['joint_seams'] if selected(r)])
        references=np.zeros(owners.shape,dtype=np.uint8)
        holes=[r for r in manifest['rest_holes'] if selected(r)]
        if len(holes)>8:raise ValueError('Fixture rest-hole bitfield overflow')
        for index,row in enumerate(holes):
            references[np.asarray(Image.open(capture/row['file']).convert('RGBA'))[...,3]>0] |= 1<<index
        masks={'owners':owners,'seam':seam.astype(np.uint8)*255,'rest_holes':references}
        if target is not None:
            old=next(r for r in rows if r['name']==target)
            masks['regression_tuck']=(np.asarray(Image.open(capture/old['file']).convert('RGBA'))[...,3]>0).astype(np.uint8)*255
        files={}
        for name,mask in masks.items():
            file=OUTPUT/f'{clip}_{frame:04d}_{name}.png';Image.fromarray(mask).save(file)
            files[name]={'file':file.name,'sha256':digest(file)}
        records.append({'view':'front','clip':clip,'frame':frame,'target':target,'rest_hole_count':len(holes),'files':files})
    write_json(OUTPUT/'captures.json',{'capture_commit':'5abe9b561 (retained at 477e6d24a)',
        'native_manifest_sha256':digest(capture/'frames.json'),'compiled_motion_sha256':manifest['inputs']['compiled_motion.json'],
        'scope':'captured pre-feedback4 GPU body; only updated rigid tucks rendered headlessly; not current mesh/native acceptance',
        'rigid_tucks':RIGID_TUCKS,'frames':records})
    print('RR10 NATIVE SEAM FIXTURES: PASS (%d captured poses; no mesh raster)'%len(records))


if __name__=='__main__':main()
