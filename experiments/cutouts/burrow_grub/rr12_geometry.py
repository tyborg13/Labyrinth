"""Nonhumanoid rr-12 hierarchy, derived from the committed native anatomy.

`body` in director tracks is the shared runtime's `root` bone. Ring pivots
are the meeting planes halfway between neighbouring native mass centres;
legs retain their native attachment joints and native ring ownership.
"""
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'hoarfrost_seer'))
from rr07_geometry import native_depths, projection_for
from rr12_inputs import DIRECTOR, read_json, projected
import numpy as np


def recipe_for(creature, spec):
    joints = {'root': {'joint': 'root', 'position_3d': spec['joints']['root'], 'parent': None}}
    native = {b['name']: b for b in spec['armature']['bones']}
    for name in spec['labels']:
        bone = native[name]
        parent = bone['parent'] or 'root'
        item = {'joint': bone['head'], 'position_3d': spec['joints'][bone['head']], 'parent': parent}
        if creature == 'burrow_grub' and not name.startswith('leg_'):
            parent = {'seg_3': 'root', 'seg_2': 'seg_3', 'seg_1': 'seg_2', 'head': 'seg_1',
                      'seg_4': 'seg_3', 'seg_5': 'seg_4', 'seg_6': 'seg_5', 'tail': 'seg_6'}[name]
            item['parent'] = parent
            if parent != 'root':
                pair = [bone['head'], native[parent]['head']]
                item = {'meeting_centres': pair, 'position_3d': np.mean(
                    [spec['joints'][j] for j in pair], axis=0).tolist(), 'parent': parent}
        joints[name] = item
    clips = read_json(DIRECTOR)[creature]['clips']
    return {'character_id': creature, 'joints': joints, 'parts': {p: p for p in spec['labels']},
            'director_decisions': {'authority': 'rr-12 brief, committed mq-05 anatomy',
                'body': 'Director body tracks bind to runtime root; no material belongs to root',
                'rings': 'seg_3 outward in both directions; pivots at native inter-ring meeting planes',
                'legs': 'Native ring children for Grub; shell > upper > lower for Tick'},
            'motion': 'motion.gd', 'features': 'features.json', 'rigid_bones': [], 'contact_feet': [],
            'materials': {p: p + ' approved paint' for p in spec['labels']}, 'design_placeholders': {},
            'clips': {n: {'frames': round(c['seconds'] * 60), 'duration': c['seconds'],
                          'loop': c.get('loop', False)} for n, c in clips.items()},
            'proof_defaults': {'native_fps': 60, 'render_size': 1024}}


def bind_layout(spec, view, transform, projected_joints, recipe):
    return {name: {'position': transform.point(projected_joints[item['joint']] if 'joint' in item
                    else projected(spec, item['position_3d'], view)), 'parent': item['parent']}
            for name, item in recipe['joints'].items()}, recipe['parts']
