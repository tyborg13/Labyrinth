"""Compile measured rigid masses and limb chains into the shared native contract.

Only this opt-in recipe path supports nonhumanoid anatomy. Existing measured
cloth figures retain their unchanged compiler, builder and capture settings.
"""
from copy import deepcopy
import json
import math
from pathlib import Path

import numpy as np

from .contract import validate
from .facing import board_spec
from .source_recipe import common, paired_point, curve, measurement_residuals

PROJECT = Path(__file__).resolve().parents[4]
SOLID_DEFAULTS = {'crack_samples_per_segment': 12, 'ray_epsilon': 1e-12, 'implementation_revision': 3}


def shell_path(spec, mass, pixels, view='front'):
    """Lift measured crack strokes onto the view-facing ellipsoidal surface."""
    from ..raster import camera
    from .source_recipe import plane_point
    matrix, _, basis, _ = camera(spec,view)
    centre = np.array(mass['centre'])
    radii = np.array(mass['radii'])
    # Cracks are measured on an unrotated abdomen. Fail closed on unsupported
    # transforms instead of silently projecting a different feature.
    if mass['rot'] != [0, 0, 0]:
        raise ValueError('Measured crack projection requires an unrotated mass')
    direction = basis[2] @ matrix[:3, :3]
    result = []
    for index, (a, b) in enumerate(zip(pixels, pixels[1:])):
        for t in np.linspace(0, 1, SOLID_DEFAULTS['crack_samples_per_segment'], endpoint=index == len(pixels)-2):
            pixel = (1-t)*np.array(a)+t*np.array(b)
            point = np.array(plane_point(spec, pixel, 2, centre[2], view=view))
            q, d = (point-centre)/radii, direction/radii
            aa, bb, cc = d@d, 2*q@d, q@q-1
            discriminant = bb*bb-4*aa*cc
            if discriminant < -SOLID_DEFAULTS['ray_epsilon']:
                raise ValueError('Measured crack lies outside shell: ' + str(pixel.tolist()))
            distance = (-bb+math.sqrt(max(0, discriminant)))/(2*aa)
            result.append((point+distance*direction).tolist())
    return result


def compile_solids(recipe):
    baseline = board_spec(json.loads((PROJECT/'spec/art_identity/maquettes/frostglass_lancer/spec_r3.json').read_text()))
    native = recipe['native_solids']
    spec = {'version': 2, 'id': recipe['id'], 'ortho_scale': baseline['ortho_scale'],
            'target': baseline['target'], 'labels': deepcopy(recipe['labels']),
            'base': deepcopy(baseline['base']), 'armature': deepcopy(baseline['armature']),
            'simulation': deepcopy(baseline['simulation']), 'pieces': [], 'joints': {'root': [0,0,0]},
            'source_recipe': recipe['id']+'/measurements.json'}
    spec['native_solid_revision'] = SOLID_DEFAULTS['implementation_revision']
    spec['base'].pop('covered_above_z', None)
    spec['base'].pop('proposed', None)
    spec['armature'].pop('proposed', None)
    spec['simulation'].pop('proposed', None)
    for name, pixels in recipe['joints_px'].items():
        spec['joints'][name] = paired_point(spec, *pixels)
    if native['anatomy'] == 'chain':
        spec['base'] = {'asset': 'procedural_chain', 'matrix': [[0,-1,0,0],[1,0,0,0],[0,0,1,0],[0,0,0,1]],
                        'covered_regions': list(spec['labels'])}
        spec['armature'] = {'rest_joints': deepcopy(spec['joints']), 'collision_margin': baseline['armature']['collision_margin'],
                           'bones': deepcopy(native['bones'])}
        spec['forward_bones'] = deepcopy(native['forward_bones'])
    elif native['anatomy'] == 'cc0_humanoid':
        spec['base']['covered_regions'] = list(spec['labels'])
    else:
        raise ValueError('Unknown native anatomy')
    for item in native['surfaces']:
        kind = item['shape']
        if kind == 'mass':
            piece = common(item['id'], 'sculpted_mass', item['part'])
            for key in ('surface','relief','subdivision_levels','bevel','ico_subdivisions','chips','rig_bone','cutouts','profile','fractures','support_z','minimum_support_thickness'):
                if key in item:
                    piece[key] = deepcopy(item[key])
            piece['centre'] = paired_point(spec, *item['centre_px'])
            piece['radii'] = (np.array(item['radii_px'])*spec['ortho_scale']/256).tolist()
            piece['rot'] = deepcopy(item.get('rot', [0,0,0]))
            if item.get('crack_paths_px'):
                paths = [shell_path(spec,piece,p) for p in item['crack_paths_px']]
                paths += [shell_path(spec,piece,p,view='rear') for p in item.get('rear_crack_paths_px',[])]
                piece['grooves'] = {'paths': paths,
                    'width': item['crack_width_px']*spec['ortho_scale']/256,
                    'depth': item['crack_depth_px']*spec['ortho_scale']/256}
        elif kind == 'curve':
            points = [paired_point(spec, *p) for p in item['path_pairs_px']]
            piece = curve(item['id'], item['part'], points, item['radius_px']*spec['ortho_scale']/256,
                          item['taper'], item.get('closed',False))
            piece['spline'] = item.get('spline','BEZIER')
            if item.get('sculpt'):
                piece['sculpt'] = deepcopy(item['sculpt'])
            for key in ('resolution','bevel_resolution','smooth_surface'):
                if key in item:piece[key]=deepcopy(item[key])
        elif kind == 'mesh':
            piece = common(item['id'],'rigid_shell',item['part'])
            piece.update(vertices=deepcopy(item['vertices']),faces=deepcopy(item['faces']),rig_joint=item['rig_joint'])
        else:
            raise ValueError('Unknown native solid: '+kind)
        if item.get('rig_bone'):
            piece['rig_bone'] = item['rig_bone']
        spec['pieces'].append(piece)
    spec['facing_parts'] = deepcopy(native['facing_parts'])
    spec['facing_joints'] = deepcopy(native['facing_joints'])
    spec['native_features'] = deepcopy(native.get('features', {}))
    if native.get('contacts'):
        spec['native_contacts'] = deepcopy(native['contacts'])
    spec['fit'] = deepcopy(recipe['fit']['front'])
    spec['fit'].update(source=recipe['sources']['front'],head_part=recipe.get('head_part','head'),weapon_parts=[])
    spec['measurement_residuals_px'] = measurement_residuals(spec, recipe['joints_px'])
    validate(spec)
    return spec
