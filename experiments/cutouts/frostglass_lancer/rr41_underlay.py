"""Exact director lining behind the front legs; rr-39 keeps priority.

Ownership follows the existing backing layers' draw order and storage domains.
Both old cloaks covered the same leg pixels; hidden_cape_far was on top. Its
existing registered canvas also contains the 28 painted texels without old fill.
No paint, palette, contour, weight field or motion is invented here.
"""
import numpy as np
from PIL import Image
from rr37_case import PROJECT, CASE
from cutout_pipeline.cases import read_json, digest
from maquette_motion.features import source_pixels
import rr39_underlay as arm

DIRECTOR = PROJECT/'spec/peer_benchmark/staged/rr-41'
BASELINE = CASE.parent/'rr41_fixture'
CLOAKS = ('cape_near', 'cape_far')
EXPOSURE_REPAIRS = CASE.parent/'rr41_exposure_repairs.json'


def inputs():
    provenance = read_json(DIRECTOR/'provenance.json')
    for name, expected in provenance['files'].items():
        if digest(DIRECTOR/name) != expected:
            raise ValueError('Changed protected rr-41 input: '+name)
    paint = np.asarray(Image.open(DIRECTOR/'front_legs_underlay.png').convert('RGBA')).copy()
    footprint = np.asarray(Image.open(DIRECTOR/'front_legs_footprint_mask.png').convert('L')) > 0
    if paint.shape != (255, 255, 4) or footprint.shape != paint.shape[:2]:
        raise ValueError('Changed rr-41 front registration')
    # The protected PNG retains keyed RGB under alpha=0. Only the derived
    # texture normalizes it to the renderer's transparent-clear representation.
    paint[paint[..., 3] == 0] = 0
    return paint, footprint


def domains():
    paint, footprint = inputs()
    _, arm_footprint = arm.inputs()
    target = footprint & ~arm_footprint & (paint[..., 3] > 0)
    layout = read_json(BASELINE/'source/front.json')
    result = {name: np.zeros(footprint.shape, bool) for name in CLOAKS}
    owner = np.full(footprint.shape, '', object)
    for part in sorted(layout['parts'], key=lambda p:p['z_index']):
        if part['name'] not in ('hidden_'+name for name in CLOAKS): continue
        x0, y0, x1, y1 = part['bbox']
        owner[y0:y1, x0:x1] = part['logical_part']
    for name in result: result[name] = target & (owner == name)
    if np.any(target & (owner == '')):
        raise ValueError('Director lining outside existing cloak backing domains')
    return result


def extensions():
    """Measured boundary UVs; values always come from protected director paint."""
    paint, footprint = inputs()
    _, arm_footprint = arm.inputs()
    result = {name:np.zeros(footprint.shape,bool) for name in CLOAKS}
    for row in read_json(EXPOSURE_REPAIRS)['texels']:
        name = row['part'].removeprefix('hidden_')
        x,y = row['uv']
        if name not in result or footprint[y,x] or arm_footprint[y,x]:
            raise ValueError('Exposure repair overlaps protected ownership or has wrong cloak')
        if row['director'] != paint[y,x].tolist(): raise ValueError('Exposure repair is not exact director paint')
        result[name][y,x] = True
    return result


def painted_domains():
    paint, _ = inputs()
    return {name:target | (extensions()[name] & (paint[...,3]>0)) for name,target in domains().items()}


def replace(hidden):
    paint, footprint = inputs()
    _, arm_footprint = arm.inputs()
    authority = footprint & ~arm_footprint
    for name, target in domains().items():
        hidden[name][authority] = 0
        hidden[name][target] = paint[target]
    for name, target in extensions().items(): hidden[name][target] = paint[target]


def surface(view, logical):
    """Authoritative pixels and RGBA for density/tucks, including true air."""
    image = np.zeros((255, 255, 4), np.uint8)
    authority = np.zeros(image.shape[:2], bool)
    if view != 'front': return authority, image
    if logical in ('torso', 'cape_far', 'foot_far'):
        paint, footprint = arm.inputs()
        authority |= footprint
        image[footprint] = paint[footprint]
    if logical in CLOAKS:
        paint, footprint = inputs()
        _, arm_footprint = arm.inputs()
        target = domains()[logical]
        authority |= footprint & ~arm_footprint
        image[target] = paint[target]
        extra = extensions()[logical]
        authority |= extra
        image[extra] = paint[extra]
    return authority, image


def paint_mask(case, layout, part):
    approved = arm.paint_mask(case, layout, part)
    if layout['facing']=='rear' and layout.get('director_rear_outline'):
        from rr43_outline import paint_mask as outline_paint_mask
        return approved | outline_paint_mask(case,layout,part)
    if layout['facing'] != 'front' or not part.get('hidden_material') or part['logical_part'] not in CLOAKS:
        return approved
    paint, _ = inputs()
    target = domains()[part['logical_part']]
    if part['name']=='hidden_'+part['logical_part']:
        target = painted_domains()[part['logical_part']]
    return approved | (target & np.all(source_pixels(case, part) == paint, axis=-1))


def retire_recipes(layout):
    arm.retire_recipes(layout)
    if layout['facing'] != 'front': return
    _, footprint = inputs()
    _, arm_footprint = arm.inputs()
    footprint &= ~arm_footprint
    extra = extensions()
    parts = {p['name']:p for p in layout['parts']}
    tables = [layout.get('gait_continuations', {})] + list(layout.get('clip_continuations', {}).values())
    for table in tables:
        for name, recipe in table.items():
            part = parts[name]
            if part['logical_part'] not in CLOAKS: continue
            x0, y0 = part['offset']
            authority = footprint | extra[part['logical_part']]
            recipe['texels'] = [row for row in recipe['texels'] if not authority[row[1]+y0, row[0]+x0]]
