"""mq-14 anatomy and protected director inputs for rr-37; no new art or tuning."""
from pathlib import Path
import json
import sys
sys.path[:0] = [str(Path(__file__).resolve().parents[3]), str(Path(__file__).resolve().parents[3] / "tools")]

PROJECT = Path(__file__).resolve().parents[3]
CASE = PROJECT / 'experiments/cutouts/frostglass_lancer/rr37'
ASSETS = PROJECT / 'assets/units/frostglass_lancer_cutout'
DIRECTOR = PROJECT / 'spec/peer_benchmark/staged/rr-37/motion_tracks.json'
# mq-14 owns the pauldrons on the torso, belt on pelvis and one held spear.
NATIVE_PIECES = {'head': ['head'], 'torso': ['torso', 'pauldron_near', 'pauldron_far'], 'pelvis': ['pelvis', 'belt'], 'tabard': ['tabard'], 'spear': ['spear']}
PIECES = dict(NATIVE_PIECES)
PARENTS = {'root': None, 'pelvis': 'root', 'torso': 'pelvis', 'head': 'torso', 'spear': 'hand_far', 'tabard_mid': 'pelvis', 'tabard_tip': 'tabard_mid'}
BONES = {'tabard': 'pelvis'}
MESHES = {'tabard': {'kind': 'chain', 'bones': ['pelvis', 'tabard_mid', 'tabard_tip']}}
for side in ('near', 'far'):
    cape = 'cape_' + side
    NATIVE_PIECES[cape] = [cape]
    PIECES[cape] = [cape]
    PARENTS.update({cape + '_mid': 'torso', cape + '_tip': cape + '_mid'})
    BONES[cape] = 'torso'
    MESHES[cape] = {'kind': 'chain', 'bones': ['torso', cape + '_mid', cape + '_tip']}
    for name, labels in [('arm_', ['upper_', 'fore_']), ('hand_', ['hand_']),
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
GROUPS = {'upper_body': ['torso', 'head', 'cape_near', 'cape_far', 'arm_near', 'hand_near'],
    'weapon_arm': ['arm_far', 'hand_far', 'spear'],
    'lower_body': ['pelvis', 'tabard', 'leg_near', 'leg_far', 'foot_near', 'foot_far']}
EMPTY_REASON = 'covered by the cloak in the approved rear painting (director, rr-37 feedback 1)'
INTENTIONALLY_EMPTY = {'rear': {name: EMPTY_REASON for name in ('hand_near', 'belt', 'pelvis', 'tabard')}}
PLACEHOLDERS = {}
RELEASE_EXEMPTIONS = [{'item': 'spear', 'clip': 'death'}]  # Director, rr-37 feedback 2; timing stays in motion.


def knee_policy():
    import numpy as np
    delivery = json.loads((PROJECT / 'spec/art_identity/maquettes/frostglass_lancer/delivery/joints_px.json').read_text())
    views = {}
    for view, joints in delivery.items():
        views[view] = {}
        for side in ('near', 'far'):
            a, b, c = [np.asarray(joints[n + '_' + side], dtype=float) for n in ('hip', 'knee', 'ankle')]
            u, v = b - a, c - b
            bend = abs(float(np.degrees(np.arctan2(u[0]*v[1]-u[1]*v[0], u@v))))
            views[view][side] = {'near_straight_deg': 6, 'crouched_stance_deg': bend}
    return {'near_straight_deg': 6, 'by_view': views}


def leg_policy():
    import numpy as np
    delivery = json.loads((PROJECT / 'spec/art_identity/maquettes/frostglass_lancer/delivery/joints_px.json').read_text())
    result = {side: {} for side in ('near', 'far')}
    for view, joints in delivery.items():
        for side in result:
            a, b, c = [np.asarray(joints[n + '_' + side], dtype=float) for n in ('hip', 'knee', 'ankle')]
            u, v = b-a, c-b
            bend = abs(float(np.degrees(np.arctan2(np.linalg.det(np.array([u,v])), u@v))))
            ray, elbow = c-a, b-a
            sign = int(np.sign(ray[0]*elbow[1]-ray[1]*elbow[0]))
            result[side][view] = {'bend_side': (1 if view == 'front' else -1) if bend <= 6 else sign}
    return result


def write(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2) + '\n')


def initialize():
    upper = ['torso', 'head', 'upper_near', 'fore_near', 'hand_near',
        'cape_near_mid', 'cape_near_tip', 'cape_far_mid', 'cape_far_tip']
    weapon = ['upper_far', 'fore_far', 'hand_far', 'spear']
    lower = [n for n in PARENTS if n not in upper + weapon]
    joins = [['head', 'torso'], ['torso', 'pelvis'], ['tabard', 'pelvis'], ['spear', 'hand_far']]
    for s in ('near', 'far'):
        joins += [['cape_' + s, 'torso'], ['cape_' + s, 'pelvis'], ['arm_' + s, 'torso'],
            ['hand_' + s, 'arm_' + s], ['leg_' + s, 'pelvis'], ['leg_' + s, 'cape_' + s],
            ['foot_' + s, 'leg_' + s]]
    tucks = {n: {'depth_px': 3, 'covers': sorted({b if a == n else a for a, b in joins if n in (a, b)}),
        'mode': 'radial'} for n in PIECES}
    anatomy = {'schema_version': 1, 'required_parents': PARENTS,
        'forbidden_joints': ['pauldron_near', 'pauldron_far', 'belt', 'visor', 'chest_crystal'], 'meshes': MESHES,
        'idle_groups': {'upper_body': {'bones': upper, 'stationary': False},
            'weapon_arm': {'bones': weapon, 'stationary': True},
            'lower_body': {'bones': lower, 'stationary': True}},
        'knee_policy': knee_policy(),
        'legs': leg_policy(),
        'planted_bones': ['foot_near', 'foot_far'], 'planted_tolerance_px': 0.5, 'held_depth_roles': {},
        'ownership': {'names': list(PIECES) + [n + '_' + s for s in ('near', 'far') for n in ('upper', 'fore', 'thigh', 'shin')],
            'segments': {n: {'joints': r['joints'], 'owners': r['bones']} for n, r in MESHES.items() if r['kind'] == 'two_segment'},
            'joint_pairs': joins + [[r['bones'][0], r['bones'][1]] for r in MESHES.values() if r['kind'] == 'two_segment'],
            'free_space_owners': []},
        'seam_joins': joins, 'covered_surfaces': {}, 'intentionally_empty': INTENTIONALLY_EMPTY,
        'held_item_release_exemptions': RELEASE_EXEMPTIONS,
        'joint_continuations': {'depth_px': 3, 'bounded_pieces': []}, 'tucks': {'base_px': 3, 'pieces': tucks},
        'integration': {'production_root': 'assets/units/frostglass_lancer_cutout', 'rig_directory': 'humanoid_v2',
            'production_files': ['rig.gd', 'renderer.gd', 'front.json', 'rear.json'],
            'binding_files': ['rig.gd', 'renderer.gd'],
            'binding_folders': ['tools/humanoid_cutout', 'scripts/maquette_cutout_runtime', 'tests/rr10', 'tests/rr37'],
            'scale': {'file': 'data/enemies.json', 'key': 'frostglass_lancer', 'field': 'art_scale', 'default': 1.0},
            'identity_registry': 'spec/art_identity/registry.json', 'identity_id': 'frostglass_lancer',
            'density_id': 'frostglass_lancer_cutout', 'owner_approval': 'rr-37 supplied identity-gated mq14 paintings; native proof pending director.',
            'identity_kind': 'creature', 'identity_entry_kind': 'legacy', 'identity_boss': False}}
    write(CASE / 'anatomy.json', anatomy)
    write(CASE / 'inputs.json', {**{v + '_job': 'spec/art_identity/jobs/frostglass_lancer/mq14_' + v + ('_v2' if v == 'rear' else '') for v in ('front', 'rear')},
        **{v + '_delivery': 'spec/art_identity/maquettes/frostglass_lancer/delivery' for v in ('front', 'rear')},
        'fused_occlusion': True, 'intentionally_empty': INTENTIONALLY_EMPTY, 'design_placeholders': PLACEHOLDERS})


if __name__ == '__main__': initialize()
