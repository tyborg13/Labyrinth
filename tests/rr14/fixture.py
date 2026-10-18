"""Tiny diagnostic textures and anatomy, never production art or tuning."""
import json
from pathlib import Path

from PIL import Image

from humanoid_cutout.compiler import compile_motion
from humanoid_cutout.materials import held_depths
from humanoid_cutout.skin_layers import layer

FIXTURE_RGBA = (80, 100, 120, 255)
FIXTURE_TEXTURE_SIZE = (2, 4)
FIXTURE_CANVAS_SIZE = (255, 255)
FIXTURE_SECONDS = 1.0
FIXTURE_WEIGHT_BLEND_PX = 1
FIXTURE_FLOOR_END = (28, 19)
FIXTURE_PROJECTION = {'front': {'forward': [1., 0.], 'lean_sign': 1}}


def write(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, indent=2) + '\n')


def build(case, item='tube'):
    case = Path(case)
    joints = {}
    def joint(name, position, parent):
        joints[name] = {'position': position, 'parent': parent}
    joint('root', [16, 32], None)
    joint('pelvis', [16, 18], 'root')
    joint('torso', [16, 10], 'pelvis')
    joint('head', [16, 5], 'torso')
    for side, x, bend in [('near', 20, 3), ('far', 10, -3)]:
        joint('thigh_' + side, [x, 20], 'pelvis')
        joint('shin_' + side, [x + bend, 24], 'thigh_' + side)
        joint('foot_' + side, [x, 28], 'shin_' + side)
    for side, points, target in [('near', [[20, 9], [24, 12], [28, 15]], 'tube_tip'),
                                 ('far', [[12, 8], [9, 12], [6, 16]], 'claw')]:
        joint('upper_' + side, points[0], 'torso')
        joint('fore_' + side, points[1], 'upper_' + side)
        joint(target, points[2], 'fore_' + side)
    joint(item, [28, 15], 'tube_tip')
    joint('loincloth', [16, 18], 'pelvis')
    joint('loincloth_mid', [16, 23], 'loincloth')
    joint('loincloth_tip', [16, 27], 'loincloth_mid')
    meshes = {}
    for name, chain in [('arm_near', ['upper_near', 'fore_near', 'tube_tip']),
                        ('arm_far', ['upper_far', 'fore_far', 'claw']),
                        ('leg_near', ['thigh_near', 'shin_near', 'foot_near']),
                        ('leg_far', ['thigh_far', 'shin_far', 'foot_far'])]:
        meshes[name] = {'kind': 'two_segment', 'joints': chain, 'bones': chain[:2],
                        'cuff_rows_px': 0, 'blend_half_width_px': FIXTURE_WEIGHT_BLEND_PX}
    meshes['loincloth'] = {'kind': 'chain', 'bones': ['loincloth', 'loincloth_mid', 'loincloth_tip']}
    groups = {
        'upper_body': {'bones': ['torso', 'head', 'upper_far', 'fore_far', 'claw'], 'stationary': False},
        'weapon_arm': {'bones': ['upper_near', 'fore_near', 'tube_tip', item], 'stationary': False},
        'lower_body': {'bones': ['root', 'pelvis', 'thigh_near', 'shin_near', 'foot_near',
                                  'thigh_far', 'shin_far', 'foot_far', 'loincloth', 'loincloth_mid',
                                  'loincloth_tip'], 'stationary': True}}
    body = ['torso', 'arm_near', 'arm_far', 'leg_near', 'leg_far', 'loincloth']
    roles = {item: {'body': body, 'grip': None, 'policy': {'front': 'in_front_of_body'}}}
    names = ['head', 'torso', 'upper_near', 'fore_near', 'upper_far', 'fore_far',
             'thigh_near', 'shin_near', 'thigh_far', 'shin_far', 'foot_near', 'foot_far',
             item, 'claw', 'loincloth']
    ownership = {'names': names, 'segments': {n: {'joints': r['joints'], 'owners': r['bones']}
                 for n, r in meshes.items() if r['kind'] == 'two_segment'},
                 'joint_pairs': [['torso', 'head'], ['torso', 'loincloth'], ['fore_far', 'claw']] +
                    [[a, b] for r in meshes.values() if r['kind'] == 'two_segment'
                     for a, b in zip(r['joints'], r['joints'][1:]) if b in names],
                 'free_space_owners': [item]}
    anatomy = {'schema_version': 1, 'required_parents': {n: j['parent'] for n, j in joints.items()},
               'forbidden_joints': [], 'meshes': meshes, 'idle_groups': groups,
               'planted_bones': ['foot_near', 'foot_far'], 'held_depth_roles': roles,
               'ownership': ownership, 'seam_joins': [['head', 'torso']],
               'covered_surfaces': {}, 'joint_continuations': {'depth_px': 0, 'bounded_pieces': []},
               'tucks': {'base_px': 0, 'pieces': {}},
               'integration': {'binding_folders': ['tools/humanoid_cutout', 'scripts/maquette_cutout_runtime'],
                               'production_root': None,
                               'rig_directory': 'unused_production', 'binding_files': []}}
    write(case / 'anatomy.json', anatomy)
    parts, layers, skinned = [], {}, []
    attachments = {'head': 'head', 'torso': 'torso', 'arm_near': 'upper_near',
                   'arm_far': 'upper_far', 'leg_near': 'thigh_near', 'leg_far': 'thigh_far',
                   'foot_near': 'foot_near', 'foot_far': 'foot_far', item: item,
                   'claw': 'claw', 'loincloth': 'loincloth'}
    depths = held_depths({n: i for i, n in enumerate(attachments)}, 'front', roles)
    rest = Image.new('RGBA', FIXTURE_CANVAS_SIZE)
    for name, bone in attachments.items():
        x, y = joints[bone]['position']
        w, h = FIXTURE_TEXTURE_SIZE
        if name in meshes:
            recipe = meshes[name]
            points = [joints[n]['position'] for n in recipe.get('joints', recipe['bones'])]
            x, y = min(p[0] for p in points), min(p[1] for p in points)
            w += max(p[0] for p in points) - x
            h += max(p[1] for p in points) - y
        texture = Image.new('RGBA', (w, h), FIXTURE_RGBA)
        texture_path = case / 'pieces' / (name + '.png')
        texture_path.parent.mkdir(parents=True, exist_ok=True)
        texture.save(texture_path)
        part = {'name': name, 'bone': bone, 'file': str(texture_path.relative_to(case)),
                'logical_part': name, 'offset': [x, y], 'bbox': [x, y, x+w, y+h], 'z_index': depths[name]}
        parts.append(part)
        if name in meshes:
            skinned.append(layer(part, name, part['bbox'], joints, depths[name], recipe=meshes[name]))
        mask = case / 'checks' / (name + '.png')
        mask.parent.mkdir(parents=True, exist_ok=True)
        Image.new('RGBA', (w, h), (255, 0, 0, 255)).save(mask)
        layers[name] = {'mask': str(mask.relative_to(case)), 'mask_offset': [x, y]}
    for part in sorted(parts, key=lambda p: p['z_index']):
        rest.alpha_composite(Image.open(case / part['file']), tuple(part['offset']))
    rest.save(case / 'rest.png')
    layout = {'version': 2, 'rig': 'humanoid_v2', 'facing': 'front', 'canvas_size': list(FIXTURE_CANVAS_SIZE),
              'joints': joints, 'parts': parts, 'joint_meshes': skinned, 'proof_layers': layers,
              'rest_source': 'rest.png', 'features': [],
              'idle_groups': {'upper_body': ['torso', 'head', 'arm_far', 'claw'],
                              'weapon_arm': ['arm_near', item],
                              'lower_body': ['leg_near', 'leg_far', 'foot_near', 'foot_far', 'loincloth']},
              'held_items': {item: {'hand': 'tube_tip', 'floor_end': list(FIXTURE_FLOOR_END)}},
              'ik_chains': [{'first': 'upper_near', 'second': 'fore_near', 'target': 'tube_tip'},
                            {'first': 'upper_far', 'second': 'fore_far', 'target': 'claw'}],
              'motion_data': str(case / 'compiled_motion.json')}
    write(case / 'layouts/front.json', layout)
    # Diagnostic channels explicitly counter the pelvis dip to plant the
    # stance ankle, then lift the swing ankle four pixels above that floor.
    keys = {'pelvis.lift_px': [[0, -2], [1, -2]],
            'foot_near.lift_px': [[0, 2], [.5, 6], [1, 2]],
            'foot_far.lift_px': [[0, 2], [.5, 6], [1, 2]],
            'foot_near.forward_px': [[0, 0], [.5, 2], [1, 0]],
            'foot_far.forward_px': [[0, 0], [.5, 2], [1, 0]],
            'tube_tip.lift_px': [[0, 0], [.5, 1], [1, 0]],
            'claw.lift_px': [[0, 0], [.5, 1], [1, 0]]}
    source = {'synthetic_humanoid': {'rig': 'humanoid_v2', 'units': 'source_px',
               'clips': {'idle': {'seconds': FIXTURE_SECONDS, 'loop': True, 'keys': {}},
                         'move': {'seconds': FIXTURE_SECONDS, 'loop': True, 'keys': keys}}}}
    write(case / 'director_motion.json', source)
    compiled = compile_motion(case / 'director_motion.json', 'synthetic_humanoid', {'front': layout}, FIXTURE_PROJECTION)
    write(case / 'compiled_motion.json', compiled)
    return layout, anatomy, {'front_rest_mismatch_pixels': 0, 'tucks': []}, compiled


if __name__ == '__main__':
    import argparse
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    build(args.output.resolve())
    print('RR14 SYNTHETIC CASE: ' + str(args.output.resolve()))
