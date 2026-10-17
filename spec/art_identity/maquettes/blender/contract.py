"""Portable v2 validation, provenance keys and deterministic pattern operations."""
from __future__ import annotations

import hashlib
import json
import math
import random

DEFAULT_BUNDLE = '~/.cache/labyrinth/blender_human_base_meshes_v1.4.1/extracted/human-base-meshes-bundle-v1.4.1/human_base_meshes_bundle.blend'


BUILD_DEFAULTS = {'schema': 2, 'cache_revision': 7, 'hash_digits': 9,
                  'collision_epsilon': 1e-6, 'triangulation_epsilon': 1e-6,
                  'zero_length_squared_epsilon': 1e-12, 'fit_passes': 6,
                  'fit_scale_min': 0.6,
                  'fit_scale_max': 1.6, 'process_timeout_seconds': 600}
PIECE_TYPES = {'plate', 'lames', 'cloth', 'curve', 'crystal', 'gem'}
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
        if b['region'] not in labels or (b.get('parent') is not None and b['parent'] not in names):
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
        if piece['at'] not in spec['joints'] or (piece.get('bone') and piece['bone'] not in names):
            raise ValueError('Unknown piece attachment: ' + piece['id'])
        vector(piece['offset'], 3, piece['id'] + '.offset')
        vector(piece['rot'], 3, piece['id'] + '.rot')
        if piece.get('conforming'):
            lift = max(piece.get('overlap', [0]))
            if not 0 <= piece['offset_surface'] <= .015 or piece['offset_surface'] + lift > .015:
                raise ValueError('Conforming armour offset must not exceed 0.015: ' + piece['id'])
            if piece['type'] in ('plate', 'lames') and piece['surface_spacing'] <= 0:
                raise ValueError('Positive armour surface spacing required')
        if piece['type'] == 'cloth':
            if piece['kind'] not in CLOTH_KINDS:
                raise ValueError('Unknown cloth kind')
            if not piece['pattern']['pins'] or piece['frames'] < 1:
                raise ValueError('Cloth requires pins and a positive frame count')
            pattern_mesh(piece['pattern'], piece['rag'])
        if piece['type'] in ('plate', 'lames'):
            if len(piece['outline']) < 3 or piece['thick'] <= 0:
                raise ValueError('Plate requires polygon and positive thickness')
        if piece['type'] == 'lames':
            if piece['count'] < 1 or any(len(piece[k]) != piece['count'] for k in ('lame_scale', 'lame_drop', 'overlap')):
                raise ValueError('Lames require positive count and one scale/drop/overlap per lame')
        if piece['type'] == 'curve':
            if piece['spline'] not in ('POLY', 'BEZIER') or len(piece['path']) < 2 or len(piece['taper']) != len(piece['path']):
                raise ValueError('Curve requires POLY/BEZIER path and matching taper profile')
            if piece['radius'] <= 0 or any(r < 0 for r in piece['taper']):
                raise ValueError('Invalid curve radius/taper')
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
    return spec


def pattern_mesh(pattern, rag):
    """Sample an owner-specified sewn pattern; notch the hem before simulation.

    Each row is a 3D cross-section: open line [a,b] or closed ring
    {centre, radii}. This represents flat panels, annular collars and open
    cowls without inventing their dimensions. Slits omit lower-row quads while retaining a single connected belt panel.
    Pinned vertex indices are explicit. Ring samples pair front/back exactly.
    """
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
