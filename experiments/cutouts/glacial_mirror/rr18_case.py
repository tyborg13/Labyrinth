"""rr-18's rigid-boulder anatomy, using only director-owned source geometry."""
from pathlib import Path
import sys

PROJECT = Path(__file__).resolve().parents[3]
CASE = PROJECT / 'experiments/cutouts/glacial_mirror/rr18'
ASSETS = PROJECT / 'assets/units/glacial_mirror_cutout'
DIRECTOR = PROJECT / 'spec/peer_benchmark/staged/rr-18/motion_tracks.json'
sys.path[:0] = [str(PROJECT), str(PROJECT / 'tools')]
from cutout_pipeline.cases import write_json

PIECES = {n: [n] for n in ('head', 'torso', 'pelvis')}
BONES = {}
PARENTS = {'root': None, 'pelvis': 'root', 'torso': 'pelvis', 'head': 'torso'}
JOINS = [['head', 'torso'], ['torso', 'pelvis']]
for side in ('near', 'far'):
    for piece, source, bone, parent in (
        ('upper_', 'upper_', 'upper_', 'torso'), ('fore_', 'fore_', 'fore_', 'upper_' + side),
        ('fist_', 'hand_', 'hand_', 'fore_' + side), ('thigh_', 'thigh_', 'thigh_', 'pelvis'),
        ('shin_', 'shin_', 'shin_', 'thigh_' + side), ('foot_', 'foot_', 'foot_', 'shin_' + side)):
        PIECES[piece + side] = [source + side]
        BONES[piece + side] = bone + side
        PARENTS[bone + side] = parent
    JOINS += [['torso', 'upper_' + side], ['upper_' + side, 'fore_' + side],
              ['fore_' + side, 'fist_' + side], ['pelvis', 'thigh_' + side],
              ['thigh_' + side, 'shin_' + side], ['shin_' + side, 'foot_' + side]]
GROUPS = {'upper_body': ['torso', 'head'] + [p + s for s in ('near', 'far') for p in ('upper_', 'fore_', 'fist_')],
          'weapon_arm': [],  # No weapon: empty painted group; root is its stationary proof anchor.
 'lower_body': ['pelvis'] + [p + s for s in ('near', 'far') for p in ('thigh_', 'shin_', 'foot_')]}


def initialize():
    adjacency = {n: [b if a == n else a for a, b in JOINS if n in (a, b)] for n in PIECES}
    anatomy = {'schema_version': 1, 'required_parents': PARENTS, 'forbidden_joints': [], 'meshes': {},
        'idle_groups': {group: {'bones': (['root'] if group in ('lower_body', 'weapon_arm') else []) + [BONES.get(n,n) for n in parts],
                                'stationary': group != 'upper_body'} for group, parts in GROUPS.items()},
        'knee_policy': {'near_straight_deg': 6},
        'legs': {'near': {'front': {'bend_side': -1}, 'rear': {'bend_side': 1}},
                 'far': {'front': {'bend_side': 1}, 'rear': {'bend_side': -1}}},
        'leg_roles': {'front': {'stride': 'near', 'trailing': 'far'}, 'rear': {'stride': 'far', 'trailing': 'near'}},
        'planted_bones': ['foot_near', 'foot_far'], 'planted_tolerance_px': 0.5, 'held_depth_roles': {},
        'ownership': {'names': list(PIECES), 'segments': {}, 'joint_pairs': JOINS, 'free_space_owners': []},
        'seam_joins': JOINS, 'covered_surfaces': {}, 'joint_continuations': {'depth_px': 3, 'bounded_pieces': []},
        'tucks': {'base_px': 3, 'pieces': {n: {'depth_px': 3, 'covers': adjacency[n], 'mode': 'radial'} for n in PIECES}},
        'integration': {'production_root': 'assets/units/glacial_mirror_cutout', 'rig_directory': 'humanoid_v2',
            'production_files': ['rig.gd', 'renderer.gd', 'front.json', 'rear.json', 'actions.gd'], 'binding_files': ['rig.gd', 'renderer.gd', 'actions.gd'],
            'binding_folders': ['tools/humanoid_cutout', 'scripts', 'tests/rr10', 'tests/rr18'],
            'scale': {'file': 'data/enemies.json', 'key': 'glacial_mirror', 'field': 'art_scale', 'default': 1.0},
            'identity_registry': 'spec/art_identity/registry.json', 'identity_id': 'glacial_mirror',
            'density_id': 'glacial_mirror_cutout', 'owner_approval': 'rr-18 director-approved mq8 paintings; native cutout proof pending director.',
            'identity_kind': 'creature', 'identity_entry_kind': 'legacy', 'identity_boss': False}}
    write_json(CASE / 'anatomy.json', anatomy)
    write_json(CASE / 'inputs.json', {**{v + '_job': 'spec/art_identity/jobs/glacial_mirror/mq8_' + v for v in ('front','rear')},
        **{v + '_delivery': 'spec/art_identity/maquettes/glacial_mirror/delivery' for v in ('front','rear')}, 'design_placeholders': {'TODO_DESIGN_density_rest_identity': 'Required density processing changes 1178 front and 15491 rear production rest pixels against the approved paintings. The source cuts remain 0 px exact. Director must resolve density treatment versus the brief production rest-identity requirement.',
        'TODO_DESIGN_move_supports': 'Protected world_step paths exceed the unchanged leg reach; front support error reaches 5.545222 px, rear 19.416488 px at the reference proof step; stance slides up to 1.414214 px. Director motion decision required.',
        'TODO_DESIGN_move_swing_apex': 'Front stride and rear trailing swing knees bend less than their stance knees at their lift apex. Protected keys retained; director motion decision required.',
        'TODO_DESIGN_near_knee_facing': 'mq8 near-leg rest bends are 8.998 degrees away from front facing and 9.537 degrees away from rear facing; preserving rest bend side conflicts with the facing gate. Director joint/policy decision required.'}})

if __name__ == '__main__': initialize()
