"""Director-owned backing: exact registered paint or explicit transparent air.

Receiving ownership is the highest existing body backing domain after excluding
all limbs/items. Storage-domain fallback handles paint formerly missing entirely;
above the pelvis that receiver is the torso. No colours are synthesized.
"""
from pathlib import Path
import sys
import numpy as np
from PIL import Image
sys.path[:0] = [str(Path(__file__).resolve().parents[3]/'tools')]
from rr38_case import PROJECT, CASE as BASE_CASE, ASSETS
from cutout_pipeline.cases import read_json, digest
from maquette_motion.features import source_pixels

CASE = BASE_CASE.parent/'rr42'
DIRECTOR = PROJECT/'spec/peer_benchmark/staged/rr-42'
RECEIVERS = ('torso', 'pelvis', 'tabard', 'coat_near', 'coat_far')
REMOVED_FILLS = ('hidden_coat_near', 'hidden_coat_far', 'hidden_foot_near', 'hidden_foot_far')
FOOTPRINTS = {'near_arm': ('arm_near', 'hand_near'),
              'far_arm': ('arm_far', 'hand_far', 'chain'),
              'legs': ('leg_near', 'foot_near', 'leg_far', 'foot_far')}


def inputs():
    provenance = read_json(DIRECTOR/'provenance.json')
    for name, expected in provenance['files'].items():
        if digest(DIRECTOR/name) != expected:
            raise ValueError('Changed protected rr-42 input: '+name)
    if digest(DIRECTOR/provenance['prompt']) != provenance['prompt_sha256']:
        raise ValueError('Changed protected rr-42 prompt')
    paint = np.asarray(Image.open(DIRECTOR/'front_body_underlay.png').convert('RGBA')).copy()
    masks = {name: np.asarray(Image.open(DIRECTOR/f'front_{name}_footprint_mask.png').convert('L')) > 0
             for name in FOOTPRINTS}
    if paint.shape != (255,255,4) or any(m.shape != (255,255) for m in masks.values()):
        raise ValueError('Changed director registration')
    paint[paint[...,3] == 0] = 0  # Derived runtime clear; protected PNG untouched.
    return paint, masks


def authority_for(logical):
    """Receiving backing only: a moving limb retains its own joint tucks.

    Underlay air describes the body behind a vacated limb. It does not delete
    that limb's painted wrist/knee attachment while the limb is still there.
    """
    _,masks=inputs()
    return np.logical_or.reduce([mask for name,mask in masks.items() if logical not in FOOTPRINTS[name]]) | extra_authority(logical)


def domains():
    paint, masks = inputs()
    authority = np.logical_or.reduce(list(masks.values()))
    layout = read_json(BASE_CASE/'layouts/front.json')
    owner = np.full(authority.shape, '', object)
    ordered = [p for p in sorted(layout['parts'], key=lambda p:p['z_index'])
               if p.get('hidden_material') and p['logical_part'] in RECEIVERS]
    for part in ordered:
        x,y,x1,y1 = part['bbox']
        owner[y:y1,x:x1] = part['logical_part']
    for part in ordered:
        owner[source_pixels(BASE_CASE,part)[...,3] > 0] = part['logical_part']
    # Existing torso/pelvis registration separates cowl from coat lining.
    pelvis_top = min(p['bbox'][1] for p in ordered if p['logical_part']=='pelvis')
    yy,_ = np.indices(authority.shape)
    owner[(owner=='') & (yy < pelvis_top)] = 'torso'
    owner[(owner=='') & (yy >= pelvis_top)] = 'coat_near'
    return {name: authority & (paint[...,3]>0) & (owner==name) for name in RECEIVERS}


def repairs():
    rows=read_json(CASE.parent/'rr42_feedback1_repairs.json')['texels']
    paint,_=inputs()
    seen=set()
    for row in rows:
        x,y=row['uv'];key=(row['part'],x,y)
        if key in seen or not row['part'].startswith('hidden_') or not (0<=x<255 and 0<=y<255):
            raise ValueError('Invalid/duplicate painted exposure repair')
        seen.add(key)
        if row['director_rgba']!=paint[y,x].tolist():raise ValueError('Repair differs from protected director RGBA')
    return rows


def certificates():
    paint,_=inputs()
    result={'hidden_'+name:mask.copy() for name,mask in domains().items()}
    for row in repairs():
        x,y=row['uv'];result.setdefault(row['part'],np.zeros((255,255),bool))[y,x]=paint[y,x,3]>0
    return result


def extra_authority(logical):
    result=np.zeros((255,255),bool)
    for row in repairs():
        if row['part']=='hidden_'+logical:
            x,y=row['uv'];result[y,x]=True
    return result


def retire_recipes(layout):
    _, masks = inputs()
    authority = np.logical_or.reduce(list(masks.values()))
    parts = {p['name']:p for p in layout['parts']}
    retired = []
    tables = [layout.get('gait_continuations',{})] + list(layout.get('clip_continuations',{}).values())
    for table in tables:
        for name, recipe in list(table.items()):
            part = parts[name]; x,y = part['offset']
            kept = [row for row in recipe['texels'] if name not in REMOVED_FILLS and
                    not (layout['facing']=='front' and authority_for(part['logical_part'])[row[1]+y,row[0]+x])]
            retired += [[name,*row[:2]] for row in recipe['texels'] if row not in kept]
            if kept: recipe['texels'] = kept
            else: del table[name]
    return retired
