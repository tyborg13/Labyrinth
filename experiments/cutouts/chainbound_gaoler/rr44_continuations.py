"""Exact accepted r1 effective paint, scoped to its original part, UV and clip."""
from functools import lru_cache
import numpy as np
from rr44_case import STAGED
from cutout_pipeline.cases import read_json,digest

SHA256='880a1a089604305b5b4f41f3a9e4b17a281864253aafd8bf3ab74c51c6b57c79'


@lru_cache(maxsize=1)
def authority():
    path=STAGED/'feedback2_continuation_acceptance.json'
    if digest(path)!=SHA256:raise ValueError('Changed accepted effective r1 paint')
    result=read_json(path)
    from rr44_authority import PAINT_SHA256,authority as static_authority
    if result['static_authority_sha256']!=PAINT_SHA256:raise ValueError('Effective paint has a different director authority')
    allowed={(r['view'],r['part'],tuple(p['uv'])) for r in static_authority()['regions'] for p in r['texels']}
    if any((r['view'],r['part'],tuple(p['uv'])) not in allowed for r in result['regions'] for p in r['texels']):raise ValueError('Effective authority adds an unapproved source coordinate')
    return result


def records(view,name,clip=None):
    return [r for r in authority()['regions'] if r['view']==view and r['part']==name and (clip is None or r['clip']==clip)]


def labels(view,name,clip,image,offset):
    result=np.zeros(image.shape[:2],bool);x0,y0=offset
    for row in records(view,name,clip):
        for texel in row['texels']:
            x,y=texel['uv'];u,v=x-x0,y-y0
            if 0<=v<image.shape[0] and 0<=u<image.shape[1] and np.array_equal(image[v,u],texel['rgba']):result[v,u]=True
    return result


@lru_cache(maxsize=64)
def required(view,name,clip):
    result=np.zeros((255,255),bool)
    for row in records(view,name,clip):
        for texel in row['texels']:x,y=texel['uv'];result[y,x]=True
    return result
