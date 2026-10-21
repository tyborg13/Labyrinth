"""Cut the actual painted belt, flap and complete iron bracer contours.

The supplied painting takes precedence over the projected maquette silhouette:
its visible belt is above that projection, and its iron has warm rim shading.
Traces select existing RGBA; body registration, alpha and colours never change.
"""
from copy import deepcopy
from pathlib import Path
import numpy as np
from PIL import Image, ImageDraw
from rr22_case import PIECES as NATIVE_PIECES
from cutout_pipeline.cases import read_json, write_json, digest
from rr22_surfaces import nearest_labels
from maquette_motion.silhouette import components

TRACES = Path(__file__).with_name('rr30_ownership_traces.json')


def mask_for(size, points):
    image = Image.new('L', size)
    ImageDraw.Draw(image).polygon([tuple(p) for p in points], fill=255)
    return np.asarray(image) > 0


def foot_sole_bridge(owners, names):
    """Keep the approved heel/sole/toe together on the planted rigid foot.

    The native labels assigned the sole between the two painted foot islands
    to the shin. Select only shin paint inside the foot islands' convex hull;
    source RGBA and the assembled silhouette remain exact.
    """
    foot,shin=[names.index(n) for n in ('foot_near','shin_near')]
    yy,xx=np.nonzero(owners==foot)
    points=sorted(set(zip(xx.tolist(),yy.tolist())))
    def cross(a,b,c):return (b[0]-a[0])*(c[1]-a[1])-(b[1]-a[1])*(c[0]-a[0])
    lower,upper=[],[]
    for sequence,chain in ((points,lower),(points[::-1],upper)):
        for point in sequence:
            while len(chain)>=2 and cross(chain[-2],chain[-1],point)<=0:chain.pop()
            chain.append(point)
    hull=lower[:-1]+upper[:-1]
    selected=mask_for((owners.shape[1],owners.shape[0]),hull)&(owners==shin)
    owners[selected]=foot
    return dict(pixels=int(selected.sum()),hull=hull,
                basis='Approved painted heel/toe hull; only intervening shin-owned sole paint transfers')


def partition(case, base, old, paint, owners, names, seeds, view):
    traces = read_json(TRACES)[view]
    names = names.copy()
    result = owners.copy()
    report = dict(trace_source=TRACES.name, trace_sha256=digest(TRACES),
                  policy='approved painted equipment boundaries; source RGBA unchanged')
    occupied = paint[..., 3] > 0
    # Flap first, then the belt over its attachment; the bracers never own pot paint.
    masks = {name: mask_for((paint.shape[1],paint.shape[0]),traces[name]) & occupied
             for name in ('flap','belt','bracer_near','bracer_far')}
    # Retain the painting's ragged hem pixels at the traced edge boxes.
    for left,top,right,bottom in traces.get('flap_extra_boxes', []):
        masks['flap'][top:bottom,left:right] |= occupied[top:bottom,left:right]
    masks['flap'] &= ~masks['belt']
    for name, selected in masks.items():
        selected &= owners != names.index('mortar')
        if name.startswith('bracer_'):
            # The trace crosses the arm's dark edge in two places. Disconnected
            # source-edge slivers retain their original arm owner, never alpha
            # deletion or a detached-component exemption.
            labels,groups=components(selected)
            selected = labels==groups[0][0]
        names.append(name)
        result[selected] = names.index(name)
        origin = 'fore_' + name.split('_',1)[1] if name.startswith('bracer_') else 'apron'
        part = deepcopy(next(p for p in old['parts'] if p['logical_part']==origin))
        part.update(name=name,logical_part=name)
        old['parts'].append(part)
        # Shell continuation is only its normal own-material tuck. The bare arm
        # retains the original forearm solo and gets skin support beneath iron.
        solo = np.zeros_like(paint)
        solo[selected] = paint[selected]
        Image.fromarray(solo).save(base / ('registered/' + view + '_solo_' + name + '.png'))
        seeds[name] = np.zeros_like(paint)
        report[name] = dict(pixels=int(selected.sum()), trace=traces[name])
    # The maquette's lower apron label must not carry hip/torso paint with the
    # hinged flap. Reassign only its unselected residue by rr22's source-nearest
    # body ownership rule, retaining every original painted pixel.
    residue = (result == names.index('apron')) & occupied
    candidates = [i for i,n in enumerate(names) if n not in ('apron','mortar','belt','flap','bracer_near','bracer_far')]
    replacement = nearest_labels(result, residue, candidates)
    result[residue] = replacement[residue]
    report['native_apron_residue_body_pixels'] = int(residue.sum())
    # The former fused limb could hide tiny ownership islands on opposite
    # sides of a joint. Each new rigid segment must carry its own connected
    # surface. Reuse the existing source-neighbour reassignment, retaining all
    # original RGBA and the protected crucible.
    from rr30_case import PIECES
    from rr22_surfaces import absorb_specks
    result, transfers = absorb_specks(result, names, owners == names.index('mortar'), PIECES)
    report['rigid_segment_speck_transfers'] = transfers
    if view=='rear':report['rigid_foot_sole_bridge']=foot_sole_bridge(result,names)
    write_json(case / ('ownership/' + view + '_mq11_partition.json'),report)
    return result,names,seeds,report
