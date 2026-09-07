"""Source-only rear cutouts for the separately illustrated rear Reaver study.

The original front remains untouched. This partitions the approved-for-study
rear reference and leaves the fully occluded left arm unpainted and invisible.
"""
from __future__ import annotations

import hashlib
import json
import math
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw

import cutout_assets as cut


HERE = Path(__file__).resolve().parent
SOURCE = HERE / 'references/rear.png'
OUTPUT = HERE / 'assets/rear'
JOINTS = {
    'root': {'parent': None, 'position': [132, 211]},
    'hips': {'parent': 'root', 'position': [122, 146]},
    'torso': {'parent': 'hips', 'position': [122, 119]},
    'neck': {'parent': 'torso', 'position': [120, 70]},
    'head': {'parent': 'neck', 'position': [123, 56]},
    'arm_r': {'parent': 'torso', 'position': [144, 87]},
    'forearm_r': {'parent': 'arm_r', 'position': [151, 112]},
    'hand_r': {'parent': 'forearm_r', 'position': [160, 146]},
    'arm_l': {'parent': 'torso', 'position': [94, 89], 'fully_occluded': True},
    'forearm_l': {'parent': 'arm_l', 'position': [88, 119], 'fully_occluded': True},
    'hand_l': {'parent': 'forearm_l', 'position': [85, 142], 'fully_occluded': True},
    'thigh_r': {'parent': 'hips', 'position': [133, 150]},
    'shin_r': {'parent': 'thigh_r', 'position': [135, 176]},
    'foot_r': {'parent': 'shin_r', 'position': [134, 205]},
    'thigh_l': {'parent': 'hips', 'position': [105, 153]},
    'shin_l': {'parent': 'thigh_l', 'position': [100, 177]},
    'foot_l': {'parent': 'shin_l', 'position': [96, 196]},
    'cape_root': {'parent': 'torso', 'position': [119, 73]},
    'cape_mid': {'parent': 'cape_root', 'position': [102, 115]},
    'cape_tip': {'parent': 'cape_mid', 'position': [84, 152]},
}

POLYGONS = [
    ('head', [(87, 0), (165, 0), (164, 45), (155, 51), (150, 54), (145, 58),
              (138, 62), (125, 62), (111, 61), (102, 60), (97, 57), (91, 56), (87, 48)]),
    ('cape_full', [(93, 53), (102, 58), (101, 64), (108, 68), (126, 71),
                   (138, 67), (143, 66), (148, 70), (148, 75), (138, 80),
                   (132, 88), (128, 97), (125, 107), (122, 117),
                   (119, 128), (116, 138), (111, 147), (106, 155), (101, 163),
                   (99, 169), (94, 173), (91, 170), (88, 176), (81, 180),
                   (76, 179), (77, 170), (68, 174), (63, 173), (62, 163),
                   (58, 166), (54, 164), (46, 166), (49, 158), (55, 151),
                   (60, 140), (64, 129), (68, 117), (73, 104), (77, 92),
                   (80, 81), (77, 76), (80, 67), (86, 60)]),
    ('scarf', [(94, 52), (106, 57), (120, 60), (136, 58), (144, 55), (147, 63),
               (143, 70), (128, 73), (112, 72), (101, 69), (94, 64)]),
    ('sword_hand_r', [(153, 136), (162, 134), (169, 137), (174, 131), (182, 131),
                      (184, 139), (180, 147), (187, 157), (201, 170), (217, 184),
                      (248, 212), (246, 220), (226, 217), (208, 206), (190, 192),
                      (175, 181), (166, 177), (158, 175), (156, 167), (158, 160),
                      (149, 154), (148, 145)]),
    ('forearm_r', [(138, 103), (151, 103), (158, 109), (163, 121), (166, 135),
                    (167, 144), (160, 150), (150, 144), (144, 133), (139, 120)]),
    ('arm_r', [(136, 76), (148, 77), (155, 85), (159, 95), (158, 104),
               (153, 111), (145, 113), (136, 105), (131, 94), (132, 84)]),
    ('foot_l', [(86, 190), (103, 188), (114, 192), (115, 201), (106, 209),
                (91, 212), (83, 206), (82, 198)]),
    ('foot_r', [(123, 199), (140, 197), (148, 201), (160, 204), (162, 215),
                (151, 224), (129, 229), (121, 220), (120, 208)]),
    ('shin_l', [(87, 170), (107, 168), (113, 178), (112, 192), (107, 201),
                (91, 203), (83, 193)]),
    ('shin_r', [(121, 170), (137, 168), (148, 175), (152, 188), (147, 202),
                (138, 209), (125, 207), (118, 194)]),
    ('thigh_l', [(95, 149), (111, 147), (116, 156), (114, 171), (108, 180),
                 (92, 179), (89, 164)]),
    ('thigh_r', [(121, 147), (140, 147), (147, 156), (145, 168), (146, 178),
                 (132, 183), (120, 177), (118, 164)]),
    ('hips', [(111, 131), (127, 129), (141, 134), (147, 146), (145, 157),
               (139, 164), (123, 163), (110, 157), (107, 144)]),
]
Z_ORDER = {'thigh_l': 10, 'shin_l': 11, 'foot_l': 12, 'thigh_r': 20, 'shin_r': 21,
           'foot_r': 22, 'torso': 40, 'hips': 45, 'cape_upper': 50, 'cape_middle': 51,
           'cape_lower': 52, 'arm_r': 60, 'forearm_r': 61, 'sword_hand_r': 65,
           'scarf': 70, 'head': 80}
OVERLAPS = [('head', 'scarf', (121, 61), 5),
            ('torso', 'arm_r', (139, 87), 5), ('arm_r', 'forearm_r', (150, 109), 5),
            ('forearm_r', 'sword_hand_r', (159, 140), 5), ('torso', 'hips', (126, 137), 6),
            ('hips', 'thigh_r', (131, 151), 5), ('hips', 'thigh_l', (105, 154), 5),
            ('thigh_r', 'shin_r', (134, 174), 5), ('shin_r', 'foot_r', (134, 201), 5),
            ('thigh_l', 'shin_l', (101, 174), 5), ('shin_l', 'foot_l', (97, 194), 5)]


def _save(source, mask, name):
    bbox = mask.getbbox()
    if not bbox:
        raise ValueError('Empty rear cutout: ' + name)
    cut._masked(source, mask).crop(bbox).save(OUTPUT / (name + '.png'))
    return bbox


def _cape_distance(x, y):
    a, c = JOINTS['cape_root']['position'], JOINTS['cape_mid']['position']
    dx, dy = c[0] - a[0], c[1] - a[1]
    length = math.hypot(dx, dy)
    return (dx * (x - a[0]) + dy * (y - a[1])) / length


def _cape_mesh(source, mask):
    bbox = _save(source, mask, 'cape_full')
    x0, y0, x1, y1 = bbox
    xs, ys = list(range(x0, x1, 8)) + [x1], list(range(y0, y1, 8)) + [y1]
    vertices, uvs = [], []
    weights = {name: [] for name in ('cape_root', 'cape_mid', 'cape_tip')}
    for y in ys:
        for x in xs:
            vertices.append([x, y]); uvs.append([x - x0, y - y0])
            distance = _cape_distance(x, y)
            if distance <= 20:
                values = (1., 0., 0.)
            elif distance <= 60:
                t = (distance - 20) / 40
                values = (1 - t, t, 0.)
            elif distance <= 99:
                t = (distance - 60) / 39
                values = (0., 1 - t, t)
            else:
                values = (0., 0., 1.)
            for name, value in zip(weights, values):
                weights[name].append(round(value, 8))
    triangles = []
    for j in range(len(ys) - 1):
        for i in range(len(xs) - 1):
            k = j * len(xs) + i
            triangles += [[k, k + 1, k + len(xs) + 1], [k, k + len(xs) + 1, k + len(xs)]]
    return {'file': 'assets/rear/cape_full.png', 'offset': [x0, y0], 'bbox': list(bbox),
            'vertices': vertices, 'uvs': uvs, 'triangles': triangles, 'weights': weights,
            'z_index': 50, 'coordinate_space': 'source pixels; UVs are crop-local pixels'}


def main():
    source = Image.open(SOURCE).convert('RGBA')
    alpha = source.getchannel('A')
    if source.size != (255, 255) or any(alpha.histogram()[1:255]):
        raise ValueError('Expected the prepared 255px rear reference with binary alpha')
    OUTPUT.mkdir(parents=True, exist_ok=True)
    available, base = alpha.copy(), {}
    for name, points in POLYGONS:
        owned = ImageChops.multiply(cut._polygon(source.size, points), available)
        base[name] = owned
        available = ImageChops.subtract(available, owned)
    assignments = cut._assign_outline_fragments(base, available,
        [(106, 72), (132, 71), (144, 82), (142, 102), (144, 122),
         (137, 144), (125, 153), (110, 149), (102, 118), (98, 85)])
    assert sum(cut._count(mask) for mask in base.values()) == cut._count(alpha)
    masks = {name: mask.copy() for name, mask in base.items() if name != 'cape_full'}
    overlap_report = []
    for a, c, point, radius in OVERLAPS:
        disk = Image.new('L', source.size)
        ImageDraw.Draw(disk).ellipse((point[0] - radius, point[1] - radius,
                                     point[0] + radius, point[1] + radius), fill=255)
        shared = ImageChops.multiply(disk, ImageChops.lighter(base[a], base[c]))
        for name in (a, c):
            masks[name] = ImageChops.lighter(masks[name], shared)
        overlap_report.append({'parts': [a, c], 'position': list(point), 'radius': radius,
                               'source_pixels_shared': cut._count(shared)})
    for name, low, high in [('cape_upper', -1000, 49), ('cape_middle', 43, 87),
                            ('cape_lower', 81, 1000)]:
        selection = Image.new('L', source.size)
        selection.putdata([255 if low <= _cape_distance(x, y) <= high else 0
                           for y in range(255) for x in range(255)])
        masks[name] = ImageChops.multiply(base['cape_full'], selection)
    parts = []
    for name in sorted(masks, key=lambda n: Z_ORDER[n]):
        bbox = _save(source, masks[name], name)
        bone = cut.PART_BONES[name]
        part = {'name': name, 'file': 'assets/rear/' + name + '.png', 'bone': bone,
                'offset': list(bbox[:2]), 'bbox': list(bbox), 'pivot': JOINTS[bone]['position'],
                'z_index': Z_ORDER[name], 'source_pixel_count': cut._count(masks[name])}
        if name.startswith('cape_'):
            part['cape_segment'] = True
        parts.append(part)
    cape_mesh = _cape_mesh(source, base['cape_full'])
    proof = {}
    for mode in ('segments', 'weighted_cape'):
        composite = Image.new('RGBA', source.size)
        if mode == 'weighted_cape':
            composite.alpha_composite(cut._masked(source, base['cape_full']))
        for part in parts:
            if mode == 'weighted_cape' and part.get('cape_segment'):
                continue
            composite.alpha_composite(cut._masked(source, masks[part['name']]))
        difference = ImageChops.difference(source, composite)
        changed = sum(1 for pixel in difference.getdata() if any(pixel))
        proof[mode] = {'different_rgba_pixels': changed, 'exact_rest_reconstruction': changed == 0}
        if changed:
            raise AssertionError(f'Rear {mode}: {changed} changed reference pixels')
        composite.save(OUTPUT / ('rest_reconstruction_' + mode + '.png'))
    comparison = Image.new('RGBA', (510, 275), (30, 31, 33, 255))
    comparison.alpha_composite(source, (0, 20)); comparison.alpha_composite(composite, (255, 20))
    draw = ImageDraw.Draw(comparison)
    draw.text((8, 4), 'Authored rear reference', fill=(239, 234, 219))
    draw.text((263, 4), 'Rear cutouts: 0 changed pixels', fill=(239, 234, 219))
    comparison.resize((1020, 550), Image.Resampling.NEAREST).save(OUTPUT / 'rest_comparison.png')
    cut._contact_sheet(source, masks, parts, OUTPUT)
    layout = {'version': 1, 'facing': 'rear', 'canvas_size': [255, 255], 'source': 'references/rear.png',
              'source_sha256': hashlib.sha256(SOURCE.read_bytes()).hexdigest(),
              'source_occupied_bbox': list(alpha.getbbox()), 'joints': JOINTS, 'parts': parts,
              'cape_mesh': cape_mesh, 'source_only_joint_overlaps': overlap_report,
              'source_outline_assignments': assignments, 'exact_rest_proof': proof,
              'hidden_bones': ['arm_l', 'forearm_l', 'hand_l'],
              'constraints': [
                  'Rear source is a separately authored interpretation, not a view recovered from the original front sprite.',
                  'All cutout pixels are copied unchanged from that rear source; no hidden body or limb pixels are invented.',
                  'The left arm is fully concealed by the cape and intentionally has no visible cutout parts.',
                  'The right hand and sword remain joined. Rear walk keeps this true rear artwork rather than mirroring the front.',
                  'Large leg separation can reveal unpainted upper-thigh regions behind the cape; begin with short planted steps.',
              ]}
    (HERE / 'cutout_layout_rear.json').write_text(json.dumps(layout, indent=2) + '\n')
    (OUTPUT / 'reconstruction_proof.json').write_text(json.dumps({
        'source_sha256': layout['source_sha256'], 'visible_source_pixels': cut._count(alpha),
        'exclusive_base_pixels': {name: cut._count(mask) for name, mask in base.items()},
        'source_outline_assignments': assignments, 'source_rgba_preserved': True, 'proof': proof,
    }, indent=2) + '\n')
    print(json.dumps({'facing': 'rear', 'parts': len(parts), 'cape_mesh_vertices': len(cape_mesh['vertices']),
                      'visible_source_pixels': cut._count(alpha), 'proof': proof}, indent=2))


if __name__ == '__main__':
    main()
