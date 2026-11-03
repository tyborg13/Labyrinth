"""On-demand immutable-input, additive compiler and earlier-rig byte checks."""
import argparse
from copy import deepcopy
import hashlib
import json
from pathlib import Path
from rr52_build import ROOT,CASE,ASSETS
from cutout_pipeline.cases import read_json,write_json,digest
from humanoid_cutout.held_follow import validate
import numpy as np
from PIL import Image
from maquette_motion.silhouette import holes


def verify(baseline=None):
    errors=[];checks=0;staged=ROOT/'spec/peer_benchmark/staged/rr-52';provenance=read_json(staged/'provenance.json')
    for name in ('motion_tracks.json','front_body_underlay.png','rear_body_underlay.png'):
        checks+=1
        if digest(staged/name)!=provenance['files'][name]:errors.append('Protected input changed: '+name)
    checks+=1
    if (CASE/'director_motion.json').read_bytes()!=(staged/'motion_tracks.json').read_bytes():errors.append('Protected case director copy differs')
    # walk-02 explicitly overrides only the production move clock/gait. The
    # original director source and every other authored field remain protected.
    from rr52_walk import authored
    expected,_=authored();checks+=1
    if read_json(ASSETS/'humanoid_v2/director_motion.json')!=expected:errors.append('Production director differs from the explicit walk-02 override')
    data=read_json(CASE/'compiled_motion.json');layout=read_json(CASE/'layouts/front.json');definition=deepcopy(data['clips']['move'])
    before=deepcopy(definition);validate(definition,layout,'move');checks+=1
    if definition!=before:errors.append('Held-follow validator mutated input')
    for bad in (-1,0,36,float('inf'),True,'25'):
        invalid=deepcopy(definition);invalid['held_follow']['limit_deg']=bad;checks+=1
        try:validate(invalid,layout,'move');errors.append('Invalid held-follow limit accepted: '+str(bad))
        except ValueError:pass
    # Absent optional limit retains every earlier compiler operation/value.
    legacy=deepcopy(definition);legacy['held_follow'].pop('limit_deg');before=deepcopy(legacy);validate(legacy,layout,'move');checks+=1
    if legacy!=before:errors.append('Legacy held-follow input mutated')
    for view in ('front','rear'):
        layout=read_json(CASE/f'layouts/{view}.json')
        rest=np.asarray(Image.open(CASE/layout['rest_source']).convert('RGBA'))[...,3]>0
        expected=holes(rest);references=layout['proof_rest_holes'];checks+=1
        if len(references)!=len(expected):errors.append(view+': incomplete immutable rest-air references')
        for record in references:
            mask=np.asarray(Image.open(CASE/record['file']).convert('RGBA'))[...,3]>0;checks+=1
            match=next((i for i,m in enumerate(expected) if np.array_equal(m,mask)),None)
            if match is None or (mask&rest).any():errors.append(view+': rest-air reference differs from exact enclosed source air')
            else:expected.pop(match)
    earlier=0
    if baseline:
        for name,sha in read_json(baseline).items():
            earlier+=1
            if digest(ROOT/name)!=sha:errors.append('Earlier rig byte differs: '+name)
    checks+=earlier
    result={'ok':not errors,'checks':checks,'earlier_files':earlier,'errors':errors,'native_pixels':False}
    write_json(CASE/'proof/immutable_checks.json',result)
    print(f'RR52 IMMUTABLE/COMPILER CHECKS: {"PASS" if not errors else "FAIL"} ({checks} checks; {earlier} earlier files byte-identical)')
    for e in errors:print(e)
    return not errors

if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('--baseline',type=Path);a=p.parse_args();raise SystemExit(int(not verify(a.baseline)))
