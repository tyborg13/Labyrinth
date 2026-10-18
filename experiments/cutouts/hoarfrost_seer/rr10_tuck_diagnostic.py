"""Apply current rigid tucks to every retained director-native body pose.

Read-only historical-body diagnostic, not fresh mesh/native acceptance. No
mesh is skinned, rasterized or rebound. Current cuff/robe pixels still require
the director's new native capture.
"""
import sys
from pathlib import Path

import numpy as np
from PIL import Image

PROJECT=Path(__file__).resolve().parents[3]
sys.path.insert(0,str(PROJECT/'tools'))
from cutout_pipeline.cases import read_json,write_json,digest
from humanoid_cutout.seam_proof import seam_holes
from humanoid_cutout.silhouette_gates import posed_owners
from maquette_motion.pixels import PROOF_DEFAULTS
from rr10_seam_fixtures import CASE,RIGID_TUCKS


def main():
    capture=CASE/'proof/native'
    manifest=read_json(capture/'frames.json')
    if digest(CASE/'compiled_motion.json')!=manifest['inputs']['compiled_motion.json']:
        raise ValueError('Historical body motion differs from current motion')
    layout=read_json(CASE/'layouts/front.json')
    samples=read_json(CASE/'proof/samples.json')
    poses={(r['view'],r['clip'],r['frame']):r for r in samples['samples'] if r['kind']=='presented'}
    grouped={field:{} for field in ('pieces','joint_seams','rest_holes')}
    for field,frames in grouped.items():
        for row in manifest[field]:frames.setdefault((row['view'],row['clip'],row['frame']),[]).append(row)
    failures=[]
    for key,pose in poses.items():
        rows=grouped['pieces'][key]
        layers=[(r,np.asarray(Image.open(capture/r['file']).convert('RGBA')),None) for r in rows if r['name'] not in RIGID_TUCKS]
        owners=posed_owners(layers,layout['parts'],pose['bones'],PROOF_DEFAULTS['source_offset'])
        seam=np.logical_or.reduce([np.asarray(Image.open(capture/r['file']).convert('RGBA'))[...,3]>0 for r in grouped['joint_seams'][key]])
        references=np.zeros(owners.shape,dtype=np.uint8)
        for index,row in enumerate(grouped['rest_holes'][key]):
            references[np.asarray(Image.open(capture/row['file']).convert('RGBA'))[...,3]>0] |= 1<<index
        found=seam_holes(CASE,layout,pose,{'owners':owners,'seam':seam,'rest_holes':references},RIGID_TUCKS)
        if found:failures.append({'view':key[0],'clip':key[1],'frame':key[2],'hole_sizes':found})
    result={'ok':not failures,'fresh_capture':False,'native_pixels':False,'accepted':False,
        'scope':'historical captured GPU body with current rigid tucks only; not current mesh/native acceptance',
        'native_manifest_sha256':digest(capture/'frames.json'),'poses':len(poses),'failures':failures}
    write_json(CASE/'proof/feedback4_rigid_tuck_diagnostic.json',result)
    print('RR10 HISTORICAL-BODY TUCK DIAGNOSTIC: %s (%d presented poses; %d flagged; current meshes not rendered)'%(
        'PASS' if not failures else 'FAIL',len(poses),len(failures)))
    return int(bool(failures))


if __name__=='__main__':raise SystemExit(main())
