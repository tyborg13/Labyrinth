#!/usr/bin/env python3
"""Native isolated group gate; uses the binding humanoid pixel comparison."""
import argparse
import json
import sys
from pathlib import Path
import numpy as np
from PIL import Image
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'tools'))
from humanoid_cutout.gates import idle_pixel_errors,idle_group_offset
from cutout_pipeline.cases import read_json,digest
CASE=ROOT/'experiments/cutouts/emaciated_man/emac02'

def check(manifest):
    data=read_json(manifest)
    if data['verify_only']:raise ValueError('Headless geometry is not native pixel proof')
    if digest(CASE/'cutout.json')!=data['case_sha256']:raise ValueError('Stale native rigid case')
    layout=read_json(CASE/read_json(CASE/'cutout.json')['layouts']['front'])
    counts={g:0 for g in layout['idle_groups']};basis_errors=0;offset_errors=0
    for row in data['rows']:
        group=row['group'];rest=np.array(Image.open(manifest.parent/(group+'_rest.png')).convert('RGBA'))
        frame=np.array(Image.open(manifest.parent/row['file']).convert('RGBA'))
        offset=idle_group_offset(layout,row['bones'],group,{'idle_groups':layout['idle_groups']})
        if not np.allclose(offset,np.rint(offset),atol=.0001):offset_errors+=1
        for bone in layout['idle_groups'][group]['bones']:
            matrix=row['bones'][bone]['global']
            if not np.allclose(matrix[:4],[1,0,0,1],atol=.0001):basis_errors+=1
            if not np.allclose(np.array(matrix[4:])-layout['joints'][bone]['position'],offset,atol=.0001):offset_errors+=1
        counts[group]+=idle_pixel_errors(rest,frame,offset)
    assert len(data['rows'])==70,'Missing presented frames'
    result={'ok':not any(counts.values()) and basis_errors==offset_errors==0,'group_pixel_mismatches':counts,'basis_errors':basis_errors,'group_offset_errors':offset_errors,'samples':len(data['rows'])}
    (manifest.parent/'rigid_gate.json').write_text(json.dumps(result,indent=2)+'\n')
    print('EMAC RIGID PIXELS: '+('PASS' if result['ok'] else 'FAIL')+'; '+json.dumps(result,sort_keys=True))
    return result['ok']
if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    source=parser.add_mutually_exclusive_group(required=True)
    source.add_argument('--manifest',type=Path);source.add_argument('--runner-manifest',type=Path)
    args=parser.parse_args();manifest=args.manifest
    if args.runner_manifest:
        runner=read_json(args.runner_manifest)
        if not runner.get('ok'):raise ValueError('Native runner failed')
        paths=[Path(p['path']).parent/'manifest.json' for p in runner['images'] if Path(p['path']).name=='upper_rest.png']
        if len(paths)!=1:raise ValueError('Native runner must contain one isolated upper rest surface')
        manifest=paths[0]
    raise SystemExit(0 if check(manifest) else 1)
