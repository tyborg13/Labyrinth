"""Portable v2 validation, provenance keys and deterministic pattern operations."""
from __future__ import annotations

import hashlib
import json
import math
import random

DEFAULT_BUNDLE = '~/.cache/labyrinth/blender_human_base_meshes_v1.4.1/extracted/human-base-meshes-bundle-v1.4.1/human_base_meshes_bundle.blend'


BUILD_DEFAULTS = {'schema': 2, 'cache_revision': 8, 'hash_digits': 9,
                  'collision_epsilon': 1e-6, 'triangulation_epsilon': 1e-6,
                  'zero_length_squared_epsilon': 1e-12, 'fit_passes': 6,
                  'fit_scale_min': 0.6,
                  'fit_scale_max': 1.6, 'process_timeout_seconds': 600}
PIECE_TYPES = {'plate', 'lames', 'cloth', 'curve', 'crystal', 'gem', 'tube', 'neck_collar', 'sculpted_blade', 'rigid_shell'}
CLOTH_KINDS = {'cloak', 'collar', 'tabard', 'skirt', 'hood'}


def todos(value, path='spec'):
    if isinstance(value, dict):
        return [f'{path}.{k}' for k in value if k.startswith('TODO_DESIGN_')] + [
            p for k, v in value.items() for p in todos(v, f'{path}.{k}')]
    if isinstance(value, list):
        return [p for i, v in enumerate(value) for p in todos(v, f'{path}[{i}]')]
    return [f'{path}: {value}'] if isinstance(value, str) and value.startswith('TODO_DESIGN_') else []


def digest(value):
    return hashlib.sha256(json.dumps(value, sort_keys=True, separators=(',', ':'),
                                     allow_nan=False).encode()).hexdigest()


def mesh_hash(vertices, faces, labels=None):
    return digest({'vertices': [[round(float(x), BUILD_DEFAULTS['hash_digits']) for x in v]
                                for v in vertices], 'faces': [list(f) for f in faces],
                   'labels': labels})


def bone_table(spec):
    """Explicit rest endpoints avoid guessing anatomy from bundle vertex indices."""
    return spec['armature']['bones']


def vector(value, size, name):
    if not isinstance(value, (list, tuple)) or len(value) != size or any(
            not isinstance(x, (int, float)) or not math.isfinite(x) for x in value):
        raise ValueError('Invalid finite vector: ' + name)


def validate(spec):
    if spec.get('version') != 2:
        raise ValueError('Blender-native builder requires version: 2')
    missing = todos(spec)
    if missing:
        raise ValueError('Unresolved design: ' + '; '.join(missing))
    if not spec['base']['asset']:
        raise ValueError('base.asset is required')
    if len(spec['base']['matrix']) != 4:
        raise ValueError('base.matrix must be 4x4')
    for row in spec['base']['matrix']:
        vector(row, 4, 'base.matrix')
    for part, profiles in spec['base'].get('source_profiles', {}).items():
        if part not in set(spec['labels']) | set(spec['base'].get('covered_regions', [])) or not profiles or not set(profiles) <= {'front', 'rear'}:
            raise ValueError('Source cage requires a registered part and measured front/rear views')
        for outline in profiles.values():
            if len(outline) < 3:
                raise ValueError('Source cage outline requires at least three points')
            for point in outline:
                vector(point, 2, 'source cage point')
    for name, p in spec['joints'].items():
        vector(p, 3, 'joint ' + name)
    labels = spec['labels']
    colours = []
    for name, colour in labels.items():
        if len(colour) != 3 or any(not math.isfinite(x) or not 0 <= x <= 1 for x in colour):
            raise ValueError('Invalid label colour: ' + name)
        if colour in colours:
            raise ValueError('Duplicate label colour: ' + name)
        colours.append(colour)
    bones = bone_table(spec)
    names = {b['name'] for b in bones}
    if len(names) != len(bones):
        raise ValueError('Duplicate bone names')
    rest = spec['armature']['rest_joints']
    for b in bones:
        for field in ('head', 'tail'):
            if b[field] not in rest or b[field] not in spec['joints']:
                raise ValueError('Missing rest/pose joint: ' + b[field])
        if b['region'] not in set(labels) | set(spec['base'].get('covered_regions', [])) or (b.get('parent') is not None and b['parent'] not in names):
            raise ValueError('Unknown bone parent or region: ' + b['name'])
        if sum((a - c) ** 2 for a, c in zip(rest[b['head']], rest[b['tail']])) < BUILD_DEFAULTS['zero_length_squared_epsilon']:
            raise ValueError('Zero-length rest bone: ' + b['name'])
        if sum((a - c) ** 2 for a, c in zip(spec['joints'][b['head']], spec['joints'][b['tail']])) < BUILD_DEFAULTS['zero_length_squared_epsilon']:
            raise ValueError('Zero-length posed bone: ' + b['name'])
        if any(x <= 0 or not math.isfinite(x) for x in b['scale']) or len(b['scale']) != 2:
            raise ValueError('Bone scale requires two positive transverse values')
    # Detect parent cycles before Blender or the pose solver can hang.
    parents = {b['name']: b.get('parent') for b in bones}
    for name in names:
        seen = set()
        while name is not None:
            if name in seen:
                raise ValueError('Bone parent cycle')
            seen.add(name)
            name = parents[name]
    ids = set()
    for piece in spec['pieces']:
        if piece['id'] in ids:
            raise ValueError('Duplicate piece id: ' + piece['id'])
        ids.add(piece['id'])
        if piece['type'] not in PIECE_TYPES or piece['part'] not in labels:
            raise ValueError('Unknown piece type or part: ' + piece['id'])
        if 'capture_view' in piece and (piece['type'] != 'cloth' or piece['capture_view'] not in ('front', 'rear')):
            raise ValueError('Only cloth may have a front/rear capture_view: ' + piece['id'])
        if piece['at'] not in spec['joints'] or (piece.get('bone') and piece['bone'] not in names):
            raise ValueError('Unknown piece attachment: ' + piece['id'])
        vector(piece['offset'], 3, piece['id'] + '.offset')
        vector(piece['rot'], 3, piece['id'] + '.rot')
        if piece['type'] == 'rigid_shell':
            if piece['rig_joint'] not in spec['joints'] or not piece['faces']:
                raise ValueError('Rigid shell requires a rig attachment and closed faces')
            for point in piece['vertices']:
                vector(point, 3, 'rigid shell vertex')
            from collections import Counter
            edges = Counter(tuple(sorted((a, b))) for face in piece['faces'] for a, b in zip(face, face[1:] + face[:1]))
            if any(count != 2 for count in edges.values()):
                raise ValueError('Rigid shell must have closed manifold plates')
            for name in piece.get('clearance_parts', []):
                target = next((p for p in spec['pieces'] if p['id'] == name), None)
                if target is None or name not in ids - {piece['id']} or target['type'] != 'cloth':
                    raise ValueError('Rigid backing requires preceding solved cloth')
        if piece.get('conforming'):
            lift = max(piece.get('overlap', [0]))
            if not 0 <= piece['offset_surface'] <= .015 or piece['offset_surface'] + lift > .015:
                raise ValueError('Conforming armour offset must not exceed 0.015: ' + piece['id'])
            if piece['type'] in ('plate', 'lames') and piece['surface_spacing'] <= 0:
                raise ValueError('Positive armour surface spacing required')
        if piece['type'] == 'neck_collar':
            vector(piece['centre'], 3, 'collar centre')
            chain = piece['chain']
            if piece['neck_region'] not in labels or min(piece['neck_clearance'], piece['tube_diameter']) <= 0 or not chain['length'] > chain['width'] > chain['wire_diameter'] > 0 or type(chain['count']) is not int or chain['count'] < 1 or chain.get('alternate_degrees') != 90:
                raise ValueError('Invalid metric collar or chain dimensions')
        if piece['type'] == 'cloth':
            if piece['kind'] not in CLOTH_KINDS:
                raise ValueError('Unknown cloth kind')
            if 'side_parts' in piece and (len(piece['side_parts']) != 2 or
                    len(set(piece['side_parts'])) != 2 or
                    any(part not in labels for part in piece['side_parts'])):
                raise ValueError('Cloth side_parts requires two distinct registered body-side labels')
            if 'contact_regions' in piece and (not piece['contact_regions'] or
                    any(part not in labels for part in piece['contact_regions'])):
                raise ValueError('Cloth contact_regions requires registered body-region labels')
            if piece.get('ownership_mode', 'body_sagittal') not in ('whole_piece', 'body_sagittal'):
                raise ValueError('Unknown cloth ownership_mode')
            if piece.get('ownership_mode') == 'whole_piece' and 'side_parts' in piece:
                raise ValueError('Whole-piece cloth cannot also partition side_parts')
            if 'joint_parts' in piece:
                if (len(piece['joint_parts']) != 2 or len(set(piece['joint_parts'])) != 2 or piece['part'] != piece['joint_parts'][0] or
                        any(p not in labels for p in piece['joint_parts']) or 'side_parts' in piece or
                        len(piece.get('joint_chain', [])) != 3 or any(j not in spec['joints'] for j in piece['joint_chain'])):
                    raise ValueError('Joint-owned cloth requires two labels and a three-joint chain')
            if not piece['pattern']['pins'] or piece['frames'] < 1:
                raise ValueError('Cloth requires pins and a positive frame count')
            if piece.get('drape'):
                from .drape import simulation_contract, DRAPE_DEFAULTS
                if piece['drape'].get('implementation_revision') != DRAPE_DEFAULTS['implementation_revision']:
                    raise ValueError('Drape implementation changed; recompile the figure recipe')
                if not simulation_contract(piece):
                    raise ValueError('Draped cloth requires free fabric and simulation frames')
                hood = piece['drape'].get('native_hood', {})
                if hood.get('opening_width_ratio') == 0 and hood.get('closed_topology_revision') != 2:
                    raise ValueError('Closed native cowl requires topology revision 2; recompile its recipe')
                if any(region not in labels for key in ('cutout_regions',)
                       for region in piece['drape'].get(key, [])):
                    raise ValueError('Cloth armholes require registered body regions')
                if 'regional_contact' in piece['drape']:
                    contact = piece['drape']['regional_contact']
                    if (not contact.get('regions') or any(r not in labels for r in contact['regions']) or
                            type(contact.get('refine_levels')) is not int or contact['refine_levels'] < 1 or
                            ('union_regions' in contact and type(contact['union_regions']) is not bool)):
                        raise ValueError('Regional cloth contact requires registered regions and positive refinement')
            pattern_mesh(piece['pattern'], piece['rag'])
        if piece['type'] in ('plate', 'lames'):
            if len(piece['outline']) < 3 or piece['thick'] <= 0:
                raise ValueError('Plate requires polygon and positive thickness')
            if 'outline_3d' in piece:
                if len(piece['outline_3d']) != len(piece['outline']) or piece.get('ridge') or piece.get('conforming'):
                    raise ValueError('Spatial plate requires matching corners and no planar ridge/conformance')
                for point in piece['outline_3d']:
                    vector(point, 3, 'spatial plate corner')
        if piece['type'] == 'lames':
            if piece['count'] < 1 or any(len(piece[k]) != piece['count'] for k in ('lame_scale', 'lame_drop', 'overlap')):
                raise ValueError('Lames require positive count and one scale/drop/overlap per lame')
        if piece['type'] == 'curve':
            if piece['spline'] not in ('POLY', 'BEZIER') or len(piece['path']) < 2 or len(piece['taper']) != len(piece['path']):
                raise ValueError('Curve requires POLY/BEZIER path and matching taper profile')
            if piece['radius'] <= 0 or any(r < 0 for r in piece['taper']):
                raise ValueError('Invalid curve radius/taper')
        if piece['type'] == 'tube':
            from .tube import tube_mesh
            tube_mesh(piece['path'], [piece['radius'] * t for t in piece['taper']],
                      piece['wall'], piece['sides'], piece.get('radial_profile'))
        if piece['type'] == 'crystal':
            profile = piece['width_profile']
            if piece['sides'] < 3 or piece['length'] <= 0 or len(profile) < 2 or profile[0][0] != 0 or profile[-1] != [1, 0]:
                raise ValueError('Crystal requires faceted profile from 0 to sharp tip [1, 0]')
            if any(a[0] >= b[0] for a, b in zip(profile, profile[1:])) or any(w < 0 for t, w in profile):
                raise ValueError('Crystal profile must increase along the path')
            if piece.get('continues'):
                previous = next((p for p in spec['pieces'] if p['id'] == piece['continues']), None)
                if previous is None or previous['type'] != 'curve' or previous['id'] not in ids - {piece['id']}:
                    raise ValueError('Crystal must follow an earlier curve piece')
            if piece.get('continues_bone') and piece['continues_bone'] not in names:
                raise ValueError('Crystal continuation bone is unknown')
        if piece['type'] == 'gem' and (piece['sides'] < 3 or min(piece['length'], piece['width'], piece['depth']) <= 0):
            raise ValueError('Invalid bipyramid gem dimensions')
    by_id = {p['id']: p for p in spec['pieces']}
    for tuck in spec['base'].get('socket_tucks', []):
        socket = by_id.get(tuck['socket'], {}).get('socket')
        if (not socket or tuck['part'] != tuck['source_region'] or tuck['part'] not in labels or
                tuck['adjacent_region'] not in spec['base'].get('covered_regions', []) or
                tuck['end_joint'] not in spec['joints']):
            raise ValueError('Socket tuck requires its own anatomy label, a covered neighbour and an open socket')
    for pair in spec.get('cloth_obstacles', []):
        if len(pair) != 2 or any(name not in by_id for name in pair) or by_id[pair[0]]['type'] != 'cloth' or by_id[pair[1]]['type'] != 'rigid_shell':
            raise ValueError('Cloth obstacle pair requires a cloth and a rigid shell')
    return spec


def pattern_mesh(pattern, rag):
    """Sample an owner-specified sewn pattern; notch the hem before simulation.

    Each row is a 3D cross-section: open line [a,b] or closed ring
    {centre, radii}. This represents flat panels, annular collars and open
    cowls without inventing their dimensions. Slits omit lower-row quads while retaining a single connected belt panel.
    Pinned vertex indices are explicit. Ring samples pair front/back exactly.
    """
    if 'explicit' in pattern:
        mesh = pattern['explicit']
        for point in mesh['vertices']:
            vector(point, 3, 'sewn point')
        if len(mesh['owners']) != len(mesh['faces']) or any(len(f) < 3 or any(not 0 <= i < len(mesh['vertices']) for i in f) for f in mesh['faces']):
            raise ValueError('Invalid sewn rest topology')
        if any(not 0 <= i < len(mesh['vertices']) for i in pattern['pins']):
            raise ValueError('Pin outside sewn pattern')
        return mesh['vertices'], mesh['faces']
    n = pattern['columns']
    closed = pattern['closed']
    if n < 4 or (closed and n % 4):
        raise ValueError('Pattern columns >=4; closed rings require a multiple of four')
    rows = pattern['rows']
    if len(rows) < 2:
        raise ValueError('Pattern needs at least two rows')
    vertices = []
    for row in rows:
        if 'points' in row:
            if len(row['points']) != n:
                raise ValueError('Custom pattern row must match columns')
            for p in row['points']:
                vector(p, 3, 'pattern point')
            vertices.extend([list(p) for p in row['points']])
            continue
        if 'a' in row:
            vector(row['a'], 3, 'pattern row a')
            vector(row['b'], 3, 'pattern row b')
        else:
            vector(row['centre'], 3, 'pattern ring centre')
            vector(row['radii'], 2, 'pattern ring radii')
            vector(row['angles'], 2, 'pattern ring angles')
        for j in range(n):
            u = j / (n if closed else n - 1)
            if 'a' in row:
                vertices.append([a + (b - a) * u for a, b in zip(row['a'], row['b'])])
            else:
                start, sweep = row['angles']
                angle = start + sweep * u
                vertices.append([row['centre'][0] + row['radii'][0] * math.cos(angle),
                                 row['centre'][1] + row['radii'][1] * math.sin(angle), row['centre'][2]])
    splits = pattern.get('splits', {})
    if splits and (closed or not 1 <= splits['from_row'] < len(rows) - 1 or
                   splits['gap_columns'] < 1 or any(not 0 < j < n - splits['gap_columns'] - 1 for j in splits['columns'])):
        raise ValueError('Invalid open-panel strip cuts')
    faces = []
    for i in range(len(rows) - 1):
        for j in range(n if closed else n - 1):
            if splits and i >= splits['from_row'] and any(c <= j < c + splits['gap_columns'] for c in splits['columns']):
                continue
            k = (j + 1) % n
            faces.append((i * n + j, i * n + k, (i + 1) * n + k, (i + 1) * n + j))
    rng = random.Random(rag['seed'])
    if not 0 <= rag['count'] <= n or rag['depth'] < 0:
        raise ValueError('Invalid hem notches')
    indices = rng.sample(range(n), rag['count'])
    for j in indices:
        vertices[(len(rows) - 1) * n + j][2] += rag['depth']
    if any(not 0 <= i < len(vertices) for i in pattern['pins']):
        raise ValueError('Pin outside pattern')
    return vertices, faces


def label_faces(vertices, faces, weights, bone_regions):
    """Own each polygon by its summed automatic weights; fail uncovered regions."""
    result = []
    for face in faces:
        totals = {}
        for index in face:
            for bone, weight in weights[index].items():
                if bone in bone_regions:
                    region = bone_regions[bone]
                    totals[region] = totals.get(region, 0) + weight
        if not totals or max(totals.values()) <= 0:
            raise ValueError('Automatic weights left an unlabelled body face')
        result.append(max(sorted(totals), key=totals.get))
    return result
