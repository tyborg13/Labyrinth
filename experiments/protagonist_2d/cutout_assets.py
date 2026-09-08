"""Partition the original Reaver pixels into editable 2D skeletal cutouts.

No pixels are painted, synthesized, stretched or color-adjusted. The masks
assign every visible source pixel, then copy a small number of existing pixels
across selected joint seams. Binary source alpha makes those source-only
overlaps reproduce the original exactly. Hidden anatomy remains unfilled.
"""
from __future__ import annotations

import hashlib
import json
import math
from pathlib import Path

from PIL import Image, ImageChops, ImageDraw, ImageFont

from mesh_assets import build_joint_meshes, front_cape_weights


HERE = Path(__file__).resolve().parent
PROJECT = HERE.parents[1]
SOURCE = PROJECT / 'assets/placeholders/units/player_reaver.png'
OUTPUT = HERE / 'assets/front'

JOINTS = {
    'root': {'parent': None, 'position': [132, 211]},
    'hips': {'parent': 'root', 'position': [131, 132]},
    'torso': {'parent': 'hips', 'position': [126, 125]},
    'neck': {'parent': 'torso', 'position': [131, 84]},
    'head': {'parent': 'neck', 'position': [130, 66]},
    'arm_r': {'parent': 'torso', 'position': [104, 100]},
    'forearm_r': {'parent': 'arm_r', 'position': [99, 113]},
    'hand_r': {'parent': 'forearm_r', 'position': [94, 126]},
    'arm_l': {'parent': 'torso', 'position': [157, 101]},
    'forearm_l': {'parent': 'arm_l', 'position': [166, 131]},
    'hand_l': {'parent': 'forearm_l', 'position': [166, 150]},
    'thigh_r': {'parent': 'hips', 'position': [122, 144]},
    'shin_r': {'parent': 'thigh_r', 'position': [117, 168]},
    'foot_r': {'parent': 'shin_r', 'position': [112, 184]},
    'thigh_l': {'parent': 'hips', 'position': [144, 146]},
    'shin_l': {'parent': 'thigh_l', 'position': [155, 178]},
    'foot_l': {'parent': 'shin_l', 'position': [164, 202]},
    'cape_root': {'parent': 'torso', 'position': [151, 78]},
    'cape_mid': {'parent': 'cape_root', 'position': [173, 119]},
    'cape_tip': {'parent': 'cape_mid', 'position': [195, 156]},
}

# Hand-traced material boundaries. Visible sleeves have priority over the long
# cape; its separate far-shoulder fold has priority over the sleeve below it.
# A repeated part name unions visible regions of the same occluded garment.
POLYGONS = [('head',
  [(88, 0),
   (183, 0),
   (180, 49),
   (169, 54),
   (164, 59),
   (161, 65),
   (156, 70),
   (149, 72),
   (147, 76),
   (139, 78),
   (129, 80),
   (120, 79),
   (116, 76),
   (112, 72),
   (109, 67),
   (107, 63),
   (100, 61),
   (94, 49),
   (87, 39)]),
 ('cape_full',
  [(104, 69),
   (106, 70),
   (108, 76),
   (111, 79),
   (112, 81),
   (111, 83),
   (109, 84),
   (108, 87),
   (107, 91),
   (105, 94),
   (100, 96),
   (96, 96),
   (97, 90),
   (100, 85),
   (100, 79),
   (101, 75)]),
 ('sword_hand_r',
  [(73, 115),
   (83, 118),
   (89, 124),
   (92, 125),
   (98, 124),
   (104, 126),
   (105, 131),
   (101, 138),
   (98, 146),
   (88, 151),
   (77, 153),
   (64, 164),
   (42, 183),
   (16, 197),
   (0, 197),
   (0, 176),
   (42, 139),
   (61, 131),
   (73, 130)]),
 ('hand_l',
  [(158, 151),
   (168, 151),
   (172, 150),
   (175, 150),
   (177, 149),
   (181, 150),
   (181, 160),
   (175, 163),
   (162, 162),
   (157, 157)]),
 ('forearm_r',
  [(91, 109), (100, 108), (109, 113), (106, 122), (101, 129), (91, 130), (85, 125), (85, 118)]),
 ('arm_r',
  [(97, 91),
   (106, 92),
   (113, 101),
   (111, 109),
   (105, 116),
   (97, 117),
   (90, 114),
   (89, 107),
   (93, 100)]),
 ('forearm_l',
  [(159, 125),
   (172, 124),
   (177, 127),
   (179, 132),
   (179, 139),
   (176, 140),
   (178, 141),
   (181, 143),
   (181, 149),
   (176, 151),
   (169, 152),
   (159, 151),
   (154, 149),
   (155, 144),
   (160, 139),
   (158, 135)]),
 ('arm_l',
  [(156, 118), (165, 117), (171, 120), (173, 121), (175, 125), (171, 128), (160, 129), (156, 125)]),
 ('cape_full',
  [(161, 54),
   (169, 59),
   (174, 67),
   (179, 72),
   (175, 77),
   (183, 83),
   (182, 91),
   (190, 101),
   (194, 113),
   (202, 121),
   (207, 132),
   (214, 138),
   (216, 148),
   (220, 158),
   (224, 180),
   (215, 177),
   (216, 191),
   (207, 197),
   (202, 183),
   (197, 180),
   (192, 182),
   (186, 170),
   (180, 160),
   (177, 150),
   (175, 140),
   (172, 131),
   (168, 123),
   (163, 116),
   (162, 109),
   (160, 107),
   (157, 105),
   (155, 102),
   (151, 101),
   (149, 99),
   (147, 97),
   (145, 95),
   (142, 93),
   (140, 92),
   (138, 89),
   (140, 86),
   (140, 82),
   (140, 78),
   (148, 74),
   (148, 71),
   (155, 68),
   (161, 66),
   (163, 62)]),
 ('scarf',
  [(105, 61),
   (113, 70),
   (122, 77),
   (133, 79),
   (144, 75),
   (151, 70),
   (158, 61),
   (163, 59),
   (162, 68),
   (156, 75),
   (150, 78),
   (140, 84),
   (139, 93),
   (129, 94),
   (121, 91),
   (115, 87),
   (109, 83),
   (105, 77),
   (102, 71)]),
 ('foot_r',
  [(103, 176),
   (118, 175),
   (128, 177),
   (134, 184),
   (131, 191),
   (120, 196),
   (107, 199),
   (96, 197),
   (92, 189),
   (97, 181)]),
 ('foot_l',
  [(153, 197), (171, 196), (181, 204), (184, 215), (178, 229), (165, 232), (153, 225), (150, 212)]),
 ('shin_r', [(110, 162), (127, 162), (133, 170), (131, 180), (123, 186), (110, 186), (105, 178)]),
 ('shin_l',
  [(145, 177),
   (157, 179),
   (167, 177),
   (172, 176),
   (178, 178),
   (181, 184),
   (177, 198),
   (176, 205),
   (161, 208),
   (152, 201),
   (145, 188)]),
 ('thigh_r', [(109, 143), (124, 143), (137, 149), (137, 158), (130, 171), (112, 171), (105, 159)]),
 ('thigh_l',
  [(130, 141),
   (145, 140),
   (156, 148),
   (165, 158),
   (174, 167),
   (179, 177),
   (177, 183),
   (151, 184),
   (139, 178),
   (132, 166),
   (127, 154)]),
 ('hips',
  [(103, 120),
   (117, 116),
   (132, 117),
   (143, 116),
   (154, 120),
   (160, 128),
   (157, 138),
   (160, 148),
   (150, 157),
   (138, 154),
   (130, 152),
   (116, 155),
   (106, 149),
   (102, 139)])]

# Isolated contour pixels follow the adjacent garment, not the nearest broad
# polygon. These were checked against the source at native-pixel resolution.
EDGE_PIXEL_OWNERS = {
    'hips': [(101, 145), (101, 146), (101, 147), (103, 135)],
    'thigh_r': [(99, 153), (133, 167), (133, 168)],
}

PART_BONES = {'head': 'head', 'scarf': 'neck', 'torso': 'torso', 'hips': 'hips',
              'sword_hand_r': 'hand_r', 'arm_r': 'arm_r', 'forearm_r': 'forearm_r',
              'arm_l': 'arm_l', 'forearm_l': 'forearm_l', 'hand_l': 'hand_l',
              'thigh_r': 'thigh_r', 'shin_r': 'shin_r', 'foot_r': 'foot_r',
              'thigh_l': 'thigh_l', 'shin_l': 'shin_l', 'foot_l': 'foot_l',
              'cape_upper': 'cape_root', 'cape_middle': 'cape_mid', 'cape_lower': 'cape_tip'}
Z_ORDER = {'cape_upper': 0, 'cape_middle': 1, 'cape_lower': 2,
           'thigh_r': 10, 'shin_r': 11, 'foot_r': 12, 'thigh_l': 20, 'shin_l': 21,
           'foot_l': 22, 'arm_r': 30, 'forearm_r': 31, 'torso': 40, 'hips': 45,
           'arm_l': 50, 'forearm_l': 51, 'hand_l': 52, 'sword_hand_r': 60,
           'scarf': 70, 'head': 80}
OVERLAPS = [('head', 'scarf', (130, 78), 5), ('scarf', 'torso', (129, 91), 4),
            ('torso', 'arm_r', (104, 100), 5), ('arm_r', 'forearm_r', (99, 113), 4),
            ('forearm_r', 'sword_hand_r', (95, 126), 3),
            ('arm_l', 'forearm_l', (166, 127), 4), ('forearm_l', 'hand_l', (166, 151), 3),
            ('torso', 'hips', (127, 122), 6), ('hips', 'thigh_r', (122, 146), 5),
            ('hips', 'thigh_l', (143, 147), 5), ('thigh_r', 'shin_r', (118, 167), 5),
            ('shin_r', 'foot_r', (114, 180), 4), ('thigh_l', 'shin_l', (156, 176), 5),
            ('shin_l', 'foot_l', (164, 201), 4)]


def _count(mask):
    return mask.histogram()[255]


def _polygon(size, points):
    mask = Image.new('L', size)
    ImageDraw.Draw(mask).polygon(points, fill=255)
    return mask


def _masked(source, mask):
    return Image.composite(source, Image.new('RGBA', source.size), mask)


def _assign_outline_fragments(base_masks, available, core_points=None):
    """Attach unclaimed outline pixels to their nearest visible body part.

    The torso owns only its actual central silhouette. Small black edge pixels
    beyond a manually drawn polygon must move with the adjacent limb/weapon,
    rather than becoming distant islands on the torso texture.
    """
    core = _polygon(available.size, core_points or [(96, 80), (114, 81), (139, 84), (148, 91),
                                                   (158, 112), (153, 123), (132, 129), (107, 126),
                                                   (99, 112), (92, 97)])
    base_masks['torso'] = ImageChops.multiply(available, core)
    outside = ImageChops.subtract(available, base_masks['torso'])
    labels = {}
    rank = {name: index for index, name in enumerate(base_masks)}
    for name, mask in base_masks.items():
        labels.update({(x, y): name for y in range(mask.height) for x in range(mask.width)
                       if mask.getpixel((x, y))})
    assigned = {name: 0 for name in base_masks}
    for y in range(outside.height):
        for x in range(outside.width):
            if not outside.getpixel((x, y)):
                continue
            best = None
            for radius in range(1, 24):
                candidates = []
                for dy in range(-radius, radius + 1):
                    for dx in range(-radius, radius + 1):
                        if max(abs(dx), abs(dy)) != radius:
                            continue
                        owner = labels.get((x + dx, y + dy))
                        if owner is not None:
                            candidates.append((dx * dx + dy * dy, rank[owner], owner))
                if candidates:
                    candidate = min(candidates)
                    if best is None or candidate < best:
                        best = candidate
                if best is not None and (radius + 1) ** 2 > best[0]:
                    break
            if best is None:
                raise ValueError(f'Unowned source island at {(x, y)} needs an explicit mask')
            base_masks[best[2]].putpixel((x, y), 255)
            assigned[best[2]] += 1
    return {name: count for name, count in assigned.items() if count}


def build_base_masks(source):
    """Return exclusive semantic source ownership before any joint overlap."""
    available, base_masks = source.getchannel('A').copy(), {}
    for name, polygon in POLYGONS:
        owned = ImageChops.multiply(_polygon(source.size, polygon), available)
        base_masks[name] = ImageChops.lighter(
            base_masks.get(name, Image.new('L', source.size)), owned)
        available = ImageChops.subtract(available, owned)
    outline_assignments = _assign_outline_fragments(base_masks, available)
    for owner, points in EDGE_PIXEL_OWNERS.items():
        for point in points:
            if not source.getchannel('A').getpixel(point):
                raise AssertionError(f'Contour landmark is transparent: {point}')
            for mask in base_masks.values():
                mask.putpixel(point, 0)
            base_masks[owner].putpixel(point, 255)
    return base_masks, outline_assignments


def _save_part(source, mask, name):
    bbox = mask.getbbox()
    if not bbox:
        raise ValueError('Empty cutout: ' + name)
    image = _masked(source, mask).crop(bbox)
    image.save(OUTPUT / (name + '.png'))
    return bbox


def _cape_mesh(source, mask):
    bbox = _save_part(source, mask, 'cape_full')
    x0, y0, x1, y1 = bbox
    xs = list(range(x0, x1, 8)) + [x1]
    ys = list(range(y0, y1, 8)) + [y1]
    vertices, uvs = [], []
    weights = {name: [] for name in ('cape_root', 'cape_mid', 'cape_tip')}
    for y in ys:
        for x in xs:
            vertices.append([x, y]); uvs.append([x - x0, y - y0])
            values = front_cape_weights((x, y))
            for name, value in zip(weights, values):
                weights[name].append(round(value, 8))
    triangles = []
    for j in range(len(ys) - 1):
        for i in range(len(xs) - 1):
            k = j * len(xs) + i
            triangles += [[k, k + 1, k + len(xs) + 1], [k, k + len(xs) + 1, k + len(xs)]]
    return {'file': 'assets/front/cape_full.png', 'offset': [x0, y0], 'bbox': list(bbox),
            'vertices': vertices, 'uvs': uvs, 'triangles': triangles, 'weights': weights,
            'z_index': 0, 'coordinate_space': 'source pixels; UVs are crop-local pixels'}


def _contact_sheet(source, masks, parts, output=None):
    cell_w, cell_h = 216, 190
    columns = 5
    rows = math.ceil(len(parts) / columns)
    sheet = Image.new('RGBA', (columns * cell_w, rows * cell_h), (37, 39, 41, 255))
    draw = ImageDraw.Draw(sheet)
    for index, part in enumerate(parts):
        x, y = (index % columns) * cell_w, (index // columns) * cell_h
        image = Image.open(HERE / part['file']).convert('RGBA')
        scale = min(4, 190 / image.width, 152 / image.height)
        size = (max(1, round(image.width * scale)), max(1, round(image.height * scale)))
        image = image.resize(size, Image.Resampling.NEAREST)
        sheet.alpha_composite(image, (x + (cell_w - size[0]) // 2, y + 25 + (152 - size[1]) // 2))
        draw.text((x + 8, y + 6), part['name'], fill=(238, 232, 210))
        draw.rectangle((x, y, x + cell_w - 1, y + cell_h - 1), outline=(62, 65, 68))
    sheet.save((output or OUTPUT) / 'cutout_contact_sheet.png')


def main():
    source = Image.open(SOURCE).convert('RGBA')
    alpha = source.getchannel('A')
    if source.size != (255, 255) or any(alpha.histogram()[1:255]):
        raise ValueError('Expected the unchanged 255px source with binary alpha')
    OUTPUT.mkdir(parents=True, exist_ok=True)
    base_masks, outline_assignments = build_base_masks(source)
    assert sum(_count(mask) for mask in base_masks.values()) == _count(alpha)
    masks = {name: mask.copy() for name, mask in base_masks.items() if name != 'cape_full'}
    overlap_report = []
    for a, c, point, radius in OVERLAPS:
        disk = Image.new('L', source.size)
        ImageDraw.Draw(disk).ellipse((point[0] - radius, point[1] - radius,
                                     point[0] + radius, point[1] + radius), fill=255)
        shared = ImageChops.multiply(disk, ImageChops.lighter(base_masks[a], base_masks[c]))
        for name in (a, c):
            masks[name] = ImageChops.lighter(masks[name], shared)
        overlap_report.append({'parts': [a, c], 'position': list(point), 'radius': radius,
                               'source_pixels_shared': _count(shared)})
    # Alternate rigid cape segments are provided for editors that cannot skin a
    # texture mesh. The primary cape mesh below uses the full unbroken texture.
    for name, low, high in [('cape_upper', -1000, 117), ('cape_middle', 111, 141),
                            ('cape_lower', 135, 1000)]:
        selection = Image.new('L', source.size)
        selection.putdata([255 if low <= y - .47 * (x - 160) <= high else 0
                           for y in range(255) for x in range(255)])
        masks[name] = ImageChops.multiply(base_masks['cape_full'], selection)
    parts = []
    for name in sorted(masks, key=lambda n: Z_ORDER[n]):
        bbox = _save_part(source, masks[name], name)
        bone = PART_BONES[name]
        part = {'name': name, 'file': 'assets/front/' + name + '.png', 'bone': bone,
                'offset': list(bbox[:2]), 'bbox': list(bbox), 'pivot': JOINTS[bone]['position'],
                'z_index': Z_ORDER[name], 'source_pixel_count': _count(masks[name])}
        if name.startswith('cape_'):
            part['cape_segment'] = True
        parts.append(part)
    cape_mesh = _cape_mesh(source, base_masks['cape_full'])
    joint_meshes = build_joint_meshes(source, masks, JOINTS, parts, OUTPUT, 'assets/front')
    mesh_by_part = {mesh['replaces_part']: mesh for mesh in joint_meshes}
    proof = {}
    for mode in ('segments', 'weighted_cape', 'weighted_joints'):
        composite = Image.new('RGBA', source.size)
        if mode != 'segments':
            composite.alpha_composite(_masked(source, base_masks['cape_full']))
        for part in parts:
            if mode != 'segments' and part.get('cape_segment'):
                continue
            if mode == 'weighted_joints' and part['name'] in mesh_by_part:
                mesh = mesh_by_part[part['name']]
                with Image.open(HERE / mesh['file']) as image:
                    composite.alpha_composite(image, tuple(mesh['offset']))
            else:
                composite.alpha_composite(_masked(source, masks[part['name']]))
        difference = ImageChops.difference(source, composite)
        changed = sum(1 for pixel in difference.getdata() if any(pixel))
        proof[mode] = {'different_rgba_pixels': changed, 'exact_rest_reconstruction': changed == 0}
        if changed:
            raise AssertionError(f'{mode} reconstruction changed {changed} original pixels')
        composite.save(OUTPUT / ('rest_reconstruction_' + mode + '.png'))
    # A visible side-by-side proof includes the native sprite and its exact
    # reconstruction; the comparison itself is enlarged only for inspection.
    comparison = Image.new('RGBA', (510, 275), (30, 31, 33, 255))
    comparison.alpha_composite(source, (0, 20)); comparison.alpha_composite(composite, (255, 20))
    draw = ImageDraw.Draw(comparison)
    draw.text((8, 4), 'Original source', fill=(239, 234, 219))
    draw.text((263, 4), 'Cutouts: 0 changed pixels', fill=(239, 234, 219))
    comparison.resize((1020, 550), Image.Resampling.NEAREST).save(OUTPUT / 'rest_comparison.png')
    _contact_sheet(source, masks, parts)
    layout = {
        'version': 2, 'facing': 'front', 'canvas_size': [255, 255],
        'source': '../../assets/placeholders/units/player_reaver.png',
        'source_sha256': hashlib.sha256(SOURCE.read_bytes()).hexdigest(),
        'source_occupied_bbox': list(alpha.getbbox()), 'joints': JOINTS, 'parts': parts,
        'cape_mesh': cape_mesh, 'joint_meshes': joint_meshes,
        'source_only_joint_overlaps': overlap_report,
        'source_outline_assignments': outline_assignments,
        'semantic_ownership_proof': 'assets/segmentation_audit.json',
        'exact_rest_proof': proof,
        'constraints': [
            'All colored pixels are copied unchanged from the original sprite; no hidden anatomy has been filled.',
            'The sword and gripping right hand remain one cutout to preserve their exact contact.',
            'Sleeve and trouser meshes share source-space grids and weights; their body and boot/hand overlaps are pinned to the corresponding rigid bones.',
            'The left upper arm is mostly concealed by the cape; a broad overhead block will need a repaired hidden upper arm or a replacement pose.',
            'Large shoulder swings, torso twists and fully crossing legs expose unpainted source occlusions. Begin with restrained actions and inspect those gaps.',
            'Front walk retains the source facing. A separately authored rear sprite is required for rear-facing walking.',
        ],
    }
    (HERE / 'cutout_layout.json').write_text(json.dumps(layout, indent=2) + '\n')
    (OUTPUT / 'reconstruction_proof.json').write_text(json.dumps({
        'source_sha256': layout['source_sha256'], 'visible_source_pixels': _count(alpha),
        'exclusive_base_pixels': {name: _count(mask) for name, mask in base_masks.items()},
        'source_outline_assignments': outline_assignments,
        'source_rgba_preserved': True, 'proof': proof,
    }, indent=2) + '\n')
    print(json.dumps({'parts': len(parts), 'cape_mesh_vertices': len(cape_mesh['vertices']),
                      'visible_source_pixels': _count(alpha), 'proof': proof}, indent=2))


if __name__ == '__main__':
    main()
