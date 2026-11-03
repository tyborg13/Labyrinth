"""Recover rear arm ink from the director's erased-arm alpha and rest contacts.

The raw composite includes unchanged edge ink outside the traced inner sleeve.
Body ownership there is impossible when the supplied body underlay is clear.
Only exact source RGBA is re-owned; no alpha, colour or pose is synthesized.
"""
from collections import Counter
import numpy as np

ARM_OWNERS=('arm_far','hand_far','chain','head')
BODY_OWNERS=('torso','pelvis','coat_far','coat_near','tabard')


def apply(owner,paint,region,underlay):
    pending={(int(y),int(x)) for y,x in np.argwhere(region & (paint[...,3]>0) & (underlay[...,3]==0) & np.isin(owner,BODY_OWNERS))}
    result=[]
    while pending:
        step=[]
        for y,x in sorted(pending):
            contacts=Counter(owner[max(0,y-1):min(255,y+2),max(0,x-1):min(255,x+2)].ravel())
            choices={n:c for n,c in contacts.items() if n in ARM_OWNERS}
            if choices:
                target=min(choices,key=lambda n:(-choices[n],n))
                step.append((y,x,target,choices))
        if not step:break
        for y,x,target,contacts in step:
            result.append(dict(uv=[x,y],previous=owner[y,x],owner=target,contacts=contacts,rgba=paint[y,x].tolist()))
            owner[y,x]=target;pending.remove((y,x))
    return dict(rule='director erased-arm alpha; nearest simultaneous eight-connected approved part contact; lexical count ties recorded',
                texels=result,unresolved=[dict(uv=[x,y],field='TODO_DESIGN_rear_arm_edge_owner') for y,x in sorted(pending)])
