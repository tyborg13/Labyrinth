"""rr-20 anatomy from the approved mq-09 delivery and humanoid v2 spec."""
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT))
sys.path.insert(0, str(ROOT / 'tools'))
from cutout_pipeline.cases import read_json, write_json, digest

CASE = ROOT / 'experiments/cutouts/hollow_mimic/rr20'
ASSETS = ROOT / 'assets/units/hollow_mimic_cutout'
DIRECTOR = ROOT / 'spec/peer_benchmark/staged/rr-20/motion_tracks.json'
VIEWS = ('front', 'rear')
PIECES = {name: [name] for name in ('head', 'torso', 'pelvis')}
PARENTS = {'root': None, 'pelvis': 'root', 'torso': 'pelvis', 'head': 'torso'}
MESHES = {}
for side in ('near', 'far'):
    for first, second, terminal, parent, garment in (
            ('upper', 'fore', 'hand', 'torso', 'sleeve'),
            ('thigh', 'shin', 'foot', 'pelvis', 'leg')):
        chain = [name + '_' + side for name in (first, second, terminal)]
        PARENTS.update(zip(chain, [parent, *chain[:2]]))
        PIECES[garment + '_' + side] = chain[:2]
        PIECES[chain[2]] = [chain[2]]
        # Existing v2 two-segment field, including the rigid cuff rows.
        MESHES[garment + '_' + side] = {'kind': 'two_segment', 'joints': chain,
            'bones': chain[:2], 'cuff_rows_px': 4, 'blend_half_width_px': 4}
BONES = {name: labels[0] for name, labels in PIECES.items()}
GROUPS = {'upper_body': ['head', 'torso', 'sleeve_near', 'hand_near', 'sleeve_far', 'hand_far'],
          'weapon_arm': [], 'lower_body': ['pelvis', 'leg_near', 'foot_near', 'leg_far', 'foot_far']}
DESIGN_PLACEHOLDERS = {
    'TODO_DESIGN_rear_far_apex_knee': 'Protected 5px gait lift: rear far apex 50.870 < stance 57.913 degrees at frame 9; 53.229 < 53.591 at frame 28. Director data decision required; gate unchanged.',
    'TODO_DESIGN_joint_continuation_rest_envelope': 'Historical rear death frame 5 neck pocket maps to transparent rest texels in head (118,100)-(120,102), torso (118,99)-(121,101), and sleeve (117,100)-(120,102). A rest-preserving own-piece continuation cannot cover those pixels. A gait-only 26-texel candidate closes the two new move pockets but exposes 20 pixels at both rear move endpoints. Director presentation/art decision required; no exemptions, motion edits or candidate activation.',
    'TODO_DESIGN_front_head_detached_source_texels': 'Approved front head has detached source texels (105,48) and (105,49); rotations put them beyond the strict 2px distance. Derived presentation/art decision required; source unchanged.'
}


def initialize():
    joins = [['head', 'torso'], ['torso', 'pelvis']]
    for side in ('near', 'far'):
        joins += [['sleeve_' + side, 'torso'], ['hand_' + side, 'sleeve_' + side],
                  ['leg_' + side, 'pelvis'], ['foot_' + side, 'leg_' + side]]
    # The spec requires >=3 source pixels of covered continuation. These
    # masks copy same-surface approved texels; they never repaint the source.
    tucks = {name: {'depth_px': 3, 'covers': [b if a == name else a for a, b in joins if name in (a, b)],
                    'mode': 'radial'} for name in PIECES}
    names = list(PIECES) + [n for chain in MESHES.values() for n in chain['bones']]
    pairs = [['torso', 'head'], ['torso', 'pelvis']]
    for side in ('near', 'far'):
        pairs += [['torso', 'upper_' + side], ['upper_' + side, 'fore_' + side],
                  ['fore_' + side, 'hand_' + side], ['pelvis', 'thigh_' + side],
                  ['thigh_' + side, 'shin_' + side], ['shin_' + side, 'foot_' + side]]
    anatomy = {'schema_version': 1, 'required_parents': PARENTS, 'forbidden_joints': [],
        'meshes': MESHES, 'idle_groups': {
            'upper_body': {'bones': ['torso', 'head', 'upper_near', 'fore_near', 'hand_near',
                                     'upper_far', 'fore_far', 'hand_far'], 'stationary': False},
            # No held item: an empty weapon group uses the stationary root as
            # its proof anchor, keeping exactly three spec groups.
            'weapon_arm': {'bones': ['root'], 'stationary': True},
            'lower_body': {'bones': ['pelvis', 'thigh_near', 'shin_near', 'foot_near',
                                    'thigh_far', 'shin_far', 'foot_far'], 'stationary': True}},
        'knee_policy': {'near_straight_deg': 6},
        'legs': {side: {'front': {'bend_side': 1}, 'rear': {'bend_side': -1}} for side in ('near', 'far')},
        'planted_bones': ['foot_near', 'foot_far'], 'planted_tolerance_px': 0.5,
        'held_depth_roles': {}, 'ownership': {'names': names,
            'segments': {n: {'joints': r['joints'], 'owners': r['bones']} for n, r in MESHES.items()},
            'joint_pairs': pairs, 'free_space_owners': []},
        'seam_joins': joins, 'covered_surfaces': {},
        'joint_continuations': {'depth_px': 3, 'bounded_pieces': []},
        'tucks': {'base_px': 3, 'pieces': tucks},
        'integration': {'production_root': str(ASSETS.relative_to(ROOT)), 'rig_directory': '',
            'production_files': ['rig.gd', 'renderer.gd', 'front.json', 'rear.json'],
            'binding_files': ['rig.gd', 'renderer.gd'],
            'binding_folders': ['tools/humanoid_cutout', 'scripts/maquette_cutout_runtime', 'tests/rr10', 'tests/rr20'],
            'scale': {'file': 'data/enemies.json', 'key': 'hollow_mimic', 'field': 'art_scale', 'default': 1.0},
            'identity_registry': 'spec/art_identity/registry.json', 'identity_id': 'hollow_mimic',
            'density_id': 'hollow_mimic_cutout', 'identity_kind': 'creature', 'identity_entry_kind': 'legacy',
            'identity_boss': False,
            'owner_approval': 'rr-20 approved mq9 front/rear paintings; derived source rest, native proof pending director.'}}
    write_json(CASE / 'anatomy.json', anatomy)
    write_json(CASE / 'inputs.json', {**{v + '_job': 'spec/art_identity/jobs/hollow_mimic/mq9_' + v for v in VIEWS},
        **{v + '_delivery': 'spec/art_identity/maquettes/hollow_mimic/delivery' for v in VIEWS},
        'fused_occlusion': True, 'design_placeholders': DESIGN_PLACEHOLDERS})


if __name__ == '__main__': initialize()
