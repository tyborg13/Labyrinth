"""One director-authorized row extension pass on native-flagged own surfaces."""
import numpy as np
from rr38_case import CASE
from rr38_surfaces import interior
from cutout_pipeline.cases import read_json, write_json


def apply(view, visible, hidden, paint, definition):
    config=read_json(CASE.parent/'rr38_feedback2_continuations.json')
    report=[]
    for name in config['row_fills'].get(view,[]):
        seed=interior(visible[name],definition)
        target=(hidden[name][...,3]>0)&(paint[...,3]>0)
        copied,unavailable=0,0
        for y in np.flatnonzero(target.any(axis=1)):
            xs=np.flatnonzero(target[y]);donors=np.flatnonzero(seed[y,:,3])
            if not len(donors):unavailable+=len(xs);continue
            selected=donors[np.abs(xs[:,None]-donors[None,:]).argmin(axis=1)]
            hidden[name][y,xs]=seed[y,selected]
            copied+=len(xs)
        report.append({'piece':name,'copied_own_row_pixels':copied,
            'no_same_row_interior_pixels':unavailable,
            'unavailable_rows':[int(y) for y in np.flatnonzero(target.any(axis=1)&~(seed[...,3]>0).any(axis=1))],
            'rule':'same-row nearest own interior, minimum2px; unavailable rows retain original own-piece fill and require director judgment'})
    write_json(CASE/f'proof/feedback2_{view}_row_fills.json',{'view':view,'surfaces':report})
