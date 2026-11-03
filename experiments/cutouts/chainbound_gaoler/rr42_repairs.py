"""Inventory exposed source UVs; adopt only exact supplied paint or clear."""
from collections import defaultdict
import argparse
import numpy as np
from PIL import Image
from rr42_underlay import CASE,PROJECT,inputs,repairs
from rr42_density import PROOF_CASE
from rr42_exposure import PaintedExposure
from cutout_pipeline.cases import read_json,write_json,digest
from humanoid_cutout.cpu_pose import CpuPose
from humanoid_cutout.canvas import for_case
from humanoid_cutout.gait_continuations import texture

RECEIPT=CASE.parent/'rr42_feedback1_repairs.json'


def collect(case,clips=None,frames=None):
    paint,_=inputs();layout=read_json(case/'layouts/front.json')
    model=CpuPose(case,layout,native_skin=True,triangle_batch_size=128);gate=PaintedExposure(model)
    parts={p['name']:p for p in layout['parts']}
    poses=[r for r in read_json(case/'proof/logs/samples.json')['samples'] if r['view']=='front' and r['kind']=='presented'
           and (not clips or r['clip'] in clips.split(',')) and (frames is None or r['frame'] in frames)]
    existing={(r['part'],*r['uv']):r for r in repairs()}
    found={};last=None
    with for_case(case):
        for pose in poses:
            if last!=pose['clip']:last=pose['clip'];print('RR42 REPAIR INVENTORY:',last,flush=True)
            gate.measure(pose,collect_texels=True)
            for name,x,y in gate.last_texels:
                if (name,x,y) in existing:raise ValueError('Previously repaired texel still fails exact provenance')
                key=(name,x,y)
                if key not in found:
                    part=parts[name];source=texture(case,layout,part,gait=pose['clip']=='move',clip=pose['clip'])
                    ox,oy=part['offset']
                    found[key]={'part':name,'uv':[x,y],'before_rgba':source[y-oy,x-ox].tolist(),
                                'director_rgba':paint[y,x].tolist(),'decision':'paint' if paint[y,x,3] else 'clear','frames':[]}
                witness=[pose['clip'],pose['frame']]
                if witness not in found[key]['frames']:found[key]['frames'].append(witness)
    merged={**existing,**found}
    result={'schema':1,'authority':'director feedback 1: every exposed hidden source texel, including outside footprints',
            'director_sha256':digest(PROJECT/'spec/peer_benchmark/staged/rr-42/front_body_underlay.png'),
            'texels':[merged[key] for key in sorted(merged)]}
    write_json(RECEIPT,result)
    print('RR42 REPAIR INVENTORY: %d new texels; %d total'%(len(found),len(merged)))
    return result


def merge_rows(frames):
    existing={(r['part'],*r['uv']):r for r in repairs()};found={}
    for pose in frames:
        for row in pose.get('repair_texels',[]):
            key=(row['part'],*row['uv'])
            if key in existing:
                record=existing[key]
            else:
                record=found.setdefault(key,dict(row,frames=[]))
            witness=[pose['clip'],pose['frame']]
            if witness not in record['frames']:record['frames'].append(witness)
    result={'schema':1,'authority':'director feedback 1: exact RGBA or clear at every exposed hidden source UV',
            'director_sha256':digest(PROJECT/'spec/peer_benchmark/staged/rr-42/front_body_underlay.png'),
            'texels':[r for _,r in sorted({**existing,**found}.items())]}
    write_json(RECEIPT,result)
    print('RR42 REPAIR RECEIPT: %d new texels; %d total'%(len(found),len(result['texels'])),flush=True)
    return result


if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--case',type=__import__('pathlib').Path,default=PROOF_CASE)
    p.add_argument('--clips');p.add_argument('--frames',help='Comma-separated focused frames')
    a=p.parse_args();collect(a.case,a.clips,set(map(int,a.frames.split(','))) if a.frames else None)
