"""rr-11 case data from the unit brief and rr-10/rr-14 field contracts."""
from pathlib import Path
import json

PROJECT = Path(__file__).resolve().parents[3]
CASE = PROJECT / 'experiments/cutouts/arc_thrall/rr11'
PIECES = {'head': ['head'], 'torso': ['torso', 'collar'], 'upper_near': ['upper_near'],
          'tube': ['fore_near'], 'sleeve_far': ['upper_far', 'fore_far'], 'claw': ['hand_far'],
          'leg_near': ['thigh_near', 'shin_near'], 'leg_far': ['thigh_far', 'shin_far'],
          'foot_near': ['foot_near'], 'foot_far': ['foot_far'], 'loincloth': ['loincloth']}
GROUPS = {'upper_body': ['torso', 'head', 'sleeve_far', 'claw'],
          'weapon_arm': ['upper_near', 'tube'],
          'lower_body': ['leg_near', 'leg_far', 'foot_near', 'foot_far', 'loincloth']}
PARENTS = {'root': None, 'pelvis': 'root', 'torso': 'pelvis', 'head': 'torso',
           'upper_near': 'torso', 'fore_near': 'upper_near', 'tube_tip': 'fore_near',
           'upper_far': 'torso', 'fore_far': 'upper_far', 'hand_far': 'fore_far',
           'thigh_near': 'pelvis', 'shin_near': 'thigh_near', 'foot_near': 'shin_near',
           'thigh_far': 'pelvis', 'shin_far': 'thigh_far', 'foot_far': 'shin_far',
           'loincloth_tip': 'pelvis'}
# Existing rr-10 weight field and rigid cuff rows, reused without retuning.
MESHES = {name: {'kind': 'two_segment', 'joints': chain, 'bones': chain[:2],
                'cuff_rows_px': 4, 'blend_half_width_px': 4}
          for name, chain in [('sleeve_far', ['upper_far', 'fore_far', 'hand_far']),
                              ('leg_near', ['thigh_near', 'shin_near', 'foot_near']),
                              ('leg_far', ['thigh_far', 'shin_far', 'foot_far'])]}
MESHES['loincloth'] = {'kind': 'chain', 'bones': ['pelvis', 'loincloth_tip']}
TUCKS = {'base_px': 3, 'pieces': {
    'head': {'depth_px': 3, 'covers': 'torso', 'mode': 'radial'},
    'torso': {'depth_px': 4, 'covers': ['upper_near', 'sleeve_far', 'loincloth'], 'mode': 'radial'},
    'upper_near': {'depth_px': 5, 'covers': 'tube', 'mode': 'wrist', 'axis_joints': ['fore_near', 'tube_tip']},
    'sleeve_far': {'depth_px': 3, 'covers': 'torso', 'mode': 'inner_edge', 'extension_px': 3},
    'claw': {'depth_px': 5, 'covers': 'sleeve_far', 'mode': 'wrist', 'axis_joints': ['hand_far', 'fore_far']},
    'leg_near': {'depth_px': 3, 'covers': ['torso', 'loincloth', 'foot_near'], 'mode': 'radial'},
    'leg_far': {'depth_px': 3, 'covers': ['torso', 'loincloth', 'foot_far'], 'mode': 'radial'},
    'foot_near': {'depth_px': 4, 'covers': ['leg_near', 'loincloth'], 'mode': 'foot', 'axis': [0., -1.]},
    'foot_far': {'depth_px': 4, 'covers': ['leg_far', 'loincloth'], 'mode': 'foot', 'axis': [0., -1.]},
    'loincloth': {'depth_px': 3, 'covers': 'torso', 'mode': 'radial'}}}


def write(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2) + '\n')


def initialize():
    anatomy = {'schema_version': 1, 'required_parents': PARENTS,
        'forbidden_joints': ['collar', 'hand_near', 'club'], 'meshes': MESHES,
        'idle_groups': {
            'upper_body': {'bones': ['torso', 'head', 'upper_far', 'fore_far', 'hand_far'], 'stationary': False},
            'weapon_arm': {'bones': ['upper_near', 'fore_near', 'tube_tip'], 'stationary': False},
            'lower_body': {'bones': ['root', 'pelvis', 'thigh_near', 'shin_near', 'foot_near',
                                    'thigh_far', 'shin_far', 'foot_far', 'loincloth_tip'], 'stationary': True}},
        # Both native near knees are bent, so rr-14 derives their side from
        # the protected joints. Do not silently reverse the supplied anatomy.
        'legs': {}, 'planted_bones': ['foot_near', 'foot_far'], 'held_depth_roles': {},
        'ownership': {'names': list(PIECES) + ['upper_far', 'fore_far', 'thigh_near', 'shin_near', 'thigh_far', 'shin_far'],
            'segments': {n: {'joints': r['joints'], 'owners': r['bones']} for n, r in MESHES.items() if r['kind'] == 'two_segment'},
            'joint_pairs': [['torso', 'head'], ['torso', 'loincloth'], ['torso', 'upper_near'],
                ['upper_near', 'tube'], ['torso', 'upper_far'], ['upper_far', 'fore_far'], ['fore_far', 'claw'],
                ['torso', 'thigh_near'], ['torso', 'thigh_far'], ['loincloth', 'thigh_near'], ['loincloth', 'thigh_far'],
                ['thigh_near', 'shin_near'], ['shin_near', 'foot_near'], ['thigh_far', 'shin_far'], ['shin_far', 'foot_far']],
            'free_space_owners': ['tube']},
        'seam_joins': [['head', 'torso'], ['upper_near', 'torso'], ['tube', 'upper_near'],
            ['sleeve_far', 'torso'], ['claw', 'sleeve_far'], ['loincloth', 'torso'],
            ['leg_near', 'torso'], ['leg_far', 'torso'], ['leg_near', 'loincloth'], ['leg_far', 'loincloth'],
            ['foot_near', 'leg_near'], ['foot_far', 'leg_far']],
        'covered_surfaces': {}, 'joint_continuations': {'depth_px': 4, 'bounded_pieces': []}, 'tucks': TUCKS,
        'integration': {'production_root': 'assets/units/arc_thrall_cutout', 'rig_directory': 'humanoid_v2',
            'production_files': ['rig.gd', 'renderer.gd', 'front.json', 'rear.json'],
            'binding_files': ['rig.gd', 'renderer.gd'],
            'binding_folders': ['tools/humanoid_cutout', 'scripts/maquette_cutout_runtime', 'tests/rr10', 'tests/rr11'],
            'scale': {'file': 'data/enemies.json', 'key': 'arc_thrall', 'field': 'art_scale', 'default': 1.0},
            'identity_registry': 'spec/art_identity/registry.json', 'identity_id': 'arc_thrall',
            'density_id': 'arc_thrall_cutout', 'owner_approval': 'rr-11 supplied approved mq7 front/rear painting; derived rest snapshot, native proof pending director.',
            'identity_kind': 'creature', 'identity_entry_kind': 'legacy', 'identity_boss': False}}
    write(CASE / 'anatomy.json', anatomy)
    write(CASE / 'inputs.json', {**{v + '_job': 'spec/art_identity/jobs/arc_thrall/mq7_' + v for v in ('front', 'rear')},
        **{v + '_delivery': 'spec/art_identity/maquettes/arc_thrall/delivery' for v in ('front', 'rear')},
        'fused_occlusion': True,
        'design_placeholders': {
            'TODO_DESIGN_near_knee_direction': 'mq-07 near knee bends opposite facing in both views; rr-14 preserves bent rest side. Approved correction required.',
            'TODO_DESIGN_move_foot_targets': 'Protected move targets produce swing frames below 15 degrees and stance drift from parent-relative pelvis motion and reach clamping; approved anatomy or channel correction required.',
            'TODO_DESIGN_jab_planted_feet': 'Protected jab pelvis translation overreaches native leg lengths. Length-preserving IK cannot keep both feet planted; approved anatomy or channel correction required.'}})


if __name__ == '__main__': initialize()
