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
from mesh_assets import build_joint_meshes


HERE = Path(__file__).resolve().parent
SOURCE = HERE / 'references/rear.png'
OUTPUT = HERE / 'assets/rear'
JOINTS = {'root': {'parent': None, 'position': [132, 211]},
 'hips': {'parent': 'root', 'position': [124, 143]},
 'torso': {'parent': 'hips', 'position': [127, 120]},
 'neck': {'parent': 'torso', 'position': [123, 76]},
 'head': {'parent': 'neck', 'position': [126, 47]},
 'arm_r': {'parent': 'torso', 'position': [146, 92]},
 'forearm_r': {'parent': 'arm_r', 'position': [156, 119]},
 'hand_r': {'parent': 'forearm_r', 'position': [167, 145]},
 'arm_l': {'parent': 'torso', 'position': [98, 92], 'fully_occluded': True},
 'forearm_l': {'parent': 'arm_l', 'position': [87, 119], 'fully_occluded': True},
 'hand_l': {'parent': 'forearm_l', 'position': [79, 144], 'fully_occluded': True},
 'thigh_r': {'parent': 'hips', 'position': [136, 155]},
 'shin_r': {'parent': 'thigh_r', 'position': [139, 178]},
 'foot_r': {'parent': 'shin_r', 'position': [141, 204]},
 'thigh_l': {'parent': 'hips', 'position': [104, 156]},
 'shin_l': {'parent': 'thigh_l', 'position': [98, 177]},
 'foot_l': {'parent': 'shin_l', 'position': [94, 196]},
 'cape_root': {'parent': 'torso', 'position': [123, 79]},
 'cape_mid': {'parent': 'cape_root', 'position': [103, 120]},
 'cape_tip': {'parent': 'cape_mid', 'position': [72, 159]}}

POLYGONS = [('head',
  [(85, 0),
   (168, 0),
   (166, 51),
   (156, 58),
   (151, 62),
   (148, 64),
   (143, 62),
   (139, 64),
   (132, 67),
   (122, 66),
   (112, 64),
   (103, 61),
   (97, 59),
   (89, 54)]),
 ('scarf',
  [(91, 59),
   (101, 61),
   (110, 65),
   (126, 67),
   (140, 64),
   (149, 62),
   (153, 69),
   (150, 75),
   (140, 75),
   (128, 79),
   (117, 79),
   (106, 76),
   (98, 73),
   (91, 69)]),
 ('cape_full',
  [(88, 66),
   (94, 72),
   (101, 76),
   (112, 80),
   (124, 79),
   (135, 76),
   (145, 73),
   (151, 73),
   (153, 79),
   (145, 83),
   (140, 89),
   (136, 96),
   (131, 103),
   (128, 110),
   (124, 116),
   (121, 122),
   (116, 129),
   (110, 137),
   (104, 145),
   (99, 152),
   (93, 162),
   (86, 171),
   (78, 179),
   (69, 183),
   (65, 190),
   (56, 190),
   (57, 182),
   (64, 172),
   (64, 167),
   (57, 175),
   (54, 170),
   (48, 175),
   (44, 164),
   (40, 167),
   (33, 172),
   (25, 180),
   (19, 180),
   (20, 170),
   (26, 160),
   (27, 154),
   (22, 150),
   (21, 140),
   (30, 132),
   (43, 126),
   (57, 115),
   (66, 102),
   (76, 87),
   (80, 81),
   (81, 73)]),
 ('sword_hand_r',
  [(162, 142),
   (168, 140),
   (174, 142),
   (178, 137),
   (186, 137),
   (191, 141),
   (188, 151),
   (182, 157),
   (191, 159),
   (255, 213),
   (255, 226),
   (243, 227),
   (215, 211),
   (194, 196),
   (176, 182),
   (167, 180),
   (164, 176),
   (165, 168),
   (163, 161),
   (158, 157),
   (159, 149)]),
 ('forearm_r',
  [(150, 110),
   (161, 109),
   (166, 119),
   (168, 129),
   (174, 139),
   (177, 148),
   (171, 155),
   (161, 151),
   (159, 139),
   (155, 131),
   (149, 121)]),
 ('arm_r',
  [(138, 82),
   (151, 81),
   (158, 88),
   (164, 102),
   (164, 114),
   (159, 121),
   (150, 119),
   (144, 110),
   (139, 104),
   (136, 94)]),
 ('foot_l', [(84, 188), (99, 186), (111, 189), (112, 198), (105, 205), (96, 213), (83, 210), (80, 198)]),
 ('foot_r',
  [(131, 197),
   (143, 194),
   (155, 198),
   (169, 201),
   (169, 216),
   (158, 222),
   (140, 228),
   (133, 224),
   (129, 215)]),
 ('shin_l', [(88, 171), (107, 171), (110, 181), (106, 191), (104, 199), (91, 203), (84, 197), (82, 184)]),
 ('shin_r',
  [(128, 172),
   (143, 171),
   (154, 177),
   (155, 191),
   (151, 203),
   (144, 210),
   (133, 208),
   (128, 198),
   (126, 186)]),
 ('thigh_l', [(95, 147), (112, 146), (117, 156), (116, 167), (110, 177), (93, 178), (88, 168)]),
 ('thigh_r',
  [(124, 149), (141, 149), (151, 156), (153, 168), (151, 180), (136, 184), (125, 177), (122, 164)]),
 ('hips',
  [(111, 131),
   (127, 129),
   (141, 134),
   (149, 146),
   (148, 157),
   (139, 165),
   (122, 163),
   (109, 157),
   (106, 146)])]

Z_ORDER = {'thigh_l': 10,
 'shin_l': 11,
 'foot_l': 12,
 'thigh_r': 20,
 'shin_r': 21,
 'foot_r': 22,
 'torso': 40,
 'hips': 45,
 'cape_upper': 50,
 'cape_middle': 51,
 'cape_lower': 52,
 'arm_r': 60,
 'forearm_r': 61,
 'sword_hand_r': 65,
 'scarf': 70,
 'head': 80}

OVERLAPS = [('head', 'scarf', (124, 65), 5),
 ('torso', 'arm_r', (146, 92), 6),
 ('arm_r', 'forearm_r', (156, 119), 6),
 ('forearm_r', 'sword_hand_r', (167, 145), 6),
 ('torso', 'hips', (125, 139), 6),
 ('hips', 'thigh_r', (136, 155), 6),
 ('hips', 'thigh_l', (104, 156), 6),
 ('thigh_r', 'shin_r', (139, 178), 6),
 ('shin_r', 'foot_r', (141, 204), 6),
 ('thigh_l', 'shin_l', (98, 177), 6),
 ('shin_l', 'foot_l', (94, 196), 6)]

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
        [(108, 78), (134, 77), (143, 87), (141, 104), (149, 132),
         (140, 151), (125, 154), (109, 148), (104, 119), (99, 88)])
    # The collar's last brown pixels sit below the broad scarf polygon. They
    # must follow the neck; leaving this isolated strip on the torso exposes it
    # when the head turns. Transfer only pixels already assigned to the torso.
    collar_strip = cut._polygon(source.size, [(108, 78), (116, 78), (116, 79), (108, 79)])
    collar_strip = ImageChops.multiply(base['torso'], collar_strip)
    base['torso'] = ImageChops.subtract(base['torso'], collar_strip)
    base['scarf'] = ImageChops.lighter(base['scarf'], collar_strip)
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
    # The torso/hips seam spans the full coat width, not just a central pivot.
    # A narrow disc left a one-pixel slit near the right waist during walk17.
    # Share the existing coat pixels across this broad hidden overlap band.
    waist_band = cut._polygon(source.size, [(94, 124), (156, 124), (156, 153), (94, 153)])
    waist_band = ImageChops.multiply(waist_band, ImageChops.lighter(base['torso'], base['hips']))
    for name in ('torso', 'hips'):
        masks[name] = ImageChops.lighter(masks[name], waist_band)
    overlap_report.append({'parts': ['torso', 'hips'], 'rect': [94, 124, 157, 154],
                           'source_pixels_shared': cut._count(waist_band),
                           'reason': 'Full-width coat coverage through pelvis counterrotation'})
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
    joint_meshes = build_joint_meshes(source, masks, JOINTS, parts, OUTPUT, 'assets/rear')
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
    layout = {'version': 2, 'facing': 'rear', 'canvas_size': [255, 255], 'source': 'references/rear.png',
              'source_sha256': hashlib.sha256(SOURCE.read_bytes()).hexdigest(),
              'source_occupied_bbox': list(alpha.getbbox()), 'joints': JOINTS, 'parts': parts,
              'cape_mesh': cape_mesh, 'joint_meshes': joint_meshes, 'source_only_joint_overlaps': overlap_report,
              'source_outline_assignments': assignments, 'exact_rest_proof': proof,
              'hidden_bones': ['arm_l', 'forearm_l', 'hand_l'],
              'constraints': [
                  'Rear source is a separately authored interpretation, not a view recovered from the original front sprite.',
                  'All cutout pixels are copied unchanged from that rear source; no hidden body or limb pixels are invented.',
                  'The left arm is fully concealed by the cape and intentionally has no visible cutout parts.',
                  'The right hand and sword remain joined. Rear walk keeps this true rear artwork rather than mirroring the front.',
                  'Upper and lower limb meshes share bend fields and pin overlap material to rigid body, boots and sword-hand pieces.',
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
