"""Semantic rigid motion compiled from protected keys and maquette geometry."""
from __future__ import annotations
import hashlib
import json
from pathlib import Path
import numpy as np
from maquette_cutout import projected, shape_center
from cutout_pipeline.cases import CutoutError

CHANNELS = {'raise_deg', 'lean_deg', 'lift_px', 'forward_px', 'squash', 'scale', 'alpha'}
VIEWS = ('front', 'rear')

def attachment_graph(spec, creature):
    """Use supplied joints, capsule starts and plate base edges, never image fits."""
    points = {'root': spec['joints']['root']}
    parents = {'root': None}
    mapping = {}
    for part in spec['labels']:
        if creature == 'lightning_wisp' and part in ('arc_left', 'arc_right', 'crown'):
            mapping[part] = 'core'
            continue
        shapes = [s for s in spec['shapes'] if s['part'] == part]
        if part in spec['joints']: point = spec['joints'][part]
        elif part == 'trunk': point = spec['joints']['base']
        elif shapes[0]['type'] == 'capsule': point = shapes[0]['a']
        elif shapes[0]['type'] == 'plate': point = np.mean([p for s in shapes for p in s['pts'][:2]], axis=0).tolist()
        else: raise CutoutError('TODO_DESIGN_joint_' + part)
        points[part] = point
        mapping[part] = part
        if creature == 'lightning_wisp': parent = 'root' if part == 'core' else 'core'
        elif part == 'trunk': parent = 'root'
        elif part == 'core' or part.startswith('petal_'): parent = 'crown'
        elif part.startswith('root_tip_'): parent = part.replace('root_tip_', 'root_stem_')
        else: parent = 'trunk'
        parents[part] = parent
    if creature == 'shale_bloomer':
        points['crown'] = spec['joints']['crown']
        parents['crown'] = 'trunk'
    return points, parents, mapping

def projection(spec, points, mapping, view):
    zero = np.asarray(projected(spec, [0, 0, 0], view))
    def vector(p): return np.asarray(projected(spec, p, view)) - zero
    up, forward = vector([0, 0, 1]), vector([1, 0, 0])
    def sign(ray, toward, label):
        cross = ray[0] * toward[1] - ray[1] * toward[0]
        if abs(cross) < 1e-8: raise CutoutError('TODO_DESIGN_' + label + '_' + view)
        return float(np.sign(cross))
    axes = {'forward': (forward / np.linalg.norm(forward)).tolist(), 'parts': {}}
    for bone, pivot in points.items():
        shapes = [s for s in spec['shapes'] if mapping.get(s['part']) == bone]
        # A composite joint (crown/root) has an upright local axis. For raise,
        # articulated surfaces use their actual joint-to-material displacement.
        ray = vector(np.mean([shape_center(s, spec['joints']) for s in shapes], axis=0) - pivot) if shapes else up
        item = {'lean_deg': sign(up, forward, 'lean_deg'), 'joint_3d': pivot}
        if shapes and abs(ray[0] * up[1] - ray[1] * up[0]) > 1e-8:
            item['raise_deg'] = sign(ray, up, 'raise_deg_' + bone)
        axes['parts'][bone] = item
    return axes

def compile_creature(source: Path, creature: str, spec: dict, graph: dict | None = None):
    all_data = json.loads(source.read_bytes())
    data = all_data[creature]
    if graph is None:
        if creature not in ('shale_bloomer','lightning_wisp'): raise CutoutError('TODO_DESIGN_joint_graph_' + creature)
        points, parents, mapping = attachment_graph(spec, creature)
    else:
        points = {name: item['position_3d'] for name,item in graph['joints'].items()}
        parents = {name: item['parent'] for name,item in graph['joints'].items()}
        mapping = graph['parts']
        if set(mapping) != set(spec['labels']) or 'root' not in points or set(mapping.values()) - set(points): raise CutoutError('Incomplete semantic joint graph')
        for name in parents:
            seen = set(); current = name
            while current is not None:
                if current in seen or current not in parents: raise CutoutError('Cyclic or missing semantic joint parent: ' + name)
                seen.add(current); current = parents[current]
    axes = {v: projection(spec, points, mapping, v) for v in VIEWS}
    compiled = {'creature': creature, 'director_sha256': hashlib.sha256(source.read_bytes()).hexdigest(),
                'joints_3d': points, 'parents': parents, 'parts': mapping, 'projection': axes,
                'clips': {}, 'view_tracks': {v: {} for v in VIEWS}, 'TODO_DESIGN': {}}
    for clip, authored in data['clips'].items():
        compiled['clips'][clip] = {k: v for k, v in authored.items() if k != 'keys'}
        for view in VIEWS:
            tracks = []
            for name, keys in authored['keys'].items():
                part, channel = name.rsplit('.', 1)
                if channel == 'forward_mode':
                    if keys != 'fraction_of_step': raise CutoutError('TODO_DESIGN_' + name)
                    continue
                if channel not in CHANNELS or (part != 'body' and part not in points): raise CutoutError('TODO_DESIGN_' + name)
                bone = 'root' if part == 'body' else part
                multiplier = axes[view]['parts'][bone].get(channel, 1.0)
                if channel in ('raise_deg', 'lean_deg') and channel not in axes[view]['parts'][bone]: raise CutoutError('TODO_DESIGN_' + name)
                rows = []
                for row in keys:
                    t, value = row[:2]
                    interpolation = row[2] if len(row) > 2 else 'smoothstep'
                    if interpolation not in ('hold','linear','smoothstep'): raise CutoutError('TODO_DESIGN_interpolation_' + name)
                    if channel in ('scale','squash') and value <= 0: raise CutoutError('Nonpositive scale: ' + name)
                    if channel == 'alpha' and not 0 <= value <= 1: raise CutoutError('Invalid alpha: ' + name)
                    rows.append({'at': t, 'value': value * multiplier, 'interpolation': row[2] if len(row) > 2 else 'smoothstep'})
                if not rows or any(not 0 <= k['at'] <= 1 for k in rows) or any(a['at'] >= b['at'] for a,b in zip(rows, rows[1:])): raise CutoutError('Invalid keys: ' + name)
                tracks.append({'source': name, 'bone': bone, 'channel': channel, 'keys': rows,
                               'forward_mode': authored['keys'].get(part + '.forward_mode', 'pixels')})
            compiled['view_tracks'][view][clip] = tracks
    return compiled

def evaluate(keys, phase):
    if phase <= keys[0]['at']: return keys[0]['value']
    for a,b in zip(keys, keys[1:]):
        if phase <= b['at']:
            w = (phase-a['at'])/(b['at']-a['at'])
            if b['interpolation'] == 'hold': w = float(phase == b['at'])
            elif b['interpolation'] == 'smoothstep': w = w*w*(3-2*w)
            return a['value'] + (b['value']-a['value'])*w
    return keys[-1]['value']

def sample_phases(compiled, clip):
    phases = {0.0, 1.0}
    for track in compiled['view_tracks']['front'][clip]:
        times = [k['at'] for k in track['keys']]
        phases.update(times)
        phases.update((a+b)/2 for a,b in zip(times,times[1:]))
    if 'contact' in compiled['clips'][clip]: phases.add(compiled['clips'][clip]['contact'])
    return sorted({round(p, 12) for p in phases})
