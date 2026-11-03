"""Both-view exact-paint certificates and the known rear strip diagnostic."""
import numpy as np
from PIL import Image
from rr44_case import STAGED, CASE
from rr44_partition import FOOTPRINTS
from rr42_exposure import PaintedExposure


def supplied(view, case=CASE):
    paint=np.asarray(Image.open(STAGED/f'{view}_body_underlay.png').convert('RGBA')).copy()
    paint[paint[...,3]==0]=0
    footprints={n:np.asarray(Image.open(case/f'uncovered/{view}_{n}_footprint.png').convert('L'))>0 for n in FOOTPRINTS}
    certificates={}
    for path in (case/'uncovered').glob(view+'_hidden_*_painted.png'):
        name=path.stem[len(view)+1:-len('_painted')]
        certificates[name]=np.asarray(Image.open(path).convert('L'))>0
    return paint,footprints,certificates


def gate(model, *, packed_footprints=True):
    result=PaintedExposure(model,supplied=supplied(model.layout['facing'],case=model.case),footprint_parts=FOOTPRINTS,packed_footprints=packed_footprints)
    from rr44_continuations import labels,required
    view=model.layout['facing']
    result.label_policy=lambda pose,part,image:labels(view,part['name'],pose['clip'],image,part['offset'])
    result.required_policy=lambda pose,part:required(view,part['name'],pose['clip'])
    from humanoid_cutout.painted_caps import masks as cap_masks
    parts={p['name']:p for p in model.layout['parts']}
    for name,mask in cap_masks(model.case,model.layout).items():
        x,y,x1,y1=parts[name]['bbox'];result.labels[name] |= mask[y:y1,x:x1]
    # Feedback 2 accepts the exact supplied flank, and only the frozen r1
    # values at the catalogued coordinates. A recolour cannot borrow authority.
    from rr44_authority import accepted
    from maquette_motion.features import source_pixels
    for name,part in parts.items():
        x,y,x1,y1=part['bbox']
        result.labels[name] |= accepted(model.layout['facing'],name,source_pixels(model.case,part))[y:y1,x:x1]
    return result


def rear_strip_source():
    # Director's known lighter striped panel; this is a diagnostic region,
    # never a paint mask or an approval exemption.
    mask=np.zeros((255,255),bool);mask[63:121,121:143]=True
    return mask
