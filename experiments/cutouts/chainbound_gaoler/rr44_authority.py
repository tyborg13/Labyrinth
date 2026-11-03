"""Exact, immutable director acceptance of r1 backing and flat-region ratchet."""
from collections import defaultdict
from functools import lru_cache
import numpy as np
from rr44_case import STAGED
from cutout_pipeline.cases import read_json,digest

PAINT_SHA256='49c23f88cc7203a2bc431e9edabdb2497ff4cf4d4832de9c5ca5b89b73e341b6'
FLAT_SHA256='69ffeead027bcaf8f3defd9290095d6913d898ea50f3a29be388bd17929fbdc8'
NATIVE_FLAT_SHA256='9e4bbe462255ec5f47d3fc0142745227418b073665b7187ea4a13b03e9d07add'


def authority():
    path=STAGED/'feedback2_backing_acceptance.json'
    if digest(path)!=PAINT_SHA256:raise ValueError('Changed director backing authority')
    result=read_json(path)
    for view,sha in result['underlays'].items():
        if digest(STAGED/f'{view}_body_underlay.png')!=sha:raise ValueError('Changed accepted underlay')
    return result


def accepted(view,name,image):
    result=np.zeros(image.shape[:2],bool)
    points=[];colours=[]
    for row in authority()['regions']:
        # Approval binds coordinate and RGBA, and survives a source-owner
        # correction. The old part name remains provenance, not a colour pass.
        if row['view']!=view:continue
        for texel in row['texels']:
            x,y=texel['uv']
            transferred=((view,row['part'],name)==('front','hidden_leg_far','hidden_pelvis') and [x,y]==[113,127]) or (
                (view,row['part'],name)==('rear','hidden_coat_far','hidden_foot_far') and 158<=x<160 and 224<=y<236)
            if row['part']==name or transferred:
                points.append(texel['uv']);colours.append(texel['rgba'])
    if points:
        coordinates=np.asarray(points);x,y=coordinates.T
        valid=np.all(image[y,x]==np.asarray(colours),axis=-1)&(image[y,x,3]>0)
        result[y[valid],x[valid]]=True
    return result


@lru_cache(maxsize=2)
def flat_inventory(path,sha):
    return read_json(path)


def flat_errors(rows,*,render_mode='cpu'):
    if render_mode not in ('cpu','native'):raise ValueError('Unknown flat raster mode')
    path=STAGED/('feedback2_native_flat_baseline.json' if render_mode=='native' else 'feedback2_flat_baseline.json')
    expected=NATIVE_FLAT_SHA256 if render_mode=='native' else FLAT_SHA256
    if digest(path)!=expected:raise ValueError('Changed director flat baseline')
    baseline=flat_inventory(path,expected);groups=defaultdict(list);current=defaultdict(list)
    key=lambda r:tuple(r[k] for k in ('view','clip','frame','piece'))
    for row in baseline['regions']:groups[key(row)].append(row)
    for row in rows:current[key(row)].append(row)
    errors=[]
    for identity,regions in current.items():
        previous=groups[identity];links={i:set() for i in range(len(regions))}
        for i,row in enumerate(regions):
            a=np.asarray(row['bbox'])
            for j,old in enumerate(previous):
                b=np.asarray(old['bbox'])
                if np.all(np.minimum(a[2:],b[2:])>np.maximum(a[:2],b[:2])):links[i].add(j)
        # An occluding chain can split one accepted patch, or stop splitting
        # two patches. Compare connected correspondence groups so old pixels
        # are consumed once. A 10px + 6px patch merging into 17px grew 1px,
        # not 7px. New spatial regions still have no baseline edge and fail.
        remaining=set(links)
        while remaining:
            seed=min(remaining);new={seed};old=set();pending={seed}
            while pending:
                index=pending.pop();old |= links[index]
                neighbours={i for i in remaining if links[i]&old}-new
                pending |= neighbours;new |= neighbours
            remaining -= new
            if not old:
                errors.extend(dict(regions[i],reason='new flat region') for i in sorted(new));continue
            current_pixels=sum(regions[i]['pixels'] for i in new);previous_pixels=sum(previous[j]['pixels'] for j in old)
            if current_pixels>previous_pixels+baseline['maximum_growth_px']:
                errors.extend(dict(regions[i],reason='flat region grew more than 2px') for i in sorted(new))
    return errors
