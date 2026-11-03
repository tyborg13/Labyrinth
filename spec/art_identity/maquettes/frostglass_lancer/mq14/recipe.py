"""mq-14: compile the untouched painting provenance with the mandated rig rules.

The r3 anatomy and armour retain the mq4 painting's provenance. Cape and
pouch measurements transcribe the approved pair. The shoulder target follows
the brief's equation, retaining the far hand/grip.
"""
import json
from pathlib import Path

import numpy as np

from spec.art_identity.maquettes.blender.contract import validate
from spec.art_identity.maquettes.blender.facing import board_spec
from spec.art_identity.maquettes.blender.pose_adjustment import corrected_joints
from spec.art_identity.maquettes.raster import project

FIGURE = Path(__file__).resolve().parents[1]
PROOF_CAMERA = {'ortho_scale': 2.8, 'target': [0, 0, 1.0]}
RECIPE_DEFAULTS = {'panel_columns': 17, 'static_frames': 1}


def fit_cloak(spec, piece, measurements):
    """Triangulate one cape from corresponding rows in the approved pair.

    A static maquette has no cloth animation. Fully pinned native cloth keeps
    the measured panel while the builder resolves body clearance and thickness.
    Front and rear always capture the same frozen mesh.
    """
    from spec.art_identity.maquettes.blender.source_recipe import paired_point
    columns = RECIPE_DEFAULTS['panel_columns']
    rows = []
    for index in range(len(measurements['cloak_rows_px']['front'])):
        views = {}
        for view in ('front', 'rear'):
            reg = measurements['native_registration'][view]
            src = measurements['geometry_source_frame'][view]
            factor = (reg['sole_bottom'] - reg['head_top']) / (src['sole_bottom'] - src['head_top'])
            a, b = np.array(measurements['cloak_rows_px'][view][index])
            points = np.array([(1-t)*a+t*b for t in np.linspace(0, 1, columns)])
            if index == len(measurements['cloak_rows_px'][view])-1:
                points[:, 1] = np.interp(points[:, 0], *np.array(measurements['cloak_hem_px'][view]).T)
            points = (points - [src['ground_x'], src['head_top']]) * factor + [reg['ground_x'], reg['head_top']]
            views[view] = points
        rows.append({'points': [paired_point(spec, a, b, size=1024) for a, b in zip(views['front'], views['rear'])]})
    piece['pattern'] = {'columns': columns, 'closed': False, 'rows': rows,
                        'pins': list(range(columns * len(rows)))}
    piece['frames'] = RECIPE_DEFAULTS['static_frames']
    piece['back_attachment'] = {'forward': [1, 1, 0], 'revision': 5}
    # Source hem points already describe the rag; do not notch it twice.
    piece['rag'] = {'count': 0, 'depth': 0, 'seed': 0}


def belt_pouch(spec, measurements):
    from spec.art_identity.maquettes.blender.source_recipe import paired_point, common
    corners = {}
    for view in ('front', 'rear'):
        src, reg = measurements['geometry_source_frame'][view], measurements['native_registration'][view]
        factor = (reg['sole_bottom']-reg['head_top'])/(src['sole_bottom']-src['head_top'])
        corners[view] = (np.array(measurements['belt_pouch'][view+'_corners_px']) -
            [src['ground_x'], src['head_top']])*factor+[reg['ground_x'], reg['head_top']]
    points = [paired_point(spec, a, b, size=1024) for a, b in zip(corners['front'], corners['rear'])]
    piece = common('pouch_belt', 'plate', 'belt')
    bevel = next(p['bevel'] for p in spec['pieces'] if p['id'] == 'tasset_far')
    piece.update(outline=[[p[0], p[2]] for p in points], outline_3d=points,
        conform_weights=[0]*len(points), thick=measurements['belt_pouch']['thickness_px']*spec['ortho_scale']/256,
        bevel=dict(bevel), offset_surface=0, rig_bone='pelvis', rig_pivot_joint='pelvis')
    return piece


def compile_spec():
    measurements = json.loads((FIGURE / 'mq14/measurements.json').read_text())
    spec = board_spec(json.loads((FIGURE / 'spec_r3.json').read_text()))
    spec.update(id='frostglass_lancer', design_status='mq-14 current-builder maquette; mq4 paintings remain protected')
    labels = spec['labels']
    aliases = {'collar': 'head', 'tasset_near': 'belt', 'tasset_far': 'belt',
               'spear_shaft': 'spear', 'spear_blade': 'spear'}
    labels['spear'] = labels['spear_shaft']
    for name in aliases:
        del labels[name]
    for piece in spec['pieces']:
        piece['part'] = aliases.get(piece['part'], piece['part'])
        if piece['id'] == 'cloak':
            piece['side_parts'] = ['cape_near', 'cape_far']
            piece['ownership_mode'] = 'body_sagittal'
            fit_cloak(spec, piece, measurements)
        if piece['id'] in ('spear_shaft', 'spear_blade'):
            piece.update(rig_bone='hand_far', rig_pivot_joint='hand_far')
    spec['pieces'].append(belt_pouch(spec, measurements))
    near, far = project(spec, [spec['joints'][j] for j in ('shoulder_near', 'shoulder_far')])[:, :2]
    spec['joints'] = corrected_joints(spec, [{'chain': ['shoulder_far', 'elbow_far', 'hand_far'],
        'shoulder_front_px': [float(far[0]), float(near[1] - .15 * abs(near[0] - far[0]))],
        'shoulder_height_joint': 'shoulder_near', 'translate_with_hand': ['hand_tip_far']}])
    # A crystal's explicit path avoids the historical continuation/pivot
    # interaction: both endpoints are in the same world frame as the shaft.
    shaft = next(p for p in spec['pieces'] if p['id'] == 'spear_shaft')
    blade = next(p for p in spec['pieces'] if p['id'] == 'spear_blade')
    start, end = np.array(shaft['path'])
    direction = (end - start) / np.linalg.norm(end - start)
    grip = np.array(spec['joints']['hand_far'])
    closest = start + direction * np.dot(grip - start, direction)
    end += grip - closest
    floor = measurements['foot_surface_plane_m'] + shaft['radius'] * np.sqrt(1-direction[2]**2)
    start = grip + (floor - grip[2]) / direction[2] * direction
    shaft['path'] = [start.tolist(), end.tolist()]
    blade.pop('continues')
    blade['path'] = [end.tolist(), (end + direction * blade['length']).tolist()]
    spec['fit'].update(source='spec/art_identity/jobs/frostglass_lancer/mq4_front/processed.png',
                       weapon_parts=['spear'], source_frame=measurements['source_frame']['front'])
    spec['rig_delivery'] = {'cloth': {'tabard': 'pelvis', 'cape_near': 'torso', 'cape_far': 'torso'},
        'rigid': {'spear': {'bone': 'hand_far', 'pivot': 'hand_far'}},
        'features': {'cyan_cross_visor': {'part': 'head', 'views': ['front']},
                     'chest_crystal': {'part': 'torso', 'views': ['front']},
                     'crystal_spearhead': {'part': 'spear', 'views': ['front', 'rear']}}}
    spec.update(PROOF_CAMERA)
    validate(spec)
    return spec


if __name__ == '__main__':
    path = FIGURE / 'mq14/spec_native.json'
    path.write_text(json.dumps(compile_spec(), indent=2) + '\n')
    print('MQ14_SPEC: PASS; ' + str(path))
