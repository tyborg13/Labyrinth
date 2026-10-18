"""Compile protected v2 channels without changing their values or clock."""
import hashlib
import json

from .anatomy import for_layout
from .bone_contracts import visible_leg, leg_bend_side
from .leg_roles import roles_for, resolve_bone

CHANNELS = {'forward_px', 'lift_px', 'inward_px', 'lean_deg', 'angle_deg'}


def compile_motion(source, creature, layouts, projection):
    author = json.loads(source.read_bytes())[creature]
    if author['rig'] != 'humanoid_v2' or author['units'] != 'source_px':
        raise ValueError('Expected humanoid_v2 source-pixel tracks')
    result = {'rig': author['rig'], 'units': author['units'], 'creature': creature,
              'director_sha256': hashlib.sha256(source.read_bytes()).hexdigest(),
              'projection': projection, 'clips': {}, 'view_tracks': {}, 'TODO_DESIGN': {}}
    for view, layout in layouts.items():
        anatomy = for_layout(layout)
        roles = roles_for(anatomy, view)
        if roles:
            result.setdefault('leg_roles', {})[view] = dict(roles)
            result.setdefault('view_forward_modes', {})[view] = {}
        if 'knee_policy' in anatomy:
            result['knee_policy'] = dict(anatomy['knee_policy'])
        for side in ('near', 'far'):
            if not visible_leg(layout['joints'], side): continue
            leg_bend_side(layout, anatomy, side, view)
            policy = anatomy.get('legs', {}).get(side, {}).get(view)
            if policy is not None:
                result.setdefault('legs', {}).setdefault(side, {})[view] = dict(policy)
        result['view_tracks'][view] = {}
        for clip, definition in author['clips'].items():
            result['clips'][clip] = {k: v for k, v in definition.items() if k != 'keys'}
            tracks, release = [], {}
            modes = {}
            for name, keys in definition['keys'].items():
                source_bone, channel = name.rsplit('.', 1)
                bone = resolve_bone(source_bone, anatomy, view)
                if bone not in layout['joints']:
                    raise ValueError('TODO_DESIGN_' + name)
                if channel == 'forward_mode':
                    if keys not in ('fraction_of_step', 'world_step', 'body'):
                        raise ValueError('TODO_DESIGN_' + name)
                    modes[bone] = keys
                    continue
                if channel == 'release_at':
                    if clip != 'death' or not 0 <= keys <= 1:
                        raise ValueError('TODO_DESIGN_' + name)
                    release[bone] = keys
                    continue
                if channel not in CHANNELS:
                    raise ValueError('TODO_DESIGN_' + name)
                sign = projection[view]['lean_sign'] if channel in ('lean_deg', 'angle_deg') else 1
                rows = []
                for row in keys:
                    interpolation = row[2] if len(row) > 2 else 'smoothstep'
                    if interpolation not in ('smoothstep', 'linear', 'hold'):
                        raise ValueError('TODO_DESIGN_interpolation_' + name)
                    rows.append({'at': row[0], 'value': row[1] * sign, 'interpolation': interpolation})
                if not rows or any(not 0 <= k['at'] <= 1 for k in rows) or any(
                        a['at'] >= b['at'] for a, b in zip(rows, rows[1:])):
                    raise ValueError('Invalid keys: ' + name)
                tracks.append({'source': name, 'bone': bone, 'channel': channel, 'keys': rows,
                               'forward_mode': definition['keys'].get(source_bone + '.forward_mode', 'pixels')})
            if roles: result['view_forward_modes'][view][clip] = modes
            result['view_tracks'][view][clip] = tracks
            result['clips'][clip]['release_at'] = release
    return result
