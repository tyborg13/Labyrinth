"""rr-22 anatomy from the supplied mq-09 landmarks and humanoid v2 contract."""
from pathlib import Path
import sys

PROJECT = Path(__file__).resolve().parents[3]
sys.path[:0] = [str(PROJECT), str(PROJECT / 'tools')]
from cutout_pipeline.cases import write_json

CASE = PROJECT / 'experiments/cutouts/slag_mortar/rr22'
ASSETS = PROJECT / 'assets/units/slag_mortar_cutout'
DIRECTOR = PROJECT / 'spec/peer_benchmark/staged/rr-22/motion_tracks.json'
PIECES = {'head': ['head'], 'torso': ['torso'], 'mortar': ['mortar'], 'pelvis': ['pelvis'],
          'apron': ['apron']}
BONES = {'apron': 'pelvis'}
PARENTS = {'root': None, 'pelvis': 'root', 'torso': 'pelvis', 'head': 'torso',
           'mortar': 'torso', 'apron_mid': 'pelvis', 'apron_tip': 'apron_mid'}
MESHES = {'apron': {'kind': 'chain', 'bones': ['pelvis', 'apron_mid', 'apron_tip']}}
for side in ('near', 'far'):
    PIECES.update({f'arm_{side}': [f'upper_{side}', f'fore_{side}'],
                   f'hand_{side}': [f'hand_{side}'],
                   f'leg_{side}': [f'thigh_{side}', f'shin_{side}'],
                   f'foot_{side}': [f'foot_{side}']})
    BONES.update({f'arm_{side}': f'upper_{side}', f'leg_{side}': f'thigh_{side}'})
    PARENTS.update({f'upper_{side}': 'torso', f'fore_{side}': f'upper_{side}',
                   f'hand_{side}': f'fore_{side}', f'thigh_{side}': 'pelvis',
                   f'shin_{side}': f'thigh_{side}', f'foot_{side}': f'shin_{side}'})
    for kind, chain in [('arm', [f'upper_{side}', f'fore_{side}', f'hand_{side}']),
                        ('leg', [f'thigh_{side}', f'shin_{side}', f'foot_{side}'])]:
        # Reuse the reference rig's source-space cuff and elbow/knee field.
        MESHES[f'{kind}_{side}'] = {'kind': 'two_segment', 'joints': chain, 'bones': chain[:2],
                                  'cuff_rows_px': 4, 'blend_half_width_px': 4}
GROUPS = {'upper_body': ['torso', 'head', 'arm_near', 'hand_near', 'arm_far', 'hand_far'],
          'weapon_arm': ['mortar'],
          'lower_body': ['pelvis', 'apron', 'leg_near', 'leg_far', 'foot_near', 'foot_far']}


def initialize():
    joins = [['head', 'torso'], ['mortar', 'torso'], ['torso', 'pelvis'], ['apron', 'pelvis']]
    for side in ('near', 'far'):
        joins += [[f'arm_{side}', 'torso'], [f'hand_{side}', f'arm_{side}'],
                  [f'leg_{side}', 'pelvis'], [f'foot_{side}', f'leg_{side}']]
    tucks = {name: {'depth_px': 3, 'covers': sorted({other for pair in joins if name in pair
              for other in pair if other != name}), 'mode': 'radial'} for name in PIECES}
    anatomy = {'schema_version': 1, 'required_parents': PARENTS, 'forbidden_joints': [],
        'meshes': MESHES,
        # Both arms are free. The schema's historical weapon_arm slot is the
        # torso-carried mortar; it has exactly the upper body's bob, no lag.
        'idle_groups': {'upper_body': {'bones': ['torso', 'head', 'upper_near', 'fore_near', 'hand_near',
                                               'upper_far', 'fore_far', 'hand_far'], 'stationary': False},
                        'weapon_arm': {'bones': ['mortar'], 'stationary': False},
                        'lower_body': {'bones': ['root', 'pelvis', 'apron_mid', 'apron_tip', 'thigh_near',
                            'shin_near', 'foot_near', 'thigh_far', 'shin_far', 'foot_far'], 'stationary': True}},
        'knee_policy': {'near_straight_deg': 6},
        'legs': {s: {'front': {'bend_side': 1}, 'rear': {'bend_side': -1}} for s in ('near', 'far')},
        'leg_roles': {'front': {'stride': 'near', 'trailing': 'far'}, 'rear': {'stride': 'far', 'trailing': 'near'}},
        'planted_bones': ['foot_near', 'foot_far'], 'planted_tolerance_px': 0.5,
        'held_depth_roles': {},
        'ownership': {'names': list(PIECES) + [n for r in MESHES.values() if r['kind'] == 'two_segment' for n in r['bones']],
            'segments': {n: {'joints': r['joints'], 'owners': r['bones']} for n, r in MESHES.items() if r['kind'] == 'two_segment'},
            'joint_pairs': joins, 'free_space_owners': ['mortar']},
        'seam_joins': joins, 'covered_surfaces': {},
        'joint_continuations': {'depth_px': 3, 'bounded_pieces': []},
        'tucks': {'base_px': 3, 'pieces': tucks},
        'integration': {'production_root': str(ASSETS.relative_to(PROJECT)), 'rig_directory': 'humanoid_v2',
            'production_files': ['rig.gd', 'renderer.gd', 'actions.gd', 'front.json', 'rear.json'],
            'binding_files': ['rig.gd', 'renderer.gd', 'actions.gd'],
            'binding_folders': ['tools/humanoid_cutout', 'scripts/maquette_cutout_runtime', 'tests/rr10', 'tests/rr11', 'tests/rr22'],
            'scale': {'file': 'data/enemies.json', 'key': 'slag_mortar', 'field': 'art_scale', 'default': 1.0},
            'identity_registry': 'spec/art_identity/registry.json', 'identity_id': 'slag_mortar',
            'density_id': 'slag_mortar_cutout', 'owner_approval': 'rr-22 supplied mq9 paintings; native proof pending director.',
            'identity_kind': 'creature', 'identity_entry_kind': 'legacy', 'identity_boss': False}}
    write_json(CASE / 'anatomy.json', anatomy)
    write_json(CASE / 'inputs.json', {**{v + '_job': 'spec/art_identity/jobs/slag_mortar/mq9_' + v for v in ('front', 'rear')},
        **{v + '_delivery': 'spec/art_identity/maquettes/slag_mortar/delivery' for v in ('front', 'rear')},
        'fused_occlusion': True, 'design_placeholders': {}})



if __name__ == '__main__': initialize()
