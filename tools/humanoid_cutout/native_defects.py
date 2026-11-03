"""Case-independent isolated-layer diagnostics for rr-36's five defect classes.

Transported ownership/tuck masks and exact own-interior palettes are independent
of presented paint. Acceptance still requires the director's native 2x review.
"""
import numpy as np
from maquette_motion.silhouette import components

DESCRIPTIONS = {'D1':'floor shards from gait continuations',
 'D2':'cloth fringes or foreign texels in hidden coverage',
 'D3':'outline bands revealed under a hem',
 'D4':'seam lines across one cloth surface', 'D5':'fraying hems'}


def packed(image):
    p=np.asarray(image,dtype=np.uint32)
    return (p[...,0]<<24)|(p[...,1]<<16)|(p[...,2]<<8)|p[...,3]


def measure(layers, contract):
    metrics={name:0 for name in DESCRIPTIONS}
    occupied=np.zeros(layers[0][1].shape[:2],dtype=bool)
    for row,image,checks in sorted(layers,key=lambda item:item[0]['z_index'],reverse=True):
        alpha=image[...,3]>0
        allowed=(checks[...,0]>0)&(checks[...,3]>0)
        continuation=(checks[...,1]>0)&(checks[...,3]>0)
        exposed=alpha&~occupied
        piece=row.get('logical_part',row['name'].removeprefix('hidden_'))
        if piece in contract['floor_pieces']: metrics['D1']+=int((alpha&~allowed).sum())
        if row.get('hidden_material'):
            own=contract['interior_palettes'].get(piece,[])
            metrics['D2']+=int((alpha&~np.isin(packed(image),own)).sum())
        metrics['D3']+=int((exposed&continuation&(checks[...,2]>0)).sum())
        if piece in contract['cloth_pieces']:
            metrics['D4']+=int((allowed&~alpha).sum())
            metrics['D5']+=int((alpha&~allowed).sum())
            metrics['D5']+=max(0,len(components(alpha,8)[1])-len(components(allowed,8)[1]))
        occupied|=alpha
    return metrics
