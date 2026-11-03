"""Rejected removal experiment for the UV-traced native reel fill speck.

Keep the crop, skin lattice, required domains and immutable proof masks.
This is never applied to production: deleting it violates the required arm
tuck. The regression keeps that independent failure visible. No replacement
colour is invented.
"""
from pathlib import Path
import numpy as np
from PIL import Image
from cutout_pipeline.cases import read_json,digest
from rr38_case import CASE

CONFIG=CASE.parent/'rr38_feedback3_pruning.json'


def apply(case,layout):
    case=Path(case).resolve()
    case.relative_to((CASE/'proof').resolve())  # Rejected experiment: proof copies only.
    config=read_json(CONFIG)
    parts={p['name']:p for p in layout['parts']}
    removed=[]
    for name,points in config['source_pixels'].get(layout['facing'],{}).items():
        part=parts[name]
        if not part.get('hidden_material'):raise ValueError('Only generated fill pixels may be removed')
        path=case/part['file'];image=np.asarray(Image.open(path).convert('RGBA')).copy()
        ox,oy=part['offset']
        for x,y in points:
            if image[y-oy,x-ox,3]:
                image[y-oy,x-ox]=0;removed.append([name,x,y])
        Image.fromarray(image).save(path)
        layout['proof_layers'][name]['source_sha256']=digest(path)
    return removed
