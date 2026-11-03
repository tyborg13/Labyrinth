"""Read-only ownership receipts for the director's detached native components."""
import argparse
from pathlib import Path
from collections import Counter,defaultdict
import numpy as np
from rr38_case import CASE
from cutout_pipeline.cases import read_json,write_json,digest
from humanoid_cutout.native_frames import load_frame,frame_digest
from rr38_triage import crop


def run(case,native,output):
    manifest=read_json(native/'frames.json')
    pockets=read_json(native/'source_space_pockets.json')
    inventory=defaultdict(list)
    for p in manifest['pieces']:inventory[p['view'],p['clip'],p['frame']].append(p)
    full={(p['view'],p['clip'],p['frame']):p for p in manifest['frames']}
    layouts={v:read_json(case/f'layouts/{v}.json') for v in ('front','rear')}
    size=read_json(case/'cutout.json')['proof_geometry']['canvas_size']
    rows=[]
    for r in pockets:
        if not r['unmatched_components']:continue
        key=r['view'],r['clip'],r['frame'];layout=layouts[key[0]];parts={p['name']:p for p in layout['parts']}
        owner=np.full((size,size),'',object)
        for p in sorted(inventory[key],key=lambda p:parts[p['name']]['z_index']):
            path=native/p['file']
            if frame_digest(path)!=p['sha256']:raise ValueError('Changed native capture: '+str(path))
            mask=np.asarray(load_frame(path))[...,3]>0
            owner[mask]=p['name']
        if frame_digest(native/full[key]['file'])!=full[key]['sha256']:raise ValueError('Changed native composite')
        image=np.asarray(load_frame(native/full[key]['file']).convert('RGBA'))
        for n,c in enumerate(r['unmatched_components']):
            x,y=np.asarray(c['pixels']).T;names=Counter(owner[y,x])
            record=dict(view=key[0],clip=key[1],frame=key[2],**c)
            record['visible_parts']=dict(names)
            record['generated_fill_parts']=[name for name in names if parts[name].get('hidden_material')]
            record['native_frame_sha256']=full[key]['sha256']
            record['crop']=crop(image,c['bbox'],output/f'{key[0]}_{key[1]}_{key[2]:04d}_{n}.png')
            rows.append(record)
    result={'native_manifest_sha256':digest(native/'frames.json'),'source_space_log_sha256':digest(native/'source_space_pockets.json'),
        'components':rows,'part_pixel_totals':{}}
    counts=Counter()
    for r in rows:counts.update(r['visible_parts'])
    result['part_pixel_totals']=dict(counts)
    write_json(output/'fill_sources.json',result)
    print('RR38 NATIVE DETACHED SOURCES: '+str(dict(counts)))
    return result


if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--case',type=Path,default=CASE)
    p.add_argument('--native',type=Path,default=CASE/'proof/native');p.add_argument('--output',type=Path,default=CASE/'proof/logs/feedback3/fill_sources')
    a=p.parse_args();run(a.case,a.native,a.output)
