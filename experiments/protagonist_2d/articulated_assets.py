"""Build fifth-pass rigs from canonical identity cutouts and new complete limbs.

ImageGen owns all new paint. This importer only keys the requested magenta,
crops/scales complete appendages to game pixels, partitions overlaps, and skins
the resulting textures. It does not draw, recolor, or synthesize character paint.
The unchanged pass-four identity assets are explicit, hashed inputs.
"""
from __future__ import annotations

import argparse
import copy
import hashlib
import json
import math
from pathlib import Path

from PIL import Image, ImageDraw

HERE = Path(__file__).resolve().parent
IDENTITY_PARTS = {'head', 'scarf', 'torso', 'hips', 'sword_hand_r'}
# Crops are atlas cells; alpha bounding boxes within them determine exact crops.
# size/offset and landmarks below were authored against the native assembly.
SETUPS = {
    'front': {
        'arm_r': {'box': [40, 100, 360, 790], 'size': [28, 57], 'offset': [82, 91],
                  'joints': [[100, 99], [98, 117], [92, 138]], 'z': [30, 31]},
        'arm_l': {'box': [425, 100, 730, 790], 'size': [28, 66], 'offset': [149, 93],
                  'joints': [[160, 101], [161, 123], [168, 147]], 'z': [30, 51]},
        'leg_r': {'box': [720, 95, 1080, 895], 'size': [31, 63], 'offset': [98, 140],
                  'joints': [[117, 145], [116, 169], [117, 193]], 'z': [10, 12]},
        'leg_l': {'box': [1150, 100, 1440, 905], 'size': [28, 78], 'offset': [133, 145],
                  'joints': [[146, 150], [147, 181], [150, 210]], 'z': [20, 22]},
    },
    'rear': {
        # Atlas columns are assigned to the body side their projected axis fits.
        'arm_r': {'box': [420, 95, 710, 800], 'size': [26, 70], 'offset': [137, 80],
                  'joints': [[147, 89], [148, 113], [154, 141]], 'z': [45, 46]},
        'arm_l': {'box': [25, 95, 340, 800], 'size': [26, 62], 'offset': [80, 85],
                  'joints': [[95, 93], [94, 114], [88, 139]], 'z': [5, 6]},
        'leg_r': {'box': [755, 95, 1070, 910], 'size': [31, 76], 'offset': [124, 147],
                  'joints': [[137, 153], [139, 182], [135, 210]], 'z': [20, 22]},
        'leg_l': {'box': [1125, 95, 1440, 910], 'size': [29, 65], 'offset': [91, 149],
                  'joints': [[104, 155], [106, 179], [103, 203]], 'z': [10, 12]},
    },
}


def digest(path):
    return hashlib.sha256(Path(path).read_bytes()).hexdigest()


def keyed_image(path):
    image = Image.open(path).convert('RGBA')
    pixels = list(image.getdata())
    # The generated matte is magenta with small encoder/model variations.
    # The costume contains no magenta; never key dark contour pixels.
    image.putdata([(0, 0, 0, 0) if r > g + 12 and b > g + 12 else (r, g, b, 255)
                   for r, g, b, _ in pixels])
    return image


def smooth(value):
    v = min(1.0, max(0.0, value))
    return v * v * (3 - 2 * v)


def weights_at(y, joints, names, parent):
    _, middle, end = (point[1] for point in joints)
    arm = names[0].startswith('arm')
    width = 32 if arm and names[0].endswith('r') else (18 if arm else 28)
    terminal_band = 12 if arm else 16
    bend = smooth((y - middle + width / 2) / width)
    distal = smooth((y - end + terminal_band) / terminal_band)
    # Complete rounded proximal ends overlap the body and the new pelvis.
    # They rotate with the upper bone; pinning their entire width to the body
    # would fold the painted shoulder/hip when the limb moves substantially.
    return {parent: 0.0, names[0]: (1 - bend) * (1 - distal),
            names[1]: bend * (1 - distal), names[2]: distal}


def save_crop(image, folder, name, offset, low=0, high=None):
    high = image.height if high is None else high
    cropped = image.crop((0, low, image.width, high))
    box = cropped.getbbox()
    if not box:
        raise ValueError('Empty new art part: ' + name)
    cropped = cropped.crop(box)
    path = folder / (name + '.png')
    cropped.save(path)
    origin = [offset[0] + box[0], offset[1] + low + box[1]]
    return cropped, path, origin


def mesh_for(image, path, origin, setup, names, parent, z, name):
    x0, y0 = origin
    # Common global grid means overlapping pieces have identical deformation.
    xs = sorted(set([x0, x0 + image.width] + list(range((x0 // 3 + 1) * 3, x0 + image.width, 3))))
    ys = sorted(set([y0, y0 + image.height] + list(range(y0 + 1, y0 + image.height))))
    vertices, uvs = [], []
    influences = {bone: [] for bone in [parent, *names]}
    for y in ys:
        for x in xs:
            vertices.append([x, y])
            uvs.append([x - x0, y - y0])
            weights = weights_at(y, setup['joints'], names, parent)
            for bone in influences:
                influences[bone].append(round(weights[bone], 8))
    triangles = []
    for row in range(len(ys) - 1):
        for col in range(len(xs) - 1):
            i = row * len(xs) + col
            triangles.extend([[i, i + 1, i + len(xs) + 1], [i, i + len(xs) + 1, i + len(xs)]])
    return {'name': 'Complete_' + name, 'replaces_part': name,
            'file': str(path.relative_to(HERE)), 'offset': origin,
            'vertices': vertices, 'uvs': uvs, 'triangles': triangles,
            'weights': influences, 'z_index': z, 'complete_anatomy': True,
            'bbox': [x0, y0, x0 + image.width, y0 + image.height],
            'family': ('arm_' if names[0].startswith('arm') else 'leg_') + name,
            'coordinate_space': 'global source pixels, crop-local UV pixels',
            'attachment': {'parent': parent, 'chain': names, 'joints': setup['joints']}}


def build(facing):
    suffix = '' if facing == 'front' else '_rear'
    baseline_path = HERE / f'references/pass5/baseline_cutout_layout{suffix}.json'
    layout = json.loads(baseline_path.read_text())
    baseline = copy.deepcopy(layout)
    for legacy in ['source_only_joint_overlaps', 'source_outline_assignments', 'semantic_ownership_proof', 'exact_rest_proof', 'constraints']:
        layout.pop(legacy, None)
    layout['legacy_identity_partition_reference'] = str(baseline_path.relative_to(HERE))
    folder = HERE / 'assets/pass5' / facing
    folder.mkdir(parents=True, exist_ok=True)
    source = keyed_image(HERE / f'references/pass5/{facing}_limbs_keyed.png')
    parts = [copy.deepcopy(p) for p in layout['parts'] if p['name'] in IDENTITY_PARTS]
    # The existing cape owns its own complete texture; no rigid cape duplicates.
    layout['cape_mesh']['z_index'] = 48 if facing == 'front' else 60
    meshes, imports = [], []
    for limb, setup in SETUPS[facing].items():
        arm = limb.startswith('arm')
        side = limb[-1]
        names = [f'arm_{side}', f'forearm_{side}', f'hand_{side}'] if arm else [f'thigh_{side}', f'shin_{side}', f'foot_{side}']
        parent = 'torso' if arm else 'hips'
        for bone, point in zip(names, setup['joints']):
            layout['joints'][bone]['position'] = point
            layout['joints'][bone].pop('fully_occluded', None)
        crop = source.crop(setup['box'])
        alpha_box = crop.getbbox()
        crop = crop.crop(alpha_box).resize(setup['size'], Image.Resampling.NEAREST)
        crop.save(folder / (limb + '_complete.png'))
        offset = setup['offset']
        middle_y = setup['joints'][1][1] - offset[1]
        end_y = setup['joints'][2][1] - offset[1]
        # Overlap is authored from complete painted material, not stretched edge
        # pixels. Pin the distal collar to its glove/boot transform.
        divisions = [(names[0], 0, end_y + 3, setup['z'][0])]
        if arm:
            divisions = [(names[0], 0, middle_y + 6, setup['z'][0]),
                         (names[1], middle_y + 2, end_y + 3, setup['z'][1])]
        for name, low, high, z in divisions:
            image, path, origin = save_crop(crop, folder, name, offset, low, high)
            parts.append({'name': name, 'file': str(path.relative_to(HERE)), 'offset': origin, 'bone': names[0], 'z_index': z})
            meshes.append(mesh_for(image, path, origin, setup, names, parent, z, name))
        name = names[2]
        image, path, origin = save_crop(crop, folder, name, offset, end_y)
        z = setup['z'][1] if not arm else ((62 if side == 'r' else 52) if facing == 'front' else (66 if side == 'r' else 7))
        parts.append({'name': name, 'file': str(path.relative_to(HERE)), 'offset': origin, 'bone': name, 'z_index': z})
        imports.append({'name': limb, 'atlas_cell': setup['box'], 'tight_crop_in_cell': list(alpha_box),
                        'native_size': setup['size'], 'offset': offset, 'joints': setup['joints']})
    # A full pelvis now exists behind the belt/flaps and rotating thigh caps.
    pelvis_source = keyed_image(HERE / 'references/pass5/pelvis_keyed.png')
    cell = [100, 250, 710, 770] if facing == 'front' else [820, 250, 1430, 770]
    pelvis = pelvis_source.crop(cell)
    pelvis = pelvis.crop(pelvis.getbbox()).resize((56, 32) if facing == 'front' else (59, 30), Image.Resampling.NEAREST)
    pelvis.save(folder / 'pelvis_underlay.png')
    parts.append({'name': 'pelvis_underlay', 'file': str((folder / 'pelvis_underlay.png').relative_to(HERE)),
                  'offset': [103, 126] if facing == 'front' else [92, 132], 'bone': 'hips', 'z_index': 9})
    # Keep the canonical chipped blade, but separate it from the old painted
    # hand. The new fist can follow its forearm while the sword pivots in its
    # grip. A compound hand+blade formerly forced a large wrist texture fold.
    sword = next(p for p in parts if p['name'] == 'sword_hand_r')
    parts.remove(sword)
    weapon = Image.new('RGBA', (255, 255))
    weapon.alpha_composite(Image.open(HERE / sword['file']).convert('RGBA'), sword['offset'])
    for y in range(255):
        for x in range(255):
            is_old_hand = (x >= 88 and y <= x + 39 and y < 139) if facing == 'front' else (x < 178 and y < 160)
            if is_old_hand:
                weapon.putpixel((x, y), (0, 0, 0, 0))
    old_grip = [95, 128] if facing == 'front' else [167, 147]
    new_grip = [90, 143] if facing == 'front' else [156, 145]
    box = weapon.getbbox()
    weapon.crop(box).save(folder / 'weapon_r.png')
    weapon_offset = [box[i] + new_grip[i] - old_grip[i] for i in range(2)]
    layout['joints']['weapon_r'] = {'parent': 'hand_r', 'position': new_grip}
    parts.append({'name': 'weapon_r', 'file': str((folder / 'weapon_r.png').relative_to(HERE)),
                  'offset': weapon_offset, 'bone': 'weapon_r', 'z_index': 61 if facing == 'front' else 65})
    # Newly painted narrow shaft restores material formerly hidden by the old
    # fist. It crosses the guard and passes through the new grip pivot.
    handle = Image.open(HERE / 'references/pass5/grip_rgba.png').convert('RGBA')
    tight = handle.getchannel('A').point(lambda a: 255 if a >= 128 else 0).getbbox()
    handle = handle.crop(tight).resize((4, 18), Image.Resampling.NEAREST)
    guard = [82, 148] if facing == 'front' else [166, 156]
    angle = math.degrees(math.atan2(guard[1] - new_grip[1], guard[0] - new_grip[0]))
    handle = handle.rotate(90 - angle, Image.Resampling.NEAREST, expand=True)
    handle.save(folder / 'grip_r.png')
    center = [(guard[i] + new_grip[i]) / 2 for i in range(2)]
    grip_offset = [round(center[i] - handle.size[i] / 2) for i in range(2)]
    parts.append({'name': 'grip_r', 'file': str((folder / 'grip_r.png').relative_to(HERE)),
                  'offset': grip_offset, 'bone': 'weapon_r', 'z_index': 60 if facing == 'front' else 64})
    layout['weapon_grip'] = {'source': old_grip, 'assembled': new_grip,
                             'tip': [13 + new_grip[0] - old_grip[0], 190 + new_grip[1] - old_grip[1]] if facing == 'front' else
                                    [249 + new_grip[0] - old_grip[0], 216 + new_grip[1] - old_grip[1]]}
    # Keep both identity comparison and the new assembly target explicit.
    layout.update({'version': 5, 'parts': parts, 'joint_meshes': meshes,
                   'source': baseline['source'], 'identity_source': baseline['source'],
                   'rest_source': f'references/pass5/{facing}_assembled_rest.png',
                   'art_imports': imports, 'new_complete_anatomy': True,
                   'notes': ['Canonical head/scarf/body/belt/cloak and chipped blade retained; complete limbs, hidden pelvis and grip shaft generated for this revision.',
                             'The canonical static image is an identity comparison, not a claim of identical rest RGBA.']})
    # Stable independent neutral composite for the actual-renderer check.
    composite = Image.new('RGBA', (255, 255))
    layers = [(p['z_index'], p['file'], p['offset']) for p in parts]
    cape = layout['cape_mesh']
    layers.append((cape['z_index'], cape['file'], cape['offset']))
    for _, path, offset in sorted(layers, key=lambda entry: entry[0]):
        composite.alpha_composite(Image.open(HERE / path).convert('RGBA'), offset)
    composite.save(HERE / layout['rest_source'])
    layout['rest_source_sha256'] = digest(HERE / layout['rest_source'])
    output = HERE / f'cutout_layout{suffix}.json'
    output.write_text(json.dumps(layout, indent=2) + '\n')
    return layout


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--facing', choices=['front', 'rear', 'both'], default='both')
    args = parser.parse_args()
    layouts = {facing: build(facing) for facing in (['front', 'rear'] if args.facing == 'both' else [args.facing])}
    if len(layouts) == 2:
        sheet = Image.new('RGBA', (1020, 1040), (48, 50, 53, 255))
        draw = ImageDraw.Draw(sheet)
        for row, (facing, layout) in enumerate(layouts.items()):
            for column, name in enumerate(['identity_source', 'rest_source']):
                image = Image.open(HERE / layout[name]).convert('RGBA').resize((510, 510), Image.Resampling.NEAREST)
                sheet.alpha_composite(image, (column * 510, row * 520 + 10))
            draw.text((6, row * 520), facing + ' identity / new complete-limb assembly', fill='white')
        sheet.convert('RGB').save(HERE / 'references/pass5/assembly_review.png')
    print('Fifth-pass articulated assets: ' + ', '.join(layouts))


if __name__ == '__main__':
    main()
