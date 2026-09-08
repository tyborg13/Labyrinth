#!/usr/bin/env python3
"""Rebuild pass-nine rear leg skins and shoulder drape from the frozen pass-eight layout.

Run the rest-bake probe afterward to refresh rest_source and its digest.
"""
from pathlib import Path
import json
from PIL import Image

root = Path(__file__).resolve().parents[2]
base = root / 'experiments/protagonist_2d/references/pass9/baseline'

def smooth(v):
    v = min(1.0, max(0.0, v))
    return v * v * (3.0 - 2.0 * v)

def mesh(part, joints):
    x0, y0 = part['offset']
    width, height = Image.open(root / part['file'].removeprefix('res://')).size
    xs = list(range(x0, x0 + width + 1, 2))
    if xs[-1] != x0 + width:
        xs.append(x0 + width)
    ys = list(range(y0, y0 + height + 1))
    points = [[x,y] for y in ys for x in xs]
    side = part['name'][-1]
    names = ['thigh_'+side, 'shin_'+side, 'foot_'+side]
    weights = {name: [] for name in names}
    knee = joints['shin_'+side]['position'][1]
    ankle = joints['foot_'+side]['position'][1]
    for x, y in points:
        lower = smooth((y - knee + 8.0) / 16.0)
        boot = smooth((y - ankle + 11.0) / 12.0)
        row = [(1-lower) * (1-boot), lower * (1-boot), boot]
        for name, value in zip(names, row):
            weights[name].append(round(value, 8))
    triangles = []
    for row in range(len(ys)-1):
        for column in range(len(xs)-1):
            i = row * len(xs) + column
            triangles.extend([[i, i+1, i+len(xs)+1], [i, i+len(xs)+1, i+len(xs)]])
    return {'equipment_slot':'legs', 'name':'Skin_'+part['name'],
        'replaces_part':part['name'], 'file':part['file'], 'offset':part['offset'],
        'bbox':[x0,y0,x0+width,y0+height], 'z_index':part['z_index'],
        'vertices':points, 'uvs':[[x-x0,y-y0] for x,y in points],
        'triangles':triangles, 'weights':weights, 'family':'rear_leg_'+side,
        'coordinate_space':'registered source pixels; crop-local UV pixels'}

data = json.loads((base/'rear.json').read_text())
# Keep the old shoulder coverage beneath a wider independent drape. The
# visible drape now spans both shoulders, with one continuous texture/mesh.
# Expansion is confined to the shoulder rows and leaves its hanging tails alone.
for point in data['cape_mesh']['vertices']:
    x, y = point
    strength = 1.0 - smooth((y - 85.0) / 33.0)
    point[0] = round(132.0 + (x - 132.0) * (1.0 + (0.70 if x < 132.0 else 0.20) * strength), 6)
    point[1] = round(y - 3.0 * strength, 6)
for part in data['parts']:
    if part['name'] in ['thigh_l', 'shin_l', 'knee_cover_l', 'thigh_r', 'shin_r', 'knee_cover_r']:
        data['joint_meshes'].append(mesh(part, data['joints']))
data['version'] = 9
data['runtime_refinement'] = {'baseline_commit':'66e36c0f51116171edf6611f9a0f346426ec0b0d',
    'rear_leg':'one-source-pixel mesh rows with shared knee and ankle weights; rigid boot retained',
    'rear_cloak':'independent drape widened 70 percent toward the far shoulder and 20 percent toward the near shoulder and raised three pixels; tapers to unchanged hanging tail by y118; underlying shoulder coverage retained'}
(root/'assets/units/protagonist_cutout/rear.json').write_text(json.dumps(data, indent=2)+'\n')
print('Rear leg skins and independent drape covering both shoulders prepared.')
