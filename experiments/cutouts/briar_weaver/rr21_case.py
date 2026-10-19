"""rr-21 anatomy from mq-09 and the director's humanoid-v2 brief."""
from pathlib import Path
import json

PROJECT = Path(__file__).resolve().parents[3]
CASE = PROJECT / 'experiments/cutouts/briar_weaver/mq9'
ASSETS = PROJECT / 'assets/units/briar_weaver_cutout'
DIRECTOR = PROJECT / 'spec/peer_benchmark/staged/rr-21/motion_tracks.json'
PIECES = {'head': ['head'], 'torso': ['torso'], 'pelvis': ['pelvis'], 'tatters': ['tatters']}
PARENTS = {'root': None, 'pelvis': 'root', 'torso': 'pelvis', 'head': 'torso',
           'tatters_mid': 'pelvis', 'tatters_tip': 'tatters_mid'}
BONES = {'tatters': 'pelvis'}
MESHES = {'tatters': {'kind': 'chain', 'bones': ['pelvis', 'tatters_mid', 'tatters_tip']}}
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
GROUPS = {'upper_body': ['torso', 'head', 'arm_near', 'hand_near', 'arm_far', 'hand_far'],
          'weapon_arm': [], 'lower_body': ['pelvis', 'tatters', 'leg_near', 'leg_far', 'foot_near', 'foot_far']}
PLACEHOLDERS = {}


def write(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2) + '\n')


def initialize():
    upper = ['torso', 'head'] + [n + '_' + s for s in ('near', 'far') for n in ('upper', 'fore', 'hand')]
    lower = [n for n in PARENTS if n not in upper]
    joins = [['head', 'torso'], ['torso', 'pelvis'], ['tatters', 'pelvis']]
    for s in ('near', 'far'):
        joins += [['arm_' + s, 'torso'], ['hand_' + s, 'arm_' + s],
                  ['leg_' + s, 'pelvis'], ['leg_' + s, 'tatters'], ['foot_' + s, 'leg_' + s]]
    tucks = {name: {'depth_px': 3, 'covers': sorted({b if a == name else a for a, b in joins if name in (a, b)}),
                    'mode': 'radial'} for name in PIECES}
    ownership_names = list(PIECES) + [n + '_' + s for s in ('near', 'far') for n in ('upper', 'fore', 'thigh', 'shin')]
    anatomy = {'schema_version': 1, 'required_parents': PARENTS, 'forbidden_joints': ['mantle', 'eye'],
        'meshes': MESHES, 'idle_groups': {
            'upper_body': {'bones': upper, 'stationary': False},
            # No weapon. This stationary reference group deliberately overlaps
            # the lower body; no arm receives the weapon group's lag.
            'weapon_arm': {'bones': ['root'], 'stationary': True},
            'lower_body': {'bones': lower, 'stationary': True}},
        'knee_policy': {'near_straight_deg': 6},
        'legs': {s: {'front': {'bend_side': 1}, 'rear': {'bend_side': -1}} for s in ('near', 'far')},
        'planted_bones': ['foot_near', 'foot_far'], 'planted_tolerance_px': 0.5, 'held_depth_roles': {},
        'ownership': {'names': ownership_names,
            'segments': {n: {'joints': r['joints'], 'owners': r['bones']} for n, r in MESHES.items() if r['kind'] == 'two_segment'},
            'joint_pairs': joins + [[r['bones'][0], r['bones'][1]] for r in MESHES.values() if r['kind'] == 'two_segment'],
            'free_space_owners': []},
        'seam_joins': joins, 'covered_surfaces': {},
        'joint_continuations': {'depth_px': 3, 'bounded_pieces': []},
        'tucks': {'base_px': 3, 'pieces': tucks},
        'integration': {'production_root': 'assets/units/briar_weaver_cutout', 'rig_directory': 'humanoid_v2',
            'production_files': ['rig.gd', 'renderer.gd', 'actions.gd', 'front.json', 'rear.json'],
            'binding_files': ['rig.gd', 'renderer.gd', 'actions.gd'],
            'binding_folders': ['tools/humanoid_cutout', 'scripts/maquette_cutout_runtime', 'tests/rr10', 'tests/rr21'],
            'scale': {'file': 'data/enemies.json', 'key': 'briar_weaver', 'field': 'art_scale', 'default': 1.0},
            'identity_registry': 'spec/art_identity/registry.json', 'identity_id': 'briar_weaver',
            'density_id': 'briar_weaver_cutout', 'owner_approval': 'rr-21 supplied identity-gated mq9 paintings; native proof pending director.',
            'identity_kind': 'creature', 'identity_entry_kind': 'legacy', 'identity_boss': False}}
    write(CASE / 'anatomy.json', anatomy)
    write(CASE / 'inputs.json', {**{v + '_job': 'spec/art_identity/jobs/briar_weaver/mq9_' + v for v in ('front', 'rear')},
        **{v + '_delivery': 'spec/art_identity/maquettes/briar_weaver/delivery' for v in ('front', 'rear')},
        'fused_occlusion': True, 'design_placeholders': PLACEHOLDERS})


if __name__ == '__main__': initialize()
