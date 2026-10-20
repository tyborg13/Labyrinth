"""Read-only producer diagnostics against the director's existing GPU pixels.

This neither edits the capture receipt nor certifies its stale input bindings.
The unchanged native gate remains authoritative; a fresh capture is required.
"""
import argparse
from collections import defaultdict
import numpy as np
from PIL import Image
from rr29_build import CASE,read_json,write_json,digest
from humanoid_cutout.gates import bindings
from humanoid_cutout.native_frames import load_frame
from maquette_motion.pixels import changed

TRANSFORM_TOLERANCE=0.0001  # Existing serialized Bone2D proof precision.


def diagnose(capture):
    receipt=capture/'frames.json';before=digest(receipt)
    native=read_json(receipt);samples=read_json(CASE/'proof/samples.json')
    poses={(r['view'],r['clip'],r['frame']):r for r in samples['samples'] if r['kind']=='presented'}
    groups=defaultdict(list);maximum=0.0;errors=[]
    for row in native['pieces']:
        key=row['view'],row['clip'],row['frame'];groups[key].append(row)
        transform=poses[key]['parts'][row['name']]['transform']
        difference=max(abs(a-b) for a,b in zip(transform,row['transform']))
        maximum=max(maximum,difference)
        if difference>TRANSFORM_TOLERANCE:errors.append([*key,row['name'],'transform differs',difference])
    mismatches=[]
    for row in native['frames']:
        key=row['view'],row['clip'],row['frame']
        order={name:i for i,name in enumerate(poses[key]['part_draw_order'])}
        layers=[(r,load_frame(capture/r['file']).convert('RGBA')) for r in groups[key]]
        actual=np.asarray(load_frame(capture/row['file']).convert('RGBA'))
        old=Image.new('RGBA',layers[0][1].size);corrected=old.copy()
        for part,image in sorted(layers,key=lambda pair:pair[0]['z_index']):old.alpha_composite(image)
        for part,image in sorted(layers,key=lambda pair:(pair[0]['z_index'],order[pair[0]['name']])):corrected.alpha_composite(image)
        prior=int(changed(np.asarray(old),actual).sum())
        current=int(changed(np.asarray(corrected),actual).sum())
        if prior:mismatches.append({'view':key[0],'clip':key[1],'frame':key[2],
            'old_difference_px':prior,'scene_order_difference_px':current})
        if current:errors.append([*key,'scene-tree composition differs',current])
    if len(native['frames'])!=len(poses):errors.append('Incomplete native frame progression')
    if digest(receipt)!=before:errors.append('Native receipt changed during diagnostics')
    bound=bindings(CASE)
    report={'ok':not errors,'errors':errors,'native_receipt_sha256':before,'native_capture_modified':False,
        'frames':len(native['frames']),'pieces':len(native['pieces']),'maximum_transform_error':maximum,
        'transform_tolerance':TRANSFORM_TOLERANCE,'old_layout_order_mismatches':mismatches,
        'binding_differences':sorted(k for k in native['inputs'].keys()|bound.keys() if native['inputs'].get(k)!=bound.get(k)),
        'native_gate_waived':False,'certifies_native_capture':False}
    write_json(CASE/'proof/feedback2_native_diagnostics.json',report)
    print(f'RR29 SAMPLE/NATIVE TRANSFORMS: {"PASS" if maximum<=TRANSFORM_TOLERANCE else "FAIL"} ({len(native["pieces"])} pieces; {len(poses)} frames; maximum error {maximum})',flush=True)
    print(f'RR29 NATIVE TIE ORDER: {"PASS" if not errors else "FAIL"} ({len(native["frames"])} existing frames; {len(mismatches)} old-order mismatches diagnosed)',flush=True)
    return report


if __name__=='__main__':
    from pathlib import Path
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--capture',type=Path,default=CASE/'proof/native')
    args=parser.parse_args()
    raise SystemExit(int(not diagnose(args.capture)['ok']))
