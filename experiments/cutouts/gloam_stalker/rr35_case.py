"""mq-13 anatomy and protected director inputs for rr-35; no new art or tuning."""
from pathlib import Path
import json

PROJECT = Path(__file__).resolve().parents[3]
CASE = PROJECT / 'experiments/cutouts/gloam_stalker/rr35'
ASSETS = PROJECT / 'assets/units/gloam_stalker_cutout'
DIRECTOR = PROJECT / 'spec/peer_benchmark/staged/rr-35/motion_tracks.json'
# Native torso has no separate pelvis label. Split only that source surface at
# the projected native pelvis, retaining the native carapace in the rigid torso.
NATIVE_PIECES = {'head': ['head'], 'torso': ['torso', 'carapace']}
PIECES = {'head': ['head'], 'torso': ['torso', 'carapace'], 'pelvis': ['pelvis']}
PARENTS = {'root': None, 'pelvis': 'root', 'torso': 'pelvis', 'head': 'torso'}
BONES = {}
MESHES = {}
for side in ('near', 'far'):
    cape = 'cape_' + side
    NATIVE_PIECES[cape] = [cape]
    PIECES[cape] = [cape]
    PARENTS.update({cape + '_mid': 'torso', cape + '_tip': cape + '_mid'})
    BONES[cape] = 'torso'
    MESHES[cape] = {'kind': 'chain', 'bones': ['torso', cape + '_mid', cape + '_tip']}
    for name, labels in [('arm_', ['upper_', 'fore_']), ('hand_', ['claw_']),
                         ('leg_', ['thigh_', 'shin_']), ('foot_', ['foot_'])]:
        PIECES[name + side] = [label + side for label in labels]
        NATIVE_PIECES[name + side] = PIECES[name + side]
    PARENTS.update({'upper_' + side: 'torso', 'fore_' + side: 'upper_' + side,
        'hand_' + side: 'fore_' + side, 'thigh_' + side: 'pelvis',
        'shin_' + side: 'thigh_' + side, 'foot_' + side: 'shin_' + side})
    BONES.update({'arm_' + side: 'upper_' + side, 'leg_' + side: 'thigh_' + side})
    for name, chain in [('arm_' + side, ['upper_' + side, 'fore_' + side, 'hand_' + side]),
                        ('leg_' + side, ['thigh_' + side, 'shin_' + side, 'foot_' + side])]:
        MESHES[name] = {'kind': 'two_segment', 'joints': chain, 'bones': chain[:2],
            'cuff_rows_px': 4, 'blend_half_width_px': 4}  # Binding reference weight field.
GROUPS = {'upper_body': ['torso', 'head', 'cape_near', 'cape_far', 'arm_far', 'hand_far'],
    'weapon_arm': ['arm_near', 'hand_near'],
    'lower_body': ['pelvis', 'leg_near', 'leg_far', 'foot_near', 'foot_far']}
PLACEHOLDERS = {}  # Director feedback 2 resolves the two geometric limits.
MINIMUM_REACH_EXCEPTION = {
    'margin_px': 3.5,
    'reason': 'r3 crouch foreshortens the rear near thigh; director judges the native rear move frames (rr-35 feedback 2)'}


def knee_policy():
    import numpy as np
    delivery = json.loads((PROJECT / 'spec/art_identity/maquettes/gloam_stalker/delivery/joints_px.json').read_text())
    views = {}
    for view, joints in delivery.items():
        views[view] = {}
        for side in ('near', 'far'):
            a, b, c = [np.asarray(joints[n + '_' + side], dtype=float) for n in ('hip', 'knee', 'ankle')]
            u, v = b - a, c - b
            bend = abs(float(np.degrees(np.arctan2(u[0]*v[1]-u[1]*v[0], u@v))))
            views[view][side] = {'near_straight_deg': 6, 'crouched_stance_deg': bend}
    return {'near_straight_deg': 6, 'by_view': views}


def write(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2) + '\n')


def initialize():
    upper = ['torso', 'head', 'upper_far', 'fore_far', 'hand_far',
        'cape_near_mid', 'cape_near_tip', 'cape_far_mid', 'cape_far_tip']
    weapon = ['upper_near', 'fore_near', 'hand_near']
    lower = [n for n in PARENTS if n not in upper + weapon]
    joins = [['head', 'torso'], ['torso', 'pelvis']]
    for s in ('near', 'far'):
        joins += [['cape_' + s, 'torso'], ['cape_' + s, 'pelvis'], ['arm_' + s, 'torso'],
            ['hand_' + s, 'arm_' + s], ['leg_' + s, 'pelvis'], ['leg_' + s, 'cape_' + s],
            ['foot_' + s, 'leg_' + s]]
    tucks = {n: {'depth_px': 3, 'covers': sorted({b if a == n else a for a, b in joins if n in (a, b)}),
        'mode': 'radial'} for n in PIECES}
    anatomy = {'schema_version': 1, 'required_parents': PARENTS,
        'forbidden_joints': ['carapace', 'eye', 'claw_near', 'claw_far'], 'meshes': MESHES,
        'idle_groups': {'upper_body': {'bones': upper, 'stationary': False},
            'weapon_arm': {'bones': weapon, 'stationary': False},
            'lower_body': {'bones': lower, 'stationary': True}},
        'knee_policy': knee_policy(),
        # r3: all four legs have a bent stance and retain the native bend side.
        'legs': {'near': {'front': {'bend_side': 1}, 'rear': {'bend_side': -1, 'minimum_reach': MINIMUM_REACH_EXCEPTION}},
                 'far': {'front': {'bend_side': 1}, 'rear': {'bend_side': -1}}},
        'planted_bones': ['foot_near', 'foot_far'], 'planted_tolerance_px': 0.5, 'held_depth_roles': {},
        'ownership': {'names': list(PIECES) + [n + '_' + s for s in ('near', 'far') for n in ('upper', 'fore', 'thigh', 'shin')],
            'segments': {n: {'joints': r['joints'], 'owners': r['bones']} for n, r in MESHES.items() if r['kind'] == 'two_segment'},
            'joint_pairs': joins + [[r['bones'][0], r['bones'][1]] for r in MESHES.values() if r['kind'] == 'two_segment'],
            'free_space_owners': []},
        'seam_joins': joins, 'covered_surfaces': {},
        'joint_continuations': {'depth_px': 3, 'bounded_pieces': []}, 'tucks': {'base_px': 3, 'pieces': tucks},
        'integration': {'production_root': 'assets/units/gloam_stalker_cutout', 'rig_directory': 'humanoid_v2',
            'production_files': ['rig.gd', 'renderer.gd', 'actions.gd', 'front.json', 'rear.json'],
            'binding_files': ['rig.gd', 'renderer.gd', 'actions.gd'],
            'binding_folders': ['tools/humanoid_cutout', 'scripts/maquette_cutout_runtime', 'tests/rr10', 'tests/rr35'],
            'scale': {'file': 'data/enemies.json', 'key': 'gloam_stalker', 'field': 'art_scale', 'default': 1.0},
            'identity_registry': 'spec/art_identity/registry.json', 'identity_id': 'gloam_stalker',
            'density_id': 'gloam_stalker_cutout', 'owner_approval': 'rr-35 supplied identity-gated mq13 paintings; native proof pending director.',
            'identity_kind': 'creature', 'identity_entry_kind': 'legacy', 'identity_boss': False}}
    write(CASE / 'anatomy.json', anatomy)
    write(CASE / 'inputs.json', {**{v + '_job': 'spec/art_identity/jobs/gloam_stalker/mq13_' + v for v in ('front', 'rear')},
        **{v + '_delivery': 'spec/art_identity/maquettes/gloam_stalker/delivery' for v in ('front', 'rear')},
        'fused_occlusion': True, 'design_placeholders': PLACEHOLDERS})


if __name__ == '__main__': initialize()
