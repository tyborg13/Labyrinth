"""Rebind unchanged tuck requirements only through director-owned paint/clear."""
from collections import defaultdict
import copy
import numpy as np
from PIL import Image
from rr42_underlay import CASE,BASE_CASE,inputs,domains,authority_for
from cutout_pipeline.cases import read_json,write_json
from maquette_motion.features import source_pixels


def plan():
    paint,_=inputs();receivers=domains();build=read_json(BASE_CASE/'proof/build.json')
    result={};receipt=[]
    for view in ('front','rear'):
        layout=read_json(CASE/f'layouts/{view}.json')
        original=read_json(BASE_CASE/f'layouts/{view}.json')
        images={p['name']:source_pixels(CASE,p) for p in layout['parts']}
        approved={p['name']:source_pixels(BASE_CASE,p) for p in original['parts']}
        tucks=copy.deepcopy(build['views'][view]['tucks'])
        for tuck in tucks:
            mask=np.asarray(Image.open(BASE_CASE/tuck['required_mask']))>0
            supplied=np.logical_or.reduce([images[p['name']][...,3]>0 for p in layout['parts']
                                           if p['logical_part']==tuck['piece']])
            bindings=defaultdict(list)
            for y,x in np.argwhere(mask&~supplied):
                if view!='front' or not authority_for(tuck['piece'])[y,x]:
                    raise ValueError('Tuck loss outside director authority')
                if paint[y,x,3]:
                    receiver=next(n for n,m in receivers.items() if m[y,x])
                    owner='hidden_'+receiver;reason='director underlay partition re-owned receiving paint'
                    if not np.array_equal(images[owner][y,x],paint[y,x]):raise ValueError('Missing re-owned director paint')
                else:
                    # The retired procedural tuck is director-owned clear.
                    # Bind its rest requirement to the original visible paint
                    # that still owns that source coordinate; never add fill.
                    candidates=[p for p in layout['parts'] if not p.get('hidden_material')
                                and images[p['name']][y,x,3]
                                and np.array_equal(images[p['name']][y,x],approved[p['name']][y,x])]
                    if not candidates:raise ValueError('Director clear loses required original paint')
                    owner=max(candidates,key=lambda p:p['z_index'])['name']
                    reason='director cleared procedural backing; original visible ownership retained'
                uv=[int(x),int(y)];bindings[owner].append(uv)
                receipt.append(dict(view=view,tuck=tuck['piece'],uv=uv,owner=owner,reason=reason,
                                    rgba=images[owner][y,x].tolist(),director_rgba=paint[y,x].tolist()))
            if bindings:tuck['owner_bindings']=[dict(part=n,texels=uvs) for n,uvs in sorted(bindings.items())]
        result[view]=tucks
    return result,receipt


def apply(case=CASE):
    expected,receipt=plan();path=case/'proof/build.json';build=read_json(path)
    for view in expected:build['views'][view]['tucks']=expected[view]
    build['tucks']=copy.deepcopy(expected['front'])
    write_json(path,build)
    write_json(CASE/'proof/feedback2_tucks.json',dict(texels=receipt,rule='unchanged required masks; exact new owners; no painted texel removed'))
    print('RR42 TUCK OWNERSHIP: PASS (%d required texels rebound; no mask deletion)'%len(receipt))


def errors(case):
    if not (case/'proof/build.json').exists():return ['missing director tuck ownership receipt']
    expected,_=plan();actual=read_json(case/'proof/build.json')
    return [view+': tuck ownership differs from director decisions' for view in expected
            if actual['views'][view]['tucks']!=expected[view]]


if __name__=='__main__':apply()
