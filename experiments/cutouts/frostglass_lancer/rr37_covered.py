"""The director's empty rear pieces never acquire visible or hidden paint.

Cloak underlaps and actual seam checks prove the visible coverage. Do not invent
hypothetical hidden painting silhouettes or a second field for empty anatomy.
"""
EMPTY_LOGICAL_PIECES = ('hand_near','pelvis','tabard')  # Belt is fused into pelvis.


def empty_pixels(view, layers):
    if view!='rear': return 0
    return sum(int((image[...,3]>0).sum()) for part,image,_ in layers
               if part['logical_part'] in EMPTY_LOGICAL_PIECES)
