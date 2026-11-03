"""rr-32 anatomy from mq-12 and the director's humanoid-v2 brief."""
from pathlib import Path
import json

PROJECT = Path(__file__).resolve().parents[3]
CASE = PROJECT / 'experiments/cutouts/gale_herald/mq12'
ASSETS = PROJECT / 'assets/units/gale_herald_cutout'
DIRECTOR = PROJECT / 'spec/peer_benchmark/staged/rr-32/motion_tracks.json'
PIECES = {'head': ['head'], 'torso': ['belt'], 'pelvis': ['torso'], 'tabard': ['tabard'],
          'cape_near': ['cape_near'], 'cape_far': ['cape_far'], 'horn': ['horn']}
PARENTS = {'root': None, 'pelvis': 'root', 'torso': 'pelvis', 'head': 'torso',
           'horn': 'hand_far'}
BONES = {}
MESHES = {}
for piece, parent in [('tabard', 'pelvis'), ('cape_near', 'torso'), ('cape_far', 'torso')]:
    PARENTS[piece + '_mid'] = parent
    PARENTS[piece + '_tip'] = piece + '_mid'
    BONES[piece] = parent
    MESHES[piece] = {'kind': 'chain', 'bones': [parent, piece + '_mid', piece + '_tip']}
for side in ('near', 'far'):
    PIECES.update({'arm_' + side: ['upper_' + side, 'fore_' + side],
                   'hand_' + side: ['hand_' + side],
                   'leg_' + side: ['thigh_' + side, 'shin_' + side], 'foot_' + side: ['foot_' + side]})
    PARENTS.update({'upper_' + side: 'torso', 'fore_' + side: 'upper_' + side,
                    'hand_' + side: 'fore_' + side, 'thigh_' + side: 'pelvis',
                    'shin_' + side: 'thigh_' + side, 'foot_' + side: 'shin_' + side})
    BONES.update({'arm_' + side: 'upper_' + side, 'leg_' + side: 'thigh_' + side})
    for name, chain in [('arm_' + side, ['upper_' + side, 'fore_' + side, 'hand_' + side]),
                        ('leg_' + side, ['thigh_' + side, 'shin_' + side, 'foot_' + side])]:
        # The reference rr-10/rr-11 source-space weight field, unchanged.
        MESHES[name] = {'kind': 'two_segment', 'joints': chain, 'bones': chain[:2],
                        'cuff_rows_px': 4, 'blend_half_width_px': 4}
GROUPS = {'upper_body': ['torso', 'head', 'arm_near', 'hand_near', 'cape_near', 'cape_far'],
          'weapon_arm': ['arm_far', 'hand_far', 'horn'],
          'lower_body': ['pelvis', 'tabard', 'leg_near', 'leg_far', 'foot_near', 'foot_far']}
# Director feedback 1: Gust Bolt drives the horn through the torso; the
# remaining positive action directions use hand targets. Coverage still spans
# every action, including movement, hit and death.
ACTION_DIRECTION_CLIPS = ('move', 'call_the_wind', 'gust_bolt', 'still_air', 'hit', 'death')
HAND_DIRECTION_CLIPS = [clip for clip in ACTION_DIRECTION_CLIPS if clip != 'gust_bolt']
BODY_DIRECTION_CLIPS = {'gust_bolt': 'torso'}
PLACEHOLDERS = {}


def write(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2) + '\n')


def initialize():
    upper = ['torso', 'head', 'upper_near', 'fore_near', 'hand_near',
             'cape_near_mid', 'cape_near_tip', 'cape_far_mid', 'cape_far_tip']
    weapon = ['upper_far', 'fore_far', 'hand_far', 'horn']
    lower = [n for n in PARENTS if n not in upper + weapon]
    joins = [['head', 'torso'], ['torso', 'pelvis'], ['tabard', 'pelvis'],
             ['cape_near', 'torso'], ['cape_far', 'torso'], ['horn', 'hand_far']]
    for s in ('near', 'far'):
        joins += [['arm_' + s, 'torso'], ['hand_' + s, 'arm_' + s],
                  ['leg_' + s, 'pelvis'], ['leg_' + s, 'tabard'], ['foot_' + s, 'leg_' + s]]
    tucks = {name: {'depth_px': 3, 'covers': sorted({b if a == name else a for a, b in joins if name in (a, b)}),
                    'mode': 'radial'} for name in PIECES}
    ownership_names = list(PIECES) + [n + '_' + s for s in ('near', 'far') for n in ('upper', 'fore', 'thigh', 'shin')]
    anatomy = {'schema_version': 1, 'required_parents': PARENTS, 'forbidden_joints': ['belt', 'mask'],
        'meshes': MESHES, 'idle_groups': {
            'upper_body': {'bones': upper, 'stationary': False},
            'weapon_arm': {'bones': weapon, 'stationary': False},
            'lower_body': {'bones': lower, 'stationary': True}},
        'knee_policy': {'near_straight_deg': 6},
        'legs': {s: {'front': {'bend_side': -1}, 'rear': {'bend_side': 1}} for s in ('near', 'far')},
        'planted_bones': ['foot_near', 'foot_far'], 'planted_tolerance_px': 0.5, 'held_depth_roles': {},
        'ownership': {'names': ownership_names,
            'segments': {n: {'joints': r['joints'], 'owners': r['bones']} for n, r in MESHES.items() if r['kind'] == 'two_segment'},
            'joint_pairs': joins + [[r['bones'][0], r['bones'][1]] for r in MESHES.values() if r['kind'] == 'two_segment'],
            'free_space_owners': []},
        'seam_joins': joins, 'covered_surfaces': {},
        'joint_continuations': {'depth_px': 3, 'bounded_pieces': []},
        'tucks': {'base_px': 3, 'pieces': tucks},
        'integration': {'production_root': 'assets/units/gale_herald_cutout', 'rig_directory': 'humanoid_v2',
            'production_files': ['rig.gd', 'renderer.gd', 'front.json', 'rear.json'],
            'binding_files': ['rig.gd', 'renderer.gd'],
            'binding_folders': ['tools/humanoid_cutout', 'scripts/maquette_cutout_runtime', 'tests/rr10', 'tests/rr11', 'tests/rr32'],
            'scale': {'file': 'data/enemies.json', 'key': 'gale_herald', 'field': 'art_scale', 'default': 1.0},
            'identity_registry': 'spec/art_identity/registry.json', 'identity_id': 'gale_herald',
            'density_id': 'gale_herald_cutout', 'owner_approval': 'rr-32 supplied identity-gated mq12 paintings; native proof pending director.',
            'identity_kind': 'creature', 'identity_entry_kind': 'legacy', 'identity_boss': False}}
    write(CASE / 'anatomy.json', anatomy)
    write(CASE / 'inputs.json', {**{v + '_job': 'spec/art_identity/jobs/gale_herald/mq12_' + v for v in ('front', 'rear')},
        **{v + '_delivery': 'spec/art_identity/maquettes/gale_herald/delivery' for v in ('front', 'rear')},
        'fused_occlusion': True, 'design_placeholders': PLACEHOLDERS})


if __name__ == '__main__': initialize()
