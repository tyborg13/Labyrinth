"""Compile measured pixel recipes into the existing Blender-native v2 contract.

The production Lancer supplies only the approved CC0 registration/rest rig and
native cloth settings. No Lancer geometry, artwork or output is overwritten.
"""
from copy import deepcopy
import json
import math
from pathlib import Path
import sys

import numpy as np

PROJECT = Path(__file__).resolve().parents[4]
sys.path.insert(0, str(PROJECT))

from spec.art_identity.maquettes.blender.contract import validate
from spec.art_identity.maquettes.blender.facing import board_spec
from spec.art_identity.maquettes.blender.source_recipe import (
    common, paired_point, plane_point, panel, sleeve, cloth, curve, measurement_residuals, bounded_hem, path_points)
from spec.art_identity.maquettes.raster import camera


COMPILE_DEFAULTS = {'static_drape_frames': 1, 'ring_samples': 32, 'seam_epsilon': 1e-10}


def compile_recipe(recipe):
    if recipe.get('native_solids'):
        from spec.art_identity.maquettes.blender.creature_recipe import compile_solids
        return compile_solids(recipe)
    baseline = board_spec(json.loads((PROJECT / 'spec/art_identity/maquettes/frostglass_lancer/spec_r3.json').read_text()))
    physics = {key: deepcopy(baseline['pieces'][0][key]) for key in
               ('frames', 'stiffness', 'collision_margin', 'solver_margin',
                'collision_refine_levels', 'self_collision', 'thick', 'solidify_offset', 'rag')}
    physics.update(frames=COMPILE_DEFAULTS['static_drape_frames'], rag={'count': 0, 'depth': 0, 'seed': 0})
    spec = {'version': 2, 'id': recipe['id'], 'ortho_scale': baseline['ortho_scale'],
            'target': baseline['target'], 'labels': recipe['labels'],
            'base': deepcopy(baseline['base']), 'armature': deepcopy(baseline['armature']),
            'simulation': deepcopy(baseline['simulation']), 'pieces': [], 'joints': {'root': [0, 0, 0]},
            'source_recipe': recipe['id'] + '/measurements.json'}
    spec['base']['covered_regions'] = recipe.get('covered_body_regions', [])
    spec['base'].pop('covered_above_z', None)
    spec['base'].pop('proposed', None)
    if recipe.get('view_registration_px'):
        spec['view_transforms'] = {}
        for view in ('front', 'rear'):
            matrix, target, basis, scale = camera({k: v for k, v in spec.items() if k != 'view_transforms'}, view)
            dx, dy = recipe['view_registration_px'].get(view, [0, 0])
            target = target + (-basis[0] * dx + basis[1] * dy) * scale / 256
            spec['view_transforms'][view] = {'object_to_world': matrix.tolist(), 'target': target.tolist(),
                'azimuth_deg': 45, 'elevation_deg': 30, 'ortho_scale': scale}
    if recipe.get('body_source_profiles'):
        spec['base']['source_profiles'] = deepcopy(recipe['body_source_profiles'])
    spec['armature'].pop('proposed', None)
    spec['simulation'].pop('proposed', None)
    for name, pixels in recipe['joints_px'].items():
        spec['joints'][name] = paired_point(spec, *pixels)
    if recipe.get('head_face_axis_px'):
        a, b = np.array(recipe['head_face_axis_px'], float)
        matrix, _, basis, _ = camera(spec, 'front')
        screen = np.array([basis[0] @ matrix[:3, :3], basis[1] @ matrix[:3, :3]])
        axis = np.linalg.solve(screen[:, [0, 2]], [b[0]-a[0], a[1]-b[1]])
        axis /= np.linalg.norm(axis)
        length = np.linalg.norm(np.subtract(spec['joints']['head_tip'], spec['joints']['head']))
        spec['joints']['head_tip'] = (np.array(spec['joints']['head']) + length * np.array([axis[0], 0, axis[1]])).tolist()
    for bone in spec['armature']['bones']:
        bone['region'] = recipe.get('region_map', {}).get(bone['region'], bone['region'])
        bone['scale'] = recipe['bone_scales'].get(bone['name'], [1, 1])
    for item in recipe['surfaces']:
        first_piece = len(spec['pieces'])
        kind = item['shape']
        if kind == 'back_sheet':
            from spec.art_identity.maquettes.blender.back_sheet import draft
            spec['pieces'].append(draft(spec, item['drape']['back_sheet'], physics, item['id'], item['part']))
        elif kind == 'panel':
            source_view = item.get('source_view', 'front')
            if source_view not in ('front', 'rear'):
                raise ValueError('Panel source_view must be front or rear')
            spec['pieces'].append(panel(spec, item['id'], item['part'], item['kind'], item['rows_px'],
                                         item['plane_axis'], item['plane_coordinate'], physics, view=source_view))
            if 'paired_rows_px' in item:
                if len(item['paired_rows_px']) != len(item['rows_px']):
                    raise ValueError('Paired cloth rows must correspond')
                n = spec['pieces'][-1]['pattern']['columns']
                paired_rows = []
                for front_row, rear_row in zip(item['rows_px'], item['paired_rows_px']):
                    endpoints = np.array([paired_point(spec, a, b) for a, b in zip(front_row, rear_row)])
                    paired_rows.append({'points': [((1-u)*endpoints[0]+u*endpoints[1]).tolist() for u in np.linspace(0,1,n)]})
                spec['pieces'][-1]['pattern']['rows'] = paired_rows
            if 'rear_rows_px' in item:
                spec['pieces'][-1]['capture_view'] = 'front'
                spec['pieces'][-1]['id'] += '_front'
                spec['pieces'].append(panel(spec, item['id'] + '_rear', item['part'], item['kind'],
                    item['rear_rows_px'], item['plane_axis'], item['plane_coordinate'], physics, view='rear'))
                spec['pieces'][-1]['capture_view'] = 'rear'
        elif kind == 'sleeve':
            centres = [spec['joints'][name] for name in item['joints']]
            if 'end_fraction' in item:
                centres[-1] = (np.array(centres[-2]) + item['end_fraction'] *
                               (np.array(centres[-1]) - centres[-2])).tolist()
            seam = None
            if item.get('seam_chain'):
                a, b, c = (np.array(spec['joints'][name]) for name in item['seam_chain'])
                first, second = b - a, c - b
                seam = first / np.linalg.norm(first) + second / np.linalg.norm(second)
                if np.linalg.norm(seam) < COMPILE_DEFAULTS['seam_epsilon']:
                    raise ValueError('Sleeve elbow seam has no bisector')
            spec['pieces'].append(sleeve(spec, item['id'], item['part'], centres,
                [x * spec['ortho_scale'] / 256 for x in item['radii_px']], physics,
                seam, item.get('seam_end')))
        elif kind == 'cowl':
            centre = np.array(spec['joints'][item['joint']])
            rows = []
            forward, lateral = np.array([1., 0, 0]), np.array([0., 1, 0])
            if item.get('frame_joints'):
                lateral = np.subtract(*(spec['joints'][j] for j in reversed(item['frame_joints'])))
                lateral[2] = 0
                lateral /= np.linalg.norm(lateral)
                forward = np.cross(lateral, [0, 0, 1])
            for index, ring in enumerate(item['rings']):
                z_offset, radius_x_px, radius_y_px = ring[:3]
                shift = np.array(ring[3:6] if len(ring) == 6 else [0, 0, 0])
                row_centre = (np.array(paired_point(spec, *item['row_centres_px'][str(index)]))
                              if str(index) in item.get('row_centres_px', {}) else
                              centre + [0, 0, z_offset * spec['ortho_scale'] / 256])
                rows.append([(row_centre + (math.cos(a) * radius_x_px * forward + math.sin(a) * radius_y_px * lateral) * spec['ortho_scale'] / 256 + shift).tolist()
                             for a in (np.linspace(item['opening_half_angles'][index], math.tau - item['opening_half_angles'][index], item.get('columns', COMPILE_DEFAULTS['ring_samples'])) if 'opening_half_angles' in item else np.linspace(*item['angles'], item.get('columns', COMPILE_DEFAULTS['ring_samples']), endpoint=False))])
            if 'hem_px' in item:
                rows[-1] = bounded_hem(spec, rows[-1], item['hem_px'])
            if 'fold_allowance_px' in item:
                from spec.art_identity.maquettes.blender.drape import gathered_rows
                rows = gathered_rows(rows, item['closed'], item['fold_allowance_px'], spec['ortho_scale'] / 256)
            spec['pieces'].append(cloth(item['id'], item['part'], item['kind'], rows,
                                        item['closed'], physics))
        elif kind == 'ring':
            centre = np.array(paired_point(spec, *item['centre_px']))
            first, second = (np.array(axis, float) for axis in item['axes'])
            radii = np.array(item['radii_px']) * spec['ortho_scale'] / 256
            path = [(centre + radii[0] * math.cos(a) * first + radii[1] * math.sin(a) * second).tolist()
                    for a in np.linspace(0, math.tau, COMPILE_DEFAULTS['ring_samples'], endpoint=False)]
            spec['pieces'].append(curve(item['id'], item['part'], path,
                item['radius_px'] * spec['ortho_scale'] / 256, [1] * len(path), True))
        elif kind == 'crescent':
            from spec.art_identity.maquettes.blender.sculpted_blade import crescent, BLADE_DEFAULTS
            outline = [paired_point(spec, a, b) for a, b in zip(item['front_outline_px'], item['rear_outline_px'])]
            vertices, faces = crescent([outline[i] for i in item['outer_indices']], [outline[i] for i in item['inner_indices']], item['root_depth_px'] * spec['ortho_scale'] / 256)
            piece = common(item['id'], 'sculpted_blade', item['part'])
            piece.update(vertices=vertices, faces=faces, source_outline_px=item['front_outline_px'])
            if item.get('root_joint'):
                piece['root_joint'] = item['root_joint']
                piece['root_indices'] = list(range(BLADE_DEFAULTS['cross_samples']))
            spec['pieces'].append(piece)
        elif kind == 'ridged_shell':
            from spec.art_identity.maquettes.blender.ridged_shell import layered
            plates = []
            for layer in item['layers']:
                if len(layer['front_rim_px']) != len(layer['rear_rim_px']):
                    raise ValueError('Rigid shell rims require corresponding corners')
                plates.append({'rim': [paired_point(spec, a, b) for a, b in zip(layer['front_rim_px'], layer['rear_rim_px'])],
                    'ridge': paired_point(spec, *layer['ridge_px']),
                    'thickness': layer['thickness_px'] * spec['ortho_scale'] / 256})
            vertices, faces = layered(plates)
            piece = common(item['id'], 'rigid_shell', item['part'])
            piece.update(vertices=vertices, faces=faces, rig_joint=item['joint'])
            if item.get('clearance_parts'):
                piece['clearance_parts'] = item['clearance_parts']
            spec['pieces'].append(piece)
        elif kind == 'body_plate':
            piece = common(item['id'], 'plate', item['part'])
            piece.update(outline=[[0,0],[1,0],[0,1]], body_shell=True, body_regions=item['regions'], contact_hull=True,
                         smooth_shell=True, thick=item['thick'], bevel=deepcopy(item['bevel']), offset_surface=item['offset_surface'])
            spec['pieces'].append(piece)
        elif kind == 'neck_collar':
            piece = common(item['id'], 'neck_collar', item['part'])
            piece.update(centre=paired_point(spec, *item['centre_px']), neck_region=item['neck_region'],
                         neck_clearance=item['neck_clearance'], tube_diameter=item['tube_diameter'],
                         tilt_degrees=item['tilt_degrees'], chain=deepcopy(item['chain']))
            spec['pieces'].append(piece)
        elif kind == 'plate':
            if 'rear_outline_px' in item and len(item['rear_outline_px']) != len(item['front_outline_px']):
                raise ValueError('Spatial plate requires corresponding front/rear corners')
            points = ([paired_point(spec, a, b) for a, b in zip(item['front_outline_px'], item['rear_outline_px'])]
                      if 'rear_outline_px' in item else
                      [plane_point(spec, p, item['plane_axis'], item['plane_coordinate']) for p in item['front_outline_px']])
            piece = common(item['id'], 'plate', item['part'])
            piece.update(outline=[[p[0], p[2]] for p in points], outline_3d=points,
                         source_outline_px=item['front_outline_px'], conform_weights=[0] * len(points),
                         thick=item['thick'], bevel=item['bevel'], offset_surface=0)
            spec['pieces'].append(piece)
        elif kind in ('curve', 'tube', 'lathe'):
            path = path_points(spec, item)
            taper = item['taper']
            if kind == 'lathe':
                from spec.art_identity.maquettes.blender.lathe_profile import smooth_axis
                path, taper = smooth_axis(path, taper)
            spec['pieces'].append(curve(item['id'], item['part'], path,
                                        item['radius_px'] * spec['ortho_scale'] / 256,
                                        taper, item.get('closed', False)))
            if kind in ('tube', 'lathe'):
                spec['pieces'][-1].update(type='tube', sides=item['sides'],
                    wall=item['wall_px'] * spec['ortho_scale'] / 256)
                if kind == 'lathe':
                    spec['pieces'][-1]['smooth_surface'] = True
                if 'radial_profile' in item:
                    spec['pieces'][-1]['radial_profile'] = deepcopy(item['radial_profile'])
        elif kind == 'crystal':
            piece = common(item['id'], 'crystal', item['part'])
            path = path_points(spec, item)
            piece.update(path=path, sides=item['sides'], length=float(np.linalg.norm(np.subtract(path[-1], path[0]))),
                         width_profile=[[t, w * spec['ortho_scale'] / 256] for t, w in item['profile_px']],
                         jag=deepcopy(item['jag']))
            spec['pieces'].append(piece)
        else:
            raise ValueError('Unknown measured surface: ' + kind)
        if item.get('paired_anchors_px'):
            spec['pieces'][-1]['spatial_anchors'] = {key: paired_point(spec, *value) for key, value in item['paired_anchors_px'].items()}
        if item.get('drape',{}).get('yoke_seam_joint'):
            from spec.art_identity.maquettes.blender.cloth_attachment import sew_yoke
            for i in range(first_piece,len(spec['pieces'])):
                spec['pieces'][i]=sew_yoke(spec['pieces'][i],spec,item['drape']['yoke_seam_joint'])
        if 'wind' in item:
            for piece in spec['pieces'][first_piece:]:
                root = np.mean(piece['pattern']['rows'][0]['points'], axis=0)
                tail = np.mean(piece['pattern']['rows'][-1]['points'], axis=0)
                direction = tail - root
                direction[2] = 0
                if item['wind'].get('space') == 'screen_right':
                    matrix, _, basis, _ = camera(spec, piece.get('capture_view', 'front'))
                    direction = basis[0] @ matrix[:3, :3]
                piece['wind'] = {**deepcopy(item['wind']), 'direction': direction.tolist(), 'location': root.tolist()}
        if 'side_parts' in item:
            spec['pieces'][-1]['side_parts'] = item['side_parts']
        for key in ('contact_regions', 'collision_refine_levels', 'symmetry_origin', 'symmetry_front', 'symmetry_lateral', 'ownership_mode', 'joint_parts', 'joint_chain', 'seat_on', 'sewn_parts', 'face_plane', 'native_mask', 'closed_cover'):
            if key in item:
                spec['pieces'][-1][key] = deepcopy(item[key])
        if item.get('symmetry_joint'):
            spec['pieces'][-1]['symmetry_origin'] = spec['joints'][item['symmetry_joint']]
        if 'drape' in item:
            from spec.art_identity.maquettes.blender.drape import tailor
            settings=deepcopy(item['drape'])
            if settings.get('yoke_seam_joint') and settings.get('trailing_splits'):
                settings['trailing_splits']['source_row']+=1
            for i in range(first_piece, len(spec['pieces'])):
                spec['pieces'][i] = tailor(spec['pieces'][i], settings)
        if item.get('column_parts'):
            from spec.art_identity.maquettes.blender.contract import pattern_mesh
            piece = spec['pieces'][-1]
            vertices, faces = pattern_mesh(piece['pattern'], piece['rag'])
            n = piece['pattern']['columns']
            pair = item['column_parts']
            owners = [list(spec['labels']).index(pair[0 if min(f) % n < (n - 1) / 2 else 1]) for f in faces]
            piece['pattern']['explicit'] = {'vertices': vertices, 'faces': [list(f) for f in faces], 'owners': owners}
            piece['sewn_parts'] = pair
        if 'bands' in item:
            from spec.art_identity.maquettes.blender.drape import path_bands
            piece = spec['pieces'][-1]
            bands = [{**band, 'thickness': band['thickness_px'] * spec['ortho_scale'] / 256}
                     for band in item['bands']]
            spec['pieces'].extend(path_bands(item['id'], item['part'], piece['path'],
                [piece['radius'] * t for t in piece['taper']], bands, COMPILE_DEFAULTS['ring_samples']))
        # Both cloth states use the same collision policy and ownership. The
        # body, rig, joints and every other piece have no view-specific state.
        if 'rear_rows_px' in item:
            for key in ('contact_regions', 'collision_refine_levels', 'ownership_mode'):
                if key in spec['pieces'][-1]:
                    spec['pieces'][-2][key] = deepcopy(spec['pieces'][-1][key])
    if recipe.get('sewn_garment'):
        from spec.art_identity.maquettes.blender.sewn_garment import sew
        sewing = recipe['sewn_garment']
        torso = next(p for p in spec['pieces'] if p['id'] == sewing['torso'])
        sleeves = [next(p for p in spec['pieces'] if p['id'] == seam['sleeve']) for seam in sewing['seams']]
        garment = sew(torso, sleeves, spec, sewing['seams'])
        removed = {torso['id']} | {p['id'] for p in sleeves}
        spec['pieces'] = [garment if p['id'] == torso['id'] else p for p in spec['pieces'] if p['id'] not in removed or p['id'] == torso['id']]
    if recipe.get('per_view_cloth_pose'):
        spec['per_view_cloth_pose'] = deepcopy(recipe['per_view_cloth_pose'])
    if recipe.get('cloth_obstacles'):
        spec['cloth_obstacles'] = deepcopy(recipe['cloth_obstacles'])
    fit = deepcopy(recipe['fit']['front'])
    fit.update(source=recipe['sources']['front'], head_part='head', weapon_parts=recipe['weapon_parts'])
    spec['fit'] = fit
    correction_key = 'rear_body' if recipe.get('rear_body') else 'floor_contact_correction'
    if recipe.get(correction_key):
        from spec.art_identity.maquettes.blender.floor_contact import along_front_ray, far_leg_changes, require_leg_bones
        config = deepcopy(recipe[correction_key])
        require_leg_bones(spec, config)
        config['fitted_joints'] = deepcopy(spec['joints'])
        corrected = deepcopy(spec['joints'])
        for name in config['joint_chain']:
            point = np.array([spec['joints'][name]])
            corrected[name] = along_front_ray(spec, point, far_leg_changes(spec, point))[0].tolist()
        spec[correction_key] = config
        spec['joints'] = corrected
    if recipe.get('rear_capture'):
        spec['rear_capture'] = deepcopy(recipe['rear_capture'])
    spec['measurement_residuals_px'] = measurement_residuals(spec, recipe['joints_px'])
    validate(spec)
    return spec


def main(path):
    path = Path(path)
    spec = compile_recipe(json.loads(path.read_text()))
    destination = path.with_name('spec_native.json')
    destination.write_text(json.dumps(spec, indent=2, allow_nan=False) + '\n')
    print('SOURCE_RECIPE: PASS; ' + str(destination))


if __name__ == '__main__':
    main(sys.argv[1])
