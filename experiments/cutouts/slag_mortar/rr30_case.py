"""rr-30 anatomy from the supplied mq-11 landmarks and humanoid v2 contract."""
from pathlib import Path
import sys

PROJECT = Path(__file__).resolve().parents[3]
sys.path[:0] = [str(PROJECT), str(PROJECT / 'tools')]
from cutout_pipeline.cases import write_json

CASE = PROJECT / 'experiments/cutouts/slag_mortar/rr30'
ASSETS = PROJECT / 'assets/units/slag_mortar_cutout'
DIRECTOR = PROJECT / 'spec/peer_benchmark/staged/rr-31/motion_tracks.json'
DESIGN_PLACEHOLDERS = {}
PIECES = {name: [name] for name in ('head', 'torso', 'mortar', 'pelvis',
    'belt', 'flap', 'bracer_near', 'bracer_far')}
BONES = {'belt': 'belt', 'bracer_near': 'fore_near', 'bracer_far': 'fore_far'}
PARENTS = {'root': None, 'pelvis': 'root', 'torso': 'pelvis', 'head': 'torso',
           'mortar': 'torso', 'belt': 'pelvis', 'flap': 'belt'}
MESHES = {}
for side in ('near', 'far'):
    for name, parent in [('upper', 'torso'), ('fore', 'upper_' + side),
                         ('hand', 'fore_' + side), ('thigh', 'pelvis'),
                         ('shin', 'thigh_' + side), ('foot', 'shin_' + side)]:
        piece = name + '_' + side
        PIECES[piece] = [piece]
        PARENTS[piece] = parent
GROUPS = {'upper_body': ['torso', 'head'] + [name + '_' + side
              for side in ('near', 'far') for name in ('upper', 'fore', 'hand', 'bracer')],
          'weapon_arm': ['mortar'],
          'lower_body': ['pelvis', 'belt', 'flap'] + [name + '_' + side
              for side in ('near', 'far') for name in ('thigh', 'shin', 'foot')]}


def initialize():
    joins = [['head', 'torso'], ['mortar', 'torso'], ['torso', 'pelvis'], ['belt', 'pelvis'], ['flap', 'belt']]
    for side in ('near', 'far'):
        joins += [['torso', 'upper_' + side], ['upper_' + side, 'fore_' + side],
                  ['fore_' + side, 'hand_' + side], ['fore_' + side, 'bracer_' + side],
                  ['bracer_' + side, 'hand_' + side],
                  ['pelvis', 'thigh_' + side], ['thigh_' + side, 'shin_' + side],
                  ['shin_' + side, 'foot_' + side]]
    tucks = {name: {'depth_px': 3, 'covers': sorted({other for pair in joins if name in pair
              for other in pair if other != name}), 'mode': 'radial'} for name in PIECES}
    # The pot's lower surface is occluded by the shoulders/head as well as the
    # torso. Its covered material must come from its own crucible edge paint.
    tucks['mortar']['covers'] = ['torso', 'head', 'upper_near', 'upper_far']
    anatomy = {'schema_version': 1, 'required_parents': PARENTS, 'forbidden_joints': [],
        'meshes': MESHES,
        # Both arms are free. The schema's historical weapon_arm slot is the
        # torso-carried mortar; it has exactly the upper body's bob, no lag.
        'idle_groups': {'upper_body': {'bones': ['torso', 'head', 'upper_near', 'fore_near', 'hand_near',
                                               'upper_far', 'fore_far', 'hand_far'], 'stationary': False},
                        'weapon_arm': {'bones': ['mortar'], 'stationary': False},
                        'lower_body': {'bones': ['root', 'pelvis', 'belt', 'flap', 'thigh_near',
                            'shin_near', 'foot_near', 'thigh_far', 'shin_far', 'foot_far'], 'stationary': True}},
        'knee_policy': {'near_straight_deg': 6},
        'legs': {s: {'front': {'bend_side': 1}, 'rear': {'bend_side': -1}} for s in ('near', 'far')},
        'planted_bones': ['foot_near', 'foot_far'], 'planted_tolerance_px': 0.5,
        'held_depth_roles': {},
        'ownership': {'names': list(PIECES) + [n for r in MESHES.values() if r['kind'] == 'two_segment' for n in r['bones']],
            'segments': {n: {'joints': r['joints'], 'owners': r['bones']} for n, r in MESHES.items() if r['kind'] == 'two_segment'},
            'joint_pairs': joins, 'free_space_owners': ['mortar']},
        'seam_policy': 'air_between_rigid_pieces', 'seam_protected_pieces': ['torso'],
        'seam_joins': joins, 'covered_surfaces': {},
        'joint_continuations': {'depth_px': 3, 'bounded_pieces': []},
        'tucks': {'base_px': 3, 'pieces': tucks},
        'integration': {'production_root': str(ASSETS.relative_to(PROJECT)), 'rig_directory': 'humanoid_v2',
            'production_files': ['rig.gd', 'renderer.gd', 'actions.gd', 'front.json', 'rear.json'],
            'binding_files': ['rig.gd', 'renderer.gd', 'actions.gd'],
            'binding_folders': ['tools/humanoid_cutout', 'scripts/maquette_cutout_runtime', 'tests/rr10', 'tests/rr11', 'tests/rr30', 'tests/rr31', 'tests/gait01'],
            'scale': {'file': 'data/enemies.json', 'key': 'slag_mortar', 'field': 'art_scale', 'default': 1.0},
            'identity_registry': 'spec/art_identity/registry.json', 'identity_id': 'slag_mortar',
            'density_id': 'slag_mortar_cutout', 'owner_approval': 'rr-30 supplied mq11 paintings; native proof pending director.',
            'identity_kind': 'creature', 'identity_entry_kind': 'legacy', 'identity_boss': False}}
    write_json(CASE / 'anatomy.json', anatomy)
    write_json(CASE / 'inputs.json', {**{v + '_job': 'spec/art_identity/jobs/slag_mortar/mq11_' + v for v in ('front', 'rear')},
        **{v + '_delivery': 'tests/mq11_proof/director_08/slag_mortar/capture' for v in ('front', 'rear')},
        'fused_occlusion': True, 'design_placeholders': DESIGN_PLACEHOLDERS})



if __name__ == '__main__': initialize()
